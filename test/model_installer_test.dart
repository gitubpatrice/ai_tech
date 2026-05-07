import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ai_tech/services/storage/model_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mock de path_provider qui renvoie un répertoire temporaire
/// pour `getApplicationSupportDirectory()`.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;

  @override
  Future<String?> getTemporaryPath() async => root.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmpRoot;

  setUp(() {
    tmpRoot = Directory.systemTemp.createTempSync('ai_tech_installer_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmpRoot);
  });

  tearDown(() {
    try {
      tmpRoot.deleteSync(recursive: true);
    } catch (_) {/* best-effort */}
  });

  test(
    'installFromSafFile copie byte-à-byte, calcule SHA-256, purge le .tmp',
    () async {
      // ~10 Mo de bytes pseudo-random (seed fixe pour repro).
      final rng = Random(42);
      const totalSize = 10 * 1024 * 1024;
      final bytes = Uint8List(totalSize);
      for (var i = 0; i < totalSize; i++) {
        bytes[i] = rng.nextInt(256);
      }

      final source = File('${tmpRoot.path}${Platform.pathSeparator}source.task')
        ..writeAsBytesSync(bytes);

      final expectedSha = sha256.convert(bytes).toString().toLowerCase();

      String? finalPath;
      String? finalHash;
      var lastCopied = 0;
      var lastTotal = 0;
      var progressEvents = 0;

      await for (final ev in ModelInstaller.instance.installFromSafFile(
        source.path,
        'my_model.task',
      )) {
        lastCopied = ev.copied;
        lastTotal = ev.total;
        if (ev.finalPath != null) {
          finalPath = ev.finalPath;
          finalHash = ev.sha256;
        } else {
          progressEvents++;
        }
      }

      // Hash + path remontés.
      expect(finalPath, isNotNull);
      expect(finalHash, equals(expectedSha));
      expect(lastCopied, equals(totalSize));
      expect(lastTotal, equals(totalSize));
      expect(progressEvents, greaterThanOrEqualTo(1));

      // Fichier copié dans le sandbox + contenu identique.
      final dest = File(finalPath!);
      expect(dest.existsSync(), isTrue);
      expect(dest.lengthSync(), equals(totalSize));
      expect(dest.readAsBytesSync(), equals(bytes));

      // .tmp purgé.
      final tmp = File('${dest.path}.tmp');
      expect(tmp.existsSync(), isFalse);

      // Path = <appSupport>/models/my_model.task
      expect(
        dest.path,
        endsWith('models${Platform.pathSeparator}my_model.task'),
      );
    },
  );

  test('installFromSafFile sanitize le filename (path traversal)', () async {
    final source = File('${tmpRoot.path}${Platform.pathSeparator}src.bin')
      ..writeAsBytesSync(List<int>.filled(1024, 7));

    String? finalPath;
    await for (final ev in ModelInstaller.instance.installFromSafFile(
      source.path,
      '../../etc/evil.task',
    )) {
      if (ev.finalPath != null) finalPath = ev.finalPath;
    }

    expect(finalPath, isNotNull);
    // Pas de remontée hors du dossier models/.
    expect(finalPath, contains('models'));
    expect(finalPath, isNot(contains('..')));
  });
}
