import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:meta/meta.dart';

/// A server endpoint the app needs that the backend does not provide (or provides in an incompatible shape).
@immutable
final class MissingEndpoint {
  /// Creates an entry.
  const MissingEndpoint({required this.endpoint, required this.neededFor, required this.reason});

  /// The method and route, for example `POST /api/admin/students`.
  final String endpoint;

  /// What in the app needs it.
  final String neededFor;

  /// Why the existing API cannot serve it today.
  final String reason;

  /// The failure an Api repository returns instead of falling back to local data.
  AppFailure toFailure() => EndpointMissingFailure(endpoint: endpoint, reason: reason);

  /// An error result carrying [toFailure].
  Err<T> refuse<T>() => Err<T>(toFailure());
}

/// THE handover list for the backend team: every endpoint the Api repositories need but the backend does not yet
/// provide. An Api repository whose endpoint is in this list REFUSES with the endpoint's name; it never falls back to the
/// local implementation.
///
/// Verified against `src/ExamProctoring.Api/Controllers` in this repository (AuthController, AdminAccountsController,
/// ExamsController, QuestionsController, QuestionImportController). Add an entry here whenever a feature needs something
/// that does not exist there.
abstract final class MissingEndpoints {
  /// Admin creating a student account.
  static const MissingEndpoint createStudentAccount = MissingEndpoint(
    endpoint: 'POST /api/admin/students',
    neededFor: 'Administrator > Create account > Student',
    reason:
        'The API only has POST /api/admin/instructors. Students currently register themselves '
        '(POST /api/auth/register), which the app must not offer: nobody signs themselves up.',
  );

  /// Creating an exam before its start time is known.
  static const MissingEndpoint createDraftExam = MissingEndpoint(
    endpoint: 'POST /api/exams (draft without startsAt)',
    neededFor: 'Instructor > Create exam > details step',
    reason:
        'POST /api/exams requires startsAt. The wizard saves the details first and asks for the schedule later, so a '
        'draft cannot be created without inventing a start time.',
  );

  /// Course name, instructions, pass mark, versioning and exam settings.
  static const MissingEndpoint examExtendedFields = MissingEndpoint(
    endpoint: 'PUT /api/exams/{id} (courseName, instructions, passMarkPercent, version, settings)',
    neededFor: 'Exam wizard: details and settings steps',
    reason:
        'ExamRequest has only title, description, startsAt and durationMinutes. The app also stores the course name, '
        'student instructions, pass mark, a version number and ten settings (randomisation, calculator, navigation, '
        'result display, proctoring rules, thresholds). Sending them would silently drop them.',
  );

  /// An availability window longer than the exam's duration.
  static const MissingEndpoint availabilityWindow = MissingEndpoint(
    endpoint: 'PUT /api/exams/{id} (closesAt)',
    neededFor: 'Exam wizard: schedule step with a window longer than the duration',
    reason:
        'ExamRequest has startsAt and durationMinutes only; EndsAt is calculated as startsAt + duration. Students cannot '
        'be given a window in which they may start, so the window can only be exactly the exam duration.',
  );

  /// The multiple-choice question type.
  static const MissingEndpoint multipleChoiceQuestions = MissingEndpoint(
    endpoint: 'POST /api/exams/{examId}/questions (type MultipleChoice)',
    neededFor: 'Exam wizard: multiple-choice questions',
    reason:
        'The API knows Mcq (exactly one correct option) and Essay only. Multiple choice with all-or-nothing marking '
        'cannot be stored.',
  );

  /// A question's topic and difficulty labels.
  static const MissingEndpoint questionMetadata = MissingEndpoint(
    endpoint: 'POST /api/exams/{examId}/questions (topic, difficulty)',
    neededFor: 'Word import: Topic and Difficulty lines',
    reason: 'QuestionRequest has no topic or difficulty field, so they would be dropped silently.',
  );

  /// Adding several questions at once.
  static const MissingEndpoint addQuestionsBatch = MissingEndpoint(
    endpoint: 'POST /api/exams/{examId}/questions/batch',
    neededFor: 'Word import: adding the reviewed questions',
    reason:
        'Questions are created one request at a time, so a failure half-way would leave a partly imported exam. The '
        'import must be all-or-nothing.',
  );

  /// Reordering questions.
  static const MissingEndpoint reorderQuestions = MissingEndpoint(
    endpoint: 'PUT /api/exams/{examId}/questions/order',
    neededFor: 'Exam wizard: moving a question up or down',
    reason: 'A question keeps the position it was created with; there is no way to move it.',
  );

  /// Listing exams by derived status.
  static const MissingEndpoint listExamsByPhase = MissingEndpoint(
    endpoint: 'GET /api/exams?phase=Scheduled|Ongoing|Completed',
    neededFor: 'Instructor exam list: filter by Scheduled, Ongoing or Completed',
    reason:
        'The API filters by stored status (Draft, Published, Cancelled) only. Phase is calculated per row, so filtering '
        'it in the app would break paging and the total count.',
  );

