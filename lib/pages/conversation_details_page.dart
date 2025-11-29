import 'package:flutter/material.dart';
import '../models/conversation.dart';
import 'recorder_page.dart';
import 'privacy_page.dart';
import 'opportunities_page.dart';
import '../screens/api_key_setup_screen.dart';
import '../services/transcription_service.dart';

class ConversationDetailsPage extends StatefulWidget {
  final Conversation conversation;

  const ConversationDetailsPage({super.key, required this.conversation});

  @override
  State<ConversationDetailsPage> createState() =>
      _ConversationDetailsPageState();
}

class _ConversationDetailsPageState extends State<ConversationDetailsPage> {
  final TranscriptionService _transcriptionService = TranscriptionService();

  @override
  void dispose() {
    _transcriptionService.dispose();
    super.dispose();
  }

  Future<void> _showApiKeySetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ApiKeySetupScreen(leopardService: _transcriptionService),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Stack(
        children: [
          // Global Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF1E293B), // Slate 800
                  Color(0xFF0F172A), // Slate 900
                ],
              ),
            ),
          ),
          // Content
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
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
                      color: Colors.white.withOpacity(0.6),
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
              ],
              bottom: const TabBar(
                indicatorColor: Color(0xFF00D9FF),
                labelColor: Color(0xFF00D9FF),
                unselectedLabelColor: Colors.white54,
                tabs: [
                  Tab(icon: Icon(Icons.mic), text: 'Transcript'),
                  Tab(icon: Icon(Icons.format_align_left), text: 'Formatting'),
                  Tab(
                    icon: Icon(Icons.lightbulb_outline),
                    text: 'Opportunities',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                RecorderPage(
                  conversation: widget.conversation,
                  showAppBar: false,
                ),
                PrivacyPage(conversation: widget.conversation),
                OpportunitiesPage(conversation: widget.conversation),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
