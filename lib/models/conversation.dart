/// Conversation model for managing patient sessions
class Conversation {
  final String id;
  final String patientName;
  final String context;
  final DateTime createdAt;
  String transcription;
  String? redactedText;
  bool isRecording;

  Conversation({
    required this.id,
    required this.patientName,
    required this.context,
    required this.createdAt,
    this.transcription = '',
    this.redactedText,
    this.isRecording = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'patientName': patientName,
    'context': context,
    'createdAt': createdAt.toIso8601String(),
    'transcription': transcription,
    'redactedText': redactedText,
    'isRecording': isRecording,
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'],
    patientName: json['patientName'],
    context: json['context'],
    createdAt: DateTime.parse(json['createdAt']),
    transcription: json['transcription'] ?? '',
    redactedText: json['redactedText'],
    isRecording: json['isRecording'] ?? false,
  );
}
