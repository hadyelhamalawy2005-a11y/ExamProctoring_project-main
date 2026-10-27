import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/word_import/data/docx_reader.dart';
import 'package:examora_app/features/word_import/data/question_document_parser.dart';
import 'package:examora_app/features/word_import/data/word_file_source.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// Where the import is.
enum ImportPhase {
  /// Nothing chosen yet.
  idle,

  /// A file is being read.
  reading,

  /// A file was read and is being reviewed.
  reviewing,

  /// The file could not be used.
  failed,
}

/// Everything the import screen shows.
@immutable
final class ImportSessionState {
  /// Creates the state.
  const ImportSessionState({
    this.phase = ImportPhase.idle,
    this.fileName = '',
    this.drafts = const [],
    this.unattached = const [],
    this.ignored = const [],
    this.skipped = const [],
    this.failure,
    this.onlyAttention = false,
  });

  /// Where the import is.
  final ImportPhase phase;

  /// The file being reviewed.
  final String fileName;

  /// The questions as they are being edited.
  final List<ImportDraft> drafts;

  /// Lines that belong to no question.
  final List<SourceLine> unattached;

  /// Title and heading lines that were read and are not used.
  final List<SourceLine> ignored;

  /// Content that could not be imported.
  final List<SkippedContent> skipped;

  /// Why the file was refused, when it was.
  final AppFailure? failure;

  /// Whether the list shows only the questions that need attention.
  final bool onlyAttention;

  /// A copy with the given changes.
  ImportSessionState copyWith({List<ImportDraft>? drafts, bool? onlyAttention}) => ImportSessionState(
    phase: phase,
    fileName: fileName,
    drafts: drafts ?? this.drafts,
    unattached: unattached,
    ignored: ignored,
    skipped: skipped,
    failure: failure,
    onlyAttention: onlyAttention ?? this.onlyAttention,
  );
}

/// The review in progress: chooses and reads a file, holds the edits, and finally adds the reviewed questions to the exam.
class ImportSessionController extends Notifier<ImportSessionState> {
  static const Uuid _uuid = Uuid();

  @override
  ImportSessionState build() => const ImportSessionState();

  /// Lets the user choose a file and reads it. A file over 10 MB is refused before its content is read.
  Future<void> chooseFile() async {
    final picked = await ref.read(wordFileSourceProvider).pick();
    if (picked == null || !ref.mounted) return;

    state = ImportSessionState(phase: ImportPhase.reading, fileName: picked.name);
    final size = picked.size;
    if (size != null && size > DocxReader.maxFileBytes) {
      _fail(picked.name, const DocumentRejectedFailure(DocumentRejection.tooLarge));
      return;
    }
    final bytes = await picked.read();
    if (!ref.mounted) return;
    final read = DocxReader.read(fileName: picked.name, bytes: bytes);
    switch (read) {
      case Err<ExtractedDocument>(:final failure):
        _fail(picked.name, failure);
      case Ok<ExtractedDocument>(:final value):
        final preview = QuestionDocumentParser.parse(value);
        state = ImportSessionState(
          phase: ImportPhase.reviewing,
          fileName: picked.name,
          drafts: [for (final parsed in preview.questions) ImportDraft.fromParsed(parsed, newId: _uuid.v4)],
          unattached: preview.unattached,
          ignored: preview.ignored,
          skipped: preview.skipped,
        );
    }
  }

  void _fail(String name, AppFailure failure) {
    state = ImportSessionState(phase: ImportPhase.failed, fileName: name, failure: failure);
  }

  /// Replaces the draft with the same id.
  void update(ImportDraft draft) {
    state = state.copyWith(drafts: [for (final d in state.drafts) d.id == draft.id ? draft : d]);
  }

  /// Shows only the questions that need attention, or all of them.
  void setOnlyAttention({required bool value}) => state = state.copyWith(onlyAttention: value);

  /// Adds the reviewed questions to the exam, all or none. Nothing is added while the review is blocked.
  Future<Result<Exam>> confirm(String examId) async {
    if (ImportReview.blockOf(state.drafts) != null) {
      return const Err(ValidationFailure(code: 'import_blocked', message: 'The review is not finished.'));
    }
    return ref.read(examRepositoryProvider).addQuestions(examId, ImportReview.build(state.drafts));
  }
}

/// The import in progress. Disposed when the screen closes, so nothing from a file lingers.
final importSessionProvider = NotifierProvider.autoDispose<ImportSessionController, ImportSessionState>(
  ImportSessionController.new,
);
