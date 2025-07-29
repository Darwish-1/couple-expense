import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';

class SearchAndToggleCard extends StatelessWidget {
  const SearchAndToggleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (val) => Provider.of<HomeScreenProvider>(context, listen: false)
                  .updateSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search expenses...',
                prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), // Larger border radius for input
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blueGrey[50], // Softer fill color
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), // More padding
              ),
            ),
            const SizedBox(height: 15), // Increased spacing
            Selector<HomeScreenProvider, ({bool showWalletReceipts, bool isLoadingStream})>(
              selector: (_, provider) => (
                showWalletReceipts: provider.showWalletReceipts,
                isLoadingStream: provider.isLoadingStream,
              ),
              builder: (_, data, __) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: data.showWalletReceipts ? Colors.blue.shade100 : Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: data.showWalletReceipts ? Colors.blue.shade300 : Colors.deepPurple.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data.showWalletReceipts ? "Wallet Expenses 🤝" : "My Expenses 👤",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: data.showWalletReceipts ? Colors.blue.shade900 : Colors.deepPurple.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    data.isLoadingStream
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : Switch(
                            value: data.showWalletReceipts,
                            onChanged: (newValue) => Provider.of<HomeScreenProvider>(context, listen: false)
                                .toggleWalletReceipts(context),
                            activeColor: Colors.blue, // Active color for wallet view
                            inactiveThumbColor: Colors.deepPurple, // Inactive for my expenses view
                            inactiveTrackColor: Colors.deepPurple.shade200,
                            activeTrackColor: Colors.blue.shade200,
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}