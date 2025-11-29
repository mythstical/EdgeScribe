import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/transcription_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider(create: (_) => TranscriptionService())],
      child: MaterialApp(
        title: 'EdgeScribe',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.teal,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            elevation: 0,
          ),
        ),
        home: const TranscriptionScreen(),
      ),
    );
  }
}

class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key});

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  String _transcribedText = "";
  String _status = "Initializing...";
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isModelReady = false;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    final service = Provider.of<TranscriptionService>(context, listen: false);
    try {
      setState(() => _status = "Downloading model...");
      await service.downloadModel(
        onProgress: (progress, status) {
          setState(() {
            _status = "$status ${(progress * 100).toStringAsFixed(1)}%";
          });
        },
      );

      setState(() => _status = "Initializing model...");
      await service.initializeModel();

      setState(() {
        _isModelReady = true;
        _status = "Ready to record";
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _toggleRecording() async {
    final service = Provider.of<TranscriptionService>(context, listen: false);

    if (_isRecording) {
      // Stop recording
      try {
        setState(() {
          _isRecording = false;
          _isTranscribing = true;
          _status = "Transcribing...";
        });

        final stream = await service.stopRecordingAndTranscribeStream();

        await for (final token in stream) {
          setState(() {
            _transcribedText += token;
          });
        }

        setState(() {
          _isTranscribing = false;
          _status = "Ready to record";
          _transcribedText += "\n\n"; // Add spacing for next recording
        });
      } catch (e) {
        setState(() {
          _isTranscribing = false;
          _status = "Error: $e";
        });
      }
    } else {
      // Start recording
      try {
        await service.startRecording(
          onSilenceDetected: () {
            // Automatically stop recording when silence is detected
            if (mounted && _isRecording) {
              _toggleRecording();
            }
          },
        );
        setState(() {
          _isRecording = true;
          _status = "Recording... (Speak now)";
        });
      } catch (e) {
        setState(() => _status = "Error: $e");
      }
    }
  }

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playLastRecording() async {
    final service = Provider.of<TranscriptionService>(context, listen: false);
    final path = await service.getLastRecordingPath();

    if (path != null) {
      try {
        await _audioPlayer.play(DeviceFileSource(path));
      } catch (e) {
        setState(() => _status = "Playback error: $e");
      }
    } else {
      setState(() => _status = "No recording found");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EdgeScribe'),
        actions: [
          if (!_isRecording && !_isTranscribing)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play Last Recording',
              onPressed: _playLastRecording,
            ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _isRecording
                ? Colors.red.withValues(alpha: 0.1)
                : _isTranscribing
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.transparent,
            child: Text(
              _status,
              style: TextStyle(
                color: _isRecording
                    ? Colors.redAccent
                    : _isTranscribing
                    ? Colors.blueAccent
                    : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Transcription Area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                reverse: true, // Auto-scroll to bottom
                child: Text(
                  _transcribedText.isEmpty
                      ? "Transcription will appear here..."
                      : _transcribedText,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    color: _transcribedText.isEmpty
                        ? Colors.grey[700]
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isModelReady
          ? SizedBox(
              width: 72,
              height: 72,
              child: FloatingActionButton(
                onPressed: _isTranscribing ? null : _toggleRecording,
                backgroundColor: _isRecording ? Colors.red : Colors.teal,
                shape: const CircleBorder(),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
