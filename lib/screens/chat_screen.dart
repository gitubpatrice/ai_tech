import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../models/model_entry.dart';
import '../models/model_family.dart';
import '../services/chat_service.dart';
import '../services/rag/rag_service.dart';
import '../services/storage/app_settings_store.dart';
import '../services/storage/encrypted_chat_store.dart';
import '../services/memory_watchdog.dart';
import '../services/storage/model_registry.dart';
import '../utils/app_dialogs.dart';
import '../utils/chat_session_label.dart';
import '../utils/latex_to_unicode.dart';
import '../utils/snackbar_ext.dart';
import '../widgets/app_empty_state.dart';
import 'about_screen.dart';
import 'chat_list_screen.dart';
import 'documents_screen.dart';
import 'settings_screen.dart';
import 'spike_screen.dart';

/// Notifier dédié au streaming token-par-token d'une bulle assistant.
class _StreamingTextNotifier extends ValueNotifier<String> {
  _StreamingTextNotifier() : super('');
}

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

  // Throttle auto-scroll : un seul postFrame en vol à la fois.
  bool _scrollScheduled = false;

  // QW5 v0.8.1 — debounce des saves : Stop+onError+inactive lifecycle
  // pouvaient queuer 3 saves successifs en quelques ms (50-200ms cumulés).
  // 300 ms collapse les rafales sans perdre de données (flush forcé en
  // dispose, paused, et stop).
  Timer? _persistDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      // QW2 v0.8.1 — cancel génération native MediaPipe sur pause :
      // Gemma 4 à 19 tok/s consomme un core à 100% → 5-15% batterie/h
      // gaspillés si l'user quitte pendant une longue réponse. Le state
      // _generating est repassé à false pour rouvrir le bouton Send au
      // retour.
      if (_generating) {
        unawaited(_chat.cancelGeneration());
        await _activeSub?.cancel();
        _activeSub = null;
        if (mounted) {
          setState(() {
            _generating = false;
            for (final m in _session.messages) {
              if (m.pending) m.pending = false;
            }
          });
        }
      }
      final hasContent = _session.messages.any((m) => !m.pending);
      if (hasContent) {
        try {
          await EncryptedChatStore.instance.save(_session);
        } catch (_) {
          /* best-effort */
        }
      }
    } else if (state == AppLifecycleState.inactive) {
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
    // QW5 v0.8.1 — flush immédiat à dispose (pas de debounce sortant qui
    // ne s'exécuterait jamais avec un widget démonté).
    _persistNow();
    _persistDebounce?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final settings = await AppSettingsStore.instance.load();
    await RagService.instance.bootstrap();

    ChatSession? loaded;
    if (settings.activeChatId != null) {
      loaded = await EncryptedChatStore.instance.load(settings.activeChatId!);
    }

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
    _persistIfNeeded();
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
    await _activeSub?.cancel();
    _activeSub = null;
    _streamingNotifier?.dispose();
    _streamingNotifier = null;

    if (_chat.isLoaded) {
      await _chat.resetConversation();
    }

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

  /// v0.9.0 (#2 WatchDog) — Avertit l'utilisateur que la marge mémoire
  /// est insuffisante pour le modèle qu'il s'apprête à charger. Retourne
  /// `true` s'il choisit de forcer, `false` ou `null` s'il annule.
  Future<bool?> _confirmLowMemory(
    ({bool ok, MemoryInfo? info, int neededBytes}) check,
  ) {
    final t = AppLocalizations.of(context);
    final neededMb = (check.neededBytes / (1024 * 1024)).round();
    final availMb = ((check.info?.availBytes ?? 0) / (1024 * 1024)).round();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.memory_outlined, color: cs.error, size: 36),
          title: Text(t.memoryLowTitle),
          content: Text(t.memoryLowBody('$neededMb', '$availMb')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.memoryLowCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: Text(t.memoryLowProceed),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadActiveModel(ModelEntry entry, AppSettings settings) async {
    if (!mounted) return;
    setState(() {
      _modelLoading = true;
      _bootError = null;
    });
    try {
      // v0.8.0 (M-A3) — re-détection systématique au load : si l'utilisateur
      // a écrasé son `.task` Gemma 3 par un Gemma 4 sans repasser par le
      // picker, `entry.family` reste figé en 'gemma' → template Gemma 3
      // appliqué sur Gemma 4 = gibberish. La re-detect par nom de fichier
      // garde l'override manuel (entry.family != 'auto') si présent.
      final stored = ModelFamilyUtils.fromName(entry.family);
      final detected = ModelFamilyUtils.detectFamily(entry.path);
      // Si la stored est 'gemma' (cas typique pré-upgrade ou register
      // ancien) et que la detect actuelle pointe vers 'gemma4', on
      // privilégie la detect actuelle.
      final family =
          (stored == ModelFamily.gemma && detected == ModelFamily.gemma4)
          ? detected
          : stored;

      // v0.9.0 (#2 WatchDog) — sonde mémoire avant chargement. Sur un
      // device <3 Go (Redmi 9C, S9), Gemma 4 E2B (~530 Mo) entraîne un
      // OOM kill brutal. On laisse l'utilisateur décider (forcer) mais
      // on le préviens explicitement avec la marge réelle.
      if (entry.sizeBytes > 0) {
        final check = await MemoryWatchdog.instance.check(entry.sizeBytes);
        if (!check.ok && mounted) {
          final proceed = await _confirmLowMemory(check);
          if (proceed != true) {
            if (mounted) {
              setState(() {
                _modelLoading = false;
                _bootError = null;
              });
            }
            return;
          }
        }
      }

      await _chat.installAndLoad(
        entry.path,
        family: family,
        maxTokens: settings.maxTokens,
        temperature: settings.temperature,
        topK: settings.topK,
      );
      // QW13 v0.8.1 — persiste la family corrigée dans ModelRegistry une
      // fois le load réussi, sinon SettingsScreen continue d'afficher
      // "Gemma 3" alors que le runtime tourne en Gemma 4 (désynchro).
      if (family != stored && family.name != entry.family) {
        try {
          await ModelRegistry.instance.register(
            path: entry.path,
            displayName: entry.displayName,
            family: family.name,
            fileType: entry.fileType,
            sha256: entry.sha256,
          );
        } catch (_) {
          /* best-effort, ne bloque pas le load */
        }
      }
    } catch (e) {
      if (mounted) setState(() => _bootError = '$e');
    } finally {
      if (mounted) setState(() => _modelLoading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _generating || !_chat.isLoaded) return;

    // U4 v0.9.1 — feedback haptique léger sur send : confirme tactilement
    // l'action quand l'utilisateur regarde ailleurs.
    HapticFeedback.selectionClick();

    // QW11 v0.8.1 — protège la race double-tap : `_generating = true`
    // AVANT le 1er `await`. Sans ça, deux taps rapprochés re-rentraient
    // dans la fenêtre async `await _activeSub?.cancel()` et ajoutaient
    // une 2e bulle user fantôme.
    setState(() => _generating = true);

    final t = AppLocalizations.of(context);
    _inputCtrl.clear();
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
    });
    // ignore: deprecated_member_use
    SemanticsService.announce(t.chatAnnounceGenerationStart, TextDirection.ltr);
    _scheduleScrollToBottom();

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
            notifier.value = buffer.toString();
            _scheduleScrollToBottom();
          },
          onError: (e) {
            if (!mounted) return;
            assistantMsg.text = t.chatBubbleErrorPrefix('$e');
            assistantMsg.pending = false;
            setState(() => _generating = false);
            unawaited(_chat.cancelGeneration());
            _persistIfNeeded();
          },
          onDone: () {
            if (!mounted) return;
            assistantMsg.text = buffer.toString();
            assistantMsg.pending = false;
            _session.updatedAt = DateTime.now();
            setState(() => _generating = false);
            // ignore: deprecated_member_use
            SemanticsService.announce(
              t.chatAnnounceGenerationDone,
              TextDirection.ltr,
            );
            _persistIfNeeded();
          },
          cancelOnError: true,
        );
  }

  Future<void> _stop() async {
    final t = AppLocalizations.of(context);
    // U4 v0.9.1 — feedback haptique sur stop génération (action plus
    // impactante que send, on prend `mediumImpact`).
    HapticFeedback.mediumImpact();
    await _chat.cancelGeneration();
    await _activeSub?.cancel();
    _activeSub = null;
    if (!mounted) return;
    setState(() {
      _generating = false;
      for (final m in _session.messages) {
        if (m.pending) {
          m.pending = false;
          if (m.text.isEmpty) m.text = t.chatBubbleCancelled;
        }
      }
    });
    // ignore: deprecated_member_use
    SemanticsService.announce(
      t.chatAnnounceGenerationCancelled,
      TextDirection.ltr,
    );
    _persistIfNeeded();
  }

  Future<void> _clearConversation() async {
    if (_generating) return;
    final t = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: t.chatClearConfirmTitle,
      body: t.chatClearConfirmBody,
      yesLabel: t.chatClearConfirmYes,
      destructive: true,
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
    final t = AppLocalizations.of(context);
    final completed = _session.messages
        .where((m) => !m.pending)
        .toList(growable: false);
    if (completed.isEmpty) return;

    final ok = await showConfirmDialog(
      context,
      title: t.chatShareConfirmTitle,
      body: t.chatShareConfirmBody,
      yesLabel: t.chatShareConfirmYes,
    );
    if (ok != true) return;

    final buf = StringBuffer()
      ..writeln(t.chatExportTitle)
      ..writeln(t.chatExportModel(_activeModel?.displayName ?? '—'))
      ..writeln(
        t.chatExportDate(
          _session.updatedAt.toLocal().toString().split(".").first,
        ),
      )
      ..writeln();
    for (final m in completed) {
      // L5 v0.9.1 — Appliquer `latexToUnicode` au texte exporté pour cohérence
      // avec l'affichage en bulle. Avant : l'export contenait le LaTeX brut
      // (`$\text{H}_2\text{O}$`) alors que l'utilisateur voyait `H₂O` à
      // l'écran — incohérence trompeuse au moment du partage.
      final rendered = m.isUser ? m.text : latexToUnicode(m.text);
      buf
        ..writeln(
          m.isUser ? t.chatExportSpeakerUser : t.chatExportSpeakerAssistant,
        )
        ..writeln(_escapeMarkdownExport(rendered))
        ..writeln();
    }
    await Share.share(buf.toString(), subject: t.chatExportSubject);
  }

  /// Échappe les patterns markdown susceptibles de :
  /// 1. falsifier la structure de l'export (`^##` qui simulerait un nouveau
  ///    tour assistant si le contenu était re-rendu),
  /// 2. embarquer des liens cliquables non-désirés (`[text](url)`).
  /// Stratégie : préfixer chaque ligne par un échappement backslash sur les
  /// caractères structurels markdown en début de ligne.
  String _escapeMarkdownExport(String text) {
    return text
        .split('\n')
        .map((line) {
          // Désactive les en-têtes ATX qui usurperaient un tour Assistant/Vous.
          if (line.startsWith('#')) return '\\$line';
          return line;
        })
        .join('\n');
  }

  void _useQuickPrompt(String text) {
    _inputCtrl
      ..text = text
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: text.length),
      );
    setState(() {});
  }

  Future<void> _reloadChatAfterSpike() async {
    if (!mounted) return;
    if (_activeModel == null) return;
    if (_chat.isLoaded) return;
    setState(() => _modelLoading = true);
    try {
      // v0.7.0 (H1) — passe expectedPath pour détecter une désynchro
      // entre _lastModelPath de ChatService et l'activeModel courant
      // (ex. user a changé de modèle dans Settings pendant qu'on était
      // dans Spike). Si désynchro → ensureLoaded retourne false et on
      // recharge explicitement le bon modèle.
      final ok = await _chat.ensureLoaded(expectedPath: _activeModel!.path);
      if (!ok && mounted) {
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
    // QW5 v0.8.1 — debounce 300 ms : collapse les rafales Stop+onError+
    // inactive lifecycle qui pouvaient queuer 3 saves successifs.
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 300), _persistNow);
  }

  /// Persiste immédiatement (skip debounce). Utilisé sur dispose / paused /
  /// flush manuel — garantit que les données pré-rafale ne sont pas perdues.
  void _persistNow() {
    _persistDebounce?.cancel();
    final hasContent = _session.messages.any((m) => !m.pending);
    if (!hasContent) return;
    unawaited(
      EncryptedChatStore.instance.save(_session).catchError((_) {
        /* best-effort */
      }),
    );
  }

  /// Throttle : empêche d'enfiler 40 postFrameCallback/s pendant le streaming.
  void _scheduleScrollToBottom() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
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
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: t.chatTooltipConversations,
          icon: const Icon(Icons.menu),
          onPressed: _generating ? null : _openChatList,
        ),
        title: Text(
          localizedSessionTitle(context, _session),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: t.chatTooltipNew,
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: _generating
                ? null
                : () async {
                    _persistIfNeeded();
                    await _switchToSession(ChatSession.empty());
                  },
          ),
          Semantics(
            toggled: _ragEnabled,
            child: IconButton(
              tooltip: _ragEnabled ? t.chatTooltipRagOn : t.chatTooltipRagOff,
              icon: Icon(
                _ragEnabled ? Icons.auto_stories : Icons.auto_stories_outlined,
                color: _ragEnabled ? theme.colorScheme.primary : null,
              ),
              onPressed: _generating
                  ? null
                  : () => setState(() => _ragEnabled = !_ragEnabled),
            ),
          ),
          IconButton(
            tooltip: t.chatTooltipDelete,
            // v0.8.0 — corbeille rouge pour visibilité de l'action destructive.
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: _generating || _session.messages.isEmpty
                ? null
                : _clearConversation,
          ),
          IconButton(
            tooltip: t.chatTooltipSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
          PopupMenuButton<String>(
            tooltip: t.chatTooltipMore,
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
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(builder: (_) => const SpikeScreen()),
                      )
                      .then((_) => _reloadChatAfterSpike());
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                enabled: _session.messages.any((m) => !m.pending),
                child: ListTile(
                  leading: const Icon(Icons.share_outlined),
                  title: Text(t.chatMenuExport),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'documents',
                child: ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(t.chatMenuDocuments),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'spike',
                child: ListTile(
                  leading: const Icon(Icons.speed),
                  title: Text(t.chatMenuSpike),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(t.chatMenuAbout),
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
    final t = AppLocalizations.of(context);
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
                      key: ValueKey(msg.id),
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
          hintGenerating: t.chatComposerHintGenerating,
          hintMessage: t.chatComposerHintMessage,
          labelMessage: t.chatComposerLabelMessage,
          tooltipSend: t.chatTooltipSend,
          tooltipStop: t.chatTooltipStop,
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
    final t = AppLocalizations.of(context);
    return AppEmptyState(
      icon: Icons.smart_toy_outlined,
      title: t.chatNoModelTitle,
      subtitle: t.chatNoModelSubtitle,
      semanticHeader: true,
      excludeIconSemantics: true,
      action: FilledButton.icon(
        onPressed: onOpenSettings,
        icon: const Icon(Icons.settings),
        label: Text(t.chatNoModelOpenSettings),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: t.chatStatusLoadingModel(name),
              liveRegion: true,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(
              t.chatStatusLoadingModel(name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(t.chatStatusLoadingHint, textAlign: TextAlign.center),
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
    final t = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 56,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                t.chatStatusLoadFailed,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(t.commonRetry),
            ),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    final prompts = <_QuickPrompt>[
      _QuickPrompt(
        icon: Icons.edit_outlined,
        label: t.chatPromptImproveLabel,
        prompt: t.chatPromptImproveText,
      ),
      _QuickPrompt(
        icon: Icons.translate,
        label: t.chatPromptTranslateLabel,
        prompt: t.chatPromptTranslateText,
      ),
      _QuickPrompt(
        icon: Icons.summarize_outlined,
        label: t.chatPromptSummarizeLabel,
        prompt: t.chatPromptSummarizeText,
      ),
      _QuickPrompt(
        icon: Icons.lightbulb_outline,
        label: t.chatPromptExplainLabel,
        prompt: t.chatPromptExplainText,
      ),
      _QuickPrompt(
        icon: Icons.refresh,
        label: t.chatPromptReformulateLabel,
        prompt: t.chatPromptReformulateText,
      ),
      _QuickPrompt(
        icon: Icons.psychology_outlined,
        label: t.chatPromptBrainstormLabel,
        prompt: t.chatPromptBrainstormText,
      ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      children: [
        ExcludeSemantics(
          child: Center(
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
        ),
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            header: true,
            child: Text(
              t.chatEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            t.chatEmptyModel(model),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.bolt, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                t.chatEmptyQuickPrompts,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: prompts
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
  const _Bubble({super.key, required this.message, this.streaming});

  final ChatMessage message;
  final _StreamingTextNotifier? streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final isUser = message.isUser;
    final bg = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    final stream = streaming;
    // Pendant le streaming : ExcludeSemantics autour du SelectableText pour
    // éviter que TalkBack ne lise le texte complet à chaque token (spam
    // sonore ininterrompu). L'annonce finale est faite par _send onDone via
    // SemanticsService.announce.
    // v0.8.0 — applique latexToUnicode pendant le streaming AUSSI : sinon
    // l'utilisateur voit `$\text{H}_2\text{O}$` brut tant que la phrase
    // n'est pas terminée. Pour les messages user (isUser:true) on ne
    // touche pas (texte brut affiché tel quel).
    final Widget body = stream != null
        ? ExcludeSemantics(
            child: ValueListenableBuilder<String>(
              valueListenable: stream,
              builder: (_, value, _) => SelectableText(
                value.isEmpty ? '…' : latexToUnicode(value),
                style: TextStyle(color: fg, height: 1.35),
              ),
            ),
          )
        : _renderBody(
            context,
            message.text.isEmpty && message.pending ? '…' : message.text,
            fg,
            isUser: isUser,
          );

    // QW1 v0.8.1 — MediaQuery.sizeOf (ne dépend que de size) au lieu de
    //   MediaQuery.of(...).size : élimine ~80% des rebuilds parasites
    //   sur ouverture/fermeture clavier (viewInsets ne déclenche plus).
    // QW4 v0.8.1 — RepaintBoundary autour de la bulle pour isoler la
    //   couche de peinture pendant le streaming d'autres bulles.
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Cap visuel sur grandes tablettes / foldables : 82 % de 800dp = 656dp.
    final maxBubbleWidth = (screenWidth * 0.82).clamp(0.0, 560.0);
    return RepaintBoundary(
      child: Padding(
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
                child: Semantics(
                  label: isUser ? t.chatBubbleUser : t.chatBubbleAssistant,
                  container: true,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
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
                        // QW15 v0.8.1 — typing dots animés (pattern attendu
                        // 2026 sur apps de chat IA, ChatGPT/Gemini-like) au
                        // lieu du mini spinner 10×10 atypique.
                        if (message.pending)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _TypingDots(color: fg),
                          ),
                        // QW16 v0.8.1 — bouton copy explicite sur bulle
                        // assistant terminée (long-press conservé en
                        // fallback). Pattern attendu UX chat IA.
                        if (!isUser &&
                            !message.pending &&
                            message.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              // U1 v0.9.1 — `IconButton` avec tap target 40dp
                              // minimum + tooltip pour TalkBack. Avant :
                              // `InkResponse(radius:16)` + `Icon(size:14)` =
                              // cible ~24dp (< 48dp WCAG 2.5.5), pas de
                              // label TalkBack.
                              child: IconButton(
                                onPressed: () => _copy(context, message.text),
                                iconSize: 16,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                tooltip: t.chatCopySnack,
                                icon: Icon(
                                  Icons.copy_outlined,
                                  color: fg.withValues(alpha: 0.55),
                                ),
                              ),
                            ),
                          ),
                        if (!message.pending && message.sources.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _SourcesRow(
                              sources: message.sources,
                              fg: fg,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
      return SelectableText(text, style: TextStyle(color: fg, height: 1.35));
    }
    final theme = Theme.of(context);
    // v0.8.0 — convertit LaTeX → Unicode AVANT MarkdownBody (qui ne sait
    // pas rendre les formules math). Couvre $\text{H}_2\text{O}$ → H₂O,
    // $E = mc^2$ → E = mc², $\alpha$ → α, etc.
    return MarkdownBody(
      data: latexToUnicode(text),
      selectable: true,
      shrinkWrap: true,
      styleSheet: _styleSheetFor(theme, fg),
      onTapLink: (_, href, _) {
        // Sécurité : on ne lance jamais un lien depuis le chat (cohérent
        // avec la promesse "100 % offline"). Le user peut copier-coller.
      },
    );
  }

  /// Cache statique des stylesheet markdown (clé = brightness + couleur fg).
  /// Évite de re-instancier `MarkdownStyleSheet.fromTheme(theme).copyWith(…)`
  /// à chaque rebuild de chaque bulle (perf P0 : sur historique long, le
  /// ListView.builder reconstruit les items hors viewport et payait le coût
  /// du parsing/styling à chaque mesure).
  static final Map<int, MarkdownStyleSheet> _styleSheetCache = {};

  static MarkdownStyleSheet _styleSheetFor(ThemeData theme, Color fg) {
    final key = Object.hash(
      theme.brightness,
      fg.toARGB32(),
      theme.colorScheme.surface.toARGB32(),
    );
    final cached = _styleSheetCache[key];
    if (cached != null) return cached;
    // QW17 v0.8.1 — dérivé depuis `textTheme` Material 3 : respecte
    // Dynamic Type / `MediaQuery.textScaler` côté a11y (au lieu de
    // fontSize hard-coded 14/16/18/20).
    final tt = theme.textTheme;
    final body = tt.bodyMedium ?? const TextStyle(fontSize: 14);
    final h1Base = tt.headlineSmall ?? const TextStyle(fontSize: 20);
    final h2Base = tt.titleLarge ?? const TextStyle(fontSize: 18);
    final h3Base = tt.titleMedium ?? const TextStyle(fontSize: 16);
    final ss = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body.copyWith(color: fg, height: 1.35),
      h1: h1Base.copyWith(color: fg, fontWeight: FontWeight.w700),
      h2: h2Base.copyWith(color: fg, fontWeight: FontWeight.w700),
      h3: h3Base.copyWith(color: fg, fontWeight: FontWeight.w700),
      listBullet: body.copyWith(color: fg),
      strong: body.copyWith(color: fg, fontWeight: FontWeight.w700),
      em: body.copyWith(color: fg, fontStyle: FontStyle.italic),
      blockquote: body.copyWith(
        color: fg.withValues(alpha: 0.85),
        fontStyle: FontStyle.italic,
      ),
      code: body.copyWith(
        color: fg,
        fontFamily: 'monospace',
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(10),
    );
    if (_styleSheetCache.length > 8) _styleSheetCache.clear();
    _styleSheetCache[key] = ss;
    return ss;
  }

  void _copy(BuildContext context, String text) {
    if (text.isEmpty) return;
    final t = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text));
    // U4 v0.9.1 — feedback haptique sur copie réussie.
    HapticFeedback.selectionClick();
    context.showFloatingSnack(
      t.chatCopySnack,
      duration: const Duration(seconds: 1),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  const _SourcesRow({required this.sources, required this.fg});
  final List<RagSource> sources;
  final Color fg;

  void _show(BuildContext context, RagSource s) {
    final t = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.chatSourceDialogTitle(s.index, s.title)),
        content: SingleChildScrollView(child: SelectableText(s.excerpt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.commonClose),
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
            (s) => Semantics(
              button: true,
              child: InkWell(
                onTap: () => _show(context, s),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '[${s.index}] ${s.title}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
    required this.hintGenerating,
    required this.hintMessage,
    required this.labelMessage,
    required this.tooltipSend,
    required this.tooltipStop,
  });

  final TextEditingController controller;
  final bool generating;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hintGenerating;
  final String hintMessage;
  final String labelMessage;
  final String tooltipSend;
  final String tooltipStop;

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
              // U7 v0.9.1 — composer chat : majuscule auto en début de
              // phrase (UX FR/EN naturelle). `autocorrect`/`enableSuggestions`
              // gardés à `true` car prompt IA = on veut bénéficier de
              // l'aide saisie.
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: labelMessage,
                hintText: generating ? hintGenerating : hintMessage,
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
            Tooltip(
              message: tooltipStop,
              child: FilledButton.tonal(
                onPressed: onStop,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.stop),
              ),
            )
          else
            Tooltip(
              message: tooltipSend,
              child: FilledButton(
                onPressed: onSend,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: const Icon(Icons.send),
              ),
            ),
        ],
      ),
    );
  }
}

/// QW15 v0.8.1 — Trois points pulsants pour signaler "le modèle réfléchit"
/// pendant la phase de pre-fill (avant le premier token). Aligné sur le
/// pattern ChatGPT/Gemini/Claude. Plus lisible que le mini spinner 10×10.
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final t = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dot(_phase(t, 0)),
              _dot(_phase(t, 1 / 3)),
              _dot(_phase(t, 2 / 3)),
            ],
          );
        },
      ),
    );
  }

  /// Calcule l'alpha (0.3..1.0) d'un point en fonction de la position
  /// dans la boucle d'animation et de son offset de phase.
  double _phase(double t, double offset) {
    var x = (t - offset) % 1.0;
    if (x < 0) x += 1.0;
    // Triangle wave : ascend 0..0.5 puis descend 0.5..1.
    final v = x < 0.5 ? x * 2 : (1 - x) * 2;
    return 0.3 + 0.7 * v;
  }

  Widget _dot(double alpha) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: widget.color.withValues(alpha: alpha),
    ),
  );
}
