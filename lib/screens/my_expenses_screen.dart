// lib/screens/my_expenses_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/controllers/expense_summary_controller.dart';
import 'package:couple_expenses/controllers/tutorial_coordinator.dart';
import 'package:couple_expenses/screens/settings_screen.dart';
import 'package:couple_expenses/services/first_run_tutorial.dart';
import 'package:couple_expenses/widgets/expense_summary_card.dart';
import 'package:couple_expenses/widgets/expenses/category_icon.dart';
import 'package:couple_expenses/widgets/expenses/receipt_actions.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:couple_expenses/widgets/wallet_setup_loading.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../controllers/expenses_controller.dart';
import '../controllers/mic_controller.dart';
import '../controllers/wallet_controller.dart';
import '../utils/date_utils_ext.dart';
import '../widgets/month_picker.dart';

class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key});

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  late final ExpensesController c;
  late final WalletController wc;
  late final MicController mic;
  Worker? _tutorialWorker; // NEW

  // --- CoachMark targets
  final _kSummary = GlobalKey();
  final _kPeriod = GlobalKey();
  final _kFab = GlobalKey();

  bool _tutorialShownOnce = false;
  int _tutorialTries = 0;

  // Success popup state
  final RxInt _savedCount = 0.obs;
  final RxBool _showSuccess = false.obs;

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<WalletController>()) {
      Get.put(WalletController(), permanent: true);
    }
    wc = Get.find<WalletController>();

    if (!Get.isRegistered<ExpensesController>(tag: 'my')) {
      c = Get.put(ExpensesController(collectionName: 'receipts'), tag: 'my');
    } else {
      c = Get.find<ExpensesController>(tag: 'my');
    }

    if (!Get.isRegistered<ExpenseSummaryController>(tag: 'my')) {
      Get.put(
        ExpenseSummaryController(expensesTag: 'my', isSharedView: false),
        tag: 'my',
      );
    }

    mic = Get.isRegistered<MicController>()
        ? Get.find<MicController>()
        : Get.put(MicController());

    // show tutorial after first frame
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowFirstRunTutorial(),
    );
    _tutorialWorker = everAll([wc.walletId, wc.loading], (_) {
      if (!_tutorialShownOnce &&
          mounted &&
          wc.walletId.value != null &&
          wc.loading.value == false) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeShowFirstRunTutorial(),
        );
      }
    });
  }

  @override