  /// Student: exam list and dashboard
  static const MissingEndpoint studentExamList = MissingEndpoint(
    endpoint: 'GET /api/student/exams',
    neededFor: 'Student: exam list and dashboard',
    reason: 'The API only lists exams for their owning instructor (GET /api/exams). Students have no way to see published exams.',
  );

  /// Student: exam briefing
  static const MissingEndpoint studentExamBriefing = MissingEndpoint(
    endpoint: 'GET /api/student/exams/{id}',
    neededFor: 'Student: exam briefing',
    reason: 'There is no student-facing exam read, and the instructor read includes the answer key.',
  );

  /// Student: consent before the system check
  static const MissingEndpoint recordConsent = MissingEndpoint(
    endpoint: 'POST /api/exams/{id}/consent',
    neededFor: 'Student: consent before the system check',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: start or resume an attempt
  static const MissingEndpoint startAttempt = MissingEndpoint(
    endpoint: 'POST /api/exams/{id}/attempts',
    neededFor: 'Student: start or resume an attempt',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: reload an attempt
  static const MissingEndpoint attemptSession = MissingEndpoint(
    endpoint: 'GET /api/attempts/{id}',
    neededFor: 'Student: reload an attempt',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: autosave of every answer
  static const MissingEndpoint saveAnswer = MissingEndpoint(
    endpoint: 'PUT /api/attempts/{id}/answers/{questionId}',
    neededFor: 'Student: autosave of every answer',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: remember the current question
  static const MissingEndpoint saveProgress = MissingEndpoint(
    endpoint: 'PUT /api/attempts/{id}/progress',
    neededFor: 'Student: remember the current question',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: submit (manual or at the deadline)
  static const MissingEndpoint submitAttempt = MissingEndpoint(
    endpoint: 'POST /api/attempts/{id}/submit',
    neededFor: 'Student: submit (manual or at the deadline)',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: result of one attempt
  static const MissingEndpoint attemptResult = MissingEndpoint(
    endpoint: 'GET /api/attempts/{id}/result',
    neededFor: 'Student: result of one attempt',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Student: list of results
  static const MissingEndpoint studentResults = MissingEndpoint(
    endpoint: 'GET /api/me/results',
    neededFor: 'Student: list of results',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Instructor: attempts at an exam
  static const MissingEndpoint instructorAttempts = MissingEndpoint(
    endpoint: 'GET /api/exams/{id}/attempts',
    neededFor: 'Instructor: attempts at an exam',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Instructor: one attempt with every answer
  static const MissingEndpoint attemptReview = MissingEndpoint(
    endpoint: 'GET /api/attempts/{id}/review',
    neededFor: 'Instructor: one attempt with every answer',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Instructor: marking a typed answer
  static const MissingEndpoint markShortAnswer = MissingEndpoint(
    endpoint: 'PUT /api/attempts/{id}/answers/{questionId}/marks',
    neededFor: 'Instructor: marking a typed answer',
    reason: 'The API has no attempts: no table, controller or DTO for students taking an exam exists yet.',
  );

  /// Proctoring: recording an incident from the exam player.
  static const MissingEndpoint recordIncident = MissingEndpoint(
    endpoint: 'POST /api/attempts/{id}/incidents',
    neededFor: 'Proctoring: recording an incident from the exam player',
    reason: 'The API has no incident or evidence model: no table, controller or DTO exists for proctoring records.',
  );

  /// Instructor: the incident queue.
  static const MissingEndpoint incidentQueue = MissingEndpoint(
    endpoint: 'GET /api/incidents',
    neededFor: 'Instructor: the incident queue',
    reason: 'The API has no incident or evidence model: no table, controller or DTO exists for proctoring records.',
  );

  /// Instructor: one incident with its timeline.
  static const MissingEndpoint incidentDetail = MissingEndpoint(
    endpoint: 'GET /api/incidents/{id}',
    neededFor: 'Instructor: one incident with its timeline',
    reason: 'The API has no incident or evidence model: no table, controller or DTO exists for proctoring records.',
  );

  /// Instructor: deciding an incident.
  static const MissingEndpoint incidentDecision = MissingEndpoint(
    endpoint: 'PUT /api/incidents/{id}/decision',
    neededFor: 'Instructor: deciding an incident',
    reason: 'The API has no incident or evidence model: no table, controller or DTO exists for proctoring records.',
  );

  /// Every entry, in the order features were built.
  static const List<MissingEndpoint> all = [
    createStudentAccount,
    createDraftExam,
    examExtendedFields,
    availabilityWindow,
    multipleChoiceQuestions,
    questionMetadata,
    addQuestionsBatch,
    reorderQuestions,
    listExamsByPhase,
    studentExamList,
    studentExamBriefing,
    recordConsent,
    startAttempt,
    attemptSession,
    saveAnswer,
    saveProgress,
    submitAttempt,
    attemptResult,
    studentResults,
    instructorAttempts,
    attemptReview,
    markShortAnswer,
    recordIncident,
    incidentQueue,
    incidentDetail,
    incidentDecision,
  ];
}
