import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/wallet_provider.dart';
import 'package:couple_expenses/services/gpt_parser.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class HomeScreenProvider extends ChangeNotifier {
  AudioRecorder? _recorder;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isLoadingStream = false;
  String _transcription = '';
  String _searchQuery = '';
  bool _showWalletReceipts = false;
  bool _showSuccessPopup = false;
  int _savedExpensesCount = 0;
  final TextEditingController _walletIdController = TextEditingController();
  List<DocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Map<String, List<DocumentSnapshot>> _queryCache = {};
  Map<String, String> _userNameCache = {};
  Map<String, double> _totalByUser = {};
  String? _currentStreamKey;
  String? _selectedUserFilter;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _debounceTimer;
  final int _documentsPerPage = 20;

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isLoadingStream => _isLoadingStream;
  bool get showSuccessPopup => _showSuccessPopup;
  int get savedExpensesCount => _savedExpensesCount;
  String get transcription => _transcription;
  String get searchQuery => _searchQuery;
  bool get showWalletReceipts => _showWalletReceipts;
  TextEditingController get walletIdController => _walletIdController;
  List<DocumentSnapshot> get allDocs => _allDocs;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
  String? get selectedUserFilter => _selectedUserFilter;
  Map<String, double> get totalByUser => _totalByUser;

  void initializeStream(BuildContext context, String userId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, userId, authProvider.walletId);
  }

  void setUserFilter(String? userId, BuildContext context) {
    _selectedUserFilter = userId;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, authProvider.user!.uid, authProvider.walletId);
    notifyListeners();
  }

  void setIsProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void showSuccess(int count) {
    _savedExpensesCount = count;
    _showSuccessPopup = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 3), () {
      hideSuccess();
    });
  }

  void hideSuccess() {
    if (_showSuccessPopup) {
      _showSuccessPopup = false;
      _savedExpensesCount = 0;
      notifyListeners();
    }
  }

  void removeDoc(String docId) {
    _allDocs.removeWhere((doc) => doc.id == docId);
    _queryCache.updateAll((key, value) => value..removeWhere((doc) => doc.id == docId));
    updateTotalByUserFromDocs(_allDocs);
    notifyListeners();
  }

  Future<String> fetchUserDisplayName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        final name = currentUser.displayName ?? currentUser.email?.split('@').first ?? 'Unknown';
        final firstName = name.split(' ').first.trim();
        final capitalizedFirstName = firstName.isEmpty
            ? 'Unknown'
            : '${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}';
        _userNameCache[userId] = capitalizedFirstName;
        return capitalizedFirstName;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final data = userDoc.data();
      String name;
      if (data != null && data.containsKey('name') && data['name'] != null) {
        name = data['name'] as String;
      } else if (data != null && data.containsKey('email') && data['email'] != null) {
        name = (data['email'] as String).split('@').first;
      } else {
        name = 'Unknown';
      }
      final firstName = name.split(' ').first.trim();
      final capitalizedFirstName = firstName.isEmpty
          ? 'Unknown'
          : '${firstName[0].toUpperCase()}${firstName.substring(1).toLowerCase()}';
      _userNameCache[userId] = capitalizedFirstName;
      return capitalizedFirstName;
    } catch (e) {
      debugPrint('Fetch user name error for $userId: $e');
      _userNameCache[userId] = 'Unknown';
      return 'Unknown';
    }
  }

  void _setupStream(BuildContext context, String userId, String? walletId) async {
    final newStreamKey = '${_showWalletReceipts}_${walletId}_${_selectedUserFilter ?? "all"}';
    if (_currentStreamKey == newStreamKey && _streamSubscription != null) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _streamSubscription?.cancel();
      _currentStreamKey = newStreamKey;
      _allDocs.clear();
      _lastDocument = null;
      _hasMore = true;
      _isLoadingMore = false;
      _isLoadingStream = true;
      _totalByUser.clear();
      notifyListeners();

      final cacheKey = newStreamKey;
      if (_queryCache.containsKey(cacheKey) && _queryCache[cacheKey]!.isNotEmpty) {
        _allDocs = _queryCache[cacheKey]!;
        _lastDocument = _allDocs.isNotEmpty ? _allDocs.last : null;
        _hasMore = _allDocs.length == _documentsPerPage;
        updateTotalByUserFromDocs(_allDocs);
        _isLoadingStream = false;
        notifyListeners();
        return;
      }

      await Future.delayed(const Duration(milliseconds: 50));
      Query<Map<String, dynamic>> baseQuery;

      if (_showWalletReceipts && walletId != null) {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('walletId', isEqualTo: walletId)
            .orderBy('created_at', descending: true);
        if (_selectedUserFilter != null) {
          baseQuery = baseQuery.where('userId', isEqualTo: _selectedUserFilter);
        }
      } else {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('userId', isEqualTo: userId)
            .orderBy('created_at', descending: true);
      }

      _streamSubscription = baseQuery.limit(_documentsPerPage).snapshots().listen((snapshot) async {
        _allDocs = snapshot.docs;
        if (snapshot.docs.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _documentsPerPage;
          _queryCache[cacheKey] = List.from(_allDocs);
          updateTotalByUserFromDocs(_allDocs);
        } else {
          _hasMore = false;
          _queryCache[cacheKey] = [];
          _totalByUser.clear();
        }
        _isLoadingStream = false;
        notifyListeners();
      }, onError: (e) {
        _isLoadingStream = false;
        Provider.of<AuthProvider>(context, listen: false).showError(context);
        debugPrint('Stream error: $e');
        notifyListeners();
      });
    });
  }

  Future<void> loadMoreExpenses(BuildContext context, String userId) async {
    if (!_hasMore || _isLoadingMore) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _isLoadingMore = true;
      notifyListeners();

      Query<Map<String, dynamic>> baseQuery;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (_showWalletReceipts && authProvider.walletId != null) {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('walletId', isEqualTo: authProvider.walletId)
            .orderBy('created_at', descending: true);
        if (_selectedUserFilter != null) {
          baseQuery = baseQuery.where('userId', isEqualTo: _selectedUserFilter);
        }
      } else {
        baseQuery = FirebaseFirestore.instance
            .collection('receipts')
            .where('userId', isEqualTo: userId)
            .orderBy('created_at', descending: true);
      }

      try {
        final snapshot = await baseQuery.startAfterDocument(_lastDocument!).limit(_documentsPerPage).get();
        if (snapshot.docs.isNotEmpty) {
          _allDocs.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == _documentsPerPage;
          _queryCache['${_showWalletReceipts}_${authProvider.walletId}_${_selectedUserFilter ?? "all"}'] = List.from(_allDocs);
          updateTotalByUserFromDocs(_allDocs);
        } else {
          _hasMore = false;
        }
      } catch (e) {
        Provider.of<AuthProvider>(context, listen: false).showError(context);
        debugPrint('Load more error: $e');
      } finally {
        _isLoadingMore = false;
        notifyListeners();
      }
    });
  }

  void updateTotalByUser(Map<String, double> newTotals) {
    _totalByUser = Map<String, double>.from(newTotals ?? {});
    debugPrint('Updated totalByUser: $_totalByUser');
    notifyListeners();
  }

  void updateTotalByUserFromDocs(List<DocumentSnapshot> docs) {
    final Map<String, double> tempTotals = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      final userId = data['userId'] as String? ?? 'Unknown';
      final total = calculateReceiptTotal(data);
      tempTotals[userId] = (tempTotals[userId] ?? 0.0) + total;
    }
    _totalByUser = tempTotals;
    debugPrint('Updated totalByUser from docs: $_totalByUser');
    notifyListeners();
  }

  Future<void> saveMultipleToFirestore(List<Map<String, dynamic>> expenses, BuildContext context) async {
    if (expenses.isEmpty) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final walletId = authProvider.walletId;
    final now = DateTime.now();

    final Map<String, Map<String, dynamic>> groupedExpenses = {};

    for (var expense in expenses) {
      final parsedDate = GptParser.normalizeDate(expense['date_of_purchase']);
      final category = expense['category'] ?? 'General';
      final item_name = expense['item_name'];
      final unit_price = (expense['unit_price'] as num?)?.toDouble();

      if (item_name == null || unit_price == null) {
        debugPrint('Skipping expense due to missing item_name or unit_price: $expense');
        continue;
      }

      final String dateKey = parsedDate != null ? DateFormat('yyyy-MM-dd').format(parsedDate) : DateFormat('yyyy-MM-dd').format(now);
      final String groupKey = '$category-$dateKey';

      if (!groupedExpenses.containsKey(groupKey)) {
        groupedExpenses[groupKey] = {
          'item_name': [],
          'unit_price': [],
          'date_of_purchase': Timestamp.fromDate(parsedDate ?? now),
          'category': category,
          'userId': userId,
          'walletId': walletId,
          'created_at': Timestamp.fromDate(now),
        };
      }
      (groupedExpenses[groupKey]!['item_name'] as List).add(item_name);
      (groupedExpenses[groupKey]!['unit_price'] as List).add(unit_price);
    }

    final batch = FirebaseFirestore.instance.batch();
    try {
      for (var entry in groupedExpenses.values) {
        final docRef = FirebaseFirestore.instance.collection('receipts').doc();
        batch.set(docRef, entry);
      }
      await batch.commit();
      showSuccess(groupedExpenses.length);
      _setupStream(context, authProvider.user!.uid, authProvider.walletId);
    } catch (e) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Save grouped expenses error: $e');
    }
  }

  Future<String> _getTempFilePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> startRecording(BuildContext context) async {
    try {
      _recorder = AudioRecorder();
      if (await _recorder!.hasPermission()) {
        final path = await _getTempFilePath();
        await _recorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            bitRate: 64000,
          ),
          path: path,
        );
        _isRecording = true;
        _transcription = '';
        notifyListeners();
      } else {
        Provider.of<AuthProvider>(context, listen: false).showError(context);
      }
    } catch (e) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> stopRecordingAndProcess(BuildContext context) async {
    try {
      if (!_isRecording || _recorder == null) return;

      _isRecording = false;
      _isProcessing = true;
      notifyListeners();

      final path = await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;

      if (path != null && File(path).existsSync()) {
        final file = File(path);
        final transcript = await GptParser.transcribeAudio(file);
        _transcription = transcript ?? '';
        notifyListeners();

        if (transcript != null && transcript.isNotEmpty) {
          await _parseAndAddExpense(transcript, context);
        } else {
          Provider.of<AuthProvider>(context, listen: false).showError(context);
        }
        await file.delete();
      } else {
        Provider.of<AuthProvider>(context, listen: false).showError(context);
      }
    } catch (e) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Stop recording error: $e');
    } finally {
      _isProcessing = false;
      _recorder?.dispose();
      _recorder = null;
      notifyListeners();
    }
  }

  Future<void> _parseAndAddExpense(String transcription, BuildContext context) async {
    try {
      final expenses = await GptParser.extractStructuredData(transcription);
      await saveMultipleToFirestore(expenses!, context);
    } catch (e) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Parse expenses error: $e');
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleWalletReceipts(BuildContext context) {
    _showWalletReceipts = !_showWalletReceipts;
    _searchQuery = '';
    _selectedUserFilter = null; // Reset filter when toggling
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, authProvider.user!.uid, authProvider.walletId);
    notifyListeners();
  }

  Future<void> joinWallet(WalletProvider walletProvider, BuildContext context) async {
    try {
      final walletId = _walletIdController.text.trim();
      if (walletId.isEmpty) {
        Provider.of<AuthProvider>(context, listen: false).showError(context);
        return;
      }

      final success = await walletProvider.joinWallet(
        walletId,
        Provider.of<AuthProvider>(context, listen: false).user!.uid,
        context,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Joined wallet successfully' : walletProvider.errorMessage ?? 'Failed to join wallet'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        _walletIdController.clear();
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        _setupStream(context, authProvider.user!.uid, authProvider.walletId);
        notifyListeners();
      }
    } catch (e) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Join wallet error: $e');
    }
  }

  static bool matchesSearch(String searchQuery, Map<String, dynamic> data) {
    final query = searchQuery.toLowerCase();
    if (query.isEmpty) return true;

    final itemNames = data['item_name'];
    final category = data['category']?.toString().toLowerCase() ?? '';
    final date = data['date_of_purchase']?.toString().toLowerCase() ?? '';

    if (itemNames is List && itemNames.any((item) => item.toString().toLowerCase().contains(query))) return true;

    return category.contains(query) || date.contains(query);
  }

  static double calculateReceiptTotal(Map<String, dynamic> data) {
    final prices = data['unit_price'];
    if (prices is List) {
      return prices.fold(0.0, (sum, price) => sum + (price is num ? price.toDouble() : 0.0));
    }
    return 0.0;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _recorder?.dispose();
    _recorder = null;
    _walletIdController.dispose();
    _streamSubscription?.cancel();
    _queryCache.clear();
    _userNameCache.clear();
    _totalByUser.clear();
    super.dispose();
  }
}