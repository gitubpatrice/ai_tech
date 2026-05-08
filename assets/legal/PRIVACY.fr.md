# Politique de confidentialité — AI Tech

**Version 0.6.0 — Mai 2026**

## En une phrase

AI Tech ne collecte, ne transmet et ne stocke aucune donnée sur des serveurs distants. Tout reste sur votre téléphone.

## Détail

### Données traitées

- **Vos messages et les réponses du modèle** : générés et conservés exclusivement sur votre téléphone, dans une zone de stockage privée à l'application, **chiffrée AES-256-GCM** avec une clé unique générée localement et stockée dans le **Android Keystore**.
- **Le modèle d'IA (`.task` / `.litertlm`)** : fichier téléchargé par votre **navigateur système** depuis Kaggle ou HuggingFace (le bouton « Télécharger le modèle » ouvre simplement un intent `ACTION_VIEW` ; AI Tech n'a pas la permission Internet et ne télécharge rien lui-même), puis lu directement depuis votre stockage. AI Tech n'envoie aucune donnée à l'éditeur du modèle.
- **Les paramètres (température, longueur, modèle actif)** : stockés dans les préférences locales de l'application, en clair (pas de donnée sensible).

### Données NON traitées

- **Aucune télémétrie**, aucune analytics, aucun crash reporter tiers.
- **Aucune publicité**, aucun tracker.
- **Aucun compte utilisateur**, aucune connexion à un service en ligne.

### Permissions Android demandées

AI Tech ne demande **AUCUNE permission `INTERNET`**. L'application est techniquement incapable de communiquer avec un serveur distant. Cette absence est vérifiable dans le `AndroidManifest.xml` du dépôt source.

Les seules permissions sont celles induites par le sélecteur de fichiers Android pour vous laisser choisir le fichier du modèle.

### Mode panique

Le menu **Paramètres → Mode panique** efface en bloc et de manière atomique :
- toutes les conversations chiffrées,
- la clé de chiffrement (les conversations qui auraient été sauvegardées sur un autre support deviennent illisibles),
- les paramètres,
- la liste des modèles enregistrés (les fichiers `.task` que vous avez téléchargés sur le stockage public ne sont pas touchés — c'est à vous de les supprimer si vous le souhaitez).

### Vos droits

Toutes les données étant strictement locales, le règlement RGPD s'applique entre vous et votre téléphone. Vous pouvez à tout moment :
- exporter manuellement vos conversations (fonction prévue dans une version ultérieure),
- supprimer toutes les données via le mode panique,
- désinstaller l'application — Android supprimera automatiquement toutes les données privées.

### Sous-traitants

**Aucun.** AI Tech n'utilise aucun service tiers à l'exécution.

### Modèles d'IA

Les modèles `.task` que vous chargez restent sur votre téléphone. Leur licence d'utilisation dépend de leur éditeur (Google pour Gemma, Alibaba pour Qwen, Microsoft pour Phi, Meta pour Llama…). AI Tech ne fait que les exécuter localement via la bibliothèque MediaPipe LLM Inference.

### Contact

Pour toute question : **contact@files-tech.com**

---

AI Tech est édité par une **micro-entreprise française** (SIRET disponible sur demande). Code source publié sous licence **Apache 2.0**.
