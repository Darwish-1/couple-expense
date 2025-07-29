import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _walletIdController = TextEditingController();
  final TextEditingController _inviteEmailController = TextEditingController();

  @override
  void initState() {
   super.initState();

  // Delay to ensure context is available
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final walletId = args?['walletId'];

    if (walletId != null) {
      context.read<WalletProvider>().fetchWallet(walletId);
    }
  });
  }

  @override
  void dispose() {
    _walletIdController.dispose();
    _inviteEmailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _leaveWallet(WalletProvider walletProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Leave Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to leave this wallet? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Leave"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await walletProvider.leaveWallet(_auth.currentUser!.uid, context);
      _showSnackBar(walletProvider.errorMessage, "Left wallet", success: success);
    }
  }

  Future<void> _removeMember(WalletProvider walletProvider, Map<String, String> member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Remove Member", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove ${member['email']} from this wallet?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await walletProvider.removeUserByUid(
        member['uid']!,
        walletProvider.wallet!.id,
        _auth.currentUser!.uid,
      );
      _showSnackBar(walletProvider.errorMessage, "Member removed", success: success);
    }
  }

  void _showSnackBar(String? errorMessage, String successMessage, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "✅ $successMessage" : "❌ ${errorMessage ?? 'An error occurred'}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.status == AuthStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (authProvider.status == AuthStatus.unauthenticated) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Your Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
              centerTitle: true,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () => authProvider.signInWithGoogle(),
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text("Sign in with Google", style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          );
        }
        if (authProvider.status == AuthStatus.error) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      authProvider.errorMessage ?? 'Authentication error occurred',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => authProvider.signInWithGoogle(),
                      child: const Text("Retry Sign-In"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      return Consumer<WalletProvider>(
  builder: (context, walletProvider, _) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Your Wallet", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: walletProvider.wallet != null
            ? [
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  tooltip: "Leave Wallet",
                  onPressed: () => _leaveWallet(walletProvider),
                ),
              ]
            : null,
      ),
      body: walletProvider.loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent))
          : walletProvider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      walletProvider.errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : walletProvider.wallet != null
                  ? _buildWalletDetails(walletProvider, Theme.of(context))
                  : _buildNoWalletState(walletProvider, Theme.of(context)),
    );
  },
);

      },
    );
  }

  Widget _buildWalletDetails(WalletProvider walletProvider, ThemeData theme) {
    if (walletProvider.wallet == null) {
      return Center(
        child: Text(
          "Wallet data is not available",
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🎉 Your Wallet",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColorDark),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            context,
            [
              _buildInfoRow("Wallet ID:", walletProvider.wallet!.id, Icons.credit_card),
              _buildInfoRow("Wallet Name:", walletProvider.wallet!['name']?.toString() ?? 'Unnamed Wallet', Icons.wallet),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            "Members (${walletProvider.memberData.length})",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColorDark),
          ),
          const SizedBox(height: 15),
          if (walletProvider.memberData.isEmpty)
            Text("No members in this wallet yet.", style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]))
          else
            _buildInfoCard(
              context,
              walletProvider.memberData.map(
                (member) => _buildMemberTile(walletProvider, member, theme),
              ).toList(),
            ),
          const SizedBox(height: 30),
          Text(
            "Invite New Member",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColorDark),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _inviteEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: "Member's Email",
              hintText: "Enter email to invite",
              prefixIcon: const Icon(Icons.email_outlined, color: Colors.deepPurpleAccent),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final email = _inviteEmailController.text.trim();
                if (!_isValidEmail(email)) {
                  _showSnackBar("Please enter a valid email address", "", success: false);
                  return;
                }
                final success = await walletProvider.addUserByEmail(
                  email,
                  walletProvider.wallet!.id,
                  _auth.currentUser!.uid,
                );
                _showSnackBar(walletProvider.errorMessage, "User added to wallet", success: success);
                if (success) {
                  _inviteEmailController.clear();
                }
              },
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Add to Wallet", style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: Colors.deepPurpleAccent.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoWalletState(WalletProvider walletProvider, ThemeData theme) {
    if (walletProvider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar(walletProvider.errorMessage, "", success: false);
      });
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: theme.primaryColor.withOpacity(0.6)),
          const SizedBox(height: 20),
          Text(
            "You don't have a wallet yet!",
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColorDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            "Create a new one or join an existing wallet to get started.",
            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await walletProvider.createWallet(
                  _auth.currentUser!.uid,
                  _auth.currentUser!.displayName ?? 'User',
                  context,
                );
                _showSnackBar(walletProvider.errorMessage, "Wallet created", success: success);
              },
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text("Create New Wallet", style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
                shadowColor: Colors.deepPurple.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 25),
          const Divider(height: 20, thickness: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 25),
          TextField(
            controller: _walletIdController,
            decoration: InputDecoration(
              labelText: "Join Wallet by ID",
              hintText: "Enter Wallet ID",
              prefixIcon: const Icon(Icons.tag, color: Colors.teal),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final walletId = _walletIdController.text.trim();
                if (walletId.isEmpty) {
                  _showSnackBar("Please enter a wallet ID", "", success: false);
                  return;
                }
                final success = await walletProvider.joinWallet(
                  walletId,
                  _auth.currentUser!.uid,
                  context,
                );
                _showSnackBar(walletProvider.errorMessage, "Joined wallet", success: success);
                if (success) {
                  _walletIdController.clear();
                }
              },
              icon: const Icon(Icons.arrow_circle_right_outlined, color: Colors.teal),
              label: const Text("Join Wallet", style: TextStyle(fontSize: 16, color: Colors.teal)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 10),
          Text(
            "$label ",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(WalletProvider walletProvider, Map<String, String> member, ThemeData theme) {
    final isCurrentUser = member['uid'] == _auth.currentUser!.uid;
    final isWalletOwner = walletProvider.wallet?['ownerUid'] == _auth.currentUser!.uid;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.deepPurple.withOpacity(0.1),
        child: Text(
          member['email']!.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        member['email']!,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey),
      ),
      subtitle: isCurrentUser ? const Text("You", style: TextStyle(color: Colors.green, fontSize: 12)) : null,
      trailing: isWalletOwner && !isCurrentUser
          ? IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.redAccent),
              onPressed: () => _removeMember(walletProvider, member),
              tooltip: "Remove Member",
            )
          : null,
      onLongPress: isWalletOwner && !isCurrentUser
          ? () => _removeMember(walletProvider, member)
          : null,
      contentPadding: EdgeInsets.zero,
    );
  }
}