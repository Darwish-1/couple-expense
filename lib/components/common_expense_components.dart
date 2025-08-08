// lib/widgets/home_screen_widgets/common_expense_components.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

// --- HELPER FUNCTION FOR CATEGORY ICONS ---
// Maps category strings to Material Icons for better visual representation.
IconData _getCategoryIcon(String category) {
 switch (category.toLowerCase()) {
  case 'groceries':
 return Icons.shopping_cart;
  case 'food & dining':
 return Icons.restaurant;
  case 'transportation':
 return Icons.directions_car;
  case 'utilities':
 return Icons.lightbulb;
  case 'rent/mortgage':
 return Icons.home;
  case 'entertainment':
 return Icons.movie;
  case 'health & wellness':
 return Icons.favorite;
  case 'shopping':
 return Icons.shopping_bag;
  default:
 return Icons.receipt_long; // A generic icon for other categories
 }
}

class CommonTransactionList extends StatefulWidget {
 final String selectedMonth;
 final int selectedYear;
 final String userId;
 final bool showShared;
 final String? walletId;
 final String? filterUserId;
 final String Function() generateCacheKey;
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
 void didUpdateWidget(covariant CommonTransactionList oldWidget) {
  super.didUpdateWidget(oldWidget);
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

  final filteredTransactions = widget.showShared
  ? transactions
  : transactions.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    return data['userId'] == widget.userId;
   }).toList();

  if (filteredTransactions.isEmpty) {
   return CommonNoResultsCard(isShared: widget.showShared);
  }

  return ListView.builder(
   shrinkWrap: true,
   physics: const NeverScrollableScrollPhysics(),
   itemCount: filteredTransactions.length,
   itemBuilder: (ctx, i) {
  final doc = filteredTransactions[i];
  final data = doc.data() as Map<String, dynamic>;
  final authorId = data['userId'] as String;

  final authorName = txnProv.getUserName(authorId);

  return CommonTransactionItem(
   doc: doc,
   data: data,
   authorName: authorName,
   borderColor: _getBorderColor(data, widget.userId),
   allowEdit: widget.allowEdit && _canEditOrDelete(data),
   allowDelete: widget.allowDelete && _canEditOrDelete(data),
   onDelete: () => _handleDelete(doc, txnProv),
   onEdit: () => _handleEdit(doc, data, txnProv),
   showAuthor: widget.showShared && authorId != widget.userId,
   heroTag: widget.showShared
   ? 'shared-transaction-${doc.id}'
   : 'my-transaction-${doc.id}',
  );
   },
  );
 },
  );
 }

 Color _getBorderColor(Map<String, dynamic> data, String currentUserId) {
  final receiptOwnerId = data['userId'] as String;
  return receiptOwnerId == currentUserId
  ? Colors.blue.shade400
  : Colors.green.shade400;
 }

 bool _canEditOrDelete(Map<String, dynamic> data) {
  if (!widget.showShared) return true;
  final receiptOwnerId = data['userId'] as String;
  return receiptOwnerId == widget.userId;
 }

 void _handleDelete(DocumentSnapshot doc, TransactionListProvider txnProv) async {
  txnProv.removeDocFromCache(doc.id, _currentCacheKey!);
  final homeProv = context.read<HomeScreenProvider>();
  await homeProv.deleteExpense(doc.id, context);
 }

 void _handleEdit(
 DocumentSnapshot doc, Map<String, dynamic> data, TransactionListProvider txnProv) {
  Navigator.push(
 context,
 MaterialPageRoute(
  builder: (_) => EditReceiptScreen(receiptId: doc.id, data: data),
 ),
  ).then((_) {
 txnProv.refreshCache(_currentCacheKey!);
  });
 }
}


// --- REFACTORED: CommonTransactionItem (Minimal Version) ---
class CommonTransactionItem extends StatelessWidget {
 final DocumentSnapshot doc;
 final Map<String, dynamic> data;
 final String? authorName;
 final Color borderColor;
 final bool allowEdit;
 final bool allowDelete;
 final VoidCallback onDelete;
 final VoidCallback onEdit;
 final String heroTag;
 final bool showAuthor;

 const CommonTransactionItem({
  Key? key,
  required this.doc,
  required this.data,
  this.authorName,
  required this.borderColor,
  required this.allowEdit,
  required this.allowDelete,
  required this.onDelete,
  required this.onEdit,
  required this.heroTag,
  required this.showAuthor,
 }) : super(key: key);

