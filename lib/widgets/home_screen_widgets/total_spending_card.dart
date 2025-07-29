import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';

class TotalSpendingCard extends StatefulWidget {
  final String userId;

  const TotalSpendingCard({super.key, required this.userId});

  @override
  State<TotalSpendingCard> createState() => _TotalSpendingCardState();
}

class _TotalSpendingCardState extends State<TotalSpendingCard> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Selector<HomeScreenProvider, ({bool showWalletReceipts, String? selectedUserFilter, Map<String, double> totalByUser})>(
      selector: (_, provider) => (
        showWalletReceipts: provider.showWalletReceipts,
        selectedUserFilter: provider.selectedUserFilter,
        totalByUser: provider.totalByUser,
      ),
      builder: (context, selectorData, _) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final homeScreenProvider = Provider.of<HomeScreenProvider>(context, listen: false);
        final walletId = authProvider.walletId;
        final currentUserId = authProvider.user?.uid ?? '';

        Stream<QuerySnapshot> getExpensesStream() {
          if (selectorData.showWalletReceipts && walletId != null) {
            Query<Map<String, dynamic>> query = FirebaseFirestore.instance
                .collection('receipts')
                .where('walletId', isEqualTo: walletId);
            if (selectorData.selectedUserFilter != null) {
              query = query.where('userId', isEqualTo: selectorData.selectedUserFilter);
            }
            return query.snapshots();
          } else {
            return FirebaseFirestore.instance
                .collection('receipts')
                .where('userId', isEqualTo: widget.userId)
                .snapshots();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: getExpensesStream(),
          builder: (context, snapshot) {
            double totalSpending = 0.0;
            int numberOfExpenses = 0;

            if (snapshot.hasData) {
              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalSpending += HomeScreenProvider.calculateReceiptTotal(data);
                numberOfExpenses++;
              }
            }

            return Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.teal, size: 32),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Text(
                            selectorData.showWalletReceipts
                                ? (selectorData.selectedUserFilter == null
                                    ? "Shared Spending:"
                                    : "Filtered Spending:")
                                : "My Spending:",
                            style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (selectorData.selectedUserFilter != null)
                          GestureDetector(
                            onTap: () => homeScreenProvider.setUserFilter(null, context),
                            child: Chip(
                              label: const Text('Reset', style: TextStyle(fontSize: 12, color: Colors.white)),
                              backgroundColor: Colors.grey.shade600,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (selectorData.showWalletReceipts && selectorData.selectedUserFilter == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildUserSegment(
                            context,
                            label: 'You',
                            userId: currentUserId,
                            total: selectorData.totalByUser[currentUserId] ?? 0.0,
                            color: Colors.blue,
                            homeScreenProvider: homeScreenProvider,
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<String>(
                            future: homeScreenProvider.fetchUserDisplayName(
                              selectorData.totalByUser.keys.firstWhere((id) => id != currentUserId, orElse: () => 'Unknown'),
                            ),
                            builder: (context, snapshot) => _buildUserSegment(
                              context,
                              label: snapshot.data ?? 'Partner',
                              userId: selectorData.totalByUser.keys.firstWhere((id) => id != currentUserId, orElse: () => 'Unknown'),
                              total: selectorData.totalByUser[selectorData.totalByUser.keys.firstWhere((id) => id != currentUserId, orElse: () => 'Unknown')] ?? 0.0,
                              color: Colors.purple,
                              homeScreenProvider: homeScreenProvider,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _currencyFormatter.format(totalSpending),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      "$numberOfExpenses expenses recorded",
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
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
    required HomeScreenProvider homeScreenProvider,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => homeScreenProvider.setUserFilter(userId, context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: homeScreenProvider.selectedUserFilter == userId ? color : color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currencyFormatter.format(total),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}