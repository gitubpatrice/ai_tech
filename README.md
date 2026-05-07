# AI Tech

**Assistant IA 100 % on-device — Files Tech**

[![Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-7%2B-3DDC84?logo=android)](https://android.com)

AI Tech est un assistant IA conversationnel **100 % on-device Android** : Gemma 3 1B int4 (ou Qwen / Phi / Llama / DeepSeek) exécuté localement via **MediaPipe LLM Inference**, aucune connexion Internet, chats chiffrés. C'est la 4ᵉ application de la suite **Files Tech** (après PDF Tech, Read Files Tech, Pass Tech).

## Engagement

- **100 % hors-ligne** — la permission `INTERNET` est **explicitement retirée** du manifest (`tools:node="remove"`). L'app est techniquement incapable de communiquer avec un serveur distant. Vérifiable dans `android/app/src/main/AndroidManifest.xml`.
- **Conversations chiffrées** AES-256-GCM, clé maître scellée par le **Android Keystore**, persistance via `EncryptedJsonStore<T>` (écriture atomique avec rename, AAD bindée à l'identifiant de session).
- **Mode panique** — efface clé + historique + modèles enregistrés + paramètres + index RAG en un appui. Sans la clé, les chats copiés ailleurs deviennent illisibles.
- **Aucune télémétrie**, aucun crash reporter tiers, aucune publicité.
- **Code source ouvert** sous licence Apache 2.0.

## Fonctionnalités

- **Chat conversationnel** avec un modèle local (Gemma 3 / Qwen / Phi / Llama / DeepSeek), streaming token par token.
- **Multi-conversations** chiffrées, renommables, exportables.
- **Spike** — banc d'essai intégré pour mesurer la vitesse d'inférence (tok/s, time-to-first-token) sur le téléphone.
- **RAG sémantique optionnel** — import de documents, indexation par mots-clés, contexte injecté dans le prompt avec sanitization anti-injection.
- **Mode panique** — wipe atomique avec timeout dur sur la génération native.
- **Onboarding scrollable** adapté aux petits écrans (POCO C75 etc.).
- **Téléchargement modèle via le navigateur système** — bouton "Télécharger le modèle" → intent `ACTION_VIEW` vers Kaggle ou HuggingFace. L'app ne télécharge **rien** elle-même (elle n'a pas la permission `INTERNET`).

## Modèles supportés

L'app **n'embarque pas** de modèle d'IA (l'APK reste léger ~50 Mo). L'utilisateur télécharge le modèle de son choix au format **MediaPipe `.task`** ou **LiteRT `.litertlm`** :

