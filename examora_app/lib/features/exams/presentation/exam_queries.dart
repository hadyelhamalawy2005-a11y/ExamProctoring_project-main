import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the exam list shows: the status filter and the page. A record, so equal queries share one cached result.
typedef ExamQuery = ({ExamStatus? status, int page});

/// One page of the instructor's exams. Invalidate it after any change so the list shows the new truth.
final examListProvider = FutureProvider.autoDispose.family<Result<ExamPage>, ExamQuery>(
  (ref, query) => ref.watch(examRepositoryProvider).listExams(status: query.status, page: query.page),
);

/// One exam with its questions.
final examDetailProvider = FutureProvider.autoDispose.family<Result<Exam>, String>(
  (ref, id) => ref.watch(examRepositoryProvider).getExam(id),
);
