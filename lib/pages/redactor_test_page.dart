import 'package:flutter/material.dart';
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

  static const String _exampleText = '''Patient John Smith (SSN: 123-45-6789) visited Dr. Emily Watson at Mayo Clinic on January 15th, 2024.

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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
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
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Redactor'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Initialize button
            if (!_redactor.isReady) ...[
              ElevatedButton.icon(
                onPressed: _isInitializing ? null : _initializeModel,
                icon: _isInitializing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isInitializing
                    ? 'Initializing LLM...'
                    : 'Initialize LLM (for names/orgs)'),
              ),
              if (_isInitializing && _downloadStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _downloadStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (_downloadProgress != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _downloadProgress),
                ],
              ],
              const SizedBox(height: 16),
            ],

            // Input text field
            const Text(
              'Input Text:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              maxLines: 8,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Enter medical text to redact...',
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRedacting ? null : () => _runRedaction(rulesOnly: true),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Rules Only'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[900],
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.security),
                    label: Text(_isRedacting ? 'Processing...' : 'Full Redaction'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Results
            if (_result != null) ...[
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: _redactor.isReady ? Colors.green[50] : Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _redactor.isReady ? Icons.check_circle : Icons.info_outline,
              color: _redactor.isReady ? Colors.green : Colors.amber[800],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _redactor.isReady
                        ? 'Ready: Rules + LLM'
                        : 'Rules Only Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _redactor.isReady
                        ? 'Full redaction available (SSN, email, phone, dates, names, orgs)'
                        : 'Initialize LLM to detect names & organizations',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final result = _result!;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats row
            Row(
              children: [
                _buildStatChip('Rules', result.rulesApplied, Colors.orange),
                const SizedBox(width: 8),
                _buildStatChip('LLM', result.llmEntitiesFound, Colors.green),
                const SizedBox(width: 8),
                _buildStatChip('Blocked', result.hallucinationsBlocked, Colors.red),
                const Spacer(),
                Text(
                  '${result.processingTimeMs}ms',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Redacted text
            const Text(
              'Redacted Output:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                result.redacted,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Legend
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildLegendItem('[PERSON]', Colors.purple),
                _buildLegendItem('[ORG]', Colors.blue),
                _buildLegendItem('[SSN]', Colors.red),
                _buildLegendItem('[EMAIL]', Colors.orange),
                _buildLegendItem('[PHONE]', Colors.teal),
                _buildLegendItem('[DATE]', Colors.indigo),
                _buildLegendItem('[LOCATION]', Colors.green),
                _buildLegendItem('[ADDRESS]', Colors.brown),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String tag, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontFamily: 'monospace',
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

