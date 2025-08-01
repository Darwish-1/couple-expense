import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/screens/edit_receipt_screen.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TransactionList extends StatefulWidget {
  final String userId;

  const TransactionList({super.key, required this.userId});

  @override
  _TransactionListState createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  final ScrollController _scrollController = ScrollController();
  late NumberFormat _currencyFormatter;
  late NumberFormat _itemPriceFormatter;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'EGP ',
      decimalDigits: 0,
    );
    _itemPriceFormatter = NumberFormat.currency(
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

  @override
  Widget build(BuildContext context) {
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

        Widget mainContent;

        if (selectorData.showWalletReceipts && authProvider.walletId == null) {
          mainContent = SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade400),
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
        } else if (selectorData.allDocs.isEmpty && (selectorData.isLoadingMore || selectorData.isLoadingStream)) {
          mainContent = const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          );
        } else {
          final docs = selectorData.allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return HomeScreenProvider.matchesSearch(selectorData.searchQuery, data);
          }).toList();

          if (docs.isEmpty) {
            mainContent = SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      selectorData.searchQuery.isEmpty
                          ? (selectorData.selectedUserFilter == null
                              ? 'No expenses recorded.'
                              : 'No expenses for this user.')
                          : 'No results for "${selectorData.searchQuery}".',
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
          } else {
            mainContent = RefreshIndicator(
              onRefresh: () async {
                homeScreenProvider.initializeStream(context, widget.userId);
              },
              color: Colors.indigo.shade700,
              child: Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectorData.showWalletReceipts ? 'Shared Transactions' : 'My Transactions',
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
                        itemCount: docs.length + (selectorData.isLoadingMore && selectorData.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == docs.length) {
                            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
                          }

                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final itemNames = (data['item_name'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                          final unitPrices = (data['unit_price'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [];
                          final date = (data['date_of_purchase'] is Timestamp)
                              ? DateFormat('MMM dd').format((data['date_of_purchase'] as Timestamp).toDate())
                              : (data['date_of_purchase'] ?? 'N/A');
                          final category = data['category'] ?? 'N/A';
                          final total = HomeScreenProvider.calculateReceiptTotal(data);

                          String displayTitle = category;
                          String itemListString = '';
                          if (itemNames.isNotEmpty) {
                            itemListString = List.generate(
                              itemNames.length,
                              (i) => '${itemNames[i]}(${_itemPriceFormatter.format(unitPrices.length > i ? unitPrices[i] : 0)})',
                            ).join(', ');
                          }

                          debugPrint('Transaction item: id=${doc.id}, category=$category, items=$itemListString, total=$total, itemNames=$itemNames, unitPrices=$unitPrices, isGrouped=${itemNames.length > 1}, locale=${_itemPriceFormatter.locale}');

                          return Animate(
                            effects: const [
                              FadeEffect(duration: Duration(milliseconds: 150)),
                              ScaleEffect(begin: Offset(1.1, 1.1), end: Offset(1, 1), duration: Duration(milliseconds: 150)),
                            ],
                            child: Dismissible(
                              key: ValueKey(doc.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                color: Colors.red.shade600,
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    title: Text(
                                      'Delete Expense?',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                    ),
                                    content: Text(
                                      'This action cannot be undone.',
                                      style: GoogleFonts.inter(fontSize: 14),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.inter(color: Colors.grey.shade600),
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          'Delete',
                                          style: GoogleFonts.inter(color: Colors.white),
                                        ),
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
                                    SnackBar(
                                      content: Text(
                                        'Expense deleted',
                                        style: GoogleFonts.inter(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.green.shade600,
                                    ),
                                  );
                                } catch (e) {
                                  authProvider.showError(context);
                                  debugPrint('Error deleting expense: $e');
                                }
                              },
                              child: Hero(
                                tag: 'transaction-${doc.id}',
                                child: Material(
                                  color: Colors.white,
                                  child: InkWell(
                                    onTap: () {
                                      debugPrint('Tapped transaction: id=${doc.id}');
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
                                    child: IntrinsicHeight(
                                      child: Card(
                                        color: Colors.white,
                                        elevation: 1,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                                    if (itemListString.isNotEmpty)
                                                      Text(
                                                        itemListString,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600,
                                                          color: Colors.grey.shade800,
                                                        ),
                                                        maxLines: 2,
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
                                                    _currencyFormatter.format(total),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.amber.shade600,
                                                    ),
                                                  ),
                                                  Text(
                                                    date,
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          children: [
            mainContent,
            if (selectorData.isRecording || selectorData.isProcessing)
              const RecordingSection(),
            if (selectorData.showSuccessPopup)
              SuccessPopUp(savedCount: selectorData.savedExpensesCount),
          ],
        );
      },
    );
  }
}