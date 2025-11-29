import 'package:cactus/cactus.dart';

/// Privacy-focused medical text redaction service using Extract & Locate architecture.
/// 
/// Pipeline:
/// 1. Rule Layer - Regex/heuristics redact deterministic PII (SSN, email, phone, dates, honorifics)
/// 2. LLM Layer - Small model extracts ONLY names/orgs as structured list
/// 3. Alignment Layer - Dart code locates exact strings and redacts (fixes hallucinations)
class MedicalRedactorService {
  final CactusLM _lm = CactusLM();
  bool _initialized = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // DICTIONARIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Common medical terms to KEEP (not redact)
  static final Set<String> _medicalTerms = {
    'hypertension', 'diabetes', 'asthma', 'copd', 'cancer', 'tumor',
    'carcinoma', 'melanoma', 'leukemia', 'lymphoma', 'arthritis',
    'osteoporosis', 'pneumonia', 'bronchitis', 'influenza', 'covid',
    'stroke', 'aneurysm', 'embolism', 'thrombosis', 'fibrillation',
    'tachycardia', 'bradycardia', 'murmur', 'stenosis', 'regurgitation',
    'insulin', 'metformin', 'lisinopril', 'amlodipine', 'atorvastatin',
    'omeprazole', 'levothyroxine', 'metoprolol', 'losartan', 'gabapentin',
    'prednisone', 'amoxicillin', 'azithromycin', 'ibuprofen', 'acetaminophen',
    'mri', 'ct', 'xray', 'ultrasound', 'ecg', 'ekg', 'biopsy', 'endoscopy',
    'colonoscopy', 'mammogram', 'pap', 'bloodwork', 'urinalysis',
    'diagnosis', 'prognosis', 'treatment', 'therapy', 'surgery', 'procedure',
    'prescription', 'medication', 'dosage', 'mg', 'ml', 'cc',
    'patient', 'doctor', 'nurse', 'physician', 'specialist', 'surgeon',
    'hospital', 'clinic', 'emergency', 'icu', 'or', 'ward', 'outpatient',
  };

  /// US Cities to redact (sample - expand as needed)
  static final Set<String> _cities = {
    'new york', 'los angeles', 'chicago', 'houston', 'phoenix', 'philadelphia',
    'san antonio', 'san diego', 'dallas', 'san jose', 'austin', 'jacksonville',
    'fort worth', 'columbus', 'charlotte', 'san francisco', 'indianapolis',
    'seattle', 'denver', 'boston', 'nashville', 'detroit', 'portland',
    'las vegas', 'memphis', 'louisville', 'baltimore', 'milwaukee', 'miami',
    'atlanta', 'cleveland', 'oakland', 'minneapolis', 'tampa', 'pittsburgh',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // REGEX PATTERNS
  // ═══════════════════════════════════════════════════════════════════════════

  /// SSN: 123-45-6789 or 123456789
  static final RegExp _ssnPattern = RegExp(
    r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b',
  );

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
    r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|'  // MM/DD/YYYY or MM-DD-YY
    r'\d{4}[/\-]\d{1,2}[/\-]\d{1,2}|'    // YYYY-MM-DD
    r'(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|'
    r'Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)'
    r'\s+\d{1,2}(?:st|nd|rd|th)?,?\s*\d{2,4}'  // January 1st, 2024
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
  static final RegExp _zipPattern = RegExp(
    r'\b\d{5}(?:-\d{4})?\b',
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the LLM model for entity extraction
  Future<void> initialize({
    Function(double?, String, bool)? onProgress,
  }) async {
    if (_initialized && _lm.isLoaded()) {
      print("[Redactor] Model already loaded");
          return;
    }

    print("[Redactor] Downloading model...");
    await _lm.downloadModel(
      model: "qwen3-0.6",
      downloadProcessCallback: (progress, status, isError) {
        onProgress?.call(progress, status, isError);
        if (isError) {
          print("[Redactor] Download error: $status");
        }
      },
    );

    print("[Redactor] Initializing model...");
    await _lm.initializeModel(
      params: CactusInitParams(
        model: "qwen3-0.6",
        contextSize: 1024,
      ),
    );

    _initialized = true;
    print("[Redactor] Ready");
  }

  /// Check if the service is ready
  bool get isReady => _initialized && _lm.isLoaded();

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

    const systemPrompt = '''Task: List ONLY the Person Names and Organization Names in the text.
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

    final result = await _lm.generateCompletion(
      messages: [
        ChatMessage(content: systemPrompt, role: "system"),
        ChatMessage(content: userPrompt, role: "user"),
      ],
      params: CactusCompletionParams(
        temperature: 0.0,       // Deterministic - no creativity
        topK: 5,                // Only high-probability tokens
        maxTokens: 100,         // Prevent rambling
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
    cleaned = cleaned.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    
    // Remove other common artifacts
    cleaned = cleaned.replaceAll(RegExp(r'<\|.*?\|>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
    
    // Handle "NOTHING" or empty output
    if (cleaned.trim().toUpperCase() == 'NOTHING' || cleaned.trim().isEmpty) {
      print("[Redactor] No entities extracted by LLM");
      return result;
    }

    // 2. Parse lines
    final lines = cleaned.split('\n')
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
      final entityLines = llmOutput.split('\n')
          .where((l) => l.contains('|'))
          .length;
      
      // STEP 3: Apply LLM redactions with validation
      print("[Redactor] Step 3: Alignment & validation...");
      finalText = _applyLLMRedactions(afterRules, llmOutput);
      
      // Count new redactions from LLM
      final newRedactions = RegExp(r'\[[A-Z]+\]').allMatches(finalText).length - ruleRedactions;
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

  /// Clean up resources
  void dispose() {
    _lm.unload();
    _initialized = false;
  }
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
