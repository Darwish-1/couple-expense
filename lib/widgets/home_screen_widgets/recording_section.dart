import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:couple_expenses/providers/home_screen_provider.dart'; // Make sure this path is correct

// New Widget: MicRecordingIndicator
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

class _MicRecordingIndicatorState extends State<MicRecordingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _updateAnimationState();
  }

  @override
  void didUpdateWidget(covariant MicRecordingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording || widget.isProcessing != oldWidget.isProcessing) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    if (widget.isRecording) {
      _controller.repeat(reverse: true); // Start pulsing when recording
    } else {
      _controller.stop();
      _controller.value = 0.0; // Reset animation when not recording
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording && !widget.isProcessing) {
      return const SizedBox.shrink(); // Don't show anything if not recording or processing
    }

    String statusText = '';
    IconData icon = Icons.mic;
    Color iconColor = Colors.white;

    Widget mainContent;

    if (widget.isRecording) {
      statusText = 'Recording...';
      mainContent = ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(icon, color: iconColor, size: 40),
      );
    } else if (widget.isProcessing) {
      statusText = 'Processing...';
      mainContent = const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 3,
      );
    } else {
      mainContent = const SizedBox.shrink(); // Should not happen due to initial check
    }

    return Center( // Center the pop-up
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.8), // Slightly less opaque
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content tightly
          children: [
            mainContent,
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}


// Your original RecordingSection widget, now using MicRecordingIndicator
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
        // Only show the MicRecordingIndicator if recording or processing
        if (data.isRecording || data.isProcessing) {
          return MicRecordingIndicator(
            isRecording: data.isRecording,
            isProcessing: data.isProcessing,
          );
        }
        return const SizedBox.shrink(); // Otherwise, don't show anything
      },
    );
  }
}