import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/chat_service.dart';
import 'services/rag/rag_service.dart';
import 'services/storage/app_settings_store.dart';

/// Notifier global du mode de thème (clair / sombre / système).
/// Persisté en SharedPreferences sous [prefKeyThemeMode].
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

/// Notifier global de la locale. `null` = suivre la locale système.
/// Persisté en SharedPreferences sous [prefKeyLocale].
final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

const String prefKeyLocale = 'app_locale';
const String prefKeyThemeMode = 'theme_mode';

Locale? parseLocale(String? code) {
  switch (code) {
    case 'fr':
      return const Locale('fr');
    case 'en':
      return const Locale('en');
    default:
      return null;
  }
}

String localeToString(Locale? l) => l == null ? 'system' : l.languageCode;

ThemeMode parseThemeMode(String? s) {
  switch (s) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

String themeModeToString(ThemeMode m) {
  switch (m) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();

  // Pré-charge thème + locale avant runApp pour éviter un flash visuel.
  final prefs = await SharedPreferences.getInstance();
  themeNotifier.value = parseThemeMode(prefs.getString(prefKeyThemeMode));
  localeNotifier.value = parseLocale(prefs.getString(prefKeyLocale));

  // Lance le chargement de l'index RAG persisté en tâche de fond (silencieux
  // si vide). Pas de `await` ici pour ne pas bloquer le démarrage de l'UI.
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
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, themeMode, _) => ValueListenableBuilder<Locale?>(
        valueListenable: localeNotifier,
        builder: (_, locale, _) {
          // F1/D3 v0.6.1 — propage la locale au ChatService pour qu'il
          // sélectionne le system prompt FR ou EN au prochain unloadModel
          // → installAndLoad. Pour les sessions actives, la mise à jour
          // prend effet lors du prochain reset/swap.
          ChatService.instance.setLocale(
            locale?.languageCode ??
                WidgetsBinding.instance.platformDispatcher.locale.languageCode,
          );
          return MaterialApp(
            title: 'AI Tech',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
            ),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
        },
      ),
    );
  }
}
