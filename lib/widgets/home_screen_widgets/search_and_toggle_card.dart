import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';

class SearchAndToggleCard extends StatelessWidget {
  const SearchAndToggleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
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
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Selector<HomeScreenProvider, ({bool showWalletReceipts, bool isLoadingStream})>(
              selector: (_, provider) => (
                showWalletReceipts: provider.showWalletReceipts,
                isLoadingStream: provider.isLoadingStream,
              ),
              builder: (_, data, __) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    data.showWalletReceipts ? "Viewing Wallet Expenses" : "Viewing My Expenses",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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
                          activeColor: Theme.of(context).primaryColor,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}