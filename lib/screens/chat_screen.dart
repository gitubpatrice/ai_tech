import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/model_entry.dart';
import '../models/model_family.dart';
import '../services/chat_service.dart';
import '../services/rag/rag_service.dart';
import '../services/storage/app_settings_store.dart';
import '../services/storage/encrypted_chat_store.dart';
import '../services/storage/model_registry.dart';
import 'about_screen.dart';
import 'chat_list_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';
import 'spike_screen.dart';

/// Notifier dédié au streaming token-par-token d'une bulle assistant.
///
/// Utiliser un [ValueNotifier] localisé évite de reconstruire l'AppBar, le
/// composer et toutes les bulles passées à chaque chunk. Seul le widget
/// [ValueListenableBuilder] qui écoute le notifier est rebuilt → meilleure
/// fluidité, surtout sur S9 / Redmi 9C.
class _StreamingTextNotifier extends ValueNotifier<String> {
  _StreamingTextNotifier() : super('');
}

/// Écran principal d'AI Tech : conversation multi-tour persistée et chiffrée.
///
/// Cycle de vie :
///   1. boot → charge [AppSettings] + [ModelEntry] actif + [ChatSession] chiffrée.
///   2. si pas de modèle actif → propose d'aller dans Paramètres.
///   3. si modèle actif → installe et charge avec les paramètres utilisateur.
///   4. à chaque tour terminé → sauvegarde la session chiffrée (atomique).
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _chat = ChatService.instance;
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  AppSettings _settings = const AppSettings();
  ModelEntry? _activeModel;
  ChatSession _session = ChatSession.empty();

  StreamSubscription<String>? _activeSub;
  _StreamingTextNotifier? _streamingNotifier;

  bool _booting = true;
  bool _modelLoading = false;
  bool _generating = false;
  bool _ragEnabled = false;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On sauvegarde à chaque mise en arrière-plan : si l'OS tue l'app, rien
    // n'est perdu pour les messages déjà finis (les `pending` sont filtrés).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistIfNeeded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeSub?.cancel();
    _streamingNotifier?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    // Persistance "best-effort" : dispose() est synchrone, on ne peut pas
    // await. Si l'OS tue l'app juste après pop, le save peut être tronqué.
    // La persistance FIABLE passe par didChangeAppLifecycleState(paused)
    // qui est appelé AVANT dispose et dont le save est await en pratique
    // (l'OS laisse ~5s avant de tuer après paused).
    _persistIfNeeded();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final settings = await AppSettingsStore.instance.load();

    // S'assure que l'index RAG est prêt avant tout envoi de message
    // (sinon `RagService.instance.isEmpty` peut renvoyer true à tort).
    await RagService.instance.bootstrap();

    // Charge la session active si elle existe, sinon en crée une nouvelle.
    ChatSession? loaded;
    if (settings.activeChatId != null) {
      loaded = await EncryptedChatStore.instance.load(settings.activeChatId!);
    }

    // Migration v0.3 → v0.4 : s'il existe un ancien `current.aichat` et qu'on
    // n'a rien trouvé via activeChatId, on le rapatrie vers un id moderne
    // et on supprime l'ancien fichier — sinon il resterait orphelin.
    if (loaded == null) {
      final legacy = await EncryptedChatStore.instance.load('current');
      if (legacy != null) {
        loaded = ChatSession(
          id: ChatSession.newId(),
          title: legacy.title,
          createdAt: legacy.createdAt,
          updatedAt: legacy.updatedAt,
          messages: legacy.messages,
        );
        await EncryptedChatStore.instance.save(loaded);
        await EncryptedChatStore.instance.deleteOne('current');
      }
    }

    final session = loaded ?? ChatSession.empty();

    ModelEntry? active;
    if (settings.activeModelId != null) {
      active = await ModelRegistry.instance.findById(settings.activeModelId!);
    }

    // Persiste l'id de session active (qu'elle soit nouvelle, migrée, ou
    // simplement chargée — ça normalise l'état).
    if (settings.activeChatId != session.id) {
      await AppSettingsStore.instance.save(
        settings.copyWith(activeChatId: session.id),
      );
    }

    if (!mounted) return;
    setState(() {
      _settings = settings.copyWith(activeChatId: session.id);
      _session = session;
      _activeModel = active;
    });

    if (active != null) {
      await _loadActiveModel(active, settings);
    }

    if (!mounted) return;
    setState(() => _booting = false);
  }

  Future<void> _openChatList() async {
    if (_generating) return;
    _persistIfNeeded(); // sauvegarde la session courante avant changement
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ChatListScreen(activeId: _session.id)),
    );
    if (!mounted || result == null) return;

    if (result == ChatListScreen.resultNew) {
      await _switchToSession(ChatSession.empty());
    } else if (result != _session.id) {
      final loaded = await EncryptedChatStore.instance.load(result);
      if (loaded != null) await _switchToSession(loaded);
    }
  }

  Future<void> _switchToSession(ChatSession next) async {
    // 1. Tue tout streaming en cours pour éviter qu'un onDone tardif
    //    pollue la nouvelle session (les callbacks référencent l'ancien
    //    `assistantMsg` qui n'appartient plus à `_session`).
    await _activeSub?.cancel();
    _activeSub = null;
    _streamingNotifier?.dispose();
    _streamingNotifier = null;

    // 2. Reset le contexte côté chat natif. La nouvelle session repart de
    //    zéro côté LLM ; l'historique persisté reste sur disque tel quel.
    if (_chat.isLoaded) {
      await _chat.resetConversation();
    }

    // 3. Persiste le changement.
    await AppSettingsStore.instance.save(
      _settings.copyWith(activeChatId: next.id),
    );

    if (!mounted) return;
    setState(() {
      _generating = false;
      _session = next;
      _settings = _settings.copyWith(activeChatId: next.id);
    });
  }

  Future<void> _loadActiveModel(ModelEntry entry, AppSettings settings) async {
    if (!mounted) return;
    setState(() {
      _modelLoading = true;
      _bootError = null;
    });
    try {
      await _chat.installAndLoad(
        entry.path,
        family: _familyOf(entry.family),
        maxTokens: settings.maxTokens,
        temperature: settings.temperature,
        topK: settings.topK,
      );
    } catch (e) {
      if (mounted) setState(() => _bootError = '$e');
    } finally {
      if (mounted) setState(() => _modelLoading = false);
    }
  }

  ModelFamily _familyOf(String s) {
    switch (s) {
      case 'qwen':
        return ModelFamily.qwen;
      case 'phi':
        return ModelFamily.phi;
      case 'llama':
        return ModelFamily.llama;
      case 'deepseek':
        return ModelFamily.deepseek;
      case 'gemma':
      default:
        return ModelFamily.gemma;
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _generating || !_chat.isLoaded) return;

    _inputCtrl.clear();
    // Sécurité : si un sub précédent traîne (ne devrait pas via la garde
    // _generating, mais ceinture+bretelles).
    await _activeSub?.cancel();
    if (!mounted) return;

    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    final assistantMsg = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      pending: true,
    );
    final notifier = _StreamingTextNotifier();
    _streamingNotifier?.dispose();
    _streamingNotifier = notifier;

    setState(() {
      _session.messages.add(userMsg);
      _session.messages.add(assistantMsg);
      _session.updatedAt = DateTime.now();
      _generating = true;
    });
    _scrollToBottom();

    // Si le RAG est activé, on s'assure d'abord que l'index est chargé
    // (le bootstrap peut être encore en cours si l'utilisateur a tapé très
    // vite après le démarrage). Puis on augmente la requête.
    String prompt = text;
    List<RagSource> sources = const [];
    if (_ragEnabled) {
      await RagService.instance.bootstrap();
      if (!RagService.instance.isEmpty) {
        final aug = await RagService.instance.augmentPrompt(text);
        if (aug != null) {
          prompt = aug.augmentedPrompt;
          sources = aug.sources;
        }
      }
    }
    if (sources.isNotEmpty) {
      assistantMsg.sources = sources;
    }

    final buffer = StringBuffer();
    _activeSub = _chat
        .sendMessage(prompt)
        .listen(
          (chunk) {
            if (!mounted) return;
            buffer.write(chunk);
            // Pas de setState : seul le notifier est touché → seul le widget
            // _StreamingBubble qui l'écoute est reconstruit.
            notifier.value = buffer.toString();
            _scrollToBottom();
          },
          onError: (e) {
            if (!mounted) return;
            assistantMsg.text = 'Erreur : $e';
            assistantMsg.pending = false;
            setState(() => _generating = false);
            // Cancel explicite : si une exception remonte ici, le natif peut être
            // resté en état "génération" → cancelGeneration garantit le cleanup.
            unawaited(_chat.cancelGeneration());
            _persistIfNeeded();
          },
          onDone: () {
            if (!mounted) return;
            // Au done, on transfère le buffer dans le message persistant et on
            // marque la bulle comme terminée → le ValueListenableBuilder cesse
            // d'être utilisé, on revient à un rendu statique de la bulle.
            assistantMsg.text = buffer.toString();
            assistantMsg.pending = false;
            _session.updatedAt = DateTime.now();
            setState(() => _generating = false);
            _persistIfNeeded();
          },
          cancelOnError: true,
        );
  }

  Future<void> _stop() async {
    await _chat.cancelGeneration();
    await _activeSub?.cancel();
    _activeSub = null;
    if (!mounted) return;
    setState(() {
      _generating = false;
      for (final m in _session.messages) {
        if (m.pending) {
          m.pending = false;
          if (m.text.isEmpty) m.text = '(annulé)';
        }
      }
    });
    _persistIfNeeded();
  }

  Future<void> _clearConversation() async {
    if (_generating) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer cette conversation ?'),
        content: const Text(
          'Cette discussion sera supprimée du téléphone (chiffrée, irrécupérable). '
          'Les autres conversations sont conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final oldId = _session.id;
    await _chat.resetConversation();
    await EncryptedChatStore.instance.deleteOne(oldId);

    final fresh = ChatSession.empty();
    await AppSettingsStore.instance.save(
      _settings.copyWith(activeChatId: fresh.id),
    );
    if (!mounted) return;
    setState(() {
      _session = fresh;
      _settings = _settings.copyWith(activeChatId: fresh.id);
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    // Au retour, on ré-applique les éventuels changements (modèle / params).
    if (!mounted) return;
    final settings = await AppSettingsStore.instance.load();
    ModelEntry? active;
    if (settings.activeModelId != null) {
      active = await ModelRegistry.instance.findById(settings.activeModelId!);
    }

    final modelChanged = active?.id != _activeModel?.id;
    final paramsChanged =
        settings.temperature != _settings.temperature ||
        settings.topK != _settings.topK ||
        settings.maxTokens != _settings.maxTokens;

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _activeModel = active;
    });

    if (active != null && (modelChanged || paramsChanged)) {
      await _loadActiveModel(active, settings);
    } else if (active == null) {
      await _chat.dispose();
    }
  }

  Future<void> _exportConversation() async {
    final completed = _session.messages
        .where((m) => !m.pending)
        .toList(growable: false);
    if (completed.isEmpty) return;

    // Avertissement explicite : le partage Android peut envoyer le contenu
    // vers une autre app cloud (Drive, WhatsApp, Gmail). C'est l'utilisateur
    // qui décide, mais on lui rappelle que ça casse la promesse offline.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partager cette conversation ?'),
        content: const Text(
          'Le contenu sera transmis à l\'application que vous choisissez '
          '(messages, mail, drive…). Si cette app envoie ses données sur '
          'Internet, votre conversation y sera exposée.\n\n'
          'AI Tech, lui, reste 100 % offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Partager'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final buf = StringBuffer()
      ..writeln('# Conversation AI Tech')
      ..writeln('Modèle : ${_activeModel?.displayName ?? '—'}')
      ..writeln(
        'Date : ${_session.updatedAt.toLocal().toString().split(".").first}',
      )
      ..writeln();
    for (final m in completed) {
      buf
        ..writeln(m.isUser ? '## Vous' : '## Assistant')
        ..writeln(m.text)
        ..writeln();
    }
    await Share.share(buf.toString(), subject: 'Conversation AI Tech');
  }

  void _useQuickPrompt(String text) {
    _inputCtrl
      ..text = text
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    setState(() {});
  }

  /// Au retour du SpikeScreen, le handle natif MediaPipe a été détruit par
  /// `LlmService.dispose()`. ChatService a été déchargé volontairement avant
  /// l'entrée dans Spike (cf. `SpikeScreen._pickAndLoad`). On recharge
  /// paresseusement avec les paramètres mémorisés. Robuste si l'utilisateur
  /// n'a jamais lancé Spike (ensureLoaded est no-op).
  Future<void> _reloadChatAfterSpike() async {
    if (!mounted) return;
    if (_activeModel == null) return; // rien à recharger
    if (_chat.isLoaded) return; // toujours en place (Spike n'a pas chargé)
    setState(() => _modelLoading = true);
    try {
      final ok = await _chat.ensureLoaded();
      if (!ok && mounted) {
        // ensureLoaded peut échouer si le fichier modèle a disparu
        // entre-temps. On bascule sur installAndLoad explicite.
        await _loadActiveModel(_activeModel!, _settings);
        return;
      }
    } catch (e) {
      if (mounted) setState(() => _bootError = '$e');
    } finally {
      if (mounted) setState(() => _modelLoading = false);
    }
  }

  void _persistIfNeeded() {
    final hasContent = _session.messages.any((m) => !m.pending);
    if (!hasContent) return;
    // fire-and-forget : on ne bloque pas l'UI
    EncryptedChatStore.instance.save(_session);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Conversations',
          icon: const Icon(Icons.menu),
          onPressed: _generating ? null : _openChatList,
        ),
        title: Text(_session.safeTitle, overflow: TextOverflow.ellipsis),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _generating
                ? null
                : () async {
                    _persistIfNeeded();
                    await _switchToSession(ChatSession.empty());
                  },
          ),
          IconButton(
            tooltip: _ragEnabled
                ? 'RAG actif (réponses basées sur vos documents)'
                : 'Activer le RAG (réponses basées sur vos documents)',
            icon: Icon(
              _ragEnabled ? Icons.auto_stories : Icons.auto_stories_outlined,
              color: _ragEnabled ? theme.colorScheme.primary : null,
            ),
            onPressed: _generating
                ? null
                : () => setState(() => _ragEnabled = !_ragEnabled),
          ),
          IconButton(
            tooltip: 'Supprimer cette conversation',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _generating || _session.messages.isEmpty
                ? null
                : _clearConversation,
          ),
          IconButton(
            tooltip: 'Paramètres',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            onSelected: (v) {
              switch (v) {
                case 'export':
                  _exportConversation();
                  break;
                case 'documents':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DocumentsScreen()),
                  );
                  break;
                case 'about':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                  break;
                case 'spike':
                  // SpikeScreen prend le contrôle exclusif du handle natif
                  // MediaPipe via LlmService. Au retour, on recharge
                  // paresseusement le ChatService si besoin (cf. _onReturn).
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (_) => const SpikeScreen(),
                        ),
                      )
                      .then((_) => _reloadChatAfterSpike());
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                enabled: _session.messages.any((m) => !m.pending),
                child: const ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('Exporter la conversation'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'documents',
                child: ListTile(
                  leading: Icon(Icons.article_outlined),
                  title: Text('Documents (RAG)'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'spike',
                child: ListTile(
                  leading: Icon(Icons.speed),
                  title: Text('Mesurer les performances'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('À propos'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(theme)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_booting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_activeModel == null) {
      return _NoModelState(onOpenSettings: _openSettings);
    }
    if (_modelLoading) {
      return _LoadingState(name: _activeModel!.displayName);
    }
    if (_bootError != null) {
      return _ErrorState(
        error: _bootError!,
        onRetry: () => _loadActiveModel(_activeModel!, _settings),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _session.messages.isEmpty
              ? _EmptyChatHint(
                  model: _activeModel!.displayName,
                  onQuickPrompt: _useQuickPrompt,
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: _session.messages.length,
                  itemBuilder: (_, i) {
                    final msg = _session.messages[i];
                    final isLast = i == _session.messages.length - 1;
                    return _Bubble(
                      message: msg,
                      streaming: isLast && msg.pending && _generating
                          ? _streamingNotifier
                          : null,
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        _Composer(
          controller: _inputCtrl,
          generating: _generating,
          onSend: _send,
          onStop: _stop,
        ),
      ],
    );
  }
}

class _NoModelState extends StatelessWidget {
  const _NoModelState({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_outlined, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Aucun modèle actif',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Allez dans les paramètres pour ajouter un modèle '
              '(.task ou .litertlm) et le sélectionner.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Ouvrir les paramètres'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Chargement de $name…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              '10–20 s en moyenne, selon la taille du modèle.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Échec du chargement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatHint extends StatelessWidget {
  const _EmptyChatHint({required this.model, required this.onQuickPrompt});
  final String model;
  final ValueChanged<String> onQuickPrompt;

  static const _prompts = <_QuickPrompt>[
    _QuickPrompt(
      icon: Icons.edit_outlined,
      label: 'Améliorer un texte',
      prompt:
          'Améliore ce texte (orthographe, style, fluidité) en gardant '
          'le sens d\'origine :\n\n',
    ),
    _QuickPrompt(
      icon: Icons.translate,
      label: 'Traduire',
      prompt: 'Traduis ce texte en français en gardant le ton :\n\n',
    ),
    _QuickPrompt(
      icon: Icons.summarize_outlined,
      label: 'Résumer',
      prompt: 'Résume ce texte en 5 points clés :\n\n',
    ),
    _QuickPrompt(
      icon: Icons.lightbulb_outline,
      label: 'Expliquer simplement',
      prompt: 'Explique-moi simplement, comme à un enfant de 12 ans :\n\n',
    ),
    _QuickPrompt(
      icon: Icons.refresh,
      label: 'Reformuler',
      prompt: 'Reformule ce texte de façon plus claire et plus naturelle :\n\n',
    ),
    _QuickPrompt(
      icon: Icons.psychology_outlined,
      label: 'Brainstormer',
      prompt: 'Donne-moi 10 idées originales sur le thème suivant :\n\n',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.smart_toy_outlined,
              size: 36,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Commencez la conversation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Modèle : $model',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.bolt, size: 16, color: cs.outline),
              const SizedBox(width: 6),
              Text(
                'Démarrages rapides',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.outline),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _prompts
              .map(
                (p) => ActionChip(
                  avatar: Icon(p.icon, size: 18, color: cs.primary),
                  label: Text(p.label),
                  onPressed: () => onQuickPrompt(p.prompt),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _QuickPrompt {
  const _QuickPrompt({
    required this.icon,
    required this.label,
    required this.prompt,
  });
  final IconData icon;
  final String label;
  final String prompt;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.streaming});

  final ChatMessage message;

  /// Si non-null, le texte affiché est piloté par ce notifier (streaming en
  /// cours). Sinon on affiche `message.text` statique.
  final _StreamingTextNotifier? streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;
    final bg = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final stream = streaming;
    // Pendant le streaming : SelectableText (très peu coûteux à rebuild
    // chaque token). À la fin de la génération (`stream == null`) on bascule
    // vers `MarkdownBody` qui parse une seule fois — listes, gras, code,
    // citations rendus proprement. Évite de payer le coût du parser markdown
    // 200 fois pour une réponse de 200 tokens.
    final Widget body = stream != null
        ? ValueListenableBuilder<String>(
            valueListenable: stream,
            builder: (_, value, _) => SelectableText(
              value.isEmpty ? '…' : value,
              style: TextStyle(color: fg, height: 1.35),
            ),
          )
        : _renderBody(
            context,
            message.text.isEmpty && message.pending ? '…' : message.text,
            fg,
            isUser: isUser,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: message.pending
                  ? null
                  : () => _copy(context, message.text),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.82,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    body,
                    if (message.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: fg.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    if (!message.pending && message.sources.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _SourcesRow(sources: message.sources, fg: fg),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderBody(
    BuildContext context,
    String text,
    Color fg, {
    required bool isUser,
  }) {
    if (isUser) {
      // Côté user : on affiche brut, sélectionnable.
      return SelectableText(text, style: TextStyle(color: fg, height: 1.35));
    }
    // Assistant : Markdown (listes, gras, italique, code, citations…).
    final theme = Theme.of(context);
    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: TextStyle(color: fg, height: 1.35, fontSize: 14),
        h1: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700),
        h2: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w700),
        h3: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w700),
        listBullet: TextStyle(color: fg, fontSize: 14),
        strong: TextStyle(color: fg, fontWeight: FontWeight.w700),
        em: TextStyle(color: fg, fontStyle: FontStyle.italic),
        blockquote: TextStyle(
          color: fg.withValues(alpha: 0.85),
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          color: fg,
          fontFamily: 'monospace',
          fontSize: 13,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(10),
      ),
      onTapLink: (_, href, _) {
        // Sécurité : on ne lance jamais un lien depuis le chat (cohérent
        // avec la promesse "100 % offline" — pas d'app de réception
        // automatique). Le user peut copier-coller s'il veut consulter.
      },
    );
  }

  void _copy(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copié'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  const _SourcesRow({required this.sources, required this.fg});
  final List<RagSource> sources;
  final Color fg;

  void _show(BuildContext context, RagSource s) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Source [${s.index}] · ${s.title}'),
        content: SingleChildScrollView(child: SelectableText(s.excerpt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: sources
          .map(
            (s) => InkWell(
              onTap: () => _show(context, s),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '[${s.index}] ${s.title}',
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.generating,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: generating ? 'Génération…' : 'Votre message',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) {
                if (!generating) onSend();
              },
            ),
          ),
          const SizedBox(width: 8),
          if (generating)
            FilledButton.tonal(
              onPressed: onStop,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: const Icon(Icons.stop),
            )
          else
            FilledButton(
              onPressed: onSend,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: const Icon(Icons.send),
            ),
        ],
      ),
    );
  }
}
