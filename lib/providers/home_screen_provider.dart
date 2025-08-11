import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/providers/wallet_provider.dart';
import 'package:couple_expenses/services/gpt_parser.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

class HomeScreenProvider extends ChangeNotifier {

int _monthFromString(String month) {
  final m = int.tryParse(month);
  if (m != null && m >= 1 && m <= 12) return m;

  const names = {
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
  return names[month.toLowerCase()] ?? DateTime.now().month;
}

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

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isLoadingStream => _isLoadingStream;
  bool get showSuccessPopup => _showSuccessPopup;
  int get savedExpensesCount => _savedExpensesCount;
  String get transcription => _transcription;
  String get searchQuery => _searchQuery;
  bool get showWalletReceipts => _showWalletReceipts;
  TextEditingController get walletIdController => _walletIdController;



List<Map<String, dynamic>> _pendingExpenses = [];
  bool _hasJustAddedExpenses = false;
  
   List<Map<String, dynamic>> get pendingExpenses => _pendingExpenses;
  bool get hasJustAddedExpenses => _hasJustAddedExpenses;

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

  Future<void> saveMultipleToFirestore(
    List<Map<String, dynamic>> expenses,
    BuildContext context,
  ) async {
    print('🎯 [DEBUG] Starting saveMultipleToFirestore with ${expenses.length} expenses');
    
    if (expenses.isEmpty) {
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final txnProvider = Provider.of<TransactionListProvider>(context, listen: false);
    final userId = authProvider.user?.uid;
    final walletId = authProvider.walletId;
    final now = DateTime.now();

    print('🎯 [DEBUG] userId: $userId, walletId: $walletId');

    // Get the selected month/year
    final monthProv = Provider.of<MonthSelectionProvider>(context, listen: false);
    final monthNum = _monthFromString(monthProv.selectedMonth);
    final year = monthProv.selectedYear;

    print('🎯 [DEBUG] Selected month: ${monthProv.selectedMonth}, year: $year, monthNum: $monthNum');

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

      // Determine the day-of-month (parsedDate or today)
      final baseDate = parsedDate ?? now;
      final day = baseDate.day;

      // Force month/year to selected values
      final purchaseDate = DateTime(year, monthNum, day);

      // GroupKey uses this forced date
      final dateKey = DateFormat('yyyy-MM-dd').format(purchaseDate);
      final groupKey = '$category-$dateKey';

      if (!groupedExpenses.containsKey(groupKey)) {
        groupedExpenses[groupKey] = {
          'item_name': [],
          'unit_price': [],
          'date_of_purchase': Timestamp.fromDate(purchaseDate),
          'category': category,
          'userId': userId,
          'walletId': walletId,
          'created_at': Timestamp.fromDate(now),
        };
      }
      (groupedExpenses[groupKey]!['item_name'] as List).add(item_name);
      (groupedExpenses[groupKey]!['unit_price'] as List).add(unit_price);
    }

    print('🎯 [DEBUG] Created ${groupedExpenses.length} grouped expenses');

    // INSTANT UPDATE: Store pending expenses and notify immediately
    _pendingExpenses = groupedExpenses.values.toList();
    _hasJustAddedExpenses = true;
    notifyListeners(); // This will instantly update the UI

    // Batch write
    final batch = FirebaseFirestore.instance.batch();
    String? lastCreatedDocId;

    try {
      for (var entry in groupedExpenses.values) {
        final docRef = FirebaseFirestore.instance.collection('receipts').doc();
        batch.set(docRef, entry);
        lastCreatedDocId ??= docRef.id;
        print('🎯 [DEBUG] Added to batch: ${docRef.id}');
      }
      
      print('🎯 [DEBUG] About to commit batch...');
      await batch.commit();
      print('🎯 [DEBUG] Batch committed successfully!');

      // After successful commit, clear pending and trigger refresh
      if (lastCreatedDocId != null) {
        print('🎯 [DEBUG] Setting lastAddedId: $lastCreatedDocId');
        txnProvider.setLastAddedId(lastCreatedDocId);
        
        // Get the month name for cache operations
        final monthName = _getMonthName(monthNum);
        print('🎯 [DEBUG] About to invalidate cache for month: $monthName, year: $year');
        
        // This will invalidate cache AND trigger refresh automatically
        txnProvider.invalidateCacheForMonth(monthName, year);
        
        Future.delayed(const Duration(seconds: 1), () {
          txnProvider.setLastAddedId(null);
          print('🎯 [DEBUG] Cleared lastAddedId');
        });
      }

      // Clear pending expenses after a short delay to let the animation play
      Future.delayed(const Duration(milliseconds: 1500), () {
        _pendingExpenses.clear();
        _hasJustAddedExpenses = false;
        notifyListeners();
      });

      showSuccess(groupedExpenses.length);
      
      print('🎯 [DEBUG] Successfully completed saveMultipleToFirestore');
      
    } catch (e) {
      // If there's an error, clear the pending expenses
      _pendingExpenses.clear();
      _hasJustAddedExpenses = false;
      notifyListeners();
      
      print('🎯 [DEBUG] ERROR in saveMultipleToFirestore: $e');
      Provider.of<AuthProvider>(context, listen: false).showError(context);
      debugPrint('Save grouped expenses error: $e');
    }
  }

  // ADD THIS METHOD
  double getPendingTotalForUser(String userId) {
    if (!_hasJustAddedExpenses || _pendingExpenses.isEmpty) return 0.0;
    
    double total = 0.0;
    for (var expense in _pendingExpenses) {
      if (expense['userId'] == userId) {
        total += calculateReceiptTotal(expense);
      }
    }
    return total;
  }

  // ADD THIS METHOD
  void clearPendingExpenses() {
    _pendingExpenses.clear();
    _hasJustAddedExpenses = false;
    notifyListeners();
  }


  

  String _getMonthName(int monthNumber) {
    const monthNames = [
      '', 'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return monthNames[monthNumber];
  }

  // Method to handle expense deletion with cache update
  Future<void> deleteExpense(String docId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('receipts')
          .doc(docId)
          .delete();
      
      // Update cache by removing the doc
      final txnProvider = Provider.of<TransactionListProvider>(context, listen: false);
      txnProvider.removeDoc(docId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted')),
      );
      
      print('[CACHE] Expense deleted and removed from cache');
    } catch (e) {
      debugPrint('Delete expense error: $e');
      Provider.of<AuthProvider>(context, listen: false).showError(context);
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

      // Stop & clean up the recorder
      _isRecording = false;
      _isProcessing = true;
      notifyListeners();

      final path = await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;

      if (path != null && File(path).existsSync()) {
        final file = File(path);

        // Start timing
        final sw = Stopwatch()..start();

        // Transcription
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
          // Parsing
          final expenses = await GptParser.extractStructuredData(transcript);
          print('⏱ Parse took ${sw.elapsedMilliseconds}ms');

          // Reset for Firestore write
          sw
            ..reset()
            ..start();

          // Firestore write
          await saveMultipleToFirestore(expenses!, context);
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

 
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

void toggleWalletReceipts(BuildContext context) {
  // flip the flag
  _showWalletReceipts = !_showWalletReceipts;

  // clear any search query
  _searchQuery = '';

  // Mark all caches for refresh instead of clearing them
  final txnProvider = Provider.of<TransactionListProvider>(context, listen: false);
  txnProvider.invalidateCache();

  // now update any listeners (UI will rebuild and re‐load)
  notifyListeners();

  print('[CACHE] Toggled wallet receipts, cache marked for refresh');
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

  String? getCachedUserDisplayName(String userId) =>
      _userNameCache[userId];
      
  void clearCaches() {
    _userNameCache.clear();
    
    // Also clear transaction cache when user logs out or similar
    // Note: You'll need to pass context or get the provider differently in a real scenario
    // This is just to show the integration
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