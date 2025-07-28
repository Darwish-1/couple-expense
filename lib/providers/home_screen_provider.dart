import 'dart:async';
import 'dart:convert';
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
  String _transcription = '';
  String _searchQuery = '';
  bool _showWalletReceipts = false;
  bool _showSuccessPopup = false;
  int _savedExpensesCount = 0;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get showSuccessPopup => _showSuccessPopup;
  int get savedExpensesCount => _savedExpensesCount;
  final TextEditingController _walletIdController = TextEditingController();
  List<DocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _streamSubscription;

  // Pagination related state
  DocumentSnapshot? _lastDocument; // Stores the last document of the current fetch
  bool _hasMore = true; // Indicates if there are more documents to load
  bool _isLoadingMore = false; // Prevents multiple simultaneous fetch calls
  final int _documentsPerPage = 20; // Number of documents to fetch per page

  String get transcription => _transcription;
  String get searchQuery => _searchQuery;
  bool get showWalletReceipts => _showWalletReceipts;
  TextEditingController get walletIdController => _walletIdController;
  List<DocumentSnapshot> get allDocs => _allDocs;
  bool get hasMore => _hasMore; // Expose hasMore to the UI
  bool get isLoadingMore => _isLoadingMore; // Expose isLoadingMore to the UI

  void initializeStream(BuildContext context, String userId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, userId, authProvider.walletId);
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

  void _setupStream(BuildContext context, String userId, String? walletId) {
    _streamSubscription?.cancel();
    _allDocs.clear();
    _lastDocument = null; // Reset for a new stream
    _hasMore = true; // Assume there's more data when a new stream starts
    _isLoadingMore = false; // Reset loading state

    Query<Map<String, dynamic>> baseQuery;

    if (_showWalletReceipts && walletId != null) {
      baseQuery = FirebaseFirestore.instance
          .collection('receipts')
          .where('walletId', isEqualTo: walletId)
          .orderBy('created_at', descending: true); // Order by creation time
    } else {
      baseQuery = FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true); // Order by creation time
    }

    _streamSubscription = baseQuery.limit(_documentsPerPage).snapshots().listen((snapshot) {
      _allDocs = snapshot.docs;
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _documentsPerPage;
      } else {
        _hasMore = false;
      }
      notifyListeners();
    }, onError: (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    });
  }

  Future<void> loadMoreExpenses(BuildContext context, String userId) async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    Query<Map<String, dynamic>> baseQuery;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_showWalletReceipts && authProvider.walletId != null) {
      baseQuery = FirebaseFirestore.instance
          .collection('receipts')
          .where('walletId', isEqualTo: authProvider.walletId)
          .orderBy('created_at', descending: true); // Consistent ordering
    } else {
      baseQuery = FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: userId)
          .orderBy('created_at', descending: true); // Consistent ordering
    }

    try {
      final snapshot = await baseQuery
          .startAfterDocument(_lastDocument!)
          .limit(_documentsPerPage)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _allDocs.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length == _documentsPerPage;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more data: $e')),
      );
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void removeDoc(String docId) {
    _allDocs.removeWhere((doc) => doc.id == docId);
    notifyListeners();
  }

  // This method is no longer used for saving multiple items
  // but keeping it in case you have single expense saves elsewhere.
  Future<void> saveToFirestore(Map<String, dynamic> expense, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('receipts').add(expense);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Expense "${expense['item_name']}" saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving "${expense['item_name']}": $e')),
      );
    }
  }

  // MODIFIED: This method now saves grouped expenses based on category and date
  Future<void> saveMultipleToFirestore(List<Map<String, dynamic>> expenses, BuildContext context) async {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses extracted. Please try again.')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final walletId = authProvider.walletId;
    final now = DateTime.now(); // Use a consistent timestamp for all grouped items from this session

    // Group expenses by category and date_of_purchase
    final Map<String, Map<String, dynamic>> groupedExpenses = {};

    for (var expense in expenses) {
      final parsedDate = GptParser.normalizeDate(expense['date_of_purchase']);
      final category = expense['category'] ?? 'General';
      final item_name = expense['item_name'];
      final unit_price = (expense['unit_price'] as num?)?.toDouble();

      if (item_name == null || unit_price == null) {
        print('Skipping expense due to missing item_name or unit_price: $expense');
        continue; // Skip if essential data is missing
      }

      // Create a unique key for grouping based on category and the normalized date (YYYY-MM-DD)
      final String dateKey = parsedDate != null ? DateFormat('yyyy-MM-dd').format(parsedDate) : DateFormat('yyyy-MM-dd').format(now);
      final String groupKey = '$category-$dateKey';

      if (!groupedExpenses.containsKey(groupKey)) {
        groupedExpenses[groupKey] = {
          'item_name': [],
          'unit_price': [],
          'date_of_purchase': Timestamp.fromDate(parsedDate ?? now), // Use parsed date or current if null
          'category': category,
          'userId': userId,
          'walletId': walletId,
          'created_at': Timestamp.fromDate(now), // Timestamp for when this grouped entry was created
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
      showSuccess(groupedExpenses.length); // Show count of grouped entries
      // Re-initialize the stream to reflect new data from the top
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _setupStream(context, authProvider.user!.uid, authProvider.walletId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving grouped expenses: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not transcribe audio.')),
          );
        }
        await file.delete();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio data recorded.')),
        );
      }

      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing audio: $e')),
      );
    }
  }

  Future<void> _parseAndAddExpense(String transcription, BuildContext context) async {
    try {
      // GPT will still return individual items
      final expenses = await GptParser.extractStructuredData(transcription);

      // Now, saveMultipleToFirestore will handle the grouping based on category and date
      await saveMultipleToFirestore(expenses!, context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error parsing expenses: $e')),
      );
    }
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void toggleWalletReceipts(BuildContext context) {
    _showWalletReceipts = !_showWalletReceipts;
    _searchQuery = '';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, authProvider.user!.uid, authProvider.walletId);
    notifyListeners();
  }

  Future<void> joinWallet(WalletProvider walletProvider, BuildContext context) async {
    try {
      final walletId = _walletIdController.text.trim();
      if (walletId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a wallet ID')),
        );
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
        ),
      );

      if (success) {
        _walletIdController.clear();
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        _setupStream(context, authProvider.user!.uid, authProvider.walletId);
        notifyListeners();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error joining wallet: $e')),
      );
    }
  }

  static bool matchesSearch(String searchQuery, Map<String, dynamic> data) {
    final query = searchQuery.toLowerCase();
    if (query.isEmpty) return true;

    final itemNames = data['item_name']; // This is now always a List
    final category = data['category']?.toString().toLowerCase() ?? '';
    final date = data['date_of_purchase']?.toString().toLowerCase() ?? '';

    // Check if any item name in the list matches
    if (itemNames is List && itemNames.any((item) => item.toString().toLowerCase().contains(query))) return true;

    return category.contains(query) || date.contains(query);
  }

  static double calculateReceiptTotal(Map<String, dynamic> data) {
    final prices = data['unit_price']; // This is now always a List
    if (prices is List) {
      return prices.fold(0.0, (sum, price) => sum + (price is num ? price.toDouble() : 0.0));
    }
    return 0.0; // Should not happen if data is structured as expected
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _recorder = null;
    _walletIdController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}