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

  /// v0.9.0 — confirme avant suppression. Utilisé par le bouton corbeille
  /// ET le swipe `Dismissible` (via `confirmDismiss`).
  Future<bool> _confirmDelete(ChatSession s) async {
    final t = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: t.chatListDeleteConfirmTitle,
      body: t.chatListDeleteConfirmBody(localizedSessionTitle(context, s)),
      yesLabel: t.commonDelete,
      destructive: true,
    );
    return ok == true;
  }

  /// v0.9.0 — renomme une conversation. Vide = réinitialise au sentinel
  /// par défaut (titre dérivé du premier message). Persiste via save().
  Future<void> _rename(ChatSession s) async {
    final t = AppLocalizations.of(context);
    final current = s.isDefaultTitle ? '' : s.title;
    final ctrl = TextEditingController(text: current);
    final newTitle = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.chatListRenameTitle),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: t.chatListRenameHint,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(t.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(t.commonOk),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (newTitle == null) return; // cancel
    final trimmed = newTitle.trim();
    s.title = trimmed.isEmpty ? ChatSession.defaultTitleSentinel : trimmed;
    s.updatedAt = DateTime.now();
    try {
      await EncryptedChatStore.instance.save(s);
    } catch (_) {
      /* best-effort */
    }
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
                return _SessionTile(
                  key: ValueKey(s.id),
                  session: s,
                  isActive: s.id == widget.activeId,
                  onTap: () => Navigator.of(context).pop(s.id),
                  onRename: () => _rename(s),
                  confirmDelete: () => _confirmDelete(s),
                  onDeleted: _load,
                );
              },
            ),
    );
  }
}

/// v0.9.0 — Tuile session : Dismissible swipe-left = supprime (avec
/// confirmation), tap = ouvre, long-press = renomme.
/// Extraite en widget pour préserver le `state` Dismissible et éviter
/// la pollution du parent par les callbacks.
class _SessionTile extends StatelessWidget {
  const _SessionTile({
    super.key,
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onRename,
    required this.confirmDelete,
    required this.onDeleted,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final Future<bool> Function() confirmDelete;
  final Future<void> Function() onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey('dis-${session.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.delete_outline, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        final ok = await confirmDelete();
        if (!ok) return false;
        await EncryptedChatStore.instance.deleteOne(session.id);
        await onDeleted();
        return true;
      },
      child: MergeSemantics(
        child: ListTile(
          leading: Icon(
            isActive ? Icons.chat : Icons.chat_bubble_outline,
            color: isActive ? cs.primary : null,
          ),
          title: Text(
            localizedSessionTitle(context, session),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            t.chatListSubtitle(
              session.messages.length,
              relativeDate(context, session.updatedAt),
            ),
            style: theme.textTheme.bodySmall,
          ),
          trailing: IconButton(
            tooltip: t.chatListRenameAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          selected: isActive,
          onTap: onTap,
          onLongPress: onRename,
        ),
      ),
    );
  }
}
