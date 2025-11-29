import 'dart:async';
import 'dart:io';
import 'package:cactus/cactus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class TranscriptionService {
  final CactusSTT _stt = CactusSTT();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool get isInitialized => _stt.isLoaded();

  Future<void> downloadModel({
    required Function(double progress, String status) onProgress,
  }) async {
    try {
      await _stt.downloadModel(
        model: "local-whisper-medium",
        downloadProcessCallback: (progress, status, isError) {
          if (isError) {
            onProgress(0, "Error: $status");
          } else {
            onProgress(progress ?? 0, status);
          }
        },
      );
    } catch (e) {
      onProgress(0, "Download failed: $e");
      rethrow;
    }
  }

  Future<void> initializeModel() async {
    if (_stt.isLoaded()) return;

    await _stt.initializeModel(
      params: CactusInitParams(model: "local-whisper-medium"),
    );
  }

  Timer? _amplitudeTimer;
  int _silenceCounter = 0;
  static const int _silenceThresholdMs = 2000; // 2 seconds of silence
  static const int _checkIntervalMs = 100;
  static const double _amplitudeThresholdDb = -20.0;

  Future<void> startRecording({void Function()? onSilenceDetected}) async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/temp_recording.wav';

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Start recording to file
      // Start recording to file
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000, // 16000 * 16 bits
          echoCancel: false,
          noiseSuppress: false,
          autoGain: false,
        ),
        path: filePath,
      );

      // Start VAD monitoring
      _silenceCounter = 0;
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(
        const Duration(milliseconds: _checkIntervalMs),
        (timer) async {
          final amplitude = await _audioRecorder.getAmplitude();
          if (amplitude.current < _amplitudeThresholdDb) {
            _silenceCounter += _checkIntervalMs;
            if (_silenceCounter >= _silenceThresholdMs) {
              timer.cancel();
              onSilenceDetected?.call();
            }
          } else {
            _silenceCounter = 0;
          }
        },
      );
    } else {
      throw Exception("Microphone permission denied");
    }
  }

  Future<String> stopRecordingAndTranscribe() async {
    _amplitudeTimer?.cancel(); // Stop VAD timer
    final path = await _audioRecorder.stop();

    if (path == null) {
      throw Exception("Recording failed or was not started");
    }

    return await transcribeFile(path);
  }

  Future<Stream<String>> stopRecordingAndTranscribeStream() async {
    _amplitudeTimer?.cancel();
    final path = await _audioRecorder.stop();

    if (path == null) {
      throw Exception("Recording failed or was not started");
    }

    return transcribeFileStream(path);
  }

  Future<String> transcribeFile(String filePath) async {
    if (!_stt.isLoaded()) {
      throw Exception("Model not initialized");
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Audio file not found at $filePath");
    }

    final result = await _stt.transcribe(audioFilePath: filePath);
    if (result.success) {
      return result.text;
    } else {
      throw Exception(result.errorMessage ?? "Unknown transcription error");
    }
  }

  Stream<String> transcribeFileStream(String filePath) async* {
    if (!_stt.isLoaded()) {
      throw Exception("Model not initialized");
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception("Audio file not found at $filePath");
    }

    final result = await _stt.transcribeStream(audioFilePath: filePath);
    yield* result.stream;
  }

  Future<String?> getLastRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/temp_recording.wav';
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _stt.unload();
    _audioRecorder.dispose();
  }
}
