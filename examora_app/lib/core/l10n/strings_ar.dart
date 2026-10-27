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

/// The Arabic texts.
final class ArabicStrings extends AppStrings {
  /// Creates the Arabic strings.
  const ArabicStrings();

  @override
  String get languageCode => 'ar';

  @override
  String get appName => 'Examora';

  @override
  String get retry => 'أعد المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get errorTitle => 'تعذّر التحميل';

  @override
  String get missingEndpointLabel => 'نقطة الخادم المطلوبة';

  @override
  String get languageLabel => 'اللغة';

  @override
  String get restoringSession => 'جارٍ استعادة جلستك…';

  @override
  String get homeTab => 'الرئيسية';

  @override
  String get examsTab => 'الامتحانات';

  @override
  String get resultsTab => 'النتائج';

  @override
  String get incidentsTab => 'الوقائع';

  @override
  String get profileTab => 'الملف الشخصي';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get loginSubtitle => 'سجّل الدخول بالحساب الذي أعطاك إياه مدير النظام.';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get signInButton => 'تسجيل الدخول';

  @override
  String get signingIn => 'جارٍ تسجيل الدخول…';

  @override
  String get forgotPasswordLink => 'هل نسيت كلمة المرور؟';

  @override
  String get accountsCreatedByAdmin => 'يُنشئ مدير النظام الحسابات.';

  @override
  String get forgotPasswordTitle => 'هل نسيت كلمة المرور؟';

  @override
  String get forgotPasswordBody =>
      'لا توجد إعادة تعيين تلقائية لكلمة المرور. اطلب من مدير النظام إصدار كلمة مرور مؤقتة جديدة. '
      'وسيُطلب منك اختيار كلمة مرور خاصة بك عند أول تسجيل دخول بها.';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get changePasswordForcedTitle => 'اختر كلمة مرور جديدة';

  @override
  String get changePasswordForcedBody =>
      'سجّلت الدخول بكلمة مرور مؤقتة. يجب أن تختار كلمة مرور خاصة بك قبل أن تتمكن من استخدام Examora.';

  @override
  String get currentPasswordLabel => 'كلمة المرور الحالية';

  @override
  String get newPasswordLabel => 'كلمة المرور الجديدة';

  @override
  String get confirmNewPasswordLabel => 'أعد كتابة كلمة المرور الجديدة';

  @override
  String get passwordPolicyHint => '8 أحرف على الأقل، مع حرف كبير وحرف صغير ورقم.';

  @override
  String get changePasswordButton => 'تغيير كلمة المرور';

  @override
  String get passwordChanged => 'تم تغيير كلمة المرور.';

  @override
  String get signOutInstead => 'تسجيل الخروج بدلاً من ذلك';

  @override
  String welcomeUser(String name) => 'مرحباً، ${isolate(name)}';

  @override
  String roleName(UserRole role) => switch (role) {
    UserRole.student => 'طالب',
    UserRole.instructor => 'مدرّس',
    UserRole.administrator => 'مدير النظام',
  };

  @override
  String get notBuiltTitle => 'لم يُبنَ بعد';

  @override
  String notBuiltBody(String feature) => '$feature لم يُبنَ بعد. لا تُعرض على هذه الشاشة أي بيانات حقيقية.';

  @override
  String featureName(PlannedFeature feature) => switch (feature) {
    PlannedFeature.studentExams => 'قائمة الامتحانات',
    PlannedFeature.studentResults => 'النتائج',
    PlannedFeature.examBriefing => 'نبذة الامتحان',
    PlannedFeature.examConsent => 'شاشة الموافقة',
    PlannedFeature.systemCheck => 'فحص النظام',
    PlannedFeature.examPlayer => 'شاشة الامتحان',
    PlannedFeature.attemptResult => 'نتيجة المحاولة',
    PlannedFeature.instructorExams => 'قائمة الامتحانات',
    PlannedFeature.incidentQueue => 'قائمة الوقائع',
    PlannedFeature.incidentDetail => 'مراجعة الواقعة',
    PlannedFeature.examAttempts => 'قائمة المحاولات',
  };

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get identitySection => 'حسابك';

  @override
  String get fullNameLabel => 'الاسم';

  @override
  String get roleLabel => 'الدور';

  @override
  String get dataLocationSection => 'أين توجد بياناتك';

  @override
  String get dataLocationBody =>
      'كل ما يخزنه Examora - الحسابات والامتحانات والإجابات والسجلات - محفوظ على هذا الجهاز. '
      'لا يُرسل أي شيء إلى خادم.';

  @override
  String get privacySection => 'ما الذي يُجمع أثناء الامتحان';

  @override
  String get privacyBody =>
      'أثناء الاختبار يسجّل التطبيق مغادرتك له، ومحاولات النسخ أو اللصق في الإجابات، ولقطات الشاشة (حيث يُبلغ الجهاز '
      'التطبيق)، وانقطاع الشبكة، وما إذا بدأت بدون كاميرا. يُخزَّن كل تسجيل على هذا الجهاز مع وقته ويستطيع مدرّس '
      'الاختبار قراءته. تُستخدم الكاميرا فقط لفحص قبل الاختبار: لا يُسجَّل فيديو أو صوت ولا يُخزَّن ولا يُرسل. '
      'لا يحتوي هذا الإصدار على كشف الوجه أو النظرة أو الكلام. تُخزَّن إجاباتك ودرجاتك على هذا الجهاز. '
      'التحذيرات لا تغيّر أي درجة أبداً.';

  @override
  String get languageSection => 'اللغة';

  @override
  String get validationGeneric => 'بعض الحقول غير صحيحة.';

  @override
  String get conflictGeneric => 'يتعارض هذا الإجراء مع الحالة الحالية.';

  @override
  String get failureInvalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get failureAccountLocked => 'تم قفل هذا الحساب مؤقتاً بعد محاولات فاشلة كثيرة. حاول مرة أخرى لاحقاً.';

  @override
  String get failureAccountDeactivated => 'تم تعطيل هذا الحساب. تواصل مع مدير النظام.';

  @override
  String get failureTemporaryPasswordExpired =>
      'انتهت صلاحية كلمة المرور المؤقتة. اطلب من مدير النظام كلمة مرور جديدة.';

  @override
  String get failureSessionExpired => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get failurePasswordChangeRequired => 'يجب تغيير كلمة المرور قبل المتابعة.';

  @override
  String get failureForbidden => 'ليست لديك صلاحية لتنفيذ هذا الإجراء.';

  @override
  String get failureNotFound => 'لم يتم العثور على العنصر المطلوب.';

  @override
  String get failureNetwork => 'تعذّر الوصول إلى الخادم. تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get failureTimeout => 'استغرق الخادم وقتاً طويلاً للرد. حاول مرة أخرى.';

  @override
  String get failureRateLimited => 'محاولات كثيرة جداً. يرجى الانتظار دقيقة ثم المحاولة مرة أخرى.';

  @override
  String get failureServer => 'حدثت مشكلة في الخادم. يرجى المحاولة لاحقاً.';

