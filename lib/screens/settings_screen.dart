import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../models/model_entry.dart';
import '../services/chat_service.dart';
import '../services/panic_service.dart';
import '../services/storage/app_settings_store.dart';
import '../services/storage/encrypted_chat_store.dart';
import '../services/storage/model_registry.dart';
import '../utils/app_dialogs.dart';
import '../utils/snackbar_ext.dart';
import 'about_screen.dart';
import 'model_picker_screen.dart';

import '../models/model_family.dart';

/// Paramètres : modèles, génération, sécurité, apparence (langue + thème).
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
    final t = AppLocalizations.of(context);
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
      if (_settings?.activeModelId == null) {
        await _update(_settings!.copyWith(activeModelId: entry.id));
      }
      await _load();
      if (mounted) context.showFloatingSnack(t.settingsModelAdded);
    } catch (e) {
      if (mounted) context.showFloatingSnack(t.commonErrorWith('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeModel(ModelEntry entry) async {
    final t = AppLocalizations.of(context);
    final confirm = await showConfirmDialog(
      context,
      title: t.settingsRemoveModelTitle,
      body: t.settingsRemoveModelBody(entry.displayName),
      yesLabel: t.settingsRemoveModelYes,
      destructive: true,
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

  Future<void> _deactivateModel(ModelEntry entry) async {
    await ChatService.instance.unloadModel();
    if (!mounted) return;
    if (_settings?.activeModelId == entry.id) {
      await _update(_settings!.copyWith(clearActiveModel: true));
    }
    if (!mounted) return;
    await _load();
  }

  Future<void> _setActive(ModelEntry entry) async {
    if (_settings == null) return;
    final t = AppLocalizations.of(context);
    await _update(_settings!.copyWith(activeModelId: entry.id));
    if (!mounted) return;
    context.showFloatingSnack(t.settingsModelActive(entry.displayName));
  }

  Future<void> _clearChats() async {
    final t = AppLocalizations.of(context);
    final confirm = await showConfirmDialog(
      context,
      title: t.settingsClearConfirmTitle,
      body: t.settingsClearConfirmBody,
      yesLabel: t.settingsClearConfirmYes,
      destructive: true,
    );
    if (confirm != true || !mounted) return;
    await EncryptedChatStore.instance.deleteAll();
    await ChatService.instance.resetConversation();
    if (mounted) context.showFloatingSnack(t.settingsClearDone);
  }

  Future<void> _triggerPanic() async {
    final t = AppLocalizations.of(context);
    final confirm = await showConfirmDialog(
      context,
      title: t.settingsPanic,
      body: t.settingsPanicConfirmBody,
      yesLabel: t.settingsPanicConfirmYes,
      destructive: true,
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    await PanicService.instance.trigger();
    if (!mounted) return;
    SemanticsService.announce(t.settingsPanicAnnounceDone, TextDirection.ltr);
    AiTechApp.refreshFirstLaunch();
    Navigator.of(context).popUntil((r) => r.isFirst);
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyLocale, localeToString(locale));
    localeNotifier.value = locale;
    if (!mounted) return;
    final lc =
        locale?.languageCode ?? Localizations.localeOf(context).languageCode;
    final msg = lc == 'en'
        ? AppLocalizations.of(context).settingsLanguageChangedEn
        : AppLocalizations.of(context).settingsLanguageChangedFr;
    SemanticsService.announce(msg, TextDirection.ltr);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyThemeMode, themeModeToString(mode));
    themeNotifier.value = mode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final s = _settings;
    final currentLocale = localeNotifier.value;
    final currentThemeMode = themeNotifier.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.settingsTitle),
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
                    title: t.settingsSectionModels,
                  ),
                  ..._models.map(
                    (m) => _ModelTile(
                      entry: m,
                      isActive: s.activeModelId == m.id,
                      onSetActive: () => _setActive(m),
                      onRemove: () => _removeModel(m),
                      onVerified: _load,
                      onDeactivate: () => _deactivateModel(m),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.add, color: theme.colorScheme.primary),
                    title: Text(t.settingsAddModelTitle),
                    subtitle: Text(t.settingsAddModelSubtitle),
                    onTap: _addModel,
                  ),
                  const Divider(),
                  _SectionHeader(
                    icon: Icons.tune,
                    title: t.settingsSectionGeneration,
                  ),
                  _SliderTile(
                    label: t.settingsSliderCreativity,
                    valueLabel: s.temperature.toStringAsFixed(2),
                    value: s.temperature,
                    min: AppSettings.minTemperature,
                    max: AppSettings.maxTemperature,
                    divisions: 14,
                    onChanged: (v) => _update(s.copyWith(temperature: v)),
                    helper: t.settingsSliderCreativityHelper,
                  ),
                  _SliderTile(
                    label: t.settingsSliderDiversity,
                    valueLabel: s.topK.toString(),
                    value: s.topK.toDouble(),
                    min: AppSettings.minTopK.toDouble(),
                    max: AppSettings.maxTopK.toDouble(),
                    divisions: 99,
                    onChanged: (v) => _update(s.copyWith(topK: v.round())),
                    helper: t.settingsSliderDiversityHelper,
                  ),
                  _SliderTile(
                    label: t.settingsSliderContext,
                    valueLabel: s.maxTokens.toString(),
                    value: s.maxTokens.toDouble(),
                    min: AppSettings.minMaxTokens.toDouble(),
                    max: AppSettings.maxMaxTokens.toDouble(),
                    divisions: 15,
                    onChanged: (v) =>
                        _update(s.copyWith(maxTokens: (v / 256).round() * 256)),
                    helper: t.settingsSliderContextHelper,
                  ),
                  const Divider(),
                  _SectionHeader(
                    icon: Icons.palette_outlined,
                    title: t.settingsSectionAppearance,
                  ),
                  _LanguageTile(current: currentLocale, onChanged: _setLocale),
                  _ThemeTile(
                    current: currentThemeMode,
                    onChanged: _setThemeMode,
                  ),
                  const Divider(),
                  _SectionHeader(
                    icon: Icons.security_outlined,
                    title: t.settingsSectionDataSecurity,
                  ),
                  ListTile(
                    // v0.8.0 — corbeille rouge pour visibilité destructive.
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(t.settingsClearChats),
                    subtitle: Text(t.settingsClearChatsSubtitle),
                    onTap: _clearChats,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.local_fire_department_outlined,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      t.settingsPanic,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: Text(t.settingsPanicSubtitle),
                    onTap: _triggerPanic,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(t.settingsAbout),
                    subtitle: Text(t.settingsAboutSubtitle),
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
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: cs.primary, size: 20)),
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
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.current, required this.onChanged});
  final Locale? current;
  final ValueChanged<Locale?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = current == null
        ? t.settingsLanguageSystem
        : (current!.languageCode == 'en'
              ? t.settingsLanguageEn
              : t.settingsLanguageFr);
    return ListTile(
      leading: const Icon(Icons.translate),
      title: Text(t.settingsLanguage),
      subtitle: Text(label),
      trailing: PopupMenuButton<String>(
        tooltip: t.settingsLanguage,
        icon: const Icon(Icons.expand_more),
        onSelected: (v) {
          switch (v) {
            case 'system':
              onChanged(null);
              break;
            case 'fr':
              onChanged(const Locale('fr'));
              break;
            case 'en':
              onChanged(const Locale('en'));
              break;
          }
        },
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: 'system',
            checked: current == null,
            child: Text(t.settingsLanguageSystem),
          ),
          CheckedPopupMenuItem(
            value: 'fr',
            checked: current?.languageCode == 'fr',
            child: Text(t.settingsLanguageFr),
          ),
          CheckedPopupMenuItem(
            value: 'en',
            checked: current?.languageCode == 'en',
            child: Text(t.settingsLanguageEn),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.current, required this.onChanged});
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final label = switch (current) {
      ThemeMode.system => t.settingsThemeSystem,
      ThemeMode.light => t.settingsThemeLight,
      ThemeMode.dark => t.settingsThemeDark,
    };
    return ListTile(
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(t.settingsTheme),
      subtitle: Text(label),
      trailing: PopupMenuButton<ThemeMode>(
        tooltip: t.settingsTheme,
        icon: const Icon(Icons.expand_more),
        onSelected: onChanged,
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: ThemeMode.system,
            checked: current == ThemeMode.system,
            child: Text(t.settingsThemeSystem),
          ),
          CheckedPopupMenuItem(
            value: ThemeMode.light,
            checked: current == ThemeMode.light,
            child: Text(t.settingsThemeLight),
          ),
          CheckedPopupMenuItem(
            value: ThemeMode.dark,
            checked: current == ThemeMode.dark,
            child: Text(t.settingsThemeDark),
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
    required this.onDeactivate,
  });
  final ModelEntry entry;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onRemove;
  final VoidCallback onVerified;
  final Future<void> Function() onDeactivate;

  @override
  State<_ModelTile> createState() => _ModelTileState();
}

