import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/l10n/planned_feature.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/scientific_calculator.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';

/// Every piece of user-facing text, in one typed interface.
///
/// [EnglishStrings] and [ArabicStrings] each implement it, so a text missing from either language is a compile error.
/// Texts with values are methods. The failure and field-problem messages are translated here by switching exhaustively
/// over the sealed failure types.
abstract class AppStrings {
  /// Creates the strings.
  const AppStrings();

  /// The language code (`en` or `ar`).
  String get languageCode;

  /// True for right-to-left languages.
  bool get isRtl => languageCode == 'ar';

  /// Wraps text that is not in this language (server text, names) so it keeps its own direction inside a sentence.
  String isolate(String text) => isRtl ? '\u2066$text\u2069' : text;

  // ---- General ----

  /// The product name.
  String get appName;

  /// Retry button.
  String get retry;

  /// Cancel button.
  String get cancel;

  /// Close button.
  String get close;

  /// Back button.
  String get back;

  /// Sign out action.
  String get signOut;

  /// Generic loading text.
  String get loading;

  /// Title of an error view.
  String get errorTitle;

  /// Label of the server endpoint a missing feature needs.
  String get missingEndpointLabel;

  /// Heading of the language switch.
  String get languageLabel;

  /// Shown while the stored session is being restored.
  String get restoringSession;

  // ---- Navigation ----

  /// Home tab.
  String get homeTab;

  /// Exams tab.
  String get examsTab;

  /// Results tab.
  String get resultsTab;

  /// Incidents tab.
  String get incidentsTab;

  /// Profile tab.
  String get profileTab;

  // ---- Sign in ----

  /// Sign-in title.
  String get loginTitle;

  /// Sign-in subtitle.
  String get loginSubtitle;

  /// Email field label.
  String get emailLabel;

  /// Password field label.
  String get passwordLabel;

  /// Tooltip to reveal the password.
  String get showPassword;

  /// Tooltip to hide the password.
  String get hidePassword;

  /// Sign-in button.
  String get signInButton;

  /// Sign-in button while working.
  String get signingIn;

  /// Link to the forgot-password screen.
  String get forgotPasswordLink;

  /// The sentence that replaces any "create account" link.
  String get accountsCreatedByAdmin;

  // ---- Forgot password ----

  /// Forgot-password title.
  String get forgotPasswordTitle;

  /// Explains there is no automatic reset.
  String get forgotPasswordBody;

  /// Link back to sign-in.
  String get backToSignIn;

  // ---- Change password ----

  /// Voluntary change-password title.
  String get changePasswordTitle;

  /// Forced change-password title.
  String get changePasswordForcedTitle;

  /// Why a change is forced.
  String get changePasswordForcedBody;

  /// Current-password label.
  String get currentPasswordLabel;

  /// New-password label.
  String get newPasswordLabel;

  /// Confirm-new-password label.
  String get confirmNewPasswordLabel;

  /// The password policy.
  String get passwordPolicyHint;

  /// Change-password button.
  String get changePasswordButton;

  /// Confirmation after a change.
  String get passwordChanged;

  /// Sign-out link on the forced screen.
  String get signOutInstead;

  // ---- Dashboards, profile ----

  /// Greeting.
  String welcomeUser(String name);

  /// The name of a role.
  String roleName(UserRole role);

  /// Title of a screen that is not built.
  String get notBuiltTitle;

  /// Body of a screen that is not built; [feature] is the feature's name.
  String notBuiltBody(String feature);

  /// The name of a feature that is not built yet.
  String featureName(PlannedFeature feature);

  /// Profile title.
  String get profileTitle;

  /// Heading of the identity section.
  String get identitySection;

  /// Full-name label.
  String get fullNameLabel;

  /// Role label.
  String get roleLabel;

  /// Heading of the data-location section.
  String get dataLocationSection;

  /// Where data lives.
  String get dataLocationBody;

  /// Heading of the privacy section.
  String get privacySection;

  /// Privacy text for the features built so far.
  String get privacyBody;

