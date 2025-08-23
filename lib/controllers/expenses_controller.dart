import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couple_expenses/controllers/wallet_controller.dart';
import '../utils/date_utils_ext.dart';

class ExpensesController extends GetxController {
  ExpensesController({
    // kept for backwards-compat, not used for writes anymore
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

  /// Info banners
  final RxString lastError = ''.obs;
  final RxString lastSuccess = ''.obs;

  /// cache bump (not strictly needed with streams, but kept)
  final RxMap<String, int> invalidationCounters = <String, int>{}.obs;

  // Wallet doc subscription (for anchor day)
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _walletSub;

  // Budgets subscriptions
  StreamSubscription? _sharedBudgetSub;
  StreamSubscription? _myBudgetSub;

  // ever(...) returns a Worker
  Worker? _walletIdWorker;
  Worker? _ownWalletIdWorker;
 final RxBool micActive = false.obs;
  void startMic() => micActive.value = true;
  void stopMic()  => micActive.value = false;

  @override
  void onInit() {
    super.onInit();

    // Watch the WalletController so we can bind anchor day + (re)bind budgets + load saved period
    if (Get.isRegistered<WalletController>()) {
      final wc = Get.find<WalletController>();
      _walletIdWorker = everAll([wc.walletId, wc.isMember, wc.joining], (_) {
        _bindAnchorDay();
        _loadSelectedPeriod();
        _rebindBudgetsIfReady();
      });
    }

    // Also watch our own walletId override
    _ownWalletIdWorker = ever<String?>(walletId, (_) {
      _bindAnchorDay();
      _loadSelectedPeriod();
      _rebindBudgetsIfReady();
    });

    // Persist month/year whenever they change and rebind budgets
    everAll([selectedMonth, selectedYear], (_) {
      _saveSelectedPeriod();
      _rebindBudgetsIfReady();
    });

    // Initial binds
    _bindAnchorDay();
    _loadSelectedPeriod();
    _rebindBudgetsIfReady();
  }

  @override
  void onClose() {
    _walletSub?.cancel();
    unbindBudgets(); // cancel budget streams too
    _walletIdWorker?.dispose();
    _ownWalletIdWorker?.dispose();
    super.onClose();
  }

  void setWalletId(String? id) => walletId.value = id;

  /// Loads budget_anchor_day from the current wallet doc and keeps it reactive.
  void _bindAnchorDay() {
    _walletSub?.cancel();

    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);
    if (wId == null) {
      budgetAnchorDay.value = 1;
      return;
    }

    // 🔒 Only attach when we’re confirmed a member and not mid-join
    final wc = Get.isRegistered<WalletController>()
        ? Get.find<WalletController>()
        : null;
    if (wc != null && (wc.joining.value || wc.isMember.value != true)) {
      // Re-try later when membership flips
      return;
    }

    _walletSub = FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .snapshots()
        .listen(
          (snap) {
            final raw = (snap.data()?['budget_anchor_day'] as num?)?.toInt();
            budgetAnchorDay.value =
                (raw == null || raw < 1 || raw > 31) ? 1 : raw;
            log('⏱️ budget_anchor_day for wallet=$wId -> ${budgetAnchorDay.value}');
          },
          onError: (e) {
            log('⚠️ failed to read budget_anchor_day: $e');
            budgetAnchorDay.value = 1;
          },
        );
  }

  /// Persist selected month/year per wallet.
  Future<void> _saveSelectedPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wId = walletId.value ??
          (Get.isRegistered<WalletController>()
              ? Get.find<WalletController>().walletId.value
              : null);
      final scope = wId ?? 'global';

      final mNum = monthFromString(selectedMonth.value);
      final y = selectedYear.value;

      await prefs.setInt('exp_period_month_$scope', mNum);
      await prefs.setInt('exp_period_year_$scope', y);
    } catch (e) {
      log('⚠️ failed to save selected period: $e');
    }
  }

  /// Load selected month/year per wallet; if nothing saved, keep current values.
  Future<void> _loadSelectedPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wId = walletId.value ??
          (Get.isRegistered<WalletController>()
              ? Get.find<WalletController>().walletId.value
              : null);
      final scope = wId ?? 'global';

      final m = prefs.getInt('exp_period_month_$scope');
      final y = prefs.getInt('exp_period_year_$scope');

      if (m != null && m >= 1 && m <= 12) {
        selectedMonth.value = getMonthName(m);
      }
      if (y != null && y > 1900 && y < 3000) {
        selectedYear.value = y;
      }
    } catch (e) {
      log('⚠️ failed to load selected period: $e');
    }
  }

  /// Allow changing the anchor day (e.g., payday = 7 or 27)
  Future<void> setBudgetAnchorDay(int day) async {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);
    if (wId == null) {
      lastError.value = 'No wallet selected.';
      return;
    }
    final clamped = day.clamp(1, 31);
    await FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .set({'budget_anchor_day': clamped}, SetOptions(merge: true));
    // Local update; snapshot will also come through
    budgetAnchorDay.value = clamped;
    lastSuccess.value = 'Start day set to $clamped';
  }

  // ============================================================
  // BUDGETS: bind/unbind
  // ============================================================

  // YYYY-MM helper
  String _monthIdFromSelection() {
    final m = monthFromString(selectedMonth.value);
    final y = selectedYear.value;
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
  }

  void _rebindBudgetsIfReady() {
    final wc =
        Get.isRegistered<WalletController>() ? Get.find<WalletController>() : null;
    final wId = walletId.value ?? wc?.walletId.value;
    final u = FirebaseAuth.instance.currentUser;

    final joining = wc?.joining.value == true;
    final member = wc?.isMember.value == true;

    if (wId == null || u == null || joining || !member) {
      unbindBudgets();
      return;
    }

    bindBudgets(wId, u.uid, _monthIdFromSelection());
  }

  void bindBudgets(String walletId, String myUid, String monthId) {
    _sharedBudgetSub?.cancel();
    _myBudgetSub?.cancel();

    _sharedBudgetSub = FirebaseFirestore.instance
        .collection('wallets')
        .doc(walletId)
        .collection('budgets_shared')
        .doc(monthId)
        .snapshots()
        .listen((doc) {
          // TODO: update your shared budget observables if you have them
          // e.g., sharedBudget.value = doc.data() ?? {};
        }, onError: (e) {
          if (e is FirebaseException && e.code == 'permission-denied') return;
          log('🔥 shared budget stream error: $e');
        });

    _myBudgetSub = FirebaseFirestore.instance
        .collection('wallets')
        .doc(walletId)
        .collection('budgets_user')
        .doc(myUid)
        .collection('months')
        .doc(monthId)
        .snapshots()
        .listen((doc) {
          // TODO: update your personal budget observables if you have them
          // e.g., myBudget.value = doc.data() ?? {};
        }, onError: (e) {
          if (e is FirebaseException && e.code == 'permission-denied') return;
          log('🔥 my budget stream error: $e');
        });
  }

  void unbindBudgets() {
    _sharedBudgetSub?.cancel();
    _sharedBudgetSub = null;
    _myBudgetSub?.cancel();
    _myBudgetSub = null;
  }

  // ============================================================
  // MIC → DIRECT WRITE (no pending)
  // ============================================================

  /// Save parsed expenses directly to receipts.
  /// Each parsed map should contain: item_name, unit_price, category?, date_of_purchase?
  /// [shared] controls visibility: true -> 'shared', false -> 'private'
 /// Save parsed expenses directly to receipts.
