import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TransactionList extends StatefulWidget {
  final String userId;
  const TransactionList({super.key, required this.userId});

  @override
  State<TransactionList> createState() => _TransactionListState();
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
      symbol: 'EGP ',
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
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        final transactionProvider = Provider.of<TransactionListProvider>(
          context,
          listen: false,
        );
        final homeScreenProvider = Provider.of<HomeScreenProvider>(
          context,
          listen: false,
        );
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (transactionProvider.hasMore && !transactionProvider.isLoadingMore) {
          transactionProvider.loadMoreExpenses(
            context,
            widget.userId,
            authProvider.walletId,
            homeScreenProvider.showWalletReceipts,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = context.select<HomeScreenProvider, String>(
      (p) => p.searchQuery,
    );
    final showWalletReceipts = context.select<HomeScreenProvider, bool>(
      (p) => p.showWalletReceipts,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isLoadingStream = context.select<HomeScreenProvider, bool>(
      (p) => p.isLoadingStream,
    );
    final transactionProvider = Provider.of<TransactionListProvider>(
      context,
      listen: true,
    );

    return Selector<
      TransactionListProvider,
      ({
        List<DocumentSnapshot> allDocs,
        bool isLoadingMore,
        bool hasMore,
        String? selectedUserFilter,
      })
    >(
      selector: (_, provider) => (
        allDocs: provider.allDocs,
        isLoadingMore: provider.isLoadingMore,
        hasMore: provider.hasMore,
        selectedUserFilter: provider.selectedUserFilter,
      ),
      builder: (context, selectorData, _) {
        Widget mainContent;

        if (showWalletReceipts && authProvider.walletId == null) {
          mainContent = _noWalletCard();
        } else if (selectorData.allDocs.isEmpty &&
            (selectorData.isLoadingMore ||
                isLoadingStream && !selectorData.hasMore)) {
          mainContent = const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          );
        } else {
          final docs = selectorData.allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return HomeScreenProvider.matchesSearch(searchQuery, data);
          }).toList();

          if (docs.isEmpty) {
            mainContent = _noResultsCard(
              searchQuery,
              selectorData.selectedUserFilter,
            );
          } else {
            mainContent = RefreshIndicator(
              onRefresh: () async {
                Provider.of<TransactionListProvider>(
                  context,
                  listen: false,
                ).initializeStream(
                  context,
                  widget.userId,
                  authProvider.walletId,
                  showWalletReceipts,
                );
              },
              color: Colors.indigo.shade700,
              child: Card(
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
                      Text(
                        showWalletReceipts
                            ? 'Shared Transactions'
                            : 'My Transactions',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),

                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _scrollController,
                        itemCount:
                            docs.length +
                            (selectorData.isLoadingMore && selectorData.hasMore
                                ? 1
                                : 0),
                        itemBuilder: (context, index) {
                          if (index == docs.length) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.indigo,
                              ),
                            );
                          }
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final category = data['category'] ?? 'N/A';
                          final itemNames = (data['item_name'] is List)
                              ? (data['item_name'] as List)
                                    .map((e) => e.toString())
                                    .toList()
                              : [data['item_name'].toString()];
                          final total =
                              HomeScreenProvider.calculateReceiptTotal(data);
                          final date = data['date_of_purchase'] is Timestamp
                              ? (data['date_of_purchase'] as Timestamp).toDate()
                              : null;
                          final userId = data['userId'];
                          final isOwner = userId == widget.userId;
                          final isNew =
                              doc.id == transactionProvider.lastAddedId;
                          return Animate(
                            effects: isNew
                                ? [
                                    ScaleEffect(
                                      begin: Offset(2.15, 1.15),
                      
                                      end: Offset(1, 1),
                                      duration: Duration(milliseconds: 500),
                                      curve: Curves.elasticOut,
                                    ),
                                    FadeEffect(
                                      begin: 0,
                                      end: 1,
                                      duration: Duration(milliseconds: 0),
                                    ),
                                  ]
                                : [
                                    FadeEffect(
                                      duration: Duration(milliseconds: 150),
                                    ),
                                    ScaleEffect(
                                      begin: Offset(1.1, 1.1),
                                      end: Offset(1, 1),
                                      duration: Duration(milliseconds: 150),
                                    ),
                                  ],
                            child: Dismissible(
                              key: ValueKey(doc.id),
                              direction: isOwner
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              background: isOwner
                                  ? Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      color: Colors.red.shade600,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                              onDismissed: isOwner
                                  ? (direction) async {
                                      await FirebaseFirestore.instance
                                          .collection('receipts')
                                          .doc(doc.id)
                                          .delete();
                                      Provider.of<TransactionListProvider>(
                                        context,
                                        listen: false,
                                      ).removeDoc(doc.id);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Expense deleted'),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Hero(
                                tag: 'transaction-${doc.id}',
                                child: Material(
                                  color: Colors.white,
                                  child: InkWell(
                                    onTap: isOwner
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    EditReceiptScreen(
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      category,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .indigo
                                                            .shade700,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      itemNames.join(', '),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey
                                                            .shade800,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    _currencyFormatter.format(
                                                      total,
                                                    ),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Colors.amber.shade600,
                                                    ),
                                                  ),
                                                  Text(
                                                    date != null
                                                        ? DateFormat(
                                                            'MMM dd',
                                                          ).format(date)
                                                        : 'N/A',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return mainContent;
      },
    );
  }

  Widget _noWalletCard() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No Wallet Joined',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join a wallet to view shared expenses.',
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

  Widget _noResultsCard(String searchQuery, String? selectedUserFilter) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                  ? (selectedUserFilter == null
                        ? 'No expenses recorded.'
                        : 'No expenses for this user.')
                  : 'No results for "$searchQuery".',
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
