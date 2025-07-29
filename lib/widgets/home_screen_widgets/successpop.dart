// widgets/home_screen_widgets/success_pop_up.dart
import 'package:flutter/material.dart';

class SuccessPopUp extends StatelessWidget {
  final int savedCount;

  const SuccessPopUp({super.key, required this.savedCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material( // Use Material to apply elevation and shape
        color: Colors.transparent, // Make Material transparent
        child: Container(
          padding: const EdgeInsets.all(15), // Slightly more padding
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.85), // Slightly less opaque
            borderRadius: BorderRadius.circular(25), // Larger border radius
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content tightly
            children: [
              const Icon(
                Icons.check_circle_outline, // Tick icon
                color: Colors.white,
                size: 65, // Slightly larger icon
              ),
              const SizedBox(height: 12), // More spacing
              Text(
                'Expense Saved!', // Simpler text
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (savedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 5.0),
                  child: Text(
                    '$savedCount pending expenses processed.', // More informative
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}