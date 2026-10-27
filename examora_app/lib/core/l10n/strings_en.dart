import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/l10n/app_strings.dart';
import 'package:examora_app/core/l10n/planned_feature.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/scientific_calculator.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';

/// The English texts.
final class EnglishStrings extends AppStrings {
  /// Creates the English strings.
  const EnglishStrings();

  @override
  String get languageCode => 'en';

  @override
  String get appName => 'Examora';

  @override
  String get retry => 'Try again';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get signOut => 'Sign out';

  @override
  String get loading => 'Loading…';

  @override
  String get errorTitle => 'This did not load';

  @override
  String get missingEndpointLabel => 'Server endpoint needed';

  @override
  String get languageLabel => 'Language';

  @override
  String get restoringSession => 'Restoring your session…';

  @override
  String get homeTab => 'Home';

  @override
  String get examsTab => 'Exams';

  @override
  String get resultsTab => 'Results';

  @override
  String get incidentsTab => 'Incidents';

  @override
  String get profileTab => 'Profile';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle => 'Sign in with the account your administrator gave you.';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signInButton => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get forgotPasswordLink => 'Forgot your password?';

  @override
  String get accountsCreatedByAdmin => 'Accounts are created by your administrator.';

  @override
  String get forgotPasswordTitle => 'Forgot your password?';

  @override
  String get forgotPasswordBody =>
      'There is no automatic password reset. Ask your administrator to issue a new temporary password. '
      'You will be asked to choose your own password the first time you sign in with it.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changePasswordForcedTitle => 'Choose a new password';

  @override
  String get changePasswordForcedBody =>
      'You signed in with a temporary password. You must choose your own password before you can use Examora.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Repeat the new password';

  @override
  String get passwordPolicyHint => 'At least 8 characters, with an uppercase letter, a lowercase letter and a digit.';

  @override
  String get changePasswordButton => 'Change password';

  @override
  String get passwordChanged => 'Your password was changed.';

  @override
  String get signOutInstead => 'Sign out instead';

  @override
  String welcomeUser(String name) => 'Welcome, $name';

  @override
  String roleName(UserRole role) => switch (role) {
    UserRole.student => 'Student',
    UserRole.instructor => 'Instructor',
    UserRole.administrator => 'Administrator',
  };

  @override
  String get notBuiltTitle => 'Not built yet';

  @override
  String notBuiltBody(String feature) => '$feature has not been built yet. Nothing on this screen is real data.';

  @override
  String featureName(PlannedFeature feature) => switch (feature) {
    PlannedFeature.studentExams => 'The exam list',
    PlannedFeature.studentResults => 'Results',
    PlannedFeature.examBriefing => 'The exam briefing',
    PlannedFeature.examConsent => 'The consent screen',
    PlannedFeature.systemCheck => 'The system check',
    PlannedFeature.examPlayer => 'The exam player',
    PlannedFeature.attemptResult => 'The attempt result',
    PlannedFeature.instructorExams => 'The exam list',
    PlannedFeature.incidentQueue => 'The incident queue',
    PlannedFeature.incidentDetail => 'The incident review',
    PlannedFeature.examAttempts => 'The attempts list',
  };

  @override
  String get profileTitle => 'Profile';

  @override
  String get identitySection => 'Your account';

  @override
  String get fullNameLabel => 'Name';

  @override
  String get roleLabel => 'Role';

  @override
  String get dataLocationSection => 'Where your data lives';

  @override
  String get dataLocationBody =>
      'Everything Examora stores - accounts, exams, answers and records - is kept on this device. '
      'Nothing is sent to a server.';

  @override
  String get privacySection => 'What is collected during an exam';

  @override
  String get privacyBody =>
      'During an exam the app notes when you leave it, try to copy or paste in an answer, take a screenshot (where the '
      'device reports it), or lose your network connection, and whether you started without a camera. Each note is '
      'stored on this device with its time, and the exam\'s instructor can read it. The camera is used only for a check '
      'before the exam: no video or audio is recorded, stored or sent. This version has no face, gaze or speech '
      'detection. Your answers and marks are stored on this device. Warnings never change a mark.';

  @override
  String get languageSection => 'Language';

  @override
  String get validationGeneric => 'Some fields are invalid.';

  @override
  String get conflictGeneric => 'This action conflicts with the current state.';

  @override
  String get failureInvalidCredentials => 'Incorrect email or password.';

  @override
  String get failureAccountLocked =>
      'This account is temporarily locked after too many failed attempts. Try again later.';

  @override
  String get failureAccountDeactivated => 'This account has been deactivated. Contact your administrator.';

  @override
  String get failureTemporaryPasswordExpired =>
      'The temporary password has expired. Ask an administrator for a new one.';

  @override
  String get failureSessionExpired => 'Your session has ended. Please sign in again.';

  @override
  String get failurePasswordChangeRequired => 'You must change your password before continuing.';

  @override
  String get failureForbidden => 'You do not have permission to do this.';

  @override
  String get failureNotFound => 'The requested item was not found.';

  @override
  String get failureNetwork => 'Cannot reach the server. Check your connection and try again.';

  @override
  String get failureTimeout => 'The server took too long to respond. Try again.';

  @override
  String get failureRateLimited => 'Too many attempts. Please wait a minute and try again.';

  @override
  String get failureServer => 'The server had a problem. Please try again later.';

  @override
  String get failureStorage => 'Could not read or write data on this device.';

  @override
  String failureParse(String field) => 'The data could not be read ($field).';

