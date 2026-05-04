import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import '../services/rag/document.dart';
import '../services/rag/rag_service.dart';

/// Lit un fichier texte dans un Isolate via compute() — évite de bloquer
/// le thread UI sur des documents > 500 Ko (200+ ms sur S9).
Future<String> _readTextInIsolate(String path) => compute(_readTextSync, path);

String _readTextSync(String path) => File(path).readAsStringSync();

/// Gestion des documents indexés pour le RAG.
///
/// L'utilisateur peut :
///   - importer un fichier texte (`.txt`, `.md`, code source) → chiffré dans
///     `<app_docs>/documents/<id>.aidoc`
///   - coller du texte directement
///   - voir la liste, supprimer
///
/// Limites volontaires (sécurité + perf) :
///   - taille max 1 Mo par document (un .txt de 1 Mo ≈ 200 000 mots)
///   - extensions autorisées : `.txt`, `.md`, `.markdown`, `.csv`, `.log`,
///     code source courant. PDF / DOCX prévus en ajout futur.
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
    // Idempotent : s'aligne sur le bootstrap déjà lancé dans `main.dart`.
    // On attend explicitement avant de rendre la liste pour ne pas afficher
    // un faux "Aucun document indexé" pendant que les .aidoc se déchiffrent.
    await RagService.instance.bootstrap();
    if (!mounted) return;
    setState(() => _bootstrapping = false);
  }

  Future<void> _importFile() async {
    if (_busy) return;
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      _snack('Erreur du picker : $e');
      return;
    }
    final p = picked?.files.isNotEmpty == true ? picked!.files.first : null;
    if (p == null) return;

    final path = p.path;
    final name = p.name;
    if (path == null) {
      _snack('Le système n\'a pas fourni de chemin lisible.');
      return;
    }
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!_allowedExt.contains(ext)) {
      _snack(
        'Format non supporté ($ext). Utilisez .txt, .md, .csv, '
        'ou code source.',
      );
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      _snack('Fichier introuvable.');
      return;
    }
    final size = await file.length();
    if (size > _maxBytes) {
      _snack(
        'Fichier trop volumineux (${(size / 1024 / 1024).toStringAsFixed(2)} Mo). '
        'Maximum 1 Mo.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      // compute() : lecture + décodage UTF-8 dans un Isolate -> UI fluide
      // même sur S9 / Redmi 9C avec un .txt de plusieurs Mo.
      final text = await _readTextInIsolate(file.path);
      if (text.trim().isEmpty) {
        _snack('Le fichier est vide.');
        return;
      }
      final title = name.replaceAll(RegExp(r'\.[^.]+$'), '');
      await RagService.instance.addDocument(title: title, text: text);
      if (!mounted) return;
      setState(() {});
      _snack('Document indexé.');
    } on FileSystemException catch (e) {
      _snack('Lecture impossible : ${e.message}');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pasteText() async {
    final ctrlTitle = TextEditingController();
    final ctrlText = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coller un texte'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380, maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrlTitle,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: 'Contenu',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Indexer'),
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
      _snack('Le contenu est vide.');
      return;
    }
    if (text.length > _maxBytes) {
      _snack('Texte trop long (max 1 Mo).');
      return;
    }
    setState(() => _busy = true);
    try {
      await RagService.instance.addDocument(title: title, text: text);
      if (!mounted) return;
      setState(() {});
      _snack('Texte indexé.');
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RagDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce document ?'),
        content: Text(
          '"${doc.title}" sera supprimé de l\'index et du téléphone (chiffré, irrécupérable).',
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
    if (ok != true || !mounted) return;
    await RagService.instance.removeDocument(doc.id);
    if (!mounted) return;
    setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final docs = RagService.instance.documents;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
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
                        label: const Text('Importer'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pasteText,
                        icon: const Icon(Icons.content_paste_outlined),
                        label: const Text('Coller'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
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
                    ? _Empty()
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

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.article_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aucun document indexé',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Importez un fichier texte ou collez du contenu pour permettre '
              'à l\'IA de répondre en s\'appuyant dessus.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.onDelete});
  final RagDocument doc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_sizeLabel(doc.charCount)} · ${_relativeDate(doc.createdAt)}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        tooltip: 'Supprimer',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }

  static String _sizeLabel(int chars) {
    if (chars >= 10000) {
      return '${(chars / 1000).toStringAsFixed(1)} k caractères';
    }
    return '$chars caractères';
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
