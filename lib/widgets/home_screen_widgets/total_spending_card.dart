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
  String? _highlightedUserId; // Track which user segment is highlighted

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

  void _toggleHighlight(String userId) {
    setState(() {
      _highlightedUserId = _highlightedUserId == userId ? null : userId;
    });
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
        // Remove the user filter logic since we're handling highlighting locally
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
                    ? (_highlightedUserId != null 
                        ? (_highlightedUserId == currentUserId ? 'Your Spending' : '${walletProv.partnerName}\'s Spending')
                        : 'Shared Spending')
                    : 'My Spending',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.indigo.shade700,
                ),
              ),
              if (homeProv.showWalletReceipts)
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

              // ─── Shared spending view ─────────────────────────
              if (homeProv.showWalletReceipts) {
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
                                  color: _highlightedUserId == currentUserId 
                                      ? Colors.indigo.shade900 
                                      : (_highlightedUserId == null 
                                          ? Colors.indigo.shade700 
                                          : Colors.indigo.shade300),
                                  title: 'You',
                                  radius: _highlightedUserId == currentUserId ? 65 : 60,
                                  titleStyle: GoogleFonts.inter(
                                      fontSize: _highlightedUserId == currentUserId ? 14 : 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (partnerTotal > 0)
                                  PieChartSectionData(
                                    value: partnerTotal,
                                    color: _highlightedUserId == partnerId 
                                        ? Colors.teal.shade600 
                                        : (_highlightedUserId == null 
                                            ? Colors.teal.shade400 
                                            : Colors.teal.shade200),
                                    title: partnerName,
                                    radius: _highlightedUserId == partnerId ? 65 : 60,
                                    titleStyle: GoogleFonts.inter(
                                        fontSize: _highlightedUserId == partnerId ? 14 : 12,
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
                      const BoxConstraints(minHeight: 100, maxHeight: 180),
                  child: Column(
                    children: [
                      // Show total for highlighted user if any
                      if (_highlightedUserId != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: (_highlightedUserId == currentUserId 
                                ? Colors.indigo.shade700 
                                : Colors.teal.shade400).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _highlightedUserId == currentUserId 
                                  ? Colors.indigo.shade700 
                                  : Colors.teal.shade400,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _highlightedUserId == currentUserId ? 'Your Total' : '${walletProv.partnerName}\'s Total',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _currencyFormatter.format(
                                  _highlightedUserId == currentUserId ? youTotal : partnerTotal
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: _highlightedUserId == currentUserId 
                                      ? Colors.indigo.shade700 
                                      : Colors.teal.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // User segments
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildUserSegment(
                                context,
                                label: 'You',
                                userId: currentUserId,
                                total: youTotal,
                                color: Colors.indigo.shade700,
                                isHighlighted: _highlightedUserId == currentUserId,
                                onTap: () => _toggleHighlight(currentUserId),
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
                                isHighlighted: _highlightedUserId == partnerId,
                                onTap: () => _toggleHighlight(partnerId),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ─── Personal spending ───────────────────────────
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
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    // Determine colors based on highlight state
    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    double elevation = 1;
    Color textColor = color;
    
    if (isHighlighted) {
      cardColor = color.withOpacity(0.1);
      borderColor = color;
      elevation = 3;
      textColor = color.withOpacity(0.9);
    } else if (_highlightedUserId != null && !isHighlighted) {
      // Dim the non-highlighted segment
      cardColor = Colors.grey.shade50;
      textColor = color.withOpacity(0.5);
    }

    return Hero(
      tag: 'segment-$userId',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Card(
            color: cardColor,
            elevation: elevation,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: borderColor,
                width: isHighlighted ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currencyFormatter.format(total),
                    style: GoogleFonts.inter(
                      fontSize: isHighlighted ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
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