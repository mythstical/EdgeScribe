import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/secure_file_storage_service.dart';

/// Provider for managing conversations
class ConversationProvider with ChangeNotifier {
  List<Conversation> _conversations = [];
  final SecureFileStorageService _storage = SecureFileStorageService();

  List<Conversation> get conversations => _conversations;

  Conversation? get activeConversation =>
      _conversations.where((c) => c.isRecording).firstOrNull;

  Future<void> loadConversations() async {
    final String? conversationsJson = await _storage.read();

    if (conversationsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(conversationsJson);
        _conversations = decoded.map((e) => Conversation.fromJson(e)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error decoding conversations: $e');
      }
    }
  }

  Future<void> _saveConversations() async {
    final String encoded = jsonEncode(
      _conversations.map((e) => e.toJson()).toList(),
    );
    await _storage.write(encoded);
  }

  Future<Conversation> createConversation({
    required String patientName,
    required String context,
  }) async {
    final conversation = Conversation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientName: patientName,
      context: context,
      createdAt: DateTime.now(),
    );

    _conversations.insert(0, conversation);
    await _saveConversations();
    notifyListeners();
    return conversation;
  }

  Future<void> updateConversation(Conversation conversation) async {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = conversation;
      await _saveConversations();
      notifyListeners();
    }
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);
    await _saveConversations();
    notifyListeners();
  }

  Future<void> setRecordingStatus(String id, bool isRecording) async {
    for (var conv in _conversations) {
      conv.isRecording = conv.id == id && isRecording;
    }
    await _saveConversations();
    notifyListeners();
  }
}
