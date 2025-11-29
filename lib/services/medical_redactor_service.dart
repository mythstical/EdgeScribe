import 'package:cactus/cactus.dart';
import 'cactus_model_service.dart';

/// Result containing text with unique placeholders and the mapping to restore them
class ReversibleRedactionResult {
  final String redactedText;
  final Map<String, String> mapping; // e.g., "{{PERSON_0}}" -> "John Doe"

  ReversibleRedactionResult({
    required this.redactedText,
    required this.mapping,
  });
}

/// Privacy-focused medical text redaction service using Extract & Locate architecture.
///
/// Pipeline:
/// 1. Rule Layer - Regex/heuristics redact deterministic PII (SSN, email, phone, dates, honorifics)
/// 2. LLM Layer - Small model extracts ONLY names/orgs as structured list
/// 3. Alignment Layer - Dart code locates exact strings and redacts (fixes hallucinations)
class MedicalRedactorService {
  // Uses global CactusModelService

  // ═══════════════════════════════════════════════════════════════════════════
  // DICTIONARIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Common medical terms to KEEP (not redact)
  static final Set<String> _medicalTerms = {
    'hypertension',
    'diabetes',
    'asthma',
    'copd',
    'cancer',
    'tumor',
    'carcinoma',
    'melanoma',
    'leukemia',
    'lymphoma',
    'arthritis',
    'osteoporosis',
    'pneumonia',
    'bronchitis',
    'influenza',
    'covid',
    'stroke',
    'aneurysm',
    'embolism',
    'thrombosis',
    'fibrillation',
    'tachycardia',
    'bradycardia',
    'murmur',
    'stenosis',
    'regurgitation',
    'insulin',
    'metformin',
    'lisinopril',
    'amlodipine',
    'atorvastatin',
    'omeprazole',
    'levothyroxine',
    'metoprolol',
    'losartan',
    'gabapentin',
    'prednisone',
    'amoxicillin',
    'azithromycin',
    'ibuprofen',
    'acetaminophen',
    'mri',
    'ct',
    'xray',
    'ultrasound',
    'ecg',
    'ekg',
    'biopsy',
    'endoscopy',
    'colonoscopy',
    'mammogram',
    'pap',
    'bloodwork',
    'urinalysis',
    'diagnosis',
    'prognosis',
    'treatment',
    'therapy',
    'surgery',
    'procedure',
    'prescription',
    'medication',
    'dosage',
    'mg',
    'ml',
    'cc',
    'patient',
    'doctor',
    'nurse',
    'physician',
    'specialist',
    'surgeon',
    'hospital',
    'clinic',
    'emergency',
    'icu',
    'or',
    'ward',
    'outpatient',
  };

