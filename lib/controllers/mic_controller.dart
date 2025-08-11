// lib/controllers/mic_controller.dart
import 'dart:io';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../services/gpt_parser.dart'; // keep your existing GptParser

class MicParseResult {
  final String transcript;
  final List<Map<String, dynamic>> expenses;

  MicParseResult({
    required this.transcript,
    required this.expenses,
  });
}

class MicController extends GetxController {
  final RxBool isRecording = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString transcript = ''.obs;

  AudioRecorder? _recorder;

  Future<String> _getTempFilePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  Future<void> startRecording() async {
    try {
      _recorder = AudioRecorder();
      if (await _recorder!.hasPermission()) {
        final path = await _getTempFilePath();
        await _recorder!.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            bitRate: 64000,
          ),
          path: path,
        );
        isRecording.value = true;
        transcript.value = '';
      } else {
        throw Exception('Microphone permission not granted');
      }
    } catch (e) {
      isRecording.value = false;
      rethrow;
    }
  }

  /// Stops recording, transcribes the audio, parses expenses, and returns both.
  /// Returns null if nothing was recorded.
  Future<MicParseResult?> stopRecordingAndParse() async {
    try {
      if (!isRecording.value || _recorder == null) return null;

      isRecording.value = false;
      isProcessing.value = true;

      final path = await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;

      if (path == null || !File(path).existsSync()) {
        throw Exception('No audio file found');
      }

      final file = File(path);

      // 1) Transcribe
      final t = await GptParser.transcribeAudio(file);
      transcript.value = t ?? '';

      // 2) Parse to structured expenses
      List<Map<String, dynamic>> expenses = [];
      if (t != null && t.isNotEmpty) {
        final parsed = await GptParser.extractStructuredData(t);
        if (parsed != null) {
          expenses = parsed;
        }
      }

      // Clean up temp
      try {
        await file.delete();
      } catch (_) {}

      return MicParseResult(transcript: transcript.value, expenses: expenses);
    } catch (e) {
      rethrow;
    } finally {
      isProcessing.value = false;
      await _recorder?.dispose();
      _recorder = null;
    }
  }

  @override
  void onClose() {
    _recorder?.dispose();
    _recorder = null;
    super.onClose();
  }
}
