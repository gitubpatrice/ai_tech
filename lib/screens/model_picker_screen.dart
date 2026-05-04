import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Picker pour les modèles `.task` / `.litertlm`.
///
/// Sur Android moderne (scoped storage, Android 11+), une app n'a pas le droit
/// de scanner librement le stockage public — l'utilisateur doit explicitement
/// désigner le fichier via le **Storage Access Framework**. C'est ce que fait
/// `file_picker`. On ajoute par-dessus :
///   - validation d'extension (`.task` / `.litertlm`),
///   - vérification taille (≥ 50 Mo),
///   - sanity-check de l'en-tête (rejet des fichiers manifestement étrangers).
class ModelPickerScreen extends StatelessWidget {
  const ModelPickerScreen({super.key});

  /// Renvoie le chemin choisi, ou null si l'utilisateur annule.
  static Future<String?> pick(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
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
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Recommandation',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Gemma 3 1B int4 (554 Mo, excellent en français, '
                        'très rapide). Source : Kaggle → google/gemma-3 → '
                        'tfLite → gemma3-1b-it-int4.',
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _systemPicker(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('Parcourir'),
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
