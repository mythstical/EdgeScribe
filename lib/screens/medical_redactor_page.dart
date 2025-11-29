import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String _sampleTranscript = '''Patient John Mitchell presented to St. Luke's Hospital with acute abdominal pain on 12/15/2024. Dr. Sarah Chen performed the initial examination. The patient reported his phone number as 555-123-4567 and email john.mitchell@email.com. Dr. Chen consulted with Dr. Robert Anderson from Mayo Clinic regarding the case. Patient's SSN on file is 123-45-6789. Recommended transfer to Boston General Hospital for specialist care.''';

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
            final pct = progress != null ? (progress * 100).toStringAsFixed(1) : '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Medical Redactor (SmolLM2-360M)"),
        actions: [
          if (!_isLoading && _result != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: "Copy redacted text",
              onPressed: _copyRedactedText,
            ),
          if (!_isLoading && _result != null)
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: "Simulate cloud upload",
              onPressed: _simulateCloudUpload,
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuickActions(),
                  const SizedBox(height: 20),
                  _buildInputSection(),
                  const SizedBox(height: 16),
                  _buildRedactButton(),
                  const SizedBox(height: 24),
                  if (_result != null) ...[
                    _buildOutputSection(),
                    const SizedBox(height: 24),
                    _buildEntitiesSection(),
                    const SizedBox(height: 24),
                  ],
                  if (_showCloudSimulation) _buildCloudSimulation(),
                  const SizedBox(height: 24),
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
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _modelStatus,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Downloading smollm2-360m (227MB) with fallback to gemma3-270m if needed.\nThis may take a few minutes on first launch.",
              style: TextStyle(color: Colors.grey),
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
            icon: const Icon(Icons.description),
            label: const Text("Load Sample Transcript"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[800],
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
        const Text(
          "Input Medical Transcript:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _inputController,
          maxLines: 8,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: "Paste medical transcript with PII...",
            filled: true,
            fillColor: Colors.grey[900],
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
            : const Icon(Icons.shield),
        label: Text(_isProcessing ? "Processing..." : "Redact PII (Hybrid)"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.teal,
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
            const Text(
              "Redacted Output:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            if (_result!.hasRedactions)
              Chip(
                label: Text("${_result!.totalRedactions} PII detected"),
                backgroundColor: Colors.orange[900],
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[850],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
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
        spans.add(TextSpan(
          text: text.substring(currentPos, match.start),
          style: const TextStyle(color: Colors.white),
        ));
      }

      // Add highlighted tag
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: Colors.green[300],
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.green[900]?.withValues(alpha: 0.3),
        ),
      ));

      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: const TextStyle(color: Colors.white),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: const TextStyle(fontSize: 16, height: 1.5),
    );
  }

  Widget _buildEntitiesSection() {
    final counts = {
      'Rules': _result!.rulesApplied,
      'LLM': _result!.llmEntitiesFound,
      'Blocked': _result!.hallucinationsBlocked,
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Detection Summary:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              ...counts.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _getIconForLabel(entry.key),
                        color: Colors.green[300],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.green[300],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text("${entry.value}"),
                        backgroundColor: Colors.green[900],
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
        return Icons.email;
      case 'PHONE':
        return Icons.phone;
      case 'SSN':
        return Icons.badge;
      case 'DATE':
        return Icons.calendar_today;
      case 'PATIENT':
        return Icons.person;
      case 'DR':
      case 'DOCTOR':
        return Icons.local_hospital;
      case 'HOSPITAL':
      case 'FACILITY':
        return Icons.business;
      default:
        return Icons.label;
    }
  }

  Widget _buildCloudSimulation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(width: 16),
              Text(
                "Uploading to Cloud...",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Sending redacted text:\n\"${_result!.redacted.substring(0, 50)}...\"",
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[300]),
              const SizedBox(width: 8),
              const Text(
                "Hybrid Redaction Pipeline:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "• Pass 1 (Regex): Instant detection of Email, Phone, SSN, Dates\n"
            "• Pass 2 (LLM): SmolLM2-360M detects Patient names, Doctors, Facilities\n"
            "• 100% Local: No data leaves your device\n"
            "• Structured Output: RedactionResult with entity metadata\n"
            "• Model: SmolLM2-360M-Instruct (227MB)",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[300],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
