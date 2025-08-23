// lib/controllers/expenses_root_controller.dart
import 'package:get/get.dart';

class ExpensesRootController extends GetxController {
  final RxInt selectedIndex = 0.obs;
  
  void navigateToTab(int index) {
    selectedIndex.value = index;
  }
}