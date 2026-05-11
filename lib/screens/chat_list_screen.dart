import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/chat_session.dart';
import '../services/storage/encrypted_chat_store.dart';
import '../utils/app_dialogs.dart';
import '../utils/chat_session_label.dart';
import '../utils/relative_date.dart';
import '../widgets/app_empty_state.dart';

/// Liste des conversations persistées.
///
/// Renvoie via Navigator.pop le `id` de la conversation choisie, ou la chaîne
/// `__new__` pour créer une nouvelle conversation, ou `null` si l'utilisateur
/// recule sans choisir.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.activeId});

  final String? activeId;

  static const String resultNew = '__new__';

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSession> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await EncryptedChatStore.instance.listAll();
    if (!mounted) return;
    setState(() {
      _sessions = list;
      _loading = false;
    });
  }

  Future<void> _delete(ChatSession s) async {
    final t = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: t.chatListDeleteConfirmTitle,
      body: t.chatListDeleteConfirmBody(localizedSessionTitle(context, s)),
      yesLabel: t.commonDelete,
      destructive: true,
    );
    if (ok != true) return;
    await EncryptedChatStore.instance.deleteOne(s.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.chatListTitle),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(ChatListScreen.resultNew),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(t.chatListNewLabel),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? AppEmptyState(
              icon: Icons.chat_bubble_outline,
              title: t.chatListEmptyTitle,
              subtitle: t.chatListEmptySubtitle,
              action: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(ChatListScreen.resultNew),
                icon: const Icon(Icons.add_comment_outlined),
                label: Text(t.chatListNewFull),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                final isActive = s.id == widget.activeId;
                return MergeSemantics(
                  child: ListTile(
                    leading: Icon(
                      isActive ? Icons.chat : Icons.chat_bubble_outline,
                      color: isActive ? theme.colorScheme.primary : null,
                    ),
                    title: Text(
                      localizedSessionTitle(context, s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      t.chatListSubtitle(
                        s.messages.length,
                        relativeDate(context, s.updatedAt),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      // v0.8.0 — corbeille rouge pour visibilité destructive.
                      icon: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: t.commonDelete,
                      onPressed: () => _delete(s),
                    ),
                    selected: isActive,
                    onTap: () => Navigator.of(context).pop(s.id),
                  ),
                );
              },
            ),
    );
  }
}