| Modèle | Taille | Qualité FR | Source |
|---|---|---|---|
| **Gemma 3 1B IT int4** ⭐ recommandé | 554 Mo | excellente | [Kaggle `google/gemma-3` → tfLite → gemma3-1b-it-int4](https://www.kaggle.com/models/google/gemma-3/tfLite/gemma3-1b-it-int4) |
| Qwen 2.5 1.5B Instruct q8 | 1.57 Go | correcte | [HuggingFace `litert-community/Qwen2.5-1.5B-Instruct`](https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct) |
| Phi-4 mini | 3.8 Go | bonne | [HuggingFace `litert-community/Phi-4-mini-instruct`](https://huggingface.co/litert-community/Phi-4-mini-instruct) |
| DeepSeek-R1 Distill 1.5B | ~1.5 Go | correcte | [HuggingFace `litert-community/DeepSeek-R1-Distill-Qwen-1.5B`](https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B) |

Le format de prompt (Gemma natif vs ChatML pour Qwen/Phi/Llama vs DeepSeek) est détecté automatiquement à partir du nom de fichier.

## Performance mesurée

Sur **Gemma 3 1B int4** :

| Device | RAM | First token | Tokens/s | Verdict |
|---|---|---|---|---|
| Galaxy S24 FE (2024) | 8 Go | 253 ms | **43.1** | excellent |
| Galaxy S9 (2018) | 4 Go | 3.3 s | **9.8** | viable |

À titre de repère : ChatGPT cloud tourne à 30-50 tok/s. AI Tech sur S24 FE est dans la même classe d'UX, **sans connexion réseau**.

## Architecture

```
lib/
├── main.dart                 — initialisation flutter_gemma + routing onboarding/chat
├── models/
│   ├── app_settings.dart     — température / topK / maxTokens persistés
│   ├── chat_message.dart     — message individuel
│   ├── chat_session.dart     — conversation (id, messages, dates)
│   ├── model_entry.dart      — métadonnées d'un modèle enregistré
│   └── model_family.dart     — enum + helpers de prompt par famille (Gemma/Qwen/Phi/Llama/DeepSeek)
├── services/
│   ├── chat_service.dart     — wrapper InferenceChat + system prompt FR + cancel
│   ├── llm_service.dart      — wrapper single-turn pour le bench
│   ├── panic_service.dart    — wipe atomique
│   ├── crypto/
│   │   ├── secure_random.dart — Fortuna seeded par dart:math Random.secure()
│   │   ├── aes_gcm.dart       — AES-256-GCM avec AAD optionnelle
│   │   └── secret_key.dart    — clé maître dans flutter_secure_storage
│   ├── storage/
│   │   ├── app_settings_store.dart  — SharedPreferences
│   │   ├── encrypted_chat_store.dart — chats AES-GCM (magic AIC1 + AAD)
│   │   └── model_registry.dart       — liste des modèles enregistrés
│   └── rag/
│       ├── document.dart      — Document + Chunk
│       ├── rag_indexer.dart   — interface
│       └── keyword_indexer.dart — BM25 simplifié (skeleton, pas branché v0.3)
└── screens/
    ├── chat_screen.dart       — conversation + streaming via ValueNotifier
    ├── onboarding_screen.dart — premier lancement
    ├── settings_screen.dart   — paramètres + modèles + panique
    ├── about_screen.dart      — version + légal + support
    ├── model_picker_screen.dart — picker custom Files Tech
    └── spike_screen.dart      — bench tok/s
```

## Sécurité

Audit complet effectué (mai 2026) : voir détails dans [SECURITY.md](SECURITY.md).

- ✅ `INTERNET` et `ACCESS_NETWORK_STATE` **retirés** du manifest via `tools:node="remove"` (offline strict, vérifiable).
- ✅ `libOpenCL.so` déclaré en `uses-native-library` `required="false"` (accélération GPU MediaPipe ; CPU fallback sinon — pas de risque réseau).
- ✅ AES-256-GCM avec nonce CSPRNG (Fortuna), tag 128 bits, AAD bindée à l'`id` de la session via `EncryptedJsonStore<T>`.
- ✅ Persistance atomique (write to tmp + rename) — pas d'état corrompu en cas de crash.
- ✅ Clé maître dans Android Keystore (via `flutter_secure_storage` / `EncryptedSharedPreferences`).
- ✅ `allowBackup="false"` + `dataExtractionRules` (exclusion totale) + `usesCleartextTraffic="false"`.
- ✅ `FLAG_SECURE` côté `MainActivity` (bloque screenshots, screen recording, aperçu dans la liste des apps récentes).
- ✅ **Sanitization anti-prompt-injection** du prompt utilisateur et des extraits RAG : retrait des balises de rôle Llama / ChatML / Gemma (`<start_of_turn>`, `<|im_start|>`, `[INST]`…) avant injection dans le contexte.
- ✅ Mode panique avec timeout dur (la génération native ne peut pas bloquer le wipe).
- ✅ Validation magic-bytes des fichiers `.task` / `.litertlm` avant chargement.

## Permissions

Aucune permission Internet : la promesse "100 % offline" est tenue au niveau du manifest. Les seules interactions stockage passent par le Storage Access Framework (SAF) — aucune permission globale `READ_EXTERNAL_STORAGE` ni équivalent.

## Comment installer un modèle

1. Dans l'app, appuyez sur **"Télécharger le modèle"** → un intent `ACTION_VIEW` ouvre **Kaggle** ou **HuggingFace** dans votre navigateur système. L'app n'a pas accès à Internet ; c'est le navigateur qui télécharge.
2. Téléchargez `gemma3-1b-it-int4.task` (~554 Mo) sur le téléphone.
3. Revenez dans AI Tech → **"Importer le fichier"** → le SAF picker système s'ouvre, vous sélectionnez le `.task`.
4. AI Tech valide la taille (≥ 50 Mo) et les magic-bytes (`PK` zip ou `TFL` LiteRT) avant de l'enregistrer dans le registre des modèles.

## Installation

APK signé disponible sur [GitHub Releases — latest](https://github.com/gitubpatrice/ai_tech/releases/latest). Vérifiez le SHA-256 publié dans les notes de version avant install.

## Build local

### Pré-requis
- Flutter 3.x (Dart SDK 3.11+)
- Android SDK avec NDK
- minSdk 24 (Android 7+, requis par MediaPipe LLM Inference)

### Build debug
```bash
flutter pub get
flutter build apk --debug
```

### Build release signé
Voir le workflow `.github/workflows/release.yml`. Push d'un tag `v*` déclenche un build signé automatique avec le keystore stocké en secret GitHub.

```bash
git tag v0.4.3
git push --tags
```

## Stack

- [Flutter](https://flutter.dev) 3.x
- [flutter_gemma](https://pub.dev/packages/flutter_gemma) 0.14 — wrapper MediaPipe LLM Inference
- [PointyCastle](https://pub.dev/packages/pointycastle) — AES-GCM
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) — Android Keystore
- [files_tech_core](https://github.com/gitubpatrice/files_tech_core) — code partagé suite Files Tech

## Licence

Apache 2.0 — voir [LICENSE](LICENSE).

Les modèles d'IA téléchargés depuis Kaggle / HuggingFace restent soumis à **leur propre licence** (Gemma Terms of Use, Apache 2.0 pour Qwen, MIT pour Phi…). Voir [assets/legal/THIRD_PARTY_NOTICES.md](assets/legal/THIRD_PARTY_NOTICES.md).

## Suite Files Tech

- [PDF Tech](https://github.com/gitubpatrice/PDF-TECH) — 23 outils PDF Android sans pub
- [Read Files Tech](https://github.com/gitubpatrice/READ-FILES-TECH) — couteau suisse fichiers + coffre chiffré
- [Pass Tech](https://github.com/gitubpatrice/pass_tech) — gestionnaire de mots de passe 100 % local
- **AI Tech** — assistant IA on-device (ce dépôt)

## Contact

**contact@files-tech.com** — site officiel : [files-tech.com](https://files-tech.com)
