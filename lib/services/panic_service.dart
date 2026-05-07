import 'package:flutter_gemma/flutter_gemma.dart';

import 'chat_service.dart';
import 'crypto/secret_key.dart';
import 'rag/rag_service.dart';
import 'storage/app_settings_store.dart';
import 'storage/document_store.dart';
import 'storage/encrypted_chat_store.dart';
import 'storage/model_registry.dart';

/// Mode panique : efface en bloc toutes les données utilisateur de l'app.
///
/// Comportement :
///   1. Coupe la session de chat avec **timeout dur** (la génération native
///      MediaPipe n'a pas d'API d'annulation ; un dispose en pleine génération
///      peut bloquer indéfiniment).
///   2. Désinstalle le modèle MediaPipe actif (libère son fichier interne).
///   3. Vide l'éventuel index RAG en mémoire.
///   4. Supprime tous les fichiers `chats/*.aichat`.
///   5. Vide le registre de modèles (mais garde les fichiers `.task` sur sdcard,
///      qui appartiennent à l'utilisateur).
///   6. Reset les paramètres applicatifs.
///   7. Supprime la clé AES du Keystore : tout chat oublié devient
///      définitivement illisible, même par récupération forensique.
///
/// L'opération n'est PAS confirmée par cette classe : c'est à l'UI d'afficher
/// une boîte de dialogue de confirmation avant d'appeler [trigger].
class PanicService {
  PanicService._();
  static final PanicService instance = PanicService._();

  static const Duration _disposeTimeout = Duration(milliseconds: 500);

  Future<void> trigger() async {
    // 1. Coupe le chat avec timeout dur.
    try {
      await ChatService.instance.dispose().timeout(_disposeTimeout);
    } catch (_) {
      /* on continue, peu importe l'état natif */
    }

    // 2. Désinstalle le modèle MediaPipe actif (best-effort).
    try {
      final installed = await FlutterGemma.listInstalledModels();
      for (final id in installed) {
        await FlutterGemma.uninstallModel(id);
      }
    } catch (_) {
      /* on continue */
    }

    // 3, 4, 5, 6. Wipe stockages — chaque échec n'arrête pas la suite.
    final wipes = <Future<void> Function()>[
      // RagService.wipeAll efface l'index RAM ET les .aidoc chiffrés.
      RagService.instance.wipeAll,
      // Sécurité défensive : on fait un deleteAll du DocumentStore au cas
      // où le RagService aurait été partiellement initialisé.
      DocumentStore.instance.deleteAll,
      EncryptedChatStore.instance.deleteAll,
      ModelRegistry.instance.wipe,
      AppSettingsStore.instance.wipe,
    ];
    for (final w in wipes) {
      try {
        await w();
      } catch (_) {
        /* on continue */
      }
    }

    // 7. Clé AES en dernier — sans elle, plus rien ne peut être déchiffré
    //    même si une copie d'un .aichat traîne.
    try {
      await SecretKey.instance.wipe();
    } catch (_) {
      /* on continue */
    }
  }
}
