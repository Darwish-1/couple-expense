import 'package:couple_expenses/providers/transaction_list_provider.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/recording_section.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/successpop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/auth_provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:couple_expenses/screens/analytics_screen.dart';
import 'package:couple_expenses/screens/wallet_screen.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/search_and_toggle_card.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/total_spending_card.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/transaction_list.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      Provider.of<TransactionListProvider>(context, listen: false)
          .initializeStream(context, widget.userId, authProvider.walletId, false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userName = authProvider.user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Hi, $userName!',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.indigo.shade700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(80),
          child: SearchAndToggleCard(),
        ),
      ),
      body: Stack(
        children: [
          // MAIN CONTENT: Does NOT rebuild unless its own state changes!
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Animate(
                effects: const [FadeEffect(duration: Duration(milliseconds: 600))],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TotalSpendingCard(userId: widget.userId),
                    const SizedBox(height: 16),
                    Selector<AuthProvider, String?>(
                      selector: (_, provider) => provider.walletId,
                      builder: (context, walletId, _) {
                        if (walletId == null) {
                          return Card(
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    'No Wallet Joined',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Join or create a wallet to share expenses.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.indigo.shade700,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                    ),
                                    child: Text(
                                      'Join Wallet',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recent Expenses',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // This widget doesn't care about overlay state!
                    TransactionList(userId: widget.userId),
                  ],
                ),
              ),
            ),
          ),
          // === OVERLAYS: Only these rebuild on overlay state ===

          // Mic / processing overlay
          const RecordingSection(),

          // Success popup overlay
          Selector<HomeScreenProvider, ({bool showSuccessPopup, int savedExpensesCount})>(
            selector: (_, provider) => (
              showSuccessPopup: provider.showSuccessPopup,
              savedExpensesCount: provider.savedExpensesCount,
            ),
            builder: (context, data, _) {
              if (data.showSuccessPopup) {
                return SuccessPopUp(savedCount: data.savedExpensesCount);
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 2,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.bar_chart, color: Colors.indigo.shade700),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                );
              },
              tooltip: 'Analytics',
            ),
            IconButton(
              icon: Icon(Icons.account_balance_wallet, color: Colors.indigo.shade700),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                );
              },
              tooltip: 'Wallet',
            ),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.indigo.shade700),
              onPressed: () async {
                await authProvider.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              tooltip: 'Logout',
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Selector<HomeScreenProvider, ({bool isRecording, bool isProcessing})>(
        selector: (_, provider) => (
          isRecording: provider.isRecording,
          isProcessing: provider.isProcessing,
        ),
        builder: (context, data, _) => FloatingActionButton(
          onPressed: data.isRecording || data.isProcessing
              ? () => Provider.of<HomeScreenProvider>(context, listen: false).stopRecordingAndProcess(context)
              : () => Provider.of<HomeScreenProvider>(context, listen: false).startRecording(context),
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          tooltip: data.isRecording ? 'Stop Recording' : 'Start Recording',
          child: Icon(data.isRecording ? Icons.stop : Icons.mic, size: 28),
        ).animate().scale(duration: const Duration(milliseconds: 200)),
      ),
    );
  }
}
