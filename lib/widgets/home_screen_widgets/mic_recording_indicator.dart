import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OptimizedMicIndicator extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;
  final Animation<double>? scaleAnimation;
  final Animation<Offset>? slideAnimation;
  final AnimationController? animationController;

  const OptimizedMicIndicator({
    super.key,
    required this.isRecording,
    required this.isProcessing,
    this.scaleAnimation,
    this.slideAnimation,
    this.animationController,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show if neither recording nor processing
    if (!isRecording && !isProcessing) return const SizedBox.shrink();
    
    final statusText = isRecording ? 'Recording...' : 'Processing...';
    
    return Positioned.fill(
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fixed container size for consistent positioning
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Center(
                    child: isRecording
                      ? Icon(
                          Icons.mic,
                          size: 90,
                          color: Colors.indigo.shade700,
                        )
                      : CircularProgressIndicator(
                          color: Colors.indigo.shade700,
                          strokeWidth: 4,
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}