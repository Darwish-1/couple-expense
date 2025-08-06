// lib/screens/monthly_transaction_list.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';

class MonthlyTransactionList extends StatelessWidget {
  final String userId;

  const MonthlyTransactionList({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MonthSelectionProvider>(
      builder: (context, monthProvider, _) {
        final selectedMonth = monthProvider.selectedMonth;
        final selectedYear = monthProvider.selectedYear;

        // Watch the shared‐toggle and wallet ID so we rebuild when they change
        final showShared    = context.watch<HomeScreenProvider>().showWalletReceipts;
        final currentWallet = context.watch<AuthProvider>().walletId;

        // Watch transaction provider for any user‐filter already set
        final txnProv      = context.watch<TransactionListProvider>();
        final filterUserId = txnProv.selectedUserFilter;

        // Pick personal vs. shared‐wallet query
        final expensesFuture = (showShared && currentWallet != null)
            ? txnProv.getSharedExpensesForMonth(
                selectedMonth, selectedYear, currentWallet, filterUserId)
            : txnProv.getExpensesForMonth(
                selectedMonth, selectedYear, userId);

        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  '$selectedMonth $selectedYear Transactions',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 8),

                // Transaction data
                FutureBuilder<List<DocumentSnapshot>>(
                  future: expensesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.indigo),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.red.shade600,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _noResultsCard();
                    }

                    final docs = snapshot.data!;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final category = data['category'] ?? 'N/A';
                        final itemNames = (data['item_name'] is List)
                            ? (data['item_name'] as List)
                                .map((e) => e.toString())
                                .toList()
                            : [data['item_name'].toString()];
                        final total = HomeScreenProvider.calculateReceiptTotal(data);
                        final date = data['date_of_purchase'] is Timestamp
                            ? (data['date_of_purchase'] as Timestamp).toDate()
                            : null;

                        // Determine who paid for border color
                        final receiptOwnerId = data['userId'] as String;
                        final isOwner        = receiptOwnerId == userId;
                        final borderColor    = isOwner
                            ? Colors.blue.shade400
                            : Colors.green.shade400;

                        final currencyFormatter = NumberFormat.currency(
                          locale: 'en_US',
                          symbol: 'EGP ',
                          decimalDigits: 0,
                        );

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: borderColor, width: 4),
                            ),
                          ),
                          child: Dismissible(
                            key: ValueKey(doc.id),
                            direction: isOwner
                                ? DismissDirection.endToStart
                                : DismissDirection.none,
                            background: isOwner
                                ? Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    color: Colors.red.shade600,
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  )
                                : null,
                            onDismissed: isOwner
                                ? (direction) async {
                                    await FirebaseFirestore.instance
                                        .collection('receipts')
                                        .doc(doc.id)
                                        .delete();
                                    txnProv.removeDoc(doc.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Expense deleted')),
                                    );
                                  }
                                : null,
                            child: Hero(
                              tag: 'transaction-${doc.id}',
                              child: Material(
                                color: Colors.white,
                                child: InkWell(
                                  onLongPress: isOwner
                                      ? () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EditReceiptScreen(
                                                receiptId: doc.id,
                                                data: data,
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: IntrinsicHeight(
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    category,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.indigo.shade700,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    itemNames.join(', '),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey.shade800,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  currencyFormatter.format(total),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.amber.shade600,
                                                  ),
                                                ),
                                                Text(
                                                  date != null
                                                      ? DateFormat('MMM dd').format(date)
                                                      : 'N/A',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _noResultsCard() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No expenses recorded for this month.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try recording a new expense.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
