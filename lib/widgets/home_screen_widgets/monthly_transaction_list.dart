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
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MonthSelectionProvider>(
      builder: (context, monthProv, _) {
        final selectedMonth = monthProv.selectedMonth;
        final selectedYear = monthProv.selectedYear;
        final showShared = context.watch<HomeScreenProvider>().showWalletReceipts;
        final currentWallet = context.watch<AuthProvider>().walletId;
        final txnProv = context.watch<TransactionListProvider>();
        final filterUserId = txnProv.selectedUserFilter;

        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedMonth $selectedYear Transactions',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 8),

                _PermanentTransactionList(
                  key: ValueKey(
                    '${userId}_${selectedMonth}_${selectedYear}_'
                    '${showShared}_${currentWallet ?? 'noWallet'}_'
                    '${filterUserId ?? 'noFilter'}',
                  ),
                  selectedMonth: selectedMonth,
                  selectedYear: selectedYear,
                  userId: userId,
                  showShared: showShared,
                  currentWallet: currentWallet,
                  filterUserId: filterUserId,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PermanentTransactionList extends StatefulWidget {
  final String selectedMonth;
  final int selectedYear;
  final String userId;
  final bool showShared;
  final String? currentWallet;
  final String? filterUserId;

  const _PermanentTransactionList({
    Key? key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.userId,
    required this.showShared,
    required this.currentWallet,
    required this.filterUserId,
  }) : super(key: key);

  @override
  State<_PermanentTransactionList> createState() => _PermanentTransactionListState();
}

class _PermanentTransactionListState extends State<_PermanentTransactionList> {
  String? _currentCacheKey;
  
  @override
  void initState() {
    super.initState();
    _currentCacheKey = _generateCacheKey();
    _ensureTransactionsLoaded();
  }

  @override
  void didUpdateWidget(covariant _PermanentTransactionList old) {
    super.didUpdateWidget(old);
    final newCacheKey = _generateCacheKey();
    
    if (_currentCacheKey != newCacheKey) {
      _currentCacheKey = newCacheKey;
      _ensureTransactionsLoaded();
    }
  }

  String _generateCacheKey() {
    return '${widget.userId}-'
           '${widget.showShared ? 'shared' : 'personal'}-'
           '${widget.currentWallet ?? 'nowallet'}-'
           '${widget.filterUserId ?? 'nofilter'}-'
           '${widget.selectedMonth}-${widget.selectedYear}';
  }

  void _ensureTransactionsLoaded() {
    final txnProv = context.read<TransactionListProvider>();
    txnProv.ensureMonthlyTransactionsLoaded(
      cacheKey: _currentCacheKey!,
      month: widget.selectedMonth,
      year: widget.selectedYear,
      userId: widget.userId,
      showShared: widget.showShared,
      walletId: widget.currentWallet,
      filterUserId: widget.filterUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionListProvider>(
      builder: (context, txnProv, _) {
        final transactions = txnProv.getTransactionsForCache(_currentCacheKey!);
        final isLoading = txnProv.isLoadingCache(_currentCacheKey!);

        // Show loading only if we have no data and we're loading
        if (isLoading && transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Apply client-side filter if needed
        final visible = widget.showShared
            ? transactions
            : transactions.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['userId'] == widget.userId;
              }).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (visible.isEmpty)
              _noResultsCard()
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visible.length,
                itemBuilder: (ctx, i) {
                  final doc = visible[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildTransactionItem(context, doc, data, txnProv);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    DocumentSnapshot doc,
    Map<String, dynamic> data,
    TransactionListProvider txnProv,
  ) {
    final category = data['category'] ?? 'N/A';
    final itemNames = (data['item_name'] is List)
        ? (data['item_name'] as List).map((e) => e.toString()).toList()
        : [data['item_name'].toString()];
    final total = HomeScreenProvider.calculateReceiptTotal(data);
    final date = data['date_of_purchase'] is Timestamp
        ? (data['date_of_purchase'] as Timestamp).toDate()
        : null;

    final receiptOwnerId = data['userId'] as String;
    final isOwner = receiptOwnerId == widget.userId;
    final borderColor = isOwner
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
                // Optimistically remove from provider's cache
                txnProv.removeDocFromCache(doc.id, _currentCacheKey!);

                final homeProv = Provider.of<HomeScreenProvider>(
                  context,
                  listen: false,
                );
                await homeProv.deleteExpense(doc.id, context);
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
                      ).then((_) {
                        // Refresh this specific cache after edit
                        txnProv.refreshCache(_currentCacheKey!);
                      });
                    }
                  : null,
              child: IntrinsicHeight(
                child: Card(
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
                              if (txnProv.lastAddedId == doc.id)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
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
  }

  Widget _noResultsCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 4),
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