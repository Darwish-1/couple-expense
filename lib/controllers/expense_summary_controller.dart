// lib/controllers/expense_summary_controller.dart
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_controller.dart';
import 'expenses_controller.dart';
import '../utils/date_utils_ext.dart';

/// Enhanced controller that handles both "my" and "shared" expense summaries
/// with improved caching and budget management
class ExpenseSummaryController extends GetxController {
  ExpenseSummaryController({
    required this.expensesTag,
    this.isSharedView = false,
  });

  /// Tag of the ExpensesController this summary follows ("my" or "shared")
  final String expensesTag;
  
  /// Whether this is for shared expenses view (affects filtering)
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
  String? _lastCachedMonth;

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

  @override
  void onInit() {
    super.onInit();
    log('📊 ExpenseSummaryController onInit - tag: $expensesTag, shared: $isSharedView');
    
    _expenses = Get.find<ExpensesController>(tag: expensesTag);
    _wallet = Get.find<WalletController>();

    // Initialize
    _bindTotals();
    _bindBudget();

    // React to month/year changes
    everAll([_expenses.selectedMonth, _expenses.selectedYear], (_) {
      _bindTotals();
      _bindBudget();
    });

    // React to wallet changes
    ever(_wallet.walletId, (_) {
      _bindTotals();
      _bindBudget();
    });
  }

  void _bindTotals() {
    log('📊 Binding totals for $expensesTag (shared: $isSharedView)');
    
    // Choose the right stream based on view type
    final stream = isSharedView 
        ? _expenses.streamMonthForWallet()  // All expenses in wallet
        : _expenses.streamMyMonthInWallet(); // Only current user's expenses

    final totalStream = stream.map((snapshot) {
      double sum = 0.0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final prices = (data['unit_price'] as List?)?.cast<num>() ?? <num>[];
        for (final price in prices) {
          sum += price.toDouble();
        }
      }
      log('📊 Calculated total for $expensesTag: $sum');
      return sum;
    });

    totalThisMonth.bindStream(totalStream);
  }

  void _bindBudget() async {
  final wId = _walletId;
  if (wId == null) { budgetThisMonth.value = 0.0; return; }

  final monthKey = this.monthKey;

  // local cache (scoped)
  await _loadBudgetFromCache(monthKey);

  // Firestore (scoped)
  final docRef = _budgetDoc(monthKey);
  budgetThisMonth.bindStream(docRef.snapshots().map((snap) {
    final amount = (snap.data()?['amount'] as num?)?.toDouble() ?? 0.0;
    _budgetCache[monthKey] = amount;
    return amount;
  }));
}

 Future<void> _loadBudgetFromCache(String monthKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getDouble('${_cachePrefix}_$monthKey');
    if (cached != null) {
      budgetThisMonth.value = cached;
      _budgetCache[monthKey] = cached;
    }
  } catch (_) {}
}

Future<void> _saveBudgetToCache(String monthKey, double amount) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('${_cachePrefix}_$monthKey', amount);
  } catch (_) {}
}

  /// Save or update the budget for the selected month
  Future<void> setBudget(double amount) async {
  budgetError.value = '';
  budgetInfo.value = '';
  isLoadingBudget.value = true;

  try {
    final auth = FirebaseAuth.instance.currentUser;
    final wId = _walletId;
    if (auth == null) { budgetError.value = 'You must be signed in.'; return; }
    if (wId == null) { budgetError.value = 'No wallet selected.'; return; }

    final monthKey = this.monthKey;
    final docRef = _budgetDoc(monthKey); // <- use scoped path

    await docRef.set({
      'amount': amount,
      'year': _expenses.selectedYear.value,
      'month': monthFromString(_expenses.selectedMonth.value),
      'wallet_id': wId,
      'scope': isSharedView ? 'shared' : 'user',
      if (!isSharedView) 'userId': FirebaseAuth.instance.currentUser!.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _budgetCache[monthKey] = amount;
    await _saveBudgetToCache(monthKey, amount);

    budgetInfo.value = 'Budget saved successfully!';
    Future.delayed(const Duration(seconds: 3), () => budgetInfo.value = '');
    log('📊 Budget saved: $amount for $monthKey');
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

  /// Get budget for a specific month (useful for analytics)
  Future<double> getBudgetForMonth(String monthKey) async {
    final wId = _walletId;
    if (wId == null) return 0.0;

    // Check cache first
    if (_budgetCache.containsKey(monthKey)) {
      return _budgetCache[monthKey]!;
    }

final doc = await _budgetDoc(monthKey).get();
final amount = (doc.data()?['amount'] as num?)?.toDouble() ?? 0.0;
_budgetCache[monthKey] = amount;
return amount;
  }

  /// Clear local budget cache (useful for debugging or manual refresh)
Future<void> clearBudgetCache() async {
  _budgetCache.clear();
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
  for (final k in keys) { await prefs.remove(k); }
}

  /// Get spending analytics for the current month
  Map<String, dynamic> getMonthlyAnalytics() {
    final total = totalThisMonth.value;
    final budget = budgetThisMonth.value;
    final remaining = this.remaining;
    final progress = this.progress;
    
    return {
      'total_spent': total,
      'budget': budget,
      'remaining': remaining,
      'progress_percentage': (progress * 100).round(),
      'is_over_budget': remaining < 0,
      'days_left_in_month': _daysLeftInMonth(),
      'daily_budget_remaining': remaining > 0 && _daysLeftInMonth() > 0 
          ? remaining / _daysLeftInMonth() 
          : 0.0,
    };
  }

  int _daysLeftInMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return lastDay.day - now.day + 1;
  }

  @override
  void onClose() {
    // Clean up if needed
    super.onClose();
  }

  String get _cachePrefix {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return isSharedView ? 'budget_shared' : 'budget_user_$uid';
}

DocumentReference<Map<String, dynamic>> _budgetDoc(String monthKey) {
  final wId = _walletId!;
  final base = FirebaseFirestore.instance.collection('wallets').doc(wId);
  if (isSharedView) {
    // one shared budget per wallet per month
    return base.collection('budgets_shared').doc(monthKey);
  } else {
    // personal budget per user per month
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return base.collection('budgets_user').doc(uid).collection('months').doc(monthKey);
  }
}
}
