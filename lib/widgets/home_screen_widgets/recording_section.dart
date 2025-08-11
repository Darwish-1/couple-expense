import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class MicRecordingIndicator extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;

  const MicRecordingIndicator({
    super.key,
    required this.isRecording,
    required this.isProcessing,
  });

  @override
  State<MicRecordingIndicator> createState() => _MicRecordingIndicatorState();
}

class _MicRecordingIndicatorState extends State<MicRecordingIndicator> {
  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording && !widget.isProcessing) {
      return const SizedBox.shrink();
    }
  print("MicRecordingIndicator - isRecording: ${widget.isRecording}, isProcessing: ${widget.isProcessing}");

    String statusText = widget.isRecording ? 'Recording...' : 'Processing...';
    Widget icon = widget.isRecording
        ? Icon(Icons.mic, size: 48, color: Colors.indigo.shade700).animate().scale(
  begin:Offset(1.2, 1.2),
  end: Offset(1, 1),
  duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            )
        : const CircularProgressIndicator(color: Colors.indigo);

    return Container(
      color: Colors.transparent,
      child: Center(
        child: Animate(
          effects: const [SlideEffect(begin: Offset(0, 0.5), duration: Duration(milliseconds: 300))],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 12),
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
    );
  }
}

class RecordingSection extends StatelessWidget {
  const RecordingSection({super.key});

  @override
  Widget build(BuildContext context) {
    
    return Selector<HomeScreenProvider, ({bool isRecording, bool isProcessing})>(
      selector: (_, provider) => (
        isRecording: provider.isRecording,
        isProcessing: provider.isProcessing,
      ),
      builder: (context, data, _) {
        print("isRecording: ${data.isRecording}, isProcessing: ${data.isProcessing}");

        if (data.isRecording || data.isProcessing) {
          return MicRecordingIndicator(
            isRecording: data.isRecording,
            isProcessing: data.isProcessing,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}