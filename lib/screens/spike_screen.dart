import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/bench_result.dart';
import '../services/bench_service.dart';
import '../services/llm_service.dart';

/// Écran de spike technique pour AI Tech.
///
/// Permet à l'utilisateur de :
///   1. Charger un modèle `.task` (Gemma 2 2B / Gemma 3 1B) depuis le stockage.
///   2. Lancer un prompt de test.
///   3. Lire les métriques (first-token latency, tokens/s) pour valider la
///      faisabilité sur les devices cibles (S24, S9, Redmi 9C).
///
/// Aucune donnée ne sort du téléphone : pas de réseau, pas de télémétrie.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final _llm = LlmService.instance;
  late final _bench = BenchService(_llm);
  final _promptCtrl = TextEditingController(
    text: 'Explique en 3 phrases ce qu\'est la photosynthèse.',
  );

  String? _modelPath;
  bool _loading = false;
  bool _running = false;
  String _status = 'Aucun modèle chargé.';
  String _partial = '';
  BenchResult? _result;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _llm.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoad() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.task')) {
      _setStatus('Format non supporté : choisissez un fichier .task');
      return;
    }

    setState(() {
      _loading = true;
      _modelPath = path;
      _status = 'Installation du modèle…';
      _result = null;
      _partial = '';
    });

    try {
      await _llm.installFromFile(path);
      _setStatus('Chargement en mémoire (peut prendre 10–20 s)…');
      await _llm.load();
      _setStatus('Modèle prêt.');
    } catch (e) {
      _setStatus('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runBench() async {
    if (!_llm.isLoaded || _running) return;
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _running = true;
      _partial = '';
      _result = null;
      _status = 'Génération en cours…';
    });

    try {
      final res = await _bench.run(
        prompt,
        onPartial: (s) {
          if (!mounted) return;
          setState(() => _partial = s);
        },
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _status = 'Terminé.';
      });
    } catch (e) {
      _setStatus('Erreur génération : $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  void _setStatus(String s) {
    if (!mounted) return;
    setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tech — Spike'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModelCard(
                modelPath: _modelPath,
                isLoaded: _llm.isLoaded,
                loading: _loading,
                onPick: _pickAndLoad,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _promptCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    _llm.isLoaded && !_running && !_loading ? _runBench : null,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_running ? 'Génération…' : 'Lancer'),
              ),
              const SizedBox(height: 16),
              _StatusBanner(text: _status),
              if (_partial.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ResponseCard(text: _partial, theme: theme),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                _MetricsCard(result: _result!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.modelPath,
    required this.isLoaded,
    required this.loading,
    required this.onPick,
  });

  final String? modelPath;
  final bool isLoaded;
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLoaded ? Icons.check_circle : Icons.upload_file,
                  color: isLoaded
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    modelPath == null
                        ? 'Aucun modèle sélectionné'
                        : modelPath!.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loading ? null : onPick,
              child: Text(loading ? 'Chargement…' : 'Choisir un .task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: theme.textTheme.bodySmall),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({required this.text, required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SelectableText(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.result});
  final BenchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Métriques', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('First token', '${result.firstTokenMs} ms'),
            _row('Durée totale', '${result.totalMs} ms'),
            _row('Tokens (chunks)', '${result.tokenCount}'),
            _row('Caractères', '${result.charCount}'),
            _row('Tokens/s', result.tokensPerSecond.toStringAsFixed(2)),
            _row('Chars/s', result.charsPerSecond.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(k)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
