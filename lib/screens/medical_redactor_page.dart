import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/medical_redactor_service.dart';

class MedicalRedactorPage extends StatefulWidget {
  const MedicalRedactorPage({super.key});

  @override
  State<MedicalRedactorPage> createState() => _MedicalRedactorPageState();
}

class _MedicalRedactorPageState extends State<MedicalRedactorPage> {
  final _redactor = MedicalRedactorService();
  final _inputController = TextEditingController();
  RedactorPipelineResult? _result;
  bool _isLoading = true;
  bool _isProcessing = false;
  String _modelStatus = "Initializing...";
  bool _showCloudSimulation = false;

  // Sample medical transcript for testing
  final String _sampleTranscript =
      '''Patient John Mitchell presented to St. Luke's Hospital with acute abdominal pain on 12/15/2024. Dr. Sarah Chen performed the initial examination. The patient reported his phone number as 555-123-4567 and email john.mitchell@email.com. Dr. Chen consulted with Dr. Robert Anderson from Mayo Clinic regarding the case. Patient's SSN on file is 123-45-6789. Recommended transfer to Boston General Hospital for specialist care.''';

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _redactor.initialize(
        onProgress: (progress, status, isError) {
          if (mounted) {
            final pct = progress != null
                ? (progress * 100).toStringAsFixed(1)
                : '';
            setState(() {
              _modelStatus = "$status $pct%";
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _modelStatus = "Model ready";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _modelStatus = "Error: $e";
        });
      }
    }
  }

  Future<void> _processRedaction() async {
    if (_inputController.text.trim().isEmpty) {
      _showSnackBar("Please enter some text to redact.");
      return;
    }

    setState(() {
      _isProcessing = true;
      _result = null;
      _showCloudSimulation = false;
    });

    try {
      final result = await _redactor.redact(_inputController.text);
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showSnackBar("Error during redaction: $e");
    }
  }

  void _loadSampleText() {
    _inputController.text = _sampleTranscript;
    setState(() {
      _result = null;
      _showCloudSimulation = false;
    });
  }

