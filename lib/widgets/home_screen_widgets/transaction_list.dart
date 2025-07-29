import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';

class TransactionList extends StatefulWidget {
  final String userId;

  const TransactionList({super.key, required this.userId});

  @override
  _TransactionListState createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final ScrollController _scrollController = ScrollController();
  late NumberFormat _currencyFormatter;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: 0,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);
        if (homeScreenProvider.hasMore && !homeScreenProvider.isLoadingMore) {
          homeScreenProvider.loadMoreExpenses(context, widget.userId);
        }
      });
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    List<String> parts = name.split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('TransactionList build');
    return Selector<HomeScreenProvider, ({List<DocumentSnapshot> allDocs, String searchQuery, bool isRecording, bool isProcessing, bool showSuccessPopup, int savedExpensesCount, bool isLoadingMore, bool hasMore, bool showWalletReceipts, bool isLoadingStream, String? selectedUserFilter})>(
      selector: (_, provider) => (
        allDocs: provider.allDocs,
        searchQuery: provider.searchQuery,
        isRecording: provider.isRecording,
        isProcessing: provider.isProcessing,
        showSuccessPopup: provider.showSuccessPopup,
        savedExpensesCount: provider.savedExpensesCount,
        isLoadingMore: provider.isLoadingMore,
        hasMore: provider.hasMore,
        showWalletReceipts: provider.showWalletReceipts,
        isLoadingStream: provider.isLoadingStream,
        selectedUserFilter: provider.selectedUserFilter,
      ),
      builder: (context, selectorData, _) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);
        final currentUserId = authProvider.user?.uid;

        Widget mainContent;

        if (selectorData.showWalletReceipts && authProvider.walletId == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 15),
                  Text(
                    "You haven't joined a wallet yet.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Join or create one to view shared expenses with your partner.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        if (selectorData.allDocs.isEmpty && (selectorData.isLoadingMore || selectorData.isLoadingStream)) {
          mainContent = const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        } else {
          final docs = selectorData.allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return HomeScreenProvider.matchesSearch(selectorData.searchQuery, data);
          }).toList();

          if (docs.isEmpty) {
            mainContent = Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 15),
                    Text(
                      selectorData.searchQuery.isEmpty
                          ? (selectorData.selectedUserFilter == null
                              ? "No expenses recorded."
                              : "No expenses found for this user.")
                          : "No expenses found for '${selectorData.searchQuery}'.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    if (selectorData.searchQuery.isEmpty && selectorData.selectedUserFilter == null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Tap the microphone button to add a new expense.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            );
          } else {
            final NumberFormat totalCurrencyFormatter = NumberFormat.currency(
              locale: 'en_US',
              symbol: 'EGP ',
              decimalDigits: 2,
            );
            mainContent = RefreshIndicator(
              onRefresh: () async {
                homeScreenProvider.initializeStream(context, widget.userId);
              },
              color: Theme.of(context).primaryColor,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: docs.length + (selectorData.isLoadingMore && selectorData.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == docs.length) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Center(child: CircularProgressIndicator(color: Colors.blue)),
                    );
                  }

                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final itemNames = (data['item_name'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                  final unitPrices = (data['unit_price'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
                  final date = (data['date_of_purchase'] is Timestamp)
                      ? DateFormat('MMM dd, yyyy').format((data['date_of_purchase'] as Timestamp).toDate())
                      : (data['date_of_purchase'] ?? 'Unknown Date');
                  final category = data['category'] ?? 'N/A';
                  final total = HomeScreenProvider.calculateReceiptTotal(data);
                  final expenseUserId = data['userId'];
                  final isMyExpense = currentUserId == expenseUserId;

                  String displayTitle = category;
                  if (itemNames.isNotEmpty && itemNames.length == 1) {
                    displayTitle = itemNames[0];
                  } else if (itemNames.length > 1) {
                    displayTitle = "$category (${itemNames.length} items)";
                  }

                  String itemListString = '';
                  if (itemNames.isNotEmpty) {
                    List<String> formattedItems = [];
                    for (int i = 0; i < itemNames.length; i++) {
                      final itemName = itemNames[i];
                      final price = unitPrices.length > i ? unitPrices[i] : 0.0;
                      formattedItems.add('$itemName (${_currencyFormatter.format(price)})');
                    }
                    itemListString = formattedItems.join(', ');
                  }

                  return Dismissible(
                    key: ValueKey(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white, size: 30),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: const Text('Delete Expense?', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text('Are you sure you want to delete this expense permanently? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      try {
                        await FirebaseFirestore.instance.collection('receipts').doc(doc.id).delete();
                        homeScreenProvider.removeDoc(doc.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Expense deleted successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        Provider.of<AuthProvider>(context, listen: false).showError(context);
                        debugPrint('Error deleting expense: $e');
                      }
                    },
                    child: GestureDetector(
                      onLongPress: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditReceiptScreen(
                              receiptId: doc.id,
                              data: data,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayTitle,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    totalCurrencyFormatter.format(total),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Category: $category",
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    date,
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                              if (selectorData.showWalletReceipts) ...[
                                const SizedBox(height: 8),
                                FutureBuilder<String?>(
                                  future: homeScreenProvider.fetchUserDisplayName(expenseUserId ?? ''),
                                  builder: (context, snapshot) {
                                    final name = snapshot.data;
                                    final initials = _getInitials(name);
                                    return Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: isMyExpense ? Colors.blue.shade100 : Colors.purple.shade100,
                                          child: Text(
                                            initials,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isMyExpense ? Colors.blue.shade800 : Colors.purple.shade800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isMyExpense ? 'By: Me' : 'By: ${name ?? 'Unknown'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isMyExpense ? Colors.blue.shade700 : Colors.purple.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                              if (itemListString.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  itemListString,
                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        }

        return Stack(
          children: [
            Column(
              children: [
                Expanded(child: mainContent),
              ],
            ),
            if (selectorData.isRecording || selectorData.isProcessing)
              const Positioned.fill(
                child: RecordingSection(),
              ),
            if (selectorData.showSuccessPopup)
              Positioned.fill(
                child: SuccessPopUp(savedCount: selectorData.savedExpensesCount),
              ),
          ],
        );
      },
    );
  }
}