import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/model_limits.dart';
import '../services/storage/model_installer.dart';
import '../services/storage/model_registry.dart';
import '../utils/file_size.dart';
import '../utils/model_magic.dart';
import '../utils/snackbar_ext.dart';

/// Résultat d'un import de modèle : path final dans le sandbox + SHA-256
/// calculé pendant la copie streaming.
typedef PickedModel = ({String path, String? sha256});

/// Picker pour les modèles `.task` / `.litertlm`.
class ModelPickerScreen extends StatelessWidget {
  const ModelPickerScreen({super.key});

  static const _kaggleUrl =
      'https://www.kaggle.com/models/google/gemma-3/tfLite/gemma-3-1b-it-int4';
  static const _hfUrl = 'https://huggingface.co/litert-community/Gemma3-1B-IT';

  /// Renvoie le résultat (path + sha256) ou null si l'utilisateur annule.
  static Future<PickedModel?> pick(BuildContext context) {
    return Navigator.of(context).push<PickedModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
  }

  /// v0.9.0 (QW10) — pick + confirmation explicite si on réinstalle un
  /// modèle au même chemin avec un SHA-256 différent (signal possible
  /// d'un fichier compromis ou d'un changement intentionnel).
  ///
  /// Retourne :
  ///  - le `PickedModel` choisi si pas de collision OU si l'utilisateur
  ///    a confirmé le remplacement,
  ///  - `null` si l'utilisateur a annulé le pick OU refusé le remplacement.
  ///
  /// Helper unique pour éviter de dupliquer cette logique entre
  /// `onboarding_screen` et `settings_screen`.
  static Future<PickedModel?> pickAndConfirm(BuildContext context) async {
    final picked = await pick(context);
    if (picked == null) return null;
    final existing = await ModelRegistry.instance.findByPath(picked.path);
    if (existing == null ||
        existing.sha256 == null ||
        picked.sha256 == null ||
        existing.sha256 == picked.sha256) {
      return picked;
    }
    if (!context.mounted) return null;
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: cs.error, size: 36),
          title: Text(t.modelShaChangedTitle),
          content: SingleChildScrollView(
            child: Text(
              t.modelShaChangedBody(
                _shortHash(existing.sha256!),
                _shortHash(picked.sha256!),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t.modelShaChangedRefuse),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              child: Text(t.modelShaChangedReplace),
            ),
          ],
        );
      },
    );
    return ok == true ? picked : null;
  }

  /// Tronque un hash SHA-256 pour l'affichage en dialog (préfixe + suffixe
  /// avec ellipsis). Lisibilité > exactitude — le hash complet reste dans
  /// le fichier modèle si l'utilisateur veut vraiment vérifier.
  static String _shortHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 8)}…${hash.substring(hash.length - 8)}';
  }

  /// Ouvre une URL via le navigateur système (intent ACTION_VIEW).
  Future<void> _openUrl(BuildContext context, String url) async {
    final t = AppLocalizations.of(context);
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        context.showFloatingSnack(t.modelPickerNoBrowser);
      }
    } catch (_) {
      if (context.mounted) {
        context.showFloatingSnack(t.modelPickerCannotOpen);
      }
    }
  }

  void _showSourceSheet(BuildContext context) {
    final t = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Semantics(
                  header: true,
                  child: Text(
                    t.modelPickerSourceTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(t.modelPickerKaggle),
                subtitle: Text(t.modelPickerKaggleSubtitle),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _openUrl(context, _kaggleUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(t.modelPickerHf),
                subtitle: Text(t.modelPickerHfSubtitle),
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
    final t = AppLocalizations.of(context);
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
    } catch (e) {
      if (context.mounted)
        context.showFloatingSnack(t.modelPickerSysError('$e'));
      return;
    }
    final picked0 = picked?.files.isNotEmpty == true
        ? picked!.files.first
        : null;
    if (picked0 == null) return;

    final path = picked0.path;
    final originalName = picked0.name.toLowerCase();
    if (path == null) {
      if (context.mounted) context.showFloatingSnack(t.modelPickerNoPath);
      return;
    }
    if (!originalName.endsWith('.task') &&
        !originalName.endsWith('.litertlm')) {
      if (context.mounted) context.showFloatingSnack(t.modelPickerWrongFormat);
      return;
    }
    final f = File(path);
    if (!await f.exists()) {
      if (context.mounted) context.showFloatingSnack(t.modelPickerNotFound);
      return;
    }
    if (await f.length() < ModelLimits.minModelBytes) {
      if (context.mounted) context.showFloatingSnack(t.modelPickerTooSmall);
      return;
    }
    // v0.8.0 — magic check des 32 premiers octets.
    // - `.task`     : doit contenir `PK` (ZIP MediaPipe) ou `TFL` (TFLite).
    // - `.litertlm` : pas de magic stable connu, mais on bloque les formats
    //   évidents qu'un attaquant pourrait renommer (PDF, EXE PE, ZIP, image,
    //   XML/HTML). Defense-in-depth pour repousser le rename opportuniste
    //   avant que le binaire C `libLiteRtLm.so` ne parse un fichier piégé.
    final List<int> head;
    try {
      head = await f.openRead(0, 32).first;
    } catch (_) {
      if (context.mounted) context.showFloatingSnack(t.modelPickerNotFound);
      return;
    }
    if (originalName.endsWith('.task')) {
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
          context.showFloatingSnack(t.modelPickerNotMediapipe);
        }
        return;
      }
    } else if (originalName.endsWith('.litertlm')) {
      if (looksLikeKnownNonModel(head)) {
        if (context.mounted) {
          context.showFloatingSnack(t.modelPickerNotMediapipe);
        }
        return;
      }
    }

    if (!context.mounted) return;
    final result = await _installToSandbox(
      context,
      sourcePath: path,
      filename: picked0.name,
    );
    if (result == null) return;
    if (!context.mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<PickedModel?> _installToSandbox(
    BuildContext context, {
    required String sourcePath,
    required String filename,
  }) async {
    final completer = Completer<PickedModel?>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return _InstallProgressDialog(
          sourcePath: sourcePath,
          filename: filename,
          onDone: (result) {
            if (!completer.isCompleted) completer.complete(result);
          },
        );
      },
    );

    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.modelPickerTitle),
        backgroundColor: cs.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              ExcludeSemantics(
                child: Center(
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
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  t.modelPickerHeading,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.modelPickerSubtitle,
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
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.modelPickerRecommendation,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(t.modelPickerRecommendationText),
                      const SizedBox(height: 12),
                      _StepRow(
                        n: '1',
                        title: t.modelPickerStep1Title,
                        subtitle: t.modelPickerStep1Subtitle,
                      ),
                      const SizedBox(height: 8),
                      _StepRow(
                        n: '2',
                        title: t.modelPickerStep2Title,
                        subtitle: t.modelPickerStep2Subtitle,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _showSourceSheet(context),
                icon: const Icon(Icons.download_outlined),
                label: Text(t.modelPickerDownload),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _systemPicker(context),
                icon: const Icon(Icons.folder_open),
                label: Text(t.modelPickerImport),
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
  const _StepRow({
    required this.n,
    required this.title,
    required this.subtitle,
  });

  final String n;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Row(
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
      ),
    );
  }
}

