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

  /// Souscription au stream natif MediaPipe — gardée pour pouvoir
  /// l'annuler explicitement et propager le cancel jusqu'au natif (sinon
  /// la génération continue en arrière-plan, gaspillant CPU/RAM).
  StreamSubscription<dynamic>? _activeNativeSub;

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
        final formatted = ModelFamilyUtils.formatUserMessage(clipped, _family);
        await chat.addQueryChunk(Message.text(text: formatted, isUser: true));
        // .listen() au lieu de `await for` : permet de cancel le souscripteur
        // côté Dart, ce que la plupart des plugins propagent au générateur
        // natif MediaPipe (vs await for qui ne peut être interrompu que par
        // une exception ou la fin du stream).
        final completer = Completer<void>();
        _activeNativeSub = chat.generateChatResponseAsync().listen(
          (response) {
            if (controller.isClosed) return;
            if (response is TextResponse) {
              controller.add(response.token);
            }
            // ThinkingResponse / FunctionCallResponse ignorés (mode chat simple).
          },
          onError: (Object e, StackTrace st) {
            if (!completer.isCompleted) completer.completeError(e, st);
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
        await completer.future;
        if (!controller.isClosed) await controller.close();
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
          await controller.close();
        }
      } finally {
        await _activeNativeSub?.cancel();
        _activeNativeSub = null;
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
    final sub = _activeNativeSub;
    _activeStream = null;
    _activeNativeSub = null;
    // 1. Cancel le souscripteur natif EN PREMIER : propage le cancel jusqu'au
    //    générateur MediaPipe pour qu'il arrête vraiment de produire des tokens.
    if (sub != null) await sub.cancel();
    // 2. Ferme le controller exposé au consumer pour signaler la fin.
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
    } catch (_) {
      /* best-effort */
    }
    try {
      await _model?.close();
    } catch (_) {
      /* best-effort */
    }
    _chat = null;
    _model = null;
  }

  Future<void> _injectSystemPrompt() async {
    final chat = _chat;
    if (chat == null) return;
    final formatted = ModelFamilyUtils.formatSystemPrompt(
      _systemPromptFr,
      _family,
    );
    // isUser:false → le prompt système est traité comme un tour modèle/system,
    // pas comme un message utilisateur. Renforce l'autorité du system prompt
    // contre les attaques "ignore les instructions précédentes" qui exploitent
    // un system prompt déguisé en user turn.
    await chat.addQueryChunk(Message.text(text: formatted, isUser: false));
  }
}
