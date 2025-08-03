import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionListProvider extends ChangeNotifier {
  // Transaction list fields
  Stream<QuerySnapshot>? _expensesStream;
  List<DocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Map<String, List<DocumentSnapshot>> _queryCache = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _debounceTimer;
  final int _documentsPerPage = 20;
  String? _currentStreamKey;
  String? _selectedUserFilter;
  Map<String, double> _totalByUser = {};

  // Public getters
  List<DocumentSnapshot> get allDocs => _allDocs;
  
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get selectedUserFilter => _selectedUserFilter;
  Map<String, double> get totalByUser => _totalByUser;
String? lastAddedId;

void setLastAddedId(String? id) {
  lastAddedId = id;
  notifyListeners();
}
  /// Initialize the transaction list stream
  void initializeStream(BuildContext context, String userId, String? walletId, bool showWalletReceipts) {
    print('initializeStream called!');

    _setupStream(context, userId, walletId, showWalletReceipts);
  }

  /// Set filter for user
  void setUserFilter(String? userId, BuildContext context, String userUid, String? walletId, bool showWalletReceipts) {
    _selectedUserFilter = userId;
    _setupStream(context, userUid, walletId, showWalletReceipts);
    notifyListeners();
  }

  /// Remove a document from the transaction list and update totals
  void removeDoc(String docId) {
    _allDocs.removeWhere((doc) => doc.id == docId);
    _queryCache.updateAll((key, value) => value..removeWhere((doc) => doc.id == docId));
    updateTotalByUserFromDocs(_allDocs);
    notifyListeners();
  }

  /// Setup stream for fetching transactions
  void _setupStream(BuildContext context, String userId, String? walletId, bool showWalletReceipts) {
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

      final cacheKey = newStreamKey;
      if (_queryCache.containsKey(cacheKey) && _queryCache[cacheKey]!.isNotEmpty) {
        _allDocs = List.from(_queryCache[cacheKey]!);
        _lastDocument = _allDocs.isNotEmpty ? _allDocs.last : null;
        _hasMore = _allDocs.length == _documentsPerPage;
        updateTotalByUserFromDocs(_allDocs);
        notifyListeners();
        return;
      }

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
            _queryCache[cacheKey] = List.from(_allDocs);
            updateTotalByUserFromDocs(_allDocs);
            notifyListeners();
          },
          onError: (e) {
            // handle error (maybe call a callback or notify error state)
            notifyListeners();
          },
        );
      } catch (e) {
        // handle error (maybe call a callback or notify error state)
        notifyListeners();
      }
    });
  }

  /// Load more transactions for pagination
  Future<void> loadMoreExpenses(BuildContext context, String userId, String? walletId, bool showWalletReceipts) async {
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
        // handle error
        notifyListeners();
      } finally {
        _isLoadingMore = false;
        notifyListeners();
      }
    });
  }

  /// Update user totals from the list of transactions (docs)
  void updateTotalByUserFromDocs(List<DocumentSnapshot> docs) {
    _totalByUser.clear();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'];
      final amount = (data['amount'] ?? 0).toDouble();
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