 @override
 Widget build(BuildContext context) {
  final category = data['category'] ?? 'N/A';
  final itemNames = (data['item_name'] is List)
  ? (data['item_name'] as List).join(', ')
  : data['item_name'].toString();
  final total = HomeScreenProvider.calculateReceiptTotal(data);
  final date = data['date_of_purchase'] is Timestamp
  ? (data['date_of_purchase'] as Timestamp).toDate()
  : null;

  final currencyFormatter = NumberFormat.currency(
 locale: 'en_US',
 symbol: 'EGP ',
 decimalDigits: 0,
  );
  
  final isNew = context.watch<TransactionListProvider>().lastAddedId == doc.id;

  return Hero(
 tag: heroTag,
 child: Material(
  type: MaterialType.transparency,
  child: Dismissible(
   key: ValueKey(doc.id),
   direction: allowDelete ? DismissDirection.endToStart : DismissDirection.none,
   onDismissed: allowDelete ? (_) => onDelete() : null,
   background: Container(
  alignment: Alignment.centerRight,
  padding: const EdgeInsets.only(right: 24),
  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
  decoration: BoxDecoration(
   color: Colors.red.shade600,
   borderRadius: BorderRadius.circular(12),
  ),
  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
   ),
   child: InkWell(
  onLongPress: allowEdit ? onEdit : null,
  borderRadius: BorderRadius.circular(12),
 child: Container(
 margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
 decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(28),
  border: Border.all(color: Colors.grey.shade200),
  boxShadow: [
   BoxShadow(
    color: Colors.black.withOpacity(0.15), // A very light, subtle shadow
    spreadRadius: 1, // Extends the shadow slightly
    blurRadius: 8, // Creates a soft, blurred effect
    offset: const Offset(0, 4), // Shifts the shadow down
   ),
  ],
 ),
   child: Row(
    children: [
   Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
     color: borderColor.withOpacity(0.1),
     borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(_getCategoryIcon(category), size: 22, color: borderColor),
   ),
   const SizedBox(width: 16),
   Expanded(
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     mainAxisAlignment: MainAxisAlignment.center,
     children: [
    Row(
     children: [
      if (isNew)
     Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
       color: Colors.green.shade600,
       shape: BoxShape.circle,
      ),
     ),
      Text(
     category,
     style: GoogleFonts.inter(
      fontWeight: FontWeight.w600,
      color: Colors.indigo.shade800,
      fontSize: 15,
     ),
      ),
     ],
    ),
    const SizedBox(height: 4),
    Text(
     itemNames,
     maxLines: 1,
     overflow: TextOverflow.ellipsis,
     style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
    ),
    if (showAuthor)
     Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
     'by ${authorName ?? '...'}',
     style: GoogleFonts.inter(
      color: Colors.grey.shade500,
      fontSize: 11,
      fontStyle: FontStyle.italic),
      ),
     ),
     ],
    ),
   ),
   const SizedBox(width: 16),
   Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
     Text(
    currencyFormatter.format(total),
    style: GoogleFonts.inter(
     fontSize: 15,
     fontWeight: FontWeight.bold,
     color: Colors.amber.shade800,
    ),
     ),
     const SizedBox(height: 4),
     if (date != null)
    Text(
     DateFormat('MMM dd').format(date),
     style: GoogleFonts.inter(
      fontSize: 11,
      color: Colors.grey.shade500,
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
  );
 }
}


// --- REFACTORED: CommonNoResultsCard (Minimal Version) ---
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
  padding: const EdgeInsets.all(24),
  child: Column(
   mainAxisSize: MainAxisSize.min,
   children: [
  Container(
   padding: const EdgeInsets.all(16),
   decoration: BoxDecoration(
    color: Colors.grey.shade100,
    shape: BoxShape.circle,
   ),
   child: Icon(
    isShared ? Icons.people_outline : Icons.inbox_outlined,
    size: 48,
    color: Colors.grey.shade500,
   ),
  ),
  const SizedBox(height: 20),
  Text(
   isShared
   ? 'No Shared Expenses Yet'
   : 'No Personal Expenses Found',
   style: GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.grey.shade800,
   ),
   textAlign: TextAlign.center,
  ),
  const SizedBox(height: 8),
  Text(
   'Start by adding a new expense for this month.',
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


// NOTE: Wrapper component remains largely the same, but the internal
// CommonTransactionList is now visually improved.
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
 
 String _generateCacheKey() {
  final prefix = showShared ? 'shared' : 'personal';
  return '$userId-$prefix-${walletId ?? 'nowallet'}-'
 '${filterUserId ?? 'nofilter'}-$selectedMonth-$selectedYear';
 }

 @override
 Widget build(BuildContext context) {
  final refreshTrigger = context.watch<TransactionListProvider>().refreshTrigger;
  final wrapperKey = '${_generateCacheKey()}_$refreshTrigger';

  return Container(
 decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
   BoxShadow(
  color: Colors.black.withOpacity(0.04),
  spreadRadius: 0,
  blurRadius: 10,
  offset: const Offset(0, 4),
   ),
  ],
 ),
 child: Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
   mainAxisSize: MainAxisSize.min,
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
  Padding(
   padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
   child: Text(
    title,
    style: GoogleFonts.inter(
   fontSize: 18,
   fontWeight: FontWeight.bold,
   color: Colors.indigo.shade800,
    ),
   ),
  ),
  const SizedBox(height: 8),
  CommonTransactionList(
   key: ValueKey(wrapperKey),
   selectedMonth: selectedMonth,
   selectedYear: selectedYear,
   userId: userId,
   showShared: showShared,
   walletId: walletId,
   filterUserId: filterUserId,
   generateCacheKey: _generateCacheKey,
  ),
   ],
  ),
 ),
  );
 }
}