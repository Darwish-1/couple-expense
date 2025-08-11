import 'package:flutter/material.dart';

class MonthSelectionProvider extends ChangeNotifier {
  String _selectedMonth = DateTime.now().month.toString();
  int _selectedYear = DateTime.now().year;

  String get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;

  // Method to update the selected month and year
  void setSelectedMonth(String month, int year) {
    _selectedMonth = month;
    _selectedYear = year;
    notifyListeners();
  }
}
