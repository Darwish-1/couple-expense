import 'package:flutter/material.dart';

class AddExpenseCard extends StatefulWidget {
  const AddExpenseCard({super.key, required this.onAdd});
  final void Function(Map<String, dynamic> expense) onAdd;

  @override
  State<AddExpenseCard> createState() => _AddExpenseCardState();
}

class _AddExpenseCardState extends State<AddExpenseCard> {
  final _item = TextEditingController();
  final _price = TextEditingController();
  final _category = TextEditingController(text: 'General');
  final _dateRaw = TextEditingController(); // optional

  @override
  void dispose() {
    _item.dispose();
    _price.dispose();
    _category.dispose();
    _dateRaw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _item,
                  decoration: const InputDecoration(labelText: 'Item'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _dateRaw,
                  decoration: const InputDecoration(
                    labelText: 'Date (optional)',
                    hintText: 'e.g. 2025-08-01',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add to Draft'),
                  onPressed: () {
                    final price = double.tryParse(_price.text.trim());
                    final map = {
                      'item_name': _item.text.trim().isEmpty ? null : _item.text.trim(),
                      'unit_price': price,
                      'category': _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
                      'date_of_purchase': _dateRaw.text.trim().isEmpty ? null : _dateRaw.text.trim(),
                    };
                    widget.onAdd(map);
                    _item.clear();
                    _price.clear();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DraftBar extends StatelessWidget {
  const DraftBar({
    super.key,
    required this.count,
    required this.onSave,
    required this.onClear,
  });

  final int count;
  final VoidCallback? onSave;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.03),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text('Draft: $count'),
          const Spacer(),
          TextButton(onPressed: onClear, child: const Text('Clear')),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class PendingBanner extends StatelessWidget {
  const PendingBanner({
    super.key,
    required this.pendingCount,
    required this.lastSuccess,
    required this.lastError,
  });

  final int pendingCount;
  final String lastSuccess;
  final String lastError;

  @override
  Widget build(BuildContext context) {
    if (lastError.isNotEmpty) {
      return Container(
        width: double.infinity,
        color: Colors.red.withOpacity(0.1),
        padding: const EdgeInsets.all(8),
        child: Text(lastError, style: const TextStyle(color: Colors.red)),
      );
    }
    if (lastSuccess.isNotEmpty) {
      return Container(
        width: double.infinity,
        color: Colors.green.withOpacity(0.08),
        padding: const EdgeInsets.all(8),
        child: Text(lastSuccess, style: const TextStyle(color: Colors.green)),
      );
    }
    if (pendingCount == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.amber.withOpacity(0.1),
      padding: const EdgeInsets.all(8),
      child: Text('Pending (instant UI): $pendingCount grouped entr${pendingCount == 1 ? 'y' : 'ies'}'),
    );
  }
}
