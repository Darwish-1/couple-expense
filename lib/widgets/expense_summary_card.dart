// lib/widgets/expense_summary_card.dart

import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/expense_summary_controller.dart';

class ExpenseSummaryCard extends StatelessWidget {
  const ExpenseSummaryCard({
    super.key,

    this.title = 'This Month',

    required this.summaryTag,

    this.currency = '₺', // change to your currency if you want
  });

  /// The tag you used when creating ExpenseSummaryController (e.g. "my")

  final String summaryTag;

  final String title;

  final String currency;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ExpenseSummaryController>(tag: summaryTag);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),

      elevation: 1,

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Obx(() {
          final total = c.totalThisMonth.value;

          final budget = c.budgetThisMonth.value;

          final remaining = c.remaining;

          final progress = c.progress;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // Header row
              Row(
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),

                  const Spacer(),

                  IconButton(
                    tooltip: 'Set budget',

                    icon: const Icon(Icons.edit),

                    onPressed: () async {
                      final controller = TextEditingController(
                        text: budget > 0 ? budget.toStringAsFixed(2) : '',
                      );

                      final newAmount = await showDialog<double>(
                        context: context,

                        builder: (ctx) => AlertDialog(
                          title: const Text('Set Monthly Budget'),

                          content: TextField(
                            controller: controller,

                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),

                            decoration: const InputDecoration(
                              hintText: 'e.g. 20000',

                              prefixIcon: Icon(Icons.account_balance_wallet),
                            ),
                          ),

                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),

                            FilledButton(
                              onPressed: () {
                                final raw = controller.text.trim();

                                final val = double.tryParse(raw);

                                Navigator.pop(ctx, val);
                              },

                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );

                      if (newAmount != null) {
                        await c.setBudget(newAmount);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Totals row
              Row(
                children: [
                  _metric(context, 'Spent', '$currency ${_fmt(total)}'),

                  const SizedBox(width: 16),

                  _metric(
                    context,
                    'Budget',
                    budget > 0 ? '$currency ${_fmt(budget)}' : '--',
                  ),

                  const SizedBox(width: 16),

                  _metric(
                    context,

                    remaining >= 0 ? 'Left' : 'Over',

                    '$currency ${_fmt(remaining.abs())}',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),

                child: LinearProgressIndicator(
                  value: budget > 0 ? progress : 0,
                ),
              ),

              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    budget <= 0
                        ? 'No budget set'
                        : '${(progress * 100).toStringAsFixed(0)}% of budget used',

                    style: Theme.of(context).textTheme.bodySmall,
                  ),

                  if (budget > 0)
                    Text(
                      remaining >= 0 ? 'Remaining' : 'Over by',

                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),

              if (c.budgetError.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),

                  child: Text(
                    c.budgetError.value,

                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                ),

              if (c.budgetInfo.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),

                  child: Text(
                    c.budgetInfo.value,

                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: Colors.grey[600]),
          ),

          const SizedBox(height: 2),

          Text(
            value,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}
