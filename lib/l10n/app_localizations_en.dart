// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AI Tech';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Close';

  @override
  String get commonShare => 'Share';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonBack => 'Back';

  @override
  String get commonImport => 'Import';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonOpen => 'Open';

  @override
  String get commonStart => 'Start';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonError => 'Error';

  @override
  String commonErrorWith(String message) {
    return 'Error: $message';
  }

  @override
  String get commonLoading => 'Loading…';

  @override
  String get dateJustNow => 'just now';

  @override
  String dateMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String dateHoursAgo(int n) {
    return '$n h ago';
  }

  @override
  String dateDaysAgo(int n) {
    return '$n d ago';
  }

  @override
  String get chatTitleDefault => 'Conversation';

  @override
  String get chatTooltipConversations => 'Conversations';

  @override
  String get chatTooltipNew => 'New conversation';

  @override
  String get chatTooltipRagOn =>
      'RAG enabled (replies based on your documents)';

  @override
  String get chatTooltipRagOff =>
      'Enable RAG (replies based on your documents)';

  @override
  String get chatTooltipDelete => 'Delete this conversation';

  @override
  String get chatTooltipSettings => 'Settings';

  @override
  String get chatTooltipMore => 'More';

  @override
  String get chatMenuExport => 'Export conversation';

  @override
  String get chatMenuDocuments => 'Documents (RAG)';

  @override
  String get chatMenuSpike => 'Measure performance';

  @override
  String get chatMenuAbout => 'About';

  @override
  String get chatComposerHintGenerating => 'Generating…';

  @override
  String get chatComposerHintMessage => 'Your message';

  @override
  String get chatComposerLabelMessage => 'Your message';

  @override
  String get chatTooltipSend => 'Send message';

  @override
  String get chatTooltipStop => 'Stop generation';

  @override
  String chatStatusLoadingModel(String name) {
    return 'Loading $name…';
  }

  @override
  String get chatStatusLoadingHint =>
      '10–20 s on average, depending on model size.';

  @override
  String get chatStatusLoadFailed => 'Loading failed';

  @override
  String get chatNoModelTitle => 'No active model';

  @override
  String get chatNoModelSubtitle =>
      'Open Settings to add a model (.task or .litertlm) and select it.';

  @override
  String get chatNoModelOpenSettings => 'Open settings';

  @override
  String get chatEmptyTitle => 'Start the conversation';

  @override
  String chatEmptyModel(String name) {
    return 'Model: $name';
  }

  @override
  String get chatEmptyQuickPrompts => 'Quick starts';

  @override
  String get chatPromptImproveLabel => 'Improve a text';

  @override
  String get chatPromptImproveText =>
      'Improve this text (spelling, style, fluency) while keeping its original meaning:\n\n';

  @override
  String get chatPromptTranslateLabel => 'Translate';

  @override
  String get chatPromptTranslateText =>
      'Translate this text into English keeping the tone:\n\n';

  @override
  String get chatPromptSummarizeLabel => 'Summarize';

  @override
  String get chatPromptSummarizeText =>
      'Summarize this text in 5 key points:\n\n';

  @override
  String get chatPromptExplainLabel => 'Explain simply';

  @override
  String get chatPromptExplainText =>
      'Explain to me simply, like I\'m 12 years old:\n\n';

  @override
  String get chatPromptReformulateLabel => 'Rephrase';

  @override
  String get chatPromptReformulateText =>
      'Rephrase this text more clearly and naturally:\n\n';

  @override
  String get chatPromptBrainstormLabel => 'Brainstorm';

  @override
  String get chatPromptBrainstormText =>
      'Give me 10 original ideas on the following topic:\n\n';

  @override
  String get chatBubbleUser => 'Your message';

  @override
  String get chatBubbleAssistant => 'Assistant message';

  @override
  String get chatBubbleCancelled => '(cancelled)';

  @override
  String chatBubbleErrorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get chatAnnounceGenerationStart => 'Generation started';

  @override
  String get chatAnnounceGenerationDone => 'Reply complete';

  @override
  String get chatAnnounceGenerationCancelled => 'Generation cancelled';

  @override
  String get chatCopySnack => 'Copied';

  @override
  String get chatClearConfirmTitle => 'Clear this conversation?';

  @override
  String get chatClearConfirmBody =>
      'This conversation will be deleted from the phone (encrypted, unrecoverable). Other conversations are kept.';

  @override
  String get chatClearConfirmYes => 'Clear';

  @override
  String get chatShareConfirmTitle => 'Share this conversation?';

  @override
  String get chatShareConfirmBody =>
      'The content will be passed to the app you choose (messages, mail, drive…). If that app sends its data over the Internet, your conversation will be exposed there.\n\nAI Tech itself stays 100% offline.';

  @override
  String get chatShareConfirmYes => 'Share';

  @override
  String get chatExportTitle => '# AI Tech conversation';

  @override
  String chatExportModel(String name) {
    return 'Model: $name';
  }

  @override
  String chatExportDate(String date) {
    return 'Date: $date';
  }

  @override
  String get chatExportSpeakerUser => '## You';

  @override
  String get chatExportSpeakerAssistant => '## Assistant';

  @override
  String get chatExportSubject => 'AI Tech conversation';

  @override
  String chatSourceDialogTitle(int n, String title) {
    return 'Source [$n] · $title';
  }

  @override
  String get chatBlockOfCode => 'Code block';

  @override
  String get chatListTitle => 'Conversations';

  @override
  String get chatListNewLabel => 'New';

  @override
  String get chatListEmptyTitle => 'No conversations yet';

  @override
  String get chatListEmptySubtitle => 'Start a new chat to get going.';

  @override
  String get chatListNewFull => 'New conversation';

  @override
  String get chatListDeleteConfirmTitle => 'Delete this conversation?';

  @override
  String chatListDeleteConfirmBody(String title) {
    return '“$title” will be deleted permanently (encrypted, unrecoverable).';
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
  String get chatListRenameAction => 'Rename';

  @override
  String get chatListRenameTitle => 'Rename conversation';

  @override
  String get chatListRenameHint => 'New title (empty to reset)';

  @override
  String get chatListSwipeHintDelete => 'Swipe left to delete';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsImport => 'Import';

  @override
  String get documentsPaste => 'Paste';

  @override
  String documentsPickerError(String message) {
    return 'Picker error: $message';
  }

  @override
  String get documentsNoPath => 'The system did not provide a readable path.';

  @override
  String documentsUnsupportedFormat(String ext) {
    return 'Unsupported format ($ext). Use .txt, .md, .csv, or source code.';
  }

  @override
  String get documentsNotFound => 'File not found.';

  @override
  String documentsTooLarge(String size) {
    return 'File too large ($size). Max 1 MB.';
  }

  @override
  String get documentsEmpty => 'The file is empty.';

  @override
  String documentsRead(String message) {
    return 'Cannot read: $message';
  }

  @override
  String get documentsIndexed => 'Document indexed.';

  @override
  String get documentsTextIndexed => 'Text indexed.';

  @override
  String get documentsPasteTitle => 'Paste a text';

  @override
  String get documentsTitleField => 'Title';

  @override
  String get documentsContentField => 'Content';

  @override
  String get documentsIndexAction => 'Index';

  @override
  String get documentsContentEmpty => 'Content is empty.';

  @override
  String get documentsContentTooLarge => 'Text too long (max 1 MB).';

  @override
  String get documentsDeleteConfirmTitle => 'Delete this document?';

  @override
  String documentsDeleteConfirmBody(String title) {
    return '“$title” will be removed from the index and from the phone (encrypted, unrecoverable).';
  }

  @override
  String get documentsEmptyTitle => 'No documents indexed';

  @override
  String get documentsEmptySubtitle =>
      'Import a text file or paste content so the AI can answer based on it.';

  @override
  String documentsCharCountThousand(String n) {
    return '$n k characters';
  }

  @override
  String documentsCharCount(int n) {
    return '$n characters';
  }

  @override
  String documentsTileSemantic(String title, String chars, String when) {
    return 'Document $title, $chars, imported $when';
  }

  @override
  String get modelPickerTitle => 'Choose a model';

  @override
  String get modelPickerHeading => 'Select your model';

  @override
  String get modelPickerSubtitle =>
      'Format .task or .litertlm, typically between 500 MB and 4 GB (Gemma, Qwen, Phi, Llama).';

  @override
  String get modelPickerRecommendation => 'Recommendation';

  @override
  String get modelPickerRecommendationText =>
      'Gemma 3 1B int4 (~554 MB). Excellent in English and French, fast, 32K context window.';

  @override
  String get modelPickerStep1Title => 'Download the model';

  @override
  String get modelPickerStep1Subtitle =>
      'Opens Kaggle or HuggingFace in your browser — AI Tech does not download anything itself.';

  @override
  String get modelPickerStep2Title => 'Import it here';

  @override
  String get modelPickerStep2Subtitle =>
      'The file is copied safely into the app sandbox and a SHA-256 is shown for verification.';

  @override
  String get modelPickerDownload => 'Download the model';

  @override
  String get modelPickerImport => 'Import the file';

  @override
  String get modelPickerSourceTitle => 'Official Gemma 3 source';

  @override
  String get modelPickerKaggle => 'Kaggle (Google)';

  @override
  String get modelPickerKaggleSubtitle => 'google/gemma-3 → tfLite';

  @override
  String get modelPickerHf => 'HuggingFace (litert-community)';

  @override
  String get modelPickerHfSubtitle => 'Gemma3-1B-IT';

  @override
  String get modelPickerNoBrowser => 'No browser available.';

  @override
  String get modelPickerCannotOpen => 'Cannot open the browser.';

  @override
  String modelPickerSysError(String message) {
    return 'System picker error: $message';
  }

  @override
  String get modelPickerNoPath =>
      'The system did not provide a readable path. Copy the file to Downloads and try again.';

  @override
  String get modelPickerWrongFormat =>
      'Unsupported format (.task or .litertlm only)';

  @override
  String get modelPickerNotFound => 'File not found.';

  @override
  String get modelPickerTooSmall => 'File too small to be a model.';

  @override
  String get modelPickerNotMediapipe =>
      'The file does not look like a MediaPipe model.';

  @override
  String get modelInstallTitleCopying => 'Copying…';

  @override
  String get modelInstallTitleDone => 'Model copied';

  @override
  String get modelInstallCopyDescription =>
      'Copying the model into the app sandbox and computing the SHA-256.';

  @override
  String modelInstallCopiedOf(String copied, String total, String pct) {
    return 'Copied: $copied / $total  ($pct %)';
  }

  @override
  String get modelInstallPreparing => 'Preparing…';

  @override
  String modelInstallDoneDescription(String size) {
    return 'The file has been copied to the app sandbox ($size).';
  }

  @override
  String get modelInstallSha256Label =>
      'SHA-256 (compare with the official source if needed):';

  @override
  String get modelInstallSha256Sem => 'SHA-256 fingerprint, copyable text';

  @override
  String get modelInstallCopyHash => 'Copy the hash';

  @override
  String get modelInstallSha256Copied => 'SHA-256 copied.';

  @override
  String get modelInstallFailedTitle => 'Copy failed';

  @override
  String modelInstallFailedBody(String error) {
    return 'The model copy failed:\n\n$error';
  }

  @override
  String get memoryLowTitle => 'Low memory';

  @override
  String memoryLowBody(String needed, String avail) {
    return 'This model (~$needed MB) is likely to crash the app: only $avail MB free on this device. Forcing the load may cause a hard kill.';
  }

  @override
  String get memoryLowProceed => 'Load anyway';

  @override
  String get memoryLowCancel => 'Cancel';

  @override
  String get modelShaChangedTitle => 'SHA-256 fingerprint changed';

  @override
  String modelShaChangedBody(String previous, String current) {
    return 'A model with the same name already existed with a different fingerprint.\n\nPrevious: $previous\nNew: $current\n\nIf you did not intentionally replace this file, refuse the install.';
  }

  @override
  String get modelShaChangedReplace => 'Replace';

  @override
  String get modelShaChangedRefuse => 'Refuse';

  @override
  String get onboardingWelcomeTitle => 'Welcome to AI Tech';

  @override
  String get onboardingWelcomeSubtitle =>
      'An AI assistant that runs entirely on your phone.';

  @override
  String get onboardingFeatureOfflineTitle => '100% offline';

  @override
  String get onboardingFeatureOfflineText =>
      'No Internet connection. The app does not even have permission to use one.';

  @override
  String get onboardingFeatureCryptoTitle => 'Encrypted conversations';

  @override
  String get onboardingFeatureCryptoText =>
      'AES-256-GCM with a key in the Android Keystore.';

  @override
  String get onboardingFeaturePanicTitle => 'Panic mode';

  @override
  String get onboardingFeaturePanicText =>
      'Wipes key and history with one tap. Final.';

  @override
  String get onboardingFeatureOpenSourceTitle => 'Open source code';

  @override
  String get onboardingFeatureOpenSourceText =>
      'Apache 2.0. Verify our promises yourself.';

  @override
  String get onboardingAboutLink => 'About · Privacy';

  @override
  String get onboardingImportTitle => 'Choose a model';

  @override
  String get onboardingImportSubtitle =>
      'Download a model in .task or .litertlm format (Gemma, Qwen, Phi, Llama…) then select it here.';

  @override
  String get onboardingImportCardTitle => 'Recommendation';

  @override
  String get onboardingImportCardBody =>
      'Gemma 3 1B (int4) — 554 MB, excellent in English and French, fast even on mid-range phones.';

  @override
  String get onboardingImportCardSource =>
      'Source: Kaggle → google/gemma-3 → tfLite → gemma3-1b-it-int4';

  @override
  String get onboardingImportSaving => 'Saving…';

  @override
  String get onboardingImportSelectAction => 'Select a model';

  @override
  String get onboardingAnnounceStep2 => 'Step 2 of 2: choose a model';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionModels => 'Models';

  @override
  String get settingsSectionGeneration => 'Generation';

  @override
  String get settingsSectionDataSecurity => 'Data and security';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsAddModelTitle => 'Add a model';

  @override
  String get settingsAddModelSubtitle => '.task or .litertlm';

  @override
  String get settingsModelAdded => 'Model added';

  @override
  String settingsModelActive(String name) {
    return 'Active model: $name';
  }

  @override
  String get settingsRemoveModelTitle => 'Remove this model?';

  @override
  String settingsRemoveModelBody(String name) {
    return 'The file $name will not be deleted from storage. It will only be removed from the registered models list.';
  }

  @override
  String get settingsRemoveModelYes => 'Remove';

  @override
  String get settingsSliderCreativity => 'Creativity (temperature)';

  @override
  String get settingsSliderCreativityHelper =>
      'Low = factual and stable. High = creative and varied.';

  @override
  String get settingsSliderDiversity => 'Diversity (top-K)';

  @override
  String get settingsSliderDiversityHelper =>
      'Number of candidate words considered at each step.';

  @override
  String get settingsSliderContext => 'Context length (maxTokens)';

  @override
  String get settingsSliderContextHelper =>
      'Conversation memory. Higher = more RAM used.';

  @override
  String settingsSliderSemantic(String label, String value) {
    return '$label, value $value';
  }

  @override
  String get settingsClearChats => 'Clear conversations';

  @override
  String get settingsClearChatsSubtitle =>
      'Deletes the encrypted history. Models and settings are kept.';

  @override
  String get settingsClearConfirmTitle => 'Clear all conversations?';

  @override
  String get settingsClearConfirmBody =>
      'The encrypted history will be deleted. Your models and settings are kept.';

  @override
  String get settingsClearConfirmYes => 'Clear';

  @override
  String get settingsClearDone => 'Conversations cleared';

  @override
  String get settingsPanic => 'Panic mode';

  @override
  String get settingsPanicSubtitle =>
      'Wipes key + history + models + settings.';

  @override
  String get settingsPanicConfirmBody =>
      'This action wipes in bulk:\n\n• all encrypted conversations\n• the encryption key (unrecoverable)\n• the registered models list\n• all settings\n\nThe .task files you downloaded on your phone are not touched. The app restarts as on first launch.\n\nContinue?';

  @override
  String get settingsPanicConfirmYes => 'Wipe everything';

  @override
  String get settingsPanicAnnounceDone => 'Wipe complete, returning to home';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutSubtitle => 'Version, legal, support';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageFr => 'Français';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

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
      'true': 'active',
      'other': 'inactive',
    });
    return 'Model $name, $family, $filetype, $size, $_temp0';
  }

  @override
  String get settingsVerifyTooltip => 'Verify integrity (SHA-256)';

  @override
  String get settingsRemoveTooltip => 'Remove from list';

  @override
  String get settingsHashStored => 'SHA-256 computed and saved';

  @override
  String get settingsHashOk => 'Integrity verified';

  @override
  String settingsHashOkBody(String hash) {
    return 'The SHA-256 matches the saved one:\n\n$hash';
  }

  @override
  String get settingsHashMismatch => 'Different SHA-256!';

  @override
  String settingsHashMismatchBody(String expected, String got) {
    return 'The file has been modified since installation.\n\nExpected: $expected\n\nGot: $got';
  }

  @override
  String get settingsHashIgnore => 'Ignore';

  @override
  String get settingsHashDeactivate => 'Disable this model';

  @override
  String settingsHashVerifyError(String message) {
    return 'Verification error: $message';
  }

  @override
  String get settingsHashFileNotFound => 'File not found.';

  @override
  String get settingsHashShortNotStored => 'SHA-256 not saved';

  @override
  String settingsHashShortPrefix(String prefix) {
    return 'SHA-256 $prefix…';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutPromiseTitle => 'Our commitment';

  @override
  String get aboutPromise1 =>
      '100% offline — the Internet permission is removed from the manifest (tools:node=\"remove\"). No cloud, no account.';

  @override
  String get aboutPromise2 =>
      'Encrypted conversations: AES-256-GCM with a unique key stored in the Android Keystore.';

  @override
  String get aboutPromise3 => 'Panic mode: wipes key + history with one tap.';

  @override
  String get aboutPromise4 => 'Source code fully published under Apache 2.0.';

  @override
  String get aboutPromise5 => 'No telemetry, no tracker, no advertising.';

  @override
  String get aboutHowTitle => 'How it works';

  @override
  String get aboutHow1 =>
      'AI Tech runs an open-source language model (Gemma, Qwen, Phi, Llama…) directly on your phone via Google\'s MediaPipe LLM Inference library.';

  @override
  String get aboutHow2 =>
      'You download the model of your choice in .task or .litertlm format from Kaggle or HuggingFace, then import it into the app. No data is sent to the model publisher or any third-party service.';

  @override
  String get aboutHow3 =>
      'Updates: AI Tech does not contact any update server, unlike other Files Tech apps, to stay consistent with the offline promise. New versions are published on GitHub Releases and F-Droid — you decide when to update.';

  @override
  String get aboutLicense => 'Apache 2.0 — Files Tech';

  @override
  String get spikeTitle => 'AI Tech — Spike';

  @override
  String get spikeNoModel => 'No model loaded.';

  @override
  String get spikeNoModelSelected => 'No model selected';

  @override
  String get spikeWrongFormat => 'Unsupported format: choose a .task file';

  @override
  String get spikeInstalling => 'Installing the model…';

  @override
  String get spikeLoadingHint => 'Loading into memory (may take 10–20 s)…';

  @override
  String get spikeReady => 'Model ready.';

  @override
  String get spikeGenerating => 'Generating…';

  @override
  String get spikeFinished => 'Done.';

  @override
  String spikeGenerationError(String message) {
    return 'Generation error: $message';
  }

  @override
  String get spikePromptLabel => 'Prompt';

  @override
  String get spikePromptDefault => 'Explain photosynthesis in 3 sentences.';

  @override
  String get spikeRun => 'Run';

  @override
  String get spikeRunning => 'Generating…';

  @override
  String get spikeChooseTask => 'Choose a .task';

  @override
  String get spikeMetricsTitle => 'Metrics';

  @override
  String get spikeMetricFirstToken => 'First token';

  @override
  String spikeMetricFirstTokenValue(int ms) {
    return '$ms ms';
  }

  @override
  String get spikeMetricTotalDuration => 'Total duration';

  @override
  String get spikeMetricTokens => 'Tokens (chunks)';

  @override
  String get spikeMetricChars => 'Characters';

  @override
  String get spikeMetricTokensPerSec => 'Tokens/s';

  @override
  String get spikeMetricCharsPerSec => 'Chars/s';
}