  /// Heading of the language section.
  String get languageSection;

  // ---- Failures ----

  /// Generic validation text.
  String get validationGeneric;

  /// Generic conflict text.
  String get conflictGeneric;

  /// Incorrect email or password.
  String get failureInvalidCredentials;

  /// Locked account.
  String get failureAccountLocked;

  /// Deactivated account.
  String get failureAccountDeactivated;

  /// Expired temporary password.
  String get failureTemporaryPasswordExpired;

  /// Session ended.
  String get failureSessionExpired;

  /// Password change required.
  String get failurePasswordChangeRequired;

  /// Forbidden.
  String get failureForbidden;

  /// Not found.
  String get failureNotFound;

  /// No connection.
  String get failureNetwork;

  /// Timeout.
  String get failureTimeout;

  /// Rate limited.
  String get failureRateLimited;

  /// Server error.
  String get failureServer;

  /// Device storage error.
  String get failureStorage;

  /// Unreadable data; [field] names what could not be read.
  String failureParse(String field);

  /// A server endpoint that does not exist yet.
  String failureEndpointMissing(String endpoint);

  /// A capability that cannot work; [because] is the reason when known.
  String failureUnavailable(String capability, String? because);

  // ---- Field problems ----

  /// A required field is empty.
  String get fieldRequired;

  /// Not an email address.
  String get fieldInvalidEmail;

  /// Password policy not met.
  String get fieldPasswordPolicy;

  /// Confirmation differs.
  String get fieldPasswordsDiffer;

  /// Wrong current password.
  String get fieldCurrentPasswordIncorrect;

  /// New password equals the current one.
  String get fieldNewPasswordSame;

  /// Text too long.
  String get fieldTooLong;

  /// The text of a field problem.
  String fieldProblemMessage(FieldProblem problem) => switch (problem) {
    ServerFieldProblem(:final text) => isolate(text),
    KnownFieldProblem(:final reason) => switch (reason) {
      FieldReason.required => fieldRequired,
      FieldReason.invalidEmail => fieldInvalidEmail,
      FieldReason.passwordPolicy => fieldPasswordPolicy,
      FieldReason.passwordsDiffer => fieldPasswordsDiffer,
      FieldReason.currentPasswordIncorrect => fieldCurrentPasswordIncorrect,
      FieldReason.newPasswordSameAsCurrent => fieldNewPasswordSame,
      FieldReason.tooLong => fieldTooLong,
      FieldReason.invalidCharacters => fieldInvalidCharacters,
      FieldReason.outOfRange => fieldOutOfRange,
      FieldReason.windowTooShort => fieldWindowTooShort,
    },
  };

  /// The text of a failure, in this language. Server text (English) is shown as sent and isolated.
  String failureMessage(AppFailure failure) => switch (failure) {
    ValidationFailure(:final fields) => fields.isEmpty ? validationGeneric : fieldProblemMessage(fields.values.first),
    InvalidCredentialsFailure() => failureInvalidCredentials,
    AccountLockedFailure() => failureAccountLocked,
    AccountDeactivatedFailure() => failureAccountDeactivated,
    TemporaryPasswordExpiredFailure() => failureTemporaryPasswordExpired,
    SessionExpiredFailure() => failureSessionExpired,
    PasswordChangeRequiredFailure() => failurePasswordChangeRequired,
    ForbiddenFailure() => failureForbidden,
    NotFoundFailure() => failureNotFound,
    ConflictFailure(:final code, :final serverDetail) => switch (code) {
      'duplicate_account' => conflictDuplicateAccount,
      'account_already_active' => conflictAlreadyActive,
      'account_already_deactivated' => conflictAlreadyDeactivated,
      'exam_not_editable' => conflictExamNotEditable,
      'exam_already_published' => conflictExamAlreadyPublished,
      'exam_archived' => conflictExamArchived,
      'exam_not_unpublishable' => conflictExamNotUnpublishable,
      'exam_not_archivable' => conflictExamNotArchivable,
      'exam_not_deletable' => conflictExamNotDeletable,
      'question_exists' => conflictQuestionExists,
      _ => serverDetail == null ? conflictGeneric : isolate(serverDetail),
    },
    ExamNotPublishableFailure(:final problems) =>
      problems.isEmpty ? failureExamNotPublishable : publishProblemMessage(problems.first),
    QuestionInvalidFailure(:final problems) => questionProblemMessage(problems.first),
    DocumentRejectedFailure(:final reason) => documentRejectionMessage(reason),
    NetworkFailure() => failureNetwork,
    TimeoutFailure() => failureTimeout,
    RateLimitedFailure() => failureRateLimited,
    ServerFailure() => failureServer,
    StorageFailure() => failureStorage,
    ParseFailure(:final field) => failureParse(field),
    EndpointMissingFailure(:final endpoint) => failureEndpointMissing(endpoint),
    UnavailableFailure(:final capability, :final because) => failureUnavailable(capability, because),
  };

