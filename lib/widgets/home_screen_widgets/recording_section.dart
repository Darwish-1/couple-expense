import 'package:couple_expenses/widgets/home_screen_widgets/mic_recording_indicator.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:couple_expenses/controllers/mic_controller.dart';

class RecordingSection extends StatelessWidget {
  const RecordingSection({super.key});
  
  @override
  Widget build(BuildContext context) {
    final mic = Get.find<MicController>();
    
    return Obx(() {
      // Only show when explicitly told to show
      if (!mic.showMicIndicator.value) return const SizedBox.shrink();
      
      // Return the indicator directly - it will handle its own positioning
      return OptimizedMicIndicator(
        isRecording: mic.isRecording.value,
        isProcessing: mic.isProcessing.value,
     
      );
    });
  }
}