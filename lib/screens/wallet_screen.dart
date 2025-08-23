// lib/screens/wallet_screen.dart
import 'package:couple_expenses/controllers/expenses_root_controller.dart';
import 'package:couple_expenses/controllers/tutorial_coordinator.dart';
import 'package:couple_expenses/services/first_run_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../controllers/wallet_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletController wc = Get.find<WalletController>();

  final _emailCtrl = TextEditingController();
  final _joinCtrl = TextEditingController();

  // Tutorial keys
  final _kWalletIdCard = GlobalKey();
  final _kInviteRow = GlobalKey();
  final _kJoinRow = GlobalKey();
  final _kMembersSec = GlobalKey();
  final _kDangerCard = GlobalKey();

  bool _walletTutorialShownOnce = false;
  int _tries = 0;

  late final ExpensesRootController _root; // for tab visibility
  @override
  void initState() {
    super.initState();
    _root = Get.find<ExpensesRootController>();

    // Try after first frame
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowWalletTutorial(),
    );

    // Re-run when this tab becomes visible
    _root.selectedIndex.listen((i) {
      if (i == 2) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeShowWalletTutorial(),
        );
      }
    });

    // Also retry when wallet becomes ready
    everAll([wc.walletId, wc.loading], (_) {
      if (mounted && _root.selectedIndex.value == 2) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _maybeShowWalletTutorial(),
        );
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

 Future<void> _confirmLeaveDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Obx(() {
      final disabled = wc.loading.value || wc.joining.value;
      return AlertDialog(
        title: const Text('Leave this wallet?'),
        content: const Text(
          "Leaving this wallet will:\n\n"
          "• Delete ALL your shared expenses in this wallet\n"
          "• Keep your private expenses (moved to your personal wallet)\n\n"
          "Other members keep their own expenses.",
        ),
        actions: [
          TextButton(
            onPressed: disabled ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: disabled ? null : () async {
              Navigator.of(ctx).pop();
              await wc.leaveCurrentWallet(); // single path
              if (wc.errorMessage.value.isEmpty && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Left wallet: your private expenses were kept in your personal wallet; your shared were removed.',
                    ),
                  ),
                );
              }
            },
            label: const Text('Leave wallet'),
          ),
        ],
      );
    }),
  );
}

  Future<void> _confirmRemoveMember(
    BuildContext context, {
    required String memberUid,
    required String label,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Obx(() {
        final disabled = wc.loading.value || wc.joining.value;
        return AlertDialog(
          title: const Text('Remove member?'),
          content: Text(
            "Remove $label from this wallet?\n\n"
            "Note: their existing receipts will remain in this wallet. "
            "They can still keep their receipts by leaving from their device.",
          ),
          actions: [
            TextButton(
              onPressed: disabled ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: disabled
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await wc.removeMember(memberUid);
                      if (mounted) {
                        final err = wc.errorMessage.value;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              err.isEmpty ? 'Member removed.' : 'Error: $err',
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('Remove'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _confirmAcceptInvite(
  BuildContext context, {
  required WalletInvite invite,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Obx(() {
      final disabled = wc.loading.value || wc.joining.value;
      return AlertDialog(
        title: const Text('Accept invitation'),
        content: const Text(
  "Joining this wallet will:\n\n"
  "• Move your existing PRIVATE expenses here (they stay private)\n"
  "• Add nothing to Shared\n\n"
  "You can only add shared expenses when there’s more than one member."
),
        actions: [
          TextButton(
            onPressed: disabled ? null : () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
  onPressed: disabled ? null : () async {
    Navigator.of(ctx).pop();
    await wc.acceptInvite(invite); // the param is ignored now
    if (mounted && wc.errorMessage.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite accepted.')),
      );
    }
  },
  child: const Text('Accept & join'),
),
        ],
      );
    }),
  );
}


  Future<void> _maybeShowWalletTutorial() async {
    debugPrint('Wallet._maybeShowWalletTutorial: start');

    if (_walletTutorialShownOnce || !mounted) return;

    // Only when wallet tab is visible
    if (_root.selectedIndex.value != 2) {
      debugPrint('Wallet._maybeShowWalletTutorial: tab not visible');
      return;
    }

    // Wait until wallet ready
    if (wc.walletId.value == null || wc.loading.value) {
      debugPrint('Wallet._maybeShowWalletTutorial: wallet not ready yet');
      return;
    }

    // Flags
    final state = await FirstRunTutorial.getDebugState();
    debugPrint('Wallet._maybeShowWalletTutorial: state=$state');

    final shouldOverall = await FirstRunTutorial.shouldShow();
    final shouldWallet = await FirstRunTutorial.shouldShowWallet();
    if (!shouldOverall || !shouldWallet) {
      _walletTutorialShownOnce = true;
      debugPrint('Wallet._maybeShowWalletTutorial: flags say skip');
      return;
    }

    // Ensure sequence active
    final coord = TutorialCoordinator.instance;
    if (!coord.isTutorialActive) coord.startTutorialSequence();

    // Wait per-frame for targets
    await WidgetsBinding.instance.endOfFrame;
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted &&
        DateTime.now().isBefore(deadline) &&
        _missingAnyRequiredTargets()) {
      _tries++;
      debugPrint(
        'Wallet._maybeShowWalletTutorial: waiting for contexts try=$_tries',
      );
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 50));
    }

    if (_missingAnyRequiredTargets()) {
      debugPrint(
        'Wallet._maybeShowWalletTutorial: targets missing; will retry on next state change',
      );
      return;
    }

    final targets = _buildWalletTargetsDynamic();
    debugPrint(
      'Wallet._maybeShowWalletTutorial: showing with ${targets.length} targets',
    );

    final tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      pulseEnable: false,
      hideSkip: false,
      textSkip: "Skip Tutorial",
      onFinish: () async {
        debugPrint('Wallet tutorial finished → go to Shared');
        await TutorialCoordinator.instance
            .navigateToSharedExpensesWithTutorial();
      },
      onSkip: () {
        FirstRunTutorial.markSeen();
        TutorialCoordinator.instance.completeTutorial();
        return true;
      },
    );

    tutorial.show(context: context);
    _walletTutorialShownOnce = true;
  }

  // Require at least wallet id + invites/join OR danger; be lenient:
  bool _missingAnyRequiredTargets() {
    // Minimal: wallet id card + join row should exist to proceed
    return _kWalletIdCard.currentContext == null ||
        _kJoinRow.currentContext == null;
  }

  List<TargetFocus> _buildWalletTargetsDynamic() {
    final t = <TargetFocus>[];

    if (_kWalletIdCard.currentContext != null) {
      t.add(
        TargetFocus(
          identify: 'wallet_id',
          keyTarget: _kWalletIdCard,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (_, c) => _walletTip(
                title: 'Your wallet ID',
                body:
                    'Share or copy this ID to let a partner join your wallet.',
                step: 'Step 4 of 6',
                onNext: c.next,
                onSkip: c.skip,
                isLast: false,
              ),
            ),
          ],
        ),
      );
    }

    if (_kInviteRow.currentContext != null) {
      t.add(
        TargetFocus(
          identify: 'invite_email',
          keyTarget: _kInviteRow,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, c) => _walletTip(
                title: 'Invite by email',
                body: 'Send an email invite to add a partner quickly.',
                step: 'Step 5 of 6',
                onNext: c.next,
                onSkip: c.skip,
                isLast: false,
              ),
            ),
          ],
        ),
      );
    }

    if (_kJoinRow.currentContext != null) {
      t.add(
        TargetFocus(
          identify: 'join_by_id',
          keyTarget: _kJoinRow,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, c) => _walletTip(
                title: 'Join by wallet ID',
                body:
                    'If someone shared an ID with you, paste it here to join.',
                step: 'Step 5 of 6',
                onNext: c.next,
                onSkip: c.skip,
                isLast: false,
              ),
            ),
          ],
        ),
      );
    }

    if (_kMembersSec.currentContext != null) {
      t.add(
        TargetFocus(
          identify: 'members',
          keyTarget: _kMembersSec,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, c) => _walletTip(
                title: 'Members',
                body: 'See who’s in your wallet. Remove members if needed.',
                step: 'Step 5 of 6',
                onNext: c.next,
                onSkip: c.skip,
                isLast: false,
              ),
            ),
          ],
        ),
      );
    }

  if (_kDangerCard.currentContext != null) {
  t.add(TargetFocus(
    identify: 'leave_wallet',
    keyTarget: _kDangerCard,
    shape: ShapeLightFocus.RRect,
    radius: 12,
    contents: [
      TargetContent(
        align: ContentAlign.top,
        builder: (_, c) => _walletTip(
          title: 'Leave the wallet',
          body: 'Leaving deletes your shared expenses here and keeps your private ones in your personal wallet.',
          step: 'Step 6 of 6',
          onNext: c.next, onSkip: c.skip, isLast: true,
          nextText: 'Continue →',
        ),
      ),
    ],
  ));
}

    return t;
  }

  Widget _walletTip({
    required String title,
    required String body,
    required String step,
    required VoidCallback onNext,
    required VoidCallback onSkip,
    required bool isLast,
    String? nextText,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              step,
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
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
                child: Text(isLast ? 'Skip Tutorial' : 'Skip'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onNext,
                child: Text(nextText ?? (isLast ? 'Finish' : 'Next')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        // Leave button removed from AppBar
      ),
      body: Obx(() {
        final loading = wc.loading.value;
        final joining = wc.joining.value;
        final err = wc.errorMessage.value;
        final isMember = wc.isMember.value;
        final isBusy = loading || joining;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Wallet id & partner
                Card(
                  key: _kWalletIdCard,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Wallet: ${wc.walletId.value ?? '—'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy wallet ID',
                          onPressed: wc.walletId.value == null
                              ? null
                              : () {
                                  final id = wc.walletId.value!;
                                  Clipboard.setData(ClipboardData(text: id));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Copied: $id')),
                                  );
                                },
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if ((wc.partnerName.value).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 4.0,
                      right: 4.0,
                      bottom: 8,
                    ),
                    child: Text(
                      'Partner: ${wc.partnerName.value}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),

                if (joining) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(Icons.hourglass_top, color: cs.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Switching wallets… hold on a sec.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Invite by email (member-only)
                Text(
                  'Invite by email',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  key: _kInviteRow, // 👈

                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        enabled: isMember && !isBusy,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'friend@email.com',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: (!isMember || isBusy)
                          ? null
                          : () async {
                              final email = _emailCtrl.text.trim();
                              if (email.isEmpty) return;
                              await wc.sendInviteByEmail(email);
                              if (wc.errorMessage.value.isEmpty) {
                                _emailCtrl.clear();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invite sent.'),
                                    ),
                                  );
                                }
                              }
                            },
                      child: const Text('Send'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Join by wallet ID (manual)
                Text(
                  'Join by wallet ID',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  key: _kJoinRow, // ✅ add this

                  children: [
                    Expanded(
                      child: TextField(
                        controller: _joinCtrl,
                        enabled: !isBusy,
                        decoration: const InputDecoration(
                          hintText: 'target wallet id',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isBusy
                          ? null
                          : () async {
                              final id = _joinCtrl.text.trim();
                              if (id.isEmpty) return;
                              await wc.joinWalletById(id);
                              if (wc.errorMessage.value.isEmpty)
                                _joinCtrl.clear();
                            },
                      child: const Text('Join'),
                    ),
                  ],
                ),

                // Incoming invites — only show if any
                if (wc.incomingInvites.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Invitations for me',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...wc.incomingInvites.map((inv) {
                    final pending = inv.status == 'pending';
                    return Card(
                      child: ListTile(
                        title: Text('Wallet: ${inv.walletId}'),
                        subtitle: Text(
                          'From: ${inv.toEmail.isNotEmpty ? inv.toEmail : inv.fromUid}',
                        ),
                        trailing: pending
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed:
                                        (wc.loading.value || wc.joining.value)
                                        ? null
                                        : () => wc.rejectInvite(inv),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed:
                                        (wc.loading.value || wc.joining.value)
                                        ? null
                                        : () => _confirmAcceptInvite(
                                            context,
                                            invite: inv,
                                          ),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              )
                            : Text(inv.status.toUpperCase()),
                      ),
                    );
                  }),
                ],

                // Outgoing invites — only show if any
                if (wc.outgoingInvites.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Invitations I sent',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...wc.outgoingInvites.map((inv) {
                    return Card(
                      child: ListTile(
                        title: Text('To: ${inv.toEmail}'),
                        subtitle: Text('Status: ${inv.status}'),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // Members
                Column(
                  key: _kMembersSec, // ✅ wraps header + list
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (wc.members.isEmpty)
                      const Text('No members.')
                    else
                      ...wc.members.map((m) {
                        final canRemoveThis =
                            wc.isMember.value &&
                            !(wc.loading.value || wc.joining.value) &&
                            myUid != null &&
                            m.uid != myUid;
                        final label = (m.name.isNotEmpty
                            ? m.name
                            : (m.email.isNotEmpty ? m.email : m.uid));

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(m.name),
                            subtitle: Text(
                              m.email.isNotEmpty ? m.email : m.uid,
                            ),
                            trailing: IconButton(
                              tooltip: canRemoveThis ? 'Remove member' : null,
                              onPressed: canRemoveThis
                                  ? () => _confirmRemoveMember(
                                      context,
                                      memberUid: m.uid,
                                      label: label,
                                    )
                                  : null,
                              icon: const Icon(
                                Icons.person_remove_alt_1_outlined,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),

                const SizedBox(height: 32),

                // DANGER ZONE: Leave wallet (moved from AppBar to body)
                Card(
                  key: _kDangerCard, // 👈

                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Danger zone',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red.shade700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Leaving the wallet will remove your access. '
                          'You can choose whether to keep your existing expenses.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Obx(() {
                          final isBusy = wc.loading.value || wc.joining.value;
                          final myUid = FirebaseAuth.instance.currentUser?.uid;
                          final others = wc.members
                              .where((m) => m.uid != myUid)
                              .length;
                          final hasPartner = others > 0;

                          // Only enable when there is at least one other member AND not busy
                          final leaveEnabled = hasPartner && !isBusy;

                          final ButtonStyle leaveStyle =
                              OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ).copyWith(
                                // dim visuals when disabled
                                foregroundColor:
                                    MaterialStateProperty.resolveWith((states) {
                                      return states.contains(
                                            MaterialState.disabled,
                                          )
                                          ? Colors.red.shade200
                                          : Colors.red.shade700;
                                    }),
                                iconColor: MaterialStateProperty.resolveWith((
                                  states,
                                ) {
                                  return states.contains(MaterialState.disabled)
                                      ? Colors.red.shade200
                                      : Colors.red.shade700;
                                }),
                                side: MaterialStateProperty.resolveWith((
                                  states,
                                ) {
                                  return BorderSide(
                                    color:
                                        states.contains(MaterialState.disabled)
                                        ? Colors.red.shade100
                                        : Colors.red.shade300,
                                  );
                                }),
                                backgroundColor:
                                    MaterialStateProperty.resolveWith((states) {
                                      return states.contains(
                                            MaterialState.disabled,
                                          )
                                          ? Colors.red.shade50.withOpacity(0.25)
                                          : Colors.transparent;
                                    }),
                                overlayColor: MaterialStateProperty.resolveWith(
                                  (states) {
                                    return states.contains(
                                          MaterialState.disabled,
                                        )
                                        ? Colors.transparent
                                        : Colors.red.shade50.withOpacity(0.12);
                                  },
                                ),
                              );

                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Tooltip(
                              message: leaveEnabled
                                  ? 'Leave wallet'
                                  : (hasPartner
                                        ? 'Action disabled while busy'
                                        : 'Add a partner to enable'),
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout),
                                label: const Text('Leave wallet'),
                                style: leaveStyle,
                                onPressed: leaveEnabled
                                    ? () => _confirmLeaveDialog(context)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),

            if (isBusy)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),

            if (err.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Material(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      err,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