  /// Title of the administrator account list.
  String get adminAccountsTitle;

  /// Button that opens the create-account screen.
  String get adminAddAccount;

  /// Label of the role filter.
  String get filterRole;

  /// Label of the status filter.
  String get filterStatus;

  /// Filter choice: no filtering.
  String get filterAll;

  /// The name of an account status.
  String accountStatusName(AccountStatus status);

  /// No accounts exist at all.
  String get accountsEmptyTitle;

  /// No account matches the filters.
  String get accountsEmptyFiltered;

  /// How many accounts are on this page of how many.
  String accountsShowing(int shown, int total);

  /// Previous page button.
  String get previousPage;

  /// Next page button.
  String get nextPage;

  /// The current page number.
  String pageNumber(int page);

  /// Badge: sign-in is locked.
  String get lockedBadge;

  /// Badge: a temporary password is in use.
  String get mustChangePasswordBadge;

  /// Title of the account detail.
  String get accountDetailTitle;

  /// Label of the account status.
  String get accountStatusLabel;

  /// Label of the creation time.
  String get createdAtLabel;

  /// Label of the last sign-in time.
  String get lastLoginLabel;

  /// The account has never signed in.
  String get neverSignedIn;

  /// Label of the last status change time.
  String get statusChangedLabel;

  /// Label of the reason for the last status change.
  String get statusReasonLabel;

  /// Label of the temporary password expiry.
  String get temporaryPasswordExpiresLabel;

  /// Label of the lock state.
  String get passwordLockedLabel;

  /// Yes.
  String get yes;

  /// No.
  String get no;

  /// Tells which time zone the times are shown in.
  String timeZoneNote(String zone);

  /// Action: issue a temporary password.
  String get issueTemporaryPassword;

  /// Title of the confirmation.
  String get issuePasswordTitle;

  /// Body of the confirmation.
  String issuePasswordBody(String name);

  /// Action: deactivate.
  String get deactivateAccount;

  /// Title of the deactivate dialog.
  String get deactivateTitle;

  /// Body of the deactivate dialog.
  String deactivateBody(String name);

  /// Label of a required reason field.
  String get reasonRequiredLabel;

  /// Label of an optional reason field.
  String get reasonOptionalLabel;

  /// Action: reactivate.
  String get reactivateAccount;

  /// Title of the reactivate dialog.
  String get reactivateTitle;

  /// Body of the reactivate dialog.
  String reactivateBody(String name);

  /// Shown after deactivating.
  String get accountDeactivatedNotice;

  /// Shown after reactivating.
  String get accountReactivatedNotice;

  /// Title of the create-account screen.
  String get createAccountTitle;

  /// Label of the instructor/student choice.
  String get accountTypeLabel;

  /// Explains what creating an account does.
  String get createAccountHint;

  /// Button that creates the account.
  String get createAccountButton;

  /// Title of the one-time password sheet.
  String get temporaryPasswordTitle;

  /// Warns that the password is shown once.
  String get temporaryPasswordOnce;