/// Each parsed map should contain: item_name, unit_price, category?, date_of_purchase?
/// [shared] controls visibility: true -> 'shared', false -> 'private'
Future<int> saveParsedExpenses({
  required List<Map<String, dynamic>> items,
  required bool shared,
}) async {
  // --- 1) Preflight: wallet must be ready and we must be a member ---
  final wc = Get.isRegistered<WalletController>() ? Get.find<WalletController>() : null;
  if (wc != null && (wc.joining.value || wc.isMember.value != true)) {
    lastError.value = 'Wallet not ready. Please try again in a moment.';
    return 0;
  }
// NEW: Block shared saves unless there’s a partner
 if (shared && wc != null && wc.members.length < 2) {
   lastError.value = 'You can only add shared expenses after someone joins your wallet.';
    return 0;
 }
  if (items.isEmpty) {
    lastError.value = 'Nothing to save.';
    return 0;
  }

  final user = FirebaseAuth.instance.currentUser;
  final userId = user?.uid;

  final wId = walletId.value ??
      (Get.isRegistered<WalletController>() ? Get.find<WalletController>().walletId.value : null);
  final now = DateTime.now();

  if (userId == null) {
    lastError.value = 'User not authenticated.';
    return 0;
  }
  if (wId == null) {
    lastError.value = 'No wallet selected.';
    return 0;
  }

  // Period bounds for clamping
  final selMonthNum = monthFromString(selectedMonth.value);
  final selYear = selectedYear.value;
  final anchor = budgetAnchorDay.value;

  final periodStart = startOfBudgetPeriod(selYear, selMonthNum, anchor);
  final periodNext  = nextStartOfBudgetPeriod(selYear, selMonthNum, anchor);

  DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
  final todayMidnight = _midnight(now);

  // Normalize to grouped receipts: group by (category + date)
  String kOf(String category, DateTime d) =>
      '$category-${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, "0")}';

  final Map<String, Map<String, dynamic>> grouped = {};

  for (final raw in items) {
    final parsedDate = tryParseAnyDate(raw['date_of_purchase'] as String?);
    final category   = (raw['category'] as String?)?.trim().isNotEmpty == true
        ? raw['category'] as String
        : 'General';
    final itemName   = (raw['item_name'] ?? '').toString().trim();
    final unitPrice  = (raw['unit_price'] is num)
        ? (raw['unit_price'] as num).toDouble()
        : double.tryParse((raw['unit_price'] ?? '').toString());

    if (itemName.isEmpty || unitPrice == null) {
      log('Skipping expense due to missing item_name or unit_price: $raw');
      continue;
    }

    // Clamp date into selected period; otherwise pin to today
    DateTime purchaseDate = _midnight(parsedDate ?? now);
    if (purchaseDate.isBefore(periodStart) || !purchaseDate.isBefore(periodNext)) {
      purchaseDate = todayMidnight;
    }

    final key = kOf(category, purchaseDate);
    grouped.putIfAbsent(key, () => {
      'item_name': <String>[],
      'unit_price': <double>[],
      'date_of_purchase': Timestamp.fromDate(purchaseDate),
      'category': category,
      'userId': userId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'visibility': shared ? 'shared' : 'private',
      'source': 'mic',
    });

    (grouped[key]!['item_name'] as List<String>).add(itemName);
    (grouped[key]!['unit_price'] as List<double>).add(unitPrice);
  }

  if (grouped.isEmpty) {
    lastError.value = 'Nothing valid to save.';
    return 0;
  }

  final batch = FirebaseFirestore.instance.batch();
  final col = FirebaseFirestore.instance
      .collection('wallets').doc(wId).collection('receipts');

  grouped.forEach((_, data) {
    final ref = col.doc();
    batch.set(ref, data);
  });

  // --- 2) Safe commit: avoid app crash, show a clear error in UI ---
  try {
    await batch.commit();
  } on FirebaseException catch (e) {
    // Typical: permission-denied when wallet changed during write, or rules mismatch
    lastError.value = e.message ?? e.code;
    log('⚠️ saveParsedExpenses commit failed: ${e.code} ${e.message}');
    return 0;
  } catch (e) {
    lastError.value = 'Failed to save: $e';
    log('⚠️ saveParsedExpenses commit failed: $e');
    return 0;
  }

  final count = grouped.length;
  lastSuccess.value = 'Saved ${count} receipt${count == 1 ? '' : 's'} (${shared ? 'shared' : 'private'}).';
  lastError.value = '';

  // Optional cache bump
  final key = '${selectedMonth.value}-${selectedYear.value}';
  invalidationCounters[key] = (invalidationCounters[key] ?? 0) + 1;

  return count;
}

  // ============================================================
  // STREAMS for active receipts
  // ============================================================

  /// My expenses under /wallets/{wId}/receipts for the selected month
  /// (created by me; includes both 'private' & 'shared')
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyMonthInWallet({
    bool includeShared = false,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);

    if (uid == null || wId == null) return const Stream.empty();

    // Only attach if we *know* we’re a member (prevents permission-denied spam)
    final wc = Get.isRegistered<WalletController>()
        ? Get.find<WalletController>()
        : null;
    if (wc != null && (wc.joining.value || wc.isMember.value != true)) {
      return const Stream.empty(); // don’t attach while joining or not a member
    }

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;
    final anchor = budgetAnchorDay.value;

    final start =
        Timestamp.fromDate(startOfBudgetPeriod(year, monthNum, anchor));
    final nextStart =
        Timestamp.fromDate(nextStartOfBudgetPeriod(year, monthNum, anchor));

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('userId', isEqualTo: uid)
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThan: nextStart);

    // 👉 Only private by default; include shared if asked
    q = includeShared
        ? q.where('visibility', whereIn: ['private', 'shared'])
        : q.where('visibility', isEqualTo: 'private');

    return q
        .orderBy('date_of_purchase', descending: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .handleError((e, _) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        // Happens during wallet switch / membership change: safe to ignore.
        log('⚠️ myMonth stream permission-denied (expected during switch)');
      }
    });
  }

  /// Shared (all members) under /wallets/{wId}/receipts for the selected month.
  /// If [visibility] is provided, filter by it (e.g., 'shared').
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMonthForWallet({
    String? visibility,
  }) {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);
    if (wId == null) return const Stream.empty();

    // 🔒 Don’t attach while joining or if we’re not confirmed as a member
    final wc = Get.isRegistered<WalletController>()
        ? Get.find<WalletController>()
        : null;
    if (wc != null && (wc.joining.value || wc.isMember.value != true)) {
      return const Stream.empty();
    }

    final monthNum = monthFromString(selectedMonth.value);
    final year = selectedYear.value;
    final anchor = budgetAnchorDay.value;

    final start =
        Timestamp.fromDate(startOfBudgetPeriod(year, monthNum, anchor));
    final nextStart =
        Timestamp.fromDate(nextStartOfBudgetPeriod(year, monthNum, anchor));

    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('wallets')
        .doc(wId)
        .collection('receipts')
        .where('date_of_purchase', isGreaterThanOrEqualTo: start)
        .where('date_of_purchase', isLessThan: nextStart);

    if (visibility != null) {
      q = q.where('visibility', isEqualTo: visibility);
    } else {
      // Note: if you truly want "everything" here, this includes private docs (from any user),
      // which your rules will deny per-doc for others. Prefer passing visibility: 'shared'
      // for a clean shared feed.
      q = q.where('visibility', whereIn: ['private', 'shared']);
    }

    return q
        .orderBy('date_of_purchase', descending: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .handleError((e, _) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        log('⚠️ month stream permission-denied (expected during switch)');
      }
    });
  }

  Future<void> deleteReceipt(String docId) async {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (wId == null || uid == null) {
      lastError.value = 'Not ready to delete.';
      return;
    }
    try {
      final ref = FirebaseFirestore.instance
          .collection('wallets')
          .doc(wId)
          .collection('receipts')
          .doc(docId);

      // Defensive: ensure it's mine before deleting (client-side).
      final snap = await ref.get();
      if (snap.exists && snap.data()?['userId'] == uid) {
        await ref.delete();
        lastSuccess.value = 'Deleted.';
        // optional: bump cache key to force rebuild
        final key = '${selectedMonth.value}-${selectedYear.value}';
        invalidationCounters[key] = (invalidationCounters[key] ?? 0) + 1;
      } else {
        lastError.value = 'You can only delete your own receipt.';
      }
    } catch (e) {
      lastError.value = 'Delete failed. $e';
    }
  }

  /// Update a receipt (items/prices/category/date). Pass only the fields you changed.
  Future<void> editReceipt(
    String docId, {
    List<String>? items,
    List<double>? prices,
    String? category,
    DateTime? date,
  }) async {
    final wId = walletId.value ??
        (Get.isRegistered<WalletController>()
            ? Get.find<WalletController>().walletId.value
            : null);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (wId == null || uid == null) {
      lastError.value = 'Not ready to edit.';
      return;
    }

    try {
      final ref = FirebaseFirestore.instance
          .collection('wallets')
          .doc(wId)
          .collection('receipts')
          .doc(docId);

      // Defensive: verify ownership
      final snap = await ref.get();
      if (!snap.exists || snap.data()?['userId'] != uid) {
        lastError.value = 'You can only edit your own receipt.';
        return;
      }

      final update = <String, dynamic>{};
      if (items != null) update['item_name'] = items;
      if (prices != null) update['unit_price'] = prices;
      if (category != null) update['category'] = category;
      if (date != null) update['date_of_purchase'] = Timestamp.fromDate(date);
      if (update.isEmpty) return;

      update['updated_at'] = FieldValue.serverTimestamp();

      await ref.update(update);
      lastSuccess.value = 'Updated.';
      final key = '${selectedMonth.value}-${selectedYear.value}';
      invalidationCounters[key] = (invalidationCounters[key] ?? 0) + 1;
    } catch (e) {
      lastError.value = 'Update failed. $e';
    }
  }
}
