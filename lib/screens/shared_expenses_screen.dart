import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:couple_expenses/controllers/expense_summary_controller.dart';
import 'package:couple_expenses/controllers/expenses_controller.dart';
import 'package:couple_expenses/controllers/mic_controller.dart';
import 'package:couple_expenses/controllers/wallet_controller.dart';
import 'package:couple_expenses/screens/settings_screen.dart';
import 'package:couple_expenses/utils/date_utils_ext.dart';
import 'package:couple_expenses/widgets/expense_summary_card.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:couple_expenses/widgets/month_picker.dart';
import 'package:couple_expenses/widgets/expenses/category_icon.dart';
import 'package:couple_expenses/widgets/shared_expense_widgets/review_shared_add_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

class SharedExpensesScreen extends StatefulWidget {
  const SharedExpensesScreen({super.key});

  @override
  State<SharedExpensesScreen> createState() => _SharedExpensesScreenState();
}

class _SharedExpensesScreenState extends State<SharedExpensesScreen> {
  // Expenses controller for shared view
  late final ExpensesController c;

  // Filter state - tracks which member UIDs are selected
  final RxSet<String> selectedMemberIds = <String>{}.obs;

  late final WalletController wc;
  late final MicController mic;

  // success popup
  final RxInt _savedCount = 0.obs;
  final RxBool _showSuccess = false.obs;

  // --- name formatting: "First L"
  String _shortName(String? full) {
    if (full == null) return 'Member';
    final t = full.trim();
    if (t.isEmpty) return 'Member';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    final first = parts.first;
    final lastInitial = parts.last.isNotEmpty ? parts.last[0].toUpperCase() : '';
    return lastInitial.isEmpty ? first : '$first $lastInitial';
  }

