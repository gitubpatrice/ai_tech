import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../l10n/app_localizations.dart';
import '../models/model_family.dart';
import '../services/storage/app_settings_store.dart';
import '../services/storage/model_registry.dart';
import '../utils/snackbar_ext.dart';
import 'about_screen.dart';
import 'model_picker_screen.dart';

/// Premier lancement : explique le principe, fait choisir un modèle.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _busy = false;

  Future<void> _pickAndFinish() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final picked = await ModelPickerScreen.pick(context);
    if (picked == null || !mounted) return;
    final path = picked.path;
    final lower = path.toLowerCase();

    setState(() => _busy = true);
    try {
      final entry = await ModelRegistry.instance.register(
        path: path,
        displayName: ModelFamilyUtils.displayNameOf(path),
        family: ModelFamilyUtils.detectFamilyName(path),
        fileType: lower.endsWith('.litertlm') ? 'litertlm' : 'task',
        sha256: picked.sha256,
      );
      final current = await AppSettingsStore.instance.load();
      await AppSettingsStore.instance.save(
        current.copyWith(activeModelId: entry.id, firstLaunchCompleted: true),
      );
      if (!mounted) return;
      widget.onCompleted();
    } catch (e) {
      if (mounted) context.showFloatingSnack(t.commonErrorWith('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goStep2() {
    setState(() => _step = 1);
    final t = AppLocalizations.of(context);
    SemanticsService.announce(t.onboardingAnnounceStep2, TextDirection.ltr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _busy,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _step == 0
                ? _WelcomeStep(
                    key: const ValueKey('welcome'),
                    onContinue: _goStep2,
                  )
                : _ImportStep(
                    key: const ValueKey('import'),
                    busy: _busy,
                    onPick: _pickAndFinish,
                    onBack: () => setState(() => _step = 0),
                  ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 1),
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
                          Icons.smart_toy_outlined,
                          color: cs.onPrimaryContainer,
                          size: 56,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      t.onboardingWelcomeTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.onboardingWelcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  _Feature(
                    icon: Icons.cloud_off_outlined,
                    title: t.onboardingFeatureOfflineTitle,
                    text: t.onboardingFeatureOfflineText,
                  ),
                  _Feature(
                    icon: Icons.lock_outline,
                    title: t.onboardingFeatureCryptoTitle,
                    text: t.onboardingFeatureCryptoText,
                  ),
                  _Feature(
                    icon: Icons.local_fire_department_outlined,
                    title: t.onboardingFeaturePanicTitle,
                    text: t.onboardingFeaturePanicText,
                  ),
                  _Feature(
                    icon: Icons.code,
                    title: t.onboardingFeatureOpenSourceTitle,
                    text: t.onboardingFeatureOpenSourceText,
                  ),
                  const Spacer(flex: 2),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(t.commonContinue),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    child: Text(t.onboardingAboutLink),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImportStep extends StatelessWidget {
  const _ImportStep({
    super.key,
    required this.busy,
    required this.onPick,
    required this.onBack,
  });

  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: busy ? null : onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(t.commonBack),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ExcludeSemantics(
                    child: Center(
                      child: Icon(
                        Icons.upload_file_outlined,
                        size: 72,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      t.onboardingImportTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(t.onboardingImportSubtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.onboardingImportCardTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(t.onboardingImportCardBody),
                          const SizedBox(height: 8),
                          Text(
                            t.onboardingImportCardSource,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 16),
                  Semantics(
                    label: busy ? t.onboardingImportSaving : null,
                    button: true,
                    child: FilledButton.icon(
                      onPressed: busy ? null : onPick,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(
                        busy ? t.onboardingImportSaving : t.onboardingImportSelectAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    child: Text(t.onboardingAboutLink),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(text, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