void dispose() {
  _tutorialWorker?.dispose();
  if (c.micActive.value) c.stopMic(); // ensure unlock
  super.dispose();
}

  // ===================== First-run Tutorial =====================

  // Updated MyExpensesScreen tutorial logic

  Future<void> _maybeShowFirstRunTutorial() async {
    debugPrint('_maybeShowFirstRunTutorial: Starting check...');

    // Don’t double-run or run on dead widgets
    if (_tutorialShownOnce || !mounted) {
      debugPrint(
        '_maybeShowFirstRunTutorial: Early return - tutorialShownOnce: $_tutorialShownOnce, mounted: $mounted',
      );
      return;
    }

    // Wait until the wallet is actually ready; your Worker in initState will re-trigger this.
    if (wc.walletId.value == null || wc.loading.value) {
      debugPrint(
        '_maybeShowFirstRunTutorial: Wallet not ready (walletId=${wc.walletId.value}, loading=${wc.loading.value}). Will retry when ready.',
      );
      return;
    }

    // Debug current tutorial state
    final debugState = await FirstRunTutorial.getDebugState();
    debugPrint('_maybeShowFirstRunTutorial: Current state = $debugState');

    // Check if the OVERALL tutorial sequence should run and if "My" should run
    final shouldShowOverall = await FirstRunTutorial.shouldShow();
    final shouldShowMyExpenses = await FirstRunTutorial.shouldShowMyExpenses();
    debugPrint(
      '_maybeShowFirstRunTutorial: shouldShowOverall = $shouldShowOverall, shouldShowMyExpenses = $shouldShowMyExpenses',
    );

    // If either says "do not show", bail (nothing to do)
    if (!shouldShowOverall || !shouldShowMyExpenses) {
      _tutorialShownOnce = true;
      debugPrint(
        '_maybeShowFirstRunTutorial: Nothing to show (flags say completed), returning',
      );
      return;
    }

    // Start/continue the sequence
    final coordinator = TutorialCoordinator.instance;
    if (!coordinator.isTutorialActive) {
      coordinator.startTutorialSequence();
    }

    // Give layout one frame before we start polling
    await WidgetsBinding.instance.endOfFrame;

    // Wait for the actual RenderObjects of the targets to exist.
    // Use endOfFrame to avoid racing the build/layout passes that happen while wallet is created.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    var tries = 0;
    while (mounted &&
        DateTime.now().isBefore(deadline) &&
        (_kSummary.currentContext == null ||
            _kPeriod.currentContext == null ||
            _kFab.currentContext == null)) {
      tries++;
      debugPrint(
        '_maybeShowFirstRunTutorial: Waiting for contexts, try $tries',
      );
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // If any target is still missing, stop now — the Worker you added will call us again
    if (_kSummary.currentContext == null ||
        _kPeriod.currentContext == null ||
        _kFab.currentContext == null) {
      debugPrint(
        '_maybeShowFirstRunTutorial: Targets still missing after wait; will retry on next wallet/tab change.',
      );
      return;
    }

    debugPrint(
      '_maybeShowFirstRunTutorial: All contexts available, showing tutorial',
    );

    final tutorial = TutorialCoachMark(
      targets:
          _buildTutorialTargets(), // your existing builder (summary, period, fab)
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      pulseEnable: false,
      hideSkip: false,
      textSkip: "Skip Tutorial",
      onFinish: () async {
        debugPrint(
          '_maybeShowFirstRunTutorial: My Expenses tutorial finished, going to wallet',
        );
        await TutorialCoordinator.instance
            .navigateToWalletWithTutorial(); // 👈 changed
      },
      onSkip: () {
        debugPrint('_maybeShowFirstRunTutorial: Tutorial skipped');
        FirstRunTutorial.markSeen(); // mark entire sequence as seen
        TutorialCoordinator.instance.completeTutorial();
        return true;
      },
    );

    tutorial.show(context: context);
    _tutorialShownOnce = true;
    debugPrint('_maybeShowFirstRunTutorial: Tutorial shown');
  }

  List<TargetFocus> _buildTutorialTargets() {
    return [
      TargetFocus(
        identify: "summary",
        keyTarget: _kSummary,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (_, controller) => _tip(
              title: "Your totals",
              body: "See your spending summary for this period.",
              onNext: controller.next,
              onSkip: controller.skip,
              isLast: false,
              stepInfo: "Step 1 of 6", // Update step info
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "period",
        keyTarget: _kPeriod,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (_, controller) => _tip(
              title: "Budget period",
              body: "Tap to change the month or start day.",
              onNext: controller.next,
              onSkip: controller.skip,
              isLast: false,
              stepInfo: "Step 2 of 6",
            ),
          ),
        ],
      ),
      TargetFocus(
        identify: "fab",
        keyTarget: _kFab,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (_, controller) => _tip(
              title: "Add by voice",
              body:
                  "Tap the mic to add expenses.\n\nNext: Let's explore the Wallets!",
              onNext: controller.next,
              onSkip: controller.skip,
              isLast: true,
              stepInfo: "Step 3 of 6",
              nextButtonText: "Continue →", // Custom button text
            ),
          ),
        ],
      ),
    ];
  }

  Widget _tip({
    required String title,
    required String body,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    required bool isLast,
    String? stepInfo,
    String? nextButtonText,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          if (stepInfo != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stepInfo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(isLast ? "Skip Tutorial" : "Skip"),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onNext,
                child: Text(nextButtonText ?? (isLast ? "Continue" : "Next")),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 600;

 return Obx(() => PopScope(
  canPop: !mic.isRecording.value, // block back while recording
  child: Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      elevation: 0,
      backgroundColor: const Color.fromRGBO(250, 247, 240, 1),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      title: Text('My Expenses', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18.sp)),
      actions: [
        IconButton(
          icon: Icon(Icons.settings, size: 20.sp),
          onPressed: mic.isRecording.value ? null : () => Get.to(() => const SettingsScreen()),
        ),
      ],
    ),
    body: Stack(
      children: [
        // ✳️ Block touches to content while mic is active
        Obx(() => IgnorePointer(
          ignoring: mic.isRecording.value || mic.isProcessing.value,
          child: SafeArea(
            child: Obx(() {
              if (wc.walletId.value == null || wc.loading.value || wc.joining.value || !wc.isMember.value) {
                return _buildMainLoadingState();
              }
              return Column(
                children: [
                  SizedBox(height: 2.h),
                  _EnhancedSummaryCard(targetKey: _kSummary),
                  _buildInteractivePeriodInfo(),
                  _buildErrorMessage(),
                  SizedBox(height: 1.h),
                  Expanded(child: _buildExpensesList(isWide: isWide)),
                ],
              );
            }),
          ),
        )),

        // (Optional) visual scrim that DOES NOT eat taps (FAB stays tappable)
        Obx(() => (mic.isRecording.value || mic.isProcessing.value)
            ? IgnorePointer(
                ignoring: true, // important: visual only
                child: Container(color: Colors.black.withOpacity(0.35)),
              )
            : const SizedBox.shrink()),

        // Mic overlay UI (your waveform / timer etc.)
        const RecordingSection(),

        // Success popup
        Obx(() => _showSuccess.value
            ? SuccessPopUp(savedCount: _savedCount.value, contextLabel: 'My Expenses')
            : const SizedBox.shrink()),
      ],
    ),
    floatingActionButton: _buildEnhancedFAB(isWide: isWide), // FAB remains on top and tappable
  ),
));


  }

  Widget _buildMainLoadingState() {
    return const Center(
      child: WalletSetupLoading(
        size: 160,
        label: 'Setting up your expenses...',
        labelStyle: TextStyle(
          fontSize: 14, // Adjust as needed for your design
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInteractivePeriodInfo() {
    final df = DateFormat("d MMMM yyyy");

    return Obx(() {
      final m = monthFromString(c.selectedMonth.value);
      final y = c.selectedYear.value;
      final a = c.budgetAnchorDay.value;
      final start = startOfBudgetPeriod(y, m, a);
      final end = nextStartOfBudgetPeriod(y, m, a);

      return GestureDetector(
        onTap: () {
           if (c.micActive.value) return; // 🔒 block while recording
          showMonthPickerDialog(context, 'my', allowAnchorEdit: true);
        },
        child: Container(
          key: _kPeriod, // 👈 coachmark target lives on the RenderObject
          margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 2.w,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 19.sp,
                  color: Colors.blue.shade600,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Budget Period',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.edit_outlined,
                          size: 14.sp,
                          color: Colors.grey.shade500,
                        ),
                      ],
                    ),
                    SizedBox(height: .3.h),
                    Text(
                      '${df.format(start)} → ${df.format(end)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(1.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.blue.shade600,
                  size: 16.sp,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildErrorMessage() {
    return Obx(() {
      if (wc.errorMessage.value.isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(5.w, 0, 5.w, 1.6.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
          ),
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(4.w),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.1),
              blurRadius: 2.w,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(1.5.w),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
                size: 12.sp,
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Text(
                wc.errorMessage.value,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: () => wc.errorMessage.value = '',
              icon: Icon(Icons.close, size: 12.sp, color: Colors.red.shade700),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                shape: const CircleBorder(),
                padding: EdgeInsets.all(1.w),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildExpensesList({required bool isWide}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: c.streamMyMonthInWallet(), // default = private only
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(snap.error.toString());
        }

        if (!snap.hasData) {
          return _buildSkeletonLoading();
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        DateTime _tsOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final m = d.data();
          final created = m['created_at'];
          if (created is Timestamp) return created.toDate();
          final createdClient = m['created_at_client'];
          if (createdClient is Timestamp) return createdClient.toDate();
          final purchased = m['date_of_purchase'];
          if (purchased is Timestamp) return purchased.toDate();
          return DateTime.fromMillisecondsSinceEpoch(0);
        }

        final sortedDocs = List.of(docs)
          ..sort((a, b) => _tsOf(b).compareTo(_tsOf(a)));
        final useGrid = MediaQuery.of(context).size.width >= 900;
        final cardPadding = EdgeInsets.all(3.5.w);
        final containerMargin = EdgeInsets.symmetric(
          horizontal: 3.w,
          vertical: 1.h,
        );

        final listChild = useGrid
            ? GridView.builder(
                padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 3.w,
                  mainAxisSpacing: 2.h,
                  childAspectRatio: 3.6,
                ),
                itemCount: sortedDocs.length,
                itemBuilder: (_, i) {
                  final doc = sortedDocs[i];
                  final data = doc.data();
                  return _EnhancedExpenseListItem(
                    docId: doc.id,
                    data: data,
                    expensesController: c,
                    index: i,
                    cardPadding: cardPadding,
                  );
                },
              )
            : ListView.builder(
                padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
                itemCount: sortedDocs.length,
                itemBuilder: (_, i) {
                  final doc = sortedDocs[i];
                  final data = doc.data();
                  return _EnhancedExpenseListItem(
                    docId: doc.id,
                    data: data,
                    expensesController: c,
                    index: i,
                    cardPadding: cardPadding,
                  );
                },
              );

        return Container(
          margin: containerMargin,
          padding: EdgeInsets.all(3.5.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4.w),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2.w,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: listChild,
        );
      },
    );
  }

  Widget _buildSkeletonLoading() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4.w),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2.w,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 12.h, top: 1.h),
        itemCount: 5,
        itemBuilder: (_, i) => _buildSkeletonItem(),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4.w),
        border: Border.all(color: Colors.black, width: 0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0.2.w,
            blurRadius: 2.6.w,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(2.w),
        child: Row(
          children: [
            Container(
              width: 12.w,
              height: 12.w,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 2.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(1.w),
                    ),
                  ),
                  SizedBox(height: 0.6.h),
                  Container(
                    width: 60.w,
                    height: 1.5.h,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(1.w),
                    ),
                  ),
                  SizedBox(height: 0.8.h),
                  Container(
                    width: 20.w,
                    height: 1.2.h,
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(2.5.w),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 3.w),
            Container(
              width: 20.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2.5.w),
              ),
            ),
            SizedBox(width: 2.w),
            Container(
              width: 8.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(2.w),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2.w,
                  blurRadius: 5.w,
                ),
              ],
            ),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 3.h),
          Text(
            'Loading expenses...',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        margin: EdgeInsets.all(8.w),
        padding: EdgeInsets.all(6.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1.w,
              blurRadius: 5.w,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 24.sp,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Error Loading Expenses',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontSize: 10.5.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.4.h),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Theme.of(context).colorScheme.surface,
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3.w),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(8.w),
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(5.w),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1.w,
              blurRadius: 5.w,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(5.w),
              decoration: const BoxDecoration(
                color: Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 28.sp,
                color: Colors.blue.shade300,
              ),
            ),
            SizedBox(height: 3.4.h),
            Text(
              'No expenses yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 20.sp,
              ),
            ),
            SizedBox(height: 1.2.h),
            Text(
              'Tap the mic button below to add your first expense by voice, or use the menu to add manually.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
                fontSize: 14.sp,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(5.w),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, size: 12.sp, color: Colors.blue.shade600),
                  SizedBox(width: 2.w),
                  Text(
                    'Try: "I spent 25 dollars on groceries"',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.blue.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedFAB({required bool isWide}) {
    return Obx(() {
      final rec = mic.isRecording.value;
      final busy = mic.isProcessing.value;

      final child = busy
          ? SizedBox(
              width: 7.w,
              height: 7.w,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(rec ? Icons.stop_rounded : Icons.mic_rounded, size: 16.sp);

    Future<void> _handlePress() async {
  final rec = mic.isRecording.value;

  if (!rec) {
    // START recording
    c.startMic();                       // 👈 mark “locked”
    mic.target = MicTarget.my;          // save as PRIVATE in My screen
    await mic.startRecording();
  } else {
    // STOP recording & parse
    final result = await mic.stopRecordingAndParse();
    // Always clear the lock, even on errors or empty parse
    try {
      if (!mounted) return;
      if (result != null && result.expenses.isNotEmpty) {
        final n = await c.saveParsedExpenses(items: result.expenses, shared: false);
        _savedCount.value = n;
        _showSuccess.value = true;
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) _showSuccess.value = false;
        });
      }
    } finally {
      c.stopMic();                      // 👈 unlock navigation/taps
    }
  }
}
      return isWide
          ? FloatingActionButton.large(
              key: _kFab,
              heroTag: 'fab-my', // 👈 unique tag
              tooltip: rec ? 'Stop & add' : 'Add by voice',
              backgroundColor: rec ? Colors.red.shade500 : Colors.blue.shade600,
              foregroundColor: Theme.of(context).colorScheme.surface,
              elevation: rec ? 12 : 8,
              onPressed: busy ? null : _handlePress,
              child: child,
            )
          : FloatingActionButton(
              key: _kFab,
              heroTag: 'fab-my', // 👈 unique tag
              tooltip: rec ? 'Stop & add' : 'Add by voice',
              backgroundColor: rec ? Colors.red.shade500 : Colors.blue.shade600,
              foregroundColor: Theme.of(context).colorScheme.surface,
              elevation: rec ? 12 : 8,
              onPressed: busy ? null : _handlePress,
              child: child,
            );
    });
  }
}