  @override
  String failureEndpointMissing(String endpoint) =>
      'This has not been built yet: the server endpoint $endpoint does not exist.';

  @override
  String failureUnavailable(String capability, String? because) =>
      because == null ? '$capability is not available.' : '$capability is not available: $because';

  @override
  String get fieldRequired => 'This field is required.';

  @override
  String get fieldInvalidEmail => 'Enter a valid email address.';

  @override
  String get fieldPasswordPolicy =>
      'The password must have at least 8 characters, an uppercase letter, a lowercase letter and a digit.';

  @override
  String get fieldPasswordsDiffer => 'The passwords do not match.';

  @override
  String get fieldCurrentPasswordIncorrect => 'The current password is incorrect.';

  @override
  String get fieldNewPasswordSame => 'The new password must be different from the current one.';

  @override
  String get fieldTooLong => 'This text is too long.';

  @override
  String get adminAccountsTitle => 'Accounts';

  @override
  String get adminAddAccount => 'Add account';

  @override
  String get filterRole => 'Role';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterAll => 'All';

  @override
  String accountStatusName(AccountStatus status) => status == AccountStatus.active ? 'Active' : 'Deactivated';

  @override
  String get accountsEmptyTitle => 'No accounts yet';

  @override
  String get accountsEmptyFiltered => 'No account matches these filters.';

  @override
  String accountsShowing(int shown, int total) => 'Showing $shown of $total';

  @override
  String get previousPage => 'Previous';

  @override
  String get nextPage => 'Next';

  @override
  String pageNumber(int page) => 'Page $page';

  @override
  String get lockedBadge => 'Locked';

  @override
  String get mustChangePasswordBadge => 'Must change password';

  @override
  String get accountDetailTitle => 'Account';

  @override
  String get accountStatusLabel => 'Account status';

  @override
  String get createdAtLabel => 'Created';

  @override
  String get lastLoginLabel => 'Last sign-in';

  @override
  String get neverSignedIn => 'Never';

  @override
  String get statusChangedLabel => 'Status changed';

  @override
  String get statusReasonLabel => 'Reason';

  @override
  String get temporaryPasswordExpiresLabel => 'Temporary password expires';

  @override
  String get passwordLockedLabel => 'Sign-in lock';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String timeZoneNote(String zone) => "Times are shown in this device's time zone: $zone.";

  @override
  String get issueTemporaryPassword => 'Issue temporary password';

  @override
  String get issuePasswordTitle => 'Issue a temporary password?';

  @override
  String issuePasswordBody(String name) =>
      "${isolate(name)}'s current password will stop working, any active sign-ins end, and they must choose a new password at their next sign-in.";

  @override
  String get deactivateAccount => 'Deactivate account';

  @override
  String get deactivateTitle => 'Deactivate this account?';

  @override
  String deactivateBody(String name) =>
      '${isolate(name)} will not be able to sign in until the account is reactivated. A reason is required.';

  @override
  String get reasonRequiredLabel => 'Reason (required)';

  @override
  String get reasonOptionalLabel => 'Reason (optional)';

  @override
  String get reactivateAccount => 'Reactivate account';

  @override
  String get reactivateTitle => 'Reactivate this account?';

  @override
  String reactivateBody(String name) => '${isolate(name)} will be able to sign in again.';

  @override
  String get accountDeactivatedNotice => 'Account deactivated.';

  @override
  String get accountReactivatedNotice => 'Account reactivated.';

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get accountTypeLabel => 'Account type';

  @override
  String get createAccountHint =>
      'A temporary password is created and shown once. The person must change it the first time they sign in.';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get temporaryPasswordTitle => 'Temporary password';

  @override
  String get temporaryPasswordOnce =>
      'This password is shown only once. It cannot be shown again, so copy it or send it now.';

  @override
  String temporaryPasswordFor(String name, String email) => 'For ${isolate(name)} (${isolate(email)})';

  @override
  String temporaryPasswordExpires(String when) => 'Works until $when. They must change it at their first sign-in.';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get passwordCopied => 'Password copied.';

  @override
  String get sendByEmail => 'Send by email';

  @override
  String get emailNotAvailable => 'No email app could be opened on this device. Copy the password instead.';

  @override
  String get temporaryPasswordEmailSubject => 'Your Examora temporary password';

  @override
  String temporaryPasswordEmailBody(String name, String email, String password, String when) =>
      'Hello $name,\n\nAn Examora account was created for you.\nEmail: $email\nTemporary password: $password\n\nIt works until $when. You will be asked to choose a new password the first time you sign in.';

  @override
  String get iHaveSavedIt => 'I have saved it';

  @override
  String get conflictDuplicateAccount => 'An account with this email already exists.';

  @override
  String get conflictAlreadyActive => 'The account is already active.';

  @override
  String get conflictAlreadyDeactivated => 'The account is already deactivated.';

  @override
  String get fieldInvalidCharacters => 'This contains characters that are not allowed.';

  @override
  String get fieldOutOfRange => 'This number is outside the allowed range.';

  @override
  String get fieldWindowTooShort => 'The window must be at least as long as the exam duration.';

  @override
  String get failureExamNotPublishable => 'The exam cannot be published yet.';

  @override
  String get conflictExamNotEditable => 'This exam can no longer be changed in its current state.';

  @override
  String get conflictExamAlreadyPublished => 'This exam is already published.';

  @override
  String get conflictExamArchived => 'This exam was archived and cannot be published.';

  @override
  String get conflictExamNotUnpublishable =>
      'Only a published exam that has not opened and has no attempts can go back to draft.';

