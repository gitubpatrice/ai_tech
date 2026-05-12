import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tech'**
  String get appTitle;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get commonOpen;

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonErrorWith.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String commonErrorWith(String message);

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @dateJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get dateJustNow;

  /// No description provided for @dateMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String dateMinutesAgo(int n);

  /// No description provided for @dateHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} h ago'**
  String dateHoursAgo(int n);

  /// No description provided for @dateDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} d ago'**
  String dateDaysAgo(int n);

  /// No description provided for @chatTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get chatTitleDefault;

  /// No description provided for @chatTooltipConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatTooltipConversations;

  /// No description provided for @chatTooltipNew.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatTooltipNew;

  /// No description provided for @chatTooltipRagOn.
  ///
  /// In en, this message translates to:
  /// **'RAG enabled (replies based on your documents)'**
  String get chatTooltipRagOn;

  /// No description provided for @chatTooltipRagOff.
  ///
  /// In en, this message translates to:
  /// **'Enable RAG (replies based on your documents)'**
  String get chatTooltipRagOff;

  /// No description provided for @chatTooltipDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation'**
  String get chatTooltipDelete;

  /// No description provided for @chatTooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get chatTooltipSettings;

  /// No description provided for @chatTooltipMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get chatTooltipMore;

  /// No description provided for @chatMenuExport.
  ///
  /// In en, this message translates to:
  /// **'Export conversation'**
  String get chatMenuExport;

  /// No description provided for @chatMenuDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents (RAG)'**
  String get chatMenuDocuments;

  /// No description provided for @chatMenuSpike.
  ///
  /// In en, this message translates to:
  /// **'Measure performance'**
  String get chatMenuSpike;

  /// No description provided for @chatMenuAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get chatMenuAbout;

  /// No description provided for @chatComposerHintGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get chatComposerHintGenerating;

  /// No description provided for @chatComposerHintMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get chatComposerHintMessage;

  /// No description provided for @chatComposerLabelMessage.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get chatComposerLabelMessage;

  /// No description provided for @chatTooltipSend.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get chatTooltipSend;

  /// No description provided for @chatTooltipStop.
  ///
  /// In en, this message translates to:
  /// **'Stop generation'**
  String get chatTooltipStop;

  /// No description provided for @chatStatusLoadingModel.
  ///
  /// In en, this message translates to:
  /// **'Loading {name}…'**
  String chatStatusLoadingModel(String name);

  /// No description provided for @chatStatusLoadingHint.
  ///
  /// In en, this message translates to:
  /// **'10–20 s on average, depending on model size.'**
  String get chatStatusLoadingHint;

  /// No description provided for @chatStatusLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Loading failed'**
  String get chatStatusLoadFailed;

  /// No description provided for @chatNoModelTitle.
  ///
  /// In en, this message translates to:
  /// **'No active model'**
  String get chatNoModelTitle;

  /// No description provided for @chatNoModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open Settings to add a model (.task or .litertlm) and select it.'**
  String get chatNoModelSubtitle;

  /// No description provided for @chatNoModelOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get chatNoModelOpenSettings;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {name}'**
  String chatEmptyModel(String name);

  /// No description provided for @chatEmptyQuickPrompts.
  ///
  /// In en, this message translates to:
  /// **'Quick starts'**
  String get chatEmptyQuickPrompts;

  /// No description provided for @chatPromptImproveLabel.
  ///
  /// In en, this message translates to:
  /// **'Improve a text'**
  String get chatPromptImproveLabel;

  /// No description provided for @chatPromptImproveText.
  ///
  /// In en, this message translates to:
  /// **'Improve this text (spelling, style, fluency) while keeping its original meaning:\n\n'**
  String get chatPromptImproveText;

  /// No description provided for @chatPromptTranslateLabel.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get chatPromptTranslateLabel;

  /// No description provided for @chatPromptTranslateText.
  ///
  /// In en, this message translates to:
  /// **'Translate this text into English keeping the tone:\n\n'**
  String get chatPromptTranslateText;

  /// No description provided for @chatPromptSummarizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get chatPromptSummarizeLabel;

  /// No description provided for @chatPromptSummarizeText.
  ///
  /// In en, this message translates to:
  /// **'Summarize this text in 5 key points:\n\n'**
  String get chatPromptSummarizeText;

  /// No description provided for @chatPromptExplainLabel.
  ///
  /// In en, this message translates to:
  /// **'Explain simply'**
  String get chatPromptExplainLabel;

  /// No description provided for @chatPromptExplainText.
  ///
  /// In en, this message translates to:
  /// **'Explain to me simply, like I\'m 12 years old:\n\n'**
  String get chatPromptExplainText;

  /// No description provided for @chatPromptReformulateLabel.
  ///
  /// In en, this message translates to:
  /// **'Rephrase'**
  String get chatPromptReformulateLabel;

  /// No description provided for @chatPromptReformulateText.
  ///
  /// In en, this message translates to:
  /// **'Rephrase this text more clearly and naturally:\n\n'**
  String get chatPromptReformulateText;

  /// No description provided for @chatPromptBrainstormLabel.
  ///
  /// In en, this message translates to:
  /// **'Brainstorm'**
  String get chatPromptBrainstormLabel;

  /// No description provided for @chatPromptBrainstormText.
  ///
  /// In en, this message translates to:
  /// **'Give me 10 original ideas on the following topic:\n\n'**
  String get chatPromptBrainstormText;

  /// No description provided for @chatBubbleUser.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get chatBubbleUser;

  /// No description provided for @chatBubbleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant message'**
  String get chatBubbleAssistant;

  /// No description provided for @chatBubbleCancelled.
  ///
  /// In en, this message translates to:
  /// **'(cancelled)'**
  String get chatBubbleCancelled;

  /// No description provided for @chatBubbleErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String chatBubbleErrorPrefix(String message);

  /// No description provided for @chatAnnounceGenerationStart.
  ///
  /// In en, this message translates to:
  /// **'Generation started'**
  String get chatAnnounceGenerationStart;

  /// No description provided for @chatAnnounceGenerationDone.
  ///
  /// In en, this message translates to:
  /// **'Reply complete'**
  String get chatAnnounceGenerationDone;

  /// No description provided for @chatAnnounceGenerationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Generation cancelled'**
  String get chatAnnounceGenerationCancelled;

  /// No description provided for @chatCopySnack.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopySnack;

  /// No description provided for @chatClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear this conversation?'**
  String get chatClearConfirmTitle;

  /// No description provided for @chatClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This conversation will be deleted from the phone (encrypted, unrecoverable). Other conversations are kept.'**
  String get chatClearConfirmBody;

  /// No description provided for @chatClearConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get chatClearConfirmYes;

  /// No description provided for @chatShareConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Share this conversation?'**
  String get chatShareConfirmTitle;

  /// No description provided for @chatShareConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The content will be passed to the app you choose (messages, mail, drive…). If that app sends its data over the Internet, your conversation will be exposed there.\n\nAI Tech itself stays 100% offline.'**
  String get chatShareConfirmBody;

  /// No description provided for @chatShareConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get chatShareConfirmYes;

  /// No description provided for @chatExportTitle.
  ///
  /// In en, this message translates to:
  /// **'# AI Tech conversation'**
  String get chatExportTitle;

  /// No description provided for @chatExportModel.
  ///
  /// In en, this message translates to:
  /// **'Model: {name}'**
  String chatExportModel(String name);

  /// No description provided for @chatExportDate.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String chatExportDate(String date);

  /// No description provided for @chatExportSpeakerUser.
  ///
  /// In en, this message translates to:
  /// **'## You'**
  String get chatExportSpeakerUser;

  /// No description provided for @chatExportSpeakerAssistant.
  ///
  /// In en, this message translates to:
  /// **'## Assistant'**
  String get chatExportSpeakerAssistant;

  /// No description provided for @chatExportSubject.
  ///
  /// In en, this message translates to:
  /// **'AI Tech conversation'**
  String get chatExportSubject;

  /// No description provided for @chatSourceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Source [{n}] · {title}'**
  String chatSourceDialogTitle(int n, String title);

  /// No description provided for @chatBlockOfCode.
  ///
  /// In en, this message translates to:
  /// **'Code block'**
  String get chatBlockOfCode;

  /// No description provided for @chatListTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatListTitle;

  /// No description provided for @chatListNewLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get chatListNewLabel;

  /// No description provided for @chatListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatListEmptyTitle;

  /// No description provided for @chatListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat to get going.'**
  String get chatListEmptySubtitle;

  /// No description provided for @chatListNewFull.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatListNewFull;

  /// No description provided for @chatListDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation?'**
  String get chatListDeleteConfirmTitle;

  /// No description provided for @chatListDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be deleted permanently (encrypted, unrecoverable).'**
  String chatListDeleteConfirmBody(String title);

  /// No description provided for @chatListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} {count, plural, =1{message} other{messages}} · {date}'**
  String chatListSubtitle(int count, String date);

  /// No description provided for @chatListRenameAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatListRenameAction;

  /// No description provided for @chatListRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename conversation'**
  String get chatListRenameTitle;

  /// No description provided for @chatListRenameHint.
  ///
  /// In en, this message translates to:
  /// **'New title (empty to reset)'**
  String get chatListRenameHint;

  /// No description provided for @chatListSwipeHintDelete.
  ///
  /// In en, this message translates to:
  /// **'Swipe left to delete'**
  String get chatListSwipeHintDelete;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentsImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get documentsImport;

  /// No description provided for @documentsPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get documentsPaste;

  /// No description provided for @documentsPickerError.
  ///
  /// In en, this message translates to:
  /// **'Picker error: {message}'**
  String documentsPickerError(String message);

  /// No description provided for @documentsNoPath.
  ///
  /// In en, this message translates to:
  /// **'The system did not provide a readable path.'**
  String get documentsNoPath;

  /// No description provided for @documentsUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format ({ext}). Use .txt, .md, .csv, or source code.'**
  String documentsUnsupportedFormat(String ext);

  /// No description provided for @documentsNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get documentsNotFound;

  /// No description provided for @documentsTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large ({size}). Max 1 MB.'**
  String documentsTooLarge(String size);

  /// No description provided for @documentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty.'**
  String get documentsEmpty;

  /// No description provided for @documentsRead.
  ///
  /// In en, this message translates to:
  /// **'Cannot read: {message}'**
  String documentsRead(String message);

  /// No description provided for @documentsIndexed.
  ///
  /// In en, this message translates to:
  /// **'Document indexed.'**
  String get documentsIndexed;

  /// No description provided for @documentsTextIndexed.
  ///
  /// In en, this message translates to:
  /// **'Text indexed.'**
  String get documentsTextIndexed;

  /// No description provided for @documentsPasteTitle.
  ///
  /// In en, this message translates to:
  /// **'Paste a text'**
  String get documentsPasteTitle;

  /// No description provided for @documentsTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get documentsTitleField;

  /// No description provided for @documentsContentField.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get documentsContentField;

  /// No description provided for @documentsIndexAction.
  ///
  /// In en, this message translates to:
  /// **'Index'**
  String get documentsIndexAction;

  /// No description provided for @documentsContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Content is empty.'**
  String get documentsContentEmpty;

  /// No description provided for @documentsContentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Text too long (max 1 MB).'**
  String get documentsContentTooLarge;

  /// No description provided for @documentsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this document?'**
  String get documentsDeleteConfirmTitle;

  /// No description provided for @documentsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'“{title}” will be removed from the index and from the phone (encrypted, unrecoverable).'**
  String documentsDeleteConfirmBody(String title);

  /// No description provided for @documentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents indexed'**
  String get documentsEmptyTitle;

  /// No description provided for @documentsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Import a text file or paste content so the AI can answer based on it.'**
  String get documentsEmptySubtitle;

  /// No description provided for @documentsCharCountThousand.
  ///
  /// In en, this message translates to:
  /// **'{n} k characters'**
  String documentsCharCountThousand(String n);

  /// No description provided for @documentsCharCount.
  ///
  /// In en, this message translates to:
  /// **'{n} characters'**
  String documentsCharCount(int n);

  /// No description provided for @documentsTileSemantic.
  ///
  /// In en, this message translates to:
  /// **'Document {title}, {chars}, imported {when}'**
  String documentsTileSemantic(String title, String chars, String when);

  /// No description provided for @modelPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get modelPickerTitle;

  /// No description provided for @modelPickerHeading.
  ///
  /// In en, this message translates to:
  /// **'Select your model'**
  String get modelPickerHeading;

  /// No description provided for @modelPickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Format .task or .litertlm, typically between 500 MB and 4 GB (Gemma, Qwen, Phi, Llama).'**
  String get modelPickerSubtitle;

  /// No description provided for @modelPickerRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get modelPickerRecommendation;

  /// No description provided for @modelPickerRecommendationText.
  ///
  /// In en, this message translates to:
  /// **'Gemma 3 1B int4 (~554 MB). Excellent in English and French, fast, 32K context window.'**
  String get modelPickerRecommendationText;

  /// No description provided for @modelPickerStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Download the model'**
  String get modelPickerStep1Title;

  /// No description provided for @modelPickerStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Opens Kaggle or HuggingFace in your browser — AI Tech does not download anything itself.'**
  String get modelPickerStep1Subtitle;

  /// No description provided for @modelPickerStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Import it here'**
  String get modelPickerStep2Title;

  /// No description provided for @modelPickerStep2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'The file is copied safely into the app sandbox and a SHA-256 is shown for verification.'**
  String get modelPickerStep2Subtitle;

  /// No description provided for @modelPickerDownload.
  ///
  /// In en, this message translates to:
  /// **'Download the model'**
  String get modelPickerDownload;

  /// No description provided for @modelPickerImport.
  ///
  /// In en, this message translates to:
  /// **'Import the file'**
  String get modelPickerImport;

  /// No description provided for @modelPickerSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Official Gemma 3 source'**
  String get modelPickerSourceTitle;

  /// No description provided for @modelPickerKaggle.
  ///
  /// In en, this message translates to:
  /// **'Kaggle (Google)'**
  String get modelPickerKaggle;

  /// No description provided for @modelPickerKaggleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'google/gemma-3 → tfLite'**
  String get modelPickerKaggleSubtitle;

  /// No description provided for @modelPickerHf.
  ///
  /// In en, this message translates to:
  /// **'HuggingFace (litert-community)'**
  String get modelPickerHf;

  /// No description provided for @modelPickerHfSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Gemma3-1B-IT'**
  String get modelPickerHfSubtitle;

  /// No description provided for @modelPickerNoBrowser.
  ///
  /// In en, this message translates to:
  /// **'No browser available.'**
  String get modelPickerNoBrowser;

  /// No description provided for @modelPickerCannotOpen.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the browser.'**
  String get modelPickerCannotOpen;

  /// No description provided for @modelPickerSysError.
  ///
  /// In en, this message translates to:
  /// **'System picker error: {message}'**
  String modelPickerSysError(String message);

  /// No description provided for @modelPickerNoPath.
  ///
  /// In en, this message translates to:
  /// **'The system did not provide a readable path. Copy the file to Downloads and try again.'**
  String get modelPickerNoPath;

  /// No description provided for @modelPickerWrongFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format (.task or .litertlm only)'**
  String get modelPickerWrongFormat;

  /// No description provided for @modelPickerNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get modelPickerNotFound;

  /// No description provided for @modelPickerTooSmall.
  ///
  /// In en, this message translates to:
  /// **'File too small to be a model.'**
  String get modelPickerTooSmall;

  /// No description provided for @modelPickerNotMediapipe.
  ///
  /// In en, this message translates to:
  /// **'The file does not look like a MediaPipe model.'**
  String get modelPickerNotMediapipe;

  /// No description provided for @modelInstallTitleCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying…'**
  String get modelInstallTitleCopying;

  /// No description provided for @modelInstallTitleDone.
  ///
  /// In en, this message translates to:
  /// **'Model copied'**
  String get modelInstallTitleDone;

  /// No description provided for @modelInstallCopyDescription.
  ///
  /// In en, this message translates to:
  /// **'Copying the model into the app sandbox and computing the SHA-256.'**
  String get modelInstallCopyDescription;

  /// No description provided for @modelInstallCopiedOf.
  ///
  /// In en, this message translates to:
  /// **'Copied: {copied} / {total}  ({pct} %)'**
  String modelInstallCopiedOf(String copied, String total, String pct);

  /// No description provided for @modelInstallPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get modelInstallPreparing;

  /// No description provided for @modelInstallDoneDescription.
  ///
  /// In en, this message translates to:
  /// **'The file has been copied to the app sandbox ({size}).'**
  String modelInstallDoneDescription(String size);

  /// No description provided for @modelInstallSha256Label.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 (compare with the official source if needed):'**
  String get modelInstallSha256Label;

  /// No description provided for @modelInstallSha256Sem.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint, copyable text'**
  String get modelInstallSha256Sem;

  /// No description provided for @modelInstallCopyHash.
  ///
  /// In en, this message translates to:
  /// **'Copy the hash'**
  String get modelInstallCopyHash;

  /// No description provided for @modelInstallSha256Copied.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 copied.'**
  String get modelInstallSha256Copied;

  /// No description provided for @modelInstallFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Copy failed'**
  String get modelInstallFailedTitle;

  /// No description provided for @modelInstallFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The model copy failed:\n\n{error}'**
  String modelInstallFailedBody(String error);

  /// No description provided for @memoryLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Low memory'**
  String get memoryLowTitle;

  /// No description provided for @memoryLowBody.
  ///
  /// In en, this message translates to:
  /// **'This model (~{needed} MB) is likely to crash the app: only {avail} MB free on this device. Forcing the load may cause a hard kill.'**
  String memoryLowBody(String needed, String avail);

  /// No description provided for @memoryLowProceed.
  ///
  /// In en, this message translates to:
  /// **'Load anyway'**
  String get memoryLowProceed;

  /// No description provided for @memoryLowCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get memoryLowCancel;

  /// No description provided for @modelShaChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint changed'**
  String get modelShaChangedTitle;

  /// No description provided for @modelShaChangedBody.
  ///
  /// In en, this message translates to:
  /// **'A model with the same name already existed with a different fingerprint.\n\nPrevious: {previous}\nNew: {current}\n\nIf you did not intentionally replace this file, refuse the install.'**
  String modelShaChangedBody(String previous, String current);

  /// No description provided for @modelShaChangedReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get modelShaChangedReplace;

  /// No description provided for @modelShaChangedRefuse.
  ///
  /// In en, this message translates to:
  /// **'Refuse'**
  String get modelShaChangedRefuse;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AI Tech'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An AI assistant that runs entirely on your phone.'**
  String get onboardingWelcomeSubtitle;

  /// No description provided for @onboardingFeatureOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'100% offline'**
  String get onboardingFeatureOfflineTitle;

  /// No description provided for @onboardingFeatureOfflineText.
  ///
  /// In en, this message translates to:
  /// **'No Internet connection. The app does not even have permission to use one.'**
  String get onboardingFeatureOfflineText;

  /// No description provided for @onboardingFeatureCryptoTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted conversations'**
  String get onboardingFeatureCryptoTitle;

  /// No description provided for @onboardingFeatureCryptoText.
  ///
  /// In en, this message translates to:
  /// **'AES-256-GCM with a key in the Android Keystore.'**
  String get onboardingFeatureCryptoText;

  /// No description provided for @onboardingFeaturePanicTitle.
  ///
  /// In en, this message translates to:
  /// **'Panic mode'**
  String get onboardingFeaturePanicTitle;

  /// No description provided for @onboardingFeaturePanicText.
  ///
  /// In en, this message translates to:
  /// **'Wipes key and history with one tap. Final.'**
  String get onboardingFeaturePanicText;

  /// No description provided for @onboardingFeatureOpenSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source code'**
  String get onboardingFeatureOpenSourceTitle;

  /// No description provided for @onboardingFeatureOpenSourceText.
  ///
  /// In en, this message translates to:
  /// **'Apache 2.0. Verify our promises yourself.'**
  String get onboardingFeatureOpenSourceText;

  /// No description provided for @onboardingAboutLink.
  ///
  /// In en, this message translates to:
  /// **'About · Privacy'**
  String get onboardingAboutLink;

  /// No description provided for @onboardingImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get onboardingImportTitle;

  /// No description provided for @onboardingImportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download a model in .task or .litertlm format (Gemma, Qwen, Phi, Llama…) then select it here.'**
  String get onboardingImportSubtitle;

  /// No description provided for @onboardingImportCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get onboardingImportCardTitle;

  /// No description provided for @onboardingImportCardBody.
  ///
  /// In en, this message translates to:
  /// **'Gemma 3 1B (int4) — 554 MB, excellent in English and French, fast even on mid-range phones.'**
  String get onboardingImportCardBody;

  /// No description provided for @onboardingImportCardSource.
  ///
  /// In en, this message translates to:
  /// **'Source: Kaggle → google/gemma-3 → tfLite → gemma3-1b-it-int4'**
  String get onboardingImportCardSource;

  /// No description provided for @onboardingImportSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get onboardingImportSaving;

  /// No description provided for @onboardingImportSelectAction.
  ///
  /// In en, this message translates to:
  /// **'Select a model'**
  String get onboardingImportSelectAction;

  /// No description provided for @onboardingAnnounceStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2 of 2: choose a model'**
  String get onboardingAnnounceStep2;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsSectionModels;

  /// No description provided for @settingsSectionGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get settingsSectionGeneration;

  /// No description provided for @settingsSectionDataSecurity.
  ///
  /// In en, this message translates to:
  /// **'Data and security'**
  String get settingsSectionDataSecurity;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsAddModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a model'**
  String get settingsAddModelTitle;

  /// No description provided for @settingsAddModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'.task or .litertlm'**
  String get settingsAddModelSubtitle;

  /// No description provided for @settingsModelAdded.
  ///
  /// In en, this message translates to:
  /// **'Model added'**
  String get settingsModelAdded;

  /// No description provided for @settingsModelActive.
  ///
  /// In en, this message translates to:
  /// **'Active model: {name}'**
  String settingsModelActive(String name);

  /// No description provided for @settingsRemoveModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this model?'**
  String get settingsRemoveModelTitle;

  /// No description provided for @settingsRemoveModelBody.
  ///
  /// In en, this message translates to:
  /// **'The file {name} will not be deleted from storage. It will only be removed from the registered models list.'**
  String settingsRemoveModelBody(String name);

  /// No description provided for @settingsRemoveModelYes.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get settingsRemoveModelYes;

  /// No description provided for @settingsSliderCreativity.
  ///
  /// In en, this message translates to:
  /// **'Creativity (temperature)'**
  String get settingsSliderCreativity;

  /// No description provided for @settingsSliderCreativityHelper.
  ///
  /// In en, this message translates to:
  /// **'Low = factual and stable. High = creative and varied.'**
  String get settingsSliderCreativityHelper;

  /// No description provided for @settingsSliderDiversity.
  ///
  /// In en, this message translates to:
  /// **'Diversity (top-K)'**
  String get settingsSliderDiversity;

  /// No description provided for @settingsSliderDiversityHelper.
  ///
  /// In en, this message translates to:
  /// **'Number of candidate words considered at each step.'**
  String get settingsSliderDiversityHelper;

  /// No description provided for @settingsSliderContext.
  ///
  /// In en, this message translates to:
  /// **'Context length (maxTokens)'**
  String get settingsSliderContext;

  /// No description provided for @settingsSliderContextHelper.
  ///
  /// In en, this message translates to:
  /// **'Conversation memory. Higher = more RAM used.'**
  String get settingsSliderContextHelper;

  /// No description provided for @settingsSliderSemantic.
  ///
  /// In en, this message translates to:
  /// **'{label}, value {value}'**
  String settingsSliderSemantic(String label, String value);

  /// No description provided for @settingsClearChats.
  ///
  /// In en, this message translates to:
  /// **'Clear conversations'**
  String get settingsClearChats;

  /// No description provided for @settingsClearChatsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Deletes the encrypted history. Models and settings are kept.'**
  String get settingsClearChatsSubtitle;

  /// No description provided for @settingsClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all conversations?'**
  String get settingsClearConfirmTitle;

  /// No description provided for @settingsClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The encrypted history will be deleted. Your models and settings are kept.'**
  String get settingsClearConfirmBody;

  /// No description provided for @settingsClearConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearConfirmYes;

  /// No description provided for @settingsClearDone.
  ///
  /// In en, this message translates to:
  /// **'Conversations cleared'**
  String get settingsClearDone;

  /// No description provided for @settingsPanic.
  ///
  /// In en, this message translates to:
  /// **'Panic mode'**
  String get settingsPanic;

  /// No description provided for @settingsPanicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Wipes key + history + models + settings.'**
  String get settingsPanicSubtitle;

  /// No description provided for @settingsPanicConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This action wipes in bulk:\n\n• all encrypted conversations\n• the encryption key (unrecoverable)\n• the registered models list\n• all settings\n\nThe .task files you downloaded on your phone are not touched. The app restarts as on first launch.\n\nContinue?'**
  String get settingsPanicConfirmBody;

  /// No description provided for @settingsPanicConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Wipe everything'**
  String get settingsPanicConfirmYes;

  /// No description provided for @settingsPanicAnnounceDone.
  ///
  /// In en, this message translates to:
  /// **'Wipe complete, returning to home'**
  String get settingsPanicAnnounceDone;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version, legal, support'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageFr.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get settingsLanguageFr;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguageChangedFr.
  ///
  /// In en, this message translates to:
  /// **'Langue changée en français'**
  String get settingsLanguageChangedFr;

  /// No description provided for @settingsLanguageChangedEn.
  ///
  /// In en, this message translates to:
  /// **'Language switched to English'**
  String get settingsLanguageChangedEn;

  /// No description provided for @settingsModelSemantic.
  ///
  /// In en, this message translates to:
  /// **'Model {name}, {family}, {filetype}, {size}, {active, select, true{active} other{inactive}}'**
  String settingsModelSemantic(
    String name,
    String family,
    String filetype,
    String size,
    String active,
  );

  /// No description provided for @settingsVerifyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Verify integrity (SHA-256)'**
  String get settingsVerifyTooltip;

  /// No description provided for @settingsRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get settingsRemoveTooltip;

  /// No description provided for @settingsHashStored.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 computed and saved'**
  String get settingsHashStored;

  /// No description provided for @settingsHashOk.
  ///
  /// In en, this message translates to:
  /// **'Integrity verified'**
  String get settingsHashOk;

  /// No description provided for @settingsHashOkBody.
  ///
  /// In en, this message translates to:
  /// **'The SHA-256 matches the saved one:\n\n{hash}'**
  String settingsHashOkBody(String hash);

  /// No description provided for @settingsHashMismatch.
  ///
  /// In en, this message translates to:
  /// **'Different SHA-256!'**
  String get settingsHashMismatch;

  /// No description provided for @settingsHashMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'The file has been modified since installation.\n\nExpected: {expected}\n\nGot: {got}'**
  String settingsHashMismatchBody(String expected, String got);

  /// No description provided for @settingsHashIgnore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get settingsHashIgnore;

  /// No description provided for @settingsHashDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Disable this model'**
  String get settingsHashDeactivate;

  /// No description provided for @settingsHashVerifyError.
  ///
  /// In en, this message translates to:
  /// **'Verification error: {message}'**
  String settingsHashVerifyError(String message);

  /// No description provided for @settingsHashFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found.'**
  String get settingsHashFileNotFound;

  /// No description provided for @settingsHashShortNotStored.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 not saved'**
  String get settingsHashShortNotStored;

  /// No description provided for @settingsHashShortPrefix.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 {prefix}…'**
  String settingsHashShortPrefix(String prefix);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutPromiseTitle.
  ///
  /// In en, this message translates to:
  /// **'Our commitment'**
  String get aboutPromiseTitle;

  /// No description provided for @aboutPromise1.
  ///
  /// In en, this message translates to:
  /// **'100% offline — the Internet permission is removed from the manifest (tools:node=\"remove\"). No cloud, no account.'**
  String get aboutPromise1;

  /// No description provided for @aboutPromise2.
  ///
  /// In en, this message translates to:
  /// **'Encrypted conversations: AES-256-GCM with a unique key stored in the Android Keystore.'**
  String get aboutPromise2;

  /// No description provided for @aboutPromise3.
  ///
  /// In en, this message translates to:
  /// **'Panic mode: wipes key + history with one tap.'**
  String get aboutPromise3;

  /// No description provided for @aboutPromise4.
  ///
  /// In en, this message translates to:
  /// **'Source code fully published under Apache 2.0.'**
  String get aboutPromise4;

  /// No description provided for @aboutPromise5.
  ///
  /// In en, this message translates to:
  /// **'No telemetry, no tracker, no advertising.'**
  String get aboutPromise5;

  /// No description provided for @aboutHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get aboutHowTitle;

  /// No description provided for @aboutHow1.
  ///
  /// In en, this message translates to:
  /// **'AI Tech runs an open-source language model (Gemma, Qwen, Phi, Llama…) directly on your phone via Google\'s MediaPipe LLM Inference library.'**
  String get aboutHow1;

  /// No description provided for @aboutHow2.
  ///
  /// In en, this message translates to:
  /// **'You download the model of your choice in .task or .litertlm format from Kaggle or HuggingFace, then import it into the app. No data is sent to the model publisher or any third-party service.'**
  String get aboutHow2;

  /// No description provided for @aboutHow3.
  ///
  /// In en, this message translates to:
  /// **'Updates: AI Tech does not contact any update server, unlike other Files Tech apps, to stay consistent with the offline promise. New versions are published on GitHub Releases and F-Droid — you decide when to update.'**
  String get aboutHow3;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'Apache 2.0 — Files Tech'**
  String get aboutLicense;

  /// No description provided for @spikeTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Tech — Spike'**
  String get spikeTitle;

  /// No description provided for @spikeNoModel.
  ///
  /// In en, this message translates to:
  /// **'No model loaded.'**
  String get spikeNoModel;

  /// No description provided for @spikeNoModelSelected.
  ///
  /// In en, this message translates to:
  /// **'No model selected'**
  String get spikeNoModelSelected;

  /// No description provided for @spikeWrongFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format: choose a .task file'**
  String get spikeWrongFormat;

  /// No description provided for @spikeInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing the model…'**
  String get spikeInstalling;

  /// No description provided for @spikeLoadingHint.
  ///
  /// In en, this message translates to:
  /// **'Loading into memory (may take 10–20 s)…'**
  String get spikeLoadingHint;

  /// No description provided for @spikeReady.
  ///
  /// In en, this message translates to:
  /// **'Model ready.'**
  String get spikeReady;

  /// No description provided for @spikeGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get spikeGenerating;

  /// No description provided for @spikeFinished.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get spikeFinished;

  /// No description provided for @spikeGenerationError.
  ///
  /// In en, this message translates to:
  /// **'Generation error: {message}'**
  String spikeGenerationError(String message);

  /// No description provided for @spikePromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get spikePromptLabel;

  /// No description provided for @spikePromptDefault.
  ///
  /// In en, this message translates to:
  /// **'Explain photosynthesis in 3 sentences.'**
  String get spikePromptDefault;

  /// No description provided for @spikeRun.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get spikeRun;

  /// No description provided for @spikeRunning.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get spikeRunning;

  /// No description provided for @spikeChooseTask.
  ///
  /// In en, this message translates to:
  /// **'Choose a .task'**
  String get spikeChooseTask;

  /// No description provided for @spikeMetricsTitle.
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get spikeMetricsTitle;

  /// No description provided for @spikeMetricFirstToken.
  ///
  /// In en, this message translates to:
  /// **'First token'**
  String get spikeMetricFirstToken;

  /// No description provided for @spikeMetricFirstTokenValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String spikeMetricFirstTokenValue(int ms);

  /// No description provided for @spikeMetricTotalDuration.
  ///
  /// In en, this message translates to:
  /// **'Total duration'**
  String get spikeMetricTotalDuration;

  /// No description provided for @spikeMetricTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens (chunks)'**
  String get spikeMetricTokens;

  /// No description provided for @spikeMetricChars.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get spikeMetricChars;

  /// No description provided for @spikeMetricTokensPerSec.
  ///
  /// In en, this message translates to:
  /// **'Tokens/s'**
  String get spikeMetricTokensPerSec;

  /// No description provided for @spikeMetricCharsPerSec.
  ///
  /// In en, this message translates to:
  /// **'Chars/s'**
  String get spikeMetricCharsPerSec;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
