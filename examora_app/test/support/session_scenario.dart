import 'dart:math';

import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/data/consent_record.dart';
import 'package:examora_app/features/exam_session/data/local_attempt_repository.dart';
import 'package:examora_app/features/exam_session/data/local_instructor_attempt_repository.dart';
import 'package:examora_app/features/exam_session/data/local_student_exam_repository.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exams/data/local_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/data/local_incident_repositories.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';

import 'exam_fixtures.dart';
import 'test_harness.dart';

/// Every local repository wired over one in-memory device, plus three students and two instructors, so a test can switch
/// who is signed in and check what each of them can and cannot do.
final class SessionScenario {
  SessionScenario._(this.env, Random random) {
    accounts = LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock);
    sessions = LocalSessionStore(env.secureStore);
    auth = LocalAuthRepository(
      accounts: accounts,
      sessions: sessions,
      hasher: TestEnvironment.fastHasher,
      clock: env.clock,
    );
    caller = LocalCaller(accounts: accounts, sessions: sessions, clock: env.clock);
    examStore = JsonCollectionStore<Exam>(
      store: env.keyValueStore,
      key: 'local.exams.v1',
      fromJson: Exam.fromJson,
      toJson: (e) => e.toJson(),
    );
    attemptStore = JsonCollectionStore<Attempt>(
      store: env.keyValueStore,
      key: 'local.attempts.v1',
      fromJson: Attempt.fromJson,
      toJson: (a) => a.toJson(),
    );
    consentStore = JsonCollectionStore<ConsentRecord>(
      store: env.keyValueStore,
      key: 'local.consents.v1',
      fromJson: ConsentRecord.fromJson,
      toJson: (c) => c.toJson(),
    );
    incidentStore = JsonCollectionStore<Incident>(
      store: env.keyValueStore,
      key: 'local.incidents.v1',
      fromJson: Incident.fromJson,
      toJson: (i) => i.toJson(),
    );
    exams = LocalExamRepository(
      exams: examStore,
      caller: caller,
      clock: env.clock,
      hasAttempts: (id) async => (await attemptStore.all()).any((a) => a.exam.id == id),
    );
    studentExams = LocalStudentExamRepository(
      exams: examStore,
      attempts: attemptStore,
      caller: caller,
      clock: env.clock,
    );
    attempts = LocalAttemptRepository(
      exams: examStore,
      attempts: attemptStore,
      consents: consentStore,
      caller: caller,
      clock: env.clock,
      random: random,
    );
    instructorAttempts = LocalInstructorAttemptRepository(
      exams: examStore,
      attempts: attemptStore,
      caller: caller,
      incidentCount: (id) async => (await incidentStore.all()).where((i) => i.attemptId == id).length,
    );
    recorder = LocalIncidentRecorder(attempts: attemptStore, incidents: incidentStore, caller: caller);
    review = LocalIncidentReviewRepository(incidents: incidentStore, caller: caller, clock: env.clock);
  }

  /// Seeds the three accounts and adds a second student and a second instructor.
  static Future<SessionScenario> create({Random? random, TestEnvironment? env}) async {
    final scenario = SessionScenario._(
      env ?? TestEnvironment(now: DateTime.utc(2026, 10, 27, 9)),
      random ?? Random(42),
    );
    await scenario.accounts.ensureSeeded();
    final hash = await TestEnvironment.fastHasher.hash('Examora#2026');
    await scenario.accounts.mutate((all) {
      for (final (id, name, email, role) in [
        ('student-2', 'Second Student', 'student2@examora.app', UserRole.student),
        ('instructor-2', 'Other Instructor', 'instructor2@examora.app', UserRole.instructor),
      ]) {
        all.add(
          StoredAccount(
            id: id,
            fullName: name,
            email: email,
            role: role,
            passwordHash: hash,
            mustChangePassword: false,
            status: AccountStatus.active,
            createdAt: scenario.env.clock.now(),
          ),
        );
      }
    });
    return scenario;
  }

  final TestEnvironment env;
  late final LocalAccountStore accounts;
  late final LocalSessionStore sessions;
  late final LocalAuthRepository auth;
  late final LocalCaller caller;
  late final JsonCollectionStore<Exam> examStore;
  late final JsonCollectionStore<Attempt> attemptStore;
  late final JsonCollectionStore<ConsentRecord> consentStore;
  late final JsonCollectionStore<Incident> incidentStore;
  late final LocalExamRepository exams;
  late final LocalStudentExamRepository studentExams;
  late final LocalAttemptRepository attempts;
  late final LocalInstructorAttemptRepository instructorAttempts;
  late final LocalIncidentRecorder recorder;
  late final LocalIncidentReviewRepository review;

  /// The window used by [publishedExam]: opens one hour after the scenario starts, closes four hours later.
  DateTime get opens => DateTime.utc(2026, 10, 27, 10);
  DateTime get closes => DateTime.utc(2026, 10, 27, 14);

  /// Signs in as [email] (all test accounts share the password `Examora#2026`).
  Future<void> signInAs(String email) async {
    await auth.signOut();
    ok(await auth.signIn(email: email, password: 'Examora#2026'));
  }

  /// Moves the clock to [moment] and signs in again as [email] (a session lasts 12 hours).
  Future<void> travelTo(DateTime moment, {required String email}) async {
    env.clock.setTo(moment);
    await signInAs(email);
  }

  /// As instructor@examora.app: creates, fills, schedules and publishes an exam. The clock stays where it was (before
  /// the window opens); the signed-in account is left as the instructor.
  Future<Exam> publishedExam({
    List<Question>? questions,
    ExamSettings settings = const ExamSettings(),
    int minutes = 60,
    double? passMark = 50,
    String owner = 'instructor@examora.app',
  }) async {
    await signInAs(owner);
    final created = ok(await exams.createExam(details(minutes: minutes, passMark: passMark ?? 0)));
    ok(await exams.updateSettings(created.id, settings));
    ok(await exams.addQuestions(created.id, questions ?? [singleChoice(), multipleChoice(), shortText()]));
    ok(await exams.updateSchedule(created.id, opensAt: opens, closesAt: closes));
    return ok(await exams.publish(created.id));
  }

  /// Moves the clock inside the window and signs in as the student, with consent given. Returns nothing; use [attempts].
  Future<void> openWindowAndConsent(String examId, {String student = 'student@examora.app'}) async {
    await travelTo(opens.add(const Duration(minutes: 5)), email: student);
    ok(await attempts.recordConsent(examId));
  }
}