  /// Who the password is for.
  String temporaryPasswordFor(String name, String email);

  /// When the password stops working.
  String temporaryPasswordExpires(String when);

  /// Copy the password.
  String get copyPassword;

  /// Confirmation after copying.
  String get passwordCopied;

  /// Open an email draft with the password.
  String get sendByEmail;

  /// No email app could be opened.
  String get emailNotAvailable;

  /// Subject of the email draft.
  String get temporaryPasswordEmailSubject;

  /// Body of the email draft.
  String temporaryPasswordEmailBody(String name, String email, String password, String when);

  /// Button that closes the one-time sheet.
  String get iHaveSavedIt;

  /// An account with that email exists.
  String get conflictDuplicateAccount;

  /// The account is already active.
  String get conflictAlreadyActive;

  /// The account is already deactivated.
  String get conflictAlreadyDeactivated;

  /// Text contains control characters.
  String get fieldInvalidCharacters;

  /// A number is outside the allowed range.
  String get fieldOutOfRange;

  /// The window is shorter than the duration.
  String get fieldWindowTooShort;

  /// Publishing was refused.
  String get failureExamNotPublishable;

  /// The exam can no longer be changed.
  String get conflictExamNotEditable;

  /// Already published.
  String get conflictExamAlreadyPublished;

  /// The exam is archived.
  String get conflictExamArchived;

  /// Cannot return to draft.
  String get conflictExamNotUnpublishable;

  /// Cannot archive.
  String get conflictExamNotArchivable;

  /// Cannot delete.
  String get conflictExamNotDeletable;

  /// The question already exists.
  String get conflictQuestionExists;

  /// Explains why a question is not valid.
  String questionProblemMessage(QuestionProblem problem);

  /// Explains one reason an exam cannot be published.
  String publishProblemMessage(PublishProblem problem);

  /// The name of an exam status.
  String examStatusName(ExamStatus status);

  /// The name of a question type.
  String questionTypeName(QuestionType type);

  /// How a question type is marked.
  String questionTypeHint(QuestionType type);

  /// Title of the instructor exam list.
  String get examsTitle;

  /// Button that starts creating an exam.
  String get createExamButton;

  /// The instructor has no exams.
  String get examsEmptyTitle;

  /// How to make the first exam.
  String get examsEmptyBody;

  /// No exam matches the filter.
  String get examsEmptyFiltered;

  /// How many exams are on this page.
  String examsShowing(int shown, int total);

  /// One line about an exam.
  String examSummary(String course, int minutes, int questions);

  /// Title of the method choice.
  String get examMethodTitle;

  /// Option: create by hand.
  String get examMethodManual;

  /// Explains the manual option.
  String get examMethodManualBody;

  /// Option: import from Word.
  String get examMethodWord;

  /// Explains the Word option.
  String get examMethodWordBody;

  /// Both methods ask for the details first.
  String get examMethodDetailsFirst;

  /// Wizard title for a new exam.
  String get wizardNewTitle;

  /// Wizard title for an existing exam.
  String get wizardEditTitle;

  /// Which step of the wizard.
  String wizardStepOf(int step, int total, String name);

  /// Wizard step name.
  String get stepDetails;

  /// Wizard step name.
  String get stepQuestions;

  /// Wizard step name.
  String get stepSettings;

  /// Wizard step name.
  String get stepSchedule;

  /// Wizard step name.
  String get stepReview;

  /// Go to the next step.
  String get nextStep;

  /// Go to the previous step.
  String get previousStep;

  /// Save this step and continue.
  String get saveAndContinue;

  /// Confirms a save on this device.
  String get savedNotice;

  /// Label.
  String get examTitleLabel;

  /// Label.
  String get examCourseLabel;

  /// Label.
  String get examDescriptionLabel;

  /// Label.
  String get examInstructionsLabel;

  /// Label.
  String get examDurationLabel;

  /// Label.
  String get examPassMarkLabel;

  /// The version of an exam.
  String examVersionLabel(int version);

  /// Explains versions.
  String get examVersionHelp;

