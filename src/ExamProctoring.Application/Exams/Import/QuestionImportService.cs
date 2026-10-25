using ExamProctoring.Application.Abstractions;
using ExamProctoring.Application.Common;
using FluentValidation;
using Microsoft.Extensions.Logging;

namespace ExamProctoring.Application.Exams.Import;

// Step 1 of the Word import: reads an uploaded .docx and returns what it contains, for review. Nothing is saved and no exam
// is touched (saving is QuestionService.ImportAsync, after the instructor has reviewed and possibly corrected the questions).
public sealed class QuestionImportService(
    IValidator<QuestionRequest> questionValidator,
    IExamSettings settings,
    ICurrentUser currentUser,
    ILogger<QuestionImportService> logger)
{
    private static readonly byte[] ZipSignature = [0x50, 0x4B, 0x03, 0x04];

    // POST /api/questions/import/preview. fileName and length come from the upload; content is read once.
    public async Task<Result<QuestionImportPreviewResponse>> PreviewAsync(
        Stream? content, string? fileName, long length, CancellationToken cancellationToken)
    {
        if (content is null || string.IsNullOrWhiteSpace(fileName))
            return Invalid("A .docx file is required.");
        if (length == 0)
            return Invalid("The file is empty.");
        if (length > QuestionImportLimits.MaxFileBytes)
            return Invalid("The file is larger than 10 MB.");
        if (!string.Equals(Path.GetExtension(fileName), ".docx", StringComparison.OrdinalIgnoreCase))
            return Invalid("Only .docx files are supported.");

        // The content is checked, not just the name: a .docx is a zip archive and starts with "PK\u0003\u0004".
        var header = new byte[ZipSignature.Length];
        var read = await content.ReadAtLeastAsync(header, header.Length, throwOnEndOfStream: false, cancellationToken);
        if (read < header.Length || !header.AsSpan().SequenceEqual(ZipSignature))
            return Invalid("The file is not a valid Word (.docx) document.");
        content.Seek(0, SeekOrigin.Begin);

        var extraction = DocxTextExtractor.Extract(content);
        if (!extraction.IsSuccess)
            return Invalid(extraction.Failure!);

        var parsed = QuestionDocumentParser.Parse(extraction.Lines!, settings.MaxMcqOptions);
        var questions = new List<ImportedQuestion>(parsed.Questions.Count);
        foreach (var question in parsed.Questions)
            questions.Add(await CheckWithQuestionRulesAsync(question, cancellationToken));

        var isValid = questions.Count > 0
            && parsed.Issues.All(i => i.Severity != ImportSeverity.Error)
            && questions.All(q => q.Issues.All(i => i.Severity != ImportSeverity.Error));

        logger.LogInformation("Instructor {InstructorId} previewed a Word import: {Questions} questions, valid: {IsValid}.",
            currentUser.UserId, questions.Count, isValid);

        return Result<QuestionImportPreviewResponse>.Success(new QuestionImportPreviewResponse(
            parsed.ExamTitle, QuestionImportLimits.DefaultMarks, settings.MaxMcqOptions, isValid, questions, parsed.Issues));
    }

    // A question the parser accepted structurally must also satisfy the rules of the manual question form (text and option
    // lengths, marks range and decimals, distinct option texts). They are applied here, so the preview already shows what the
    // confirmation would refuse. A question that already has parser errors is not checked again: its errors are the cause.
    private async Task<ImportedQuestion> CheckWithQuestionRulesAsync(ImportedQuestion question, CancellationToken cancellationToken)
    {
        if (question.Issues.Any(i => i.Severity == ImportSeverity.Error))
            return question;

        var request = new QuestionRequest(
            question.Type,
            question.Text,
            question.Marks,
            question.ModelAnswer,
            question.Options.Select(o => (QuestionOptionRequest?)new QuestionOptionRequest(o.Text, o.IsCorrect)).ToList());

        var result = await questionValidator.ValidateAsync(request, cancellationToken);
        if (result.IsValid)
            return question;

        var issues = question.Issues.ToList();
        foreach (var message in result.Errors.Select(e => e.ErrorMessage).Distinct())
            issues.Add(new ImportIssue(ImportIssueCodes.Validation, ImportSeverity.Error, $"Question {question.Number}: {message}", question.Number, question.Line));
        return question with { Issues = issues };
    }

    // File-level failure: 400 validation_failed on the "file" field.
    private static Result<QuestionImportPreviewResponse> Invalid(string message) =>
        Result<QuestionImportPreviewResponse>.Failure(new AppError(
            ErrorCodes.ValidationFailed,
            "One or more fields are invalid.",
            new Dictionary<string, string[]> { ["file"] = [message] }));
}
