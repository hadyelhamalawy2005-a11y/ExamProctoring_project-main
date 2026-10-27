import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/features/exam_session/data/api_exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/data/local_attempt_repository.dart';
import 'package:examora_app/features/exam_session/data/local_instructor_attempt_repository.dart';
import 'package:examora_app/features/exam_session/data/local_stores.dart';
import 'package:examora_app/features/exam_session/data/local_student_exam_repository.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/proctoring/data/api_incident_repositories.dart';
import 'package:examora_app/features/proctoring/data/local_incident_repositories.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one provider that decides where a student's exam list comes from.
final studentExamRepositoryProvider = Provider<StudentExamRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalStudentExamRepository(
      exams: ref.watch(localExamStoreProvider),
      attempts: ref.watch(localAttemptStoreProvider),
      caller: ref.watch(localCallerProvider),
      clock: ref.watch(clockProvider),
    ),
    DataSource.api => const ApiStudentExamRepository(),
  },
);

/// The one provider that decides where a student's attempts live.
final attemptRepositoryProvider = Provider<AttemptRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalAttemptRepository(
      exams: ref.watch(localExamStoreProvider),
      attempts: ref.watch(localAttemptStoreProvider),
      consents: ref.watch(localConsentStoreProvider),
      caller: ref.watch(localCallerProvider),
      clock: ref.watch(clockProvider),
    ),
    DataSource.api => const ApiAttemptRepository(),
  },
);

/// The one provider that decides where an instructor's view of attempts comes from.
final instructorAttemptRepositoryProvider = Provider<InstructorAttemptRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalInstructorAttemptRepository(
      exams: ref.watch(localExamStoreProvider),
      attempts: ref.watch(localAttemptStoreProvider),
      caller: ref.watch(localCallerProvider),
      incidentCount: (attemptId) async {
        final incidents = await ref.read(localIncidentStoreProvider).all();
        return incidents.where((incident) => incident.attemptId == attemptId).length;
      },
    ),
    DataSource.api => const ApiInstructorAttemptRepository(),
  },
);

/// Where the exam player reports incidents.
final incidentRecorderProvider = Provider<IncidentRecorder>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalIncidentRecorder(
      attempts: ref.watch(localAttemptStoreProvider),
      incidents: ref.watch(localIncidentStoreProvider),
      caller: ref.watch(localCallerProvider),
    ),
    DataSource.api => const ApiIncidentRecorder(),
  },
);

/// Where an instructor reviews incidents.
final incidentReviewRepositoryProvider = Provider<IncidentReviewRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalIncidentReviewRepository(
      incidents: ref.watch(localIncidentStoreProvider),
      caller: ref.watch(localCallerProvider),
      clock: ref.watch(clockProvider),
    ),
    DataSource.api => const ApiIncidentReviewRepository(),
  },
);
