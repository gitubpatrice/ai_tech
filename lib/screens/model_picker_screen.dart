import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Picker pour les modèles `.task` / `.litertlm`.
///
/// Sur Android moderne (scoped storage, Android 11+), une app n'a pas le droit
/// de scanner librement le stockage public — l'utilisateur doit explicitement
/// désigner le fichier via le **Storage Access Framework**. C'est ce que fait
/// `file_picker`. On ajoute par-dessus :
///   - validation d'extension (`.task` / `.litertlm`),
///   - vérification taille (≥ 50 Mo),
///   - sanity-check de l'en-tête (rejet des fichiers manifestement étrangers).
///
/// L'app n'ayant pas la permission INTERNET (par design : 100 % offline),
/// on ne télécharge pas le modèle nous-mêmes. À la place, on guide
/// l'utilisateur en deux étapes :
///   1. Tap "Télécharger" → ouvre Kaggle / HuggingFace dans le navigateur
///      via un intent ACTION_VIEW (n'utilise pas la permission INTERNET de
///      cette app, c'est le navigateur système qui télécharge).
///   2. Tap "Importer le fichier" → SAF picker, copie atomique en sandbox.
class ModelPickerScreen extends StatelessWidget {
  const ModelPickerScreen({super.key});

  static const _kaggleUrl =
      'https://www.kaggle.com/models/google/gemma-3/tfLite/gemma-3-1b-it-int4';
  static const _hfUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT';

  /// Renvoie le chemin choisi, ou null si l'utilisateur annule.
  static Future<String?> pick(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
  }

  /// Ouvre une URL via le navigateur système (intent ACTION_VIEW).
  /// L'app n'a PAS la permission INTERNET — c'est le navigateur qui
  /// téléchargera. Aucun trafic réseau ne transite par cette app.
  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun navigateur disponible.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir le navigateur.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Source officielle Gemma 3',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('Kaggle (Google)'),
                subtitle: const Text('google/gemma-3 → tfLite'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openUrl(context, _kaggleUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: const Text('HuggingFace (litert-community)'),
                subtitle: const Text('Gemma3-1B-IT'),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openUrl(context, _hfUrl);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _systemPicker(BuildContext context) async {
    void snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      if (context.mounted) snack('Erreur du picker système : $e');
      return;
    }
    final picked0 = picked?.files.isNotEmpty == true
        ? picked!.files.first
        : null;
    if (picked0 == null) return; // annulé

    final path = picked0.path;
    final originalName = picked0.name.toLowerCase();
    if (path == null) {
      if (context.mounted) {
        snack(
          'Le système n\'a pas fourni de chemin lisible. '
          'Copiez le fichier dans Téléchargements et réessayez.',
        );
      }
      return;
    }
    if (!originalName.endsWith('.task') &&
        !originalName.endsWith('.litertlm')) {
      if (context.mounted) {
        snack('Format non supporté (.task ou .litertlm uniquement)');
      }
      return;
    }
    final f = File(path);
    if (!await f.exists()) {
      if (context.mounted) snack('Fichier introuvable.');
      return;
    }
    if (await f.length() < 50 * 1024 * 1024) {
      if (context.mounted) snack('Fichier trop petit pour être un modèle.');
      return;
    }
    // Sanity check : un `.task` MediaPipe contient un zip ; on cherche "PK"
    // dans les 32 premiers octets (le format peut avoir un en-tête propre
    // de quelques octets avant le zip).
    final head = await f.openRead(0, 32).first;
    bool hasPk = false;
    for (var i = 0; i < head.length - 1; i++) {
      if (head[i] == 0x50 && head[i + 1] == 0x4B) {
        hasPk = true;
        break;
      }
    }
    final hasTfl =
        head.length >= 8 &&
        ((head[4] == 0x54 && head[5] == 0x46 && head[6] == 0x4C) ||
            (head[0] == 0x54 && head[1] == 0x46 && head[2] == 0x4C));
    if (!hasPk && !hasTfl) {
      if (context.mounted) {
        snack('Le fichier ne ressemble pas à un modèle MediaPipe.');
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un modèle'),
        backgroundColor: cs.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.upload_file_outlined,
                    color: cs.onPrimaryContainer,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Sélectionnez votre modèle',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Format `.task` ou `.litertlm`, typiquement entre 500 Mo et 4 Go '
                '(Gemma, Qwen, Phi, Llama).',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.outline),
              ),
              const SizedBox(height: 24),
              Card(
                color: cs.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Recommandation',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Gemma 3 1B int4 (~554 Mo). Excellent en français, '
                        'très rapide, fenêtre de contexte 32K.',
                      ),
                      const SizedBox(height: 12),
                      _StepRow(
                        n: '1',
                        title: 'Téléchargez le modèle',
                        subtitle: 'Ouvre Kaggle ou HuggingFace dans votre '
                            'navigateur — AI Tech ne télécharge rien lui-même.',
                      ),
                      const SizedBox(height: 8),
                      _StepRow(
                        n: '2',
                        title: 'Importez-le ici',
                        subtitle:
                            'Une fois le `.task` téléchargé, "Importer" '
                            'le copie en sécurité dans le sandbox de l\'app '
                            '(SHA-256 vérifié).',
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _showSourceSheet(context),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Télécharger le modèle'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _systemPicker(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Importer le fichier'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.title, required this.subtitle});

  final String n;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            n,
            style: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(color: cs.outline, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
