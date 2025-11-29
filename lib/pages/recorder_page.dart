import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/conversation.dart';
import '../providers/conversation_provider.dart';
import '../services/transcription_service.dart';
import '../services/soap_generation_service.dart';
import '../screens/api_key_setup_screen.dart';

/// Recorder page for a specific conversation
class RecorderPage extends StatefulWidget {
  final Conversation conversation;
  final bool showAppBar;

  const RecorderPage({
    super.key,
    required this.conversation,
    this.showAppBar = true,
  });

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final TranscriptionService _transcriptionService = TranscriptionService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  TextEditingController? _textController;

  String _status = "Initializing...";
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isModelReady = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.conversation.transcription,
    );
    _initializeModel();
  }

  @override
  void didUpdateWidget(RecorderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversation.transcription !=
            oldWidget.conversation.transcription &&
        !_isEditing) {
      _textController?.text = widget.conversation.transcription;
    }
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

        // Update controller
        _textController?.text = widget.conversation.transcription;

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
      // Start recording - request permission first
      try {
        // Request microphone permission
        final micStatus = await Permission.microphone.request();

        if (!micStatus.isGranted) {
          setState(() => _status = "Microphone permission denied");
          return;
        }

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

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _textController ??= TextEditingController(
          text: widget.conversation.transcription,
        );
        _textController!.text = widget.conversation.transcription;
      }
    });
  }

  Future<void> _saveEdits() async {
    final provider = Provider.of<ConversationProvider>(context, listen: false);

    if (_textController != null) {
      widget.conversation.transcription = _textController!.text;
      await provider.updateConversation(widget.conversation);
    }

    setState(() {
      _isEditing = false;
      _status = "Changes saved";
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _status == "Changes saved") {
        setState(() => _status = "Ready to record");
      }
    });
  }

  Future<void> _showApiKeySetup() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ApiKeySetupScreen(
          leopardService: _transcriptionService,
          soapService: SoapGenerationService(),
        ),
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
    _textController?.dispose();
    super.dispose();
  }

  Future<void> _playLastRecording() async {
    final path = await _transcriptionService.getLastRecordingPath();

    if (path == null) {
      setState(() => _status = "No recording found");
      return;
    }

    try {
      // Verify file exists and has content
      final file = File(path);
      if (!await file.exists()) {
        setState(() => _status = "Recording file not found");
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        setState(() => _status = "Recording file is empty");
        return;
      }

      print("Playing file: $path (size: $fileSize bytes)");

      // Stop any existing playback and reset player state
      await _audioPlayer.stop();
      await _audioPlayer.release();

      // Set source and play using file:// URL scheme
      await _audioPlayer.setSourceUrl('file://$path');
      await _audioPlayer.resume();

      setState(() => _status = "Playing recording...");
    } catch (e) {
      print("Playback error: $e");
      setState(
        () => _status = "Playback error: ${e.toString().split('\n').first}",
      );
    }
  }

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.conversation.patientName.toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    widget.conversation.context.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'CONFIGURE API',
                  onPressed: _showApiKeySetup,
                ),
                if (!_isRecording && !_isTranscribing)
                  IconButton(
                    icon: const Icon(
                      Icons.play_arrow_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'PLAY LAST',
                    onPressed: _playLastRecording,
                  ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: Colors.white24, height: 1),
              ),
            )
          : null,
      body: Column(
        children: [
          // Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: _isRecording
                  ? const Color(0xFFD71921).withValues(alpha: 0.1)
                  : Colors.black,
              border: Border(
                bottom: BorderSide(
                  color: _isRecording
                      ? const Color(0xFFD71921)
                      : Colors.white24,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                if (_isRecording)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD71921),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    _status.toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: _isRecording
                          ? const Color(0xFFD71921)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (!widget.showAppBar && !_isRecording && !_isTranscribing)
                  IconButton(
                    icon: const Icon(
                      Icons.play_arrow_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'PLAY LAST',
                    onPressed: _playLastRecording,
                  ),
                if (!_isRecording &&
                    !_isTranscribing &&
                    widget.conversation.transcription.isNotEmpty)
                  if (_isEditing)
                    Row(
                      children: [
                        TextButton(
                          onPressed: _toggleEdit,
                          child: Text(
                            'CANCEL',
                            style: GoogleFonts.robotoMono(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveEdits,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD71921),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'SAVE',
                            style: GoogleFonts.robotoMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'EDIT TRANSCRIPT',
                      onPressed: _toggleEdit,
                    ),
              ],
            ),
          ),

          // Transcription Display
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: widget.conversation.transcription.isEmpty && !_isEditing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.mic_none_outlined,
                                size: 32,
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'READY TO RECORD',
                              style: GoogleFonts.robotoMono(
                                color: Colors.white54,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isEditing
                                ? const Color(0xFFD71921)
                                : Colors.white12,
                            width: 1,
                          ),
                        ),
                        child: _isEditing
                            ? TextField(
                                controller: _textController,
                                maxLines: null,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'ENTER TRANSCRIPTION...',
                                  hintStyle: GoogleFonts.robotoMono(
                                    color: Colors.white24,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            : SelectableText(
                                widget.conversation.transcription,
                                style: GoogleFonts.robotoMono(
                                  fontSize: 14,
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
      floatingActionButton: _isModelReady && !_isEditing
          ? SizedBox(
              width: 80,
              height: 80,
              child: FloatingActionButton(
                onPressed: _isTranscribing ? null : _toggleRecording,
                backgroundColor: _isRecording
                    ? const Color(0xFFD71921)
                    : Colors.white,
                foregroundColor: _isRecording ? Colors.white : Colors.black,
                shape: const CircleBorder(),
                elevation: 0,
                child: Icon(_isRecording ? Icons.stop : Icons.mic, size: 32),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
