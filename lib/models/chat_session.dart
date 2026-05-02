import 'dart:math' as math;

import 'chat_message.dart';

/// Une conversation persistée (chiffrée sur disque).
///
/// Chaque conversation a un identifiant unique qui sert de nom de fichier
/// (`<id>.aichat`) et d'AAD pour le chiffrement AES-GCM — un fichier renommé
/// devient illisible.
class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  /// Génère un identifiant compact (timestamp + 4 hex aléatoires) pour
  /// nommer un nouveau fichier `.aichat`. Format : `c-1715812345-a1b2`.
  static String newId() {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rand = math.Random.secure().nextInt(0xFFFF).toRadixString(16);
    return 'c-$ts-${rand.padLeft(4, '0')}';
  }

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

  factory ChatSession.empty({String? id}) {
    final now = DateTime.now();
    return ChatSession(
      id: id ?? newId(),
      title: 'Nouvelle conversation',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }

  /// Renvoie un titre court dérivé du premier message utilisateur, ou
  /// `title` si déjà personnalisé. Utilisé pour l'affichage dans la liste.
  String get displayTitle {
    if (title.isNotEmpty && title != 'Nouvelle conversation') return title;
    final firstUser = messages.firstWhere(
      (m) => m.isUser && m.text.trim().isNotEmpty,
      orElse: () => throw StateError('no user message'),
    );
    final preview = firstUser.text.trim().split('\n').first;
    return preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;
  }

  /// Variante sécurisée : ne lève jamais, retourne 'Nouvelle conversation'
  /// si aucun message utilisateur.
  String get safeTitle {
    try {
      return displayTitle;
    } catch (_) {
      return 'Nouvelle conversation';
    }
  }
}
