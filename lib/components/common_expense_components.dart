// lib/widgets/home_screen_widgets/common_expense_components.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class CommonTransactionList extends StatefulWidget {
  final String selectedMonth;
  final int selectedYear;
  final String userId;
  final bool showShared;
  final String? walletId;
  final String? filterUserId;
  final String Function() generateCacheKey;
  final Color borderColor;
  final bool allowEdit;
  final bool allowDelete;

  const CommonTransactionList({
    Key? key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.userId,
    required this.showShared,
    required this.walletId,
    required this.filterUserId,
    required this.generateCacheKey,
    required this.borderColor,
    this.allowEdit = true,
    this.allowDelete = true,
  }) : super(key: key);

  @override
  State<CommonTransactionList> createState() => _CommonTransactionListState();
}

class _CommonTransactionListState extends State<CommonTransactionList> {
  String? _currentCacheKey;

  @override
  void initState() {
    super.initState();
    _currentCacheKey = widget.generateCacheKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTransactionsLoaded();
    });
  }

  @override
  void didUpdateWidget(covariant CommonTransactionList old) {
    super.didUpdateWidget(old);
    final newCacheKey = widget.generateCacheKey();
    
    if (_currentCacheKey != newCacheKey) {
      _currentCacheKey = newCacheKey;
      _ensureTransactionsLoaded();
    }
  }

  void _ensureTransactionsLoaded() {
    final txnProv = context.read<TransactionListProvider>();
    txnProv.ensureMonthlyTransactionsLoaded(
      cacheKey: _currentCacheKey!,
      month: widget.selectedMonth,
      year: widget.selectedYear,
      userId: widget.userId,
      showShared: widget.showShared,
      walletId: widget.walletId,
      filterUserId: widget.filterUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionListProvider>(
      builder: (context, txnProv, _) {
        final transactions = txnProv.getTransactionsForCache(_currentCacheKey!);
        final isLoading = txnProv.isLoadingCache(_currentCacheKey!);

        if (isLoading && transactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Filter transactions based on type
        final filteredTransactions = widget.showShared 
            ? transactions 
            : transactions.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['userId'] == widget.userId;
              }).toList();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (filteredTransactions.isEmpty)
              CommonNoResultsCard(isShared: widget.showShared)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTransactions.length,
                itemBuilder: (ctx, i) {
                  final doc = filteredTransactions[i];
                  final data = doc.data() as Map<String, dynamic>;
                  return CommonTransactionItem(
                    doc: doc,
                    data: data,
                    userId: widget.userId,
                    borderColor: widget.showShared
                        ? _getSharedBorderColor(data, widget.userId)
                        : widget.borderColor,
                    allowEdit: widget.allowEdit && _canEdit(data),
                    allowDelete: widget.allowDelete && _canDelete(data),
                    onDelete: () => _handleDelete(doc, txnProv),
                    onEdit: () => _handleEdit(doc, data, txnProv),
                    heroTag: widget.showShared 
                        ? 'shared-transaction-${doc.id}'
                        : 'my-transaction-${doc.id}',
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Color _getSharedBorderColor(Map<String, dynamic> data, String currentUserId) {
    final receiptOwnerId = data['userId'] as String;
    return receiptOwnerId == currentUserId
        ? Colors.blue.shade400
        : Colors.green.shade400;
  }

  bool _canEdit(Map<String, dynamic> data) {
    if (!widget.showShared) return true;
    final receiptOwnerId = data['userId'] as String;
    return receiptOwnerId == widget.userId;
  }

  bool _canDelete(Map<String, dynamic> data) {
    if (!widget.showShared) return true;
    final receiptOwnerId = data['userId'] as String;
    return receiptOwnerId == widget.userId;
  }

  void _handleDelete(DocumentSnapshot doc, TransactionListProvider txnProv) async {
    txnProv.removeDocFromCache(doc.id, _currentCacheKey!);
    final homeProv = Provider.of<HomeScreenProvider>(context, listen: false);
    await homeProv.deleteExpense(doc.id, context);
  }

  void _handleEdit(
    DocumentSnapshot doc, 
    Map<String, dynamic> data, 
    TransactionListProvider txnProv
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditReceiptScreen(
          receiptId: doc.id,
          data: data,
        ),
      ),
    ).then((_) {
      txnProv.refreshCache(_currentCacheKey!);
    });
  }
}

class CommonTransactionItem extends StatelessWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> data;
  final String userId;
  final Color borderColor;
  final bool allowEdit;
  final bool allowDelete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final String heroTag;

  const CommonTransactionItem({
    Key? key,
    required this.doc,
    required this.data,
    required this.userId,
    required this.borderColor,
    required this.allowEdit,
    required this.allowDelete,
    required this.onDelete,
    required this.onEdit,
    required this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = data['category'] ?? 'N/A';
    final itemNames = (data['item_name'] is List)
        ? (data['item_name'] as List).map((e) => e.toString()).toList()
        : [data['item_name'].toString()];
    final total = HomeScreenProvider.calculateReceiptTotal(data);
    final date = data['date_of_purchase'] is Timestamp
        ? (data['date_of_purchase'] as Timestamp).toDate()
        : null;

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
        direction: allowDelete
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: allowDelete
            ? Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.red.shade600,
                child: const Icon(Icons.delete, color: Colors.white),
              )
            : null,
        onDismissed: allowDelete ? (direction) => onDelete() : null,
        child: Hero(
          tag: heroTag,
          child: Material(
            color: Colors.white,
            child: InkWell(
              onLongPress: allowEdit ? onEdit : null,
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
                              Consumer<TransactionListProvider>(
                                builder: (context, txnProv, _) {
                                  if (txnProv.lastAddedId == doc.id) {
                                    return Container(
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
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
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
}

class CommonNoResultsCard extends StatelessWidget {
  final bool isShared;

  const CommonNoResultsCard({
    Key? key,
    required this.isShared,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isShared ? Icons.people : Icons.receipt_long,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              isShared
                  ? 'No shared expenses recorded for this month.'
                  : 'No personal expenses recorded for this month.',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isShared
                  ? 'Try recording a new shared expense.'
                  : 'Try recording a new expense.',
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

class CommonTransactionListWrapper extends StatelessWidget {
  final String selectedMonth;
  final int selectedYear;
  final String userId;
  final String title;
  final bool showShared;
  final String? walletId;
  final String? filterUserId;

  const CommonTransactionListWrapper({
    Key? key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.userId,
    required this.title,
    required this.showShared,
    this.walletId,
    this.filterUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(height: 8),
            CommonTransactionList(
              key: ValueKey(_generateKey()),
              selectedMonth: selectedMonth,
              selectedYear: selectedYear,
              userId: userId,
              showShared: showShared,
              walletId: walletId,
              filterUserId: filterUserId,
              generateCacheKey: _generateCacheKey,
              borderColor: Colors.blue.shade400,
            ),
          ],
        ),
      ),
    );
  }

  String _generateKey() {
    final prefix = showShared ? 'shared' : 'my';
    return '${prefix}_${userId}_${selectedMonth}_${selectedYear}_'
           '${walletId ?? 'noWallet'}_${filterUserId ?? 'noFilter'}';
  }

  String _generateCacheKey() {
    final prefix = showShared ? 'shared' : 'personal';
    return '$userId-$prefix-${walletId ?? 'nowallet'}-'
           '${filterUserId ?? 'nofilter'}-$selectedMonth-$selectedYear';
  }
}