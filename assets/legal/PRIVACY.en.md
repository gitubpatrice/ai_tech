# Privacy policy — AI Tech

**Version 0.6.1 — May 2026**

## In one sentence

AI Tech does not collect, transmit or store any data on remote servers. Everything stays on your phone.

## Detail

### Data processed

- **Your messages and the model's replies**: generated and kept exclusively on your phone, in a private app-scoped storage area, **encrypted with AES-256-GCM** using a unique key generated locally and stored in the **Android Keystore**.
- **The AI model (`.task` / `.litertlm`)**: file downloaded by your **system browser** from Kaggle or HuggingFace (the "Download the model" button merely fires an `ACTION_VIEW` intent; AI Tech has no Internet permission and downloads nothing itself), then read directly from your storage. AI Tech sends no data to the model publisher.
- **Settings (temperature, length, active model)**: stored in the app's local preferences, in clear (no sensitive data).

### Data NOT processed

- **No telemetry**, no analytics, no third-party crash reporter.
- **No advertising**, no tracker.
- **No user account**, no online service connection.

### Android permissions requested

AI Tech requests **NO `INTERNET` permission**. The app is technically unable to communicate with any remote server. This absence can be verified in the `AndroidManifest.xml` of the source repository.

The only permissions are those induced by the Android file picker so you can select the model file.

### Panic mode

The **Settings → Panic mode** menu wipes in bulk and atomically:
- all encrypted conversations,
- the encryption key (any conversation backed up elsewhere becomes unreadable),
- the settings,
- the registered models list (the `.task` files you downloaded to public storage are not touched — it is up to you to delete them if you wish).

### Your rights

All data being strictly local, the GDPR applies between you and your phone. You may at any time:
- manually export your conversations (feature planned for a future version),
- delete all data via panic mode,
- uninstall the app — Android will automatically delete all private data.

### Subprocessors

**None.** AI Tech uses no third-party service at runtime.

### AI models

The `.task` models you load stay on your phone. Their usage license depends on their publisher (Google for Gemma, Alibaba for Qwen, Microsoft for Phi, Meta for Llama…). AI Tech merely runs them locally through the MediaPipe LLM Inference library.

### Contact

For any question: **contact@files-tech.com**

---

AI Tech is published by a **French sole proprietorship** (SIRET available on request). Source code published under **Apache 2.0** license.
