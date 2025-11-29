import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SoapGenerationService {
  static const String _prefApiKey = 'openrouter_api_key';

  // Build-time constant for default key
  static const String _defaultApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
  );

  // Default model: Google Gemini Flash 1.5 (High speed, low cost, large context)
  static const String _defaultModel = "x-ai/grok-4.1-fast:free";

  Future<String?> getStoredApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefApiKey) ??
        (_defaultApiKey.isNotEmpty ? _defaultApiKey : null);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key);
  }

  /// Generates a SOAP note from the provided (redacted) transcript.
  /// Returns the generated SOAP note text.
  Future<String> generateSoapNote({
    required String transcript,
    String model = _defaultModel,
  }) async {
    final apiKey = await getStoredApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'OpenRouter API Key not configured. Please set it in Settings.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://edgescribe.app', // Required by OpenRouter
          'X-Title': 'EdgeScribe',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': '''You are an expert medical scribe. 
Task: Create a professional SOAP note based on the provided transcript.
Format:
S: Subjective
O: Objective
A: Assessment
P: Plan

Rules:
1. Use the exact placeholders provided in the transcript (e.g., {{PERSON_0}}, {{ORG_1}}) in your output. DO NOT change or hallucinate names.
2. Be concise and professional.
3. Maintain the placeholders exactly as they appear so they can be re-identified later.''',
            },
            {'role': 'user', 'content': transcript},
          ],
          'temperature': 0.2, // Low temperature for consistency
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        if (content != null) {
          return content;
        } else {
          throw Exception('Empty response from AI provider');
        }
      } else {
        throw Exception(
          'Failed to generate SOAP note: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[SoapService] Error: $e');
      rethrow;
    }
  }
}
