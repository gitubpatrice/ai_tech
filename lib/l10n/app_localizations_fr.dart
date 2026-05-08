// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AI Tech';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonImport => 'Importer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonOpen => 'Ouvrir';

  @override
  String get commonStart => 'Commencer';

  @override
  String get commonSelect => 'Sélectionner';

  @override
  String get commonError => 'Erreur';

  @override
  String commonErrorWith(String message) {
    return 'Erreur : $message';
  }

  @override
  String get commonLoading => 'Chargement…';

  @override
  String get dateJustNow => 'à l\'instant';

  @override
  String dateMinutesAgo(int n) {
    return 'il y a $n min';
  }

  @override
  String dateHoursAgo(int n) {
    return 'il y a $n h';
  }

  @override
  String dateDaysAgo(int n) {
    return 'il y a $n j';
  }

  @override
  String get chatTitleDefault => 'Conversation';

  @override
  String get chatTooltipConversations => 'Conversations';

  @override
  String get chatTooltipNew => 'Nouvelle conversation';

  @override
  String get chatTooltipRagOn =>
      'RAG actif (réponses basées sur vos documents)';

  @override
  String get chatTooltipRagOff =>
      'Activer le RAG (réponses basées sur vos documents)';

  @override
  String get chatTooltipDelete => 'Supprimer cette conversation';

  @override
  String get chatTooltipSettings => 'Paramètres';

  @override
  String get chatTooltipMore => 'Plus';

  @override
  String get chatMenuExport => 'Exporter la conversation';

  @override
  String get chatMenuDocuments => 'Documents (RAG)';

  @override
  String get chatMenuSpike => 'Mesurer les performances';

  @override
  String get chatMenuAbout => 'À propos';

  @override
  String get chatComposerHintGenerating => 'Génération…';

  @override
  String get chatComposerHintMessage => 'Votre message';

  @override
  String get chatComposerLabelMessage => 'Votre message';

  @override
  String get chatTooltipSend => 'Envoyer le message';

  @override
  String get chatTooltipStop => 'Arrêter la génération';

  @override
  String chatStatusLoadingModel(String name) {
    return 'Chargement de $name…';
  }

  @override
  String get chatStatusLoadingHint =>
      '10–20 s en moyenne, selon la taille du modèle.';

  @override
  String get chatStatusLoadFailed => 'Échec du chargement';

  @override
  String get chatNoModelTitle => 'Aucun modèle actif';

  @override
  String get chatNoModelSubtitle =>
      'Allez dans les paramètres pour ajouter un modèle (.task ou .litertlm) et le sélectionner.';

  @override
  String get chatNoModelOpenSettings => 'Ouvrir les paramètres';

  @override
  String get chatEmptyTitle => 'Commencez la conversation';

  @override
  String chatEmptyModel(String name) {
    return 'Modèle : $name';
  }

  @override
  String get chatEmptyQuickPrompts => 'Démarrages rapides';

  @override
  String get chatPromptImproveLabel => 'Améliorer un texte';

  @override
  String get chatPromptImproveText =>
      'Améliore ce texte (orthographe, style, fluidité) en gardant le sens d\'origine :\n\n';

  @override
  String get chatPromptTranslateLabel => 'Traduire';

  @override
  String get chatPromptTranslateText =>
      'Traduis ce texte en français en gardant le ton :\n\n';

  @override
  String get chatPromptSummarizeLabel => 'Résumer';

  @override
  String get chatPromptSummarizeText =>
      'Résume ce texte en 5 points clés :\n\n';

  @override
  String get chatPromptExplainLabel => 'Expliquer simplement';

  @override
  String get chatPromptExplainText =>
      'Explique-moi simplement, comme à un enfant de 12 ans :\n\n';

  @override
  String get chatPromptReformulateLabel => 'Reformuler';

  @override
  String get chatPromptReformulateText =>
      'Reformule ce texte de façon plus claire et plus naturelle :\n\n';

  @override
  String get chatPromptBrainstormLabel => 'Brainstormer';

  @override
  String get chatPromptBrainstormText =>
      'Donne-moi 10 idées originales sur le thème suivant :\n\n';

  @override
  String get chatBubbleUser => 'Message de vous';

  @override
  String get chatBubbleAssistant => 'Message de l\'assistant';

  @override
  String get chatBubbleCancelled => '(annulé)';

  @override
  String chatBubbleErrorPrefix(String message) {
    return 'Erreur : $message';
  }

  @override
  String get chatAnnounceGenerationStart => 'Génération démarrée';

  @override
  String get chatAnnounceGenerationDone => 'Réponse terminée';

  @override
  String get chatAnnounceGenerationCancelled => 'Génération annulée';

  @override
  String get chatCopySnack => 'Copié';

  @override
  String get chatClearConfirmTitle => 'Effacer cette conversation ?';

  @override
  String get chatClearConfirmBody =>
      'Cette discussion sera supprimée du téléphone (chiffrée, irrécupérable). Les autres conversations sont conservées.';

  @override
  String get chatClearConfirmYes => 'Effacer';

  @override
  String get chatShareConfirmTitle => 'Partager cette conversation ?';

  @override
  String get chatShareConfirmBody =>
      'Le contenu sera transmis à l\'application que vous choisissez (messages, mail, drive…). Si cette app envoie ses données sur Internet, votre conversation y sera exposée.\n\nAI Tech, lui, reste 100 % offline.';

  @override
  String get chatShareConfirmYes => 'Partager';

  @override
  String get chatExportTitle => '# Conversation AI Tech';

  @override
  String chatExportModel(String name) {
    return 'Modèle : $name';
  }

  @override
  String chatExportDate(String date) {
    return 'Date : $date';
  }

  @override
  String get chatExportSpeakerUser => '## Vous';

  @override
  String get chatExportSpeakerAssistant => '## Assistant';

  @override
  String get chatExportSubject => 'Conversation AI Tech';

  @override
  String chatSourceDialogTitle(int n, String title) {
    return 'Source [$n] · $title';
  }

  @override
  String get chatBlockOfCode => 'Bloc de code';

  @override
  String get chatListTitle => 'Conversations';

  @override
  String get chatListNewLabel => 'Nouvelle';

  @override
  String get chatListEmptyTitle => 'Aucune conversation';

  @override
  String get chatListEmptySubtitle =>
      'Démarrez une nouvelle discussion pour commencer.';

  @override
  String get chatListNewFull => 'Nouvelle conversation';

  @override
  String get chatListDeleteConfirmTitle => 'Supprimer cette conversation ?';

  @override
  String chatListDeleteConfirmBody(String title) {
    return '« $title » sera supprimée définitivement (chiffrée, irrécupérable).';
  }

  @override
  String chatListSubtitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'messages',
      one: 'message',
    );
    return '$count $_temp0 · $date';
  }

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsImport => 'Importer';

  @override
  String get documentsPaste => 'Coller';

  @override
  String documentsPickerError(String message) {
    return 'Erreur du picker : $message';
  }

  @override
  String get documentsNoPath => 'Le système n\'a pas fourni de chemin lisible.';

  @override
  String documentsUnsupportedFormat(String ext) {
    return 'Format non supporté ($ext). Utilisez .txt, .md, .csv, ou code source.';
  }

  @override
  String get documentsNotFound => 'Fichier introuvable.';

  @override
  String documentsTooLarge(String size) {
    return 'Fichier trop volumineux ($size). Maximum 1 Mo.';
  }

  @override
  String get documentsEmpty => 'Le fichier est vide.';

  @override
  String documentsRead(String message) {
    return 'Lecture impossible : $message';
  }

  @override
  String get documentsIndexed => 'Document indexé.';

  @override
  String get documentsTextIndexed => 'Texte indexé.';

  @override
  String get documentsPasteTitle => 'Coller un texte';

  @override
  String get documentsTitleField => 'Titre';

  @override
  String get documentsContentField => 'Contenu';

  @override
  String get documentsIndexAction => 'Indexer';

  @override
  String get documentsContentEmpty => 'Le contenu est vide.';

  @override
  String get documentsContentTooLarge => 'Texte trop long (max 1 Mo).';

  @override
  String get documentsDeleteConfirmTitle => 'Supprimer ce document ?';

  @override
  String documentsDeleteConfirmBody(String title) {
    return '« $title » sera supprimé de l\'index et du téléphone (chiffré, irrécupérable).';
  }

  @override
  String get documentsEmptyTitle => 'Aucun document indexé';

  @override
  String get documentsEmptySubtitle =>
      'Importez un fichier texte ou collez du contenu pour permettre à l\'IA de répondre en s\'appuyant dessus.';

  @override
  String documentsCharCountThousand(String n) {
    return '$n k caractères';
  }

  @override
  String documentsCharCount(int n) {
    return '$n caractères';
  }

  @override
  String documentsTileSemantic(String title, String chars, String when) {
    return 'Document $title, $chars, importé $when';
  }

  @override
  String get modelPickerTitle => 'Choisir un modèle';

  @override
  String get modelPickerHeading => 'Sélectionnez votre modèle';

  @override
  String get modelPickerSubtitle =>
      'Format .task ou .litertlm, typiquement entre 500 Mo et 4 Go (Gemma, Qwen, Phi, Llama).';

  @override
  String get modelPickerRecommendation => 'Recommandation';

  @override
  String get modelPickerRecommendationText =>
      'Gemma 3 1B int4 (~554 Mo). Excellent en français, très rapide, fenêtre de contexte 32K.';

  @override
  String get modelPickerStep1Title => 'Téléchargez le modèle';

  @override
  String get modelPickerStep1Subtitle =>
      'Ouvre Kaggle ou HuggingFace dans votre navigateur — AI Tech ne télécharge rien lui-même.';

  @override
  String get modelPickerStep2Title => 'Importez-le ici';

  @override
  String get modelPickerStep2Subtitle =>
      'Le fichier sera copié en sécurité dans le sandbox de l\'app et un SHA-256 sera affiché pour vérification.';

  @override
  String get modelPickerDownload => 'Télécharger le modèle';

  @override
  String get modelPickerImport => 'Importer le fichier';

  @override
  String get modelPickerSourceTitle => 'Source officielle Gemma 3';

  @override
  String get modelPickerKaggle => 'Kaggle (Google)';

  @override
  String get modelPickerKaggleSubtitle => 'google/gemma-3 → tfLite';

  @override
  String get modelPickerHf => 'HuggingFace (litert-community)';

  @override
  String get modelPickerHfSubtitle => 'Gemma3-1B-IT';

  @override
  String get modelPickerNoBrowser => 'Aucun navigateur disponible.';

  @override
  String get modelPickerCannotOpen => 'Impossible d\'ouvrir le navigateur.';

  @override
  String modelPickerSysError(String message) {
    return 'Erreur du picker système : $message';
  }

  @override
  String get modelPickerNoPath =>
      'Le système n\'a pas fourni de chemin lisible. Copiez le fichier dans Téléchargements et réessayez.';

  @override
  String get modelPickerWrongFormat =>
      'Format non supporté (.task ou .litertlm uniquement)';

  @override
  String get modelPickerNotFound => 'Fichier introuvable.';

  @override
  String get modelPickerTooSmall => 'Fichier trop petit pour être un modèle.';

  @override
  String get modelPickerNotMediapipe =>
      'Le fichier ne ressemble pas à un modèle MediaPipe.';

  @override
  String get modelInstallTitleCopying => 'Copie en cours…';

  @override
  String get modelInstallTitleDone => 'Modèle copié';

  @override
  String get modelInstallCopyDescription =>
      'Copie du modèle dans le sandbox de l\'app et calcul du SHA-256.';

  @override
  String modelInstallCopiedOf(String copied, String total, String pct) {
    return 'Copié : $copied / $total  ($pct %)';
  }

  @override
  String get modelInstallPreparing => 'Préparation…';

  @override
  String modelInstallDoneDescription(String size) {
    return 'Le fichier a été copié dans le sandbox de l\'app ($size).';
  }

  @override
  String get modelInstallSha256Label =>
      'SHA-256 (à comparer avec la source officielle si besoin) :';

  @override
  String get modelInstallSha256Sem => 'Empreinte SHA-256, contenu copiable';

  @override
  String get modelInstallCopyHash => 'Copier le hash';

  @override
  String get modelInstallSha256Copied => 'SHA-256 copié.';

  @override
  String get modelInstallFailedTitle => 'Échec de la copie';

  @override
  String modelInstallFailedBody(String error) {
    return 'La copie du modèle a échoué :\n\n$error';
  }

  @override
  String get onboardingWelcomeTitle => 'Bienvenue dans AI Tech';

  @override
  String get onboardingWelcomeSubtitle =>
      'Un assistant IA qui tourne entièrement sur votre téléphone.';

  @override
  String get onboardingFeatureOfflineTitle => '100 % hors-ligne';

  @override
  String get onboardingFeatureOfflineText =>
      'Aucune connexion Internet. L\'app n\'a même pas la permission d\'en faire.';

  @override
  String get onboardingFeatureCryptoTitle => 'Conversations chiffrées';

  @override
  String get onboardingFeatureCryptoText =>
      'AES-256-GCM avec clé dans le Android Keystore.';

  @override
  String get onboardingFeaturePanicTitle => 'Mode panique';

  @override
  String get onboardingFeaturePanicText =>
      'Efface clé et historique en un appui. Définitif.';

  @override
  String get onboardingFeatureOpenSourceTitle => 'Code source ouvert';

  @override
  String get onboardingFeatureOpenSourceText =>
      'Apache 2.0. Vérifiez vous-même nos promesses.';

  @override
  String get onboardingAboutLink => 'À propos · Confidentialité';

  @override
  String get onboardingImportTitle => 'Choisir un modèle';

  @override
  String get onboardingImportSubtitle =>
      'Téléchargez un modèle au format .task ou .litertlm (Gemma, Qwen, Phi, Llama…) puis sélectionnez-le ici.';

  @override
  String get onboardingImportCardTitle => 'Recommandation';

  @override
  String get onboardingImportCardBody =>
      'Gemma 3 1B (int4) — 554 Mo, excellent en français, très rapide même sur téléphones milieu de gamme.';

  @override
  String get onboardingImportCardSource =>
      'Source : Kaggle → google/gemma-3 → tfLite → gemma3-1b-it-int4';

  @override
  String get onboardingImportSaving => 'Enregistrement…';

  @override
  String get onboardingImportSelectAction => 'Sélectionner un modèle';

  @override
  String get onboardingAnnounceStep2 => 'Étape 2 sur 2 : choisir un modèle';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsSectionModels => 'Modèles';

  @override
  String get settingsSectionGeneration => 'Génération';

  @override
  String get settingsSectionDataSecurity => 'Données et sécurité';

  @override
  String get settingsSectionAppearance => 'Apparence';

  @override
  String get settingsAddModelTitle => 'Ajouter un modèle';

  @override
  String get settingsAddModelSubtitle => '.task ou .litertlm';

  @override
  String get settingsModelAdded => 'Modèle ajouté';

  @override
  String settingsModelActive(String name) {
    return 'Modèle actif : $name';
  }

  @override
  String get settingsRemoveModelTitle => 'Retirer ce modèle ?';

  @override
  String settingsRemoveModelBody(String name) {
    return 'Le fichier $name ne sera pas supprimé du stockage. Il sera juste retiré de la liste des modèles enregistrés.';
  }

  @override
  String get settingsRemoveModelYes => 'Retirer';

  @override
  String get settingsSliderCreativity => 'Créativité (température)';

  @override
  String get settingsSliderCreativityHelper =>
      'Bas = factuel et stable. Haut = créatif et varié.';

  @override
  String get settingsSliderDiversity => 'Diversité (top-K)';

  @override
  String get settingsSliderDiversityHelper =>
      'Nombre de mots candidats considérés à chaque étape.';

  @override
  String get settingsSliderContext => 'Longueur de contexte (maxTokens)';

  @override
  String get settingsSliderContextHelper =>
      'Mémoire de la conversation. Plus haut = plus de RAM consommée.';

  @override
  String settingsSliderSemantic(String label, String value) {
    return '$label, valeur $value';
  }

  @override
  String get settingsClearChats => 'Effacer les conversations';

  @override
  String get settingsClearChatsSubtitle =>
      'Supprime l\'historique chiffré. Modèles et paramètres conservés.';

  @override
  String get settingsClearConfirmTitle => 'Effacer toutes les conversations ?';

  @override
  String get settingsClearConfirmBody =>
      'L\'historique chiffré sera supprimé. Vos modèles et paramètres sont conservés.';

  @override
  String get settingsClearConfirmYes => 'Effacer';

  @override
  String get settingsClearDone => 'Conversations effacées';

  @override
  String get settingsPanic => 'Mode panique';

  @override
  String get settingsPanicSubtitle =>
      'Efface clé + historique + modèles + paramètres.';

  @override
  String get settingsPanicConfirmBody =>
      'Cette action efface en bloc :\n\n• toutes les conversations chiffrées\n• la clé de chiffrement (irrécupérable)\n• la liste des modèles enregistrés\n• tous les paramètres\n\nLes fichiers .task que vous avez téléchargés sur votre téléphone ne sont pas touchés. L\'application redémarre comme au premier lancement.\n\nContinuer ?';

  @override
  String get settingsPanicConfirmYes => 'Tout effacer';

  @override
  String get settingsPanicAnnounceDone =>
      'Effacement effectué, retour à l\'accueil';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Version, légal, support';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Suivre le système';

  @override
  String get settingsLanguageFr => 'Français';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Suivre le système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguageChangedFr => 'Langue changée en français';

  @override
  String get settingsLanguageChangedEn => 'Language switched to English';

  @override
  String settingsModelSemantic(
    String name,
    String family,
    String filetype,
    String size,
    String active,
  ) {
    String _temp0 = intl.Intl.selectLogic(active, {
      'true': 'actif',
      'other': 'inactif',
    });
    return 'Modèle $name, $family, $filetype, $size, $_temp0';
  }

  @override
  String get settingsVerifyTooltip => 'Vérifier l\'intégrité (SHA-256)';

  @override
  String get settingsRemoveTooltip => 'Retirer de la liste';

  @override
  String get settingsHashStored => 'SHA-256 calculé et enregistré';

  @override
  String get settingsHashOk => 'Intégrité vérifiée';

  @override
  String settingsHashOkBody(String hash) {
    return 'Le SHA-256 correspond à celui enregistré :\n\n$hash';
  }

  @override
  String get settingsHashMismatch => 'SHA-256 différent !';

  @override
  String settingsHashMismatchBody(String expected, String got) {
    return 'Le fichier a été modifié depuis l\'installation.\n\nAttendu : $expected\n\nCalculé : $got';
  }

  @override
  String get settingsHashIgnore => 'Ignorer';

  @override
  String get settingsHashDeactivate => 'Désactiver ce modèle';

  @override
  String settingsHashVerifyError(String message) {
    return 'Erreur de vérification : $message';
  }

  @override
  String get settingsHashFileNotFound => 'Fichier introuvable.';

  @override
  String get settingsHashShortNotStored => 'SHA-256 non enregistré';

  @override
  String settingsHashShortPrefix(String prefix) {
    return 'SHA-256 $prefix…';
  }

  @override
  String get aboutTitle => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPromiseTitle => 'Notre engagement';

  @override
  String get aboutPromise1 =>
      '100 % hors-ligne — la permission Internet est retirée du manifest (tools:node=\"remove\"). Aucun cloud, aucun compte.';

  @override
  String get aboutPromise2 =>
      'Conversations chiffrées AES-256-GCM avec une clé unique stockée dans le Android Keystore.';

  @override
  String get aboutPromise3 =>
      'Mode panique : efface clé + historique en un appui.';

  @override
  String get aboutPromise4 =>
      'Code source intégralement publié sous Apache 2.0.';

  @override
  String get aboutPromise5 =>
      'Aucune télémétrie, aucun tracker, aucune publicité.';

  @override
  String get aboutHowTitle => 'Comment ça marche';

  @override
  String get aboutHow1 =>
      'AI Tech exécute un modèle de langage open-source (Gemma, Qwen, Phi, Llama…) directement sur votre téléphone via la bibliothèque MediaPipe LLM Inference de Google.';

  @override
  String get aboutHow2 =>
      'Vous téléchargez le modèle de votre choix au format .task ou .litertlm depuis Kaggle ou HuggingFace, puis vous l\'importez dans l\'application. Aucune donnée n\'est envoyée à l\'éditeur du modèle ni à un service tiers.';

  @override
  String get aboutHow3 =>
      'Mises à jour : AI Tech ne contacte aucun serveur de mise à jour, contrairement aux autres apps Files Tech, par cohérence avec la promesse offline. Les nouvelles versions sont publiées sur GitHub Releases et F-Droid — vous décidez quand mettre à jour.';

  @override
  String get aboutLicense => 'Apache 2.0 — Files Tech';

  @override
  String get spikeTitle => 'AI Tech — Spike';

  @override
  String get spikeNoModel => 'Aucun modèle chargé.';

  @override
  String get spikeNoModelSelected => 'Aucun modèle sélectionné';

  @override
  String get spikeWrongFormat =>
      'Format non supporté : choisissez un fichier .task';

  @override
  String get spikeInstalling => 'Installation du modèle…';

  @override
  String get spikeLoadingHint =>
      'Chargement en mémoire (peut prendre 10–20 s)…';

  @override
  String get spikeReady => 'Modèle prêt.';

  @override
  String get spikeGenerating => 'Génération en cours…';

  @override
  String get spikeFinished => 'Terminé.';

  @override
  String spikeGenerationError(String message) {
    return 'Erreur génération : $message';
  }

  @override
  String get spikePromptLabel => 'Prompt';

  @override
  String get spikePromptDefault =>
      'Explique en 3 phrases ce qu\'est la photosynthèse.';

  @override
  String get spikeRun => 'Lancer';

  @override
  String get spikeRunning => 'Génération…';

  @override
  String get spikeChooseTask => 'Choisir un .task';

  @override
  String get spikeMetricsTitle => 'Métriques';

  @override
  String get spikeMetricFirstToken => 'First token';

  @override
  String spikeMetricFirstTokenValue(int ms) {
    return '$ms ms';
  }

  @override
  String get spikeMetricTotalDuration => 'Durée totale';

  @override
  String get spikeMetricTokens => 'Tokens (chunks)';

  @override
  String get spikeMetricChars => 'Caractères';

  @override
  String get spikeMetricTokensPerSec => 'Tokens/s';

  @override
  String get spikeMetricCharsPerSec => 'Chars/s';
}
