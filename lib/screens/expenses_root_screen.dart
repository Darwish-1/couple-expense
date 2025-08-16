// lib/screens/expenses_root_screen.dart
import 'package:couple_expenses/controllers/wallet_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'my_expenses_screen.dart';
import 'shared_expenses_screen.dart';
import 'wallet_screen.dart';

class ExpensesRootScreen extends StatefulWidget {
  const ExpensesRootScreen({super.key});

  @override
  State<ExpensesRootScreen> createState() => _ExpensesRootScreenState();
}

class _ExpensesRootScreenState extends State<ExpensesRootScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _tabs;
  static const kBackgroundColor = Color.fromRGBO(250, 247, 240, 1);

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController(), permanent: true);
    }

    _tabs = [
      const MyExpensesScreen(),
      SharedExpensesScreen(),
      const WalletScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: kBackgroundColor, // cream background
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black87, // active tab color
        unselectedItemColor: Colors.black54, // inactive tab color
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'My'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Shared'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
        ],
      ),
    );
  }
}