  @override
  String get conflictExamNotArchivable => 'Only a published exam can be archived.';

  @override
  String get conflictExamNotDeletable => 'Only a draft can be deleted.';

  @override
  String get conflictQuestionExists => 'This question is already in the exam.';

  @override
  String questionProblemMessage(QuestionProblem problem) => switch (problem) {
    QuestionProblem.noText => 'The question has no text.',
    QuestionProblem.textTooLong => 'The question text is longer than ${ExamLimits.questionTextMax} characters.',
    QuestionProblem.invalidMarks => 'Marks must be above 0 and at most 9999.99, with at most two decimals.',
    QuestionProblem.tooFewOptions => 'A choice question needs at least ${ExamLimits.optionsMin} options.',
    QuestionProblem.tooManyOptions => 'A choice question can have at most ${ExamLimits.optionsMax} options.',
    QuestionProblem.optionEmpty => 'An option has no text.',
    QuestionProblem.optionTooLong => 'An option is longer than ${ExamLimits.optionTextMax} characters.',
    QuestionProblem.noCorrectAnswer => 'No option is marked as correct.',
    QuestionProblem.severalCorrectForSingle => 'A single-choice question must have exactly one correct option.',
    QuestionProblem.duplicateOptionTexts => 'Two options have the same text.',
    QuestionProblem.optionsOnShortText => 'A short-text question cannot have options.',
    QuestionProblem.modelAnswerTooLong => 'The model answer is longer than ${ExamLimits.modelAnswerMax} characters.',
    QuestionProblem.flaggedForReview => 'The question is flagged for review. Open it, check it and save it.',
    QuestionProblem.answerKeyStale =>
      'The options changed after the correct answer was set. Open the question and confirm the correct answer.',
  };

  @override
  String publishProblemMessage(PublishProblem problem) => switch (problem) {
    DetailsIncompleteProblem() =>
      'The exam details or settings are incomplete or out of range. Go back to the details and settings steps.',
    NoQuestionsProblem() => 'The exam has no questions.',
    QuestionPublishProblem(:final position, :final problem) => 'Question $position: ${questionProblemMessage(problem)}',
    ScheduleMissingProblem() => 'No availability window is set. Choose when the exam opens and closes.',
    WindowTooShortProblem() => 'The availability window is shorter than the exam duration.',
    StartTimePassedProblem() => 'The start time has already passed. Choose a later start.',
  };

  @override
  String examStatusName(ExamStatus status) => switch (status) {
    ExamStatus.draft => 'Draft',
    ExamStatus.scheduled => 'Scheduled',
    ExamStatus.ongoing => 'Ongoing',
    ExamStatus.completed => 'Completed',
    ExamStatus.archived => 'Archived',
  };

  @override
  String questionTypeName(QuestionType type) => switch (type) {
    QuestionType.singleChoice => 'Single choice',
    QuestionType.multipleChoice => 'Multiple choice',
    QuestionType.shortText => 'Short text',
  };

  @override
  String questionTypeHint(QuestionType type) => switch (type) {
    QuestionType.singleChoice => 'The student picks one option. Marked automatically.',
    QuestionType.multipleChoice => 'The student picks any number of options. Marked automatically, all or nothing: full marks only for exactly the correct options.',
    QuestionType.shortText => 'The student types an answer. The app never marks it: you mark it yourself.',
  };

  @override
  String get examsTitle => 'Exams';

  @override
  String get createExamButton => 'Create exam';

  @override
  String get examsEmptyTitle => 'No exams yet';

  @override
  String get examsEmptyBody => 'Create your first exam to get started.';

  @override
  String get examsEmptyFiltered => 'No exam has this status.';

  @override
  String examsShowing(int shown, int total) => 'Showing $shown of $total';

  @override
  String examSummary(String course, int minutes, int questions) =>
      '${isolate(course)} · $minutes min · $questions ${questions == 1 ? 'question' : 'questions'}';

  @override
  String get examMethodTitle => 'How do you want to create the exam?';

  @override
  String get examMethodManual => 'Create manually';

  @override
  String get examMethodManualBody => 'Write the questions yourself, one at a time.';

  @override
  String get examMethodWord => 'Import from Word';

  @override
  String get examMethodWordBody =>
      'Read the questions from a .docx file written in the Examora template. You review everything before it is added.';

  @override
  String get examMethodDetailsFirst =>
      'Both ways start with the exam details, so the exam has a title before anything is saved.';

  @override
  String get wizardNewTitle => 'New exam';

  @override
  String get wizardEditTitle => 'Edit exam';

  @override
  String wizardStepOf(int step, int total, String name) => 'Step $step of $total · $name';

  @override
  String get stepDetails => 'Details';

  @override
  String get stepQuestions => 'Questions';

  @override
  String get stepSettings => 'Settings';

  @override
  String get stepSchedule => 'Schedule';

  @override
  String get stepReview => 'Review and publish';

  @override
  String get nextStep => 'Next';

  @override
  String get previousStep => 'Back';

  @override
  String get saveAndContinue => 'Save and continue';

  @override
  String get savedNotice => 'Saved on this device.';

  @override
  String get examTitleLabel => 'Exam title';

  @override
  String get examCourseLabel => 'Course name';

  @override
  String get examDescriptionLabel => 'Description (optional)';

  @override
  String get examInstructionsLabel => 'Instructions for students (optional)';

  @override
  String get examDurationLabel => 'Duration (minutes)';

  @override
  String get examPassMarkLabel => 'Pass mark (% of the total marks)';

