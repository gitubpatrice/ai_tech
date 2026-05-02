import 'chat_message.dart';

/// Une conversation persistée (chiffrée sur disque).
///
/// Pour la v0.3, on ne gère qu'une seule conversation active à la fois (id
/// `current`) — la liste multi-conversations sera ajoutée plus tard si besoin.
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'messages': messages
            .where((m) => !m.pending) // n'archive que les messages terminés
            .map((m) => {
                  'text': m.text,
                  'isUser': m.isUser,
                  'timestamp': m.timestamp.toIso8601String(),
                })
            .toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Conversation',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((m) => ChatMessage(
                text: m['text'] as String,
                isUser: m['isUser'] as bool,
                timestamp: DateTime.parse(m['timestamp'] as String),
              ))
          .toList(),
    );
  }

  factory ChatSession.empty({String id = 'current'}) {
    final now = DateTime.now();
    return ChatSession(
      id: id,
      title: 'Conversation',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }
}
