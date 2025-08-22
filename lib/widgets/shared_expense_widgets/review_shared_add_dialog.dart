import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReviewSharedAddResult {
  final List<Map<String, dynamic>> selectedPrivateItems;
  ReviewSharedAddResult({required this.selectedPrivateItems});
}

Future<ReviewSharedAddResult?> showReviewSharedAddDialog({
  required BuildContext context,
  required List<Map<String, dynamic>> parsedItems,
}) {
  return showDialog<ReviewSharedAddResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _ReviewSharedAddDialog(parsedItems: parsedItems);
    },
  );
}

class _ReviewSharedAddDialog extends StatefulWidget {
  final List<Map<String, dynamic>> parsedItems;
  const _ReviewSharedAddDialog({required this.parsedItems});

  @override
  State<_ReviewSharedAddDialog> createState() => _ReviewSharedAddDialogState();
}

class _ReviewSharedAddDialogState extends State<_ReviewSharedAddDialog> {
  late List<bool> selected;
  final df = NumberFormat.currency(symbol: '₺', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    selected = List<bool>.filled(widget.parsedItems.length, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Add to private too?',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300, // fixed height, scroll inside
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared expenses will always be saved.\nSelect which items should also be added to your private expenses:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  itemCount: widget.parsedItems.length,
                  itemBuilder: (ctx, i) {
                    final row = widget.parsedItems[i];
                    final name = (row['item_name'] ?? '').toString();
                    final priceAny = row['unit_price'];
                    final price = priceAny is num
                        ? priceAny.toDouble()
                        : double.tryParse('$priceAny') ?? 0.0;

                    return CheckboxListTile(
                      value: selected[i],
                      onChanged: (v) => setState(() => selected[i] = v ?? true),
                      title: Text(name.isEmpty ? 'Item ${i + 1}' : name),
                      subtitle: Text(df.format(price)),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final chosen = <Map<String, dynamic>>[];
            for (var i = 0; i < widget.parsedItems.length; i++) {
              if (selected[i]) chosen.add(widget.parsedItems[i]);
            }
            Navigator.pop(
              context,
              ReviewSharedAddResult(selectedPrivateItems: chosen),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