  @override
  String get failureStorage => 'تعذّرت قراءة البيانات أو كتابتها على هذا الجهاز.';

  @override
  String failureParse(String field) => 'تعذّرت قراءة البيانات (${isolate(field)}).';

  @override
  String failureEndpointMissing(String endpoint) => 'لم يُبنَ هذا بعد: نقطة الخادم ${isolate(endpoint)} غير موجودة.';

  @override
  String failureUnavailable(String capability, String? because) =>
      because == null ? '${isolate(capability)} غير متاح.' : '${isolate(capability)} غير متاح: ${isolate(because)}';

  @override
  String get fieldRequired => 'هذا الحقل مطلوب.';

  @override
  String get fieldInvalidEmail => 'أدخل بريداً إلكترونياً صالحاً.';

  @override
  String get fieldPasswordPolicy => 'يجب أن تحتوي كلمة المرور على 8 أحرف على الأقل، وحرف كبير، وحرف صغير، ورقم.';

  @override
  String get fieldPasswordsDiffer => 'كلمتا المرور غير متطابقتين.';

  @override
  String get fieldCurrentPasswordIncorrect => 'كلمة المرور الحالية غير صحيحة.';

  @override
  String get fieldNewPasswordSame => 'يجب أن تختلف كلمة المرور الجديدة عن الحالية.';

  @override
  String get fieldTooLong => 'النص طويل جداً.';

  @override
  String get adminAccountsTitle => 'الحسابات';

  @override
  String get adminAddAccount => 'إضافة حساب';

  @override
  String get filterRole => 'الدور';

  @override
  String get filterStatus => 'الحالة';

  @override
  String get filterAll => 'الكل';

  @override
  String accountStatusName(AccountStatus status) => status == AccountStatus.active ? 'مفعّل' : 'معطّل';

  @override
  String get accountsEmptyTitle => 'لا توجد حسابات بعد';

  @override
  String get accountsEmptyFiltered => 'لا يوجد حساب يطابق هذه التصفية.';

  @override
  String accountsShowing(int shown, int total) => 'عرض $shown من $total';

  @override
  String get previousPage => 'السابق';

  @override
  String get nextPage => 'التالي';

  @override
  String pageNumber(int page) => 'الصفحة $page';

  @override
  String get lockedBadge => 'مقفل';

  @override
  String get mustChangePasswordBadge => 'يجب تغيير كلمة المرور';

  @override
  String get accountDetailTitle => 'الحساب';

  @override
  String get accountStatusLabel => 'حالة الحساب';

  @override
  String get createdAtLabel => 'تاريخ الإنشاء';

  @override
  String get lastLoginLabel => 'آخر تسجيل دخول';

  @override
  String get neverSignedIn => 'لم يسجّل الدخول بعد';

  @override
  String get statusChangedLabel => 'تاريخ تغيير الحالة';

  @override
  String get statusReasonLabel => 'السبب';

  @override
  String get temporaryPasswordExpiresLabel => 'تنتهي كلمة المرور المؤقتة';

  @override
  String get passwordLockedLabel => 'قفل تسجيل الدخول';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String timeZoneNote(String zone) => 'تُعرض الأوقات بتوقيت هذا الجهاز: ${isolate(zone)}.';

  @override
  String get issueTemporaryPassword => 'إصدار كلمة مرور مؤقتة';

  @override
  String get issuePasswordTitle => 'إصدار كلمة مرور مؤقتة؟';

  @override
  String issuePasswordBody(String name) =>
      'ستتوقف كلمة مرور ${isolate(name)} الحالية عن العمل، وتنتهي جلسات الدخول الحالية، وعليه اختيار كلمة مرور جديدة عند الدخول التالي.';

  @override
  String get deactivateAccount => 'تعطيل الحساب';

  @override
  String get deactivateTitle => 'تعطيل هذا الحساب؟';

  @override
  String deactivateBody(String name) =>
      'لن يتمكن ${isolate(name)} من تسجيل الدخول حتى يُعاد تفعيل الحساب. السبب مطلوب.';

  @override
  String get reasonRequiredLabel => 'السبب (مطلوب)';

  @override
  String get reasonOptionalLabel => 'السبب (اختياري)';

  @override
  String get reactivateAccount => 'إعادة تفعيل الحساب';

  @override
  String get reactivateTitle => 'إعادة تفعيل هذا الحساب؟';

  @override
  String reactivateBody(String name) => 'سيتمكن ${isolate(name)} من تسجيل الدخول مرة أخرى.';

  @override
  String get accountDeactivatedNotice => 'تم تعطيل الحساب.';

  @override
  String get accountReactivatedNotice => 'تمت إعادة تفعيل الحساب.';

  @override
  String get createAccountTitle => 'إنشاء حساب';

  @override
  String get accountTypeLabel => 'نوع الحساب';

  @override
  String get createAccountHint => 'تُنشأ كلمة مرور مؤقتة وتظهر مرة واحدة فقط. على الشخص تغييرها عند أول تسجيل دخول.';

  @override
  String get createAccountButton => 'إنشاء الحساب';

  @override
  String get temporaryPasswordTitle => 'كلمة المرور المؤقتة';

  @override
  String get temporaryPasswordOnce =>
      'تظهر كلمة المرور هذه مرة واحدة فقط ولا يمكن عرضها مرة أخرى، لذا انسخها أو أرسلها الآن.';

  @override
  String temporaryPasswordFor(String name, String email) => 'لـ ${isolate(name)} (${isolate(email)})';

  @override
  String temporaryPasswordExpires(String when) => 'تعمل حتى $when. عليهم تغييرها عند أول تسجيل دخول.';

  @override
  String get copyPassword => 'نسخ كلمة المرور';

  @override
  String get passwordCopied => 'تم نسخ كلمة المرور.';

  @override
  String get sendByEmail => 'إرسال بالبريد الإلكتروني';

  @override
  String get emailNotAvailable => 'تعذّر فتح تطبيق بريد إلكتروني على هذا الجهاز. انسخ كلمة المرور بدلاً من ذلك.';

  @override
  String get temporaryPasswordEmailSubject => 'كلمة مرور Examora المؤقتة';

  @override
  String temporaryPasswordEmailBody(String name, String email, String password, String when) =>
      'مرحباً $name،\n\nتم إنشاء حساب Examora لك.\nالبريد الإلكتروني: $email\nكلمة المرور المؤقتة: $password\n\nتعمل حتى $when. سيُطلب منك اختيار كلمة مرور جديدة عند أول تسجيل دخول.';

  @override
  String get iHaveSavedIt => 'لقد حفظتها';

  @override
  String get conflictDuplicateAccount => 'يوجد حساب بهذا البريد الإلكتروني بالفعل.';

  @override
  String get conflictAlreadyActive => 'الحساب مفعّل بالفعل.';

  @override
  String get conflictAlreadyDeactivated => 'الحساب معطّل بالفعل.';

  @override
  String get fieldInvalidCharacters => 'يحتوي على أحرف غير مسموح بها.';

