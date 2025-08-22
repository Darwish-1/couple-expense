import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SuccessPopUp extends StatefulWidget {
  final int savedCount;
  final String contextLabel;
  final bool autoSwitchTab;        // optional: control tab switching
  final int switchToIndex;         // which tab to switch to

  const SuccessPopUp({
    super.key,
    required this.savedCount,
    required this.contextLabel,
    this.autoSwitchTab = true,
    this.switchToIndex = 1,        // pending tab by default
  });

  @override
  State<SuccessPopUp> createState() => _SuccessPopUpState();
}

class _SuccessPopUpState extends State<SuccessPopUp> {
  @override
  void initState() {
    super.initState();

    // Run after first frame so context is fully mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.autoSwitchTab) return;

      // ✅ Safe lookup: returns null if no DefaultTabController in the tree.
      final controller = DefaultTabController.maybeOf(context);
      if (controller != null && widget.switchToIndex >= 0 &&
          widget.switchToIndex < controller.length) {
        // A tiny delay keeps the popup animation smooth.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) controller.animateTo(widget.switchToIndex);
        });
      }
      // If controller is null, silently skip (no exception).
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.savedCount;
    final message = count > 0
        ? '$count expense${count == 1 ? '' : 's'} added to ${widget.contextLabel}'
        : 'Expense saved in ${widget.contextLabel}';

    return Container(
      color: Colors.transparent,
      child: Center(
        child: Animate(
          effects: const [
            SlideEffect(begin: Offset(0, 0.3), duration: Duration(milliseconds: 400), curve: Curves.easeOut),
            ScaleEffect(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0), duration: Duration(milliseconds: 400), curve: Curves.elasticOut),
            FadeEffect(duration: Duration(milliseconds: 300)),
          ],
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, size: 60, color: const Color(0xFF10B981))
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 200),
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ).animate().fadeIn(duration: const Duration(milliseconds: 400), delay: const Duration(milliseconds: 300)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
