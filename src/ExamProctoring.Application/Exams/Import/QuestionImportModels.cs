namespace ExamProctoring.Application.Exams.Import;

// Fixed limits and defaults of the Word import. The format itself is documented in docs/Word_Import_Format.md.
public static class QuestionImportLimits
{
    // The uploaded .docx (the request may carry a little more for the multipart framing).
    public const long MaxFileBytes = 10 * 1024 * 1024;

    public const long MaxRequestBytes = MaxFileBytes + 1024 * 1024;

    // Questions per import, in the preview and in the confirmation.
    public const int MaxQuestions = 200;

    // Marks of a question whose "Points:" line is missing. The exam model has no default; this is the one the manual
    // question form also starts with.
    public const decimal DefaultMarks = 1m;
}

public static class ImportSeverity
{
    public const string Error = "error";
    public const string Warning = "warning";
}

// A problem found in the document. Code is stable (the frontend translates it); Message is the English text. Question is the
// question's number as written in the document, Line is the line's position among the document's non-empty lines.
public sealed record ImportIssue(string Code, string Severity, string Message, int? Question, int? Line);

public static class ImportIssueCodes
{
    public const string TextOutsideQuestion = "text_outside_question";
    public const string DuplicateTitle = "duplicate_title";
    public const string NoQuestions = "no_questions";
    public const string TooManyQuestions = "too_many_questions";
    public const string DuplicateQuestionNumber = "duplicate_question_number";
    public const string QuestionTextMissing = "question_text_missing";
    public const string UnknownType = "unknown_type";
    public const string DuplicateType = "duplicate_type";
    public const string OptionsMissing = "options_missing";
    public const string TooManyOptions = "too_many_options";
    public const string DuplicateOptionLabel = "duplicate_option_label";
    public const string OptionLabelsOutOfOrder = "option_labels_out_of_order";
    public const string OptionTextMissing = "option_text_missing";
    public const string CorrectAnswerMissing = "correct_answer_missing";
    public const string CorrectAnswerInvalid = "correct_answer_invalid";
    public const string MultipleCorrectAnswers = "multiple_correct_answers";
    public const string PointsInvalid = "points_invalid";
    public const string DuplicatePoints = "duplicate_points";
    public const string DuplicateModelAnswer = "duplicate_model_answer";
    public const string EssayHasOptions = "essay_has_options";
    public const string EssayHasAnswer = "essay_has_answer";
    public const string UnexpectedLine = "unexpected_line";
    public const string InferredEssay = "inferred_essay";
    public const string Validation = "validation";
}

// One option of a question found in the document. Label is the letter as normalized (A, B, C ...).
public sealed record ImportedOption(string Label, string Text, bool IsCorrect);

// A question as read from the document. Nothing is guessed: a question without a correct answer has no option marked
// correct and carries a "correct_answer_missing" issue. Marks is DefaultMarks when the document gave none (MarksDefaulted).
public sealed record ImportedQuestion(
    int Number,
    int Line,
    string Type,
    string Text,
    decimal Marks,
    bool MarksDefaulted,
    string? ModelAnswer,
    IReadOnlyList<ImportedOption> Options,
    IReadOnlyList<ImportIssue> Issues);

// POST /api/questions/import/preview. Nothing is saved. IsValid is true when there is at least one question and no issue
// has severity "error". Issues holds the problems that belong to the document as a whole.
public sealed record QuestionImportPreviewResponse(
    string? ExamTitle,
    decimal DefaultMarks,
    int MaxOptions,
    bool IsValid,
    IReadOnlyList<ImportedQuestion> Questions,
    IReadOnlyList<ImportIssue> Issues);

// POST /api/exams/{examId}/questions/import: the reviewed questions, in the same shape as POST /api/exams/{id}/questions.
public sealed record QuestionImportRequest(IReadOnlyList<QuestionRequest?>? Questions);
