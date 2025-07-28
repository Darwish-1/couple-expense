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
  bool _showSuccessPopup = false; // New state variable
  int _savedExpensesCount = 0;   // To display count in success message
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get showSuccessPopup => _showSuccessPopup; // Getter for the new state
  int get savedExpensesCount => _savedExpensesCount; // Getter for count
  final TextEditingController _walletIdController = TextEditingController();
  List<DocumentSnapshot> _allDocs = [];
  StreamSubscription<QuerySnapshot>? _streamSubscription;

  String get transcription => _transcription;
  String get searchQuery => _searchQuery;
  bool get showWalletReceipts => _showWalletReceipts;
  TextEditingController get walletIdController => _walletIdController;
  List<DocumentSnapshot> get allDocs => _allDocs;

  void initializeStream(BuildContext context, String userId) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _setupStream(context, userId, authProvider.walletId);
  }

  void setIsProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  // New methods to control success pop-up
  void showSuccess(int count) {
    _savedExpensesCount = count;
    _showSuccessPopup = true;
    notifyListeners();
    // Automatically hide after a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      hideSuccess();
    });
  }

  void hideSuccess() {
    if (_showSuccessPopup) { // Only notify if it was actually shown
      _showSuccessPopup = false;
      _savedExpensesCount = 0; // Reset count
      notifyListeners();
    }
  }

  void _setupStream(BuildContext context, String userId, String? walletId) {
    _streamSubscription?.cancel();
    _allDocs.clear();

    Query<Map<String, dynamic>> query = _showWalletReceipts && walletId != null
        ? FirebaseFirestore.instance
            .collection('receipts')
            .where('walletId', isEqualTo: walletId)
            .orderBy('date_of_purchase', descending: true)
            .limit(10)
        : FirebaseFirestore.instance
            .collection('receipts')
            .where('userId', isEqualTo: userId)
            .orderBy('date_of_purchase', descending: true)
            .limit(10);

    _streamSubscription = query.snapshots().listen((snapshot) {
      _allDocs = snapshot.docs;
      notifyListeners();
    }, onError: (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching data: $e')),
      );
    });
  }

  void removeDoc(String docId) {
    _allDocs.removeWhere((doc) => doc.id == docId);
    notifyListeners();
  }

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

  Future<void> saveMultipleToFirestore(List<Map<String, dynamic>> expenses, BuildContext context) async {
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses extracted. Please try again.')),
      );
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    try {
      for (var expense in expenses) {
        final docRef = FirebaseFirestore.instance.collection('receipts').doc();
        batch.set(docRef, expense);
      }
      await batch.commit();
      // Removed initializeStream call to prevent unnecessary refresh
      showSuccess(expenses.length); // Call the new method
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving multiple expenses: $e')),
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final expenses = await GptParser.extractStructuredData(transcription);

      if (expenses != null && expenses.isNotEmpty) {
        final now = DateTime.now();
        final formattedExpenses = expenses.map((expense) {
          final parsedDate = GptParser.normalizeDate(expense['date_of_purchase']);
          final timestamp = parsedDate != null
              ? DateTime(parsedDate.year, parsedDate.month, parsedDate.day, now.hour, now.minute, now.second)
              : now;

          return {
            'item_name': expense['item_name'] ?? 'Unknown',
            'unit_price': (expense['unit_price'] as num?)?.toDouble() ?? 0.0,
            'date_of_purchase': timestamp,
            'category': expense['category'] ?? 'General',
            'userId': authProvider.user?.uid,
            'walletId': authProvider.walletId,
          };
        }).toList();

        await saveMultipleToFirestore(formattedExpenses, context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not extract expenses.')),
        );
      }
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

    final itemName = data['item_name'];
    final category = data['category']?.toString().toLowerCase() ?? '';
    final date = data['date_of_purchase']?.toString().toLowerCase() ?? '';

    if (itemName is List && itemName.any((item) => item.toString().toLowerCase().contains(query))) return true;
    if (itemName is String && itemName.toLowerCase().contains(query)) return true;

    return category.contains(query) || date.contains(query);
  }

  static double calculateReceiptTotal(Map<String, dynamic> data) {
    final prices = data['unit_price'];
    if (prices is List) {
      return prices.fold(0.0, (sum, price) => sum + (price is num ? price.toDouble() : 0.0));
    } else if (prices is num) {
      return prices.toDouble();
    } else if (prices is String) {
      return double.tryParse(prices.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    }
    return 0.0;
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