import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edgescribe/services/medical_redactor_service.dart';

class RedactorTestPage extends StatefulWidget {
  const RedactorTestPage({super.key});

  @override
  State<RedactorTestPage> createState() => _RedactorTestPageState();
}

class _RedactorTestPageState extends State<RedactorTestPage> {
  final MedicalRedactorService _redactor = MedicalRedactorService();
  final TextEditingController _inputController = TextEditingController();

  bool _isInitializing = false;
  bool _isRedacting = false;
  String _downloadStatus = "";
  double? _downloadProgress;
  RedactorPipelineResult? _result;

  @override
  void initState() {
    super.initState();
    // Pre-fill with example medical text
    _inputController.text = _exampleText;
  }

  static const String _exampleText =
      '''Patient John Smith (SSN: 123-45-6789) visited Dr. Emily Watson at Mayo Clinic on January 15th, 2024.

Contact: john.smith@email.com, Phone: (555) 123-4567
Address: 123 Oak Street, Boston, MA 02101

Chief Complaint: Patient reports persistent hypertension and diabetes symptoms.

Dr. Watson prescribed metformin 500mg twice daily. Follow-up scheduled with Nurse Rodriguez at Cleveland Medical Center.

Emergency contact: Alice Johnson at Mercy General Hospital.''';

  Future<void> _initializeModel() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _downloadStatus = "Starting...";
      _downloadProgress = null;
    });

    try {
      await _redactor.initialize(
        onProgress: (progress, status, isError) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = progress;
            _downloadStatus = status;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Model ready for entity extraction'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _downloadStatus = "";
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _runRedaction({bool rulesOnly = false}) async {
    if (_inputController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter some text to redact')),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isRedacting = true;
      _result = null;
    });

    try {
      final result = rulesOnly
          ? _redactor.redactRulesOnly(_inputController.text)
          : await _redactor.redact(_inputController.text);

      if (mounted) {
        setState(() {
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRedacting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _redactor.dispose();
    super.dispose();
  }

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'MEDICAL REDACTOR TEST',
          style: GoogleFonts.robotoMono(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white24, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            _buildStatusCard(),
            const SizedBox(height: 20),

            // Initialize button
            if (!_redactor.isReady) ...[
              ElevatedButton.icon(
                onPressed: _isInitializing ? null : _initializeModel,
                icon: _isInitializing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                label: Text(
                  _isInitializing
                      ? 'INITIALIZING LLM...'
                      : 'INITIALIZE LLM (FOR NAMES/ORGS)',
                  style: GoogleFonts.robotoMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              if (_isInitializing && _downloadStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _downloadStatus.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
                if (_downloadProgress != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: const Color(0xFF111111),
                    color: const Color(0xFFD71921),
                  ),
                ],
              ],
              const SizedBox(height: 20),
            ],

            // Input text field
            Text(
              'INPUT TEXT',
              style: GoogleFonts.robotoMono(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              maxLines: 8,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFD71921)),
                ),
                hintText: 'ENTER MEDICAL TEXT TO REDACT...',
                hintStyle: GoogleFonts.robotoMono(
                  color: Colors.white24,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF111111),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRedacting
                        ? null
                        : () => _runRedaction(rulesOnly: true),
                    icon: const Icon(Icons.bolt, color: Colors.white),
                    label: Text(
                      'RULES ONLY',
                      style: GoogleFonts.robotoMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isRedacting || !_redactor.isReady)
                        ? null
                        : () => _runRedaction(rulesOnly: false),
                    icon: _isRedacting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.security, color: Colors.white),
                    label: Text(
                      _isRedacting ? 'PROCESSING...' : 'FULL REDACTION',
                      style: GoogleFonts.robotoMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD71921),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: const Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Results
            if (_result != null) ...[_buildResultCard()],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _redactor.isReady ? const Color(0xFFD71921) : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _redactor.isReady ? Icons.check_circle : Icons.info_outline,
            color: _redactor.isReady ? const Color(0xFFD71921) : Colors.white54,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _redactor.isReady ? 'READY: RULES + LLM' : 'RULES ONLY MODE',
                  style: GoogleFonts.robotoMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _redactor.isReady
                      ? 'FULL REDACTION AVAILABLE'
                      : 'INITIALIZE LLM TO DETECT NAMES & ORGANIZATIONS',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white54,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          Row(
            children: [
              _buildStatChip('RULES', result.rulesApplied, Colors.white),
              const SizedBox(width: 8),
              _buildStatChip(
                'LLM',
                result.llmEntitiesFound,
                const Color(0xFFD71921),
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                'BLOCKED',
                result.hallucinationsBlocked,
                Colors.white54,
              ),
              const Spacer(),
              Text(
                '${result.processingTimeMs}MS',
                style: GoogleFonts.robotoMono(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Redacted text
          Text(
            'REDACTED OUTPUT',
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: SelectableText(
              result.redacted,
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendItem('[PERSON]', const Color(0xFF00D9FF)),
              _buildLegendItem('[ORG]', const Color(0xFF3498DB)),
              _buildLegendItem('[SSN]', const Color(0xFFE74C3C)),
              _buildLegendItem('[EMAIL]', const Color(0xFFFF6B6B)),
              _buildLegendItem('[PHONE]', const Color(0xFFFFB800)),
              _buildLegendItem('[DATE]', const Color(0xFF9B59B6)),
              _buildLegendItem('[LOCATION]', const Color(0xFF00FF88)),
              _buildLegendItem('[ADDRESS]', const Color(0xFFA569BD)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: GoogleFonts.robotoMono(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.robotoMono(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        tag,
        style: GoogleFonts.robotoMono(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
