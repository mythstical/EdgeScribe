/// Represents a single redacted entity with metadata for UI highlighting
class RedactionEntity {
  final String label; // e.g. "PATIENT", "PHONE", "DR", "EMAIL"
  final String originalValue; // e.g. "John Smith", "555-1234"
  final int start; // Character position in original text
  final int end; // Character position in original text

  RedactionEntity({
    required this.label,
    required this.originalValue,
    required this.start,
    required this.end,
  });

  @override
  String toString() => 'RedactionEntity($label: "$originalValue" at $start-$end)';
}

/// Structured result from the redaction pipeline
class RedactionResult {
  final String originalText; // Raw input
  final String redactedText; // Clean text with [TAGS] for cloud upload
  final List<RedactionEntity> entities; // All detected PII with positions

  RedactionResult({
    required this.originalText,
    required this.redactedText,
    required this.entities,
  });

  /// Quick check if any PII was found
  bool get hasPII => entities.isNotEmpty;

  /// Count of entities by type
  Map<String, int> get entityCounts {
    final counts = <String, int>{};
    for (var entity in entities) {
      counts[entity.label] = (counts[entity.label] ?? 0) + 1;
    }
    return counts;
  }

  @override
  String toString() {
    return 'RedactionResult(entities: ${entities.length}, hasPII: $hasPII)';
  }
}
