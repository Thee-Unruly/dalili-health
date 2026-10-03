import 'chat_message.dart';

/// Represents a distinct conversation session in Dalili.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? activeDocumentId;
  final String? activeDocumentName;
  final List<ChatMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.activeDocumentId,
    this.activeDocumentName,
    required this.messages,
  });

  /// Returns the last non-empty user or AI message preview text.
  String get previewText {
    for (int i = messages.length - 1; i >= 0; i--) {
      final text = messages[i].content.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return 'Empty conversation';
  }

  /// Returns total count of user messages in this session.
  int get userMessageCount =>
      messages.where((m) => m.role == MessageRole.user).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'activeDocumentId': activeDocumentId,
      'activeDocumentName': activeDocumentName,
      'messages': messages.map((m) => {
        'id': m.id,
        'role': m.role == MessageRole.user ? 'user' : 'ai',
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
        if (m.generationSeconds != null)
          'generationSeconds': m.generationSeconds,
      }).toList(),
    };
  }

  factory ChatSession.fromMap(Map<dynamic, dynamic> map) {
    final rawMessages = map['messages'] as List? ?? [];
    return ChatSession(
      id: map['id']?.toString() ?? 'session_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title']?.toString() ?? 'Socratic Tutor',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      activeDocumentId: map['activeDocumentId']?.toString(),
      activeDocumentName: map['activeDocumentName']?.toString(),
      messages: rawMessages.whereType<Map>().map((e) {
        final m = Map<dynamic, dynamic>.from(e);
        return ChatMessage(
          id: m['id']?.toString() ?? '',
          role: m['role'] == 'user' ? MessageRole.user : MessageRole.ai,
          content: m['content']?.toString() ?? '',
          timestamp: m['timestamp'] != null
              ? DateTime.tryParse(m['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now(),
          generationSeconds: m['generationSeconds'] != null
              ? (m['generationSeconds'] as num).toDouble()
              : null,
        );
      }).toList(),
    );
  }

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    String? activeDocumentId,
    String? activeDocumentName,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeDocumentId: activeDocumentId ?? this.activeDocumentId,
      activeDocumentName: activeDocumentName ?? this.activeDocumentName,
      messages: messages ?? this.messages,
    );
  }
}
