import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/conversation.dart';
import 'recorder_page.dart';
import 'privacy_page.dart';
import 'opportunities_page.dart';
import '../screens/api_key_setup_screen.dart';
import '../services/transcription_service.dart';
import '../services/soap_generation_service.dart';

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
        builder: (context) => ApiKeySetupScreen(
          leopardService: _transcriptionService,
          soapService: SoapGenerationService(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black, // Pure Black
        appBar: AppBar(
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
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                widget.conversation.context.toUpperCase(),
                style: GoogleFonts.inter(
                  color: const Color(0xFFD71921), // Nothing Red
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              tooltip: 'CONFIGURE API',
              onPressed: _showApiKeySetup,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 1),
                ),
              ),
              child: TabBar(
                indicatorColor: const Color(0xFFD71921), // Nothing Red
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.normal,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(text: 'TRANSCRIPT'),
                  Tab(text: 'FORMATTING'),
                  Tab(text: 'INSIGHTS'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            RecorderPage(conversation: widget.conversation, showAppBar: false),
            PrivacyPage(conversation: widget.conversation),
            OpportunitiesPage(conversation: widget.conversation),
          ],
        ),
      ),
    );
  }
}