  @override
  String examVersionLabel(int version) => 'Version $version';

  @override
  String get examVersionHelp =>
      'The version goes up when something students see or are graded on changes after publishing.';

  @override
  String questionsSummary(int count, String marks) =>
      '$count ${count == 1 ? 'question' : 'questions'} · $marks ${marks == '1' ? 'mark' : 'marks'} in total';

  @override
  String get addQuestion => 'Add question';

  @override
  String get questionsEmpty => 'No questions yet. Add one, or import them from Word.';

  @override
  String questionNumber(int number) => 'Question $number';

  @override
  String marksValue(String marks) => marks == '1' ? '1 mark' : '$marks marks';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get editQuestion => 'Edit';

  @override
  String get deleteQuestion => 'Delete';

  @override
  String get deleteQuestionTitle => 'Delete this question?';

  @override
  String get deleteQuestionBody => 'It will be removed from the exam.';

  @override
  String get needsReviewBadge => 'Needs review';

  @override
  String get answerKeyStaleBadge => 'Confirm the answer';

  @override
  String get wordBadge => 'WORD';

  @override
  String get newQuestionTitle => 'New question';

  @override
  String get editQuestionTitle => 'Edit question';

  @override
  String get questionTypeLabel => 'Question type';

  @override
  String get questionTextLabel => 'Question';

  @override
  String get marksFieldLabel => 'Marks';

  @override
  String optionLabel(int number) => 'Option $number';

  @override
  String get addOption => 'Add option';

  @override
  String get removeOption => 'Remove option';

  @override
  String get markCorrect => 'Correct answer';

  @override
  String get modelAnswerLabel => 'Model answer (for whoever marks it, optional)';

  @override
  String get explanationLabel => 'Explanation shown with the result (optional)';

  @override
  String get confirmAnswerKey => 'I have checked which option(s) are correct';

  @override
  String get saveQuestion => 'Save question';

  @override
  String get questionSavedNotice => 'Question saved.';

  @override
  String get settingRandomizeQuestions => 'Shuffle the order of questions';

  @override
  String get settingRandomizeOptions => 'Shuffle the order of options';

  @override
  String get settingCalculator => 'Allow the scientific calculator';

  @override
  String get settingBackward => 'Let students go back to earlier questions';

  @override
  String get settingShowResult => 'Show the result as soon as the exam is submitted';

  @override
  String get settingShowExplanations => 'Show explanations with the result';

  @override
  String get proctoringRulesHeading => 'Proctoring rules';

  @override
  String incidentCategoryName(IncidentCategory category) => switch (category) {
    IncidentCategory.appBackgrounded => 'App left the foreground',
    IncidentCategory.windowFocusLost => 'Window lost focus',
    IncidentCategory.deviceInterrupted => 'Device interrupted',
    IncidentCategory.clipboardAttempt => 'Copy or paste attempt',
    IncidentCategory.screenshotDetected => 'Screenshot or recording',
    IncidentCategory.cameraUnavailable => 'Camera unavailable',
    IncidentCategory.microphoneUnavailable => 'Microphone unavailable',
    IncidentCategory.networkLost => 'Network lost',
    IncidentCategory.gazeAway => 'Looking away',
    IncidentCategory.faceAbsent => 'Face absent',
    IncidentCategory.multipleFaces => 'Several faces',
    IncidentCategory.speechDetected => 'Speech heard',
  };

  @override
  String get ruleInactiveNoDetector =>
      'Inactive: this build has no face, gaze or speech detector, so this rule cannot fire.';

  @override
  String get ruleImmediateHint => 'Fires immediately';

  @override
  String get ruleSustainedHint => 'Fires after the threshold';

  @override
  String get settingThreshold => 'Sustained-behaviour threshold (seconds)';

  @override
  String get settingThresholdHelp =>
      'A behaviour must last this long before it counts as an incident. Short glances never add up.';

  @override
  String get settingBuffer => 'Evidence buffer (seconds)';

  @override
  String get settingBufferHelp =>
      'Seconds of video you would like kept before an incident. This build cannot record video retroactively, so evidence will be reported as unavailable.';

  @override
  String get settingMaxWarnings => 'Warnings before the attempt is flagged';

  @override
  String get settingMaxWarningsHelp =>
      'When a student reaches this many warnings, the attempt is flagged for your review. The exam is not ended and marks never change.';

  @override
  String get scheduleOpensLabel => 'Opens';

  @override
  String get scheduleClosesLabel => 'Closes';

  @override
  String get scheduleNotSet => 'Not set';

  @override
  String get scheduleChoose => 'Choose date and time';

  @override
  String get scheduleHelp =>
      'Students can start between these times. Each attempt lasts the exam duration, but never goes past the closing time.';

  @override
  String get reviewReady => 'Ready to publish';

  @override
  String reviewBlocked(int count) =>
      count == 1 ? '1 thing to fix before publishing' : '$count things to fix before publishing';

  @override
  String get publishExam => 'Publish exam';

  @override
  String get publishedNotice => 'The exam is published.';

  @override
  String get publishConfirmTitle => 'Publish this exam?';

  @override
  String get publishConfirmBody => 'Students will see it from its opening time. You can still edit it until it opens.';

  @override
  String get unpublishExam => 'Return to draft';

  @override
  String get archiveExam => 'Archive exam';

  @override
  String get archiveConfirmTitle => 'Archive this exam?';

  @override
  String get archiveConfirmBody => 'An archived exam is withdrawn for good.';

  @override
  String get deleteDraft => 'Delete draft';