class _ModelTileState extends State<_ModelTile> {
  bool _verifying = false;

  Future<void> _verify() async {
    if (_verifying) return;
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _verifying = true);
    try {
      final file = File(widget.entry.path);
      if (!await file.exists()) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(t.settingsHashFileNotFound),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final digest = await sha256.bind(file.openRead()).first;
      final hex = digest.toString().toLowerCase();
      if (!mounted) return;
      final stored = widget.entry.sha256;
      if (stored == null) {
        await ModelRegistry.instance.register(
          path: widget.entry.path,
          displayName: widget.entry.displayName,
          family: widget.entry.family,
          fileType: widget.entry.fileType,
          sha256: hex,
        );
        widget.onVerified();
        if (!mounted) return;
        await _showHashDialog(title: t.settingsHashStored, body: hex);
      } else if (hex == stored) {
        await _showHashDialog(
          title: t.settingsHashOk,
          body: t.settingsHashOkBody(hex),
        );
      } else {
        if (!mounted) return;
        final disable = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final theme = Theme.of(ctx);
            return AlertDialog(
              title: Text(
                t.settingsHashMismatch,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              content: SingleChildScrollView(
                child: SelectableText(
                  t.settingsHashMismatchBody(stored, hex),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(t.settingsHashIgnore),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.onErrorContainer,
                    backgroundColor: theme.colorScheme.errorContainer,
                  ),
                  child: Text(t.settingsHashDeactivate),
                ),
              ],
            );
          },
        );
        if (disable == true && mounted) {
          await widget.onDeactivate();
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.settingsHashVerifyError('$e')),
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
  }) async {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Semantics(
            label: t.modelInstallSha256Sem,
            readOnly: true,
            child: SelectableText(
              body,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: body));
              },
              child: Text(t.commonCopy),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.commonOk),
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
    final t = AppLocalizations.of(context);
    final entry = widget.entry;
    final hash = entry.sha256;
    final shortHash = hash == null
        ? t.settingsHashShortNotStored
        : t.settingsHashShortPrefix(hash.substring(0, 12));
    return MergeSemantics(
      child: ListTile(
        leading: Icon(
          widget.isActive ? Icons.radio_button_checked : Icons.radio_button_off,
          color: widget.isActive ? cs.primary : cs.outline,
        ),
        title: Text(entry.displayName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ModelFamilyUtils.displayLabelFromName(entry.family)} · '
              '${entry.fileType} · ${entry.sizeLabel}',
              style: textTheme.bodyMedium,
            ),
            Text(
              shortHash,
              style: textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                icon: _verifying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                tooltip: t.settingsVerifyTooltip,
                onPressed: _verifying ? null : _verify,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: IconButton(
                // v0.8.0 — corbeille rouge pour visibilité destructive.
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                tooltip: t.settingsRemoveTooltip,
                onPressed: widget.onRemove,
              ),
            ),
          ],
        ),
        selected: widget.isActive,
        onTap: widget.isActive ? null : widget.onSetActive,
      ),
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
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: MergeSemantics(
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
            Semantics(
              value: t.settingsSliderSemantic(label, valueLabel),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                label: valueLabel,
                onChanged: onChanged,
              ),
            ),
            Text(
              helper,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
