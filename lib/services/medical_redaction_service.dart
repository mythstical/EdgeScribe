import 'package:flutter/services.dart' show rootBundle;
import 'package:cactus/cactus.dart';
import 'cactus_model_service.dart';

/// Represents a single redacted entity with position metadata for UI highlighting
class RedactionEntity {
  final String label; // e.g., "EMAIL", "PHONE", "PERSON", "ORG", "LOC"
  final String originalValue; // The actual PII text that was redacted
  final int start; // Start position in original text
  final int end; // End position in original text
  final int layer; // Which layer detected it (1=Regex, 2=Dict, 3=LLM)

  RedactionEntity({
    required this.label,
    required this.originalValue,
    required this.start,
    required this.end,
    required this.layer,
  });

  @override
  String toString() =>
      'RedactionEntity($label: "$originalValue" at $start-$end, L$layer)';
}

/// Per-layer timing metrics
class LayerMetrics {
  final int layer1RegexMs;
  final int layer2DictMs;
  final int layer3LlmMs;
  final int totalMs;

  LayerMetrics({
    required this.layer1RegexMs,
    required this.layer2DictMs,
    required this.layer3LlmMs,
    required this.totalMs,
  });

  @override
  String toString() =>
      'L1: ${layer1RegexMs}ms, L2: ${layer2DictMs}ms, L3: ${layer3LlmMs}ms, Total: ${totalMs}ms';
}

/// Structured result from the redaction pipeline
class RedactionResult {
  final String originalText;
  final String redactedText;
  final List<RedactionEntity> entities;
  final LayerMetrics metrics;
  final int hallucinationsBlocked;
  final bool llmEnabled;

  RedactionResult({
    required this.originalText,
    required this.redactedText,
    required this.entities,
    required this.metrics,
    required this.hallucinationsBlocked,
    required this.llmEnabled,
  });

  bool get hasPII => entities.isNotEmpty;
  int get layer1Count => entities.where((e) => e.layer == 1).length;
  int get layer2Count => entities.where((e) => e.layer == 2).length;
  int get layer3Count => entities.where((e) => e.layer == 3).length;

  Map<String, int> get entityCounts {
    final counts = <String, int>{};
    for (var entity in entities) {
      counts[entity.label] = (counts[entity.label] ?? 0) + 1;
    }
    return counts;
  }
}

/// Production-ready Medical Redaction Service using 3-Layer Filter Architecture
/// Optimized for Nothing Phone (2) - Snapdragon 8+ Gen 1
///
/// Layer 1: Deterministic Regex (<1ms) - Email, Phone, Date, MRN/SSN
/// Layer 2: Fast Dictionary Lookup (~5ms) - Cities with O(1) HashSet
/// Layer 3: Cactus LLM Inference (~200ms) - Person Names, Organizations
///
/// NOTE: This service now uses the global CactusModelService for the LLM.
/// The model is loaded once at app startup and shared across all instances.
class MedicalRedactionService {
  // O(1) lookup sets loaded from assets
  Set<String> _medicalTerms = {};
  Set<String> _cities = {};

  bool _dictionariesLoaded = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // REGEX PATTERNS (Layer 1)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Email: standard pattern
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  /// Phone: Matches various US phone number formats
  /// - (555) 123-4567
  /// - 555.123.4567
  /// - 555-123-4567
  /// - 5551234567
  /// - +1 555-123-4567
  /// - 1-555-123-4567
  /// - Also catches international formats with country codes
  static final RegExp _phonePattern = RegExp(
    r'(?<!\w)(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?:\s*(?:ext|extension|x|#)[-.\s]?\d+)?\b',
  );

  /// Honorifics/titles followed by capitalized name (catches Dr. X, Patient Y, etc.)
  static final RegExp _honorificPattern = RegExp(
    r"\b(Dr|Mr|Mrs|Ms|Miss|Prof|Nurse|Patient|Officer|Detective|Agent|Rev|Fr|Sr|Jr)\.?\s+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+)?)",
  );

  /// Date: MM/DD/YYYY or Month Day, Year
  static final RegExp _datePattern = RegExp(
    r'\b(?:'
    r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|'
    r'\d{4}[/\-]\d{1,2}[/\-]\d{1,2}|'
    r'(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
    r'\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{2,4}'
    r')\b',
    caseSensitive: false,
  );

