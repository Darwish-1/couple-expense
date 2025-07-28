// transaction_list.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart'; // Import the recording section
class TransactionList extends StatefulWidget {
  final String userId;

  const TransactionList({super.key, required this.userId});

  @override
  _TransactionListState createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  @override
  Widget build(BuildContext context) {
    print('TransactionList build');
    // We only select states that affect the *overall structure*
    // or very top-level conditions here.
    return Selector<HomeScreenProvider, ({bool showWalletReceipts, String searchQuery, bool isRecording, bool isProcessing, bool showSuccessPopup, int savedExpensesCount})>(
      selector: (_, provider) => (
        showWalletReceipts: provider.showWalletReceipts,
        searchQuery: provider.searchQuery,
        isRecording: provider.isRecording,
        isProcessing: provider.isProcessing,
        showSuccessPopup: provider.showSuccessPopup,
        savedExpensesCount: provider.savedExpensesCount,
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
          // Inner Selector for the document list
          mainContent = Selector<HomeScreenProvider, List<DocumentSnapshot>>(
            selector: (_, provider) => provider.allDocs, // Only rebuilds when allDocs changes
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
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      // Extract data here only once per item
                      final itemNames = data['item_name'];
                      final unitPrices = data['unit_price'];
                      final date = (data['date_of_purchase'] is Timestamp)
                          ? DateFormat('MMM dd, yyyy').format((data['date_of_purchase'] as Timestamp).toDate())
                          : (data['date_of_purchase'] ?? 'Unknown Date');
                      final category = data['category'] ?? 'N/A';
                      final total = HomeScreenProvider.calculateReceiptTotal(data);

                      String displayItemName = 'No items';
                      if (itemNames is List && itemNames.isNotEmpty) {
                        displayItemName = itemNames[0]?.toString() ?? 'Item';
                        if (itemNames.length > 1) {
                          displayItemName += " and ${itemNames.length - 1} more";
                        }
                      } else if (itemNames is String) {
                        displayItemName = itemNames;
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
                            homeScreenProvider.removeDoc(doc.id); // This will cause list rebuild, but only for the list
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
                            elevation: 2,
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
                                          displayItemName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        "\$${total.toStringAsFixed(2)}",
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
                                  if (itemNames is List && unitPrices is List && itemNames.length > 1) ...[
                                    const SizedBox(height: 10),
                                    const Text("Items:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: itemNames.length,
                                      itemBuilder: (context, idx) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  itemNames[idx]?.toString() ?? 'Item',
                                                  style: const TextStyle(fontSize: 14),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                "\$${(unitPrices[idx] as num?)?.toStringAsFixed(2) ?? '0.00'}",
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
            // Layer 1: The RecordingSection, positioned to float
            if (selectorData.isRecording || selectorData.isProcessing)
              const Positioned.fill(
                child: RecordingSection(),
              ),
            // Layer 2: The SuccessPopUp, positioned to float
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