  /// How many questions and marks.
  String questionsSummary(int count, String marks);

  /// Add a question.
  String get addQuestion;

  /// No questions yet.
  String get questionsEmpty;

  /// Question n.
  String questionNumber(int number);

  /// The marks of a question.
  String marksValue(String marks);

  /// Move a question up.
  String get moveUp;

  /// Move a question down.
  String get moveDown;

  /// Edit a question.
  String get editQuestion;

  /// Delete a question.
  String get deleteQuestion;

  /// Confirm deleting a question.
  String get deleteQuestionTitle;

  /// Explains deleting a question.
  String get deleteQuestionBody;

  /// Badge: flagged for review.
  String get needsReviewBadge;

  /// Badge: answer key stale.
  String get answerKeyStaleBadge;

  /// Badge: came from Word.
  String get wordBadge;

  /// Title of the editor for a new question.
  String get newQuestionTitle;

  /// Title of the editor for an existing question.
  String get editQuestionTitle;

  /// Label.
  String get questionTypeLabel;

  /// Label.
  String get questionTextLabel;

  /// Label.
  String get marksFieldLabel;

  /// Label of option n.
  String optionLabel(int number);

  /// Add an option.
  String get addOption;

  /// Remove an option.
  String get removeOption;

  /// Tooltip: mark an option as correct.
  String get markCorrect;

  /// Label.
  String get modelAnswerLabel;

  /// Label.
  String get explanationLabel;

  /// Checkbox: the instructor checked the answer.
  String get confirmAnswerKey;

  /// Save the question.
  String get saveQuestion;

  /// Confirms saving a question.
  String get questionSavedNotice;

  /// Setting.
  String get settingRandomizeQuestions;

  /// Setting.
  String get settingRandomizeOptions;

  /// Setting.
  String get settingCalculator;

  /// Setting.
  String get settingBackward;

  /// Setting.
  String get settingShowResult;

  /// Setting.
  String get settingShowExplanations;

  /// Heading of the proctoring rules.
  String get proctoringRulesHeading;

  /// The name of an incident category.
  String incidentCategoryName(IncidentCategory category);

  /// Says an AI rule cannot work.
  String get ruleInactiveNoDetector;

  /// Says the rule fires immediately.
  String get ruleImmediateHint;

  /// Says the rule needs the threshold.
  String get ruleSustainedHint;

  /// Setting.
  String get settingThreshold;

  /// Explains the threshold.
  String get settingThresholdHelp;

  /// Setting.
  String get settingBuffer;

  /// Explains the buffer is not available.
  String get settingBufferHelp;

  /// Setting.
  String get settingMaxWarnings;

  /// Explains the warning limit.
  String get settingMaxWarningsHelp;

  /// Label.
  String get scheduleOpensLabel;

  /// Label.
  String get scheduleClosesLabel;

  /// Nothing chosen yet.
  String get scheduleNotSet;

  /// Choose a date and time.
  String get scheduleChoose;

  /// Explains the window.
  String get scheduleHelp;

  /// Nothing blocks publishing.
  String get reviewReady;

  /// How many things block publishing.
  String reviewBlocked(int count);

  /// Publish button.
  String get publishExam;

  /// Published.
  String get publishedNotice;

  /// Confirm publishing.
  String get publishConfirmTitle;

  /// Explains publishing.
  String get publishConfirmBody;

  /// Return to draft.
  String get unpublishExam;

  /// Archive.
  String get archiveExam;

  /// Confirm archiving.
  String get archiveConfirmTitle;

  /// Explains archiving.
  String get archiveConfirmBody;

  /// Delete a draft.
  String get deleteDraft;

  /// Confirm deleting.
  String get deleteDraftTitle;

  /// Explains deleting.
  String get deleteDraftBody;

  /// Shown for an exam that cannot be edited.
  String get examNotEditableNotice;

  /// Open an exam.
  String get examDetailOpen;

  /// Explains why a Word file was turned away.
  String documentRejectionMessage(DocumentRejection reason);

