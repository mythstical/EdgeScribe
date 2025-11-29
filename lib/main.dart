import 'package:flutter/material.dart';
import 'package:edgescribe/pages/redactor_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'services/transcription_service.dart';
import 'screens/api_key_setup_screen.dart';

void main() {
  runApp(const EdgeScribeApp());
}

class EdgeScribeApp extends StatelessWidget {
  const EdgeScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeScribe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00D9FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EdgeScribeHome(),
    );
  }
}

class EdgeScribeHome extends StatefulWidget {
  const EdgeScribeHome({super.key});

  @override
  State<EdgeScribeHome> createState() => _EdgeScribeHomeState();
}

class _EdgeScribeHomeState extends State<EdgeScribeHome> {
  int _currentIndex = 0;
  final TranscriptionService _transcriptionService = TranscriptionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          RecorderPage(transcriptionService: _transcriptionService),
          const RedactorPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mic), label: 'Recorder'),
          NavigationDestination(
            icon: Icon(Icons.shield),
            label: 'PII Redactor',
          ),
        ],
      ),
    );
  }
}

// Recorder Page
class RecorderPage extends StatefulWidget {
  final TranscriptionService transcriptionService;

  const RecorderPage({super.key, required this.transcriptionService});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  String _transcribedText = "";
  String _status = "Initializing...";
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isModelReady = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      setState(() => _status = "Checking for API key...");

      // Check if Leopard API key exists, if not show setup screen
      if (!await widget.transcriptionService.hasApiKey()) {
        setState(() {
          _status = "Setup required";
          _isModelReady = true;
        });

        // Show API key setup dialog
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          _showApiKeySetup();
        }
        return;
      }

      // Initialize Leopard
      setState(() => _status = "Initializing Leopard...");
      await widget.transcriptionService.initialize();

      setState(() {
        _isModelReady = true;
        _status = "Ready to record";
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _toggleRecording() async {
    if (!widget.transcriptionService.isInitialized) {
      setState(() => _status = "Leopard not ready. Check API key.");
      return;
    }

    if (_isRecording) {
      // Stop recording and transcribe
      try {
        setState(() {
          _isRecording = false;
          _isTranscribing = true;
          _status = "Transcribing...";
        });

        final transcription = await widget.transcriptionService
            .stopRecordingAndTranscribe();

        setState(() {
          _isTranscribing = false;
          _status = "Ready to record";
          _transcribedText += "$transcription\n\n";
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
        await widget.transcriptionService.startRecording();

        setState(() {
          _isRecording = true;
          _status = "Recording...";
        });
      } catch (e) {
        setState(() => _status = "Error: $e");
      }
    }
  }

  Future<void> _showApiKeySetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            ApiKeySetupScreen(leopardService: widget.transcriptionService),
        fullscreenDialog: true,
      ),
    );

    // If user saved key, reinitialize Leopard
    if (result == true && mounted) {
      setState(() => _status = "Initializing Leopard...");
      try {
        await widget.transcriptionService.initialize();
        setState(() => _status = "Ready to record");
        setState(() => _isModelReady = true);
      } catch (e) {
        setState(() => _status = "Init failed: $e");
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playLastRecording() async {
    final path = await widget.transcriptionService.getLastRecordingPath();

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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Speech Recorder'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configure API Key',
            onPressed: _showApiKeySetup,
          ),
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
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: _isRecording
                ? Colors.red.withValues(alpha: 0.1)
                : _isTranscribing
                ? Colors.purple.withValues(alpha: 0.1)
                : Colors.grey[900],
            child: Row(
              children: [
                if (_isRecording)
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _isRecording
                          ? Colors.red[300]
                          : _isTranscribing
                          ? Colors.purple[300]
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transcription Display
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
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
                backgroundColor: _isRecording ? Colors.red : Colors.purple,
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
