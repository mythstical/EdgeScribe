import 'package:cactus/cactus.dart';

/// A local PII redaction service using hybrid regex + LLM approach
/// Uses regex for fast detection of emails/phones, and Qwen 2.5 for context-aware redaction
class LocalPIIRedactor {
  CactusLM? _model;
  bool isModelLoaded = false;
  String? _downloadError;

  // Use a hosted model slug that exists in the current Cactus catalog.
  // Primary keeps tool-calling capability; fallback is the smallest live model.
  static const String _primaryModelSlug = "qwen3-0.6";
  static const String _fallbackModelSlug = "gemma3-270m";

  // Regex patterns for "easy" redaction (100% accuracy, zero latency)
  final _emailRegex = RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w{2,4}\b');
  final _phoneRegex = RegExp(
      r'\b(?:\+?(\d{1,3}))?[-. (]*(\d{3})[-. )]*(\d{3})[-. ]*(\d{4})\b');

  // Additional regex patterns for common PII
  final _ssnRegex = RegExp(r'\b\d{3}-\d{2}-\d{4}\b'); // SSN pattern
  final _creditCardRegex = RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'); // Credit card

  String? get downloadError => _downloadError;

  /// Initialize the Cactus Local Model
  /// Downloads and initializes Qwen 2.5 (0.5B) - optimized for mobile/emulator
  Future<void> init({
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      _model = CactusLM();
      _downloadError = null;

      // Try primary model first, then fall back to a smaller live model if needed.
      await _downloadAndInitModel(_primaryModelSlug, onProgress);

      isModelLoaded = true;
    } catch (e) {
      // On failure, attempt a fallback model once.
      if (_model != null && _model!.isLoaded() == false) {
        try {
          await _downloadAndInitModel(_fallbackModelSlug, onProgress);
          isModelLoaded = true;
          _downloadError = null;
          return;
        } catch (_) {
          // Preserve the original error if fallback also fails.
        }
      }

      _downloadError = e.toString();
      rethrow;
    }
  }

  Future<void> _downloadAndInitModel(
    String slug,
    Function(double progress, String status)? onProgress,
  ) async {
    await _model!.downloadModel(
      model: slug,
      downloadProcessCallback: (progress, status, isError) {
        if (isError) {
          _downloadError = status;
          onProgress?.call(0, "Error: $status");
        } else {
          onProgress?.call(progress ?? 0, status);
        }
      },
    );

    if (_downloadError != null) {
      throw Exception("Model download failed: $_downloadError");
    }

    await _model!.initializeModel(
      params: CactusInitParams(model: slug, contextSize: 1024),
    );
  }

  /// The Main Redaction Function
  /// Step 1: Regex pass (instant, high precision)
  /// Step 2: LLM pass (context-aware, catches names/locations/orgs)
  Future<String> redact(String input) async {
    if (!isModelLoaded) {
      return "Error: Model not loaded. Please initialize first.";
    }

    if (input.trim().isEmpty) {
      return input;
    }

    // Step 1: Regex Redaction (Fast & Cheap)
    String partiallyRedacted = _regexRedact(input);

    // Step 2: LLM Redaction (Smart & Contextual)
    // We send the partially redacted text to the LLM to find names/addresses/orgs
    return await _runLLMRedaction(partiallyRedacted);
  }

  /// Fast regex-based redaction for structured PII
  String _regexRedact(String text) {
    return text
        .replaceAll(_emailRegex, '[EMAIL]')
        .replaceAll(_phoneRegex, '[PHONE]')
        .replaceAll(_ssnRegex, '[SSN]')
        .replaceAll(_creditCardRegex, '[CARD]');
  }

  /// LLM-based contextual redaction for names, locations, organizations
  /// Uses few-shot prompting to teach the model the exact pattern we want
  Future<String> _runLLMRedaction(String text) async {
    // Critical: Few-shot prompting to prevent the model from "chatting back"
    // Small models need explicit examples to stay on task
    final messages = [
      ChatMessage(
        role: "system",
        content:
            "Redact PII from input. Replace names with [PERSON], locations with [LOC], organizations with [ORG]. Return ONLY the modified text, no explanations.",
      ),

      // Example 1: Teaching the pattern (Few-shot learning)
      ChatMessage(
        role: "user",
        content: "Contact Sarah at 555-0192.",
      ),
      ChatMessage(
        role: "assistant",
        content: "Contact [PERSON] at [PHONE].",
      ),

      // Example 2: More complex case
      ChatMessage(
        role: "user",
        content: "Meeting with John Smith from CorpInc in Berlin tomorrow.",
      ),
      ChatMessage(
        role: "assistant",
        content: "Meeting with [PERSON] from [ORG] in [LOC] tomorrow.",
      ),

      // Example 3: Mixed entities
      ChatMessage(
        role: "user",
        content: "Dr. Martinez works at Mayo Clinic in Rochester.",
      ),
      ChatMessage(
        role: "assistant",
        content: "[PERSON] works at [ORG] in [LOC].",
      ),

      // Actual User Input (what we want to redact)
      ChatMessage(
        role: "user",
        content: text,
      ),
    ];

    try {
      final result = await _model!.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          temperature: 0.1, // Low temp = strict adherence, less creativity
          maxTokens: 1000, // Allow for longer outputs if needed
          topP: 0.9,
        ),
      );

      // Clean up the response (remove any extra chatter)
      final response = result.response.trim();

      // Sometimes small models add prefix like "Here is the text:" - remove it
      final cleanedResponse = _removeCommonPrefixes(response);

      return cleanedResponse;
    } catch (e) {
      // Fallback to regex-only redaction if LLM fails
      return text;
    }
  }

  /// Remove common conversational prefixes that small models sometimes add
  String _removeCommonPrefixes(String text) {
    final prefixPatterns = [
      RegExp(r"^(Sure,?\s*)?here\s+(is|'s)\s+(the\s+)?(redacted\s+)?text:?\s*", caseSensitive: false),
      RegExp(r'^(OK,?\s*)?redacted version:?\s*', caseSensitive: false),
      RegExp(r'^output:?\s*', caseSensitive: false),
    ];

    String cleaned = text;
    for (var pattern in prefixPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }

    return cleaned.trim();
  }

  /// Cleanup and unload model
  void dispose() {
    _model?.unload();
    isModelLoaded = false;
  }
}