  /// US Cities to redact (sample - expand as needed)
  static final Set<String> _cities = {
    'new york',
    'los angeles',
    'chicago',
    'houston',
    'phoenix',
    'philadelphia',
    'san antonio',
    'san diego',
    'dallas',
    'san jose',
    'austin',
    'jacksonville',
    'fort worth',
    'columbus',
    'charlotte',
    'san francisco',
    'indianapolis',
    'seattle',
    'denver',
    'boston',
    'nashville',
    'detroit',
    'portland',
    'las vegas',
    'memphis',
    'louisville',
    'baltimore',
    'milwaukee',
    'miami',
    'atlanta',
    'cleveland',
    'oakland',
    'minneapolis',
    'tampa',
    'pittsburgh',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // REGEX PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════

  /// SSN: 123-45-6789 or 123456789
  static final RegExp _ssnPattern = RegExp(r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b');

  /// Email addresses
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
  );

  /// Phone numbers (various formats)
  static final RegExp _phonePattern = RegExp(
    r'\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
  );

  /// Dates: MM/DD/YYYY, MM-DD-YYYY, Month DD, YYYY, etc.
  static final RegExp _datePattern = RegExp(
    r'\b(?:'
    r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|' // MM/DD/YYYY or MM-DD-YY
    r'\d{4}[/\-]\d{1,2}[/\-]\d{1,2}|' // YYYY-MM-DD
    r'(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
    r'\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{2,4}' // January 1st, 2024
    r')\b',
    caseSensitive: false,
  );

  /// Honorifics followed by capitalized name (includes Patient for medical contexts)
  static final RegExp _honorificPattern = RegExp(
    r"\b(Dr|Mr|Mrs|Ms|Miss|Prof|Nurse|Patient|Officer|Detective|Agent|Rev|Fr|Sr|Jr)\.?\s+([A-Z][a-zA-Z'-]+(?:\s+[A-Z][a-zA-Z'-]+)?)",
  );

  /// Street addresses (basic pattern)
  static final RegExp _addressPattern = RegExp(
    r'\b\d+\s+[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\s+(?:St(?:reet)?|Ave(?:nue)?|Blvd|Boulevard|Dr(?:ive)?|Ln|Lane|Rd|Road|Ct|Court|Way|Pl(?:ace)?|Cir(?:cle)?)\b\.?',
    caseSensitive: false,
  );

  /// ZIP codes
  static final RegExp _zipPattern = RegExp(r'\b\d{5}(?:-\d{4})?\b');

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the LLM model for entity extraction
  ///
  /// Delegates to global CactusModelService
  Future<void> initialize({Function(double?, String, bool)? onProgress}) async {
    // Just ensure global service is initialized
    await CactusModelService.instance.initialize();
  }

  /// Check if the service is ready
  bool get isReady => CactusModelService.instance.isLoaded;

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 1: RULE ENGINE (Pure Dart)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply all heuristic rules BEFORE the LLM
  String _applyHeuristics(String text) {
    var result = text;

    // 1. Redact SSNs
    result = result.replaceAllMapped(_ssnPattern, (m) => '[SSN]');

    // 2. Redact emails
    result = result.replaceAllMapped(_emailPattern, (m) => '[EMAIL]');

    // 3. Redact phone numbers
    result = result.replaceAllMapped(_phonePattern, (m) => '[PHONE]');

    // 4. Redact dates
    result = result.replaceAllMapped(_datePattern, (m) => '[DATE]');

    // 5. Redact addresses
    result = result.replaceAllMapped(_addressPattern, (m) => '[ADDRESS]');

    // 6. Redact ZIP codes (careful - might match other numbers)
    result = result.replaceAllMapped(_zipPattern, (m) {
      // Only redact if it looks like a standalone ZIP
      final match = m.group(0)!;
      final before = m.start > 0 ? text[m.start - 1] : ' ';
      if (before == ',' || before == ' ' || before == '\n') {
        return '[ZIP]';
      }
      return match;
    });

    // 7. Redact honorific + name patterns
    result = result.replaceAllMapped(_honorificPattern, (m) {
      final honorific = m.group(1)!;
      return '$honorific. [PERSON]';
    });

    // 8. Redact known cities (case-insensitive)
    for (final city in _cities) {
      final cityPattern = RegExp(
        r'\b' + RegExp.escape(city) + r'\b',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(cityPattern, (m) => '[LOCATION]');
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: LLM EXTRACTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// LLM extracts ONLY names and organizations as pipe-separated list
  Future<String> _runLLMExtraction(String cleanedText) async {
    if (!isReady) {
      throw StateError("Service not initialized. Call initialize() first.");
    }

    const systemPrompt =
        '''Task: List ONLY the Person Names and Organization Names in the text.
Format: "Entity Text | LABEL"
Rules:
1. Do not rewrite the sentence.
2. Do not include Dates, Emails, Phones, or Addresses (already redacted).
3. If none found, output NOTHING.
4. PERSON = human names, ORG = companies/hospitals/institutions.

Examples:
Input: "Dr. [PERSON] visited the hospital."
Output:
NOTHING

Input: "Alice went to Mayo Clinic for her appointment."
Output:
Alice | PERSON
Mayo Clinic | ORG

Input: "Give this prescription to Bob Smith at Mercy General."
Output:
Bob Smith | PERSON
Mercy General | ORG

Input: "The patient has hypertension and diabetes."
Output:
NOTHING''';

    final userPrompt = 'Input: "$cleanedText"\nOutput:';

    final result = await CactusModelService.instance.model.generateCompletion(
      messages: [
        ChatMessage(content: systemPrompt, role: "system"),
        ChatMessage(content: userPrompt, role: "user"),
      ],
      params: CactusCompletionParams(
        temperature: 0.0, // Deterministic - no creativity
        topK: 5, // Only high-probability tokens
        maxTokens: 100, // Prevent rambling
        stopSequences: [
          "Input:",
          "User:",
          "<|endoftext|>",
          "<|im_end|>",
          "<|end|>",
          "\n\n\n",
        ],
      ),
    );

    if (!result.success) {
      print("[Redactor] LLM extraction failed");
      return "";
    }

    final responseText = result.response;
    if (responseText.isEmpty) {
      print("[Redactor] LLM returned empty response");
      return "";
    }

    print("[Redactor] LLM raw output: $responseText");
    return responseText;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: ALIGNMENT & VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse LLM output and apply redactions with validation
  String _applyLLMRedactions(String originalText, String llmOutput) {
    var result = originalText;

    // 1. Clean artifacts (thinking traces, etc.)
    var cleaned = llmOutput;

    // Remove <think>...</think> blocks (dotall mode)
    cleaned = cleaned.replaceAll(
      RegExp(r'<think>.*?</think>', dotAll: true),
      '',
    );

    // Remove other common artifacts
    cleaned = cleaned.replaceAll(RegExp(r'<\|.*?\|>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```.*?```', dotAll: true), '');

    // Handle "NOTHING" or empty output
    if (cleaned.trim().toUpperCase() == 'NOTHING' || cleaned.trim().isEmpty) {
      print("[Redactor] No entities extracted by LLM");
      return result;
    }

    // 2. Parse lines
    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.contains('|'))
        .toList();

    print("[Redactor] Parsed ${lines.length} entity lines");

    // 3. Process each entity
    for (final line in lines) {
      final parts = line.split('|').map((p) => p.trim()).toList();

      if (parts.length < 2) continue;

      final entity = parts[0];
      final label = parts[1].toUpperCase();

      // Skip empty or too-short entities
      if (entity.isEmpty || entity.length < 2) continue;

      // Skip if it's a medical term we want to keep
      if (_medicalTerms.contains(entity.toLowerCase())) {
        print("[Redactor] Skipping medical term: $entity");
        continue;
      }

      // 4. Validate: Does this entity ACTUALLY exist in the text?
      // Use word boundary matching to avoid partial matches
      final entityPattern = RegExp(
        r'\b' + RegExp.escape(entity) + r'\b',
        caseSensitive: false,
      );

      if (!entityPattern.hasMatch(result)) {
        print("[Redactor] HALLUCINATION BLOCKED: '$entity' not found in text");
        continue;
      }

      // 5. Determine the redaction tag
      String tag;
      if (label.contains('PERSON') || label.contains('NAME')) {
        tag = '[PERSON]';
      } else if (label.contains('ORG')) {
        tag = '[ORG]';
      } else if (label.contains('LOCATION') || label.contains('PLACE')) {
        tag = '[LOCATION]';
      } else {
        tag = '[REDACTED]';
      }

      // 6. Apply redaction
      result = result.replaceAllMapped(entityPattern, (m) => tag);
      print("[Redactor] Redacted: '$entity' -> $tag");
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Redact PII from medical text using Extract & Locate architecture
  ///
  /// Returns a [RedactorPipelineResult] with the redacted text and metadata
  Future<RedactorPipelineResult> redact(String text) async {
    if (text.trim().isEmpty) {
      return RedactorPipelineResult(
        original: text,
        redacted: text,
        rulesApplied: 0,
        llmEntitiesFound: 0,
        hallucinationsBlocked: 0,
      );
    }

    final stopwatch = Stopwatch()..start();

    // STEP 1: Apply rule-based heuristics
    print("[Redactor] Step 1: Applying heuristics...");
    final afterRules = _applyHeuristics(text);

    // Count how many redactions were made by rules
    final ruleRedactions = RegExp(r'\[[A-Z]+\]').allMatches(afterRules).length;
    print("[Redactor] Rules applied: $ruleRedactions redactions");

    // STEP 2: LLM extraction (only if service is ready)
    String finalText = afterRules;
    int llmEntities = 0;
    int hallucinations = 0;

    if (isReady) {
      print("[Redactor] Step 2: LLM extraction...");
      final llmOutput = await _runLLMExtraction(afterRules);

      // Count entities found
      final entityLines = llmOutput
          .split('\n')
          .where((l) => l.contains('|'))
          .length;

      // STEP 3: Apply LLM redactions with validation
      print("[Redactor] Step 3: Alignment & validation...");
      finalText = _applyLLMRedactions(afterRules, llmOutput);

      // Count new redactions from LLM
      final newRedactions =
          RegExp(r'\[[A-Z]+\]').allMatches(finalText).length - ruleRedactions;
      llmEntities = newRedactions > 0 ? newRedactions : 0;
      hallucinations = entityLines - llmEntities;
      if (hallucinations < 0) hallucinations = 0;
    } else {
      print("[Redactor] LLM not ready, using rules only");
    }

    stopwatch.stop();
    print("[Redactor] Complete in ${stopwatch.elapsedMilliseconds}ms");

    return RedactorPipelineResult(
      original: text,
      redacted: finalText,
      rulesApplied: ruleRedactions,
      llmEntitiesFound: llmEntities,
      hallucinationsBlocked: hallucinations,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Redact using ONLY rules (no LLM) - fast mode
  RedactorPipelineResult redactRulesOnly(String text) {
    if (text.trim().isEmpty) {
      return RedactorPipelineResult(
        original: text,
        redacted: text,
        rulesApplied: 0,
        llmEntitiesFound: 0,
        hallucinationsBlocked: 0,
      );
    }

    final stopwatch = Stopwatch()..start();
    final redacted = _applyHeuristics(text);
    final ruleRedactions = RegExp(r'\[[A-Z]+\]').allMatches(redacted).length;
    stopwatch.stop();

    return RedactorPipelineResult(
      original: text,
      redacted: redacted,
      rulesApplied: ruleRedactions,
      llmEntitiesFound: 0,
      hallucinationsBlocked: 0,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REVERSIBLE REDACTION (For SOAP Generation)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generates text with unique placeholders (e.g., {{PERSON_0}}) and a mapping to restore them.
  /// This allows sending the text to a cloud LLM and then re-identifying the result.
  ReversibleRedactionResult applyReversibleRedaction(
    String text,
    // Note: We need the original entities or we need to re-extract them.
    // Since this service's redact() method returns a string with [TAGS],
    // we might need to change how we call this.
    //
    // Ideally, we should have a method that returns the entities found.
    // For now, let's assume we run the extraction again or modify redact to return entities.
    //
    // Actually, the current redact() returns a string with [TAGS].
    // To support reversible redaction, we need to know WHAT was redacted.
    //
    // Let's implement a method that returns the entities found, similar to the previous service.
  ) {
    // TODO: This requires a change in architecture to return entities instead of just string.
    // For now, let's implement a simple version that finds [TAGS] in the redacted string
    // and gives them unique IDs, but that doesn't help with restoration since we lost the original value.
    //
    // We need to implement a method that returns the *matches* before replacement.
    throw UnimplementedError(
      "Need to refactor redact() to return entities first.",
    );
  }

  /// Helper to extract entities with their original values and positions
  Future<List<RedactionEntity>> extractEntities(String text) async {
    final entities = <RedactionEntity>[];

    // 1. Rules
    // We need to run the regexes and collect matches instead of replacing
    // This duplicates logic but is cleaner than refactoring everything right now

    // SSN
    for (final m in _ssnPattern.allMatches(text)) {
      entities.add(
        RedactionEntity(
          label: 'SSN',
          originalValue: m.group(0)!,
          start: m.start,
          end: m.end,
        ),
      );
    }
    // Email
    for (final m in _emailPattern.allMatches(text)) {
      entities.add(
        RedactionEntity(
          label: 'EMAIL',
          originalValue: m.group(0)!,
          start: m.start,
          end: m.end,
        ),
      );
    }
    // Phone
    for (final m in _phonePattern.allMatches(text)) {
      entities.add(
        RedactionEntity(
          label: 'PHONE',
          originalValue: m.group(0)!,
          start: m.start,
          end: m.end,
        ),
      );
    }
    // Date
    for (final m in _datePattern.allMatches(text)) {
      entities.add(
        RedactionEntity(
          label: 'DATE',
          originalValue: m.group(0)!,
          start: m.start,
          end: m.end,
        ),
      );
    }
    // Address
    for (final m in _addressPattern.allMatches(text)) {
      entities.add(
        RedactionEntity(
          label: 'ADDRESS',
          originalValue: m.group(0)!,
          start: m.start,
          end: m.end,
        ),
      );
    }
    // ZIP
    for (final m in _zipPattern.allMatches(text)) {
      // Basic check from before
      final before = m.start > 0 ? text[m.start - 1] : ' ';
      if (before == ',' || before == ' ' || before == '\n') {
        entities.add(
          RedactionEntity(
            label: 'ZIP',
            originalValue: m.group(0)!,
            start: m.start,
            end: m.end,
          ),
        );
      }
    }
    // Honorifics
    for (final m in _honorificPattern.allMatches(text)) {
      // Group 2 is the name
      final nameGroup = m.group(2);
      if (nameGroup != null) {
        // We need the absolute start of the name group
        // RegExp match gives start of the whole match.
        // We need to find where group 2 starts.
        // This is tricky with Dart regex.
        // Simple approximation: end of match - length of name
        final start = m.end - nameGroup.length;
        entities.add(
          RedactionEntity(
            label: 'PERSON',
            originalValue: nameGroup,
            start: start,
            end: m.end,
          ),
        );
      }
    }
    // Cities
    for (final city in _cities) {
      final cityPattern = RegExp(
        r'\b' + RegExp.escape(city) + r'\b',
        caseSensitive: false,
      );
      for (final m in cityPattern.allMatches(text)) {
        entities.add(
          RedactionEntity(
            label: 'LOCATION',
            originalValue: m.group(0)!,
            start: m.start,
            end: m.end,
          ),
        );
      }
    }

    // 2. LLM
    if (isReady) {
      // We need to run heuristics first to clean text for LLM?
      // Or run LLM on raw text?
      // The original pipeline ran LLM on text *after* heuristics.
      // But for extraction, we want to know original positions.
      //
      // If we run LLM on raw text, it might get confused by SSNs etc.
      // But if we run on redacted text, we lose the original values.
      //
      // Compromise: Run LLM on raw text but instruct it to ignore numbers/dates.
      // The prompt already says "Do not include Dates...".

      final llmOutput = await _runLLMExtraction(text); // Run on raw text

      // Parse output
      final lines = llmOutput
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && l.contains('|'));

      for (final line in lines) {
        final parts = line.split('|').map((p) => p.trim()).toList();
        if (parts.length < 2) continue;

        final entityVal = parts[0];
        final labelVal = parts[1].toUpperCase();

        if (entityVal.length < 2) continue;
        if (_medicalTerms.contains(entityVal.toLowerCase())) continue;

        // Find in text
        final entityPattern = RegExp(
          r'\b' + RegExp.escape(entityVal) + r'\b',
          caseSensitive: false,
        );
        for (final m in entityPattern.allMatches(text)) {
          // Check overlap with existing entities
          bool overlaps = false;
          for (final e in entities) {
            if (m.start < e.end && m.end > e.start) {
              overlaps = true;
              break;
            }
          }

          if (!overlaps) {
            String tag = 'REDACTED';
            if (labelVal.contains('PERSON') || labelVal.contains('NAME'))
              tag = 'PERSON';
            else if (labelVal.contains('ORG'))
              tag = 'ORG';
            else if (labelVal.contains('LOCATION'))
              tag = 'LOCATION';

            entities.add(
              RedactionEntity(
                label: tag,
                originalValue: m.group(0)!,
                start: m.start,
                end: m.end,
              ),
            );
          }
        }
      }
    }

    return entities;
  }

  /// Reversible Redaction Implementation
  Future<ReversibleRedactionResult> redactForCloud(String text) async {
    final entities = await extractEntities(text);

    // Sort by start desc
    entities.sort((a, b) => b.start.compareTo(a.start));

    var currentText = text;
    final mapping = <String, String>{};
    final counters = <String, int>{};

    for (final entity in entities) {
      final count = counters[entity.label] ?? 0;
      counters[entity.label] = count + 1;

      final placeholder = '{{${entity.label}_$count}}';
      mapping[placeholder] = entity.originalValue;

      if (entity.end <= currentText.length) {
        currentText =
            currentText.substring(0, entity.start) +
            placeholder +
            currentText.substring(entity.end);
      }
    }

    return ReversibleRedactionResult(
      redactedText: currentText,
      mapping: mapping,
    );
  }

  /// Restores PII in a text (e.g., SOAP note) using the provided mapping.
  String restoreRedactions(String text, Map<String, String> mapping) {
    var result = text;
    mapping.forEach((placeholder, originalValue) {
      result = result.replaceAll(placeholder, originalValue);
    });
    return result;
  }

  /// Clean up resources
  void dispose() {
    // Model managed globally, nothing to dispose here
    _medicalTerms.clear();
    _cities.clear();
  }
}

/// Simple entity class for internal use
class RedactionEntity {
  final String label;
  final String originalValue;
  final int start;
  final int end;

  RedactionEntity({
    required this.label,
    required this.originalValue,
    required this.start,
    required this.end,
  });
}

/// Result of a redaction operation with pipeline metrics
class RedactorPipelineResult {
  final String original;
  final String redacted;
  final int rulesApplied;
  final int llmEntitiesFound;
  final int hallucinationsBlocked;
  final int processingTimeMs;

  RedactorPipelineResult({
    required this.original,
    required this.redacted,
    required this.rulesApplied,
    required this.llmEntitiesFound,
    required this.hallucinationsBlocked,
    this.processingTimeMs = 0,
  });

  /// Check if any redactions were made
  bool get hasRedactions => rulesApplied > 0 || llmEntitiesFound > 0;

  /// Total redactions made
  int get totalRedactions => rulesApplied + llmEntitiesFound;

  @override
  String toString() {
    return 'RedactorPipelineResult(rules: $rulesApplied, llm: $llmEntitiesFound, '
        'blocked: $hallucinationsBlocked, time: ${processingTimeMs}ms)';
  }
}
