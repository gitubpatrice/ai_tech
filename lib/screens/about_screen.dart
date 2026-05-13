import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';

/// Écran "À propos" : présentation de l'app, version, licences, support, légal.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (e) {
      if (kDebugMode) debugPrint('about: PackageInfo failed: $e');
      if (!mounted) return;
      setState(() => _version = '?.?.?');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(t.aboutTitle),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(version: _version),
              const SizedBox(height: 24),
              _PromiseCard(),
              const SizedBox(height: 16),
              _HowItWorksCard(),
              const SizedBox(height: 24),
              LegalSupportSections(
                appName: 'AI Tech',
                version: _version,
                privacyAsset: isEn
                    ? 'assets/legal/PRIVACY.en.md'
                    : 'assets/legal/PRIVACY.fr.md',
                termsAsset: isEn
                    ? 'assets/legal/TERMS.en.md'
                    : 'assets/legal/TERMS.fr.md',
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  t.aboutLicense,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.version});
  final String version;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/icon/ai_tech_icon.png',
              width: 96,
              height: 96,
              // U5 v0.9.1 — `cacheWidth` borné (2× pour HiDPI) : sans ça,
              // le PNG source 1024×1024 était décodé à pleine résolution
              // pour afficher 96 dp → ~3-4 Mo RAM permanent inutile.
              cacheWidth: 192,
              cacheHeight: 192,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            'AI Tech',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          t.aboutVersion(version),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: cs.outline),
        ),
      ],
    );
  }
}

class _PromiseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text(
                    t.aboutPromiseTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Bullet(text: t.aboutPromise1),
            _Bullet(text: t.aboutPromise2),
            _Bullet(text: t.aboutPromise3),
            _Bullet(text: t.aboutPromise4),
            _Bullet(text: t.aboutPromise5),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Semantics(
                  header: true,
                  child: Text(
                    t.aboutHowTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t.aboutHow1),
            const SizedBox(height: 8),
            Text(t.aboutHow2),
            const SizedBox(height: 12),
            Text(t.aboutHow3),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 6),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
