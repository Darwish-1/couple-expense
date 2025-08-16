import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SuccessPopUp extends StatelessWidget {
  final int savedCount;

  const SuccessPopUp({super.key, required this.savedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // No overlay
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
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated checkmark with background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 50,
                    color: Colors.green.shade600,
                  ),
                )
                .animate()
                .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                ),
                
                const SizedBox(height: 20),
                
                // Main success text
                Text(
                  '✨ Success! ✨',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.indigo.shade700,
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 300),
                )
                .slideX(
                  begin: 0.2,
                  end: 0,
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 300),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Expense Saved!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                )
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 400),
                  delay: const Duration(milliseconds: 400),
                ),
                
                if (savedCount > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.indigo.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 16,
                          color: Colors.indigo.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$savedCount expense${savedCount == 1 ? '' : 's'} processed',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 500),
                  )
                  .slideY(
                    begin: 0.3,
                    end: 0,
                    duration: const Duration(milliseconds: 400),
                    delay: const Duration(milliseconds: 500),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Optional: Add a subtle "tap anywhere to dismiss" hint
                Text(
                  'Tap anywhere to continue',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .fadeIn(
                  duration: const Duration(milliseconds: 800),
                  delay: const Duration(milliseconds: 1000),
                )
                .then()
                .fadeOut(
                  duration: const Duration(milliseconds: 800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}