/// Every route in the app, in one place. Screens navigate with these, never with string literals.
abstract final class RoutePaths {
  /// Splash: session restore.
  static const String splash = '/';

  /// Sign in.
  static const String login = '/login';

  /// Forgot password.
  static const String forgotPassword = '/forgot-password';

  /// Change password: forced or voluntary.
  static const String changePassword = '/change-password';

  // ---- Student ----

  /// Student home.
  static const String studentDashboard = '/student/dashboard';

  /// Student exam list.
  static const String studentExams = '/student/exams';

  /// Student results.
  static const String studentResults = '/student/results';

  /// Student profile.
  static const String studentProfile = '/student/profile';

  /// Exam briefing.
  static String studentExam(String examId) => '/student/exams/$examId';

  /// Consent before any camera use.
  static String studentConsent(String examId) => '/student/exams/$examId/consent';

  /// System check.
  static String studentSystemCheck(String examId) => '/student/exams/$examId/system-check';

  /// Exam player.
  static String studentAttempt(String attemptId) => '/student/attempts/$attemptId';

  /// Result of one attempt.
  static String studentAttemptResult(String attemptId) => '/student/attempts/$attemptId/result';

  // ---- Instructor ----

  /// Instructor home.
  static const String instructorDashboard = '/instructor/dashboard';

  /// Instructor exam list.
  static const String instructorExams = '/instructor/exams';

  /// Instructor incident queue.
  static const String instructorIncidents = '/instructor/incidents';

  /// Instructor profile.
  static const String instructorProfile = '/instructor/profile';

  /// Choose how to create an exam.
  static const String instructorNewExamMethod = '/instructor/exams/new/method';

  /// Authoring wizard.
  static String instructorExamEdit(String examId) => '/instructor/exams/$examId/edit';

  /// The id the wizard uses while the exam does not exist yet. Its first step creates the draft.
  static const String newExamId = 'new';

  /// The query parameter that carries how a new exam is being created ([methodManual] or [methodWord]).
  static const String methodParameter = 'method';

  /// Value of [methodParameter]: questions are written by hand.
  static const String methodManual = 'manual';

  /// Value of [methodParameter]: questions are imported from a Word file once the details are saved.
  static const String methodWord = 'word';

  /// The wizard for a brand-new exam, created by [method].
  static String instructorNewExam(String method) => '${instructorExamEdit(newExamId)}?$methodParameter=$method';

  /// Word import.
  static String instructorExamImport(String examId) => '/instructor/exams/$examId/import';

  /// Attempts at one exam.
  static String instructorExamAttempts(String examId) => '/instructor/exams/$examId/attempts';

  /// One incident.
  static String instructorIncident(String incidentId) => '/instructor/incidents/$incidentId';

  // ---- Administrator ----

  /// Account list (the administrator's home).
  static const String adminAccounts = '/admin/accounts';

  /// One account.
  static String adminAccount(String accountId) => '/admin/accounts/$accountId';

  /// Create an account.
  static const String adminNewInstructor = '/admin/instructors/new';

  /// Administrator profile.
  static const String adminProfile = '/admin/profile';

  /// The query parameter on the player route that says the student started without a working camera.
  static const String cameraParameter = 'camera';

  /// The query parameter that remembers where a deep link was going.
  static const String fromParameter = 'from';
}