class _EnhancedSummaryCard extends StatelessWidget {
  final GlobalKey? targetKey;
  const _EnhancedSummaryCard({Key? key, this.targetKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: targetKey, // attach the coachmark key to the RenderObject
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      child: const ExpenseSummaryCard(
        summaryTag: 'my',
        title: 'My Expenses This Period',
      ),
    );
  }
}

class _EnhancedExpenseListItem extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final ExpensesController expensesController;
  final int index;
  final EdgeInsets cardPadding;

  const _EnhancedExpenseListItem({
    required this.docId,
    required this.data,
    required this.expensesController,
    required this.index,
    required this.cardPadding,
  });

  @override
  Widget build(BuildContext context) {
    final items = (data['item_name'] as List?)?.cast<String>() ?? <String>[];
    final prices = (data['unit_price'] as List?)?.cast<num>() ?? <num>[];
    final category = data['category'] as String? ?? 'General';
    final date = (data['date_of_purchase'] as Timestamp?)?.toDate();
    final total = prices.fold<double>(0, (p, e) => p + e.toDouble());

    final base = _getCategoryColor(category);
    final iconBg = base.withOpacity(0.15);
    final itemBg = Colors.white;
    final iconBox = 12.w;

    return Dismissible(
      key: ValueKey(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.symmetric(vertical: 0.8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
          ),
          borderRadius: BorderRadius.circular(4.w),
        ),
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(context).colorScheme.surface,
                fontWeight: FontWeight.bold,
                fontSize: 11.sp,
              ),
            ),
            SizedBox(width: 3.w),
            Icon(
              Icons.delete_sweep_rounded,
              color: Theme.of(context).colorScheme.surface,
              size: 16.sp,
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.w),
            ),
            title: const Text('Delete Receipt?'),
            content: const Text(
              'This will permanently remove the selected receipt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2.w),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) await expensesController.deleteReceipt(docId);
        return false;
      },

      child: Container(
        margin: EdgeInsets.symmetric(vertical: 0.8.h),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(4.w),
          border: Border.all(color: Colors.black, width: 0.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              spreadRadius: 0.2.w,
              blurRadius: 2.6.w,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(2.w),
          child: Row(
            children: [
              Container(
                width: iconBox,
                height: iconBox,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.all(0.8.w),
                  child: CategoryIcon(category),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 0.6.h),
                    Text(
                      items.isNotEmpty ? items.join(', ') : 'No items listed',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (date != null) ...[
                      SizedBox(height: 0.8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.w,
                          vertical: 0.6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(2.5.w),
                        ),
                        child: Text(
                          DateFormat('E, MMM d').format(date),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 3.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 3.w,
                      vertical: 0.8.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2.5.w),
                    ),
                    child: Text(
                      '₺${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  if (items.length > 1) ...[
                    SizedBox(height: 0.5.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 1.5.w,
                        vertical: 0.4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(2.w),
                      ),
                      child: Text(
                        '${items.length} items',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: 2.w),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(2.w),
                ),
                child: ReceiptActionsMenu(
                  docId: docId,
                  items: items,
                  prices: prices,
                  category: category,
                  date: date,
                  controllerTag: 'my',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Colors.orange.shade600;
      case 'transportation':
      case 'gas':
        return Colors.blue.shade600;
      case 'shopping':
        return Colors.purple.shade600;
      case 'entertainment':
        return Colors.green.shade600;
      case 'health':
        return Colors.red.shade600;
      case 'utilities':
        return Colors.teal.shade600;
      case 'education':
        return Colors.indigo.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
