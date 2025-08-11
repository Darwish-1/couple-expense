// lib/widgets/month_picker.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/expenses_controller.dart';
import '../utils/date_utils_ext.dart';

/// A compact button you can drop in an AppBar to open the month picker.
/// It shows the currently selected month/year from the tagged ExpensesController.
class MonthPickerButton extends StatelessWidget {
  const MonthPickerButton({
    super.key,
    required this.controllerTag,
    this.allowAnchorEdit = true,
  });

  final String controllerTag;
  final bool allowAnchorEdit;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ExpensesController>(tag: controllerTag);

    return Obx(() {
      final label = '${c.selectedMonth.value} ${c.selectedYear.value}';
      return TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: () =>
            showMonthPickerDialog(context, controllerTag, allowAnchorEdit: allowAnchorEdit),
        icon: const Icon(Icons.date_range),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    });
  }
}

/// Opens a dialog that lets the user:
/// - Pick a month (no days)
/// - Pick a year (via chevrons)
/// - Set the "budget starts on" day (1..31)
Future<void> showMonthPickerDialog(
  BuildContext context,
  String controllerTag, {
  bool allowAnchorEdit = true,
}) async {
  final c = Get.find<ExpensesController>(tag: controllerTag);

  int tempYear = c.selectedYear.value;
  int tempMonth = monthFromString(c.selectedMonth.value); // 1..12
  int tempAnchor = c.budgetAnchorDay.value; // 1..31

  String monthName(int m) => getMonthName(m);
  final months = List<String>.generate(12, (i) => monthName(i + 1));

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Select month'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            // keep dialog content nicely sized on all screens
            maxWidth: 440,
            // let dialog compute height; no viewports with intrinsic sizes inside
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year chooser
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Previous year',
                      onPressed: () => ctx.setState(() => tempYear--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$tempYear',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      tooltip: 'Next year',
                      onPressed: () => ctx.setState(() => tempYear++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Month choices — use Wrap/ChoiceChip (NO GridView/Viewport)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(12, (i) {
                      final isSelected = (i + 1) == tempMonth;
                      return ChoiceChip(
                        label: Text(months[i]),
                        selected: isSelected,
                        onSelected: (_) => ctx.setState(() => tempMonth = i + 1),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // Budget anchor day selector
                if (allowAnchorEdit) ...[
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('Budget starts on'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: tempAnchor,
                        items: List<DropdownMenuItem<int>>.generate(
                          31,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('${i + 1}${_ordinal(i + 1)}'),
                          ),
                        ),
                        onChanged: (v) => ctx.setState(() => tempAnchor = v ?? tempAnchor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Period preview
                  Builder(builder: (_) {
                    final previewStart = startOfBudgetPeriod(tempYear, tempMonth, tempAnchor);
                    final previewEnd = nextStartOfBudgetPeriod(tempYear, tempMonth, tempAnchor);
                    final preview =
                        '${monthLabel(previewStart.year, previewStart.month)} ${previewStart.day} → '
                        '${monthLabel(previewEnd.year, previewEnd.month)} ${previewEnd.day}';
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Period: $preview',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              // Apply selection
              c.selectedYear.value = tempYear;
              c.selectedMonth.value = monthName(tempMonth);

              // If the anchor changed, persist it on the wallet
              if (allowAnchorEdit && tempAnchor != c.budgetAnchorDay.value) {
                await c.setBudgetAnchorDay(tempAnchor);
              }

              // Streams & summary react automatically
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}

extension _StatefulDialogExt on BuildContext {
  void setState(VoidCallback fn) {
    // Helper to call setState inside showDialog's builder without StatefulBuilder.
    // It works because AlertDialog content is rebuilt via Element.markNeedsBuild()
    // when we use this extension; if you ever see it not updating, fall back to StatefulBuilder.
    (this as Element).markNeedsBuild();
    fn();
  }
}

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return 'th';
  switch (n % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}
