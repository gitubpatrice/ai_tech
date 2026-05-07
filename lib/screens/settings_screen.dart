import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../main.dart';
import '../models/app_settings.dart';
import '../models/model_entry.dart';
import '../models/model_family.dart';
import '../services/chat_service.dart';
import '../services/panic_service.dart';
import '../services/storage/app_settings_store.dart';
import '../services/storage/encrypted_chat_store.dart';
import '../services/storage/model_registry.dart';
import 'about_screen.dart';
import 'model_picker_screen.dart';

/// Paramètres : modèles, génération, sécurité, à propos.
///
/// Toute modification est persistée immédiatement. Les changements sur la
/// génération (température, topK, maxTokens) ne s'appliquent qu'au prochain
/// rechargement du modèle (via "Recharger" ou changement de modèle actif).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  List<ModelEntry> _models = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppSettingsStore.instance.load();
    final m = await ModelRegistry.instance.loadAndPrune();
    if (!mounted) return;
    setState(() {
      _settings = s;
      _models = m;
    });
  }

  Future<void> _update(AppSettings next) async {
    setState(() => _settings = next);
    await AppSettingsStore.instance.save(next);
  }

  Future<void> _addModel() async {
    if (_busy) return;
    final picked = await ModelPickerScreen.pick(context);
    if (picked == null || !mounted) return;
    final path = picked.path;
    final lower = path.toLowerCase();
    setState(() => _busy = true);
    try {
      final family = ModelFamilyUtils.detectFamilyName(path);
      final fileType = lower.endsWith('.litertlm') ? 'litertlm' : 'task';
      final entry = await ModelRegistry.instance.register(
        path: path,
        displayName: ModelFamilyUtils.displayNameOf(path),
        family: family,
        fileType: fileType,
        sha256: picked.sha256,
      );
      // Si c'est le premier, le rendre actif.
      if (_settings?.activeModelId == null) {
        await _update(_settings!.copyWith(activeModelId: entry.id));
      }
      await _load();
      _toast('Modèle ajouté');
    } catch (e) {
      _toast('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeModel(ModelEntry entry) async {
    final confirm = await _confirm(
      title: 'Retirer ce modèle ?',
      body:
          'Le fichier ${entry.displayName} ne sera pas supprimé du stockage. '
          'Il sera juste retiré de la liste des modèles enregistrés.',
      destructive: true,
      yesLabel: 'Retirer',
    );
    if (confirm != true || !mounted) return;
    await ModelRegistry.instance.remove(entry.id);
    if (!mounted) return;
    if (_settings?.activeModelId == entry.id) {
      await _update(_settings!.copyWith(clearActiveModel: true));
    }
    if (!mounted) return;
    await _load();
  }

  Future<void> _setActive(ModelEntry entry) async {
    if (_settings == null) return;
    await _update(_settings!.copyWith(activeModelId: entry.id));
    if (!mounted) return;
    _toast('Modèle actif : ${entry.displayName}');
  }

  Future<void> _clearChats() async {
    final confirm = await _confirm(
      title: 'Effacer toutes les conversations ?',
      body:
          'L\'historique chiffré sera supprimé. Vos modèles et paramètres '
          'sont conservés.',
      destructive: true,
      yesLabel: 'Effacer',
    );
    if (confirm != true || !mounted) return;
    await EncryptedChatStore.instance.deleteAll();
    await ChatService.instance.resetConversation();
    if (mounted) _toast('Conversations effacées');
  }

  Future<void> _triggerPanic() async {
    final confirm = await _confirm(
      title: 'Mode panique',
      body:
          'Cette action efface en bloc :\n\n'
          '• toutes les conversations chiffrées\n'
          '• la clé de chiffrement (irrécupérable)\n'
          '• la liste des modèles enregistrés\n'
          '• tous les paramètres\n\n'
          'Les fichiers .task que vous avez téléchargés sur votre téléphone '
          'ne sont pas touchés. L\'application redémarre comme au premier '
          'lancement.\n\nContinuer ?',
      destructive: true,
      yesLabel: 'Tout effacer',
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    await PanicService.instance.trigger();
    if (!mounted) return;
    // Force la re-évaluation de `firstLaunchCompleted` AVANT de remplacer
    // la route. Sans ça, `_AiTechAppState._firstLaunchDone` resterait à
    // `true` (cache du `Future`) et l'utilisateur retomberait directement
    // sur `ChatScreen` au lieu de l'onboarding pourtant attendu après wipe.
    AiTechApp.refreshFirstLaunch();
    // Rentre dans le pop pour relancer l'onboarding au prochain démarrage.
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String yesLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(backgroundColor: cs.error)
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yesLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : AbsorbPointer(
              absorbing: _busy,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _SectionHeader(
                    icon: Icons.psychology_outlined,
                    title: 'Modèles',
                  ),
                  ..._models.map(
                    (m) => _ModelTile(
                      entry: m,
                      isActive: s.activeModelId == m.id,
                      onSetActive: () => _setActive(m),
                      onRemove: () => _removeModel(m),
                      onVerified: _load,
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.add, color: theme.colorScheme.primary),
                    title: const Text('Ajouter un modèle'),
                    subtitle: const Text('.task ou .litertlm'),
                    onTap: _addModel,
                  ),
                  const Divider(),
                  _SectionHeader(icon: Icons.tune, title: 'Génération'),
                  _SliderTile(
                    label: 'Créativité (température)',
                    valueLabel: s.temperature.toStringAsFixed(2),
                    value: s.temperature,
                    min: AppSettings.minTemperature,
                    max: AppSettings.maxTemperature,
                    divisions: 14,
                    onChanged: (v) => _update(s.copyWith(temperature: v)),
                    helper: 'Bas = factuel et stable. Haut = créatif et varié.',
                  ),
                  _SliderTile(
                    label: 'Diversité (top-K)',
                    valueLabel: s.topK.toString(),
                    value: s.topK.toDouble(),
                    min: AppSettings.minTopK.toDouble(),
                    max: AppSettings.maxTopK.toDouble(),
                    divisions: 99,
                    onChanged: (v) => _update(s.copyWith(topK: v.round())),
                    helper:
                        'Nombre de mots candidats considérés à chaque étape.',
                  ),
                  _SliderTile(
                    label: 'Longueur de contexte (maxTokens)',
                    valueLabel: s.maxTokens.toString(),
                    value: s.maxTokens.toDouble(),
                    min: AppSettings.minMaxTokens.toDouble(),
                    max: AppSettings.maxMaxTokens.toDouble(),
                    divisions: 15,
                    onChanged: (v) =>
                        _update(s.copyWith(maxTokens: (v / 256).round() * 256)),
                    helper:
                        'Mémoire de la conversation. Plus haut = plus de RAM consommée.',
                  ),
                  const Divider(),
                  _SectionHeader(
                    icon: Icons.security_outlined,
                    title: 'Données et sécurité',
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined),
                    title: const Text('Effacer les conversations'),
                    subtitle: const Text(
                      'Supprime l\'historique chiffré. Modèles et paramètres conservés.',
                    ),
                    onTap: _clearChats,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.local_fire_department_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Mode panique',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: const Text(
                      'Efface clé + historique + modèles + paramètres.',
                    ),
                    onTap: _triggerPanic,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('À propos'),
                    subtitle: const Text('Version, légal, support'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatefulWidget {
  const _ModelTile({
    required this.entry,
    required this.isActive,
    required this.onSetActive,
    required this.onRemove,
    required this.onVerified,
  });
  final ModelEntry entry;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onRemove;

  /// Callback déclenché après un re-calcul SHA-256 réussi (pour reload UI).
  final VoidCallback onVerified;

  @override
  State<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  bool _verifying = false;

  Future<void> _verify() async {
    if (_verifying) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _verifying = true);
    try {
      final file = File(widget.entry.path);
      if (!await file.exists()) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Fichier introuvable.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      // Calcule en streaming (pas de chargement complet en RAM).
      final digest = await sha256.bind(file.openRead()).first;
      final hex = digest.toString().toLowerCase();
      if (!mounted) return;
      final stored = widget.entry.sha256;
      if (stored == null) {
        // Première vérification : on persiste le hash recalculé.
        await ModelRegistry.instance.register(
          path: widget.entry.path,
          displayName: widget.entry.displayName,
          family: widget.entry.family,
          fileType: widget.entry.fileType,
          sha256: hex,
        );
        widget.onVerified();
        if (!mounted) return;
        await _showHashDialog(
          title: 'SHA-256 calculé et enregistré',
          body: hex,
        );
      } else if (hex == stored) {
        await _showHashDialog(
          title: 'Intégrité vérifiée',
          body: 'Le SHA-256 correspond à celui enregistré :\n\n$hex',
        );
      } else {
        await _showHashDialog(
          title: 'SHA-256 différent !',
          body:
              'Attendu : $stored\n\n'
              'Calculé : $hex\n\n'
              'Le fichier a été modifié depuis l\'installation.',
          warning: true,
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur de vérification : $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _showHashDialog({
    required String title,
    required String body,
    bool warning = false,
  }) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: warning
                ? TextStyle(color: theme.colorScheme.error)
                : null,
          ),
          content: SelectableText(
            body,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: body));
              },
              child: const Text('Copier'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entry = widget.entry;
    final hash = entry.sha256;
    final shortHash = hash == null
        ? 'SHA-256 non enregistré'
        : 'SHA-256 ${hash.substring(0, 12)}…';
    return ListTile(
      leading: Icon(
        widget.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
        color: widget.isActive ? cs.primary : cs.outline,
      ),
      title: Text(entry.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.family} · ${entry.fileType} · ${entry.sizeLabel}',
            style: textTheme.bodySmall,
          ),
          Text(
            shortHash,
            style: textTheme.bodySmall?.copyWith(
              color: cs.outline,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: _verifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            tooltip: 'Vérifier l\'intégrité (SHA-256)',
            onPressed: _verifying ? null : _verify,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Retirer de la liste',
            onPressed: widget.onRemove,
          ),
        ],
      ),
      onTap: widget.isActive ? null : widget.onSetActive,
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.helper,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                valueLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
          Text(
            helper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
