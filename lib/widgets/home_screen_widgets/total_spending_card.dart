// lib/screens/total_spending_card.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TotalSpendingCard extends StatefulWidget {
  final String userId;
  const TotalSpendingCard({super.key, required this.userId});

  @override
  State<TotalSpendingCard> createState() => _TotalSpendingCardState();
}

class _TotalSpendingCardState extends State<TotalSpendingCard> {
  late NumberFormat _currencyFormatter;
  bool _showPieChart = false;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(
      locale: 'en_US',
      symbol: 'EGP ',
      decimalDigits: 2,
    );
  }

  int _monthFromString(String month) {
    final m = int.tryParse(month);
    if (m != null && m >= 1 && m <= 12) return m;
    const names = {
      'january': 1, 'february': 2, 'march': 3, 'april': 4,
      'may': 5, 'june': 6, 'july': 7, 'august': 8,
      'september': 9, 'october': 10, 'november': 11, 'december': 12,
    };
    return names[month.toLowerCase()] ?? DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final homeProv      = context.watch<HomeScreenProvider>();
    final txnProv       = context.watch<TransactionListProvider>();
    final authProv      = context.watch<AuthProvider>();
    final walletProv    = context.watch<WalletProvider>();
    final walletId      = authProv.walletId;
    final currentUserId = authProv.user?.uid ?? '';

    final monthProv    = context.watch<MonthSelectionProvider>();
    final monthNum     = _monthFromString(monthProv.selectedMonth);
    final year         = monthProv.selectedYear;
    final startOfMonth = DateTime(year, monthNum, 1);
    final endOfMonth   = DateTime(year, monthNum + 1, 0, 23, 59, 59);

    Stream<QuerySnapshot> getExpensesStream() {
      var query = FirebaseFirestore.instance
          .collection('receipts')
          .where('date_of_purchase',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date_of_purchase',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth));

      if (homeProv.showWalletReceipts && walletId != null) {
        query = query.where('walletId', isEqualTo: walletId);
        if (txnProv.selectedUserFilter != null) {
          query =
              query.where('userId', isEqualTo: txnProv.selectedUserFilter);
        }
      } else {
        query = query.where('userId', isEqualTo: widget.userId);
      }

      return query.orderBy('date_of_purchase', descending: true).snapshots();
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ─── Header ───────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                homeProv.showWalletReceipts
                    ? (txnProv.selectedUserFilter == null
                        ? 'Shared Spending'
                        : 'Filtered Spending')
                    : 'My Spending',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade700,
                ),
              ),
              if (homeProv.showWalletReceipts &&
                  txnProv.selectedUserFilter == null)
                FilterChip(
                  label: Text(
                    _showPieChart ? 'Show Segments' : 'Show Chart',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: Colors.indigo.shade700,
                  selected: _showPieChart,
                  onSelected: (sel) => setState(() => _showPieChart = sel),
                  tooltip: _showPieChart
                      ? 'Switch to segment view'
                      : 'Switch to pie chart view',
                ).animate().scale(duration: 200.ms),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Data Stream ───────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: getExpensesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: 150,
                  child: Center(
                      child:
                          CircularProgressIndicator(color: Colors.indigo)),
                );
              }
              if (snapshot.hasError) {
                return const SizedBox(
                  height: 150,
                  child: Center(
                    child: Text('Error loading data',
                        style: TextStyle(fontSize: 14, color: Colors.red)),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final count = docs.length;
              double total = 0;
              for (var d in docs) {
                total += HomeScreenProvider.calculateReceiptTotal(
                    d.data() as Map<String, dynamic>);
              }

              // ─── Shared & no filter ───────────────────────────
              if (homeProv.showWalletReceipts &&
                  txnProv.selectedUserFilter == null) {
                // 1) compute totals by user
                final sums = <String, double>{};
                for (var d in docs) {
                  final data = d.data() as Map<String, dynamic>;
                  final uid = data['userId'] as String? ?? 'Unknown';
                  final amt =
                      HomeScreenProvider.calculateReceiptTotal(data);
                  sums[uid] = (sums[uid] ?? 0) + amt;
                }
                final youTotal = sums[currentUserId] ?? 0.0;
                final other = sums.entries.firstWhere(
                  (e) => e.key != currentUserId,
                  orElse: () => const MapEntry('Unknown', 0.0),
                );
                final partnerId    = other.key;
                final partnerTotal = other.value;

                // 2) synchronous lookup from WalletProvider.memberData
               final partnerName = walletProv.partnerName;

                // ─ Pie Chart ─────────────────────────────────────
                if (_showPieChart) {
                  final hasAny = (youTotal + partnerTotal) > 0;
                  return SizedBox(
                    height: 150,
                    child: hasAny
                        ? PieChart(
                            PieChartData(
                              sections: [
                                PieChartSectionData(
                                  value: youTotal,
                                  color: Colors.indigo.shade700,
                                  title: 'You',
                                  radius: 60,
                                  titleStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (partnerTotal > 0)
                                  PieChartSectionData(
                                    value: partnerTotal,
                                    color: Colors.teal.shade400,
                                    title: partnerName,
                                    radius: 60,
                                    titleStyle: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                              ],
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          )
                        : const Center(
                            child: Text('No spending data',
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey)),
                          ),
                  );
                }

                // ─ Segmented View ───────────────────────────────
                return ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 100, maxHeight: 150),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildUserSegment(
                          context,
                          label: 'You',
                          userId: currentUserId,
                          total: youTotal,
                          color: Colors.indigo.shade700,
                          onTap: () => txnProv.setUserFilter(
                            currentUserId,
                            context,
                            authProv.user!.uid,
                            authProv.walletId,
                            homeProv.showWalletReceipts,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildUserSegment(
                          context,
                          label: partnerName,
                          userId: partnerId,
                          total: partnerTotal,
                          color: Colors.teal.shade400,
                          onTap: () => txnProv.setUserFilter(
                            partnerId,
                            context,
                            authProv.user!.uid,
                            authProv.walletId,
                            homeProv.showWalletReceipts,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ─── Personal or Filtered ─────────────────────────
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currencyFormatter.format(total),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count expenses',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (txnProv.selectedUserFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: GestureDetector(
                        onTap: () => txnProv.setUserFilter(
                          null,
                          context,
                          authProv.user!.uid,
                          authProv.walletId,
                          homeProv.showWalletReceipts,
                        ),
                        child: Chip(
                          label: Text(
                            'Clear Filter',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white),
                          ),
                          backgroundColor: Colors.indigo.shade700,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildUserSegment(
    BuildContext context, {
    required String label,
    required String userId,
    required double total,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Hero(
      tag: 'segment-$userId',
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          color: Colors.white,
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 4),
                Text(_currencyFormatter.format(total),
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
