import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SearchAndToggleCard extends StatelessWidget {
  const SearchAndToggleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) {
                Provider.of<HomeScreenProvider>(context, listen: false).updateSearchQuery(val);
                debugPrint('Search query updated: $val');
              },
              style: GoogleFonts.inter(color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: 'Search expenses...',
                hintStyle: GoogleFonts.inter(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.indigo.shade700),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Selector<HomeScreenProvider, ({bool showWalletReceipts, bool isLoadingStream})>(
            selector: (_, provider) => (
              showWalletReceipts: provider.showWalletReceipts,
              isLoadingStream: provider.isLoadingStream,
            ),
            builder: (_, data, __) => Tooltip(
              message: 'Switch between your personal and shared expenses',
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      'My Expenses',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: data.showWalletReceipts ? Colors.grey.shade600 : Colors.amber.shade600,
                      ),
                    ),
                    icon: Icon(
                      Icons.person,
                      size: 16,
                      color: data.showWalletReceipts ? Colors.grey.shade600 : Colors.amber.shade600,
                    ),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      'Shared Expenses',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: data.showWalletReceipts ? Colors.amber.shade600 : Colors.grey.shade600,
                      ),
                    ),
                    icon: Icon(
                      Icons.group,
                      size: 16,
                      color: data.showWalletReceipts ? Colors.amber.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
                selected: {data.showWalletReceipts},
                onSelectionChanged: (newSelection) {
                  final newValue = newSelection.first;
                  Provider.of<HomeScreenProvider>(context, listen: false).toggleWalletReceipts(context);
                  debugPrint('Toggled wallet receipts: showWalletReceipts=$newValue');
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.indigo.shade700;
                    }
                    return Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.all(Colors.amber.shade600),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ).animate().slideX(begin: 0.2, end: 0, duration: 200.ms).fadeIn(duration: 200.ms),
            ),
          ),
        ],
      ),
    );
  }
}