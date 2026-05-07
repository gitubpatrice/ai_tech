import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Écran "À propos" : présentation de l'app, version, licences, support, légal.
///
/// Utilise [LegalSupportSections] partagé entre toutes les apps Files Tech
/// pour rester cohérent (mêmes liens contact, même rendu Markdown des PRIVACY
/// et TERMS, mêmes garanties anti-XSS sur les schemes d'URL).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  /// Version lue depuis pubspec via package_info_plus — source unique pour
  /// éviter qu'une string hardcodée ici et le pubspec divergent.
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // Try/catch défensif : sur certains devices (modes particuliers,
    // installations corrompues), `PackageInfo.fromPlatform()` peut throw
    // un PlatformException. On dégrade proprement plutôt que de laisser
    // l'écran "À propos" planter au démarrage.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
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
                privacyAsset: 'assets/legal/PRIVACY.fr.md',
                termsAsset: 'assets/legal/TERMS.fr.md',
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Apache 2.0 — Files Tech',
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
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/icon/ai_tech_icon.png',
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'AI Tech',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Version $version',
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
                Text(
                  'Notre engagement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _Bullet(
              text:
                  '100 % hors-ligne — la permission Internet est retirée '
                  'du manifest (tools:node="remove"). Aucun cloud, aucun compte.',
            ),
            const _Bullet(
              text:
                  'Conversations chiffrées AES-256-GCM avec une clé '
                  'unique stockée dans le Android Keystore.',
            ),
            const _Bullet(
              text: 'Mode panique : efface clé + historique en un appui.',
            ),
            const _Bullet(
              text: 'Code source intégralement publié sous Apache 2.0.',
            ),
            const _Bullet(
              text: 'Aucune télémétrie, aucun tracker, aucune publicité.',
            ),
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
                Text(
                  'Comment ça marche',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'AI Tech exécute un modèle de langage open-source (Gemma, Qwen, '
              'Phi, Llama…) directement sur votre téléphone via la bibliothèque '
              'MediaPipe LLM Inference de Google.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous téléchargez le modèle de votre choix au format .task ou '
              '.litertlm depuis Kaggle ou HuggingFace, puis vous l\'importez '
              'dans l\'application. Aucune donnée n\'est envoyée à l\'éditeur '
              'du modèle ni à un service tiers.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Mises à jour : AI Tech ne contacte aucun serveur de mise à '
              'jour, contrairement aux autres apps Files Tech, par cohérence '
              'avec la promesse offline. Les nouvelles versions sont '
              'publiées sur GitHub Releases et F-Droid — vous décidez quand '
              'mettre à jour.',
            ),
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
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