  /// Title of the import screen.
  String get importTitle;

  /// What the importer does.
  String get importIntro;

  /// Pick a file.
  String get importChooseFile;

  /// Pick another file.
  String get importChooseAnother;

  /// Opens the template help.
  String get importTemplateHelp;

  /// Title of the template help.
  String get importTemplateTitle;

  /// The rules of the template.
  String get importTemplateRules;

  /// Copy the template text.
  String get importTemplateCopy;

  /// Confirms copying.
  String get importTemplateCopied;

  /// Save the template file.
  String get importTemplateSave;

  /// Confirms saving.
  String get importTemplateSaved;

  /// Saving failed.
  String get importTemplateSaveFailed;

  /// Shown while reading.
  String importReading(String name);

  /// The file being reviewed.
  String importFileLabel(String name);

  /// The review summary.
  String importSummary(int found, int ready, int attention, int notImported);

  /// Filter: only questions that need attention.
  String get importOnlyAttention;

  /// No question matches the filter.
  String get importNothingToShow;

  /// No questions in the document.
  String get importNoQuestionsFound;

  /// The review status of a question, as a word.
  String importStatusName(ImportStatus status);

  /// Which question in the document.
  String importQuestionHeading(int number, int line);

  /// The collapsible source text.
  String get importAsWritten;

  /// A numbered source line.
  String importLine(int line, String text);

  /// Leave a question out.
  String get importDontImport;

  /// Bring a question back.
  String get importDoImport;

  /// Confirm that a question was checked.
  String get importAcknowledge;

  /// A question was checked.
  String get importAcknowledged;

  /// Nothing wrong.
  String get importNoProblems;

  /// Topic and difficulty are only labels.
  String get importReadOnlyNote;

  /// Label.
  String get topicLabel;

  /// Label.
  String get difficultyLabel;

  /// Heading of the unattached text.
  String get importUnattachedTitle;

  /// Explains the unattached text.
  String get importUnattachedBody;

  /// Titles and headings are read but unused.
  String importIgnoredNote(int count);

  /// Heading of the content that could not be imported.
  String get importSkippedTitle;

  /// What kind of content could not be imported.
  String importSkippedKindName(SkippedKind kind);

  /// One piece of content that could not be imported.
  String importSkippedItem(String kindName, int afterLine);

  /// Add the reviewed questions.
  String importContinue(int count);

  /// Nothing to add.
  String get importContinueNone;

  /// Some questions cannot be added yet.
  String get importContinueBlocked;

  /// Confirms the import.
  String importAdded(int count);

  /// Explains one thing wrong with an imported question.
  String importIssueMessage(ImportIssue issue);

  /// Says a rule cannot fire in this build.
  String get ruleInactiveNotDetectable;

  /// Title of the student exam list.
  String get studentExamsTitle;

  /// No exam is available.
  String get studentExamsEmptyTitle;

  /// Explains the empty list.
  String get studentExamsEmptyBody;

  /// Where the student stands with an exam.
  String attemptStateName(AttemptState state);

  /// When an exam can be started.
  String examWindow(String from, String to);

  /// Title of the student results list.
  String get studentResultsTitle;

  /// No results yet.
  String get studentResultsEmptyTitle;

  /// Explains the empty list.
  String get studentResultsEmptyBody;

  /// Title of the briefing.
  String get briefingTitle;

  /// Heading.
  String get briefingInstructionsHeading;

  /// Heading.
  String get briefingDetailsHeading;

  /// Heading.
  String get briefingRulesHeading;

  /// Heading.
  String get briefingMonitoringHeading;

  /// Duration line.
  String briefingDuration(int minutes);

  /// Questions line.
  String briefingQuestions(int count);

  /// Marks line.
  String briefingTotalMarks(String marks);

  /// Window line.
  String briefingWindowLine(String from, String to);

  /// Calculator line.
  String ruleCalculator(bool allowed);

  /// Navigation line.
  String ruleBackward(bool allowed);

