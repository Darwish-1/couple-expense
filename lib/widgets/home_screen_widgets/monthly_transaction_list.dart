// lib/screens/monthly_transaction_list.dart

import 'package:couple_expenses/components/common_expense_components.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/month_selection_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MonthlyTransactionList extends StatelessWidget {
  final String userId;

  const MonthlyTransactionList({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
        print('🏠 [DEBUG] MonthlyTransactionList building for userId: $userId');

    return Consumer<MonthSelectionProvider>(
      builder: (context, monthProv, _) {
        final selectedMonth = monthProv.selectedMonth;
        final selectedYear = monthProv.selectedYear;
        final showShared = context.watch<HomeScreenProvider>().showWalletReceipts;
        final currentWallet = context.watch<AuthProvider>().walletId;
        final txnProv = context.watch<TransactionListProvider>();
        final filterUserId = txnProv.selectedUserFilter;
        final refreshTrigger = txnProv.refreshTrigger; // ← Watch refresh trigger

        print('🏠 [DEBUG] MonthlyTransactionList Consumer rebuild');
        print('🏠 [DEBUG] - selectedMonth: $selectedMonth');
        print('🏠 [DEBUG] - selectedYear: $selectedYear');
        print('🏠 [DEBUG] - showShared: $showShared');
        print('🏠 [DEBUG] - currentWallet: $currentWallet');
        print('🏠 [DEBUG] - filterUserId: $filterUserId');
        print('🏠 [DEBUG] - refreshTrigger: $refreshTrigger');

        final cacheKey = _generateCacheKey(
          userId,
          showShared,
          currentWallet,
          filterUserId,
          selectedMonth,
          selectedYear,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          txnProv.ensureMonthlyTransactionsLoaded(
            cacheKey:      cacheKey,
            month:         selectedMonth,
            year:          selectedYear,
            userId:        userId,
            showShared:    showShared,
            walletId:      currentWallet,
            filterUserId:  filterUserId,
            forceReload:   true,
          );
        });

        
        print('🏠 [DEBUG] Generated cache key: $cacheKey');
        
        final currentCacheData = txnProv.getTransactionsForCache(cacheKey);
        print('🏠 [DEBUG] Current cache data length: ${currentCacheData.length}');

        final valueKey = '${userId}_${selectedMonth}_${selectedYear}_'
            '${showShared}_${currentWallet ?? 'noWallet'}_'
            '${filterUserId ?? 'noFilter'}_$refreshTrigger';
            
        print('🏠 [DEBUG] ValueKey for CommonTransactionList: $valueKey');
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
               CommonTransactionList(
                  key: ValueKey(valueKey),
                  selectedMonth: selectedMonth,
                  selectedYear: selectedYear,
                  userId: userId,
                  showShared: showShared,
                  walletId: currentWallet,
                  filterUserId: filterUserId,
                  generateCacheKey: () {
                    final key = _generateCacheKey(
                      userId,
                      showShared,
                      currentWallet,
                      filterUserId,
                      selectedMonth,
                      selectedYear,
                    );
                    print('🏠 [DEBUG] CommonTransactionList generateCacheKey called, returning: $key');
                    return key;
                  },
              //    borderColor: Colors.blue.shade400,
                ),
              ],
            ),
          ),
        
              
            
      
        );
      },
    );
  }

  
  String _generateCacheKey(
    String userId,
    bool showShared,
    String? currentWallet,
    String? filterUserId,
    String selectedMonth,
    int selectedYear,
  ) {
    final key = '$userId-'
           '${showShared ? 'shared' : 'personal'}-'
           '${currentWallet ?? 'nowallet'}-'
           '${filterUserId ?? 'nofilter'}-'
           '$selectedMonth-$selectedYear';
    print('🏠 [DEBUG] _generateCacheKey returning: $key');
    return key;
  }
}