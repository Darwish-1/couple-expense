// lib/controllers/mic_controller.dart
import 'dart:io';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../services/gpt_parser.dart';

class MicParseResult {
  final String transcript;
  final List<Map<String, dynamic>> expenses;
  MicParseResult({required this.transcript, required this.expenses});
}

class MicController extends GetxController {
  final RxBool isRecording = false.obs;
  final RxBool isProcessing = false.obs;
  final RxString transcript = ''.obs;
  final RxBool showMicIndicator = false.obs;

  AudioRecorder? _recorder;

  Future<String> _tempPath({required bool useWebM}) async {
    final dir = await getTemporaryDirectory();
    final ext = useWebM ? 'webm' : 'm4a';
    return '${dir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  Future<void> startRecording() async {
    try {
      _recorder = AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        throw Exception('Microphone permission not granted');
      }

      // Show indicator and start recording
      showMicIndicator.value = true;
      isRecording.value = true;
      transcript.value = '';

      // Android => Opus/WebM, iOS => AAC/M4A
      final useWebM = Platform.isAndroid;
      final path = await _tempPath(useWebM: useWebM);

      final config = RecordConfig(
        encoder: useWebM ? AudioEncoder.opus : AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: useWebM ? 24000 : 32000,
        numChannels: 1,
      );

      await _recorder!.start(config, path: path);
    } catch (e) {
      // Reset everything on error
      isRecording.value = false;
      showMicIndicator.value = false;
      rethrow;
    }
  }

  /// Stops recording, transcribes the audio, parses expenses, and returns both.
  /// Returns null if nothing was recorded.
  Future<MicParseResult?> stopRecordingAndParse() async {
    try {
      if (!isRecording.value || _recorder == null) return null;

      // Switch to processing state
      isRecording.value = false;
      isProcessing.value = true;

      final path = await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;

      if (path == null) throw Exception('No audio file path');

      final file = File(path);

      // Wait briefly until the OS finishes flushing the file
      if (!await _waitForNonEmpty(file)) {
        throw Exception('Recorded file is empty or not ready');
      }

      // 1) Transcribe (fast model then fallback)
      final t = await GptParser.transcribeAudio(file);
      transcript.value = t ?? '';

      // 2) Parse to structured expenses (fast lane → LLM fallback)
      List<Map<String, dynamic>> expenses = [];
      if (t != null && t.isNotEmpty) {
        final fast = GptParser.fastLaneExtract(t);
        if (fast != null && fast.isNotEmpty) {
          expenses = fast;
        } else {
          final parsed = await GptParser.extractStructuredData(t);
          if (parsed != null) expenses = parsed;
        }
      }

      // Clean up temp
      try { await file.delete(); } catch (_) {}

      return MicParseResult(transcript: transcript.value, expenses: expenses);
    } finally {
      isProcessing.value = false;
      showMicIndicator.value = false;
      await _recorder?.dispose();
      _recorder = null;
    }
  }

  Future<bool> _waitForNonEmpty(File f) async {
    for (var i = 0; i < 5; i++) {
      if (await f.exists()) {
        final len = await f.length();
        if (len > 512) return true;
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return false;
  }

  @override
  void onClose() {
    _recorder?.dispose();
    _recorder = null;
    super.onClose();
  }
}