  /// Shuffle line.
  String ruleShuffled(bool questions, bool options);

  /// Autosave line.
  String get ruleAutosave;

  /// What is watched.
  String get monitoringIntro;

  /// Rules that cannot work.
  String get monitoringInactiveHeading;

  /// No active rule.
  String get monitoringNoneActive;

  /// Go to consent.
  String get briefingContinue;

  /// Resume the attempt.
  String get briefingResume;

  /// Open the result.
  String get briefingViewResult;

  /// Window not open.
  String briefingNotOpenYet(String when);

  /// Window closed.
  String get briefingClosed;

  /// Title of the consent screen.
  String get consentTitle;

  /// Intro.
  String get consentIntro;

  /// Consent point.
  String get consentPoint1;

  /// Consent point.
  String get consentPoint2;

  /// Consent point.
  String get consentPoint3;

  /// Consent point.
  String get consentPoint4;

  /// Consent point.
  String get consentPoint5;

  /// Checkbox.
  String get consentAgree;

  /// Continue to the system check.
  String get consentContinue;

  /// Go back without agreeing.
  String get consentDecline;

  /// Title.
  String get systemCheckTitle;

  /// Intro.
  String get systemCheckIntro;

  /// Row title.
  String get cameraCheckTitle;

  /// Camera state.
  String get cameraChecking;

  /// Camera state.
  String get cameraWorking;

  /// Camera state.
  String get cameraNone;

  /// Camera state.
  String get cameraDenied;

  /// Camera state.
  String get cameraError;

  /// Retry the camera.
  String get cameraRetry;

  /// Checkbox.
  String get startWithoutCamera;

  /// Row title.
  String get connectionCheckTitle;

  /// Connection state.
  String get connectionOnline;

  /// Connection state.
  String get connectionOffline;

  /// Row title.
  String get timeCheckTitle;

  /// Time state.
  String timeCheckBody(int minutes, String zone);

  /// Start the exam.
  String get startExam;

  /// Consent missing.
  String get consentNeeded;

  /// Time left.
  String timeRemaining(String time);

  /// Time is almost up.
  String get timeLowWarning;

  /// Which question.
  String questionOf(int number, int total);

  /// Previous.
  String get previousQuestion;

  /// Next.
  String get nextQuestion;

  /// Submit.
  String get submitExam;

  /// Confirm.
  String get submitConfirmTitle;

  /// Confirm text.
  String submitConfirmBody(int unanswered);

  /// Autosave indicator.
  String get savedIndicator;

  /// A save failed.
  String get savingFailed;

  /// Label of the answer box.
  String get answerLabel;

  /// Hint.
  String get chooseOneHint;

  /// Hint.
  String get chooseAllHint;

  /// Hint.
  String get typedAnswerHint;

  /// Shown when copy or paste is blocked.
  String get pasteBlocked;

  /// Open the calculator.
  String get openCalculator;

  /// Open the palette.
  String get questionPalette;

  /// A question in the palette.
  String paletteEntry(int number, bool answered);

  /// A warning was recorded.
  String warningRecorded(String what, int count);

  /// Warning limit reached.
  String get warningLimitReached;

  /// Offline during the exam.
  String get offlineBanner;

  /// Time is up.
  String get timeUpTitle;

  /// Time is up.
  String get timeUpBody;

  /// Submitting.
  String get submitting;

  /// The attempt does not exist.
  String get attemptNotFound;

  /// Calculator title.
  String get calcTitle;

  /// Angle mode.
  String get calcDegrees;

  /// Angle mode.
  String get calcRadians;

  /// Clear.
  String get calcClear;

  /// Backspace.
  String get calcBackspace;

  /// Equals.
  String get calcEquals;

  /// Label of the expression.
  String get calcExpression;

  /// Why a calculation has no value.
  String calcError(CalcError error);

  /// Title of the result screen.
  String get resultTitle;

  /// When submitted.
  String resultSubmittedAt(String when);

  /// Auto-submitted.
  String get resultAutoSubmitted;