  void _simulateCloudUpload() {
    if (_result == null) return;

    setState(() => _showCloudSimulation = true);

    // Simulate upload delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showSnackBar("✓ Redacted text sent to cloud successfully!");
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _copyRedactedText() {
    if (_result != null) {
      Clipboard.setData(ClipboardData(text: _result!.redacted));
      _showSnackBar("Copied redacted text to clipboard");
    }
  }

  @override
  void dispose() {
    _redactor.dispose();
    _inputController.dispose();
    super.dispose();
  }

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'MEDICAL REDACTOR (SMOLLM2-360M)',
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
        actions: [
          if (!_isLoading && _result != null)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              tooltip: "COPY REDACTED TEXT",
              onPressed: _copyRedactedText,
            ),
          if (!_isLoading && _result != null)
            IconButton(
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              tooltip: "SIMULATE CLOUD UPLOAD",
              onPressed: _simulateCloudUpload,
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildInputSection(),
                  const SizedBox(height: 20),
                  _buildRedactButton(),
                  const SizedBox(height: 30),
                  if (_result != null) ...[
                    _buildOutputSection(),
                    const SizedBox(height: 20),
                    _buildEntitiesSection(),
                    const SizedBox(height: 20),
                  ],
                  if (_showCloudSimulation) _buildCloudSimulation(),
                  const SizedBox(height: 20),
                  _buildInfoSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFD71921)),
          const SizedBox(height: 20),
          Text(
            _modelStatus.toUpperCase(),
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "DOWNLOADING SMOLLM2-360M (227MB) WITH FALLBACK TO GEMMA3-270M IF NEEDED.\nTHIS MAY TAKE A FEW MINUTES ON FIRST LAUNCH.",
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _loadSampleText,
            icon: const Icon(Icons.description, color: Colors.white),
            label: Text(
              "LOAD SAMPLE TRANSCRIPT",
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
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "INPUT MEDICAL TRANSCRIPT",
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
            hintText: "PASTE MEDICAL TRANSCRIPT WITH PII...",
            hintStyle: GoogleFonts.robotoMono(
              color: Colors.white24,
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF111111),
            contentPadding: const EdgeInsets.all(20),
          ),
        ),
      ],
    );
  }

  Widget _buildRedactButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _isProcessing) ? null : _processRedaction,
        icon: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.shield, color: Colors.white),
        label: Text(
          _isProcessing ? "PROCESSING..." : "REDACT PII (HYBRID)",
          style: GoogleFonts.robotoMono(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: const Color(0xFFD71921),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          disabledBackgroundColor: const Color(0xFF111111),
        ),
      ),
    );
  }

  Widget _buildOutputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "REDACTED OUTPUT",
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            if (_result!.hasRedactions)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD71921).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD71921)),
                ),
                child: Text(
                  "${_result!.totalRedactions} PII DETECTED",
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFFD71921),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
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
          child: _buildHighlightedText(),
        ),
      ],
    );
  }

  Widget _buildHighlightedText() {
    final text = _result!.redacted;
    final spans = <TextSpan>[];
    int currentPos = 0;

    // Find all [TAG] patterns and highlight them
    final tagPattern = RegExp(r'\[([A-Z]+)\]');
    final matches = tagPattern.allMatches(text).toList();

    for (var match in matches) {
      // Add text before tag
      if (match.start > currentPos) {
        spans.add(
          TextSpan(
            text: text.substring(currentPos, match.start),
            style: GoogleFonts.robotoMono(color: Colors.white),
          ),
        );
      }

      // Add highlighted tag
      spans.add(
        TextSpan(
          text: match.group(0),
          style: GoogleFonts.robotoMono(
            color: const Color(0xFFD71921),
            fontWeight: FontWeight.bold,
            backgroundColor: const Color(0xFFD71921).withValues(alpha: 0.1),
          ),
        ),
      );

      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentPos),
          style: GoogleFonts.robotoMono(color: Colors.white),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: GoogleFonts.robotoMono(fontSize: 14, height: 1.6),
    );
  }

  Widget _buildEntitiesSection() {
    final counts = {
      'RULES': _result!.rulesApplied,
      'LLM': _result!.llmEntitiesFound,
      'BLOCKED': _result!.hallucinationsBlocked,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "DETECTION SUMMARY",
          style: GoogleFonts.robotoMono(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              ...counts.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getIconForLabel(entry.key),
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        entry.key,
                        style: GoogleFonts.robotoMono(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${entry.value}",
                          style: GoogleFonts.robotoMono(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'EMAIL':
        return Icons.email_outlined;
      case 'PHONE':
        return Icons.phone_outlined;
      case 'SSN':
        return Icons.badge_outlined;
      case 'DATE':
        return Icons.calendar_today_outlined;
      case 'PATIENT':
        return Icons.person_outlined;
      case 'DR':
      case 'DOCTOR':
        return Icons.local_hospital_outlined;
      case 'HOSPITAL':
      case 'FACILITY':
        return Icons.business_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Widget _buildCloudSimulation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00D9FF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00D9FF),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "UPLOADING TO CLOUD...",
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF00D9FF),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "SENDING REDACTED TEXT:\n\"${_result!.redacted.substring(0, 50)}...\"",
            style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white54, size: 20),
              const SizedBox(width: 12),
              Text(
                "HYBRID REDACTION PIPELINE",
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "• PASS 1 (REGEX): INSTANT DETECTION OF EMAIL, PHONE, SSN, DATES\n"
            "• PASS 2 (LLM): SMOLLM2-360M DETECTS PATIENT NAMES, DOCTORS, FACILITIES\n"
            "• 100% LOCAL: NO DATA LEAVES YOUR DEVICE\n"
            "• STRUCTURED OUTPUT: REDACTIONRESULT WITH ENTITY METADATA\n"
            "• MODEL: SMOLLM2-360M-INSTRUCT (227MB)",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white54,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
