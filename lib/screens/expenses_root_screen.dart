// lib/screens/expenses_root_screen.dart
import 'package:couple_expenses/controllers/mic_controller.dart';
import 'package:couple_expenses/controllers/wallet_controller.dart';
import 'package:couple_expenses/controllers/expenses_root_controller.dart';
import 'package:couple_expenses/controllers/tutorial_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'my_expenses_screen.dart';
import 'shared_expenses_screen.dart';
import 'wallet_screen.dart';

// ⬇️ import to access ExpensesController with tags
import 'package:couple_expenses/controllers/expenses_controller.dart';

class ExpensesRootScreen extends StatefulWidget {
  const ExpensesRootScreen({super.key});

  @override
  State<ExpensesRootScreen> createState() => _ExpensesRootScreenState();
}

class _ExpensesRootScreenState extends State<ExpensesRootScreen> {
  late final List<Widget> _tabs;
  static const kBackgroundColor = Color.fromRGBO(250, 247, 240, 1);
  late final ExpensesRootController _controller;

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController(), permanent: true);
    }

    if (!Get.isRegistered<ExpensesRootController>()) {
      _controller = Get.put(ExpensesRootController(), permanent: true);
    } else {
      _controller = Get.find<ExpensesRootController>();
    }

    // Register TutorialCoordinator if not already registered
    if (!Get.isRegistered<TutorialCoordinator>()) {
      Get.put(TutorialCoordinator(), permanent: true);
    }

    _tabs = const [
      MyExpensesScreen(),
      SharedExpensesScreen(),
      WalletScreen(),
    ];
  }

  bool _anyMicActive() {
    final my = Get.isRegistered<ExpensesController>(tag: 'my')
        ? Get.find<ExpensesController>(tag: 'my')
        : null;
    final shared = Get.isRegistered<ExpensesController>(tag: 'shared')
        ? Get.find<ExpensesController>(tag: 'shared')
        : null;

    return (my?.micActive.value == true) || (shared?.micActive.value == true);
  }

  void _onItemTapped(int index) {
  final mic = Get.isRegistered<MicController>() ? Get.find<MicController>() : null;
  if (mic != null && (mic.isRecording.value || mic.isProcessing.value)) {
    
    return;
  }
  _controller.navigateToTab(index);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Obx(() => IndexedStack(
            index: _controller.selectedIndex.value,
            children: _tabs,
          )),
      bottomNavigationBar: Obx(() => BottomNavigationBar(
            backgroundColor: kBackgroundColor,
            type: BottomNavigationBarType.fixed,
            currentIndex: _controller.selectedIndex.value,
            selectedItemColor: Colors.black87,
            unselectedItemColor: Colors.black54,
            onTap: _onItemTapped, // 👈 guarded
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.list), label: 'My'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Shared'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
            ],
          )),
    );
  }
}