  /// MRN/SSN/ID: Matches SSN (###-##-####), MRN (various formats like MRN-123456, 12345678)
  static final RegExp _idPattern = RegExp(
    r'(?:'
    r'(?:SSN|MRN|ID|Medical\s+Record|Patient\s+ID)[:\s#-]+\d{5,12}|'  // MRN: 12345678, SSN: 123-45-6789
    r'\b\d{3}[-\s]\d{2}[-\s]\d{4}\b'                                    // SSN format only: 123-45-6789
    r')',
    caseSensitive: false,
  );

  /// Insurance provider names (e.g., "BlueCross", "Aetna PPO", "UnitedHealth")
  static final RegExp _insurancePattern = RegExp(
    r'\b(?:'
    r'(?:[A-Z][a-z]+)?(?:Shield|Cross|Care|Health|Guard|Plan|Med)\s*(?:PPO|HMO|EPO|POS)?|'
    r'Aetna|Cigna|Humana|UnitedHealth(?:care)?|Anthem|Kaiser|WellPoint|Centene|'
    r'Medicare|Medicaid|Blue\s*(?:Cross|Shield)|Silver\s*(?:Shield|Cross)|Gold\s*(?:Shield|Cross)'
    r')\b',
    caseSensitive: false,
  );

  /// Street address: Number + Street name + optional apt/unit + optional city + optional state/ZIP
  /// Matches: "742 lakeview drive, apt 3b, Riverside, CA 92507"
  static final RegExp _addressPattern = RegExp(
    r'\b\d{1,5}\s+(?:[A-Z][a-z]+\s+){1,4}(?:Street|St|Avenue|Ave|Road|Rd|Drive|Dr|Lane|Ln|Boulevard|Blvd|Way|Court|Ct|Circle|Cir|Place|Pl)'
    r'(?:,?\s*(?:Apt|Unit|Suite|Ste|#)\s*[A-Za-z0-9-]+)?'
    r'(?:,?\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)?' // Optional city name
    r'(?:,?\s+[A-Z]{2}\s+\d{5}(?:-\d{4})?)?', // Optional state + ZIP
    caseSensitive: false,
  );

  /// ZIP code pattern: 12345 or 12345-6789
  static final RegExp _zipPattern = RegExp(
    r'\b\d{5}(?:-\d{4})?\b',
  );

