import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionListProvider extends ChangeNotifier {
  // Permanent cache that holds all transactions by cache key
  final Map<String, List<DocumentSnapshot>> _permanentCache = {};
  
  // Track loading states for each cache key
  final Map<String, bool> _loadingStates = {};
  
  // Cache for monthly totals: {cacheKey: Map<String, double>}
  final Map<String, Map<String, double>> _totalsByUserCache = {};
  
  // Stream management
  Stream<QuerySnapshot>? _expensesStream;
  List<DocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _debounceTimer;
  final int _documentsPerPage = 20;
  String? _currentStreamKey;
  String? _selectedUserFilter;
  Map<String, double> _totalByUser = {};
  String? lastAddedId;
 int _refreshTrigger = 0;




  int get refreshTrigger => _refreshTrigger;
    void triggerRefresh() {
    _refreshTrigger++;
    print('🔄 [DEBUG] triggerRefresh called - new value: $_refreshTrigger');
    notifyListeners();
    print('🔄 [DEBUG] notifyListeners called after triggerRefresh');
  }

  // Getters
  List<DocumentSnapshot> get allDocs => _allDocs;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get selectedUserFilter => _selectedUserFilter;
  Map<String, double> get totalByUser => _totalByUser;

  void setLastAddedId(String? id) {
    lastAddedId = id;
    notifyListeners();
  }



void addNewDocumentsToCache(List<Map<String, dynamic>> newExpenseData, String month, int year) {
    // Convert the expense data to mock DocumentSnapshots for immediate display
    // This is a temporary solution until Firestore sync happens
    
    for (var expenseData in newExpenseData) {
      // Find all relevant cache keys that should show this expense
      for (var cacheKey in _permanentCache.keys.toList()) {
        final parts = cacheKey.split('-');
        if (parts.length != 6) continue;
        
        final cacheMonth = parts[4];
        final cacheYear = int.tryParse(parts[5]);
        
        // Only add to caches for the current month/year
        if (cacheMonth.toLowerCase() == month.toLowerCase() && cacheYear == year) {
          // Create a temporary document ID for immediate display
          final tempDocId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
          
          // Add the expense data with Firestore-like structure
          final docData = Map<String, dynamic>.from(expenseData);
          
          // Create a mock DocumentSnapshot (simplified)
          // In a real implementation, you might want to create a proper mock
          // For now, we'll add to a separate "pending" list
          
          // Add to beginning of cache (newest first)
          // Note: This is simplified - you'd need proper DocumentSnapshot mocking
        }
      }
    }
    
    notifyListeners();
  }









  int _monthFromString(String month) {
    const months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return months[month.toLowerCase()] ?? DateTime.now().month;
  }

  // Get transactions for a specific cache key (always returns a list, never null)
  List<DocumentSnapshot> getTransactionsForCache(String cacheKey) {
    return _permanentCache[cacheKey] ?? [];
  }

  // Check if a cache key is currently loading
  bool isLoadingCache(String cacheKey) {
    return _loadingStates[cacheKey] ?? false;
  }

  // Ensure transactions are loaded for a specific month/filter combination
 Future<void> ensureMonthlyTransactionsLoaded({
    required String cacheKey,
    required String month,
    required int year,
    required String userId,
    required bool showShared,
    String? walletId,
    String? filterUserId,
    bool forceReload = false,
  }) async {
    print('📚 [DEBUG] ensureMonthlyTransactionsLoaded called');
    print('📚 [DEBUG] cacheKey: $cacheKey');
    print('📚 [DEBUG] forceReload: $forceReload');
    print('📚 [DEBUG] Current cache has data: ${_permanentCache.containsKey(cacheKey) && _permanentCache[cacheKey]!.isNotEmpty}');
    print('📚 [DEBUG] Currently loading: ${_loadingStates[cacheKey] == true}');
    
    // If we already have data for this cache key and not forcing reload, don't reload
    if (!forceReload && _permanentCache.containsKey(cacheKey) && _permanentCache[cacheKey]!.isNotEmpty) {
      print('📚 [DEBUG] Skipping load - cache exists and not forcing reload');
      return;
    }

    // If we're already loading this cache, don't start another load
    if (_loadingStates[cacheKey] == true) {
      print('📚 [DEBUG] Skipping load - already loading');
      return;
    }

    print('📚 [DEBUG] Starting to load data...');
    _loadingStates[cacheKey] = true;
    notifyListeners();

    try {
      List<DocumentSnapshot> docs;
      
      if (showShared && walletId != null) {
        print('📚 [DEBUG] Fetching shared expenses for walletId: $walletId, filterUserId: $filterUserId');
        docs = await _fetchSharedExpensesForMonth(month, year, walletId, filterUserId);
      } else {
        print('📚 [DEBUG] Fetching personal expenses for userId: $userId');
        docs = await _fetchExpensesForMonth(month, year, userId);
      }

      print('📚 [DEBUG] Fetched ${docs.length} documents');
      _permanentCache[cacheKey] = docs;
      _calculateAndCacheTotals(cacheKey, docs);
      
      print('📚 [DEBUG] ${forceReload ? 'Force reloaded' : 'Loaded'} ${docs.length} transactions for cache key: $cacheKey');
    } catch (e) {
      print('📚 [DEBUG] Error loading transactions for $cacheKey: $e');
      _permanentCache[cacheKey] = [];
    }

    _loadingStates[cacheKey] = false;
    print('📚 [DEBUG] Loading complete, calling notifyListeners');
    notifyListeners();
  }
  // Force refresh a specific cache (used after edits)
  Future<void> refreshCache(String cacheKey) async {
    // Parse cache key to get the parameters
    final parts = cacheKey.split('-');
    if (parts.length != 6) return;

    final userId = parts[0];
    final type = parts[1]; // 'shared' or 'personal'
    final walletId = parts[2] != 'nowallet' ? parts[2] : null;
    final filterUserId = parts[3] != 'nofilter' ? parts[3] : null;
    final month = parts[4];
    final year = int.tryParse(parts[5]);

    if (year == null) return;

    _loadingStates[cacheKey] = true;
    
    try {
      List<DocumentSnapshot> docs;
      
      if (type == 'shared' && walletId != null) {
        docs = await _fetchSharedExpensesForMonth(month, year, walletId, filterUserId);
      } else {
        docs = await _fetchExpensesForMonth(month, year, userId);
      }

      _permanentCache[cacheKey] = docs;
      _calculateAndCacheTotals(cacheKey, docs);
      
      print('[CACHE] Refreshed ${docs.length} transactions for cache key: $cacheKey');
    } catch (e) {
      print('[CACHE] Error refreshing cache $cacheKey: $e');
    }

    _loadingStates[cacheKey] = false;
    notifyListeners();
  }
Future<List<DocumentSnapshot>> fetchSharedSummaryForMonth(
  String month,
  int year,
  String walletId,
) async {
  // simply defer to the private method with no filter
  return _fetchSharedExpensesForMonth(month, year, walletId, null);
}

Future<List<DocumentSnapshot>> _fetchSharedExpensesForMonth(
  String month,
  int year,
  String walletId,
  String? filterUserId,   // ← new, nullable parameter
) async {
  final monthNumber = _monthFromString(month);
  final startOfMonth = DateTime.utc(year, monthNumber, 1);
  final endOfMonth = DateTime.utc(year, monthNumber + 1, 0)
      .add(const Duration(hours: 23, minutes: 59, seconds: 59));

  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('receipts')
      .where('date_of_purchase',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date_of_purchase',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
      .where('walletId', isEqualTo: walletId)
      .orderBy('date_of_purchase', descending: true)
      .orderBy('created_at', descending: true);

  // **Only one** filter block is needed:
  if (filterUserId != null) {
    query = query.where('userId', isEqualTo: filterUserId);
  }

  final snapshot = await query.get();
  return snapshot.docs;
}

  Future<List<DocumentSnapshot>> _fetchExpensesForMonth(
    String month,
    int year,
    String userId,
  ) async {
    final monthNumber = _monthFromString(month);
    final startOfMonth = DateTime.utc(year, monthNumber, 1);
    final endOfMonth = DateTime.utc(year, monthNumber + 1, 0)
        .add(const Duration(hours: 23, minutes: 59, seconds: 59));

    QuerySnapshot snapshot = await FirebaseFirestore.instance
      .collection('receipts')
      .where('date_of_purchase',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
      .where('date_of_purchase',
          isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
      .where('userId', isEqualTo: userId)
      .orderBy('date_of_purchase', descending: true)
      .orderBy('created_at', descending: true)
      .get();

    return snapshot.docs;
  }

  void _calculateAndCacheTotals(String cacheKey, List<DocumentSnapshot> docs) {
    final totals = <String, double>{};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?;
      if (userId != null) {
        final prices = data['unit_price'];
        double amount = 0.0;
        
        if (prices is List) {
          amount = prices.fold(0.0, (sum, price) => 
            sum + (price is num ? price.toDouble() : 0.0));
        } else if (prices is num) {
          amount = prices.toDouble();
        } else if (data.containsKey('amount') && data['amount'] is num) {
          amount = (data['amount'] as num).toDouble();
        }
        
        totals[userId] = (totals[userId] ?? 0) + amount;
      }
    }
    _totalsByUserCache[cacheKey] = totals;
  }

  Map<String, double> getCachedTotals(String cacheKey) {
    return _totalsByUserCache[cacheKey] ?? {};
  }

  // Add a new document to the appropriate caches
  void addDocToCache(DocumentSnapshot doc, String month, int year) {
    final data = doc.data() as Map<String, dynamic>;
    final docUserId = data['userId'] as String?;
    final docWalletId = data['walletId'] as String?;
    
    if (docUserId == null) return;

    // Find all cache keys that should include this document
    final keysToUpdate = <String>[];
    
    for (final cacheKey in _permanentCache.keys) {
      if (_shouldDocumentBeInCache(doc, cacheKey, month, year)) {
        keysToUpdate.add(cacheKey);
      }
    }
    
    // Add document to all relevant caches
    for (final key in keysToUpdate) {
      _permanentCache[key]!.insert(0, doc); // Add at beginning (most recent first)
      _calculateAndCacheTotals(key, _permanentCache[key]!);
    }
    
    if (keysToUpdate.isNotEmpty) {
      print('[CACHE] Added new document to ${keysToUpdate.length} cache(s)');
      notifyListeners();
    }
  }

  // Remove a document from all caches
  void removeDocFromCache(String docId, String cacheKey) {
    // Remove from specific cache
    if (_permanentCache.containsKey(cacheKey)) {
      final originalLength = _permanentCache[cacheKey]!.length;
      _permanentCache[cacheKey]!.removeWhere((doc) => doc.id == docId);
      
      if (_permanentCache[cacheKey]!.length < originalLength) {
        _calculateAndCacheTotals(cacheKey, _permanentCache[cacheKey]!);
        print('[CACHE] Removed doc $docId from cache $cacheKey');
      }
    }
    
    // Also remove from all other caches that might contain this document
    for (final key in _permanentCache.keys) {
      if (key != cacheKey) {
        final originalLength = _permanentCache[key]!.length;
        _permanentCache[key]!.removeWhere((doc) => doc.id == docId);
        
        if (_permanentCache[key]!.length < originalLength) {
          _calculateAndCacheTotals(key, _permanentCache[key]!);
        }
      }
    }
    
    // Remove from stream docs too
    _allDocs.removeWhere((doc) => doc.id == docId);
    updateTotalByUserFromDocs(_allDocs);
    
    notifyListeners();
  }

  bool _shouldDocumentBeInCache(DocumentSnapshot doc, String cacheKey, String month, int year) {
    final data = doc.data() as Map<String, dynamic>;
    final parts = cacheKey.split('-');
    
    if (parts.length != 6) return false;
    
    final cacheUserId = parts[0];
    final cacheType = parts[1]; // 'shared' or 'personal'
    final cacheWalletId = parts[2];
    final cacheFilterUserId = parts[3];
    final cacheMonth = parts[4];
    final cacheYear = int.tryParse(parts[5]);
    
    // Check month and year match
    if (cacheMonth != month || cacheYear != year) return false;
    
    // Check document matches cache criteria
    if (cacheType == 'shared') {
      if (cacheWalletId != 'nowallet' && data['walletId'] != cacheWalletId) return false;
      if (cacheFilterUserId != 'nofilter' && data['userId'] != cacheFilterUserId) return false;
    } else {
      if (data['userId'] != cacheUserId) return false;
    }
    
    return true;
  }

  void setUserFilter(String? userId, BuildContext context, String userUid, 
      String? walletId, bool showWalletReceipts) {
    _selectedUserFilter = userId;
    _setupStream(context, userUid, walletId, showWalletReceipts);
    notifyListeners();
  }

  void removeDoc(String docId) {
    // Remove from current stream docs
    _allDocs.removeWhere((doc) => doc.id == docId);
    
    // Remove from all permanent caches
    for (final key in _permanentCache.keys) {
      final originalLength = _permanentCache[key]!.length;
      _permanentCache[key]!.removeWhere((doc) => doc.id == docId);
      if (_permanentCache[key]!.length < originalLength) {
        _calculateAndCacheTotals(key, _permanentCache[key]!);
      }
    }
    
    updateTotalByUserFromDocs(_allDocs);
    notifyListeners();
    print('[CACHE] Removed doc $docId from all caches');
  }

  void invalidateCache({String? specificKey}) {
    if (specificKey != null) {
      _permanentCache.remove(specificKey);
      _totalsByUserCache.remove(specificKey);
      _loadingStates.remove(specificKey);
      print('[CACHE] Invalidated specific cache: $specificKey');
    } else {
      _permanentCache.clear();
      _totalsByUserCache.clear();
      _loadingStates.clear();
      print('[CACHE] Invalidated all cache');
    }
    
    notifyListeners();
  }


void debugCacheState() {
    print('🔍 [DEBUG] === CACHE STATE DEBUG ===');
    print('🔍 [DEBUG] Total cache keys: ${_permanentCache.length}');
    print('🔍 [DEBUG] Refresh trigger: $_refreshTrigger');
    
    for (var key in _permanentCache.keys) {
      final itemCount = _permanentCache[key]?.length ?? 0;
      final isLoading = _loadingStates[key] ?? false;
      print('🔍 [DEBUG] Cache key: $key');
      print('🔍 [DEBUG] - Items: $itemCount');
      print('🔍 [DEBUG] - Loading: $isLoading');
    }
    print('🔍 [DEBUG] === END CACHE STATE DEBUG ===');
  }



void invalidateCacheForMonth(String month, int year) {
  // convert both numeric and name into the same format:
  final monthNumber = int.tryParse(month) ?? _monthFromString(month);
  final targetMonth = monthNumber.toString();

  final keysToRemove = _permanentCache.keys.where((key) {
    final parts     = key.split('-');
    final cacheMonth = parts[4];               // e.g. "8"
    final cacheYear  = int.tryParse(parts[5]);
    return cacheMonth == targetMonth && cacheYear == year;
  }).toList();

  for (final k in keysToRemove) {
    _permanentCache.remove(k);
    _totalsByUserCache.remove(k);
    _loadingStates.remove(k);
  }

  triggerRefresh();
}

  // Compatibility methods for existing stream functionality
  void initializeStream(BuildContext context, String userId, String? walletId, 
      bool showWalletReceipts) {
    _setupStream(context, userId, walletId, showWalletReceipts);
  }

  void _setupStream(BuildContext context, String userId, String? walletId, 
      bool showWalletReceipts) {
    final newStreamKey = '${showWalletReceipts}_${walletId}_${_selectedUserFilter ?? "all"}';
    if (_currentStreamKey == newStreamKey && _streamSubscription != null) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _allDocs.clear();
      _lastDocument = null;
      _hasMore = true;
      _totalByUser.clear();
      _isLoadingMore = false;
      _currentStreamKey = newStreamKey;
      notifyListeners();

      Query<Map<String, dynamic>> baseQuery = FirebaseFirestore.instance
          .collection('receipts')
          .orderBy('created_at', descending: true);

      if (showWalletReceipts && walletId != null) {
        baseQuery = baseQuery.where('walletId', isEqualTo: walletId);
        if (_selectedUserFilter != null) {
          baseQuery = baseQuery.where('userId', isEqualTo: _selectedUserFilter);
        }
      } else {
        baseQuery = baseQuery.where('userId', isEqualTo: userId);
      }

      try {
        _expensesStream = baseQuery.limit(_documentsPerPage).snapshots();
        _streamSubscription?.cancel();
        _streamSubscription = _expensesStream!.listen(
          (snapshot) {
            _allDocs = snapshot.docs;
            _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
            _hasMore = snapshot.docs.length == _documentsPerPage;
            updateTotalByUserFromDocs(_allDocs);
            notifyListeners();
          },
          onError: (e) {
            print('[CACHE] Stream error: $e');
            notifyListeners();
          },
        );
      } catch (e) {
        print('[CACHE] Setup stream error: $e');
        notifyListeners();
      }
    });
  }

  Future<void> loadMoreExpenses(BuildContext context, String userId, 
      String? walletId, bool showWalletReceipts) async {
    if (!_hasMore || _isLoadingMore) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _isLoadingMore = true;
      notifyListeners();

      Query<Map<String, dynamic>> baseQuery;

      if (showWalletReceipts && walletId != null) {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('walletId', isEqualTo: walletId);
        if (_selectedUserFilter != null) {
          baseQuery = baseQuery.where('userId', isEqualTo: _selectedUserFilter);
        }
      } else {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('userId', isEqualTo: userId);
      }

      if (_lastDocument != null) {
        baseQuery = baseQuery
            .orderBy('created_at', descending: true)
            .startAfterDocument(_lastDocument!)
            .limit(_documentsPerPage);
      } else {
        baseQuery = baseQuery
            .orderBy('created_at', descending: true)
            .limit(_documentsPerPage);
      }

      try {
        final snapshot = await baseQuery.get();
        if (snapshot.docs.isNotEmpty) {
          _allDocs.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _documentsPerPage;
          updateTotalByUserFromDocs(_allDocs);
        } else {
          _hasMore = false;
        }
        notifyListeners();
      } catch (e) {
        print('[CACHE] Load more error: $e');
        notifyListeners();
      } finally {
        _isLoadingMore = false;
        notifyListeners();
      }
    });
  }

  void updateTotalByUserFromDocs(List<DocumentSnapshot> docs) {
    _totalByUser.clear();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'];
      
      final prices = data['unit_price'];
      double amount = 0.0;
      
      if (prices is List) {
        amount = prices.fold(0.0, (sum, price) => 
          sum + (price is num ? price.toDouble() : 0.0));
      } else if (prices is num) {
        amount = prices.toDouble();
      } else if (data.containsKey('amount') && data['amount'] is num) {
        amount = (data['amount'] as num).toDouble();
      }
      
      if (userId != null) {
        _totalByUser[userId] = (_totalByUser[userId] ?? 0) + amount;
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  
}