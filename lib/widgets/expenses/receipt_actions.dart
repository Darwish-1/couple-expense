import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_receipt_sheet.dart';
import '../../controllers/expenses_controller.dart';

class ReceiptActionsMenu extends StatelessWidget {
  const ReceiptActionsMenu({
    super.key,
    required this.docId,
    required this.items,
    required this.prices,
    required this.category,
    required this.date,
    this.controllerTag = 'my',
  });

  final String docId;
  final List<String> items;
  final List<num> prices;
  final String category;
  final DateTime? date;
  final String controllerTag;

  static const kBackgroundColor = Color.fromRGBO(250, 247, 240, 1);

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ExpensesController>(tag: controllerTag);

    Future<void> _edit() async {
      final edited = await showEditReceiptSheet(
        context: context,
        items: items,
        prices: prices,
        category: category,
        date: date,
      );
      if (edited == null) return;
      await c.editReceipt(
        docId,
        items: edited.items,
        prices: edited.prices,
        category: edited.category,
        date: edited.date,
      );
    }

    Future<void> _delete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete receipt?'),
          content: const Text(
            'This will permanently remove the selected receipt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await c.deleteReceipt(docId);
      }
    }

    return PopupMenuButton<String>(
      tooltip: 'More',
      color: kBackgroundColor, // ✅ Set menu background color
      onSelected: (value) async {
        if (value == 'edit') {
          await _edit();
        } else if (value == 'delete') {
          await _delete();
        }
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }
}
