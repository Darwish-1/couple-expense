// lib/models/expense_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RawExpense {
  final String? itemName;
  final double? unitPrice;
  final String? category;
  final String? dateOfPurchase; // raw string (e.g., user input)

  RawExpense({
    this.itemName,
    this.unitPrice,
    this.category,
    this.dateOfPurchase,
  });

  Map<String, dynamic> toMap() => {
        'item_name': itemName,
        'unit_price': unitPrice,
        'category': category,
        'date_of_purchase': dateOfPurchase,
      };
}

class GroupedExpense {
  final List<String> itemNames;
  final List<double> unitPrices;
  final Timestamp dateOfPurchase;
  final String category;
  final String userId;
  final String? walletId;
  final Timestamp createdAt;

  GroupedExpense({
    required this.itemNames,
    required this.unitPrices,
    required this.dateOfPurchase,
    required this.category,
    required this.userId,
    required this.walletId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'item_name': itemNames,
        'unit_price': unitPrices,
        'date_of_purchase': dateOfPurchase,
        'category': category,
        'userId': userId,
        'walletId': walletId,
        'created_at': createdAt,
      };
}
