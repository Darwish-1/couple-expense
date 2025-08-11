// lib/controllers/expenses_controller.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import 'package:couple_expenses/controllers/wallet_controller.dart';
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

  /// Month/year selection (month is the *label* month; the period is [anchorDay..nextAnchorDay))
  final RxString selectedMonth = getMonthName(DateTime.now().month).obs;
  final RxInt selectedYear = DateTime.now().year.obs;

  /// Budget anchor day (1..31). Period = [YYYY-MM-anchor, nextMonth(anchor))
  /// Loaded from wallet: wallets/{id}.budget_anchor_day (default 1)
  final RxInt budgetAnchorDay = 1.obs;

  /// Instant UI feedback
  final RxList<Map<String, dynamic>> pendingExpenses = <Map<String, dynamic>>[].obs;
  final RxBool hasJustAddedExpenses = false.obs;
  final RxnString lastAddedId = RxnString();

  /// Info banners
  final RxString lastError = ''.obs;
  final RxString lastSuccess = ''.obs;

  /// cache bump (not strictly needed with streams, but kept)
  final RxMap<String, int> invalidationCounters = <String, int>{}.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _walletSub;

  // 🔧 ever(...) returns a Worker, not a StreamSubscription
  Worker? _walletIdWorker;
  Worker? _ownWalletIdWorker;

  @override
  void onInit() {
    super.onInit();

    // Watch the WalletController's wallet id so we can bind anchor day
    if (Get.isRegistered<WalletController>()) {
      final wc = Get.find<WalletController>();
      _walletIdWorker = ever<String?>(wc.walletId, (_) => _bindAnchorDay());
    }

    // Also watch our own walletId override
    _ownWalletIdWorker = ever<String?>(walletId, (_) => _bindAnchorDay());

    // Initial bind
    _bindAnchorDay();
  }

  @override
  void onClose() {
    _walletSub?.cancel();
    _walletIdWorker?.dispose();
    _ownWalletIdWorker?.dispose();
    super.onClose();
  }

  void setWalletId(String? id) => walletId.value = id;

  /// Loads budget_anchor_day from the current wallet doc and keeps it reactive.
  void _bindAnchorDay() {
    _walletSub?.cancel();

    final wId = walletId.value ??
        (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
    if (wId == null) {
      budgetAnchorDay.value = 1;
      return;
    }

    _walletSub = FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .snapshots()
        .listen((snap) {
      final raw = (snap.data()?['budget_anchor_day'] as num?)?.toInt();
      // keep 1..31; clamping to 28/30 happens when computing period boundaries
      budgetAnchorDay.value = (raw == null || raw < 1 || raw > 31) ? 1 : raw;
      log('⏱️ budget_anchor_day for wallet=$wId -> ${budgetAnchorDay.value}');
    }, onError: (e) {
      log('⚠️ failed to read budget_anchor_day: $e');
      budgetAnchorDay.value = 1;
    });
  }

  /// Allow changing the anchor day (e.g., payday = 7 or 27)
  Future<void> setBudgetAnchorDay(int day) async {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
    if (wId == null) {
      lastError.value = 'No wallet selected.';
      return;
    }
    final clamped = day.clamp(1, 31);
    await FirebaseFirestore.instance.collection('wallets').doc(wId).set(
      {'budget_anchor_day': clamped},
      SetOptions(merge: true),
    );
    // Local update; snapshot will also come through
    budgetAnchorDay.value = clamped;
    lastSuccess.value = 'Start day set to $clamped';
  }

 Future<void> saveMultipleExpenses(List<Map<String, dynamic>> expenses) async {
  log('🎯 [DEBUG] Starting saveMultipleExpenses with ${expenses.length} expenses');

  if (expenses.isEmpty) {
    lastError.value = 'Nothing to save.';
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid;
  final wId = walletId.value ??
      (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
  final now = DateTime.now();

  if (userId == null) {
    lastError.value = 'User not authenticated.';
    return;
  }
  if (wId == null) {
    lastError.value = 'No wallet selected.';
    return;
  }

  // NOTE: we no longer force month/year to the selected label.
  // The period filter is handled by the stream queries.
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

    // Use the actual date (parsed or "now"), without forcing the selected label month.
    final purchaseDate = parsedDate ?? now;

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
  /// My expenses under /wallets/{wId}/receipts for the selected month (scoped by wallet + anchor day)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyMonthInWallet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
    if (uid == null || wId == null) return const Stream.empty();

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;
    final anchor = budgetAnchorDay.value;

    final start = Timestamp.fromDate(startOfBudgetPeriod(year, monthNum, anchor));
    final nextStart = Timestamp.fromDate(nextStartOfBudgetPeriod(year, monthNum, anchor));

    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('userId', isEqualTo: uid)
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThan: nextStart) // exclusive upper bound
        .orderBy('date_of_purchase', descending: true)
        .snapshots();
  }

  /// Shared (all members) under /wallets/{wId}/receipts for the selected month (scoped by wallet + anchor day)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMonthForWallet() {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
    if (wId == null) return const Stream.empty();

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;
    final anchor = budgetAnchorDay.value;

    final start = Timestamp.fromDate(startOfBudgetPeriod(year, monthNum, anchor));
    final nextStart = Timestamp.fromDate(nextStartOfBudgetPeriod(year, monthNum, anchor));

    return FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThan: nextStart) // exclusive upper bound
        .orderBy('date_of_purchase', descending: true)
        .snapshots();
  }
}
