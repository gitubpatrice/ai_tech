import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'screens/chat_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage/app_settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  runApp(const AiTechApp());
}

class AiTechApp extends StatefulWidget {
  const AiTechApp({super.key});

  @override
  State<AiTechApp> createState() => _AiTechAppState();
}

class _AiTechAppState extends State<AiTechApp> {
  Future<bool>? _firstLaunchDone;

  @override
  void initState() {
    super.initState();
    _firstLaunchDone = _checkFirstLaunch();
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