  @override
  String get fieldOutOfRange => 'هذا الرقم خارج النطاق المسموح.';

  @override
  String get fieldWindowTooShort => 'يجب ألا تقل مدة الإتاحة عن مدة الاختبار.';

  @override
  String get failureExamNotPublishable => 'لا يمكن نشر الاختبار بعد.';

  @override
  String get conflictExamNotEditable => 'لم يعد بالإمكان تعديل هذا الاختبار في حالته الحالية.';

  @override
  String get conflictExamAlreadyPublished => 'هذا الاختبار منشور بالفعل.';

  @override
  String get conflictExamArchived => 'تمت أرشفة هذا الاختبار ولا يمكن نشره.';

  @override
  String get conflictExamNotUnpublishable => 'لا يعود إلى المسودة إلا اختبار منشور لم يُفتح بعد وليس له محاولات.';

  @override
  String get conflictExamNotArchivable => 'لا يمكن أرشفة إلا اختبار منشور.';

  @override
  String get conflictExamNotDeletable => 'لا يمكن حذف إلا المسودات.';

  @override
  String get conflictQuestionExists => 'هذا السؤال موجود بالفعل في الاختبار.';

  @override
  String questionProblemMessage(QuestionProblem problem) => switch (problem) {
    QuestionProblem.noText => 'السؤال بلا نص.',
    QuestionProblem.textTooLong => 'نص السؤال أطول من ${ExamLimits.questionTextMax} حرفاً.',
    QuestionProblem.invalidMarks => 'يجب أن تكون الدرجة أكبر من 0 وحتى 9999.99 وبمنزلتين عشريتين على الأكثر.',
    QuestionProblem.tooFewOptions => 'سؤال الاختيار يحتاج ${ExamLimits.optionsMin} خيارات على الأقل.',
    QuestionProblem.tooManyOptions => 'سؤال الاختيار يقبل ${ExamLimits.optionsMax} خيارات على الأكثر.',
    QuestionProblem.optionEmpty => 'أحد الخيارات بلا نص.',
    QuestionProblem.optionTooLong => 'أحد الخيارات أطول من ${ExamLimits.optionTextMax} حرفاً.',
    QuestionProblem.noCorrectAnswer => 'لم يتم تحديد أي خيار كإجابة صحيحة.',
    QuestionProblem.severalCorrectForSingle => 'سؤال الاختيار الواحد يجب أن يكون له خيار صحيح واحد بالضبط.',
    QuestionProblem.duplicateOptionTexts => 'خياران لهما النص نفسه.',
    QuestionProblem.optionsOnShortText => 'السؤال النصي القصير لا يقبل خيارات.',
    QuestionProblem.modelAnswerTooLong => 'الإجابة النموذجية أطول من ${ExamLimits.modelAnswerMax} حرفاً.',
    QuestionProblem.flaggedForReview => 'السؤال معلّم للمراجعة. افتحه وتحقق منه ثم احفظه.',
    QuestionProblem.answerKeyStale => 'تغيّرت الخيارات بعد تحديد الإجابة الصحيحة. افتح السؤال وأكّد الإجابة الصحيحة.',
  };

  @override
  String publishProblemMessage(PublishProblem problem) => switch (problem) {
    DetailsIncompleteProblem() =>
      'بيانات الاختبار أو إعداداته ناقصة أو خارج النطاق. ارجع إلى خطوتي البيانات والإعدادات.',
    NoQuestionsProblem() => 'الاختبار بلا أسئلة.',
    QuestionPublishProblem(:final position, :final problem) => 'السؤال $position: ${questionProblemMessage(problem)}',
    ScheduleMissingProblem() => 'لم تُحدَّد فترة الإتاحة. اختر وقت فتح الاختبار وإغلاقه.',
    WindowTooShortProblem() => 'فترة الإتاحة أقصر من مدة الاختبار.',
    StartTimePassedProblem() => 'وقت البدء مضى بالفعل. اختر وقتاً لاحقاً.',
  };

  @override
  String examStatusName(ExamStatus status) => switch (status) {
    ExamStatus.draft => 'مسودة',
    ExamStatus.scheduled => 'مجدول',
    ExamStatus.ongoing => 'جارٍ',
    ExamStatus.completed => 'مكتمل',
    ExamStatus.archived => 'مؤرشف',
  };

  @override
  String questionTypeName(QuestionType type) => switch (type) {
    QuestionType.singleChoice => 'اختيار واحد',
    QuestionType.multipleChoice => 'اختيار متعدد',
    QuestionType.shortText => 'نص قصير',
  };

  @override
  String questionTypeHint(QuestionType type) => switch (type) {
    QuestionType.singleChoice => 'يختار الطالب خياراً واحداً. يُصحَّح تلقائياً.',
    QuestionType.multipleChoice => 'يختار الطالب أي عدد من الخيارات. يُصحَّح تلقائياً بنظام الكل أو لا شيء: الدرجة الكاملة فقط عند اختيار الخيارات الصحيحة تماماً.',
    QuestionType.shortText => 'يكتب الطالب إجابة. لا يصحّحها التطبيق أبداً: أنت تصحّحها بنفسك.',
  };

  @override
  String get examsTitle => 'الاختبارات';

  @override
  String get createExamButton => 'إنشاء اختبار';

  @override
  String get examsEmptyTitle => 'لا توجد اختبارات بعد';

  @override
  String get examsEmptyBody => 'أنشئ أول اختبار للبدء.';

  @override
  String get examsEmptyFiltered => 'لا يوجد اختبار بهذه الحالة.';

  @override
  String examsShowing(int shown, int total) => 'عرض $shown من $total';

  @override
  String examSummary(String course, int minutes, int questions) =>
      '${isolate(course)} · المدة: $minutes د · الأسئلة: $questions';

  @override
  String get examMethodTitle => 'كيف تريد إنشاء الاختبار؟';

  @override
  String get examMethodManual => 'إنشاء يدوي';

  @override
  String get examMethodManualBody => 'اكتب الأسئلة بنفسك، سؤالاً سؤالاً.';

  @override
  String get examMethodWord => 'استيراد من Word';

  @override
  String get examMethodWordBody => 'اقرأ الأسئلة من ملف docx مكتوب وفق قالب Examora. تراجع كل شيء قبل إضافته.';

  @override
  String get examMethodDetailsFirst => 'تبدأ الطريقتان ببيانات الاختبار، فيكون للاختبار عنوان قبل حفظ أي شيء.';

  @override
  String get wizardNewTitle => 'اختبار جديد';

  @override
  String get wizardEditTitle => 'تعديل الاختبار';

  @override
  String wizardStepOf(int step, int total, String name) => 'الخطوة $step من $total · $name';

  @override
  String get stepDetails => 'البيانات';

  @override
  String get stepQuestions => 'الأسئلة';

  @override
  String get stepSettings => 'الإعدادات';

  @override
  String get stepSchedule => 'الجدولة';

  @override
  String get stepReview => 'المراجعة والنشر';

