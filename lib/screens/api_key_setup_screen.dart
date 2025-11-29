import 'package:flutter/material.dart';
import '../services/transcription_service.dart';

/// API Key setup screen for first-time users
class ApiKeySetupScreen extends StatefulWidget {
  final TranscriptionService leopardService;

  const ApiKeySetupScreen({super.key, required this.leopardService});

  @override
  State<ApiKeySetupScreen> createState() => _ApiKeySetupScreenState();
}

class _ApiKeySetupScreenState extends State<ApiKeySetupScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final key = _keyController.text.trim();

    if (key.isEmpty) {
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
      await widget.leopardService.setApiKey(key);

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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Setup Picovoice Leopard'),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
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
              child: Icon(
                Icons.key,
                size: 80,
                color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
              ),
            ),

            const SizedBox(height: 32),

            // Title
            const Text(
              'Welcome to EdgeScribe!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'EdgeScribe uses Picovoice Leopard for fast, accurate transcription.\n\n'
              'To get started, enter your Picovoice AccessKey below.\n'
              '(Free tier: 3 hours/month processing)',
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: 32),

            // API Key Input
            TextField(
              controller: _keyController,
              enabled: !_isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Picovoice AccessKey',
                labelStyle: TextStyle(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
                ),
                hintText: 'Paste your key here',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF00D9FF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00D9FF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF16213E),
                errorText: _errorMessage,
              ),
              maxLines: 1,
              obscureText: false,
            ),

            const SizedBox(height: 16),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00D9FF),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Get your free key at console.picovoice.ai',
                      style: TextStyle(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF00D9FF),
                  foregroundColor: const Color(0xFF1A1A2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF1A1A2E),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
