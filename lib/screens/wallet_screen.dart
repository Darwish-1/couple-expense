// lib/screens/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
            "You can move your own expenses to a personal wallet first, "
            "or just leave and keep them in this shared wallet.",
          ),
          actions: [
            TextButton(
              onPressed: disabled ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: disabled
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await wc.leaveCurrentWallet(migrateReceipts: false);
                      if (wc.errorMessage.value.isEmpty && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Left wallet.')),
                        );
                      }
                    },
              child: const Text("Leave (don’t move)"),
            ),
            ElevatedButton(
              onPressed: disabled
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await wc.leaveCurrentWallet(migrateReceipts: true);
                      if (wc.errorMessage.value.isEmpty && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Left wallet and kept your expenses.'),
                          ),
                        );
                      }
                    },
              child: const Text('Leave & keep my expenses'),
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
            "Do you want to move your past expenses from your previous wallet "
            "into this shared wallet you’re joining?\n\n"
            "• Move = your old expenses appear in Shared\n"
            "• Don’t move = your old expenses stay in your personal wallet",
          ),
          actions: [
            TextButton(
              onPressed: disabled ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: disabled
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await wc.acceptInvite(invite, moveMyOldToShared: false);
                      if (mounted && wc.errorMessage.value.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite accepted.')),
                        );
                      }
                    },
              child: const Text("Don’t move"),
            ),
            ElevatedButton(
              onPressed: disabled
                  ? null
                  : () async {
                      Navigator.of(ctx).pop();
                      await wc.acceptInvite(invite, moveMyOldToShared: true);
                      if (mounted && wc.errorMessage.value.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite accepted.')),
                        );
                      }
                    },
              child: const Text('Move my past expenses'),
            ),
          ],
        );
      }),
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
                    padding:
                        const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
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
                                    const SnackBar(content: Text('Invite sent.')),
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
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
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
                              if (wc.errorMessage.value.isEmpty) _joinCtrl.clear();
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
                                    onPressed: (wc.loading.value || wc.joining.value)
                                        ? null
                                        : () => wc.rejectInvite(inv),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: (wc.loading.value || wc.joining.value)
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
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
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
                Text(
                  'Members',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (wc.members.isEmpty)
                  const Text('No members.')
                else
                  ...wc.members.map(
                    (m) {
                      final canRemoveThis = wc.isMember.value &&
                          !isBusy &&
                          myUid != null &&
                          m.uid != myUid;
                      final label = (m.name.isNotEmpty
                          ? m.name
                          : (m.email.isNotEmpty ? m.email : m.uid));

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text(m.name),
                          subtitle: Text(m.email.isNotEmpty ? m.email : m.uid),
                          trailing: IconButton(
                            tooltip: canRemoveThis ? 'Remove member' : null,
                            onPressed: canRemoveThis
                                ? () => _confirmRemoveMember(
                                      context,
                                      memberUid: m.uid,
                                      label: label,
                                    )
                                : null,
                            icon: const Icon(Icons.person_remove_alt_1_outlined),
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 32),

                // DANGER ZONE: Leave wallet (moved from AppBar to body)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Danger zone',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
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
                          final isMember = wc.isMember.value;
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout),
                              label: const Text('Leave wallet'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                              ),
                              onPressed: (!isMember || isBusy)
                                  ? null
                                  : () => _confirmLeaveDialog(context),
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
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(0.6),
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