  @override
  String get nextStep => 'التالي';

  @override
  String get previousStep => 'رجوع';

  @override
  String get saveAndContinue => 'حفظ ومتابعة';

  @override
  String get savedNotice => 'تم الحفظ على هذا الجهاز.';

  @override
  String get examTitleLabel => 'عنوان الاختبار';

  @override
  String get examCourseLabel => 'اسم المقرر';

  @override
  String get examDescriptionLabel => 'الوصف (اختياري)';

  @override
  String get examInstructionsLabel => 'تعليمات للطلاب (اختياري)';

  @override
  String get examDurationLabel => 'المدة (بالدقائق)';

  @override
  String get examPassMarkLabel => 'درجة النجاح (% من الدرجة الكلية)';

  @override
  String examVersionLabel(int version) => 'الإصدار $version';

  @override
  String get examVersionHelp => 'يزداد رقم الإصدار عند تغيّر ما يراه الطلاب أو يُقيَّمون عليه بعد النشر.';

  @override
  String questionsSummary(int count, String marks) => 'عدد الأسئلة: $count · مجموع الدرجات: $marks';

  @override
  String get addQuestion => 'إضافة سؤال';

  @override
  String get questionsEmpty => 'لا توجد أسئلة بعد. أضف سؤالاً أو استوردها من Word.';

  @override
  String questionNumber(int number) => 'السؤال $number';

  @override
  String marksValue(String marks) => 'الدرجة: $marks';

  @override
  String get moveUp => 'نقل لأعلى';

  @override
  String get moveDown => 'نقل لأسفل';

  @override
  String get editQuestion => 'تعديل';

  @override
  String get deleteQuestion => 'حذف';

  @override
  String get deleteQuestionTitle => 'حذف هذا السؤال؟';

  @override
  String get deleteQuestionBody => 'ستتم إزالته من الاختبار.';

  @override
  String get needsReviewBadge => 'يحتاج مراجعة';

  @override
  String get answerKeyStaleBadge => 'أكّد الإجابة';

  @override
  String get wordBadge => 'WORD';

  @override
  String get newQuestionTitle => 'سؤال جديد';

  @override
  String get editQuestionTitle => 'تعديل السؤال';

  @override
  String get questionTypeLabel => 'نوع السؤال';

  @override
  String get questionTextLabel => 'السؤال';

  @override
  String get marksFieldLabel => 'الدرجة';

  @override
  String optionLabel(int number) => 'الخيار $number';

  @override
  String get addOption => 'إضافة خيار';

  @override
  String get removeOption => 'إزالة الخيار';

  @override
  String get markCorrect => 'الإجابة الصحيحة';

  @override
  String get modelAnswerLabel => 'إجابة نموذجية (لمن يصحّح، اختياري)';

  @override
  String get explanationLabel => 'شرح يظهر مع النتيجة (اختياري)';

  @override
  String get confirmAnswerKey => 'تحققت من الخيارات الصحيحة';

  @override
  String get saveQuestion => 'حفظ السؤال';

  @override
  String get questionSavedNotice => 'تم حفظ السؤال.';

  @override
  String get settingRandomizeQuestions => 'ترتيب الأسئلة عشوائي';

  @override
  String get settingRandomizeOptions => 'ترتيب الخيارات عشوائي';

  @override
  String get settingCalculator => 'السماح بالآلة الحاسبة العلمية';

  @override
  String get settingBackward => 'السماح للطلاب بالرجوع إلى الأسئلة السابقة';

  @override
  String get settingShowResult => 'إظهار النتيجة فور تسليم الاختبار';

  @override
  String get settingShowExplanations => 'إظهار الشروح مع النتيجة';

  @override
  String get proctoringRulesHeading => 'قواعد المراقبة';

  @override
  String incidentCategoryName(IncidentCategory category) => switch (category) {
    IncidentCategory.appBackgrounded => 'مغادرة التطبيق',
    IncidentCategory.windowFocusLost => 'فقدان تركيز النافذة',
    IncidentCategory.deviceInterrupted => 'مقاطعة الجهاز',
    IncidentCategory.clipboardAttempt => 'محاولة نسخ أو لصق',
    IncidentCategory.screenshotDetected => 'لقطة شاشة أو تسجيل',
    IncidentCategory.cameraUnavailable => 'الكاميرا غير متاحة',
    IncidentCategory.microphoneUnavailable => 'الميكروفون غير متاح',
    IncidentCategory.networkLost => 'انقطاع الشبكة',
    IncidentCategory.gazeAway => 'النظر بعيداً',
    IncidentCategory.faceAbsent => 'غياب الوجه',
    IncidentCategory.multipleFaces => 'عدة وجوه',
    IncidentCategory.speechDetected => 'سماع كلام',
  };

  @override
  String get ruleInactiveNoDetector =>
      'غير فعّال: لا يحتوي هذا الإصدار على كاشف للوجه أو النظرة أو الكلام، لذا لا يمكن لهذه القاعدة أن تعمل.';

  @override
  String get ruleImmediateHint => 'تُسجَّل فوراً';

  @override
  String get ruleSustainedHint => 'تُسجَّل بعد بلوغ الحد';

  @override
  String get settingThreshold => 'حد السلوك المستمر (بالثواني)';

  @override
  String get settingThresholdHelp => 'يجب أن يستمر السلوك هذه المدة ليُعدّ حادثة. النظرات القصيرة لا تتراكم أبداً.';

  @override
  String get settingBuffer => 'مخزن الأدلة (بالثواني)';

  @override
  String get settingBufferHelp =>
      'عدد ثواني الفيديو التي تريد حفظها قبل الحادثة. لا يستطيع هذا الإصدار تسجيل الفيديو بأثر رجعي، لذا ستُعرض الأدلة على أنها غير متاحة.';

  @override
  String get settingMaxWarnings => 'عدد التحذيرات قبل تعليم المحاولة';

  @override
  String get settingMaxWarningsHelp =>
      'عندما يصل الطالب إلى هذا العدد من التحذيرات تُعلَّم المحاولة لمراجعتك. لا ينتهي الاختبار ولا تتغير الدرجات أبداً.';

  @override
  String get scheduleOpensLabel => 'يُفتح';

  @override
  String get scheduleClosesLabel => 'يُغلق';

  @override
  String get scheduleNotSet => 'غير محدد';

  @override
  String get scheduleChoose => 'اختر التاريخ والوقت';

  @override
  String get scheduleHelp =>
      'يستطيع الطلاب البدء بين هذين الوقتين. تستمر كل محاولة طوال مدة الاختبار لكنها لا تتجاوز وقت الإغلاق.';

  @override
  String get reviewReady => 'جاهز للنشر';

  @override
  String reviewBlocked(int count) => 'أمور تحتاج إصلاحاً قبل النشر: $count';

  @override
  String get publishExam => 'نشر الاختبار';

  @override
  String get publishedNotice => 'تم نشر الاختبار.';

  @override
  String get publishConfirmTitle => 'نشر هذا الاختبار؟';

