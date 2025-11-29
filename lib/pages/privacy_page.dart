import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/conversation_provider.dart';
import '../services/medical_redactor_service.dart';
import '../services/soap_generation_service.dart';

class PrivacyPage extends StatefulWidget {
  final Conversation conversation;

  const PrivacyPage({super.key, required this.conversation});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final MedicalRedactorService _redactionService = MedicalRedactorService();
  late TextEditingController _textController;
  bool _isRedacting = false;
  bool _isEditing = false;
  bool _isApproved = false;
  String _currentText = '';
  ReversibleRedactionResult? _reversibleResult;
  final SoapGenerationService _soapService = SoapGenerationService();
  bool _isGeneratingSoap = false;
  String? _generatedSoapNote;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.conversation.redactedText ?? '',
    );
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    // Dictionaries are loaded statically in MedicalRedactorService
    // Initialize LLM if needed, but maybe lazy load on action
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _redactionService.dispose();
    super.dispose();
  }

  Future<void> _runRedaction() async {
    if (widget.conversation.transcription.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transcription to redact')),
      );
      return;
    }

    setState(() => _isRedacting = true);

    try {
      // Initialize LLM first if needed
      // Ensure LLM is ready if we want to use it
      if (!_redactionService.isReady) {
        await _redactionService.initialize();
      }

      // Run reversible redaction
      final result = await _redactionService.redactForCloud(
        _currentText.isEmpty ? widget.conversation.transcription : _currentText,
      );

      if (mounted) {
        setState(() {
          _reversibleResult = result;
          _currentText = result.redactedText;
          _textController.text = _currentText; // Update text controller
          _isRedacting = false;
        });
        _saveRedaction(result.redactedText); // Save the new redacted text
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRedacting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Redaction failed: $e')));
      }
    }
  }

  Future<void> _saveRedaction(String text) async {
    final provider = Provider.of<ConversationProvider>(context, listen: false);
    widget.conversation.redactedText = text;
    await provider.updateConversation(widget.conversation);
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
      if (!_isEditing) {
        _saveRedaction(_textController.text);
      }
    });
  }

  void _approveRedaction() {
    setState(() {
      _isApproved = true;
      _isEditing = false;
      _saveRedaction(_textController.text);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Redaction approved')));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversation.transcription.isEmpty) {
      return Center(
        child: Text(
          'NO TRANSCRIPT DATA',
          style: GoogleFonts.robotoMono(
            color: Colors.white54,
            letterSpacing: 1.5,
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Custom Tab Bar
          Container(
            color: Colors.black,
            child: TabBar(
              indicatorColor: const Color(0xFFD71921),
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
                Tab(text: 'REDACTION'),
                Tab(text: 'SOAP NOTE'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              children: [_buildRedactionView(), _buildSoapNoteView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRedactionView() {
    return Container(
      color: Colors.black,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Control Center
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(color: Colors.white24, width: 1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONTROL CENTER',
                    style: GoogleFonts.robotoMono(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isRedacting)
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD71921),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'PROCESSING PII...',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  else if (_textController.text.isEmpty)
                    _buildNothingButton(
                      label: 'REDACT PII',
                      icon: Icons.shield_outlined,
                      onPressed: _runRedaction,
                      isPrimary: true,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildNothingButton(
                            label: 'RERUN',
                            icon: Icons.refresh,
                            onPressed: _runRedaction,
                            isPrimary: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNothingButton(
                            label: 'APPROVE',
                            icon: Icons.check_circle_outline,
                            onPressed: _isApproved ? null : _approveRedaction,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Redacted Text Area
            if (_textController.text.isNotEmpty || _isEditing)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(
                    color: _isEditing
                        ? const Color(0xFFD71921)
                        : Colors.white12,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'REDACTED OUTPUT',
                            style: GoogleFonts.robotoMono(
                              color: Colors.white54,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isEditing ? Icons.save : Icons.edit_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _toggleEdit,
                            tooltip: _isEditing ? 'SAVE' : 'EDIT',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _isEditing
                          ? TextField(
                              controller: _textController,
                              maxLines: null,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.6,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            )
                          : SelectableText(
                              _textController.text,
                              style: GoogleFonts.robotoMono(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoapNoteView() {
    return Container(
      color: Colors.black,
      child: _isGeneratingSoap
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFD71921),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'GENERATING NOTE...',
                    style: GoogleFonts.robotoMono(
                      color: Colors.white,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : _generatedSoapNote == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'NO NOTE GENERATED',
                    style: GoogleFonts.robotoMono(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildNothingButton(
                    label: 'GENERATE SOAP',
                    icon: Icons.auto_awesome,
                    onPressed: _isApproved ? _generateSoapNote : null,
                    isPrimary: true,
                  ),
                  if (!_isApproved)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'APPROVE REDACTION FIRST',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFFD71921),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      border: Border.all(color: Colors.white24, width: 1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SOAP NOTE',
                                style: GoogleFonts.robotoMono(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.refresh,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    onPressed: _generateSoapNote,
                                    tooltip: 'REGENERATE',
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: _generatedSoapNote!,
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('COPIED TO CLIPBOARD'),
                                          backgroundColor: Color(0xFF111111),
                                        ),
                                      );
                                    },
                                    tooltip: 'COPY',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.white12),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            _generatedSoapNote!,
                            style: GoogleFonts.robotoMono(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildNothingButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFFD71921)
            : Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        side: isPrimary ? null : const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateSoapNote() async {
    // Use stored result if available, otherwise run redaction
    ReversibleRedactionResult? result = _reversibleResult;

    if (result == null) {
      final originalText = widget.conversation.transcription;
      if (originalText.isEmpty) return;

      try {
        result = await _redactionService.redactForCloud(originalText);
        setState(() {
          _reversibleResult = result;
          _currentText = result!.redactedText;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Redaction failed: $e')));
        }
        return;
      }
    }

    setState(() {
      _isGeneratingSoap = true;
      _generatedSoapNote = null;
    });

    try {
      // 2. Send to Cloud LLM
      final soapNote = await _soapService.generateSoapNote(
        transcript: result.redactedText,
      );

      // 3. Restore PII
      final restoredSoapNote = _redactionService.restoreRedactions(
        soapNote,
        result.mapping,
      );

      if (mounted) {
        setState(() {
          _generatedSoapNote = restoredSoapNote;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating SOAP note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingSoap = false;
        });
      }
    }
  }
}
