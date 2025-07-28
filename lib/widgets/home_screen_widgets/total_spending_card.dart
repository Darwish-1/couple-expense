// total_spending_card.dart (you need to update this file manually)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Import this
import 'package:couple_expenses/providers/auth_provider.dart'; // Make sure this path is correct
import 'package:couple_expenses/providers/home_screen_provider.dart'; // Make sure this path is correct

class TotalSpendingCard extends StatefulWidget { // Change to StatefulWidget if not already
  final String userId; // Keep this if it's passed from home_screen.dart

  const TotalSpendingCard({super.key, required this.userId});

  @override
  State<TotalSpendingCard> createState() => _TotalSpendingCardState();
}

class _TotalSpendingCardState extends State<TotalSpendingCard> {
  late NumberFormat _currencyFormatter; // Declare the formatter

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'en_US', // Or your desired locale
      symbol: '\$',      // Explicit symbol
      decimalDigits: 2,  // Always show 2 decimal places
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<HomeScreenProvider, bool>(
      selector: (_, provider) => provider.showWalletReceipts,
      builder: (context, showWalletReceipts, _) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final walletId = authProvider.walletId;

        Stream<QuerySnapshot> getExpensesStream() {
          if (showWalletReceipts && walletId != null) {
            return FirebaseFirestore.instance
                .collection('receipts')
                .where('walletId', isEqualTo: walletId)
                .snapshots();
          } else {
            return FirebaseFirestore.instance
                .collection('receipts')
                .where('userId', isEqualTo: widget.userId)
                .snapshots();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: getExpensesStream(),
          builder: (context, snapshot) {
            double totalSpending = 0.0;
            int numberOfExpenses = 0;

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalSpending += HomeScreenProvider.calculateReceiptTotal(data);
                numberOfExpenses++;
              }
            }

            return Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.money, color: Colors.deepPurple, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Spending:",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          Text(
                            _currencyFormatter.format(totalSpending), // Apply formatter
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "$numberOfExpenses expenses recorded",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}