  @override
  String get deleteDraftTitle => 'Delete this draft?';

  @override
  String get deleteDraftBody => 'The draft and its questions will be deleted for good.';

  @override
  String get examNotEditableNotice => 'This exam can no longer be edited because it has opened or was archived.';

  @override
  String get examDetailOpen => 'Open';

  @override
  String documentRejectionMessage(DocumentRejection reason) => switch (reason) {
    DocumentRejection.notDocx => 'Only Word documents saved as .docx can be imported.',
    DocumentRejection.oldDoc => 'This is an older Word file (.doc). Open it in Word, choose Save As > Word Document (.docx), then pick the new file.',
    DocumentRejection.pdf => 'This is a PDF, even if its name ends in .docx. Export or copy the questions into a Word document and save it as .docx.',
    DocumentRejection.notAZip => 'This file is not a Word document: a .docx is a zip package and this one is not.',
    DocumentRejection.notWord =>
      'This package is not a Word document (it has no document part). It may be an Excel or PowerPoint file.',
    DocumentRejection.tooLarge => 'The file is larger than 10 MB, the limit for an import.',
    DocumentRejection.tooComplex => 'This document is too complex to read safely.',
    DocumentRejection.unreadable => 'The file is damaged and cannot be read as a Word document.',
    DocumentRejection.empty => 'The document has no text in it.',
  };

  @override
  String get importTitle => 'Import from Word';

  @override
  String get importIntro =>
      'Choose a .docx file written in the Examora template. Nothing is added to the exam until you have reviewed every question.';

  @override
  String get importChooseFile => 'Choose a .docx file';

  @override
  String get importChooseAnother => 'Choose another file';

  @override
  String get importTemplateHelp => 'Template and rules';

  @override
  String get importTemplateTitle => 'The Examora question template';

  @override
  String get importTemplateRules =>
      'Each question starts with "Question 1 [MCQ]". Use [MCQ] for one correct option, [Multiple] for several, [Short] for a typed answer. Options are "A.", "B.", ... and the answer is "Correct Answer: B" (or "A, C"). "Marks:" is required: the importer never picks a mark for you. "Difficulty:" and "Topic:" are optional. A tracked deletion in Word is ignored. Tables, pictures and equations cannot be imported and are listed.';

  @override
  String get importTemplateCopy => 'Copy template text';

  @override
  String get importTemplateCopied => 'Template text copied.';

  @override
  String get importTemplateSave => 'Save template (.docx)';

  @override
  String get importTemplateSaved => 'Template saved.';

  @override
  String get importTemplateSaveFailed => 'The template could not be saved here. Copy its text instead.';

  @override
  String importReading(String name) => 'Reading $name…';

  @override
  String importFileLabel(String name) => 'File: $name';

  @override
  String importSummary(int found, int ready, int attention, int notImported) =>
      '$found found · $ready ready · $attention need attention · $notImported not imported';

  @override
  String get importOnlyAttention => 'Only questions needing attention';

  @override
  String get importNothingToShow => 'No question needs attention.';

  @override
  String get importNoQuestionsFound => 'No questions were found in this document. Check that it follows the template.';

  @override
  String importStatusName(ImportStatus status) => switch (status) {
    ImportStatus.ready => 'Ready',
    ImportStatus.needsAttention => 'Needs attention',
    ImportStatus.notImported => 'Not imported',
  };

  @override
  String importQuestionHeading(int number, int line) => 'Question $number · line $line';

  @override
  String get importAsWritten => 'As written in the document';

  @override
  String importLine(int line, String text) => '$line: $text';

  @override
  String get importDontImport => 'Do not import';

  @override
  String get importDoImport => 'Import this question';

  @override
  String get importAcknowledge => 'I checked this question';

  @override
  String get importAcknowledged => 'Checked';

  @override
  String get importNoProblems => 'No problems found.';

  @override
  String get importReadOnlyNote => 'Read from the file. Only a label for you: never used to mark.';

  @override
  String get topicLabel => 'Topic';

  @override
  String get difficultyLabel => 'Difficulty';

  @override
  String get importUnattachedTitle => 'Text that belongs to no question';

  @override
  String get importUnattachedBody =>
      'These lines were read but not imported. If one of them is part of a question, fix it in the document and import again.';

  @override
  String importIgnoredNote(int count) =>
      '$count lines (the document title and section headings) were read and are not used.';

  @override
  String get importSkippedTitle => 'Content that could not be imported';

  @override
  String importSkippedKindName(SkippedKind kind) => switch (kind) {
    SkippedKind.image => 'A picture or drawing',
    SkippedKind.table => 'A table',
    SkippedKind.equation => 'An equation',
  };

  @override
  String importSkippedItem(String kindName, int afterLine) => '$kindName after line $afterLine';

  @override
  String importContinue(int count) => 'Add to the exam ($count)';

  @override
  String get importContinueNone => 'Keep at least one question to continue.';

  @override
  String get importContinueBlocked =>
      'Fix the questions that cannot be added yet (marked below), or choose not to import them.';

  @override
  String importAdded(int count) => count == 1 ? '1 question added.' : '$count questions added.';

