
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
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
  Map<String, String> _userNameCache = {};



  bool get isRecording => _isRecording;

  bool get isProcessing => _isProcessing;
  bool get isLoadingStream => _isLoadingStream;
  bool get showSuccessPopup => _showSuccessPopup;
  int get savedExpensesCount => _savedExpensesCount;
  String get transcription => _transcription;
  String get searchQuery => _searchQuery;
  bool get showWalletReceipts => _showWalletReceipts;
  TextEditingController get walletIdController => _walletIdController;



 

  void setIsProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void showSuccess(int count) {
    _savedExpensesCount = count;
    _showSuccessPopup = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 2), () {
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

 


  void updateTotalByUser(Map<String, double> newTotals) {
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
    String? lastCreatedDocId; // Store this for animation

    try {
      for (var entry in groupedExpenses.values) {
        final docRef = FirebaseFirestore.instance.collection('receipts').doc();
        batch.set(docRef, entry);
            lastCreatedDocId ??= docRef.id; // Set the first created doc's ID (could be changed to last if you prefer)

      }
      await batch.commit();


  if (lastCreatedDocId != null) {
    Provider.of<TransactionListProvider>(context, listen: false).setLastAddedId(lastCreatedDocId);
    Future.delayed(const Duration(seconds: 1), () {
      Provider.of<TransactionListProvider>(context, listen: false).setLastAddedId(null);
    });
  }

      showSuccess(groupedExpenses.length);
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

    // 1️⃣ Stop & clean up the recorder
    _isRecording = false;
    _isProcessing = true;
    notifyListeners();

    final path = await _recorder!.stop();
    await _recorder!.dispose();
    _recorder = null;

    if (path != null && File(path).existsSync()) {
      final file = File(path);

      // 🚦 Start timing
      final sw = Stopwatch()..start();

      // 2️⃣ Transcription
      final transcript = await GptParser.transcribeAudio(file);
      print('⏱ Transcribe took ${sw.elapsedMilliseconds}ms');

      // Show interim transcript
      _transcription = transcript ?? '';
      notifyListeners();

      // Reset stopwatch for parsing
      sw
        ..reset()
        ..start();

      if (transcript != null && transcript.isNotEmpty) {
        // 3️⃣ Parsing
        final expenses = await GptParser.extractStructuredData(transcript);
        print('⏱ Parse took ${sw.elapsedMilliseconds}ms');

        // Reset for Firestore write
        sw
          ..reset()
          ..start();

        // 4️⃣ Firestore write
         saveMultipleToFirestore(expenses!, context);
        print('⏱ Firestore write took ${sw.elapsedMilliseconds}ms');

        // Stop timing
        sw.stop();
      } else {
        Provider.of<AuthProvider>(context, listen: false).showError(context);
      }

      // Delete temp file
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
  } else if (prices is num) {
    return prices.toDouble();
  } else if (data.containsKey('amount') && data['amount'] is num) {
    return (data['amount'] as num).toDouble();
  }
  return 0.0;
}
void clearCaches() {
  _userNameCache.clear();
}
  @override
  void dispose() {
    _recorder?.dispose();
    _recorder = null;
    _walletIdController.dispose();
    _userNameCache.clear();
    super.dispose();
  }
}