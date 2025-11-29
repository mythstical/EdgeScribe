import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pii_redactor.dart';

class PIITesterPage extends StatefulWidget {
  const PIITesterPage({super.key});

  @override
  State<PIITesterPage> createState() => _PIITesterPageState();
}

class _PIITesterPageState extends State<PIITesterPage> {
  final _redactor = LocalPIIRedactor();
  final _inputController = TextEditingController();
  String _output = "";
  bool _isLoading = true;
  bool _isProcessing = false;
  String _modelStatus = "Initializing...";

  // Sample test cases for quick testing
  final List<String> _sampleTexts = [
    "Hi, I'm John Smith. Email me at john.smith@company.com or call 555-123-4567.",
    "Contact Dr. Sarah Martinez at Mayo Clinic in Rochester, Minnesota for more info.",
    "My SSN is 123-45-6789 and my credit card is 4532-1234-5678-9010.",
    "Meeting with Tim Cook from Apple Inc. at their Cupertino headquarters tomorrow.",
  ];

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      await _redactor.init(
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _modelStatus = "$status ${(progress * 100).toStringAsFixed(1)}%";
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
      setState(() => _output = "Please enter some text to redact.");
      return;
    }

    setState(() {
      _output = "Processing...";
      _isProcessing = true;
    });

    try {
      final result = await _redactor.redact(_inputController.text);
      setState(() {
        _output = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _output = "Error during redaction: $e";
        _isProcessing = false;
      });
    }
  }

  void _loadSampleText(String sample) {
    _inputController.text = sample;
    setState(() => _output = ""); // Clear output when loading new sample
  }

  void _copyToClipboard() {
    if (_output.isNotEmpty && _output != "Processing...") {
      Clipboard.setData(ClipboardData(text: _output));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Copied to clipboard"),
          duration: Duration(seconds: 2),
        ),
      );
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
        title: const Text("Local PII Redactor"),
        actions: [
          if (!_isLoading && _output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: "Copy redacted text",
              onPressed: _copyToClipboard,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
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
                      "Downloading Qwen 2.5 (0.5B) model...\nThis may take a few minutes on first launch.",
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sample Texts Section
                  const Text(
                    "Quick Samples:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _sampleTexts.asMap().entries.map((entry) {
                      return ActionChip(
                        label: Text("Sample ${entry.key + 1}"),
                        onPressed: () => _loadSampleText(entry.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Input Section
                  const Text(
                    "Input Text:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _inputController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText:
                          "Paste text with names, emails, phone numbers...",
                      filled: true,
                      fillColor: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Redact Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isProcessing || !_redactor.isModelLoaded)
                          ? null
                          : _processRedaction,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.shield_outlined),
                      label: Text(
                        _isProcessing
                            ? "Processing..."
                            : "Redact PII (Locally)",
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Output Section
                  const Text(
                    "Redacted Output:",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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
                    constraints: const BoxConstraints(minHeight: 150),
                    child: SelectableText(
                      _output.isEmpty ? "Redacted text will appear here..." : _output,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: _output.isEmpty ? Colors.grey[600] : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info Section
                  Container(
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
                              "How it works:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "• Regex Pass: Instantly catches emails, phones, SSNs, credit cards\n"
                          "• LLM Pass: Uses Qwen 2.5 (0.5B) to detect names, locations, organizations\n"
                          "• 100% Local: No data leaves your device\n"
                          "• Model: Qwen 2.5 (0.5B) - optimized for mobile",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[300],
                            height: 1.5,
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
}
