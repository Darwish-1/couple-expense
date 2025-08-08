// lib/widgets/home_screen_widgets/shared_expenses_view.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/components/common_expense_components.dart';
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

class SharedExpensesView extends StatelessWidget {
  final String userId;

  const SharedExpensesView({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SharedExpensesTotalCard(userId: userId),
        const SizedBox(height: 16),
        Text(
          'Transactions',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.indigo.shade700,
          ),
        ),
        const SizedBox(height: 8),
        _SharedExpensesTransactionList(userId: userId),
      ],
    );
  }
}

class _SharedExpensesTotalCard extends StatefulWidget {
  final String userId;

  const _SharedExpensesTotalCard({Key? key, required this.userId})
      : super(key: key);

  @override
  State<_SharedExpensesTotalCard> createState() =>
      _SharedExpensesTotalCardState();
}

class _SharedExpensesTotalCardState extends State<_SharedExpensesTotalCard> {
  late NumberFormat _currencyFormatter;
  bool _showPieChart = false;
  String? _highlightedUserId;

  @override
  void initState() {
    super.initState();
    _currencyFormatter =
        NumberFormat.currency(symbol: '\$', decimalDigits: 2);
  }

  void _toggleHighlight(String userId) {
    setState(() {
      _highlightedUserId = (_highlightedUserId == userId) ? null : userId;
    });
    // Update the transaction list filter whenever highlight changes
    final homeProv = context.read<HomeScreenProvider>();
    final authProv = context.read<AuthProvider>();
    context
        .read<TransactionListProvider>()
        .setUserFilter(
          _highlightedUserId,
          context,
          widget.userId,
          authProv.walletId,
          homeProv.showWalletReceipts,
        );
  }

  int _monthFromString(String month) {
    final m = int.tryParse(month);
    if (m != null && m >= 1 && m <= 12) return m;
    const names = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };
    return names[month.toLowerCase()] ?? DateTime.now().month;
  }

  @override
  Widget build(BuildContext context) {
    final monthProv = context.watch<MonthSelectionProvider>();
    final selectedMonth = monthProv.selectedMonth;
    final selectedYear = monthProv.selectedYear;
    final authProv = context.watch<AuthProvider>();
    final currentUserId = widget.userId;
    final walletProv = context.watch<WalletProvider>();
    final currentWallet = authProv.walletId;

    return FutureBuilder<List<DocumentSnapshot>>(
      future: context
          .read<TransactionListProvider>()
          .fetchSharedSummaryForMonth(
            selectedMonth,
            selectedYear,
            currentWallet!,
          ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final docs = snapshot.data!;

        // Compute per‐user sums
        final sums = <String, double>{};
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['userId'] as String? ?? 'Unknown';
          final amt = HomeScreenProvider.calculateReceiptTotal(data);
          sums[uid] = (sums[uid] ?? 0) + amt;
        }

        final youTotal = sums[currentUserId] ?? 0.0;
        final otherEntry = sums.entries.firstWhere(
          (e) => e.key != currentUserId,
          orElse: () => const MapEntry('Unknown', 0.0),
        );
        final partnerId = otherEntry.key;
        final partnerTotal = otherEntry.value;
        final partnerName = walletProv.partnerName;

        return Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // —————— Toggle Pie vs Totals ——————
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _showPieChart = !_showPieChart),
                    child: _showPieChart
                        ? Icon(Icons.bar_chart,
                            color: Colors.indigo.shade700)
                        : Text(
                            'Pie',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                  ),
                ],
              ),

              // —————— Pie Chart Breakdown ——————
              if (_showPieChart)
                SizedBox(
                  height: 150,
                  child: (youTotal + partnerTotal) > 0
                      ? PieChart(
                          PieChartData(
                            sections: [
                              PieChartSectionData(
                                value: youTotal,
                                color: _highlightedUserId ==
                                        currentUserId
                                    ? Colors.indigo.shade900
                                    : (_highlightedUserId == null
                                        ? Colors.indigo.shade700
                                        : Colors.indigo.shade300),
                                title: 'You',
                                radius: _highlightedUserId ==
                                        currentUserId
                                    ? 65
                                    : 60,
                                titleStyle: GoogleFonts.inter(
                                  fontSize: _highlightedUserId ==
                                          currentUserId
                                      ? 14
                                      : 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (partnerTotal > 0)
                                PieChartSectionData(
                                  value: partnerTotal,
                                  color:
                                      _highlightedUserId == partnerId
                                          ? Colors.teal.shade600
                                          : (_highlightedUserId ==
                                                  null
                                              ? Colors.teal.shade400
                                              : Colors.teal.shade200),
                                  title: partnerName,
                                  radius: _highlightedUserId ==
                                          partnerId
                                      ? 65
                                      : 60,
                                  titleStyle: GoogleFonts.inter(
                                    fontSize:
                                        _highlightedUserId ==
                                                partnerId
                                            ? 14
                                            : 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        )
                      : Center(child: Text('No shared expenses')),
                )
              // —————— Big Totals View ——————
              else
                Column(
                  children: [
                    // ← Label ABOVE the number again:
                    Text(
                      _highlightedUserId != null
                          ? (_highlightedUserId == currentUserId
                              ? 'Your spending'
                              : '$partnerName\'s spending')
                          : 'Combined spending',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _currencyFormatter.format(
                        _highlightedUserId == currentUserId
                            ? youTotal
                            : partnerTotal,
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _highlightedUserId ==
                                currentUserId
                            ? Colors.indigo.shade700
                            : Colors.teal.shade400,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // —————— “You” / “Partner” Segments ——————
              Row(
                children: [
                  Expanded(
                    child: _buildUserSegment(
                      context,
                      label: 'You',
                      userId: currentUserId,
                      total: youTotal,
                      color: Colors.indigo.shade700,
                      isHighlighted:
                          _highlightedUserId == currentUserId,
                      onTap: () => _toggleHighlight(currentUserId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (partnerTotal > 0)
                    Expanded(
                      child: _buildUserSegment(
                        context,
                        label: partnerName,
                        userId: partnerId,
                        total: partnerTotal,
                        color: Colors.teal.shade400,
                        isHighlighted:
                            _highlightedUserId == partnerId,
                        onTap: () => _toggleHighlight(partnerId),
                      ),
                    ),
                ],
              ),
            ]),
          ),
        );
      },
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
      cardColor = Colors.grey.shade50;
      textColor = color.withOpacity(0.5);
    }

    return Hero(
      tag: 'shared-segment-$userId',
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
              padding: const EdgeInsets.symmetric(
                  vertical: 12, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: isHighlighted ? 14 : 12,
                      fontWeight: FontWeight.w600,
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

class _SharedExpensesTransactionList extends StatelessWidget {
  final String userId;

  const _SharedExpensesTransactionList({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MonthSelectionProvider>(
      builder: (context, monthProv, _) {
        final selectedMonth = monthProv.selectedMonth;
        final selectedYear = monthProv.selectedYear;
        final authProv = context.watch<AuthProvider>();
        final currentWallet = authProv.walletId;
        final txnProv = context.watch<TransactionListProvider>();
        final filterUserId = txnProv.selectedUserFilter;

        return CommonTransactionListWrapper(
          selectedMonth: selectedMonth,
          selectedYear: selectedYear,
          userId: userId,
          title: '$selectedMonth $selectedYear - Shared Transactions',
          showShared: true,
          walletId: currentWallet,
          filterUserId: filterUserId,
        );
      },
    );
  }
}
