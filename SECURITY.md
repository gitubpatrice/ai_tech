# Politique de sécurité — AI Tech

## Versions supportées

Seule la dernière version publiée sur GitHub Releases est activement
maintenue côté sécurité.

| Version | Supportée |
| ------- | --------- |
| 0.9.x   | ✅        |
| 0.8.x   | ⚠️ best-effort |
| < 0.8   | ❌        |

## Modèle de menace

AI Tech est une app **strictement offline** exécutant des modèles de
langage open-source sur le téléphone de l'utilisateur. Les principaux
risques considérés :

- **Exfiltration réseau** — neutralisée par retrait des permissions
  `INTERNET` et `ACCESS_NETWORK_STATE` dans le manifest
  (`tools:node="remove"`). L'app est techniquement incapable d'ouvrir
  une socket. Vérifiable dans le manifest mergé du build.
- **Prompt injection** — un message utilisateur ou un extrait RAG peut
  contenir des balises de rôle (`<start_of_turn>`, `<|im_start|>`,
  `[INST]`, ChatML, Gemma, Llama). Ces balises sont neutralisées avant
  injection dans le contexte du modèle (voir `chat_service.dart` et
  `rag_service.dart` `_sanitize`).
- **Lecture forensique des chats** — chaque conversation est chiffrée
  AES-256-GCM via `EncryptedJsonStore<T>`, écrite atomiquement (write
  to tmp + rename), AAD bindée à l'`id` de la session : un fichier
  copié hors de l'app ne peut pas être déchiffré sans la clé maître,
  et ne peut pas être déplacé d'une session à une autre.
- **Capture écran / aperçu apps récentes** — `FLAG_SECURE` posé au
  `onCreate` de la `MainActivity` bloque screenshots, screen recording
  et le rendu dans la liste des apps récentes.
- **Sauvegarde Android automatique** — `allowBackup="false"` +
  `dataExtractionRules` excluent l'app de adb backup et des transferts
  device-to-device.
- **Tampering du modèle** — validation magic-bytes (`PK` zip ou `TFL`
  LiteRT) + vérification de taille minimale (≥ 50 Mo) avant chargement
  d'un fichier `.task` / `.litertlm`. Le SHA-256 est calculé pendant la
  copie streaming et affiché à l'utilisateur pour comparaison manuelle
  avec la valeur officielle Kaggle / HuggingFace. **Depuis v0.9.0** : si
  l'utilisateur réinstalle un fichier au même nom avec un SHA-256
  différent, un dialogue de confirmation explicite avertit du
  remplacement (`SHA-256 has changed`).

## Choix de posture explicites

Ces décisions de conception sont assumées et documentées pour clarifier
ce qui est dans / hors périmètre de la garantie sécurité d'AI Tech.

### Pas de détection root / jailbreak

AI Tech **ne détecte pas** un appareil rooté et n'altère pas son
comportement en présence de root. La philosophie est cohérente avec
notre licence Apache 2.0 et notre engagement « 100 % local + open
source » : un utilisateur root est explicitement maître de son
téléphone, pas un attaquant.

Conséquence : un attaquant qui parvient à obtenir root **physique** sur
votre appareil peut extraire la clé maître de chiffrement (via Frida /
keystore dump). C'est un compromis assumé. Pour une protection contre
ce vecteur, utiliser un appareil avec verrouillage biométrique + clé
maître bound à `userAuthenticationRequired` (option v1.0 envisagée).

### Master key sans `userAuthenticationRequired`

La clé maître AES-256 est wrappée RSA-OAEP-SHA256 par une clé Keystore
non-extractible, **mais sans contrainte `setUserAuthenticationRequired(true)`**.
Trade-off : pas de prompt biométrique à chaque sauvegarde de chat — UX
fluide. Menace résiduelle : un attaquant qui obtient votre appareil
**déjà déverrouillé** pendant ~1 minute peut lire les chats sans avoir
à débloquer la biométrie.

Mitigation conseillée à l'utilisateur :

- Verrouillage écran avec PIN/biométrie + timeout court (15 s)
- Mode panique disponible dans Réglages (efface tout)
- `FLAG_SECURE` global pour éviter les fuites par capture d'écran

