// lib/widgets/home_screen_widgets/my_expenses_view.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/components/common_expense_components.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class MyExpensesView extends StatelessWidget {
  final String userId;

  const MyExpensesView({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MyExpensesTotalCard(userId: userId),
        const SizedBox(height: 16),
        Text(
          'My Recent Expenses',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.indigo.shade700,
          ),
        ),
        const SizedBox(height: 6),
        _MyExpensesTransactionList(userId: userId),
      ],
    );
  }
}

class _MyExpensesTotalCard extends StatefulWidget {
  final String userId;
  
  const _MyExpensesTotalCard({required this.userId});

  @override
  State<_MyExpensesTotalCard> createState() => _MyExpensesTotalCardState();
}

class _MyExpensesTotalCardState extends State<_MyExpensesTotalCard> {
  late NumberFormat _currencyFormatter;

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
    final monthProv = context.watch<MonthSelectionProvider>();
    final monthNum = _monthFromString(monthProv.selectedMonth);
    final year = monthProv.selectedYear;
    final startOfMonth = DateTime(year, monthNum, 1);
    final endOfMonth = DateTime(year, monthNum + 1, 0, 23, 59, 59);

    Stream<QuerySnapshot> getMyExpensesStream() {
      return FirebaseFirestore.instance
          .collection('receipts')
          .where('userId', isEqualTo: widget.userId)
          .where('date_of_purchase',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('date_of_purchase',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date_of_purchase', descending: true)
          .snapshots();
    }

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Spending',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: getMyExpensesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.indigo),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return const SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'Error loading data',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
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
          ],
        ),
      ),
    );
  }
}

class _MyExpensesTransactionList extends StatelessWidget {
  final String userId;

  const _MyExpensesTransactionList({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonthSelectionProvider>(
      builder: (context, monthProv, _) {
        final selectedMonth = monthProv.selectedMonth;
        final selectedYear = monthProv.selectedYear;

        return CommonTransactionListWrapper(
          selectedMonth: selectedMonth,
          selectedYear: selectedYear,
          userId: userId,
          title: '$selectedMonth $selectedYear - My Transactions',
          showShared: false,
        );
      },
    );
  }
}