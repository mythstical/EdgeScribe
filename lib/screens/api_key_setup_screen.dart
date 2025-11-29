import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/transcription_service.dart';
import '../services/soap_generation_service.dart';

/// API Key setup screen for first-time users
class ApiKeySetupScreen extends StatefulWidget {
  final TranscriptionService leopardService;
  final SoapGenerationService soapService;

  const ApiKeySetupScreen({
    super.key,
    required this.leopardService,
    required this.soapService,
  });

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  final TextEditingController _picovoiceKeyController = TextEditingController();
  final TextEditingController _openRouterKeyController =
      TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final openRouterKey = await widget.soapService.getStoredApiKey();
    if (openRouterKey != null && mounted) {
      _openRouterKeyController.text = openRouterKey;
    }
  }

  @override
  void dispose() {
    _picovoiceKeyController.dispose();
    _openRouterKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final picovoiceKey = _picovoiceKeyController.text.trim();
    final openRouterKey = _openRouterKeyController.text.trim();

    if (picovoiceKey.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your Picovoice AccessKey';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save and initialize Leopard
      await widget.leopardService.setApiKey(picovoiceKey);

      // Save OpenRouter Key (optional)
      if (openRouterKey.isNotEmpty) {
        await widget.soapService.setApiKey(openRouterKey);
      }

      if (mounted) {
        // Success - close this screen
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid API key: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'SETUP API KEYS',
          style: GoogleFonts.robotoMono(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white24, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.vpn_key_outlined,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Title
            Text(
              'WELCOME TO EDGESCRIBE',
              style: GoogleFonts.robotoMono(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'Configure your API keys to enable transcription and SOAP note generation features.',
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.6,
                color: Colors.white54,
              ),
            ),

            const SizedBox(height: 40),

            // Picovoice API Key Input
            TextField(
              controller: _picovoiceKeyController,
              enabled: !_isLoading,
              style: GoogleFonts.robotoMono(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'PICOVOICE ACCESSKEY (REQUIRED)',
                labelStyle: GoogleFonts.robotoMono(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                hintText: 'PASTE YOUR PICOVOICE KEY',
                hintStyle: GoogleFonts.robotoMono(
                  color: Colors.white24,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.mic_none_outlined,
                  color: Colors.white54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD71921),
                    width: 1,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF111111),
                errorText: _errorMessage,
                errorStyle: GoogleFonts.robotoMono(
                  color: const Color(0xFFD71921),
                ),
              ),
              maxLines: 1,
              obscureText: false,
            ),

            const SizedBox(height: 8),

            // Picovoice Help Text
            Text(
              'GET FREE KEY AT CONSOLE.PICOVOICE.AI',
              style: GoogleFonts.robotoMono(
                color: Colors.white24,
                fontSize: 10,
              ),
            ),

            const SizedBox(height: 24),

            // OpenRouter API Key Input
            TextField(
              controller: _openRouterKeyController,
              enabled: !_isLoading,
              style: GoogleFonts.robotoMono(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'OPENROUTER API KEY (OPTIONAL)',
                labelStyle: GoogleFonts.robotoMono(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                hintText: 'PASTE YOUR OPENROUTER KEY',
                hintStyle: GoogleFonts.robotoMono(
                  color: Colors.white24,
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.cloud_outlined,
                  color: Colors.white54,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFD71921),
                    width: 1,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF111111),
              ),
              maxLines: 1,
              obscureText: true,
            ),

            const SizedBox(height: 8),

            // OpenRouter Help Text
            Text(
              'REQUIRED FOR SOAP NOTE GENERATION',
              style: GoogleFonts.robotoMono(
                color: Colors.white24,
                fontSize: 10,
              ),
            ),

            const SizedBox(height: 40),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
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
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'SAVE & CONTINUE',
                        style: GoogleFonts.robotoMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 1.0,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
