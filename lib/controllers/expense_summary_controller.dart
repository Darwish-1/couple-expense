import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_controller.dart';
import 'expenses_controller.dart';
import '../utils/date_utils_ext.dart';

/// Handles both "my" and "shared" summaries.
/// Uses the same rolling period as ExpensesController:
/// [startOfBudgetPeriod(year, month, anchor) .. nextStartOfBudgetPeriod)
class ExpenseSummaryController extends GetxController {
  ExpenseSummaryController({
    required this.expensesTag,
    this.isSharedView = false,
  });

  /// Tag of the ExpensesController this summary follows ("my" or "shared")
  final String expensesTag;

  /// Whether this is for shared expenses view (affects budget scope path)
  final bool isSharedView;

  late final ExpensesController _expenses;
  late final WalletController _wallet;

  // Reactive state
  final RxDouble totalThisMonth = 0.0.obs;
  final RxDouble budgetThisMonth = 0.0.obs;
  final RxString budgetError = ''.obs;
  final RxString budgetInfo = ''.obs;
  final RxBool isLoadingBudget = false.obs;

  // Cache for budget values (reduces Firestore reads)
  final Map<String, double> _budgetCache = {};

  double get remaining => (budgetThisMonth.value - totalThisMonth.value);
  double get progress => budgetThisMonth.value <= 0
      ? 0
      : (totalThisMonth.value / budgetThisMonth.value).clamp(0.0, 1.0);

