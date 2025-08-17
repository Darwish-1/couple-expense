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
          effects: [
            const SlideEffect(
              begin: Offset(0, 0.3),
              duration: Duration(milliseconds: 400),
              curve: Curves.easeOut,
            ),
            const ScaleEffect(
              begin: Offset(0.8, 0.8),
              end: Offset(1.0, 1.0),
              duration: Duration(milliseconds: 400),
              curve: Curves.elasticOut,
            ),
            const FadeEffect(
              duration: Duration(milliseconds: 300),
            ),
          ],
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated checkmark icon
                Icon(
                  Icons.check_circle_rounded,
                  size: 50,
                  color: const Color(0xFF10B981), // Green color
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                ),
                
                const SizedBox(height: 12),
                
                // Success text
                Text(
                  'Saved!',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                    letterSpacing: -0.2,
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 300),
                ),
                
                // Count indicator (only show if > 0)
                if (savedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${savedCount} expense${savedCount == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 400),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}