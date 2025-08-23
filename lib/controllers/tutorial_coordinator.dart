// lib/controllers/tutorial_coordinator.dart
import 'package:get/get.dart';
import '../services/first_run_tutorial.dart';
import 'expenses_root_controller.dart';

class TutorialCoordinator extends GetxController {
  static TutorialCoordinator get instance => Get.find<TutorialCoordinator>();

  final RxBool _isTutorialActive = false.obs;
  final RxInt _currentTutorialStep = 0.obs;

  bool get isTutorialActive => _isTutorialActive.value;
  int get currentTutorialStep => _currentTutorialStep.value;

  void startTutorialSequence() {
    _isTutorialActive.value = true;
    _currentTutorialStep.value = 0;
  }

  void nextTutorialStep() => _currentTutorialStep.value++;

  void completeTutorial() {
    _isTutorialActive.value = false;
    _currentTutorialStep.value = 0;
    FirstRunTutorial.markSeen();
  }

  Future<void> navigateToWalletWithTutorial() async {
    await FirstRunTutorial.markMyExpensesSeen();
    final root = Get.find<ExpensesRootController>();
    root.navigateToTab(2); // index 2 = Wallet
    await Future.delayed(const Duration(milliseconds: 300));
    nextTutorialStep();
  }

  Future<void> navigateToSharedExpensesWithTutorial() async {
    await FirstRunTutorial.markWalletSeen();
    final root = Get.find<ExpensesRootController>();
    root.navigateToTab(1); // index 1 = Shared
    await Future.delayed(const Duration(milliseconds: 300));
    nextTutorialStep();
  }
}