  @override
  String get publishConfirmBody => 'سيراه الطلاب منذ وقت فتحه. يمكنك تعديله حتى موعد فتحه.';

  @override
  String get unpublishExam => 'إعادة إلى مسودة';

  @override
  String get archiveExam => 'أرشفة الاختبار';

  @override
  String get archiveConfirmTitle => 'أرشفة هذا الاختبار؟';

  @override
  String get archiveConfirmBody => 'الاختبار المؤرشف يُسحب نهائياً.';

  @override
  String get deleteDraft => 'حذف المسودة';

  @override
  String get deleteDraftTitle => 'حذف هذه المسودة؟';

  @override
  String get deleteDraftBody => 'ستُحذف المسودة وأسئلتها نهائياً.';

  @override
  String get examNotEditableNotice => 'لم يعد بالإمكان تعديل هذا الاختبار لأنه فُتح أو أُرشف.';

  @override
  String get examDetailOpen => 'فتح';

  @override
  String documentRejectionMessage(DocumentRejection reason) => switch (reason) {
    DocumentRejection.notDocx => 'يمكن استيراد مستندات Word المحفوظة بصيغة docx فقط.',
    DocumentRejection.oldDoc =>
      'هذا ملف Word قديم (doc). افتحه في Word واختر حفظ باسم > مستند Word (docx) ثم اختر الملف الجديد.',
    DocumentRejection.pdf => 'هذا ملف PDF حتى لو انتهى اسمه بـ docx. انسخ الأسئلة إلى مستند Word واحفظه بصيغة docx.',
    DocumentRejection.notAZip => 'هذا الملف ليس مستند Word: ملف docx حزمة مضغوطة وهذا الملف ليس كذلك.',
    DocumentRejection.notWord =>
      'هذه الحزمة ليست مستند Word (لا تحتوي على جزء المستند). قد تكون ملف Excel أو PowerPoint.',
    DocumentRejection.tooLarge => 'حجم الملف أكبر من 10 ميغابايت وهو حد الاستيراد.',
    DocumentRejection.tooComplex => 'هذا المستند معقّد جداً ولا يمكن قراءته بأمان.',
    DocumentRejection.unreadable => 'الملف تالف ولا يمكن قراءته كمستند Word.',
    DocumentRejection.empty => 'لا يحتوي المستند على أي نص.',
  };

  @override
  String get importTitle => 'استيراد من Word';

  @override
  String get importIntro => 'اختر ملف docx مكتوباً وفق قالب Examora. لا يُضاف شيء إلى الاختبار قبل أن تراجع كل سؤال.';

  @override
  String get importChooseFile => 'اختر ملف docx';

  @override
  String get importChooseAnother => 'اختر ملفاً آخر';

  @override
  String get importTemplateHelp => 'القالب والقواعد';

  @override
  String get importTemplateTitle => 'قالب أسئلة Examora';

  @override
  String get importTemplateRules =>
      'يبدأ كل سؤال بـ "Question 1 [MCQ]". استخدم [MCQ] لخيار صحيح واحد و [Multiple] لعدة خيارات و [Short] لإجابة مكتوبة. الخيارات "A." و "B." ... والإجابة "Correct Answer: B" (أو "A, C"). السطر "Marks:" مطلوب: لا يختار المستورد درجة نيابةً عنك. "Difficulty:" و "Topic:" اختياريان. يتم تجاهل الحذف المتتبَّع في Word. لا يمكن استيراد الجداول والصور والمعادلات وسيتم سردها.';

  @override
  String get importTemplateCopy => 'نسخ نص القالب';

  @override
  String get importTemplateCopied => 'تم نسخ نص القالب.';

  @override
  String get importTemplateSave => 'حفظ القالب (docx)';

  @override
  String get importTemplateSaved => 'تم حفظ القالب.';

  @override
  String get importTemplateSaveFailed => 'تعذّر حفظ القالب هنا. انسخ نصه بدلاً من ذلك.';

  @override
  String importReading(String name) => 'جارٍ قراءة $name…';

  @override
  String importFileLabel(String name) => 'الملف: $name';

  @override
  String importSummary(int found, int ready, int attention, int notImported) =>
      'الموجود: $found · الجاهز: $ready · يحتاج مراجعة: $attention · غير مستورد: $notImported';

  @override
  String get importOnlyAttention => 'الأسئلة التي تحتاج مراجعة فقط';

  @override
  String get importNothingToShow => 'لا يحتاج أي سؤال إلى مراجعة.';

  @override
  String get importNoQuestionsFound => 'لم يُعثر على أي سؤال في هذا المستند. تأكد من أنه يتبع القالب.';

  @override
  String importStatusName(ImportStatus status) => switch (status) {
    ImportStatus.ready => 'جاهز',
    ImportStatus.needsAttention => 'يحتاج مراجعة',
    ImportStatus.notImported => 'غير مستورد',
  };

  @override
  String importQuestionHeading(int number, int line) => 'السؤال $number · السطر $line';

  @override
  String get importAsWritten => 'كما كُتب في المستند';

  @override
  String importLine(int line, String text) => '$line: ${isolate(text)}';

  @override
  String get importDontImport => 'عدم الاستيراد';

  @override
  String get importDoImport => 'استيراد هذا السؤال';

  @override
  String get importAcknowledge => 'راجعت هذا السؤال';

  @override
  String get importAcknowledged => 'تمت المراجعة';

  @override
  String get importNoProblems => 'لا توجد مشكلات.';

  @override
  String get importReadOnlyNote => 'مقروء من الملف. مجرد وسم لك: لا يُستخدم في التصحيح أبداً.';

  @override
  String get topicLabel => 'الموضوع';

  @override
  String get difficultyLabel => 'الصعوبة';

  @override
  String get importUnattachedTitle => 'نص لا ينتمي إلى أي سؤال';

  @override
  String get importUnattachedBody =>
      'قُرئت هذه الأسطر ولم تُستورد. إن كان أحدها جزءاً من سؤال فصحّحه في المستند واستورد مرة أخرى.';

  @override
  String importIgnoredNote(int count) => 'قُرئ $count سطراً (عنوان المستند وعناوين الأقسام) ولا تُستخدم.';

  @override
  String get importSkippedTitle => 'محتوى تعذّر استيراده';

  @override
  String importSkippedKindName(SkippedKind kind) => switch (kind) {
    SkippedKind.image => 'صورة أو رسم',
    SkippedKind.table => 'جدول',
    SkippedKind.equation => 'معادلة',
  };

  @override
  String importSkippedItem(String kindName, int afterLine) => '$kindName بعد السطر $afterLine';

  @override
  String importContinue(int count) => 'إضافة إلى الاختبار ($count)';

  @override
  String get importContinueNone => 'أبقِ سؤالاً واحداً على الأقل للمتابعة.';

  @override
  String get importContinueBlocked => 'أصلح الأسئلة التي لا يمكن إضافتها بعد (المعلَّمة أدناه) أو اختر عدم استيرادها.';

