import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditReceiptScreen extends StatefulWidget {
  final String receiptId;
  final Map<String, dynamic> data;

  const EditReceiptScreen({super.key, required this.receiptId, required this.data});

  @override
  State<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends State<EditReceiptScreen> {
  late List<TextEditingController> itemControllers;
  late List<TextEditingController> priceControllers;
  late TextEditingController dateController;
  late TextEditingController categoryController;

  @override
  void initState() {
    super.initState();
    final items = widget.data['item_name'];
    final prices = widget.data['unit_price'];

    itemControllers = (items is List ? items : [items])
        .map((e) => TextEditingController(text: e.toString()))
        .toList();

    priceControllers = (prices is List ? prices : [prices])
        .map((e) => TextEditingController(text: e.toString()))
        .toList();

    dateController = TextEditingController(text: widget.data['date_of_purchase'] ?? '');
    categoryController = TextEditingController(text: widget.data['category'] ?? '');
  }

Future<void> saveChanges() async {
  final items = itemControllers.map((c) => c.text.trim()).toList();
  final prices = priceControllers.map((c) => c.text.trim()).toList();
  final category = categoryController.text.trim();
  final date = dateController.text.trim();

  // Validate: no empty items or prices
  if (category.isEmpty || date.isEmpty || items.any((e) => e.isEmpty) || prices.any((e) => e.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all fields before saving.')),
    );
    return;
  }

  final parsedPrices = prices.map((e) => double.tryParse(e) ?? 0.0).toList();

  final updatedData = {
    'item_name': items.length == 1 ? items[0] : items,
    'unit_price': parsedPrices.length == 1 ? parsedPrices[0] : parsedPrices,
    'date_of_purchase': date,
    'category': category,
  };

  await FirebaseFirestore.instance
      .collection('receipts')
      .doc(widget.receiptId)
      .update(updatedData);

  Navigator.pop(context); // Go back after saving
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Receipt")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: itemControllers.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: itemControllers[index],
                        decoration: InputDecoration(labelText: 'Item ${index + 1}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: priceControllers[index],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Price ${index + 1}'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: 'Date of Purchase'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveChanges,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
