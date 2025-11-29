import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // ... (imports remain the same)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'LOCAL PII REDACTOR',
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
          if (!_isLoading && _output.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white),
              tooltip: "COPY REDACTED TEXT",
              onPressed: _copyToClipboard,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
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
                      "DOWNLOADING QWEN 2.5 (0.5B) MODEL...\nTHIS MAY TAKE A FEW MINUTES ON FIRST LAUNCH.",
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
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sample Texts Section
                  Text(
                    "QUICK SAMPLES",
                    style: GoogleFonts.robotoMono(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sampleTexts.asMap().entries.map((entry) {
                      return ActionChip(
                        label: Text(
                          "SAMPLE ${entry.key + 1}",
                          style: GoogleFonts.robotoMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: const Color(0xFF111111),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: () => _loadSampleText(entry.value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 30),

                  // Input Section
                  Text(
                    "INPUT TEXT",
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
                    maxLines: 6,
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
                      hintText:
                          "PASTE TEXT WITH NAMES, EMAILS, PHONE NUMBERS...",
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

                  // Redact Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isLoading ||
                              _isProcessing ||
                              !_redactor.isModelLoaded)
                          ? null
                          : _processRedaction,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.shield_outlined,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isProcessing
                            ? "PROCESSING..."
                            : "REDACT PII (LOCALLY)",
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
                  ),
                  const SizedBox(height: 30),

                  // Output Section
                  Text(
                    "REDACTED OUTPUT",
                    style: GoogleFonts.robotoMono(
                      color: Colors.white54,
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
                    constraints: const BoxConstraints(minHeight: 150),
                    child: SelectableText(
                      _output.isEmpty
                          ? "REDACTED TEXT WILL APPEAR HERE..."
                          : _output,
                      style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        height: 1.6,
                        color: _output.isEmpty ? Colors.white24 : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Info Section
                  Container(
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
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white54,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "HOW IT WORKS",
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
                          "• REGEX PASS: INSTANTLY CATCHES EMAILS, PHONES, SSNS, CREDIT CARDS\n"
                          "• LLM PASS: USES QWEN 2.5 (0.5B) TO DETECT NAMES, LOCATIONS, ORGANIZATIONS\n"
                          "• 100% LOCAL: NO DATA LEAVES YOUR DEVICE\n"
                          "• MODEL: QWEN 2.5 (0.5B) - OPTIMIZED FOR MOBILE",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white54,
                            height: 1.6,
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
