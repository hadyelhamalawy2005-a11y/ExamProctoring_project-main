/// Screens whose features are not built yet. Each shows a plain "not built yet" message instead of pretending to work;
/// an entry disappears (and the compiler flags every place that named it) when its feature is built.
enum PlannedFeature {
  /// The student's list of exams.
  studentExams,

  /// The student's results.
  studentResults,

  /// The exam briefing.
  examBriefing,

  /// The consent screen before camera use.
  examConsent,

  /// The pre-exam system check.
  systemCheck,

  /// The exam player.
  examPlayer,

  /// The result of one attempt.
  attemptResult,

  /// The instructor's exam list.
  instructorExams,

  /// The incident queue.
  incidentQueue,

  /// One incident.
  incidentDetail,

  /// Attempts at one exam.
  examAttempts,
}
