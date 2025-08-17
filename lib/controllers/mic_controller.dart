// lib/controllers/mic_controller.dart
import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/azure_gemini_direct_parser.dart';
import 'expenses_controller.dart' show saveMultipleExpenses, ExpensesController;

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

  // progress bar state
  final RxDouble recordingProgress = 0.0.obs; // 0.0 → 1.0
  final int maxSeconds = 15;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _autoStopped = false; // 👈 flag to know if timer stopped it

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

      showMicIndicator.value = true;
      isRecording.value = true;
      transcript.value = '';
      recordingProgress.value = 0.0;
      _elapsedSeconds = 0;
      _autoStopped = false;

      final useWebM = Platform.isAndroid;
      final path = await _tempPath(useWebM: useWebM);

      final config = RecordConfig(
        encoder: useWebM ? AudioEncoder.opus : AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: useWebM ? 24000 : 32000,
        numChannels: 1,
      );

      await _recorder!.start(config, path: path);

      // start timer to update progress
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        _elapsedSeconds++;
        recordingProgress.value = _elapsedSeconds / maxSeconds;

        if (_elapsedSeconds >= maxSeconds) {
          _autoStopped = true; // 👈 mark auto-stop
          await stopRecordingAndParse();
        }
      });
    } catch (e) {
      isRecording.value = false;
      showMicIndicator.value = false;
      rethrow;
    }
  }

  /// Stops recording, sends audio to Azure, parses with Gemini, returns both.
  Future<MicParseResult?> stopRecordingAndParse() async {
    try {
      if (!isRecording.value || _recorder == null) return null;

      isRecording.value = false;
      isProcessing.value = true;
      _timer?.cancel();

      final path = await _recorder!.stop();
      await _recorder!.dispose();
      _recorder = null;

      if (path == null) throw Exception('No audio file path');
      final file = File(path);

      if (!await _waitForNonEmpty(file)) {
        throw Exception('Recorded file is empty or not ready');
      }

      final result = await AzureGeminiDirectParser.transcribeAndParse(file);

      // Clean up temp
      try {
        await file.delete();
      } catch (_) {}

      final tx = (result?['transcript'] ?? '').toString();
      final ex = ((result?['expenses'] ?? []) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      transcript.value = tx.trim().isEmpty ? '[No speech detected]' : tx;

      // 👇 auto-save only if timer forced the stop
      if (_autoStopped) {
        _autoStopped = false; // reset
        if (ex.isNotEmpty) {
await Get.find<ExpensesController>().saveMultipleExpenses(ex);
        }
      }

      return MicParseResult(transcript: tx, expenses: ex);
    } finally {
      isProcessing.value = false;
      showMicIndicator.value = false;
      await _recorder?.dispose();
      _recorder = null;
      _timer?.cancel();
    }
  }

  Future<bool> _waitForNonEmpty(File f) async {
    for (var i = 0; i < 3; i++) {
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
    _timer?.cancel();
    super.onClose();
  }
}
