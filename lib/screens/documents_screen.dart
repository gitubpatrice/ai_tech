import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/rag/document.dart';
import '../services/rag/rag_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/relative_date.dart';
import '../utils/snackbar_ext.dart';
import '../widgets/app_empty_state.dart';

/// Lit un fichier texte dans un Isolate via compute() — évite de bloquer
/// le thread UI sur des documents > 500 Ko (200+ ms sur S9).
Future<String> _readTextInIsolate(String path) => compute(_readTextSync, path);

String _readTextSync(String path) => File(path).readAsStringSync();

/// Gestion des documents indexés pour le RAG.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const int _maxBytes = 1 * 1024 * 1024;
  static const Set<String> _allowedExt = {
    'txt',
    'md',
    'markdown',
    'csv',
    'log',
    'json',
    'xml',
    'yaml',
    'yml',
    'dart',
    'py',
    'js',
    'ts',
    'php',
    'kt',
    'java',
    'html',
    'css',
  };

  bool _busy = false;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _ensureBootstrapped();
  }

  Future<void> _ensureBootstrapped() async {
    await RagService.instance.bootstrap();
    if (!mounted) return;
    setState(() => _bootstrapping = false);
  }

  Future<void> _importFile() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      if (mounted) context.showFloatingSnack(t.documentsPickerError('$e'));
      return;
    }
    final p = picked?.files.isNotEmpty == true ? picked!.files.first : null;
    if (p == null) return;

    final path = p.path;
    final name = p.name;
    if (!mounted) return;
    if (path == null) {
      context.showFloatingSnack(t.documentsNoPath);
      return;
    }
    final ext = PathUtils.fileExt(name);
    if (!_allowedExt.contains(ext)) {
      context.showFloatingSnack(t.documentsUnsupportedFormat(ext));
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      if (mounted) context.showFloatingSnack(t.documentsNotFound);
      return;
    }
    final size = await file.length();
    if (size > _maxBytes) {
      if (mounted) {
        context.showFloatingSnack(
          t.documentsTooLarge(
            '${(size / 1024 / 1024).toStringAsFixed(2)} Mo',
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    try {
      final text = await _readTextInIsolate(file.path);
      if (text.trim().isEmpty) {
        if (mounted) context.showFloatingSnack(t.documentsEmpty);
        return;
      }
      final title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
      await RagService.instance.addDocument(title: title, text: text);
      if (!mounted) return;
      setState(() {});
      context.showFloatingSnack(t.documentsIndexed);
    } on FileSystemException catch (e) {
      if (mounted) context.showFloatingSnack(t.documentsRead(e.message));
    } catch (e) {
      if (mounted) context.showFloatingSnack(t.commonErrorWith('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteText() async {
    final t = AppLocalizations.of(context);
    final ctrlTitle = TextEditingController();
    final ctrlText = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.documentsPasteTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380, maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlTitle,
                decoration: InputDecoration(
                  labelText: t.documentsTitleField,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 80,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TextField(
                  controller: ctrlText,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    labelText: t.documentsContentField,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.documentsIndexAction),
          ),
        ],
      ),
    );

    final title = ctrlTitle.text;
    final text = ctrlText.text;
    ctrlTitle.dispose();
    ctrlText.dispose();

    if (saved != true || !mounted) return;
    if (text.trim().isEmpty) {
      context.showFloatingSnack(t.documentsContentEmpty);
      return;
    }
    if (text.length > _maxBytes) {
      context.showFloatingSnack(t.documentsContentTooLarge);
      return;
    }
    setState(() => _busy = true);
    try {
      await RagService.instance.addDocument(title: title, text: text);
      if (!mounted) return;
      setState(() {});
      context.showFloatingSnack(t.documentsTextIndexed);
    } catch (e) {
      if (mounted) context.showFloatingSnack(t.commonErrorWith('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RagDocument doc) async {
    final t = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: t.documentsDeleteConfirmTitle,
      body: t.documentsDeleteConfirmBody(doc.title),
      yesLabel: t.commonDelete,
      destructive: true,
    );
    if (ok != true || !mounted) return;
    await RagService.instance.removeDocument(doc.id);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final docs = RagService.instance.documents;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.documentsTitle),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _importFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(t.documentsImport),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pasteText,
                        icon: const Icon(Icons.content_paste_outlined),
                        label: Text(t.documentsPaste),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _bootstrapping
                    ? const Center(child: CircularProgressIndicator())
                    : docs.isEmpty
                    ? AppEmptyState(
                        icon: Icons.article_outlined,
                        title: t.documentsEmptyTitle,
                        subtitle: t.documentsEmptySubtitle,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _DocTile(
                          doc: docs[i],
                          onDelete: () => _delete(docs[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.onDelete});
  final RagDocument doc;
  final VoidCallback onDelete;

  String _charLabel(BuildContext context, int chars) {
    final t = AppLocalizations.of(context);
    if (chars >= 10000) {
      return t.documentsCharCountThousand((chars / 1000).toStringAsFixed(1));
    }
    return t.documentsCharCount(chars);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final chars = _charLabel(context, doc.charCount);
    final when = relativeDate(context, doc.createdAt);
    return MergeSemantics(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$chars · $when', style: theme.textTheme.bodySmall),
        trailing: IconButton(
          tooltip: t.commonDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
