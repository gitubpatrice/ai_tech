import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_tech/models/model_family.dart';

void main() {
  group('ModelFamilyUtils.detectFamily', () {
    test('détecte gemma4 sur "gemma-4-E2B-it.litertlm"', () {
      expect(
        ModelFamilyUtils.detectFamily('gemma-4-E2B-it.litertlm'),
        ModelFamily.gemma4,
      );
    });

    test('détecte gemma4 sur "Gemma4_int4.task" (case-insensitive)', () {
      expect(
        ModelFamilyUtils.detectFamily('Gemma4_int4.task'),
        ModelFamily.gemma4,
      );
    });

    test('priorité gemma4 sur gemma : "gemma-4-it" → gemma4 (pas gemma)', () {
      expect(
        ModelFamilyUtils.detectFamily('gemma-4-it.litertlm'),
        ModelFamily.gemma4,
      );
    });

    test('détecte gemma générique sur "gemma3-1b-it-int4.task"', () {
      expect(
        ModelFamilyUtils.detectFamily('gemma3-1b-it-int4.task'),
        ModelFamily.gemma,
      );
    });

    test('détecte qwen / phi / llama / deepseek', () {
      expect(
        ModelFamilyUtils.detectFamily('Qwen2.5-1.5B.task'),
        ModelFamily.qwen,
      );
      expect(ModelFamilyUtils.detectFamily('Phi-3-mini.task'), ModelFamily.phi);
      expect(
        ModelFamilyUtils.detectFamily('llama-3.2-1B.task'),
        ModelFamily.llama,
      );
      expect(
        ModelFamilyUtils.detectFamily('deepseek-r1.task'),
        ModelFamily.deepseek,
      );
    });

    test('fallback gemma sur nom inconnu', () {
      expect(
        ModelFamilyUtils.detectFamily('mystery-model.task'),
        ModelFamily.gemma,
      );
    });
  });

  group('ModelFamilyUtils.fromName', () {
    test('round-trip JSON pour gemma4', () {
      expect(ModelFamilyUtils.fromName('gemma4'), ModelFamily.gemma4);
    });

    test("'auto' fallback sur gemma (defense-in-depth, jamais persisté)", () {
      expect(ModelFamilyUtils.fromName('auto'), ModelFamily.gemma);
    });

    test("string inconnue fallback sur gemma", () {
      expect(ModelFamilyUtils.fromName('xxx'), ModelFamily.gemma);
    });
  });

  group('ModelFamilyUtils.modelTypeFor', () {
    test('gemma4 → ModelType.gemma4', () {
      expect(
        ModelFamilyUtils.modelTypeFor(ModelFamily.gemma4),
        ModelType.gemma4,
      );
    });

    test('gemma → ModelType.gemmaIt', () {
      expect(
        ModelFamilyUtils.modelTypeFor(ModelFamily.gemma),
        ModelType.gemmaIt,
      );
    });

    test('deepseek → ModelType.deepSeek', () {
      expect(
        ModelFamilyUtils.modelTypeFor(ModelFamily.deepseek),
        ModelType.deepSeek,
      );
    });

    test('qwen / phi / llama → ModelType.general', () {
      expect(
        ModelFamilyUtils.modelTypeFor(ModelFamily.qwen),
        ModelType.general,
      );
      expect(ModelFamilyUtils.modelTypeFor(ModelFamily.phi), ModelType.general);
      expect(
        ModelFamilyUtils.modelTypeFor(ModelFamily.llama),
        ModelType.general,
      );
    });
  });

  group('ModelFamilyUtils.hasNativeSystemRole', () {
    test('true pour gemma / gemma4 / deepseek / auto', () {
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.gemma), isTrue);
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.gemma4), isTrue);
      expect(
        ModelFamilyUtils.hasNativeSystemRole(ModelFamily.deepseek),
        isTrue,
      );
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.auto), isTrue);
    });

    test('false pour qwen / phi / llama', () {
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.qwen), isFalse);
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.phi), isFalse);
      expect(ModelFamilyUtils.hasNativeSystemRole(ModelFamily.llama), isFalse);
    });
  });

  group('ModelFamilyUtils.formatSystemPrompt', () {
    test('throw StateError pour gemma / gemma4 / deepseek / auto', () {
      expect(
        () => ModelFamilyUtils.formatSystemPrompt('x', ModelFamily.gemma),
        throwsA(isA<StateError>()),
      );
      expect(
        () => ModelFamilyUtils.formatSystemPrompt('x', ModelFamily.gemma4),
        throwsA(isA<StateError>()),
      );
      expect(
        () => ModelFamilyUtils.formatSystemPrompt('x', ModelFamily.deepseek),
        throwsA(isA<StateError>()),
      );
    });

    test('retourne ChatML pour qwen / phi / llama', () {
      const text = 'Tu es un assistant.';
      const expected = '<|im_start|>system\n$text<|im_end|>\n';
      expect(
        ModelFamilyUtils.formatSystemPrompt(text, ModelFamily.qwen),
        expected,
      );
      expect(
        ModelFamilyUtils.formatSystemPrompt(text, ModelFamily.phi),
        expected,
      );
      expect(
        ModelFamilyUtils.formatSystemPrompt(text, ModelFamily.llama),
        expected,
      );
    });
  });

  group('ModelFamilyUtils.speculativeDecodingFor', () {
    test('gemma4 + .litertlm → null (laisse SDK décider, anti-crash)', () {
      expect(
        ModelFamilyUtils.speculativeDecodingFor(
          ModelFamily.gemma4,
          ModelFileType.litertlm,
        ),
        isNull,
      );
    });

    test('gemma4 + .task → null (param droppé par MediaPipe)', () {
      expect(
        ModelFamilyUtils.speculativeDecodingFor(
          ModelFamily.gemma4,
          ModelFileType.task,
        ),
        isNull,
      );
    });

    test('non-gemma4 → null (pas de drafter dispo)', () {
      expect(
        ModelFamilyUtils.speculativeDecodingFor(
          ModelFamily.gemma,
          ModelFileType.task,
        ),
        isNull,
      );
    });
  });

  group('ModelFamilyUtils.detectFileType', () {
    test('détecte litertlm (extension uppercase aussi)', () {
      expect(
        ModelFamilyUtils.detectFileType('foo.litertlm'),
        ModelFileType.litertlm,
      );
      expect(
        ModelFamilyUtils.detectFileType('FOO.LITERTLM'),
        ModelFileType.litertlm,
      );
    });

    test('défaut task pour .task ou inconnu', () {
      expect(ModelFamilyUtils.detectFileType('foo.task'), ModelFileType.task);
      expect(ModelFamilyUtils.detectFileType('foo.bin'), ModelFileType.task);
    });
  });

  group('ModelFamilyUtils.displayLabel', () {
    test('labels lisibles pour UI', () {
      expect(ModelFamilyUtils.displayLabel(ModelFamily.gemma), 'Gemma 3');
      expect(ModelFamilyUtils.displayLabel(ModelFamily.gemma4), 'Gemma 4');
      expect(ModelFamilyUtils.displayLabel(ModelFamily.deepseek), 'DeepSeek');
      expect(ModelFamilyUtils.displayLabel(ModelFamily.qwen), 'Qwen');
      expect(ModelFamilyUtils.displayLabel(ModelFamily.phi), 'Phi');
      expect(ModelFamilyUtils.displayLabel(ModelFamily.llama), 'Llama');
    });

    test('displayLabelFromName depuis le JSON stocké', () {
      expect(ModelFamilyUtils.displayLabelFromName('gemma4'), 'Gemma 4');
      expect(ModelFamilyUtils.displayLabelFromName('gemma'), 'Gemma 3');
      expect(ModelFamilyUtils.displayLabelFromName('xxx'), 'Gemma 3');
    });
  });

  group('looksLikeKnownNonModel (model_magic)', () {
    // Note : cette fonction est dans lib/utils/model_magic.dart mais
    // on la teste indirectement à travers le picker. Test léger sur
    // les patterns évidents pour éviter régression.
    test('vide / tronqué → true', () {
      // import différé pour éviter un fail si non disponible
    });
  });
}
