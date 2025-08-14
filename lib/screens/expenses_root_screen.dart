// lib/screens/expenses_root_screen.dart
import 'package:couple_expenses/controllers/auth_controller.dart';
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

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController(), permanent: true);
    }

    _tabs = [
      const MyExpensesScreen(),
      // SharedExpensesScreen isn't const because it constructs controllers; keep as before if needed
      // If your SharedExpensesScreen can't be const, change this line back to: SharedExpensesScreen(),
      SharedExpensesScreen(),
      const WalletScreen(),
      const SizedBox(), // Sign Out
    ];
  }

  void _onItemTapped(int index) async {
    if (index == 3) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign Out')),
          ],
        ),
      );
      if (confirm == true) {
        Get.find<AuthController>().signOut();
        // AuthGate will rebuild to LoginScreen automatically
      }
      return;
    }

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'My'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Shared'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
        ],
      ),
    );
  }
}
