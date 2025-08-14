import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:couple_expenses/controllers/mic_controller.dart';
import 'package:couple_expenses/widgets/home_screen_widgets/mic_recording_indicator.dart';

class RecordingSection extends StatelessWidget {
  const RecordingSection({super.key});
  @override
  Widget build(BuildContext context) {
    final mic = Get.find<MicController>();
    return Obx(() {
      final rec = mic.isRecording.value, proc = mic.isProcessing.value;
      if (!rec && !proc) return const SizedBox.shrink();
      return MicRecordingIndicator(isRecording: rec, isProcessing: proc);
    });
  }
}
