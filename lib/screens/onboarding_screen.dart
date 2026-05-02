import 'package:flutter/material.dart';

import '../services/storage/app_settings_store.dart';
import '../services/storage/model_registry.dart';
import 'about_screen.dart';
import 'model_picker_screen.dart';

/// Premier lancement : explique le principe, fait choisir un modèle.
///
/// 2 étapes :
///   1. Bienvenue + 4 garanties (offline, chiffré, panique, open-source).
///   2. Sélection d'un fichier `.task` ou `.litertlm` → enregistrement
///      dans le registre + marquage actif + `firstLaunchCompleted = true`.
///
/// L'utilisateur peut consulter À propos / Politique de confidentialité
/// avant de continuer (lien discret en bas).
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
    final path = await ModelPickerScreen.pick(context);
    if (path == null || !mounted) return;
    final lower = path.toLowerCase();

    setState(() => _busy = true);
    try {
      final entry = await ModelRegistry.instance.register(
        path: path,
        displayName: _displayNameOf(path),
        family: _detectFamily(path),
        fileType: lower.endsWith('.litertlm') ? 'litertlm' : 'task',
      );
      final current = await AppSettingsStore.instance.load();
      await AppSettingsStore.instance.save(
        current.copyWith(
          activeModelId: entry.id,
          firstLaunchCompleted: true,
        ),
      );
      if (!mounted) return;
      widget.onCompleted();
    } catch (e) {
      _toast('Erreur : $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _displayNameOf(String path) {
    final base = path.split(RegExp(r'[\\/]')).last;
    return base.replaceAll(RegExp(r'\.(task|litertlm)$'), '');
  }

  String _detectFamily(String path) {
    final p = path.toLowerCase();
    if (p.contains('gemma')) return 'gemma';
    if (p.contains('qwen')) return 'qwen';
    if (p.contains('phi')) return 'phi';
    if (p.contains('llama')) return 'llama';
    if (p.contains('deepseek')) return 'deepseek';
    return 'gemma';
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
                    onContinue: () => setState(() => _step = 1),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 1),
          Center(
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
          const SizedBox(height: 24),
          Text(
            'Bienvenue dans AI Tech',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Un assistant IA qui tourne entièrement sur votre téléphone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          const _Feature(
            icon: Icons.cloud_off_outlined,
            title: '100 % hors-ligne',
            text: 'Aucune connexion Internet. L\'app n\'a même pas la '
                'permission d\'en faire.',
          ),
          const _Feature(
            icon: Icons.lock_outline,
            title: 'Conversations chiffrées',
            text: 'AES-256-GCM avec clé dans le Android Keystore.',
          ),
          const _Feature(
            icon: Icons.local_fire_department_outlined,
            title: 'Mode panique',
            text: 'Efface clé et historique en un appui. Définitif.',
          ),
          const _Feature(
            icon: Icons.code,
            title: 'Code source ouvert',
            text: 'Apache 2.0. Vérifiez vous-même nos promesses.',
          ),
          const Spacer(flex: 2),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Continuer'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            child: const Text('À propos · Confidentialité'),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: busy ? null : onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour'),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Icon(
              Icons.upload_file_outlined,
              size: 72,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Choisir un modèle',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Téléchargez un modèle au format .task ou .litertlm '
            '(Gemma, Qwen, Phi, Llama…) puis sélectionnez-le ici.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            color: cs.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommandation',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Gemma 3 1B (int4) — 554 Mo, excellent en français, '
                    'très rapide même sur téléphones milieu de gamme.',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Source : Kaggle → google/gemma-3 → tfLite → '
                    'gemma3-1b-it-int4',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
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
            label: Text(busy ? 'Enregistrement…' : 'Sélectionner un modèle'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
            child: const Text('À propos · Confidentialité'),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 22),
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
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
