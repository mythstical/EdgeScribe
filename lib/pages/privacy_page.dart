import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conversation.dart';
import '../providers/conversation_provider.dart';
import '../services/medical_redaction_service.dart';

class PrivacyPage extends StatefulWidget {
  final Conversation conversation;

  const PrivacyPage({super.key, required this.conversation});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final MedicalRedactionService _redactionService = MedicalRedactionService();
  late TextEditingController _textController;
  bool _isRedacting = false;
  bool _isEditing = false;
  bool _isApproved = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.conversation.redactedText ?? '',
    );
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    await _redactionService.loadDictionaries();
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
      if (!_redactionService.llmReady) {
        await _redactionService.initializeLLM();
      }

      final result = await _redactionService.redact(
        widget.conversation.transcription,
        enableLLM: true,
      );

      if (mounted) {
        setState(() {
          _textController.text = result.redactedText;
          _isRedacting = false;
          _saveRedaction(result.redactedText);
        });
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
    // If no transcription, show empty state
    if (widget.conversation.transcription.isEmpty) {
      return Center(
        child: Text(
          'No transcript available to redact.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Actions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (_isRedacting)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00D9FF)),
                      SizedBox(height: 16),
                      Text(
                        'Redacting PII...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                else if (_textController.text.isEmpty)
                  ElevatedButton.icon(
                    onPressed: _runRedaction,
                    icon: const Icon(Icons.shield),
                    label: const Text('Redact PII'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9FF),
                      foregroundColor: const Color(0xFF1A1A2E),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _runRedaction,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Re-run'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00D9FF),
                            side: const BorderSide(color: Color(0xFF00D9FF)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isApproved ? null : _approveRedaction,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00FF88),
                            foregroundColor: const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Redacted Text Area
          if (_textController.text.isNotEmpty || _isEditing)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(12),
                border: _isEditing
                    ? Border.all(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.5),
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Redacted Transcript',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isEditing ? Icons.save : Icons.edit,
                          color: const Color(0xFF00D9FF),
                        ),
                        onPressed: _toggleEdit,
                        tooltip: _isEditing ? 'Save' : 'Edit',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _isEditing
                      ? TextField(
                          controller: _textController,
                          maxLines: null,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                        )
                      : Text(
                          _textController.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                ],
              ),
            ),

          // SOAP Note Button (Placeholder)
          if (_isApproved) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('SOAP Note generation coming soon!'),
                  ),
                );
              },
              icon: const Icon(Icons.description),
              label: const Text('Generate SOAP Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