  @override
  void initState() {
    super.initState();

    wc = Get.find<WalletController>();

    if (!Get.isRegistered<ExpensesController>(tag: 'shared')) {
      c = Get.put(ExpensesController(collectionName: 'receipts'), tag: 'shared');
    } else {
      c = Get.find<ExpensesController>(tag: 'shared');
    }

    if (!Get.isRegistered<ExpenseSummaryController>(tag: 'shared')) {
      Get.put(
        ExpenseSummaryController(expensesTag: 'shared', isSharedView: true),
        tag: 'shared',
      );
    }

    mic = Get.isRegistered<MicController>() ? Get.find<MicController>() : Get.put(MicController());
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Obx(() {
      if (wc.walletId.value == null || wc.loading.value) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
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
                  'Loading shared expenses...',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final memberMap = {for (final m in wc.members) m.uid: _shortName(m.name)};

      if (selectedMemberIds.isEmpty && wc.members.isNotEmpty) {
        selectedMemberIds.addAll(wc.members.map((m) => m.uid));
      }

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color.fromRGBO(250, 247, 240, 1),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          title: Text(
            'Shared Expenses',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18.sp,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 20.sp),
              onPressed: () {
                Get.to(() => const SettingsScreen());
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 0.5.h),
                  _buildEnhancedSummaryCard(),
                  _buildInteractivePeriodInfo(),
                  _buildMembersInfo(wc.members, memberMap),
                  _buildErrorMessage(wc),
                  SizedBox(height: 0.5.h),
                  Expanded(child: _buildExpensesList(memberMap: memberMap, isWide: w >= 600)),
                ],
              ),
            ),
            const RecordingSection(),
            Obx(() => _showSuccess.value
                ? SuccessPopUp(
                    savedCount: _savedCount.value,
                    contextLabel: 'Shared Expenses',
                  )
                : const SizedBox.shrink()),
          ],
        ),
        floatingActionButton: _buildSharedFAB(),
      );
    });
  }

  Widget _buildEnhancedSummaryCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      child: const ExpenseSummaryCard(
        summaryTag: 'shared',
        title: 'Shared Expenses This Period',
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
          showMonthPickerDialog(Get.context!, 'shared', allowAnchorEdit: true);
        },
        child: Container(
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
                        color: Theme.of(Get.context!).colorScheme.onSurface,
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

  Widget _buildMembersInfo(List<dynamic> members, Map<String, String> memberMap) {
    if (members.length <= 1) return const SizedBox.shrink();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(3.w),
                ),
                child: Icon(
                  Icons.people_outlined,
                  size: 19.sp,
                  color: Colors.green.shade600,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Member',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 0.2.h),
                    Text(
                      'Select which members\' expenses to view',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 1.2.h),
          Obx(() {
            return Wrap(
              spacing: 2.w,
              runSpacing: 1.h,
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: selectedMemberIds.length == members.length,
                  onTap: () {
                    selectedMemberIds.clear();
                    selectedMemberIds.addAll(members.map((m) => m.uid));
                  },
                  color: Colors.blue,
                ),
                ...members.map((member) {
                  final isSelected =
                      selectedMemberIds.length == 1 && selectedMemberIds.contains(member.uid);
                  return _buildFilterChip(
                    label: _shortName(member.name),
                    isSelected: isSelected,
                    onTap: () {
                      selectedMemberIds.clear();
                      selectedMemberIds.add(member.uid);
                    },
                    color: Colors.green,
                  );
                }).toList(),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required MaterialColor color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: isSelected ? color.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(3.w),
          border: Border.all(
            color: isSelected ? color.shade300 : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4.w,
              height: 4.w,
              decoration: BoxDecoration(
                color: isSelected ? color.shade600 : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color.shade600 : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 10.sp,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 2.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isSelected ? color.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(WalletController wc) {
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
              icon: Icon(
                Icons.close,
                size: 12.sp,
                color: Colors.red.shade700,
              ),
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

  Widget _buildExpensesList({
    required Map<String, String> memberMap,
    required bool isWide,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: c.streamMonthForWallet(visibility: 'shared'),
      builder: (context, snap) {
        if (snap.hasError) {
          return _buildErrorState(snap.error.toString());
        }

        if (!snap.hasData) {
          return _buildLoadingState();
        }

        final docs = snap.data!.docs;

        final filteredDocs = selectedMemberIds.isEmpty
            ? docs
            : docs.where((doc) {
                final userId = doc.data()['userId'] as String?;
                return userId != null && selectedMemberIds.contains(userId);
              }).toList();

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

        final sortedDocs = List.of(filteredDocs)
          ..sort((a, b) => _tsOf(b).compareTo(_tsOf(a)));

        if (sortedDocs.isEmpty) {
          return _buildEmptyState();
        }

        final useGrid = MediaQuery.of(context).size.width >= 900;
        final cardPadding = EdgeInsets.all(3.5.w);
        final containerMargin = EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h);

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
                  return _EnhancedSharedExpenseListItem(
                    docId: doc.id,
                    data: data,
                    memberMap: memberMap,
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
                  return _EnhancedSharedExpenseListItem(
                    docId: doc.id,
                    data: data,
                    memberMap: memberMap,
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: Theme.of(Get.context!).colorScheme.surface,
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
            'Loading shared expenses...',
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
          color: Theme.of(Get.context!).colorScheme.surface,
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
              'Error Loading Shared Expenses',
              style: Theme.of(Get.context!).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
            ),
            SizedBox(height: 1.h),
            Text(
              error,
              style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontSize: 10.5.sp,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.4.h),
            ElevatedButton.icon(
              onPressed: () => (Get.context as Element).markNeedsBuild(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Theme.of(Get.context!).colorScheme.surface,
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
    return Obx(() {
      final isFiltered = selectedMemberIds.isNotEmpty &&
          Get.find<WalletController>().members.length > selectedMemberIds.length;

      return Center(
        child: Container(
          margin: EdgeInsets.all(8.w),
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: Theme.of(Get.context!).colorScheme.surface,
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
                decoration: BoxDecoration(
                  color: isFiltered ? const Color(0xFFFFF3E0) : const Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFiltered ? Icons.filter_list_off : Icons.people_outline,
                  size: 28.sp,
                  color: isFiltered ? Colors.orange.shade300 : Colors.blue.shade300,
                ),
              ),
              SizedBox(height: 3.4.h),
              Text(
                isFiltered ? 'No expenses found' : 'No shared expenses yet',
                style: Theme.of(Get.context!).textTheme.titleLarge?.copyWith(
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 20.sp,
                    ),
              ),
              SizedBox(height: 1.2.h),
              Text(
                isFiltered
                    ? 'The selected members haven\'t added any expenses during the current budget period. Try selecting different members or changing the budget period.'
                    : 'Expenses added by wallet members will appear here during the current budget period.',
                style: Theme.of(Get.context!).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.5,
                      fontSize: 14.sp,
                    ),
                textAlign: TextAlign.center,
              ),
              if (isFiltered) ...[
                SizedBox(height: 2.4.h),
                ElevatedButton.icon(
                  onPressed: () {
                    selectedMemberIds.clear();
                    selectedMemberIds
                        .addAll(Get.find<WalletController>().members.map((m) => m.uid));
                  },
                  icon: Icon(Icons.clear_all, size: 16.sp),
                  label: const Text('Show All Members'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3.w),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildSharedFAB() {
    return Obx(() {
      final mic = Get.find<MicController>();
      final rec = mic.isRecording.value;
      final busy = mic.isProcessing.value;

      final child = busy
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            )
          : Icon(rec ? Icons.stop_rounded : Icons.mic_none_rounded);

Future<void> _handlePress() async {
  if (!rec) {
    mic.target = MicTarget.shared; // save intent = shared
    await mic.startRecording();
  } else {
    final result = await mic.stopRecordingAndParse();
    if (!mounted) return;

    if (result != null && result.expenses.isNotEmpty) {
      // 1) Ask the user
   final review = await showReviewSharedAddDialog(
  context: context,
  parsedItems: result.expenses,
);

      if (review == null) {
        // user cancelled; do nothing
        return;
      }
int totalSaved = 0;
totalSaved += await c.saveParsedExpenses(items: result.expenses, shared: true);

// Optionally save chosen ones to Private
if (review.selectedPrivateItems.isNotEmpty) {
  totalSaved += await c.saveParsedExpenses(
    items: review.selectedPrivateItems,
    shared: false,
  );
}

_savedCount.value = totalSaved;
_showSuccess.value = true;
Future.delayed(const Duration(seconds: 3), () {
  if (mounted) _showSuccess.value = false;
});
    }
  }
}


      return FloatingActionButton.extended(
        onPressed: busy ? null : _handlePress,
        backgroundColor: rec ? Colors.red.shade500 : Colors.blue.shade700,
        foregroundColor: Colors.white,
        icon: child,
        label: Text(rec ? 'Stop & add' : 'Add shared expense'),
      );
    });
  }
}

// Enhanced Shared Expense List Item Widget
class _EnhancedSharedExpenseListItem extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, String> memberMap;
  final int index;
  final EdgeInsets cardPadding;

  const _EnhancedSharedExpenseListItem({
    required this.docId,
    required this.data,
    required this.memberMap,
    required this.index,
    required this.cardPadding,
  });

  @override
  Widget build(BuildContext context) {
    final items = (data['item_name'] as List?)?.cast<String>() ?? <String>[];
    final prices = (data['unit_price'] as List?)?.cast<num>() ?? <num>[];
    final category = data['category'] as String? ?? 'General';
    final date = (data['date_of_purchase'] as Timestamp?)?.toDate();
    final userId = data['userId'] as String?;
    final total = prices.fold<double>(0, (p, e) => p + e.toDouble());

    final addedByName = (userId != null ? memberMap[userId] : null) ?? 'Member';

    // Category color used ONLY for the icon bubble
    final base = _getCategoryColor(category);
    final iconBg = base.withOpacity(0.15);

    // List item background is ALWAYS white
    final itemBg = Colors.white;
    final iconBox = 12.w;

    return Container(
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
            // Category-colored circular background JUST for the icon
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

            // Texts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17.sp,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.4.h),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(2.w),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          addedByName,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.6.h),
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
                  ]
                ],
              ),
            ),
            SizedBox(width: 3.w),

            // Amount + items count
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
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
                    padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.4.h),
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
          ],
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
