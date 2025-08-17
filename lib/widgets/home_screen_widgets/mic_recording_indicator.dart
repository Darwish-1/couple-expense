// lib/widgets/home_screen_widgets/mic_recording_indicator.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:couple_expenses/controllers/mic_controller.dart';

class OptimizedMicIndicator extends StatelessWidget {
  final bool isRecording;
  final bool isProcessing;

  const OptimizedMicIndicator({
    super.key,
    required this.isRecording,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final mic = Get.find<MicController>();

    if (!isRecording && !isProcessing) return const SizedBox.shrink();

    return Positioned.fill(
      child: Center(
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer progress ring
              if (isRecording)
                Obx(() {
                  final progress = mic.recordingProgress.value.clamp(0.0, 1.0);
                  return SizedBox(
                    width: 160,
                    height: 160,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF6366F1),
                      ),
                    ),
                  );
                }),

              // Center content
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon without animation
                  Icon(
                    isRecording ? Icons.mic_rounded : Icons.more_horiz_rounded,
                    size: 36,
                    color: const Color(0xFF6366F1),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Status text without animation
                  Text(
                    isRecording ? 'Listening' : 'Processing',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                      letterSpacing: -0.2,
                    ),
                  ),
                  
                  // Timer (only show when recording)
                  if (isRecording)
                    Obx(() {
                      final progress = mic.recordingProgress.value.clamp(0.0, 1.0);
                      final remaining = (mic.maxSeconds - (progress * mic.maxSeconds)).ceil();
                      
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: AnimatedOpacity(
                          opacity: remaining <= 5 ? 1.0 : 0.7,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            '${remaining}s',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: remaining <= 5 
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}