  /// State abbreviation + ZIP: CA 92507, NY 10001
  static final RegExp _stateZipPattern = RegExp(
    r'\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Load dictionaries from assets (call on app launch)
  Future<void> loadDictionaries() async {
    if (_dictionariesLoaded) return;

    // Load medical terms
    final medicalData = await rootBundle.loadString('assets/medical_terms.txt');
    _medicalTerms = medicalData
        .split('\n')
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();

    // Load cities
    final citiesData = await rootBundle.loadString('assets/cities.txt');
    _cities = citiesData
        .split('\n')
        .map((l) => l.trim().toLowerCase())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toSet();

    _dictionariesLoaded = true;
    print(
      '[Redactor] Dictionaries loaded: ${_medicalTerms.length} medical terms, ${_cities.length} cities',
    );
  }

  /// Initialize LLM model for Layer 3
  ///
  /// DEPRECATED: The global CactusModelService is now initialized at app startup.
  /// This method is kept for backward compatibility but delegates to the global service.
  Future<void> initializeLLM({
    Function(double?, String, bool)? onProgress,
  }) async {
    print('[Redactor] Delegating LLM initialization to global CactusModelService');

    // The model is already initialized at app startup via CactusModelService
    // This method now just ensures it's ready
    if (!CactusModelService.instance.isLoaded) {
      await CactusModelService.instance.initialize();
    }

    print('[Redactor] LLM ready (using global model service)');
  }

  bool get dictionariesReady => _dictionariesLoaded;

  /// Check if LLM is ready (uses global model service)
  bool get llmReady => CactusModelService.instance.isLoaded;

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 1: DETERMINISTIC REGEX (Speed: <1ms)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply regex rules and collect entities with positions
  String _applyRegexRules(String text, List<RedactionEntity> entities) {
    var result = text;
    var offset = 0; // Track position shifts from replacements

    // Helper to apply pattern and track entities
    void applyPattern(RegExp pattern, String label) {
      final newResult = StringBuffer();
      var lastEnd = 0;
      var matchCount = 0;

      for (final match in pattern.allMatches(result)) {
        matchCount++;
        // Add text before match
        newResult.write(result.substring(lastEnd, match.start));

        // Record entity at original position
        final originalStart = match.start + offset;
        final originalEnd = match.end + offset;

        final matchedText = match.group(0)!;
        entities.add(
          RedactionEntity(
            label: label,
            originalValue: matchedText,
            start: originalStart,
            end: originalEnd,
            layer: 1,
          ),
        );

        print('[Redactor] Regex matched $label: "$matchedText"');

        // Add replacement tag
        final tag = '[$label]';
        newResult.write(tag);

        lastEnd = match.end;
      }

      if (matchCount == 0) {
        print('[Redactor] No matches for $label pattern');
      }

      newResult.write(result.substring(lastEnd));

      // Update offset for position tracking
      final oldLength = result.length;
      result = newResult.toString();
      offset += result.length - oldLength;
    }

    // Apply patterns in order (most specific first)
    print('[Redactor] Applying EMAIL pattern...');
    applyPattern(_emailPattern, 'EMAIL');
    print('[Redactor] Applying PHONE pattern...');
    print('[Redactor] ==== COMPLETE TEXT BEING SCANNED ====');
    print(result);
    print('[Redactor] ==== END OF TEXT ====');
    applyPattern(_phonePattern, 'PHONE');
    print('[Redactor] Applying ADDRESS pattern (full address with city/state/zip)...');
    applyPattern(_addressPattern, 'LOC');
    print('[Redactor] Applying STATE+ZIP pattern...');
    applyPattern(_stateZipPattern, 'LOC');
    print('[Redactor] Applying ZIP pattern...');
    applyPattern(_zipPattern, 'LOC');
    print('[Redactor] Applying DATE pattern...');
    applyPattern(_datePattern, 'DATE');
    print('[Redactor] Applying ID pattern to: ${result.substring(0, result.length > 100 ? 100 : result.length)}...');
    applyPattern(_idPattern, 'ID');
    print('[Redactor] Applying INSURANCE pattern...');
    applyPattern(_insurancePattern, 'INSURANCE');

    // Special handling for honorific + name (keep title, redact name)
    print('[Redactor] Applying HONORIFIC pattern to: ${result.substring(0, result.length > 100 ? 100 : result.length)}...');
    final honorificResult = StringBuffer();
    var lastEnd = 0;
    for (final match in _honorificPattern.allMatches(result)) {
      honorificResult.write(result.substring(lastEnd, match.start));

      final title = match.group(1)!; // "Dr", "Patient", etc.
      final name = match.group(2)!; // "John Smith"

      print('[Redactor] Regex matched PERSON (honorific): "$title. $name"');

      entities.add(
        RedactionEntity(
          label: 'PERSON',
          originalValue: name,
          start: match.start + title.length + 1 + offset, // Position of name
          end: match.end + offset,
          layer: 1,
        ),
      );

      // Keep the title, redact the name
      honorificResult.write('$title. [PERSON]');
      lastEnd = match.end;
    }
    honorificResult.write(result.substring(lastEnd));
    result = honorificResult.toString();

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 2: FAST DICTIONARY LOOKUP (Speed: ~5ms)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply dictionary-based city detection with O(1) HashSet lookup
  String _applyDictionaries(String text, List<RedactionEntity> entities) {
    if (!_dictionariesLoaded) return text;

    var result = text;
    final words = <_WordToken>[];

    // Tokenize text while preserving positions
    final wordPattern = RegExp(r'\b[A-Za-z]+(?:\s+[A-Za-z]+)?\b');
    for (final match in wordPattern.allMatches(text)) {
      words.add(
        _WordToken(text: match.group(0)!, start: match.start, end: match.end),
      );
    }

    // Check each word/phrase against dictionaries
    final toRedact = <_WordToken>[];

    for (final word in words) {
      final lower = word.text.toLowerCase();

      // Check if Title Case (potential location)
      final isTitleCase = word.text[0] == word.text[0].toUpperCase();

      if (isTitleCase &&
          _cities.contains(lower) &&
          !_medicalTerms.contains(lower)) {
        toRedact.add(word);
      }
    }

    // Apply redactions in reverse order to preserve positions
    toRedact.sort((a, b) => b.start.compareTo(a.start));

    for (final word in toRedact) {
      entities.add(
        RedactionEntity(
          label: 'LOC',
          originalValue: word.text,
          start: word.start,
          end: word.end,
          layer: 2,
        ),
      );

      result =
          result.substring(0, word.start) +
          '[LOC]' +
          result.substring(word.end);
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 3: CACTUS LLM INFERENCE (Speed: ~200ms)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Use LLM to extract Person Names and Organizations
  Future<_LLMResult> _applyCactusLLM(
    String text,
    List<RedactionEntity> entities,
  ) async {
    if (!llmReady) {
      return _LLMResult(text: text, hallucinations: 0);
    }

    // Few-shot prompt to force format (no reasoning allowed)
    const systemPrompt = '''Extract person names only.''';

    final userPrompt = '''Text: Dr. Smith treated John Doe.
Names:
John Doe | PERSON

Text: Patient visited clinic.
Names:
NOTHING

Text: $text
Names:''';

    // Use the global model instance
    final model = CactusModelService.instance.model;

    final response = await model.generateCompletion(
      messages: [
        ChatMessage(content: systemPrompt, role: 'system'),
        ChatMessage(content: userPrompt, role: 'user'),
      ],
      params: CactusCompletionParams(
        temperature: 0.0,       // Deterministic
        topK: 3,                // Very focused
        maxTokens: 50,          // Reduced - just need names
        stopSequences: [
          '\n\nText:',
          '\nText:',
          'Okay',
          'So ',
          'Let me',
          'First',
          '<|endoftext|>',
          '<|im_end|>',
        ],
      ),
    );

    if (!response.success) {
      print('[Redactor] LLM extraction failed');
      return _LLMResult(text: text, hallucinations: 0);
    }

    final responseText = response.response;
    if (responseText.isEmpty) {
      print('[Redactor] LLM returned empty response');
      return _LLMResult(text: text, hallucinations: 0);
    }

    var output = responseText;
    print('[Redactor] LLM raw: $output');

    // Aggressive cleaning of thinking artifacts and explanations
    // Remove <think>...</think> blocks (even incomplete ones)
    output = output.replaceAll(RegExp(r'<think>.*', dotAll: true), '');

    // Remove any line that looks like reasoning/explanation
    final lines = output.split('\n');
    final cleanedLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // Keep only lines that match the "Name | LABEL" format or "NOTHING"
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase() == 'NOTHING') {
        cleanedLines.add(trimmed);
        break; // Stop processing after NOTHING
      }
      if (trimmed.contains('|') && !trimmed.toLowerCase().startsWith('okay') &&
          !trimmed.toLowerCase().startsWith('so ') && !trimmed.toLowerCase().startsWith('first')) {
        cleanedLines.add(trimmed);
      }
    }

    output = cleanedLines.join('\n');

    if (output.trim().toUpperCase() == 'NOTHING' || output.trim().isEmpty) {
      print('[Redactor] No entities found by LLM');
      return _LLMResult(text: text, hallucinations: 0);
    }

    // Parse entities
    var result = text;
    var hallucinations = 0;

    final entityLines = output
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.contains('|'));

    for (final line in entityLines) {
      final parts = line.split('|').map((p) => p.trim()).toList();
      if (parts.length < 2) continue;

      final entity = parts[0];
      final labelRaw = parts[1].toUpperCase();

      if (entity.isEmpty || entity.length < 2) continue;

      // Skip medical terms
      if (_medicalTerms.contains(entity.toLowerCase())) {
        print('[Redactor] Skip medical term: $entity');
        continue;
      }

      // Validate: Does entity exist in current text?
      final pattern = RegExp(
        r'\b' + RegExp.escape(entity) + r'\b',
        caseSensitive: false,
      );

      if (!pattern.hasMatch(result)) {
        print('[Redactor] HALLUCINATION BLOCKED: "$entity"');
        hallucinations++;
        continue;
      }

      // Determine label
      String label;
      if (labelRaw.contains('PERSON') || labelRaw.contains('NAME')) {
        label = 'PERSON';
      } else if (labelRaw.contains('ORG') || labelRaw.contains('FACILITY')) {
        label = 'ORG';
      } else {
        label = 'REDACTED';
      }

      // Find and record entity position in original text
      final match = pattern.firstMatch(result);
      if (match != null) {
        entities.add(
          RedactionEntity(
            label: label,
            originalValue: entity,
            start: match.start,
            end: match.end,
            layer: 3,
          ),
        );
      }

      // Apply redaction
      result = result.replaceAllMapped(pattern, (m) => '[$label]');
      print('[Redactor] Redacted: "$entity" -> [$label]');
    }

    return _LLMResult(text: result, hallucinations: hallucinations);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Run the full 3-layer redaction pipeline
  Future<RedactionResult> redact(String text, {bool enableLLM = true}) async {
    if (!_dictionariesLoaded) {
      await loadDictionaries();
    }

    if (text.trim().isEmpty) {
      return RedactionResult(
        originalText: text,
        redactedText: text,
        entities: [],
        metrics: LayerMetrics(
          layer1RegexMs: 0,
          layer2DictMs: 0,
          layer3LlmMs: 0,
          totalMs: 0,
        ),
        hallucinationsBlocked: 0,
        llmEnabled: enableLLM,
      );
    }

    final totalStopwatch = Stopwatch()..start();
    final entities = <RedactionEntity>[];

    // LAYER 1: Regex
    final l1Stopwatch = Stopwatch()..start();
    var currentText = _applyRegexRules(text, entities);
    l1Stopwatch.stop();
    print(
      '[Redactor] Layer 1 (Regex): ${l1Stopwatch.elapsedMilliseconds}ms, ${entities.length} entities',
    );

    // LAYER 2: Dictionary
    final l2Stopwatch = Stopwatch()..start();
    currentText = _applyDictionaries(currentText, entities);
    l2Stopwatch.stop();
    final l2Count = entities.where((e) => e.layer == 2).length;
    print(
      '[Redactor] Layer 2 (Dict): ${l2Stopwatch.elapsedMilliseconds}ms, $l2Count entities',
    );

    // LAYER 3: LLM (optional)
    int hallucinations = 0;
    int l3Ms = 0;

    if (enableLLM && llmReady) {
      final l3Stopwatch = Stopwatch()..start();
      final llmResult = await _applyCactusLLM(currentText, entities);
      currentText = llmResult.text;
      hallucinations = llmResult.hallucinations;
      l3Stopwatch.stop();
      l3Ms = l3Stopwatch.elapsedMilliseconds;
      final l3Count = entities.where((e) => e.layer == 3).length;
      print(
        '[Redactor] Layer 3 (LLM): ${l3Ms}ms, $l3Count entities, $hallucinations blocked',
      );
    }

    totalStopwatch.stop();

    return RedactionResult(
      originalText: text,
      redactedText: currentText,
      entities: entities,
      metrics: LayerMetrics(
        layer1RegexMs: l1Stopwatch.elapsedMilliseconds,
        layer2DictMs: l2Stopwatch.elapsedMilliseconds,
        layer3LlmMs: l3Ms,
        totalMs: totalStopwatch.elapsedMilliseconds,
      ),
      hallucinationsBlocked: hallucinations,
      llmEnabled: enableLLM && llmReady,
    );
  }

  /// Run Layer 1 + 2 only (fast mode, no LLM)
  Future<RedactionResult> redactFast(String text) async {
    return redact(text, enableLLM: false);
  }

  /// Generate embeddings using the loaded CactusLM model
  Future<List<double>> generateEmbedding(String text) async {
    if (!llmReady) {
      throw Exception('CactusLM not initialized (global model service not ready)');
    }

    // Use the global model instance
    final model = CactusModelService.instance.model;
    final result = await model.generateEmbedding(text: text);

    if (result.success) {
      return result.embeddings;
    } else {
      throw Exception('Embedding generation failed: ${result.errorMessage}');
    }
  }

  /// Clean up resources
  ///
  /// NOTE: This no longer unloads the LLM model since it's now global.
  /// The model stays resident in memory for use by all features.
  void dispose() {
    // Dictionary cleanup only - model is managed globally
    _medicalTerms.clear();
    _cities.clear();
    _dictionariesLoaded = false;
  }
}

/// Internal token for word position tracking
class _WordToken {
  final String text;
  final int start;
  final int end;

  _WordToken({required this.text, required this.start, required this.end});
}

/// Internal LLM result
class _LLMResult {
  final String text;
  final int hallucinations;

  _LLMResult({required this.text, required this.hallucinations});
}
