import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class MicRecordingIndicator extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  const MicRecordingIndicator({super.key, required this.isRecording, required this.isProcessing});
  @override
  State<MicRecordingIndicator> createState() => _MicRecordingIndicatorState();
}

class _MicRecordingIndicatorState extends State<MicRecordingIndicator> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording && !widget.isProcessing) return const SizedBox.shrink();
    final statusText = widget.isRecording ? 'Recording...' : 'Processing...';
    final icon = widget.isRecording
        ? Icon(Icons.mic, size: 48, color: Colors.indigo.shade700)
            .animate()
            .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
        : const CircularProgressIndicator(color: Colors.indigo);

    return Center(
      child: Animate(
        effects: const [SlideEffect(begin: Offset(0, 0.5), duration: Duration(milliseconds: 300))],
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(height: 12),
          Text(statusText, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
        ]),
      ),
    );
  }
}