  @override
  String importIssueMessage(ImportIssue issue) => switch (issue.code) {
    ImportIssueCode.typeInferred =>
      'The document does not say what kind of question this is, so it was guessed from its shape. Check the type.',
    ImportIssueCode.unknownTypeTag =>
      'The type ${issue.detail} is not one the importer knows. Use MCQ, Multiple or Short.',
    ImportIssueCode.strayText => 'This line did not fit the question and was not imported: ${issue.detail}',
    ImportIssueCode.unknownAnswerLabel => 'The correct answer "${issue.detail}" does not match any option.',
    ImportIssueCode.severalAnswersForSingle => 'Several options are marked correct but the type is single choice. Keep one, or change the type to multiple choice.',
    ImportIssueCode.conflictingAnswerLines =>
      'The document names the correct answer more than once and the lines disagree.',
    ImportIssueCode.answerTreatedAsModel =>
      'A "Correct Answer" line on a question without options was kept as the model answer.',
    ImportIssueCode.duplicateOptionLabel => 'Option ${issue.detail} appears more than once.',
    ImportIssueCode.duplicateQuestionNumber =>
      'Question number ${issue.detail} appears more than once in the document.',
    ImportIssueCode.missingMarks =>
      'There is no "Marks:" line. Enter the marks yourself: the importer never chooses a number for you.',
    ImportIssueCode.marksUnreadable => 'The marks ${issue.detail} could not be read as a number. Enter them yourself.',
  };

  @override
  String get ruleInactiveNotDetectable => 'Inactive: this build has no way to notice this, so this rule cannot fire.';

  @override
  String get studentExamsTitle => 'My exams';

  @override
  String get studentExamsEmptyTitle => 'No exams are available yet';

  @override
  String get studentExamsEmptyBody => 'When an instructor publishes an exam, it appears here.';

  @override
  String attemptStateName(AttemptState state) => switch (state) {
    AttemptState.notStarted => 'Not started',
    AttemptState.inProgress => 'In progress',
    AttemptState.submitted => 'Submitted',
  };

  @override
  String examWindow(String from, String to) => 'Open from $from to $to';

  @override
  String get studentResultsTitle => 'My results';

  @override
  String get studentResultsEmptyTitle => 'No results yet';

  @override
  String get studentResultsEmptyBody => 'Results appear here after you submit an exam.';

  @override
  String get briefingTitle => 'Exam briefing';

  @override
  String get briefingInstructionsHeading => 'Instructions';

  @override
  String get briefingDetailsHeading => 'The exam';

  @override
  String get briefingRulesHeading => 'How it works';

  @override
  String get briefingMonitoringHeading => 'What is watched';

  @override
  String briefingDuration(int minutes) => 'Time allowed: $minutes minutes';

  @override
  String briefingQuestions(int count) => 'Questions: $count';

  @override
  String briefingTotalMarks(String marks) => 'Total marks: $marks';

  @override
  String briefingWindowLine(String from, String to) => 'Open from $from to $to';

  @override
  String ruleCalculator(bool allowed) =>
      (allowed ? 'A scientific calculator is available.' : 'No calculator is available.');

  @override
  String ruleBackward(bool allowed) =>
      (allowed ? 'You can go back to earlier questions.' : 'You cannot go back to earlier questions.');

  @override
  String ruleShuffled(bool questions, bool options) => (questions && options
      ? 'Questions and answer options are in a random order.'
      : questions
      ? 'Questions are in a random order.'
      : options
      ? 'Answer options are in a random order.'
      : 'Questions and options are in the same order for everyone.');

  @override
  String get ruleAutosave =>
      'Every answer is saved the moment you give it. If you leave and come back, your answers are still there, but the clock keeps running.';

  @override
  String get monitoringIntro => 'While the exam is open, these are recorded as incidents:';

  @override
  String get monitoringInactiveHeading => 'Listed by the instructor but NOT active in this app:';

  @override
  String get monitoringNoneActive => 'Nothing is being watched in this exam.';

  @override
  String get briefingContinue => 'Continue';

  @override
  String get briefingResume => 'Resume the exam';

  @override
  String get briefingViewResult => 'View my result';

  @override
  String briefingNotOpenYet(String when) => 'This exam opens on $when.';

  @override
  String get briefingClosed => 'This exam is closed. You can no longer start it.';

  @override
  String get consentTitle => 'Before you begin';

  @override
  String get consentIntro => 'Please read how this exam is supervised.';

  @override
  String get consentPoint1 =>
      'While the exam is open, the app notes when you leave it, try to copy or paste in an answer box, take a screenshot (where the device tells the app), or lose your network connection.';

  @override
  String get consentPoint2 =>
      'Each of these is saved as an incident with the time it happened. The instructor of this exam can read them. You cannot read or change them.';

  @override
  String get consentPoint3 =>
      'The camera is used only for a check before the exam starts. This app does not record, store or send any video or audio.';

  @override
  String get consentPoint4 =>
      'This version has no face, gaze or speech detection. Nobody and nothing watches you through the camera.';

  @override
  String get consentPoint5 =>
      'Warnings never change your marks. An instructor may look at the incidents and decide for themselves.';

  @override
  String get consentAgree => 'I have read this and I agree';

  @override
  String get consentContinue => 'Continue to the system check';

  @override
  String get consentDecline => 'Go back';

  @override
  String get systemCheckTitle => 'System check';

  @override
  String get systemCheckIntro =>
      'Check that everything works before the clock starts. The clock starts when you press Start the exam.';

  @override
  String get cameraCheckTitle => 'Camera';

  @override
  String get cameraChecking => 'Checking the camera…';

  @override
  String get cameraWorking => 'The camera works. This preview is not recorded.';

  @override
  String get cameraNone => 'No camera was found on this device.';

  @override
  String get cameraDenied => 'Camera permission was not given.';

  @override
  String get cameraError => 'The camera could not be started.';

  @override
  String get cameraRetry => 'Check the camera again';

