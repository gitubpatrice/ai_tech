import 'dart:async';
import 'dart:io';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/model_family.dart';
import '../models/model_limits.dart';

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

  /// Mutex défensif : si l'UI déclenche deux `sendMessage` quasi-simultanés
  /// (double-tap avant que `_generating=true` ne soit setState côté ChatScreen),
  /// la 2e doit échouer proprement plutôt que crasher MediaPipe (qui ne tolère
  /// pas deux générations sur la même session).
  Completer<void>? _activeGen;

  /// Souscription au stream natif MediaPipe — gardée pour pouvoir
  /// l'annuler explicitement et propager le cancel jusqu'au natif (sinon
  /// la génération continue en arrière-plan, gaspillant CPU/RAM).
  StreamSubscription<dynamic>? _activeNativeSub;

  /// Paramètres du dernier `installAndLoad` réussi — utilisés par
  /// [ensureLoaded] pour reload paresseux après un [unloadModel] (cas où
  /// l'utilisateur revient de SpikeScreen et le handle natif a été libéré).
  String? _lastModelPath;
  ModelFamily _lastFamily = ModelFamily.gemma;
  int _lastMaxTokens = 1024;
  double _lastTemperature = 0.7;
  int _lastTopK = 40;
  PreferredBackend? _lastBackend;

  bool get isLoaded => _chat != null;
  ModelFamily get family => _family;

  /// True si on a déjà chargé un modèle au moins une fois (les paramètres
  /// sont mémorisés et [ensureLoaded] peut le re-charger).
  bool get canReload => _lastModelPath != null;

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
    if (await file.length() < ModelLimits.minModelBytes) {
      throw ArgumentError('Fichier modèle trop petit, fichier suspect.');
    }

    _family = family == ModelFamily.auto
        ? ModelFamilyUtils.detectFamily(path)
        : family;

    // Mémorise les paramètres pour permettre à [ensureLoaded] de rebuild la
    // session après un [unloadModel] (cession du handle natif au LlmService
    // du SpikeScreen, par ex.).
    _lastModelPath = path;
    _lastFamily = _family;
    _lastMaxTokens = maxTokens;
    _lastTemperature = temperature;
    _lastTopK = topK;
    _lastBackend = backend;

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
    if (_activeGen != null) {
      return Stream.error(StateError('Génération déjà en cours.'));
    }
    final clipped = userText.length > maxUserPromptChars
        ? userText.substring(0, maxUserPromptChars)
        : userText;
    final controller = StreamController<String>();
    _activeStream = controller;
    final genCompleter = Completer<void>();
    _activeGen = genCompleter;

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
        if (identical(_activeGen, genCompleter)) {
          _activeGen = null;
        }
        if (!genCompleter.isCompleted) genCompleter.complete();
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

  /// Libère le handle natif MediaPipe (model + chat) tout en gardant en
  /// mémoire les paramètres du dernier `installAndLoad` afin que la prochaine
  /// utilisation puisse recharger via [ensureLoaded].
  ///
  /// Utilisé pour éviter le conflit de session quand `LlmService` (SpikeScreen)
  /// veut prendre le contrôle du modèle natif global (`getActiveModel`). Un
  /// seul propriétaire du handle natif à la fois — sinon dispose en cascade
  /// laisse l'autre service avec un handle fermé.
  ///
  /// Idempotent : ne fait rien si rien n'est chargé.
  Future<void> unloadModel() async {
    if (_chat == null && _model == null) return;
    await _disposeInternal();
  }

  /// Recharge le modèle si on l'a déjà chargé une fois mais qu'il a depuis
  /// été libéré (typiquement par [unloadModel] avant une session SpikeScreen).
  ///
  /// No-op si déjà chargé. Renvoie `false` si aucun modèle n'a jamais été
  /// chargé (ce sera à l'appelant — typiquement ChatScreen — d'appeler
  /// [installAndLoad] avec un chemin explicite).
  Future<bool> ensureLoaded() async {
    if (_chat != null) return true;
    final path = _lastModelPath;
    if (path == null) return false;
    // Vérifie que le fichier existe encore — l'utilisateur peut l'avoir
    // supprimé entre temps.
    if (!await File(path).exists()) {
      _lastModelPath = null;
      return false;
    }
    await installAndLoad(
      path,
      family: _lastFamily,
      maxTokens: _lastMaxTokens,
      temperature: _lastTemperature,
      topK: _lastTopK,
      backend: _lastBackend,
    );
    return _chat != null;
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
