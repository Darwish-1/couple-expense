import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../controllers/expenses_controller.dart';
import '../controllers/expense_summary_controller.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/expense_summary_card.dart';
import '../widgets/month_picker.dart';
import '../utils/date_utils_ext.dart';

class SharedExpensesScreen extends StatelessWidget {
  SharedExpensesScreen({super.key});


  // Expenses controller for shared view
  final ExpensesController c = (() {
    if (!Get.isRegistered<ExpensesController>(tag: 'shared')) {
      return Get.put(
        ExpensesController(collectionName: 'receipts'),
        tag: 'shared',
      );
    }
    return Get.find<ExpensesController>(tag: 'shared');
  })();

  @override
  Widget build(BuildContext context) {
        final WalletController wc = Get.find<WalletController>(); // safe now

    // Initialize shared expense summary controller
    if (!Get.isRegistered<ExpenseSummaryController>(tag: 'shared')) {
      Get.put(
        ExpenseSummaryController(expensesTag: 'shared', isSharedView: true),
        tag: 'shared',
      );
    }

    return Obx(() {
      // Wait for walletId before building
      if (wc.walletId.value == null || wc.loading.value) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final memberMap = {for (final m in wc.members) m.uid: m.name};

      return Scaffold(
        appBar: AppBar(
          title: const Text('Shared Expenses'),
          actions: const [
            // Month-only picker (also lets you set the budget start day)
            MonthPickerButton(controllerTag: 'shared', allowAnchorEdit: true),
          ],
        ),
        body: Column(
          children: [
            // Shared expense summary (shows total for all members)
            const ExpenseSummaryCard(
              summaryTag: 'shared',
              title: 'Shared Expenses This Period',
            ),

            // Show rolling window info
            Obx(() {
              final m = monthFromString(c.selectedMonth.value);
              final y = c.selectedYear.value;
              final a = c.budgetAnchorDay.value;
              final start = startOfBudgetPeriod(y, m, a);
              final end = nextStartOfBudgetPeriod(y, m, a);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Period: ${monthLabel(start.year, start.month)} ${start.day} → '
                    '${monthLabel(end.year, end.month)} ${end.day}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              );
            }),

            // Show error message if any
            Obx(() {
              if (wc.errorMessage.value.isNotEmpty) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wc.errorMessage.value,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => wc.errorMessage.value = '',
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.red.shade700,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Member list header
            Obx(() {
              if (wc.members.length <= 1) return const SizedBox.shrink();

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Members: ${wc.members.map((m) => m.name).join(', ')}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Expenses list
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: c.streamMonthForWallet(), // All wallet expenses (rolling window)
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text('Error loading shared expenses'),
                          const SizedBox(height: 8),
                          Text(
                            snap.error.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Force rebuild
                              (context as Element).markNeedsBuild();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No shared expenses this period',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Expenses added by wallet members will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) {
                      final d = docs[i].data();
                      final items =
                          (d['item_name'] as List?)?.cast<String>() ?? <String>[];
                      final prices =
                          (d['unit_price'] as List?)?.cast<num>() ?? <num>[];
                      final category = (d['category'] as String?) ?? 'General';
                      final date =
                          (d['date_of_purchase'] as Timestamp?)?.toDate();
                      final userId = d['userId'] as String?;
                      final total = prices.fold<double>(
                          0, (p, e) => p + e.toDouble());

                      // Use the map; if not found, show a nicer fallback
                      final addedByName =
                          (userId != null ? memberMap[userId] : null) ?? 'Member';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _getCategoryColor(category).withOpacity(0.2),
                            child: Icon(_getCategoryIcon(category),
                                color: _getCategoryColor(category), size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(category,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  addedByName,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (date != null)
                                Text(_formatDate(date),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600)),
                              Text(items.join(', '),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₺${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              if (items.length > 1)
                                Text('${items.length} items',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600)),
                            ],
                          ),
                          isThreeLine: date != null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Colors.orange;
      case 'transportation':
      case 'gas':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'entertainment':
        return Colors.green;
      case 'health':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Icons.restaurant;
      case 'transportation':
      case 'gas':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'health':
        return Icons.medical_services;
      default:
        return Icons.receipt;
    }
  }
}
