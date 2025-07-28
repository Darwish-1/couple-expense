// transaction_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Make sure this is imported
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
  final ScrollController _scrollController = ScrollController(); // Controller for scrolling
  late NumberFormat _currencyFormatter; // Declare the formatter

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'en_US', // Or your desired locale (e.g., 'ar_EG' for Arabic, 'en_GB' for £)
      symbol: '',      // No currency symbol needed for individual item prices
      decimalDigits: 0,  // Show no decimal places for item prices within the list
    );
    _scrollController.addListener(_onScroll); // Add listener for pagination
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll); // Remove listener to prevent memory leaks
    _scrollController.dispose(); // Dispose the controller
    super.dispose();
  }

  void _onScroll() {
    final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);
    // Check if the user has scrolled to the bottom of the list
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      // If there's more data and not currently loading, load more
      if (homeScreenProvider.hasMore && !homeScreenProvider.isLoadingMore) {
        homeScreenProvider.loadMoreExpenses(context, widget.userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('TransactionList build');
    return Selector<HomeScreenProvider, ({bool showWalletReceipts, String searchQuery, bool isRecording, bool isProcessing, bool showSuccessPopup, int savedExpensesCount, bool isLoadingMore, bool hasMore})>(
      selector: (_, provider) => (
        showWalletReceipts: provider.showWalletReceipts,
        searchQuery: provider.searchQuery,
        isRecording: provider.isRecording,
        isProcessing: provider.isProcessing,
        showSuccessPopup: provider.showSuccessPopup,
        savedExpensesCount: provider.savedExpensesCount,
        isLoadingMore: provider.isLoadingMore,
        hasMore: provider.hasMore,
      ),
      builder: (context, selectorData, _) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        Widget mainContent;

        if (selectorData.showWalletReceipts && authProvider.walletId == null) {
          mainContent = Center(
            child: Text(
              "Join a wallet to view shared expenses.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          );
        } else {
          mainContent = Selector<HomeScreenProvider, List<DocumentSnapshot>>(
            selector: (_, provider) => provider.allDocs,
            builder: (context, allDocs, _) {
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return HomeScreenProvider.matchesSearch(selectorData.searchQuery, data);
              }).toList();

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    selectorData.searchQuery.isNotEmpty
                        ? "No results found for '${selectorData.searchQuery}'."
                        : "No expenses found. Tap the mic to add a new expense.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                );
              } else {
                return RefreshIndicator(
                  onRefresh: () async {
                    final provider = Provider.of<HomeScreenProvider>(context, listen: false);
                    provider.initializeStream(context, widget.userId);
                  },
                  color: Colors.deepPurple,
                  child: ListView.builder(
                    controller: _scrollController, // Assign the scroll controller
                    itemCount: docs.length + (selectorData.isLoadingMore && selectorData.hasMore ? 1 : 0), // Add 1 for loading indicator only if more data exists
                    itemBuilder: (context, index) {
                      if (index == docs.length) {
                        // This is the loading indicator at the end of the list
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
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

                      // Re-initialize for total, as item prices formatter is different
                      final NumberFormat totalCurrencyFormatter = NumberFormat.currency(
                        locale: 'en_US', // Or your desired locale
                        symbol: 'EGP ',      // Set currency symbol explicitly
                        decimalDigits: 2,  // Always show 2 decimal places
                      );


                      String displayTitle = category; // Primary title is the category
                      if (itemNames.isNotEmpty && itemNames.length == 1) {
                         // If only one item, show its name instead of category for clarity
                         displayTitle = itemNames[0];
                      } else if (itemNames.length > 1) {
                         // For multiple items, still show category but indicate multiple items
                         displayTitle = "$category (${itemNames.length} items)";
                      }

                      // Format the item list string
                      String itemListString = '';
                      if (itemNames.isNotEmpty) {
                        List<String> formattedItems = [];
                        for (int i = 0; i < itemNames.length; i++) {
                          final itemName = itemNames[i];
                          final price = unitPrices.length > i ? unitPrices[i] : 0.0;
                          formattedItems.add('$itemName(${_currencyFormatter.format(price)})');
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
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white, size: 30),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              title: const Text('Delete Expense?'),
                              content: const Text('Are you sure you want to delete this expense permanently?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
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
                          final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          try {
                            await FirebaseFirestore.instance.collection('receipts').doc(doc.id).delete();
                            homeScreenProvider.removeDoc(doc.id);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Expense deleted successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            print('Error deleting expense: $e');
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Error deleting expense: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
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
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            elevation:0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: Colors.grey[300]!, width: 1.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          displayTitle, // Display category or single item name
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        totalCurrencyFormatter.format(total), // Apply formatter for total
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Category: $category",
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                      ),
                                      Text(
                                        "$date",
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                  // Display individual items as a comma-separated string
                                  if (itemListString.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      "$itemListString",
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 2, // Allow multiple lines if the string is long
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
            },
          );
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