import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final date = widget.data['date_of_purchase'];

    // Initialize item controllers, ensuring `items` is a list
    itemControllers = (items is List
            ? items.map((e) => TextEditingController(text: e.toString())).toList()
            : [TextEditingController(text: items.toString())]);

    // Initialize price controllers, ensuring `prices` is a list and formatting to a string
    priceControllers = (prices is List
            ? prices.map((e) => TextEditingController(text: (e is num) ? e.toString() : '')).toList()
            : [TextEditingController(text: (prices is num) ? prices.toString() : '')]);

    // Initialize date controller, converting from Timestamp to a formatted string
    if (date is Timestamp) {
      dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(date.toDate()));
    } else {
      dateController = TextEditingController(text: '');
    }

    // Initialize category controller
    categoryController = TextEditingController(text: widget.data['category'] ?? '');
  }

  Future<void> saveChanges() async {
    final items = itemControllers.map((c) => c.text.trim()).toList();
    final prices = priceControllers.map((c) => double.tryParse(c.text.trim()) ?? 0.0).toList();
    final category = categoryController.text.trim();
    final date = dateController.text.trim();

    if (category.isEmpty || date.isEmpty || items.any((e) => e.isEmpty) || prices.any((e) => e == 0.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields with valid data.')),
      );
      return;
    }

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid date in YYYY-MM-DD format.')),
      );
      return;
    }

    final updatedData = {
      'item_name': items,
      'unit_price': prices,
      'date_of_purchase': Timestamp.fromDate(parsedDate),
      'category': category,
    };

    try {
      await FirebaseFirestore.instance.collection('receipts').doc(widget.receiptId).update(updatedData);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save changes: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit Receipt",
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.indigo.shade700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: itemControllers.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: itemControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Item ${index + 1}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: priceControllers[index],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Price ${index + 1}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Details',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                    labelText: 'Date of Purchase (YYYY-MM-DD)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveChanges,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.indigo.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      "Save Changes",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}