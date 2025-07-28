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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.9), // Green background
            borderRadius: BorderRadius.circular(20),
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
                size: 60,
              ),
              const SizedBox(height: 10),
              Text(
                'Successfully saved expense',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}