  @override
  String importAdded(int count) => 'تمت الإضافة إلى الاختبار: $count';

  @override
  String importIssueMessage(ImportIssue issue) => switch (issue.code) {
    ImportIssueCode.typeInferred => 'لا يذكر المستند نوع هذا السؤال، لذا خُمِّن من شكله. تحقق من النوع.',
    ImportIssueCode.unknownTypeTag =>
      'النوع ${isolate(issue.detail ?? '')} غير معروف للمستورد. استخدم MCQ أو Multiple أو Short.',
    ImportIssueCode.strayText => 'لم يناسب هذا السطر السؤال ولم يُستورد: ${isolate(issue.detail ?? '')}',
    ImportIssueCode.unknownAnswerLabel => 'الإجابة الصحيحة ${isolate(issue.detail ?? '')} لا تطابق أي خيار.',
    ImportIssueCode.severalAnswersForSingle =>
      'عُلّمت عدة خيارات كصحيحة بينما النوع اختيار واحد. أبقِ خياراً واحداً أو غيّر النوع إلى اختيار متعدد.',
    ImportIssueCode.conflictingAnswerLines => 'يذكر المستند الإجابة الصحيحة أكثر من مرة والأسطر متعارضة.',
    ImportIssueCode.answerTreatedAsModel => 'سطر "Correct Answer" في سؤال بلا خيارات حُفظ كإجابة نموذجية.',
    ImportIssueCode.duplicateOptionLabel => 'الخيار ${isolate(issue.detail ?? '')} يظهر أكثر من مرة.',
    ImportIssueCode.duplicateQuestionNumber => 'رقم السؤال ${isolate(issue.detail ?? '')} يظهر أكثر من مرة في المستند.',
    ImportIssueCode.missingMarks => 'لا يوجد سطر "Marks:". أدخل الدرجة بنفسك: لا يختار المستورد رقماً نيابةً عنك.',
    ImportIssueCode.marksUnreadable => 'تعذّرت قراءة الدرجة ${isolate(issue.detail ?? '')} كرقم. أدخلها بنفسك.',
  };

  @override
  String get ruleInactiveNotDetectable =>
      'غير فعّال: لا يملك هذا الإصدار وسيلة لملاحظة ذلك، لذا لا يمكن لهذه القاعدة أن تعمل.';

  @override
  String get studentExamsTitle => 'اختباراتي';

  @override
  String get studentExamsEmptyTitle => 'لا توجد اختبارات متاحة بعد';

  @override
  String get studentExamsEmptyBody => 'عندما ينشر المدرّس اختباراً سيظهر هنا.';

  @override
  String attemptStateName(AttemptState state) => switch (state) {
    AttemptState.notStarted => 'لم يبدأ',
    AttemptState.inProgress => 'قيد التنفيذ',
    AttemptState.submitted => 'تم التسليم',
  };

  @override
  String examWindow(String from, String to) => 'متاح من $from إلى $to';

  @override
  String get studentResultsTitle => 'نتائجي';

  @override
  String get studentResultsEmptyTitle => 'لا توجد نتائج بعد';

  @override
  String get studentResultsEmptyBody => 'تظهر النتائج هنا بعد تسليم الاختبار.';

  @override
  String get briefingTitle => 'معلومات الاختبار';

  @override
  String get briefingInstructionsHeading => 'التعليمات';

  @override
  String get briefingDetailsHeading => 'الاختبار';

  @override
  String get briefingRulesHeading => 'طريقة سير الاختبار';

  @override
  String get briefingMonitoringHeading => 'ما الذي تتم مراقبته';

  @override
  String briefingDuration(int minutes) => 'الزمن المسموح: $minutes دقيقة';

  @override
  String briefingQuestions(int count) => 'عدد الأسئلة: $count';

  @override
  String briefingTotalMarks(String marks) => 'مجموع الدرجات: $marks';

  @override
  String briefingWindowLine(String from, String to) => 'متاح من $from إلى $to';

  @override
  String ruleCalculator(bool allowed) => (allowed ? 'تتوفر آلة حاسبة علمية.' : 'لا تتوفر آلة حاسبة.');

  @override
  String ruleBackward(bool allowed) =>
      (allowed ? 'يمكنك العودة إلى الأسئلة السابقة.' : 'لا يمكنك العودة إلى الأسئلة السابقة.');

  @override
  String ruleShuffled(bool questions, bool options) => (questions && options
      ? 'ترتيب الأسئلة وخيارات الإجابة عشوائي.'
      : questions
      ? 'ترتيب الأسئلة عشوائي.'
      : options
      ? 'ترتيب خيارات الإجابة عشوائي.'
      : 'ترتيب الأسئلة والخيارات واحد للجميع.');

  @override
  String get ruleAutosave =>
      'تُحفظ كل إجابة لحظة إدخالها. إذا غادرت وعدت تجد إجاباتك كما هي، لكن الوقت يستمر في العدّ.';

  @override
  String get monitoringIntro => 'أثناء فتح الاختبار تُسجَّل الأمور التالية كحوادث:';

  @override
  String get monitoringInactiveHeading => 'أدرجها المدرّس لكنها غير فعّالة في هذا التطبيق:';

  @override
  String get monitoringNoneActive => 'لا شيء تتم مراقبته في هذا الاختبار.';

  @override
  String get briefingContinue => 'متابعة';

  @override
  String get briefingResume => 'استئناف الاختبار';

  @override
  String get briefingViewResult => 'عرض نتيجتي';

  @override
  String briefingNotOpenYet(String when) => 'يُفتح هذا الاختبار في $when.';

  @override
  String get briefingClosed => 'هذا الاختبار مغلق ولم يعد بالإمكان بدؤه.';

  @override
  String get consentTitle => 'قبل أن تبدأ';

  @override
  String get consentIntro => 'يرجى قراءة كيفية الإشراف على هذا الاختبار.';

  @override
  String get consentPoint1 =>
      'أثناء فتح الاختبار يسجّل التطبيق مغادرتك له، ومحاولات النسخ أو اللصق في مربع الإجابة، ولقطات الشاشة (حيث يُبلغ الجهاز التطبيق)، وانقطاع الاتصال بالشبكة.';

  @override
  String get consentPoint2 =>
      'يُحفظ كل منها كحادثة مع وقت حدوثها. يستطيع مدرّس هذا الاختبار قراءتها. لا يمكنك قراءتها أو تغييرها.';

  @override
  String get consentPoint3 =>
      'تُستخدم الكاميرا فقط لفحص قبل بدء الاختبار. لا يسجّل هذا التطبيق أي فيديو أو صوت ولا يخزّنه ولا يرسله.';

  @override
  String get consentPoint4 =>
      'لا يحتوي هذا الإصدار على كشف الوجه أو النظرة أو الكلام. لا أحد ولا شيء يراقبك عبر الكاميرا.';

  @override
  String get consentPoint5 => 'التحذيرات لا تغيّر درجاتك أبداً. قد ينظر المدرّس في الحوادث ويقرر بنفسه.';

