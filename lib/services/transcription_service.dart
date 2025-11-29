import 'dart:async';
import 'dart:io';
import 'package:leopard_flutter/leopard.dart';
import 'package:leopard_flutter/leopard_error.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'secure_storage_service.dart';

/// Transcription service using Picovoice Leopard
/// Supports local, offline speech-to-text
class TranscriptionService {
  Leopard? _leopard;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isInitialized = false;

  // Dual API key support: 1) Build-time, 2) Runtime
  static const String _buildTimeKey = String.fromEnvironment('PICOVOICE_KEY');
  String? _runtimeKey;

  bool get isInitialized => _isInitialized;

  /// Initialize Leopard with API key
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = await _getApiKey();

      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(
          'Picovoice API key required. Build with: flutter build apk --dart-define=PICOVOICE_KEY=your_key',
        );
      }

      // Model path - using default English model from assets
      const modelPath = 'assets/leopard_model.pv';

      _leopard = await Leopard.create(
        apiKey,
        modelPath,
        enableAutomaticPunctuation: true,
        enableDiarization: false, // Diarization requires Pro license
      );

      _isInitialized = true;
    } on LeopardException catch (e) {
      throw Exception('Leopard init error: ${e.message}');
    }
  }

  /// Get API key: Runtime (user) > Build-time > null
  Future<String?> _getApiKey() async {
    // Runtime key from secure storage
    _runtimeKey = await SecureStorageService.getPicovoiceKey();
    if (_runtimeKey != null && _runtimeKey!.isNotEmpty) {
      return _runtimeKey;
    }

    // Build-time key
    if (_buildTimeKey.isNotEmpty) {
      return _buildTimeKey;
    }

    return null;
  }

  /// Set API key at runtime
  Future<void> setApiKey(String key) async {
    await SecureStorageService.savePicovoiceKey(key);
    _runtimeKey = key;

    if (_isInitialized) {
      await _leopard?.delete();
      _isInitialized = false;
      await initialize();
    }
  }

  /// Check if API key exists
  Future<bool> hasApiKey() async {
    final key = await _getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Start recording
  Future<void> startRecording({void Function()? onSilenceDetected}) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/leopard_recording.wav';

    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );
  }

  /// Stop and transcribe
  Future<String> stopRecordingAndTranscribe() async {
    final path = await _audioRecorder.stop();

    if (path == null) {
      throw Exception('Recording failed');
    }

    return await transcribeFile(path);
  }

  /// Transcribe audio file
  Future<String> transcribeFile(String filePath) async {
    if (!_isInitialized || _leopard == null) {
      throw Exception('Leopard not initialized');
    }

    try {
      final result = await _leopard!.processFile(filePath);
      return result.transcript;
    } on LeopardException catch (e) {
      throw Exception('Transcription error: ${e.message}');
    }
  }

  /// Get last recording path
  Future<String?> getLastRecordingPath() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/leopard_recording.wav';
    if (await File(filePath).exists()) {
      return filePath;
    }
    return null;
  }

  /// Dispose
  void dispose() {
    _leopard?.delete();
    _audioRecorder.dispose();
  }
}
