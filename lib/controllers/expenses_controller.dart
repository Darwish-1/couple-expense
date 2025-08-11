// lib/controllers/expenses_controller.dart
import 'dart:developer';
import 'package:couple_expenses/controllers/wallet_controller.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/date_utils_ext.dart';

class ExpensesController extends GetxController {
  ExpensesController({
    // kept for backwards-compat, not used anymore (we always write under wallet subcollection)
    required this.collectionName,
    String? walletId,
  }) : walletId = RxnString(walletId);

  /// Deprecated for writes; we now use /wallets/{walletId}/receipts
  final String collectionName;

  /// active wallet id (if null we read from WalletController)
  final RxnString walletId;

  /// Month/year selection
  final RxString selectedMonth = getMonthName(DateTime.now().month).obs;
  final RxInt selectedYear = DateTime.now().year.obs;

  /// Instant UI feedback
  final RxList<Map<String, dynamic>> pendingExpenses = <Map<String, dynamic>>[].obs;
  final RxBool hasJustAddedExpenses = false.obs;
  final RxnString lastAddedId = RxnString();

  /// Info banners
  final RxString lastError = ''.obs;
  final RxString lastSuccess = ''.obs;

  /// cache bump (not strictly needed with streams, but kept)
  final RxMap<String, int> invalidationCounters = <String, int>{}.obs;

  void setWalletId(String? id) => walletId.value = id;

  Future<void> saveMultipleExpenses(List<Map<String, dynamic>> expenses) async {
    log('🎯 [DEBUG] Starting saveMultipleExpenses with ${expenses.length} expenses');

    if (expenses.isEmpty) {
      lastError.value = 'Nothing to save.';
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid;
    final wId = walletId.value ?? Get.find<WalletController>().walletId.value;
    final now = DateTime.now();

    if (userId == null) {
      lastError.value = 'User not authenticated.';
      return;
    }
    if (wId == null) {
      lastError.value = 'No wallet selected.';
      return;
    }

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;

    log('🎯 [DEBUG] userId: $userId, walletId: $wId, month: ${selectedMonth.value}($monthNum), year: $year');

    final Map<String, Map<String, dynamic>> grouped = {};

    for (final expense in expenses) {
      final parsedDate = tryParseAnyDate(expense['date_of_purchase'] as String?);
      final category = (expense['category'] as String?) ?? 'General';
      final itemName = expense['item_name'] as String?;
      final unitPrice = (expense['unit_price'] as num?)?.toDouble();

      if (itemName == null || unitPrice == null) {
        log('Skipping expense due to missing item_name or unit_price: $expense');
        continue;
      }

      final baseDate = parsedDate ?? now;
      final day = baseDate.day;
      final purchaseDate = DateTime(year, monthNum, day);

      final y = purchaseDate.year.toString().padLeft(4, '0');
      final m = purchaseDate.month.toString().padLeft(2, '0');
      final d = purchaseDate.day.toString().padLeft(2, '0');
      final dateKey = '$y-$m-$d';
      final groupKey = '$category-$dateKey';

      grouped.putIfAbsent(groupKey, () {
        return {
          'item_name': <String>[],
          'unit_price': <double>[],
          'date_of_purchase': Timestamp.fromDate(purchaseDate),
          'category': category,
          'userId': userId,                       // who added it
          'created_at': Timestamp.fromDate(now),  // for ordering
        };
      });

      (grouped[groupKey]!['item_name'] as List).add(itemName);
      (grouped[groupKey]!['unit_price'] as List).add(unitPrice);
    }

    log('🎯 [DEBUG] Created ${grouped.length} grouped expenses');

    // Instant UI: mark as pending
    pendingExpenses.assignAll(grouped.values.toList());
    hasJustAddedExpenses.value = true;

    final batch = FirebaseFirestore.instance.batch();
    String? firstDocId;

    try {
      final col = FirebaseFirestore.instance
          .collection('wallets')
          .doc(wId)
          .collection('receipts');

      for (final data in grouped.values) {
        final docRef = col.doc();
        batch.set(docRef, data);
        firstDocId ??= docRef.id;
        log('🎯 [DEBUG] Added to batch: ${docRef.id}');
      }

      log('🎯 [DEBUG] About to commit batch...');
      await batch.commit();
      log('🎯 [DEBUG] Batch committed successfully!');

      if (firstDocId != null) {
        lastAddedId.value = firstDocId;

        final monthName = getMonthName(monthNum);
        final key = '$monthName-$year';
        invalidationCounters[key] = (invalidationCounters[key] ?? 0) + 1;

        Future.delayed(const Duration(seconds: 1), () {
          lastAddedId.value = null;
        });
      }

      Future.delayed(const Duration(milliseconds: 1500), () {
        pendingExpenses.clear();
        hasJustAddedExpenses.value = false;
      });

      lastSuccess.value = 'Saved ${grouped.length} grouped entr${grouped.length == 1 ? 'y' : 'ies'}.';
      lastError.value = '';
      log('🎯 [DEBUG] Successfully completed saveMultipleExpenses');
    } catch (e) {
      pendingExpenses.clear();
      hasJustAddedExpenses.value = false;
      lastAddedId.value = null;

      lastError.value = 'Save failed. $e';
      lastSuccess.value = '';
      log('🎯 [DEBUG] ERROR in saveMultipleExpenses: $e');
    }
  }

  /// My expenses under /wallets/{wId}/receipts for the selected month (scoped by path)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyMonthInWallet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final wId = walletId.value ?? Get.find<WalletController>().walletId.value;
    if (uid == null || wId == null) return const Stream.empty();

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;

    final start = Timestamp.fromDate(DateTime(year, monthNum, 1));
    final end = Timestamp.fromDate(
      DateTime(year, monthNum + 1, 1).subtract(const Duration(milliseconds: 1)),
    );

    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('userId', isEqualTo: uid)
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThanOrEqualTo: end)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Shared (all members) under /wallets/{wId}/receipts for the selected month
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMonthForWallet() {
    final wId = walletId.value ?? Get.find<WalletController>().walletId.value;
    if (wId == null) return const Stream.empty();

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;

    final start = Timestamp.fromDate(DateTime(year, monthNum, 1));
    final end = Timestamp.fromDate(
      DateTime(year, monthNum + 1, 1).subtract(const Duration(milliseconds: 1)),
    );

    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThanOrEqualTo: end)
        .orderBy('created_at', descending: true)
        .snapshots();
  }
}
