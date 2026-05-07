import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/rag/rag_service.dart';
import 'services/storage/app_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  // Lance le chargement de l'index RAG persisté en tâche de fond (silencieux
  // si vide). Pas de `await` ici pour ne pas bloquer le démarrage de l'UI.
  // Les chemins qui dépendent du bootstrap (chat _send, DocumentsScreen)
  // re-appellent `bootstrap()` — idempotent grâce au flag `_booted`.
  unawaited(RagService.instance.bootstrap());
  runApp(const AiTechApp());
}

class AiTechApp extends StatefulWidget {
  const AiTechApp({super.key});

  /// Exposé pour permettre au mode panique (cf. `SettingsScreen._triggerPanic`)
  /// de forcer une re-évaluation du flag `firstLaunchCompleted` après wipe —
  /// sinon le `popUntil` + `pushReplacementNamed('/')` ré-affiche le
  /// `FutureBuilder` mais avec l'ancien `_firstLaunchDone` (true) et zappe
  /// l'onboarding qui devrait pourtant ré-apparaître.
  static void refreshFirstLaunch() => _AiTechAppState._instance?._refresh();

  @override
  State<AiTechApp> createState() => _AiTechAppState();
}

class _AiTechAppState extends State<AiTechApp> {
  static _AiTechAppState? _instance;

  Future<bool>? _firstLaunchDone;

  @override
  void initState() {
    super.initState();
    _instance = this;
    _firstLaunchDone = _checkFirstLaunch();
  }

  @override
  void dispose() {
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }

  Future<bool> _checkFirstLaunch() async {
    final settings = await AppSettingsStore.instance.load();
    return settings.firstLaunchCompleted;
  }

  void _refresh() {
    final f = _checkFirstLaunch();
    setState(() => _firstLaunchDone = f);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      routes: {
        '/': (_) => FutureBuilder<bool>(
          future: _firstLaunchDone,
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!snap.data!) {
              return OnboardingScreen(onCompleted: _refresh);
            }
            return const ChatScreen();
          },
        ),
      },
    );
  }
}
