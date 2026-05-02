import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/model_family.dart';

/// Service de chat multi-tour basé sur `InferenceChat` de flutter_gemma 0.14.
///
/// Gère :
///   - chargement du modèle (`installAndLoad`) — supporte `.task` et `.litertlm`
///   - injection unique d'un **prompt système FR** au début de la session
///   - génération en streaming (`sendMessage` retourne un `Stream<String>`)
///   - annulation propre via `cancelGeneration`
///   - reset complet via `resetConversation`
///
/// Le prompt système n'est PAS modifiable par l'utilisateur (codé en dur)
/// pour limiter les tentatives de prompt injection depuis le champ de chat.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const String _systemPromptFr =
      'Tu es un assistant français utile, sobre et précis. '
      'Tu réponds toujours en français correct, avec tous les accents '
      '(à, â, é, è, ê, ë, î, ï, ô, ù, û, ü, ÿ, ç) et la ponctuation française. '
      'Tu réponds en moins de 200 mots sauf demande contraire. '
      'Tu reconnais honnêtement ce que tu ignores.';

  /// Limite défensive sur la longueur du prompt utilisateur (caractères).
  /// Au-delà, on tronque proprement plutôt que de submerger le contexte.
  static const int maxUserPromptChars = 8000;

  InferenceModel? _model;
  InferenceChat? _chat;
  ModelFamily _family = ModelFamily.gemma;

  StreamController<String>? _activeStream;

  bool get isLoaded => _chat != null;
  ModelFamily get family => _family;

  Future<void> installAndLoad(
    String path, {
    ModelFamily family = ModelFamily.auto,
    int maxTokens = 1024,
    double temperature = 0.7,
    int topK = 40,
    PreferredBackend? backend,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw ArgumentError('Fichier modèle introuvable : $path');
    }
    if (await file.length() < 50 * 1024 * 1024) {
      throw ArgumentError('Fichier modèle trop petit, fichier suspect.');
    }

    _family = family == ModelFamily.auto
        ? ModelFamilyUtils.detectFamily(path)
        : family;

    await _disposeInternal();

    await FlutterGemma.installModel(
      modelType: ModelFamilyUtils.modelTypeFor(_family),
      fileType: ModelFamilyUtils.detectFileType(path),
    ).fromFile(path).install();

    _model = await FlutterGemma.getActiveModel(
      maxTokens: maxTokens,
      preferredBackend: backend,
      supportImage: false,
    );

    _chat = await _model!.createChat(
      temperature: temperature,
      topK: topK,
      tokenBuffer: 256,
      supportImage: false,
    );

    await _injectSystemPrompt();
  }

  /// Envoie un message utilisateur et streame la réponse de l'assistant.
  Stream<String> sendMessage(String userText) {
    final chat = _chat;
    if (chat == null) {
      return Stream.error(StateError('Modèle non chargé.'));
    }
    final clipped = userText.length > maxUserPromptChars
        ? userText.substring(0, maxUserPromptChars)
        : userText;
    final controller = StreamController<String>();
    _activeStream = controller;

    Future<void> run() async {
      try {
        final formatted =
            ModelFamilyUtils.formatUserMessage(clipped, _family);
        await chat.addQueryChunk(Message.text(text: formatted, isUser: true));
        await for (final response in chat.generateChatResponseAsync()) {
          if (controller.isClosed) return;
          if (response is TextResponse) {
            controller.add(response.token);
          }
          // ThinkingResponse / FunctionCallResponse ignorés (mode chat simple).
        }
        if (!controller.isClosed) await controller.close();
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
      } finally {
        if (identical(_activeStream, controller)) {
          _activeStream = null;
        }
      }
    }

    run();
    return controller.stream;
  }

  /// Interrompt le stream en cours sans détruire la session.
  Future<void> cancelGeneration() async {
    final ctrl = _activeStream;
    _activeStream = null;
    if (ctrl != null && !ctrl.isClosed) {
      await ctrl.close();
    }
  }

  /// Vide l'historique et recrée une session vierge avec le prompt système.
  Future<void> resetConversation() async {
    final chat = _chat;
    if (chat == null) return;
    await cancelGeneration();
    await chat.clearHistory();
    await _injectSystemPrompt();
  }

  Future<void> dispose() async {
    await _disposeInternal();
  }

  Future<void> _disposeInternal() async {
    await cancelGeneration();
    try {
      await _chat?.session.close();
    } catch (_) {/* best-effort */}
    try {
      await _model?.close();
    } catch (_) {/* best-effort */}
    _chat = null;
    _model = null;
  }

  Future<void> _injectSystemPrompt() async {
    final chat = _chat;
    if (chat == null) return;
    final formatted =
        ModelFamilyUtils.formatSystemPrompt(_systemPromptFr, _family);
    await chat.addQueryChunk(Message.text(text: formatted, isUser: true));
  }
}
