import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/conversation.dart';
import '../providers/conversation_provider.dart';
import '../services/transcription_service.dart';
import '../screens/api_key_setup_screen.dart';

/// Recorder page for a specific conversation
class RecorderPage extends StatefulWidget {
  final Conversation conversation;

  const RecorderPage({super.key, required this.conversation});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final TranscriptionService _transcriptionService = TranscriptionService();
  final AudioPlayer _audioPlayer = AudioPlayer();

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
    try {
      setState(() => _status = "Checking for API key...");

      if (!await _transcriptionService.hasApiKey()) {
        setState(() {
          _status = "Setup required";
          _isModelReady = true;
        });

        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          _showApiKeySetup();
        }
        return;
      }

      setState(() => _status = "Initializing Leopard...");
      await _transcriptionService.initialize();

      setState(() {
        _isModelReady = true;
        _status = "Ready to record";
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _toggleRecording() async {
    if (!_transcriptionService.isInitialized) {
      setState(() => _status = "Leopard not ready. Check API key.");
      return;
    }

    final provider = Provider.of<ConversationProvider>(context, listen: false);

    if (_isRecording) {
      // Stop recording and transcribe
      try {
        setState(() {
          _isRecording = false;
          _isTranscribing = true;
          _status = "Transcribing...";
        });

        final transcription = await _transcriptionService
            .stopRecordingAndTranscribe();

        // Update conversation with new transcription
        widget.conversation.transcription += "$transcription\n\n";
        widget.conversation.isRecording = false;
        await provider.updateConversation(widget.conversation);

        setState(() {
          _isTranscribing = false;
          _status = "Ready to record";
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
        await _transcriptionService.startRecording();

        widget.conversation.isRecording = true;
        await provider.updateConversation(widget.conversation);

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
            ApiKeySetupScreen(leopardService: _transcriptionService),
        fullscreenDialog: true,
      ),
    );

    if (result == true && mounted) {
      setState(() => _status = "Initializing Leopard...");
      try {
        await _transcriptionService.initialize();
        setState(() {
          _status = "Ready to record";
          _isModelReady = true;
        });
      } catch (e) {
        setState(() => _status = "Init failed: $e");
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _playLastRecording() async {
    final path = await _transcriptionService.getLastRecordingPath();

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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.conversation.patientName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            Text(
              widget.conversation.context,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF00D9FF)),
            tooltip: 'Configure API Key',
            onPressed: _showApiKeySetup,
          ),
          if (!_isRecording && !_isTranscribing)
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFF00D9FF)),
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
            decoration: BoxDecoration(
              color: _isRecording
                  ? Colors.red.withValues(alpha: 0.1)
                  : _isTranscribing
                  ? const Color(0xFF00D9FF).withValues(alpha: 0.1)
                  : const Color(0xFF16213E),
              border: Border(
                bottom: BorderSide(
                  color: _isRecording
                      ? Colors.red
                      : _isTranscribing
                      ? const Color(0xFF00D9FF)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
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
                          ? const Color(0xFF00D9FF)
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
                child: widget.conversation.transcription.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Icon(
                              Icons.mic_none,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tap the button to start recording',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16213E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.conversation.transcription,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.white,
                          ),
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
                backgroundColor: _isRecording
                    ? Colors.red
                    : const Color(0xFF00D9FF),
                shape: const CircleBorder(),
                elevation: 8,
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 32,
                  color: _isRecording ? Colors.white : const Color(0xFF1A1A2E),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
