import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeScreenProvider>(context, listen: false).initializeStream(context, widget.userId);
    });
  }

  @override
  void dispose() {
    debugPrint('HomeScreenContent: Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.user?.displayName?.split(' ').first ?? 'there';

    return FutureBuilder(
      future: Provider.of<AuthProvider>(context, listen: false).waitForInitialization(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.blue)),
          );
        }
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(
              "Hello, $userName! 👋",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.blue,
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.blue),
                tooltip: 'Analytics',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet, color: Colors.blue),
                tooltip: 'Wallet',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WalletScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.blue),
                tooltip: 'Logout',
                onPressed: () async {
                  await authProvider.signOut();
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
                      style: TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 20),
                    const SearchAndToggleCard(),
                    const SizedBox(height: 20),
                    TotalSpendingCard(userId: widget.userId),
                    const SizedBox(height: 20),
                    Selector<AuthProvider, String?>(
                      selector: (_, provider) => provider.walletId,
                      builder: (context, walletId, _) {
                        if (walletId == null) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Card(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'No Wallet Joined!',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'Join or create a wallet to share expenses with your partner.',
                                      style: TextStyle(fontSize: 14, color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 15),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const WalletScreen()),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueAccent, // More vibrant color
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          elevation: 5,
                                        ),
                                        child: const Text('Join or Create Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                  color: Colors.white, // Background for the list section
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Recent Expenses",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TransactionList(userId: widget.userId),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              backgroundColor: Colors.blueAccent, // Consistent primary color
              foregroundColor: Colors.white,
              elevation: 6,
              shape: const CircleBorder(),
              child: Icon(data.isRecording ? Icons.stop : Icons.mic, size: 30),
            ),
          ),
        );
      },
    );
  }
}