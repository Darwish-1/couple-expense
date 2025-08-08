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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Recent Transactions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 12),
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

class _SharedExpensesTotalCardState extends State<_SharedExpensesTotalCard>
    with TickerProviderStateMixin {
  late NumberFormat _currencyFormatter;
  String? _highlightedUserId;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _currencyFormatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _toggleHighlight(String userId) {
    setState(() {
      _highlightedUserId = (_highlightedUserId == userId) ? null : userId;
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
    
    final homeProv = context.read<HomeScreenProvider>();
    final authProv = context.read<AuthProvider>();
    context.read<TransactionListProvider>().setUserFilter(
          _highlightedUserId,
          context,
          widget.userId,
          authProv.walletId,
          homeProv.showWalletReceipts,
        );
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
          return _buildLoadingCard();
        }
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
        final docs = snapshot.data!;

        final sums = <String, double>{};
        int totalTransactions = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final uid = data['userId'] as String? ?? 'Unknown';
          final amt = HomeScreenProvider.calculateReceiptTotal(data);
          sums[uid] = (sums[uid] ?? 0) + amt;
          totalTransactions++;
        }

        final youTotal = sums[currentUserId] ?? 0.0;
        final otherEntry = sums.entries.firstWhere(
          (e) => e.key != currentUserId,
          orElse: () => const MapEntry('Unknown', 0.0),
        );
        final partnerId = otherEntry.key;
        final partnerTotal = otherEntry.value;
        final partnerName = walletProv.partnerName;
        final totalSpent = youTotal + partnerTotal;
        final youPercentage = totalSpent > 0 ? (youTotal / totalSpent) * 100 : 50.0;
        final partnerPercentage = totalSpent > 0 ? (partnerTotal / totalSpent) * 100 : 50.0;

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutCubic,
          )),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[50]!,
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(selectedMonth, selectedYear.toString()),
                  const SizedBox(height: 24),
                  _buildMainMetrics(totalSpent, totalTransactions),
                  const SizedBox(height: 24),
                  _buildProgressIndicator(youTotal, partnerTotal, youPercentage, partnerPercentage),
                  const SizedBox(height: 20),
                  _buildUserCards(
                    youTotal,
                    partnerTotal,
                    youPercentage,
                    partnerPercentage,
                    currentUserId,
                    partnerId,
                    partnerName,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[400], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load data',
              style: GoogleFonts.inter(
                color: Colors.red[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String selectedMonth, String selectedYear) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared Expenses',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$selectedMonth $selectedYear',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500],
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.blue[600],
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildMainMetrics(double totalSpent, int totalTransactions) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Spent',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.05),
                    child: Text(
                      _currencyFormatter.format(totalSpent),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[800],
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_outlined,
                size: 14,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '$totalTransactions transactions',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(double youTotal, double partnerTotal, double youPercentage, double partnerPercentage) {
    if (youTotal + partnerTotal == 0) return const SizedBox.shrink();
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Spending Split',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${youPercentage.toInt()}% • ${partnerPercentage.toInt()}%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.grey[200],
          ),
          child: Row(
            children: [
              if (youPercentage > 0)
                Expanded(
                  flex: youPercentage.round(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        bottomLeft: Radius.circular(3),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[400]!,
                          Colors.blue[500]!,
                        ],
                      ),
                    ),
                  ),
                ),
              if (partnerPercentage > 0)
                Expanded(
                  flex: partnerPercentage.round(),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(3),
                        bottomRight: Radius.circular(3),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal[400]!,
                          Colors.teal[500]!,
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCards(
    double youTotal,
    double partnerTotal,
    double youPercentage,
    double partnerPercentage,
    String currentUserId,
    String partnerId,
    String partnerName,
  ) {
    return Row(
      children: [
        Expanded(
          child: _ModernUserCard(
            label: 'You',
            total: youTotal,
            percentage: youPercentage,
            primaryColor: Colors.blue,
            isHighlighted: _highlightedUserId == currentUserId,
            onTap: () => _toggleHighlight(currentUserId),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModernUserCard(
            label: partnerName,
            total: partnerTotal,
            percentage: partnerPercentage,
            primaryColor: Colors.teal,
            isHighlighted: _highlightedUserId == partnerId,
            onTap: () => _toggleHighlight(partnerId),
          ),
        ),
      ],
    );
  }
}

class _ModernUserCard extends StatelessWidget {
  final String label;
  final double total;
  final double percentage;
  final MaterialColor primaryColor;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _ModernUserCard({
    required this.label,
    required this.total,
    required this.percentage,
    required this.primaryColor,
    required this.isHighlighted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted ? primaryColor[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlighted ? primaryColor[300]! : Colors.grey[200]!,
            width: isHighlighted ? 1.5 : 1,
          ),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: primaryColor[200]!.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHighlighted ? primaryColor[100] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    size: 14,
                    color: isHighlighted ? primaryColor[600] : Colors.grey[600],
                  ),
                ),
                if (percentage > 0)
                  Text(
                    '${percentage.toInt()}%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted ? primaryColor[600] : Colors.grey[500],
                      letterSpacing: -0.1,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isHighlighted ? primaryColor[700] : Colors.grey[600],
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(total),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isHighlighted ? primaryColor[800] : Colors.grey[800],
                letterSpacing: -0.5,
                height: 1.1,
              ),
            ),
          ],
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