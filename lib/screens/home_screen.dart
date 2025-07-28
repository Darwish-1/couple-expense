import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/providers/wallet_provider.dart'; // Still needed for joinWallet logic
import 'package:couple_expenses/screens/analytics_screen.dart';
import 'package:couple_expenses/screens/wallet_screen.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/search_and_toggle_card.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/total_spending_card.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/transaction_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.uid ?? '';

    if (userId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    return _HomeScreenContent(userId: userId);
  }
}

class _HomeScreenContent extends StatefulWidget {
  final String userId;

  const _HomeScreenContent({required this.userId});

  @override
  __HomeScreenContentState createState() => __HomeScreenContentState();
}

class __HomeScreenContentState extends State<_HomeScreenContent> {
  @override
  void initState() {
    super.initState();
    // Initialize stream after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeScreenProvider>(context, listen: false).initializeStream(context, widget.userId);
    });
  }

  @override
  void dispose() {
    print('HomeScreenContent: Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(
          "Hello, $userName! 👋",
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.deepPurple),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            tooltip: 'Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.deepPurple),
            tooltip: 'Logout',
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Track your expenses together.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                const SearchAndToggleCard(), // Extracted Widget
                const SizedBox(height: 20),
                TotalSpendingCard(userId: widget.userId), // Extracted Widget
                const SizedBox(height: 20),
                // This Selector part needs to stay here because it uses
                // walletIdController and directly calls joinWallet from HomeScreenProvider
                Selector<HomeScreenProvider, ({bool showWalletReceipts, TextEditingController walletIdController})>(
                  selector: (_, provider) => (
                    showWalletReceipts: provider.showWalletReceipts,
                    walletIdController: provider.walletIdController,
                  ),
                  builder: (context, data, _) {
                    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                    final walletId = Provider.of<AuthProvider>(context, listen: false).walletId;
                    if (walletId == null && data.showWalletReceipts) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                TextField(
                                  controller: data.walletIdController,
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
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => Provider.of<HomeScreenProvider>(context, listen: false)
                                        .joinWallet(walletProvider, context),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.teal,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                    ),
                                    child: const Text('Join Wallet', style: TextStyle(fontSize: 16)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recent Expenses",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: TransactionList(userId: widget.userId), // Extracted Widget
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Selector<HomeScreenProvider, ({bool isRecording, bool isProcessing})>(
        selector: (_, provider) => (
          isRecording: provider.isRecording,
          isProcessing: provider.isProcessing,
        ),
        builder: (context, data, _) => FloatingActionButton(
          onPressed: data.isRecording || data.isProcessing
              ? () => Provider.of<HomeScreenProvider>(context, listen: false)
                  .stopRecordingAndProcess(context)
              : () => Provider.of<HomeScreenProvider>(context, listen: false)
                  .startRecording(context),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 5,
          child: Icon(data.isRecording ? Icons.stop : Icons.mic, size: 30),
        ),
      ),
    );
  }
}