  /// The result is not released yet.
  String resultHeldBack(String when);

  /// The marks.
  String resultScore(String awarded, String total);

  /// The percentage.
  String resultPercent(String percent);

  /// Passed.
  String get resultPassed;

  /// Failed.
  String get resultFailed;

  /// No pass mark.
  String get resultNoPassMark;

  /// Marks pending.
  String resultPending(int count);

  /// Heading.
  String get resultAnswersHeading;

  /// How a question turned out.
  String outcomeName(QuestionOutcome outcome);

  /// Marks of a question.
  String questionMarksOf(String awarded, String max);

  /// Explanation heading.
  String get explanationLabelShort;

  /// The result does not show the key.
  String get resultsNoKeyNote;

  /// Title of the attempts list.
  String get attemptsTitle;

  /// Open the attempts of an exam.
  String get attemptsButton;

  /// No attempts.
  String get attemptsEmptyTitle;

  /// Explains.
  String get attemptsEmptyBody;

  /// Status of an attempt.
  String attemptStatusName(AttemptStatus status);

  /// Marks so far.
  String attemptMarks(String awarded, String total);

  /// Typed answers waiting.
  String attemptPending(int count);

  /// Incident count.
  String attemptIncidents(int count);

  /// Title of the attempt review.
  String get attemptReviewTitle;

  /// Label.
  String get studentAnswerLabel;

  /// Nothing answered.
  String get noAnswer;

  /// Label.
  String get correctOptionsLabel;

  /// This option was chosen.
  String get chosenMarker;

  /// This option is correct.
  String get correctMarker;

  /// Label of the marks field.
  String marksOutOf(String max);

  /// Save.
  String get saveMarks;

  /// Confirms.
  String marksSaved(String value);

  /// The marks were limited.
  String marksClamped(String value);

  /// Warning count.
  String warningsLabel(int count);

  /// Title of the incident queue.
  String get incidentsTitle;

  /// No incidents.
  String get incidentsEmptyTitle;

  /// Explains the empty queue.
  String get incidentsEmptyBody;

  /// Filter.
  String get incidentFilterOpen;

  /// Filter.
  String get incidentFilterDecided;

  /// Severity.
  String incidentSeverityName(IncidentSeverity severity);

  /// What detected it.
  String incidentSourceName(DetectionSource source);

  /// A decision.
  String incidentDecisionName(ReviewDecision decision);

  /// No decision yet.
  String get incidentUndecided;

  /// A factual description of an incident.
  String incidentDescription(IncidentCategory category, String? detail, int? seconds);

  /// Title.
  String get incidentDetailTitle;

  /// Student and exam.
  String incidentWhoWhat(String student, String exam);

  /// Label.
  String get incidentSeverityLabel;

  /// Label.
  String get incidentSourceLabel;

  /// Heading.
  String get incidentTimelineHeading;

  /// Marks the open incident in the timeline.
  String get incidentThisOne;

  /// Heading.
  String get incidentEvidenceHeading;

  /// No evidence.
  String get evidenceUnavailableBody;

  /// Evidence exists.
  String evidenceCapturedBody(String reference);

  /// Heading.
  String get incidentDecisionHeading;

  /// Label.
  String get incidentNotesLabel;

  /// Save.
  String get incidentSaveDecision;

  /// Confirms.
  String get incidentDecisionSaved;

  /// Warnings in the attempt.
  String incidentWarningsLine(int count, int limit);

  /// Limit reached.
  String get incidentLimitReached;

  /// An incident is not a verdict.
  String get incidentNotAVerdict;

  /// Heading.
  String get dashboardExamsHeading;

  /// Count of exams in a status.
  String dashboardStatusCount(String status, int count);

  /// Typed answers waiting.
  String dashboardNeedsMarking(int count);

  /// Nothing waiting.
  String get dashboardNothingToMark;

  /// Incidents waiting.
  String dashboardIncidentsWaiting(int count);

  /// Nothing waiting.
  String get dashboardNoIncidentsWaiting;
}
