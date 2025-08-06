import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionListProvider extends ChangeNotifier {
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
  
   Future<List<DocumentSnapshot>> getSharedExpensesForMonth(
    String month,
    int year,
    String walletId,
    String? filterUserId,
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
    .where('walletId', isEqualTo: walletId);

  if (filterUserId != null) {
    query = query.where('userId', isEqualTo: filterUserId);
  }

  final snapshot = await query.get();
  print(
    '[DEBUG] Shared query returned ${snapshot.docs.length} docs '
    'for wallet=$walletId, filter=$filterUserId'
  );
  return snapshot.docs;
}

  Future<List<DocumentSnapshot>> getExpensesForMonth(String month, int year, String userId) async {
    int monthNumber = _monthFromString(month);

    final startOfMonth = DateTime.utc(year, monthNumber, 1);
    final endOfMonth = DateTime.utc(year, monthNumber + 1, 0).add(const Duration(hours: 23, minutes: 59, seconds: 59));

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('receipts')
        .where('date_of_purchase', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date_of_purchase', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs;
  }

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

  void initializeStream(BuildContext context, String userId, String? walletId, bool showWalletReceipts) {
    _setupStream(context, userId, walletId, showWalletReceipts);
  }

  void setUserFilter(String? userId, BuildContext context, String userUid, String? walletId, bool showWalletReceipts) {
    _selectedUserFilter = userId;
    _setupStream(context, userUid, walletId, showWalletReceipts);
    notifyListeners();
  }

  void removeDoc(String docId) {
    _allDocs.removeWhere((doc) => doc.id == docId);
    _queryCache.updateAll((key, value) => value..removeWhere((doc) => doc.id == docId));
    updateTotalByUserFromDocs(_allDocs);
    notifyListeners();
  }

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
            notifyListeners();
          },
        );
      } catch (e) {
        notifyListeners();
      }
    });
  }

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