  @override
  String get consentAgree => 'قرأت هذا وأوافق';

  @override
  String get consentContinue => 'المتابعة إلى فحص النظام';

  @override
  String get consentDecline => 'رجوع';

  @override
  String get systemCheckTitle => 'فحص النظام';

  @override
  String get systemCheckIntro => 'تأكد من أن كل شيء يعمل قبل بدء الوقت. يبدأ الوقت عند الضغط على بدء الاختبار.';

  @override
  String get cameraCheckTitle => 'الكاميرا';

  @override
  String get cameraChecking => 'جارٍ فحص الكاميرا…';

  @override
  String get cameraWorking => 'الكاميرا تعمل. هذه المعاينة لا تُسجَّل.';

  @override
  String get cameraNone => 'لم يُعثر على كاميرا في هذا الجهاز.';

  @override
  String get cameraDenied => 'لم تُمنح صلاحية الكاميرا.';

  @override
  String get cameraError => 'تعذّر تشغيل الكاميرا.';

  @override
  String get cameraRetry => 'فحص الكاميرا مرة أخرى';

  @override
  String get startWithoutCamera => 'سأبدأ بدون كاميرا. سيُسجَّل هذا كحادثة.';

  @override
  String get connectionCheckTitle => 'الاتصال';

  @override
  String get connectionOnline => 'متصل. يعمل الاختبار أيضاً بدون اتصال.';

  @override
  String get connectionOffline => 'غير متصل. يمكنك أداء الاختبار: تُحفظ الإجابات على هذا الجهاز.';

  @override
  String get timeCheckTitle => 'الوقت';

  @override
  String timeCheckBody(int minutes, String zone) =>
      'سيكون لديك $minutes دقيقة. تُعرض الأوقات بتوقيت هذا الجهاز: $zone.';

  @override
  String get startExam => 'بدء الاختبار';

  @override
  String get consentNeeded => 'لم توافق على الإشعار بعد.';

  @override
  String timeRemaining(String time) => 'الوقت المتبقي: $time';

  @override
  String get timeLowWarning => 'بقي أقل من خمس دقائق.';

  @override
  String questionOf(int number, int total) => 'السؤال $number من $total';

  @override
  String get previousQuestion => 'السابق';

  @override
  String get nextQuestion => 'التالي';

  @override
  String get submitExam => 'تسليم الاختبار';

  @override
  String get submitConfirmTitle => 'تسليم الاختبار؟';

  @override
  String submitConfirmBody(int unanswered) => (unanswered == 0
      ? 'أجبت عن كل الأسئلة. بعد التسليم لا يمكنك تغيير شيء.'
      : 'عدد الأسئلة بلا إجابة: $unanswered. بعد التسليم لا يمكنك تغيير شيء.');

  @override
  String get savedIndicator => 'تم الحفظ';

  @override
  String get savingFailed => 'تعذّر حفظ هذه الإجابة. حاول مرة أخرى.';

  @override
  String get answerLabel => 'إجابتك';

  @override
  String get chooseOneHint => 'اختر إجابة واحدة.';

  @override
  String get chooseAllHint => 'اختر كل الإجابات الصحيحة. الدرجة الكاملة فقط إذا اخترت الصحيحة تماماً.';

  @override
  String get typedAnswerHint => 'اكتب إجابتك. سيصحّحها المدرّس.';

  @override
  String get pasteBlocked => 'النسخ واللصق غير مسموحين في الإجابات. تم تسجيل ذلك.';

  @override
  String get openCalculator => 'الآلة الحاسبة';

  @override
  String get questionPalette => 'كل الأسئلة';

  @override
  String paletteEntry(int number, bool answered) => "السؤال $number${answered ? '، تمت الإجابة' : '، بلا إجابة'}";

  @override
  String warningRecorded(String what, int count) => 'تم تسجيل تحذير: $what (التحذير $count)';

  @override
  String get warningLimitReached =>
      'بلغت حدّ التحذيرات. يستمر الاختبار ولا تتغير درجاتك، لكن المدرّس سيراجع هذه المحاولة.';

  @override
  String get offlineBanner => 'أنت غير متصل. تابع: تُحفظ إجاباتك على هذا الجهاز.';

  @override
  String get timeUpTitle => 'انتهى الوقت';

  @override
  String get timeUpBody => 'تم تسليم إجاباتك المحفوظة.';

  @override
  String get submitting => 'جارٍ التسليم…';

  @override
  String get attemptNotFound => 'لم يُعثر على هذه المحاولة.';

  @override
  String get calcTitle => 'آلة حاسبة علمية';

  @override
  String get calcDegrees => 'درجات';

  @override
  String get calcRadians => 'راديان';

  @override
  String get calcClear => 'مسح';

  @override
  String get calcBackspace => 'حذف الأخير';

  @override
  String get calcEquals => 'احسب';

  @override
  String get calcExpression => 'العملية';

  @override
  String calcError(CalcError error) => switch (error) {
    CalcError.empty => 'اكتب ما تريد حسابه.',
    CalcError.syntax => 'خطأ في الصياغة: تحقق من الأقواس والعمليات وأسماء الدوال.',
    CalcError.divisionByZero => 'لا يمكن القسمة على صفر.',
    CalcError.domain => 'غير معرَّف لهذا الرقم (مثل الجذر التربيعي لعدد سالب، أو ln لـ 0، أو tan لـ 90°).',
    CalcError.overflow => 'الناتج كبير جداً.',
    CalcError.tooLong => 'العملية طويلة جداً.',
    CalcError.tooDeep => 'أقواس متداخلة أكثر من اللازم.',
  };

  @override
  String get resultTitle => 'النتيجة';

  @override
  String resultSubmittedAt(String when) => 'سُلّم في $when';

  @override
  String get resultAutoSubmitted => 'سُلّم تلقائياً عند انتهاء الوقت.';

  @override
  String resultHeldBack(String when) => 'تم تسليم اختبارك. ستظهر النتيجة بعد إغلاق فترة الاختبار ($when).';

  @override
  String resultScore(String awarded, String total) => '$awarded من $total درجة';

  @override
  String resultPercent(String percent) => '$percent%';

  @override
  String get resultPassed => 'ناجح';

  @override
  String get resultFailed => 'غير ناجح';

  @override
  String get resultNoPassMark => 'ليس لهذا الاختبار درجة نجاح.';

  @override
  String resultPending(int count) =>
      'عدد الإجابات المكتوبة التي تنتظر التصحيح: $count. لا تشملها الدرجات أعلاه بعد، ولم يتحدد النجاح بعد.';

  @override
  String get resultAnswersHeading => 'إجاباتك';

  @override
  String outcomeName(QuestionOutcome outcome) => switch (outcome) {
    QuestionOutcome.correct => 'صحيحة',
    QuestionOutcome.incorrect => 'خاطئة',
    QuestionOutcome.unanswered => 'بلا إجابة',
    QuestionOutcome.pendingManual => 'بانتظار التصحيح',
    QuestionOutcome.markedManually => 'صحّحها مدرّسك',
  };

