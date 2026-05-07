# Politique de confidentialité — AI Tech

**Version** : v0.4.3 — 2026-05-07
**Éditeur** : Files Tech / Patrice Haltaya
**Contact** : contact@files-tech.com

---

## TL;DR

AI Tech ne collecte, n'envoie et ne stocke à distance **aucune
donnée**. L'application n'a pas la permission Android d'accéder à
Internet (vérifiable dans `AndroidManifest.xml` :
`<uses-permission android:name="android.permission.INTERNET"
tools:node="remove" />`).

---

## 1. Données collectées

**Aucune.** Pas de serveur, pas de télémétrie, pas de crash reporter
tiers (Firebase, Sentry, Crashlytics), pas d'identifiant publicitaire,
pas de mesure d'audience.

## 2. Données stockées localement

Sur votre téléphone, dans la zone privée de l'application
(`/data/data/com.aitech.ai_tech`, isolée par Android) :

- Historique des conversations (chiffré AES-256-GCM, clé scellée par
  l'Android Keystore — hardware-backed sur téléphones modernes)
- Préférences (modèle actif, température, longueur de réponse)
- Index RAG dérivé de vos documents importés (n'est jamais transmis)

Les modèles `.task` / `.litertlm` que vous chargez restent là où vous
les avez placés (stockage public ou privé selon votre choix).

## 3. Modèles d'intelligence artificielle

Vous les téléchargez vous-même depuis les sources officielles : Gemma
(Google Kaggle, licence Gemma), Qwen, Phi, Llama, DeepSeek. Le bouton
« Télécharger le modèle » de l'app ouvre simplement Kaggle ou
HuggingFace dans votre **navigateur système** (intent `ACTION_VIEW`) :
c'est votre navigateur qui télécharge, jamais AI Tech (qui n'a pas la
permission Internet). AI Tech ne fait qu'exécuter le modèle localement
via MediaPipe LLM Inference. Aucun modèle ni aucune sortie n'est
transmis à l'éditeur ni à un tiers.

## 4. Permissions Android

Aucune permission sensible. Les imports de fichiers (modèle, documents
RAG) passent par le Storage Access Framework qui ne nécessite pas de
permission globale. Notamment **pas de** : `INTERNET`,
`ACCESS_NETWORK_STATE`, `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`.

## 5. Mode panique

Réglages → Mode panique : efface en une opération atomique l'historique
chiffré, la clé Keystore, les préférences, l'index RAG. Action
irréversible.

## 6. Vos droits (RGPD)

Toutes les données étant strictement locales, le RGPD s'applique entre
vous et votre téléphone. Vous pouvez à tout moment effacer via le mode
panique ou en désinstallant l'application.

## 7. Licence

Code source intégral publié sous **Apache License 2.0** :
https://github.com/gitubpatrice/ai_tech
