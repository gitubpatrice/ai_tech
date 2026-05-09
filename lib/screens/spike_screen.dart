import 'package:file_picker/file_picker.dart';
import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/bench_result.dart';
import '../services/bench_service.dart';
import '../services/chat_service.dart';
import '../services/llm_service.dart';

/// Écran de spike technique pour AI Tech.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  final _llm = LlmService.instance;
  late final _bench = BenchService(_llm);
  TextEditingController? _promptCtrl;

  String? _modelPath;
  bool _loading = false;
  bool _running = false;
  String _status = '';
  String _partial = '';
  BenchResult? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_promptCtrl == null) {
      final t = AppLocalizations.of(context);
      _promptCtrl = TextEditingController(text: t.spikePromptDefault);
      _status = t.spikeNoModel;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _promptCtrl?.dispose();
    super.dispose();
  }

  Future<void> _pickAndLoad() async {
    final t = AppLocalizations.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    if (!path.toLowerCase().endsWith('.task')) {
      _setStatus(t.spikeWrongFormat);
      return;
    }

    setState(() {
      _loading = true;
      _modelPath = path;
      _status = t.spikeInstalling;
      _result = null;
      _partial = '';
    });

    try {
      await ChatService.instance.unloadModel();
      await _llm.installFromFile(path);
      _setStatus(t.spikeLoadingHint);
      await _llm.load();
      _setStatus(t.spikeReady);
    } catch (e) {
      _setStatus(t.commonErrorWith('$e'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runBench() async {
    final t = AppLocalizations.of(context);
    if (!_llm.isLoaded || _running) return;
    final prompt = _promptCtrl?.text.trim() ?? '';
    if (prompt.isEmpty) return;

    setState(() {
      _running = true;
      _partial = '';
      _result = null;
      _status = t.spikeGenerating;
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
        _status = t.spikeFinished;
      });
    } catch (e) {
      _setStatus(t.spikeGenerationError('$e'));
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
    final t = AppLocalizations.of(context);
    return PopScope(
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _llm.dispose();
        if (!context.mounted) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.spikeTitle),
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
                if (_promptCtrl != null)
                  TextField(
                    controller: _promptCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: t.spikePromptLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _llm.isLoaded && !_running && !_loading
                      ? _runBench
                      : null,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_running ? t.spikeRunning : t.spikeRun),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: _StatusBanner(text: _status),
                ),
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
    final t = AppLocalizations.of(context);
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
                        ? t.spikeNoModelSelected
                        : PathUtils.fileName(modelPath!),
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: loading ? null : onPick,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(loading ? t.commonLoading : t.spikeChooseTask),
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
      child: Text(text, style: theme.textTheme.bodyMedium),
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
    final t = AppLocalizations.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                t.spikeMetricsTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            _row(
              t.spikeMetricFirstToken,
              t.spikeMetricFirstTokenValue(result.firstTokenMs),
            ),
            _row(
              t.spikeMetricTotalDuration,
              t.spikeMetricFirstTokenValue(result.totalMs),
            ),
            _row(t.spikeMetricTokens, '${result.tokenCount}'),
            _row(t.spikeMetricChars, '${result.charCount}'),
            _row(
              t.spikeMetricTokensPerSec,
              result.tokensPerSecond.toStringAsFixed(2),
            ),
            _row(
              t.spikeMetricCharsPerSec,
              result.charsPerSecond.toStringAsFixed(1),
            ),
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