  @override
  String get startWithoutCamera => 'I will start without a camera. This is recorded as an incident.';

  @override
  String get connectionCheckTitle => 'Connection';

  @override
  String get connectionOnline => 'Online. The exam also works without a connection.';

  @override
  String get connectionOffline => 'Offline. You can still take the exam: answers are saved on this device.';

  @override
  String get timeCheckTitle => 'Time';

  @override
  String timeCheckBody(int minutes, String zone) =>
      "You will have $minutes minutes. Times are shown in this device's time zone: $zone.";

  @override
  String get startExam => 'Start the exam';

  @override
  String get consentNeeded => 'You have not agreed to the notice yet.';

  @override
  String timeRemaining(String time) => 'Time left: $time';

  @override
  String get timeLowWarning => 'Less than five minutes left.';

  @override
  String questionOf(int number, int total) => 'Question $number of $total';

  @override
  String get previousQuestion => 'Previous';

  @override
  String get nextQuestion => 'Next';

  @override
  String get submitExam => 'Submit the exam';

  @override
  String get submitConfirmTitle => 'Submit the exam?';

  @override
  String submitConfirmBody(int unanswered) => (unanswered == 0
      ? 'You answered every question. After you submit you cannot change anything.'
      : unanswered == 1
      ? '1 question has no answer. After you submit you cannot change anything.'
      : '$unanswered questions have no answer. After you submit you cannot change anything.');

  @override
  String get savedIndicator => 'Saved';

  @override
  String get savingFailed => 'This answer could not be saved. Try again.';

  @override
  String get answerLabel => 'Your answer';

  @override
  String get chooseOneHint => 'Choose one answer.';

  @override
  String get chooseAllHint => 'Choose every correct answer. Full marks only if you choose exactly the correct ones.';

  @override
  String get typedAnswerHint => 'Type your answer. Your instructor marks it.';

  @override
  String get pasteBlocked => 'Copying and pasting are not allowed in answers. This was recorded.';

  @override
  String get openCalculator => 'Calculator';

  @override
  String get questionPalette => 'All questions';

  @override
  String paletteEntry(int number, bool answered) => "Question $number${answered ? ', answered' : ', not answered'}";

  @override
  String warningRecorded(String what, int count) => 'Warning recorded: $what (warning $count)';

  @override
  String get warningLimitReached =>
      'You reached the warning limit. The exam goes on and your marks are not changed, but the instructor will review this attempt.';

  @override
  String get offlineBanner => 'You are offline. Keep going: your answers are saved on this device.';

  @override
  String get timeUpTitle => 'Time is up';

  @override
  String get timeUpBody => 'Your saved answers were submitted.';

  @override
  String get submitting => 'Submitting…';

  @override
  String get attemptNotFound => 'This attempt was not found.';

  @override
  String get calcTitle => 'Scientific calculator';

  @override
  String get calcDegrees => 'Degrees';

  @override
  String get calcRadians => 'Radians';

  @override
  String get calcClear => 'Clear';

  @override
  String get calcBackspace => 'Delete last';

  @override
  String get calcEquals => 'Calculate';

  @override
  String get calcExpression => 'Expression';

  @override
  String calcError(CalcError error) => switch (error) {
    CalcError.empty => 'Type something to calculate.',
    CalcError.syntax => 'Syntax error: check the brackets, operators and function names.',
    CalcError.divisionByZero => 'Cannot divide by zero.',
    CalcError.domain =>
      'Not defined for this number (for example the square root of a negative, ln of 0, or tan of 90°).',
    CalcError.overflow => 'The answer is too large.',
    CalcError.tooLong => 'The expression is too long.',
    CalcError.tooDeep => 'Too many brackets inside brackets.',
  };

  @override
  String get resultTitle => 'Result';

  @override
  String resultSubmittedAt(String when) => 'Submitted $when';

  @override
  String get resultAutoSubmitted => 'Submitted automatically when time ran out.';

  @override
  String resultHeldBack(String when) =>
      'Your exam was submitted. The result will be shown after the exam window closes ($when).';

  @override
  String resultScore(String awarded, String total) => '$awarded out of $total marks';

  @override
  String resultPercent(String percent) => '$percent%';

  @override
  String get resultPassed => 'Passed';

  @override
  String get resultFailed => 'Not passed';

  @override
  String get resultNoPassMark => 'This exam has no pass mark.';

  @override
  String resultPending(int count) =>
      "${count == 1 ? '1 written answer is waiting to be marked' : '$count written answers are waiting to be marked'}. The marks above do not include them yet, and it is not decided whether you passed.";

  @override
  String get resultAnswersHeading => 'Your answers';

  @override
  String outcomeName(QuestionOutcome outcome) => switch (outcome) {
    QuestionOutcome.correct => 'Correct',
    QuestionOutcome.incorrect => 'Incorrect',
    QuestionOutcome.unanswered => 'Not answered',
    QuestionOutcome.pendingManual => 'Waiting to be marked',
    QuestionOutcome.markedManually => 'Marked by your instructor',
  };

  @override
  String questionMarksOf(String awarded, String max) => '$awarded / $max';

  @override
  String get explanationLabelShort => 'Explanation';

  @override
  String get resultsNoKeyNote => 'Correct answers are not shown here.';

  @override
  String get attemptsTitle => 'Attempts';

  @override
  String get attemptsButton => 'View attempts';

  @override
  String get attemptsEmptyTitle => 'No attempts yet';

  @override
  String get attemptsEmptyBody => 'Attempts appear here once students start the exam.';

