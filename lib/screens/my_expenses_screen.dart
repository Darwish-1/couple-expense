import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/controllers/expense_summary_controller.dart';
import 'package:couple_expenses/widgets/expense_summary_card.dart';
import 'package:couple_expenses/widgets/expense_widgets.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/expenses_controller.dart';
import '../controllers/mic_controller.dart';
import '../controllers/wallet_controller.dart';

class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  late final ExpensesController c;
  late final WalletController wc;
  late final MicController mic;

  // Tiny in-memory form state
  final RxList<Map<String, dynamic>> _draft = <Map<String, dynamic>>[].obs;

  // Success popup state
  final RxInt _savedCount = 0.obs;
  final RxBool _showSuccess = false.obs;

  @override
  void initState() {
    super.initState();

    // Ensure WalletController exists
    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController(), permanent: true);
    }
    wc = Get.find<WalletController>();

    // Expenses controller for "my" tab
    if (!Get.isRegistered<ExpensesController>(tag: 'my')) {
      c = Get.put(
        ExpensesController(collectionName: 'receipts'),
        tag: 'my',
      );
    } else {
      c = Get.find<ExpensesController>(tag: 'my');
    }

    // Expense summary controller for "my" view (personal expenses only)
    if (!Get.isRegistered<ExpenseSummaryController>(tag: 'my')) {
  Get.put(
    ExpenseSummaryController(
      expensesTag: 'my',
      isSharedView: false,
    ),
    tag: 'my', // <-- this was missing
  );
}
    // Mic controller ONLY for this screen (not global)
    mic = Get.put(MicController());
  }

  @override
  void dispose() {
    // Remove the mic controller when leaving this screen
    if (Get.isRegistered<MicController>()) {
      Get.delete<MicController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Wait until walletId is available before building the StreamBuilder
      if (wc.walletId.value == null || wc.loading.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('My Expenses'),
          actions: [
            // Show wallet info
            Obx(() => Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${c.selectedMonth.value} ${c.selectedYear.value}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (wc.partnerName.value.isNotEmpty)
                      Text(
                        'with ${wc.partnerName.value}',
                        style: const TextStyle(fontSize: 10),
                      ),
                  ],
                ),
              ),
            )),
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () => _showDatePicker(context),
            ),
          ],
        ),

        // BODY + overlays stacked together
        body: Stack(
          children: [
            Column(
              children: [
                // Personal expense summary
                const ExpenseSummaryCard(
                  summaryTag: 'my', 
                  title: 'My Expenses This Month'
                ),

                // Show error message if any
                Obx(() {
                  if (wc.errorMessage.value.isNotEmpty) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              wc.errorMessage.value,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
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

                // Expenses list
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: c.streamMyMonthInWallet(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                              const SizedBox(height: 16),
                              Text('Error loading expenses'),
                              const SizedBox(height: 8),
                              Text(
                                snap.error.toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  // Force refresh
                                  setState(() {});
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
                              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses this month',
                                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Use the microphone button to add expenses quickly',
                                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final d = docs[i].data();
                          final items = (d['item_name'] as List?)?.cast<String>() ?? <String>[];
                          final prices = (d['unit_price'] as List?)?.cast<num>() ?? <num>[];
                          final category = d['category'] ?? '';
                          final date = (d['date_of_purchase'] as Timestamp?)?.toDate();
                          final total = prices.fold<double>(0, (p, e) => p + e.toDouble());
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getCategoryColor(category).withOpacity(0.2),
                              child: Icon(
                                _getCategoryIcon(category),
                                color: _getCategoryColor(category),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              category.isEmpty ? 'General' : category,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (date != null)
                                  Text(
                                    _formatDate(date),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                Text(
                                  items.join(', '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₺${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (items.length > 1)
                                  Text(
                                    '${items.length} items',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            isThreeLine: date != null,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Draft bar
                Obx(
                  () => DraftBar(
                    count: _draft.length,
                    onSave: _draft.isEmpty
                        ? null
                        : () async {
                            await c.saveMultipleExpenses(_draft.toList());
                            _draft.clear();
                          },
                    onClear: _draft.isEmpty ? null : _draft.clear,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

            // Mic recording/processing overlay
            Obx(() {
              final rec = mic.isRecording.value;
              final proc = mic.isProcessing.value;
              if (!rec && !proc) return const SizedBox.shrink();
              return MicRecordingIndicator(isRecording: rec, isProcessing: proc);
            }),

            // Success popup overlay
            Obx(
              () => _showSuccess.value
                  ? SuccessPopUp(savedCount: _savedCount.value)
                  : const SizedBox.shrink(),
            ),
          ],
        ),

        // MIC FAB
        floatingActionButton: Obx(() {
          final rec = mic.isRecording.value;
          final busy = mic.isProcessing.value;
          return FloatingActionButton.large(
            tooltip: rec ? 'Stop & add' : 'Add by voice',
            backgroundColor: rec ? Colors.red.shade400 : null,
            onPressed: busy
                ? null
                : () async {
                    if (!rec) {
                      // Start recording
                      await mic.startRecording();
                    } else {
                      // Stop, transcribe, parse, then save
                      final result = await mic.stopRecordingAndParse();
                      if (result != null && result.expenses.isNotEmpty) {
                        await c.saveMultipleExpenses(result.expenses);
                        _savedCount.value = result.expenses.length;
                        _showSuccess.value = true;
                        Future.delayed(const Duration(seconds: 2), () {
                          _showSuccess.value = false;
                        });
                      }
                    }
                  },
            child: busy 
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(rec ? Icons.stop : Icons.mic),
          );
        }),
      );
    });
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      initialDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Pick any day (we\'ll take its month/year)',
    );
    if (picked != null) {
      c.selectedMonth.value = _monthName(picked.month);
      c.selectedYear.value = picked.year;
    }
  }

  String _monthName(int m) {
    const names = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return names[m - 1];
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