  @override
  String questionMarksOf(String awarded, String max) => '$awarded / $max';

  @override
  String get explanationLabelShort => 'الشرح';

  @override
  String get resultsNoKeyNote => 'لا تُعرض الإجابات الصحيحة هنا.';

  @override
  String get attemptsTitle => 'المحاولات';

  @override
  String get attemptsButton => 'عرض المحاولات';

  @override
  String get attemptsEmptyTitle => 'لا توجد محاولات بعد';

  @override
  String get attemptsEmptyBody => 'تظهر المحاولات هنا عندما يبدأ الطلاب الاختبار.';

  @override
  String attemptStatusName(AttemptStatus status) => switch (status) {
    AttemptStatus.inProgress => 'قيد التنفيذ',
    AttemptStatus.submitted => 'تم التسليم',
  };

  @override
  String attemptMarks(String awarded, String total) => 'الدرجات حتى الآن: $awarded من $total';

  @override
  String attemptPending(int count) => 'للتصحيح: $count';

  @override
  String attemptIncidents(int count) => 'الحوادث: $count';

  @override
  String get attemptReviewTitle => 'المحاولة';

  @override
  String get studentAnswerLabel => 'إجابة الطالب';

  @override
  String get noAnswer => '(بلا إجابة)';

  @override
  String get correctOptionsLabel => 'الخيارات الصحيحة';

  @override
  String get chosenMarker => 'مختار';

  @override
  String get correctMarker => 'صحيح';

  @override
  String marksOutOf(String max) => 'الدرجة (من 0 إلى $max)';

  @override
  String get saveMarks => 'حفظ الدرجة';

  @override
  String marksSaved(String value) => 'تم حفظ الدرجة: $value';

  @override
  String marksClamped(String value) => 'حُدّدت بما يتيحه السؤال: $value';

  @override
  String warningsLabel(int count) => 'التحذيرات: $count';

  @override
  String get incidentsTitle => 'الحوادث';

  @override
  String get incidentsEmptyTitle => 'لا توجد حوادث';

  @override
  String get incidentsEmptyBody => 'تظهر هنا الحوادث المسجَّلة أثناء اختباراتك.';

  @override
  String get incidentFilterOpen => 'بلا قرار';

  @override
  String get incidentFilterDecided => 'تم اتخاذ قرار';

  @override
  String incidentSeverityName(IncidentSeverity severity) => switch (severity) {
    IncidentSeverity.low => 'منخفضة',
    IncidentSeverity.medium => 'متوسطة',
    IncidentSeverity.high => 'عالية',
    IncidentSeverity.critical => 'حرجة',
  };

  @override
  String incidentSourceName(DetectionSource source) => switch (source) {
    DetectionSource.appLifecycle => 'دورة حياة التطبيق',
    DetectionSource.platformApi => 'الجهاز (نظام التشغيل)',
    DetectionSource.appUi => 'شاشة الإجابة',
    DetectionSource.deviceHardware => 'عتاد الجهاز',
    DetectionSource.connectivity => 'الشبكة',
    DetectionSource.aiDetector => 'كاشف ذكاء اصطناعي',
    DetectionSource.manual => 'أُضيفت يدوياً',
  };

  @override
  String incidentDecisionName(ReviewDecision decision) => switch (decision) {
    ReviewDecision.noViolation => 'لا مخالفة',
    ReviewDecision.violationConfirmed => 'تأكدت المخالفة',
    ReviewDecision.inconclusive => 'غير حاسمة',
  };

  @override
  String get incidentUndecided => 'لم يُتخذ قرار بعد';

  @override
  String incidentDescription(IncidentCategory category, String? detail, int? seconds) => switch (category) {
    IncidentCategory.appBackgrounded =>
      seconds == null ? 'غادر التطبيق الواجهة.' : 'كان التطبيق خارج الشاشة لمدة $seconds ثانية.',
    IncidentCategory.windowFocusLost => 'لم تكن نافذة الاختبار في التركيز لمدة ${seconds ?? 0} ثانية.',
    IncidentCategory.clipboardAttempt =>
      (detail ?? '').startsWith('bulk:')
          ? 'أُدخلت كتلة من ${(detail ?? '').substring(5)} حرفاً دفعة واحدة في إجابة ورُفضت.'
          : 'جرت محاولة نسخ أو قص أو لصق في إجابة وتم منعها.',
    IncidentCategory.screenshotDetected => 'أبلغ الجهاز عن لقطة شاشة أو تسجيل للشاشة.',
    IncidentCategory.cameraUnavailable => 'بدأ الطالب الاختبار بدون كاميرا تعمل.',
    IncidentCategory.networkLost => 'انقطعت الشبكة لمدة ${seconds ?? 0} ثانية. استمر الاختبار.',
    _ => incidentCategoryName(category),
  };

  @override
  String get incidentDetailTitle => 'الحادثة';

  @override
  String incidentWhoWhat(String student, String exam) => '$student · $exam';

  @override
  String get incidentSeverityLabel => 'الخطورة';

  @override
  String get incidentSourceLabel => 'اكتُشفت بواسطة';

  @override
  String get incidentTimelineHeading => 'الخط الزمني لهذه المحاولة';

  @override
  String get incidentThisOne => '(هذه الحادثة)';

  @override
  String get incidentEvidenceHeading => 'الأدلة';

  @override
  String get evidenceUnavailableBody =>
      'غير متاح. لا يوجد تسجيل. لا يستطيع هذا التطبيق تسجيل الفيديو السابق لوقوع الحادثة، لذا لا يوجد ولا يُعرض شيء.';

  @override
  String evidenceCapturedBody(String reference) => 'يوجد تسجيل: $reference';

  @override
  String get incidentDecisionHeading => 'قرارك';

  @override
  String get incidentNotesLabel => 'ملاحظات (اختياري)';

  @override
  String get incidentSaveDecision => 'حفظ القرار';

  @override
  String get incidentDecisionSaved => 'تم حفظ القرار.';

  @override
  String incidentWarningsLine(int count, int limit) => 'التحذيرات في هذه المحاولة: $count من $limit';

  @override
  String get incidentLimitReached => 'بلغت المحاولة حدّ التحذيرات. التحذيرات لا تغيّر الدرجات.';

  @override
  String get incidentNotAVerdict => 'الحادثة ملاحظة وليست حكماً. ولا تغيّر أي درجة أبداً.';

  @override
  String get dashboardExamsHeading => 'اختباراتك';

  @override
  String dashboardStatusCount(String status, int count) => '$status: $count';

  @override
  String dashboardNeedsMarking(int count) => 'إجابات مكتوبة تنتظر درجاتك: $count';

  @override
  String get dashboardNothingToMark => 'لا توجد إجابات مكتوبة تنتظر التصحيح.';

  @override
  String dashboardIncidentsWaiting(int count) => 'حوادث بانتظار قرار: $count';

  @override
  String get dashboardNoIncidentsWaiting => 'لا توجد حوادث بانتظار قرار.';
}