class _InstallProgressDialog extends StatefulWidget {
  const _InstallProgressDialog({
    required this.sourcePath,
    required this.filename,
    required this.onDone,
  });

  final String sourcePath;
  final String filename;
  final void Function(PickedModel? result) onDone;

  @override
  State<_InstallProgressDialog> createState() => _InstallProgressDialogState();
}

class _InstallProgressDialogState extends State<_InstallProgressDialog> {
  StreamSubscription<ModelInstallEvent>? _sub;
  int _copied = 0;
  int _total = 0;
  String? _finalPath;
  String? _sha256;
  Object? _error;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    final stream = ModelInstaller.instance.installFromSafFile(
      widget.sourcePath,
      widget.filename,
    );
    _sub = stream.listen(
      (ev) {
        if (!mounted) return;
        setState(() {
          _copied = ev.copied;
          _total = ev.total;
          if (ev.finalPath != null) {
            _finalPath = ev.finalPath;
            _sha256 = ev.sha256;
          }
        });
      },
      onError: (Object e, StackTrace _) {
        if (!mounted) return;
        setState(() => _error = e);
      },
      onDone: () {
        if (!mounted) return;
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _finish(PickedModel? result) {
    if (_completed) return;
    _completed = true;
    Navigator.of(context).pop();
    widget.onDone(result);
  }

  /// QW19 v0.8.1 — reset l'état d'échec et relance la copie depuis le
  /// même `sourcePath` (évite à l'utilisateur de refaire un pick SAF
  /// après échec à 95 % sur 6 Go).
  void _retry() {
    _sub?.cancel();
    setState(() {
      _sub = null;
      _copied = 0;
      _total = 0;
      _finalPath = null;
      _sha256 = null;
      _error = null;
    });
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppLocalizations.of(context);

    if (_error != null) {
      return AlertDialog(
        title: Text(t.modelInstallFailedTitle),
        content: Text(
          t.modelInstallFailedBody('$_error'),
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => _finish(null),
            child: Text(t.commonClose),
          ),
          // QW19 v0.8.1 — bouton "Réessayer" : un import 2-6 Go qui échoue
          // à 95 % (disk full, kill OS) ne doit pas forcer un re-pick SAF
          // complet. On reset l'état et relance le stream depuis le même
          // sourcePath.
          FilledButton.tonal(
            onPressed: _retry,
            child: Text(t.commonRetry),
          ),
        ],
      );
    }

    final done = _finalPath != null && _sha256 != null;
    final progress = _total > 0 ? _copied / _total : 0.0;

    return AlertDialog(
      title: Text(done ? t.modelInstallTitleDone : t.modelInstallTitleCopying),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!done) ...[
            Text(
              t.modelInstallCopyDescription,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Semantics(
              label: t.commonLoading,
              liveRegion: true,
              child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
            ),
            const SizedBox(height: 8),
            Text(
              _total > 0
                  ? t.modelInstallCopiedOf(
                      fmtMegabytes(_copied),
                      fmtMegabytes(_total),
                      (progress * 100).toStringAsFixed(1),
                    )
                  : t.modelInstallPreparing,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
          ] else ...[
            Text(
              t.modelInstallDoneDescription(fmtMegabytes(_total)),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              t.modelInstallSha256Label,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Semantics(
                label: t.modelInstallSha256Sem,
                readOnly: true,
                child: SelectableText(
                  _sha256!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _sha256!));
                  if (!context.mounted) return;
                  // QW12 v0.8.1 — uniformise sur showFloatingSnack
                  // (helper centralisé) au lieu du SnackBar direct.
                  context.showFloatingSnack(t.modelInstallSha256Copied);
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(t.modelInstallCopyHash),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!done)
          TextButton(
            onPressed: () {
              _sub?.cancel();
              _finish(null);
            },
            child: Text(t.commonCancel),
          )
        else
          FilledButton(
            onPressed: () => _finish(
              _finalPath == null ? null : (path: _finalPath!, sha256: _sha256),
            ),
            child: Text(t.commonContinue),
          ),
      ],
    );
  }
}
