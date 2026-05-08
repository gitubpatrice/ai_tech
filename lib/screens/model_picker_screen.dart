import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/model_limits.dart';
import '../services/storage/model_installer.dart';
import '../utils/file_size.dart';
import '../utils/snackbar_ext.dart';

/// Résultat d'un import de modèle : path final dans le sandbox + SHA-256
/// calculé pendant la copie streaming.
typedef PickedModel = ({String path, String? sha256});

/// Picker pour les modèles `.task` / `.litertlm`.
class ModelPickerScreen extends StatelessWidget {
  const ModelPickerScreen({super.key});

  static const _kaggleUrl =
      'https://www.kaggle.com/models/google/gemma-3/tfLite/gemma-3-1b-it-int4';
  static const _hfUrl =
      'https://huggingface.co/litert-community/Gemma3-1B-IT';

  /// Renvoie le résultat (path + sha256) ou null si l'utilisateur annule.
  static Future<PickedModel?> pick(BuildContext context) {
    return Navigator.of(context).push<PickedModel>(
      MaterialPageRoute(builder: (_) => const ModelPickerScreen()),
    );
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
      if (context.mounted) context.showFloatingSnack(t.modelPickerSysError('$e'));
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
      if (context.mounted) context.showFloatingSnack(t.modelPickerNotMediapipe);
      return;
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
                          Icon(Icons.lightbulb_outline,
                              size: 18, color: cs.primary),
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
  const _StepRow({required this.n, required this.title, required this.subtitle});

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
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: _sha256!));
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(t.modelInstallSha256Copied),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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
              _finalPath == null
                  ? null
                  : (path: _finalPath!, sha256: _sha256),
            ),
            child: Text(t.commonContinue),
          ),
      ],
    );
  }
}