  String get monthKey {
    final m = monthFromString(_expenses.selectedMonth.value);
    final y = _expenses.selectedYear.value;
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}';
  }

  String? get _walletId => _wallet.walletId.value;

  bool get _canAttach =>
      _wallet.walletId.value != null &&
      _wallet.isMember.value == true &&
      _wallet.joining.value == false &&
      FirebaseAuth.instance.currentUser != null;

  @override
  void onInit() {
    super.onInit();
    log('📊 ExpenseSummaryController onInit - tag: $expensesTag, shared: $isSharedView');
    _expenses = Get.find<ExpensesController>(tag: expensesTag);
    _wallet = Get.find<WalletController>();

    // Initial binds
    _bindTotals();
    _bindBudget();

    // Re-bind when ANY relevant state changes (wallet, membership, period)
    everAll(
      [
        _wallet.walletId,
        _wallet.isMember,
        _wallet.joining,
        _expenses.selectedMonth,
        _expenses.selectedYear,
        _expenses.budgetAnchorDay,
      ],
      (_) {
        _bindTotals();
        _bindBudget();
      },
    );
  }

  // ---------- Totals ----------

  void _bindTotals() {
    log('📊 Binding totals for $expensesTag (shared: $isSharedView)');

    if (!_canAttach) {
      // Detach by binding to an empty stream and show 0 while switching/blocked.
      totalThisMonth.value = 0.0;
      totalThisMonth.bindStream(const Stream<double>.empty());
      return;
    }

    // Choose the right stream based on view type
    final sourceStream = isSharedView
        ? _expenses.streamMonthForWallet(visibility: 'shared')
        : _expenses.streamMyMonthInWallet(includeShared: false); // private only

    // Map to a sum, and guard errors (permission-denied during transitions)
    final totalStream = sourceStream
        .map((snapshot) {
          double sum = 0.0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final pricesAny = data['unit_price'];
            if (pricesAny is List) {
              for (final n in pricesAny.cast<num>()) {
                sum += n.toDouble();
              }
            } else if (pricesAny is num) {
              sum += pricesAny.toDouble();
            }
          }
          log('📊 Calculated total for $expensesTag: $sum');
          return sum;
        })
        .handleError((e, _) {
          if (e is FirebaseException && e.code == 'permission-denied') {
            log('⚠️ totals stream permission-denied (expected during switch)');
            return;
          }
          log('🔥 totals stream error: $e');
        });

    totalThisMonth.bindStream(totalStream);
  }

  // ---------- Budget ----------

  void _bindBudget() async {
    final mk = monthKey;

    // Load cached value immediately for snappy UI
    await _loadBudgetFromCache(mk);

    if (!_canAttach) {
      // Stop listening while we don’t have permission
      budgetThisMonth.bindStream(const Stream<double>.empty());
      return;
    }

    final docRef = _budgetDoc(mk);

    budgetThisMonth.bindStream(
      docRef.snapshots().map((snap) {
        final amount = (snap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
        _budgetCache[mk] = amount;
        // fire-and-forget local cache write
        _saveBudgetToCache(mk, amount);
        return amount;
      }).handleError((e, _) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          log('⚠️ budget stream permission-denied (expected during switch)');
          return;
        }
        final msg = e is FirebaseException ? (e.message ?? e.code) : e.toString();
        budgetError.value = msg;
        log('🔥 budget stream error: $msg');
      }),
    );
  }

  Future<void> _loadBudgetFromCache(String mk) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getDouble('${_cachePrefix}_$mk');
      if (cached != null) {
        budgetThisMonth.value = cached;
        _budgetCache[mk] = cached;
      }
    } catch (_) {}
  }

  Future<void> _saveBudgetToCache(String mk, double amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('${_cachePrefix}_$mk', amount);
    } catch (_) {}
  }

  /// Save or update the budget for the selected (label) month
  Future<void> setBudget(double amount) async {
    budgetError.value = '';
    budgetInfo.value = '';
    isLoadingBudget.value = true;

    try {
      final auth = FirebaseAuth.instance.currentUser;
      final wId = _walletId;
      if (auth == null) {
        budgetError.value = 'You must be signed in.';
        return;
      }
      if (wId == null) {
        budgetError.value = 'No wallet selected.';
        return;
      }

      final mk = monthKey;
      final docRef = _budgetDoc(mk); // scoped path

      await docRef.set({
        'amount': amount,
        'year': _expenses.selectedYear.value,
        'month': monthFromString(_expenses.selectedMonth.value),
        'wallet_id': wId,
        'scope': isSharedView ? 'shared' : 'user',
        if (!isSharedView) 'userId': FirebaseAuth.instance.currentUser!.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _budgetCache[mk] = amount;
      await _saveBudgetToCache(mk, amount);

      budgetInfo.value = 'Budget saved successfully!';
      Future.delayed(const Duration(seconds: 3), () => budgetInfo.value = '');
      log('📊 Budget saved: $amount for $mk');
    } on FirebaseException catch (e) {
      budgetError.value = e.message ?? 'Failed to save budget.';
      log('📊 Firebase error saving budget: ${e.message}');
    } catch (e) {
      budgetError.value = 'Failed to save budget: $e';
      log('📊 Error saving budget: $e');
    } finally {
      isLoadingBudget.value = false;
    }
  }

  /// Get budget for a specific month key (e.g. "2025-08")
  Future<double> getBudgetForMonth(String mk) async {
    final wId = _walletId;
    if (wId == null) return 0.0;

    // Check cache first
    if (_budgetCache.containsKey(mk)) {
      return _budgetCache[mk]!;
    }

    final doc = await _budgetDoc(mk).get();
    final amount = (doc.data()?['amount'] as num?)?.toDouble() ?? 0.0;
    _budgetCache[mk] = amount;
    return amount;
  }

  /// Clear local budget cache (useful for debugging or manual refresh)
  Future<void> clearBudgetCache() async {
    _budgetCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  /// Analytics derived from the *selected* period
  Map<String, dynamic> getMonthlyAnalytics() {
    final total = totalThisMonth.value;
    final budget = budgetThisMonth.value;
    final remaining = this.remaining;
    final progress = this.progress;

    final m = monthFromString(_expenses.selectedMonth.value);
    final y = _expenses.selectedYear.value;
    final anchor = _expenses.budgetAnchorDay.value;
    final start = startOfBudgetPeriod(y, m, anchor);
    final nextStart = nextStartOfBudgetPeriod(y, m, anchor);

    final now = DateTime.now();
    int daysLeft;
    if (now.isBefore(start)) {
      // selected period is in the future
      daysLeft = nextStart.difference(start).inDays;
    } else if (now.isAfter(nextStart)) {
      // selected period is past
      daysLeft = 0;
    } else {
      daysLeft = nextStart.difference(now).inDays; // remaining whole days
      if (daysLeft < 0) daysLeft = 0;
    }

    return {
      'total_spent': total,
      'budget': budget,
      'remaining': remaining,
      'progress_percentage': (progress * 100).round(),
      'is_over_budget': remaining < 0,
      'days_left_in_period': daysLeft,
      'daily_budget_remaining':
          remaining > 0 && daysLeft > 0 ? remaining / daysLeft : 0.0,
    };
  }

  String get _cachePrefix {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    return isSharedView ? 'budget_shared' : 'budget_user_$uid';
  }

  DocumentReference<Map<String, dynamic>> _budgetDoc(String mk) {
    final wId = _walletId!;
    final base = FirebaseFirestore.instance.collection('wallets').doc(wId);
    if (isSharedView) {
      // one shared budget per wallet per month
      return base.collection('budgets_shared').doc(mk);
    } else {
      // personal budget per user per month
      final uid = FirebaseAuth.instance.currentUser!.uid;
      return base
          .collection('budgets_user')
          .doc(uid)
          .collection('months')
          .doc(mk);
    }
  }
}
