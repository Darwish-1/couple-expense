import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
@override
void initState() {
  super.initState();
  final items = widget.data['item_name'];
  final prices = widget.data['unit_price'];

  // Initialize controllers for items and prices
  itemControllers = (items is List ? items : [items])
      .map((e) => TextEditingController(text: e.toString()))
      .toList();

  priceControllers = (prices is List ? prices : [prices])
      .map((e) => TextEditingController(text: e.toString()))
      .toList();

  // Handle date_of_purchase correctly
  final date = widget.data['date_of_purchase'];
  String formattedDate = '';

  if (date is Timestamp) {
    // Convert Timestamp to String
    formattedDate = DateFormat('yyyy-MM-dd').format(date.toDate());
  } else if (date is String) {
    // If it's already a String, keep it as is
    formattedDate = date;
  } else {
    // If it's neither, set a default value
    formattedDate = '';
  }

  // Set the formatted date in the controller
  dateController = TextEditingController(text: formattedDate);
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

  // Convert date string to DateTime
  final parsedDate = DateTime.tryParse(date) ?? DateTime.now();

  // Ensure both item_name and unit_price are always stored as lists
  final updatedData = {
    'item_name': items, // Always store as list, even if there's just one item
    'unit_price': prices.map((e) => double.tryParse(e) ?? 0.0).toList(), // Convert prices to double
    'date_of_purchase': Timestamp.fromDate(parsedDate),
    'category': category,
  };

  // Update Firestore with all the values
  await FirebaseFirestore.instance
      .collection('receipts')
      .doc(widget.receiptId)
      .update(updatedData);

  // Go back after saving
  Navigator.pop(context);
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
