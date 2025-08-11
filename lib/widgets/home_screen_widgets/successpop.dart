import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SuccessPopUp extends StatelessWidget {
  final int savedCount;

  const SuccessPopUp({super.key, required this.savedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: Animate(
          effects: const [SlideEffect(begin: Offset(0, 0.5), duration: Duration(seconds: 1))],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.indigo.shade700,
              ),
              const SizedBox(height: 12),
              Text(
                'Expense Saved!',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade700,
                ),
              ),
              if (savedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '$savedCount expenses processed.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              
            ],
          ),
        ),
      ),
    );
  }
}