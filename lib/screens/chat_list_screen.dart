import 'package:flutter/material.dart';

import '../models/chat_session.dart';
import '../services/storage/encrypted_chat_store.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette conversation ?'),
        content: Text(
          '"${s.safeTitle}" sera supprimée définitivement (chiffrée, irrécupérable).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await EncryptedChatStore.instance.deleteOne(s.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversations'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(ChatListScreen.resultNew),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nouvelle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
          ? _Empty(
              onCreate: () =>
                  Navigator.of(context).pop(ChatListScreen.resultNew),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _sessions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = _sessions[i];
                final isActive = s.id == widget.activeId;
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.chat : Icons.chat_bubble_outline,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                  title: Text(
                    s.safeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isActive
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${s.messages.length} message${s.messages.length > 1 ? 's' : ''} · '
                    '${_relativeDate(s.updatedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Supprimer',
                    onPressed: () => _delete(s),
                  ),
                  onTap: () => Navigator.of(context).pop(s.id),
                );
              },
            ),
    );
  }

  static String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucune conversation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Démarrez une nouvelle discussion pour commencer.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Nouvelle conversation'),
            ),
          ],
        ),
      ),
    );
  }
}