### Modèles non-whitelistés

AI Tech accepte tout fichier `.task` / `.litertlm` que l'utilisateur
sélectionne via SAF (Storage Access Framework). Il n'y a **pas de
liste blanche** d'origines ni de validation cryptographique de la
provenance.

Risque résiduel : un fichier `.task` ou `.litertlm` malicieusement
forgé pourrait théoriquement exploiter une vulnérabilité 0-day du
runtime MediaPipe / LiteRT (binaire `libLiteRtLm.so`, code Google
fermé côté natif). La validation magic-bytes neutralise les renommages
opportunistes mais pas un fichier réellement piégé.

Recommandation utilisateur stricte :

- **Télécharger les modèles uniquement depuis** Kaggle officiel
  (`kaggle.com/models/google/...`) ou HuggingFace officiel
  (`huggingface.co/google/...`, `huggingface.co/litert-community/...`)
- **Vérifier le SHA-256** affiché dans le dialogue d'installation
  contre la valeur publique
- **Ne pas accepter** un modèle reçu par messagerie / téléchargé via
  un mirror non officiel

## Stratégies clés

- **INTERNET retiré du manifest** — pas seulement non utilisé, mais
  **explicitement supprimé** (`tools:node="remove"`) pour neutraliser
  toute permission introduite par une dépendance transitive. C'est la
  garantie technique du « 100 % offline ».
- **`libOpenCL.so` en `uses-native-library` `required="false"`** —
  permet à MediaPipe LLM Inference d'utiliser le GPU quand disponible,
  CPU fallback sinon. Native lib système, pas de surface réseau.
- **`EncryptedJsonStore<T>`** — base générique pour la persistance
  chiffrée (chats, paramètres sensibles). AAD = `id` de l'objet,
  écriture atomique, magic header de format.
- **Mode panique** — wipe atomique avec **timeout dur** : la
  génération native MediaPipe n'a pas d'API d'annulation propre, donc
  le wipe ne peut pas être bloqué par un appel native en cours. Efface
  clé Keystore + chats + index RAG + paramètres + registre de modèles.
- **Stockage Access Framework uniquement** — pas de permission globale
  de lecture du stockage ; l'utilisateur désigne explicitement le
  fichier modèle.

## Signaler une vulnérabilité

Si vous découvrez une vulnérabilité de sécurité dans AI Tech,
**merci de ne PAS ouvrir d'issue publique sur GitHub**.

📧 **contact@files-tech.com** — sujet : `[SECURITY] AI Tech — <description courte>`

Merci d'inclure :

- Description claire et reproductible
- Étapes de reproduction
- Impact potentiel
- Version affectée (visible dans l'écran « À propos »)
- Suggestion de correctif si possible

## Délais de réponse

- Accusé de réception : sous 7 jours
- Évaluation initiale : sous 30 jours
- Correctif : selon la criticité (critique → patch sous 30 jours,
  majeur → version mineure suivante, mineur → backlog)

## Divulgation responsable

Merci de ne pas divulguer publiquement la vulnérabilité avant qu'un
correctif ne soit publié et qu'un délai raisonnable de mise à jour ait
été laissé aux utilisateurs (typiquement 30 jours après publication).

## Vérification de l'intégrité d'un APK

Chaque release publiée sur GitHub Releases inclut le SHA-256 attendu
de l'APK arm64-v8a dans les notes. Avant install :

```bash
sha256sum app-arm64-v8a-release.apk
```

Le résultat doit correspondre exactement à la valeur publiée. Sinon,
ne pas installer.

## Périmètre

Vulnérabilités acceptées :

- Contournement de la promesse offline (génération de trafic réseau)
- Contournement du chiffrement des chats
- Lecture/écriture arbitraire hors du sandbox de l'app
- Crash exploitable (DoS persistant)
- Élévation de privilèges, contournement de FLAG_SECURE
- Prompt injection contournant la sanitization

Hors périmètre :

- Hallucinations / biais des modèles (par nature des LLM, voir TERMS.md)
- Bugs UX sans impact sécurité
- Vulnérabilités dans des dépendances tierces déjà reportées en amont
- Attaques nécessitant un appareil rooté ou compromis
- Attaques physiques sur appareil déverrouillé
