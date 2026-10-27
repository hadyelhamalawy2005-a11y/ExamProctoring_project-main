import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The student's exams.
final studentExamListProvider = FutureProvider.autoDispose<Result<List<StudentExamSummary>>>(
  (ref) => ref.watch(studentExamRepositoryProvider).listExams(),
);

/// One exam's briefing.
final studentExamInfoProvider = FutureProvider.autoDispose.family<Result<StudentExamInfo>, String>(
  (ref, examId) => ref.watch(studentExamRepositoryProvider).getExam(examId),
);

/// The student's submitted attempts.
final studentResultsProvider = FutureProvider.autoDispose<Result<List<StudentResult>>>(
  (ref) => ref.watch(attemptRepositoryProvider).listResults(),
);

/// One result.
final studentResultProvider = FutureProvider.autoDispose.family<Result<StudentResult>, String>(
  (ref, attemptId) => ref.watch(attemptRepositoryProvider).getResult(attemptId),
);
