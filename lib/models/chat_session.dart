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

  /// Sentinelle non-localisée pour un titre par défaut. Stockée telle quelle
  /// sur disque ; l'affichage utilise `safeTitle` qui dérive du premier
  /// message ou retombe sur ce sentinel. Préfixe ASCII improbable dans un
  /// vrai titre utilisateur, donc safe pour comparaison sans collision.
  static const String defaultTitleSentinel = '__ai_tech_default_title__';

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
        .map(
          (m) => {
            'text': m.text,
            'isUser': m.isUser,
            'timestamp': m.timestamp.toIso8601String(),
          },
        )
        .toList(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? defaultTitleSentinel,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (m) => ChatMessage(
              text: m['text'] as String,
              isUser: m['isUser'] as bool,
              timestamp: DateTime.parse(m['timestamp'] as String),
            ),
          )
          .toList(),
    );
  }

  factory ChatSession.empty({String? id}) {
    final now = DateTime.now();
    return ChatSession(
      id: id ?? newId(),
      title: defaultTitleSentinel,
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }

  /// Vrai si le titre est encore le sentinel par défaut (jamais personnalisé
  /// ni dérivé d'un message). Permet aux écrans de localiser l'affichage.
  bool get isDefaultTitle =>
      title.isEmpty || title == defaultTitleSentinel ||
      // Compatibilité descendante : sessions persistées avant l'introduction
      // du sentinel non-localisé peuvent contenir l'ancien défaut FR.
      title == 'Nouvelle conversation' || title == 'Conversation';

  /// Renvoie un titre court dérivé du premier message utilisateur, ou
  /// `title` si déjà personnalisé. Lève si le titre est par défaut et
  /// qu'aucun message utilisateur n'existe — `safeTitle` est la variante
  /// non-throw pour l'affichage.
  String get displayTitle {
    if (!isDefaultTitle) return title;
    final firstUser = messages.firstWhere(
      (m) => m.isUser && m.text.trim().isNotEmpty,
      orElse: () => throw StateError('no user message'),
    );
    final preview = firstUser.text.trim().split('\n').first;
    return preview.length > 60 ? '${preview.substring(0, 60)}…' : preview;
  }

  /// Variante sécurisée : ne lève jamais, retourne le sentinel par défaut
  /// si aucun message utilisateur n'est trouvé. L'écran consommateur
  /// remplace le sentinel par sa traduction (ARB `chatTitleDefault`).
  String get safeTitle {
    try {
      return displayTitle;
    } catch (_) {
      return defaultTitleSentinel;
    }
  }
}