  @override
  String attemptStatusName(AttemptStatus status) => switch (status) {
    AttemptStatus.inProgress => 'In progress',
    AttemptStatus.submitted => 'Submitted',
  };

  @override
  String attemptMarks(String awarded, String total) => 'Marks so far: $awarded of $total';

  @override
  String attemptPending(int count) => '$count to mark';

  @override
  String attemptIncidents(int count) => (count == 1 ? '1 incident' : '$count incidents');

  @override
  String get attemptReviewTitle => 'Attempt';

  @override
  String get studentAnswerLabel => "Student's answer";

  @override
  String get noAnswer => '(no answer)';

  @override
  String get correctOptionsLabel => 'Correct option(s)';

  @override
  String get chosenMarker => 'chosen';

  @override
  String get correctMarker => 'correct';

  @override
  String marksOutOf(String max) => 'Marks (0 to $max)';

  @override
  String get saveMarks => 'Save marks';

  @override
  String marksSaved(String value) => 'Marks saved: $value';

  @override
  String marksClamped(String value) => 'Limited to what the question offers: $value';

  @override
  String warningsLabel(int count) => 'Warnings: $count';

  @override
  String get incidentsTitle => 'Incidents';

  @override
  String get incidentsEmptyTitle => 'No incidents';

  @override
  String get incidentsEmptyBody => 'Incidents recorded during your exams appear here.';

  @override
  String get incidentFilterOpen => 'Not decided';

  @override
  String get incidentFilterDecided => 'Decided';

  @override
  String incidentSeverityName(IncidentSeverity severity) => switch (severity) {
    IncidentSeverity.low => 'Low',
    IncidentSeverity.medium => 'Medium',
    IncidentSeverity.high => 'High',
    IncidentSeverity.critical => 'Critical',
  };

  @override
  String incidentSourceName(DetectionSource source) => switch (source) {
    DetectionSource.appLifecycle => 'App lifecycle',
    DetectionSource.platformApi => 'Device (operating system)',
    DetectionSource.appUi => 'The answer screen',
    DetectionSource.deviceHardware => 'Device hardware',
    DetectionSource.connectivity => 'Network',
    DetectionSource.aiDetector => 'AI detector',
    DetectionSource.manual => 'Added by hand',
  };

  @override
  String incidentDecisionName(ReviewDecision decision) => switch (decision) {
    ReviewDecision.noViolation => 'No violation',
    ReviewDecision.violationConfirmed => 'Violation confirmed',
    ReviewDecision.inconclusive => 'Inconclusive',
  };

  @override
  String get incidentUndecided => 'Not decided yet';

  @override
  String incidentDescription(IncidentCategory category, String? detail, int? seconds) => switch (category) {
    IncidentCategory.appBackgrounded =>
      seconds == null ? 'The app left the foreground.' : 'The app was off screen for $seconds seconds.',
    IncidentCategory.windowFocusLost => 'The exam window was not in focus for ${seconds ?? 0} seconds.',
    IncidentCategory.clipboardAttempt =>
      (detail ?? '').startsWith('bulk:')
          ? 'A block of ${(detail ?? '').substring(5)} characters was inserted at once into an answer and refused.'
          : 'A copy, cut or paste was attempted in an answer and blocked.',
    IncidentCategory.screenshotDetected => 'The device reported a screenshot or screen recording.',
    IncidentCategory.cameraUnavailable => 'The student started the exam without a working camera.',
    IncidentCategory.networkLost => 'The network was lost for ${seconds ?? 0} seconds. The exam continued.',
    _ => incidentCategoryName(category),
  };

  @override
  String get incidentDetailTitle => 'Incident';

  @override
  String incidentWhoWhat(String student, String exam) => '$student · $exam';

  @override
  String get incidentSeverityLabel => 'Severity';

  @override
  String get incidentSourceLabel => 'Detected by';

  @override
  String get incidentTimelineHeading => 'Timeline of this attempt';

  @override
  String get incidentThisOne => '(this incident)';

  @override
  String get incidentEvidenceHeading => 'Evidence';

  @override
  String get evidenceUnavailableBody =>
      'Unavailable. There is no recording. This app cannot record video from before an incident, so none exists and none is shown.';

  @override
  String evidenceCapturedBody(String reference) => 'A recording exists: $reference';

  @override
  String get incidentDecisionHeading => 'Your decision';

  @override
  String get incidentNotesLabel => 'Notes (optional)';

  @override
  String get incidentSaveDecision => 'Save decision';

  @override
  String get incidentDecisionSaved => 'Decision saved.';

  @override
  String incidentWarningsLine(int count, int limit) => 'Warnings in this attempt: $count of $limit';

  @override
  String get incidentLimitReached => 'The warning limit was reached. Marks are not changed by warnings.';

  @override
  String get incidentNotAVerdict => 'An incident is an observation, not a verdict. It never changes a mark.';

  @override
  String get dashboardExamsHeading => 'Your exams';

  @override
  String dashboardStatusCount(String status, int count) => '$status: $count';

  @override
  String dashboardNeedsMarking(int count) =>
      "${count == 1 ? '1 written answer is' : '$count written answers are'} waiting for your marks";

  @override
  String get dashboardNothingToMark => 'No written answers are waiting to be marked.';

  @override
  String dashboardIncidentsWaiting(int count) =>
      "${count == 1 ? '1 incident is' : '$count incidents are'} waiting for a decision";

  @override
  String get dashboardNoIncidentsWaiting => 'No incidents are waiting for a decision.';
}
