using System.Runtime.CompilerServices;
using System.Text;
using ExamProctoring.Application.Abstractions;
using ExamProctoring.Application.Common;
using ExamProctoring.Application.Exams;
using ExamProctoring.Application.Exams.Import;
using Microsoft.Extensions.Logging.Abstractions;

namespace ExamProctoring.UnitTests.Exams.Import;

// The upload checks and the preview: file name, size, content, and the question rules applied on top of the parser.
public sealed class QuestionImportServiceTests
{
    private static readonly string[] ValidDocument =
    [
        "Exam Title: Sample", "Question 1: Capital of France?", "A) Paris", "B) Lyon", "Correct Answer: A", "Points: 2",
    ];

    private readonly QuestionImportService _service;

    public QuestionImportServiceTests()
    {
        var settings = new Settings(maxMcqOptions: 8);
        _service = new QuestionImportService(new QuestionRequestValidator(settings), settings, new Caller(), NullLogger<QuestionImportService>.Instance);
    }

    private Task<Result<QuestionImportPreviewResponse>> PreviewAsync(byte[] bytes, string fileName = "exam.docx", long? length = null)
    {
        var stream = new MemoryStream(bytes);
        return _service.PreviewAsync(stream, fileName, length ?? bytes.Length, CancellationToken.None);
    }

    private static string FileError(Result<QuestionImportPreviewResponse> result)
    {
        Assert.False(result.IsSuccess);
        Assert.Equal(ErrorCodes.ValidationFailed, result.Error!.Code);
        return Assert.Single(result.Error.FieldErrors!["file"]);
    }

    [Fact]
    public async Task AValidDocument_IsPreviewed_AsValid()
    {
        var result = await PreviewAsync(DocxBuilder.Build(ValidDocument));

        Assert.True(result.IsSuccess);
        var preview = result.Value!;
        Assert.True(preview.IsValid);
        Assert.Equal("Sample", preview.ExamTitle);
        Assert.Equal(8, preview.MaxOptions);
        var question = Assert.Single(preview.Questions);
        Assert.Equal("Capital of France?", question.Text);
        Assert.Equal(2m, question.Marks);
        Assert.Equal("Paris", question.Options.Single(o => o.IsCorrect).Text);
    }

    [Fact]
    public async Task ADocumentWithAnInvalidQuestion_IsPreviewed_NotValid_WithTheQuestionStillShown()
    {
        var result = await PreviewAsync(DocxBuilder.Build(["Question 1: Q?", "A) x", "B) y"]));

        Assert.True(result.IsSuccess);
        Assert.False(result.Value!.IsValid);
        var question = Assert.Single(result.Value.Questions);
        Assert.Equal("Q?", question.Text);
        Assert.Contains(question.Issues, i => i.Code == ImportIssueCodes.CorrectAnswerMissing);
    }

    [Fact]
    public async Task TheQuestionFormRules_AreAppliedToo_ForExampleMarksWithThreeDecimals()
    {
        var result = await PreviewAsync(DocxBuilder.Build(["Question 1: Q?", "A) x", "B) x", "Correct Answer: A", "Points: 1.005"]));

        var question = Assert.Single(result.Value!.Questions);
        Assert.False(result.Value.IsValid);
        Assert.Contains(question.Issues, i => i.Code == ImportIssueCodes.Validation && i.Message.Contains("2 decimal places"));
        Assert.Contains(question.Issues, i => i.Code == ImportIssueCodes.Validation && i.Message.Contains("repeat the same text"));
    }

    [Fact]
    public async Task ADocumentWithNoQuestions_IsNotValid()
    {
        var result = await PreviewAsync(DocxBuilder.Build(["Hello"]));

        Assert.False(result.Value!.IsValid);
        Assert.Empty(result.Value.Questions);
    }

    [Fact]
    public async Task ArabicContent_SurvivesThePreviewUnchanged()
    {
        var result = await PreviewAsync(DocxBuilder.Build(
            ["السؤال 1: ما هي عاصمة مصر؟", "أ) القاهرة", "ب) الإسكندرية", "الإجابة الصحيحة: أ", "الدرجة: 3"], rightToLeft: true));

        var question = Assert.Single(result.Value!.Questions);
        Assert.True(result.Value.IsValid);
        Assert.Equal("ما هي عاصمة مصر؟", question.Text);
        Assert.Equal(["القاهرة", "الإسكندرية"], question.Options.Select(o => o.Text));
        Assert.Equal(3m, question.Marks);
    }

    [Fact]
    public async Task NoFile_AnEmptyFile_AWrongExtension_AndAnOversizedFile_AreRejected()
    {
        Assert.Equal("A .docx file is required.", FileError(await _service.PreviewAsync(null, null, 0, CancellationToken.None)));
        Assert.Equal("The file is empty.", FileError(await PreviewAsync([], "exam.docx")));
        Assert.Equal("Only .docx files are supported.", FileError(await PreviewAsync(DocxBuilder.Build(ValidDocument), "exam.doc")));
        Assert.Equal("Only .docx files are supported.", FileError(await PreviewAsync(DocxBuilder.Build(ValidDocument), "exam.docx.exe")));
        Assert.Equal("The file is larger than 10 MB.", FileError(await PreviewAsync(DocxBuilder.Build(ValidDocument), length: QuestionImportLimits.MaxFileBytes + 1)));
    }

    [Fact]
    public async Task APlainTextFileRenamedToDocx_IsRejectedByItsContent()
    {
        Assert.Equal("The file is not a valid Word (.docx) document.", FileError(await PreviewAsync(Encoding.UTF8.GetBytes("Question 1: text"))));
    }

    [Fact]
    public async Task ACorruptedDocx_IsRejected_NotThrown()
    {
        var bytes = DocxBuilder.Build(ValidDocument);
        var truncated = bytes[..(bytes.Length / 2)];

        Assert.Equal("The file is not a valid Word (.docx) document.", FileError(await PreviewAsync(truncated)));
    }

    // The sample file offered for download in the dashboard (frontend/public) must itself be a valid import document.
    [Fact]
    public async Task TheDownloadableTemplate_IsAValidDocument_WithEnglishArabicAndEssayQuestions()
    {
        var path = Path.GetFullPath(Path.Combine(
            SourceDirectory(), "..", "..", "..", "..", "frontend", "public", "question-import-template.docx"));

        var result = await PreviewAsync(await File.ReadAllBytesAsync(path), "question-import-template.docx");

        Assert.True(result.IsSuccess);
        Assert.True(result.Value!.IsValid, string.Join("; ", result.Value.Questions.SelectMany(q => q.Issues).Concat(result.Value.Issues).Select(i => i.Message)));
        Assert.Empty(result.Value.Issues);
        Assert.Equal(["Mcq", "Mcq", "Mcq", "Essay"], result.Value.Questions.Select(q => q.Type));
        Assert.Equal("ما هي عاصمة فرنسا؟", result.Value.Questions[2].Text);
        Assert.Equal("باريس", result.Value.Questions[2].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal(5m, result.Value.Questions[3].Marks);
        Assert.NotNull(result.Value.Questions[3].ModelAnswer);
    }

    private static string SourceDirectory([CallerFilePath] string path = "") => Path.GetDirectoryName(path)!;

    private sealed class Settings(int maxMcqOptions) : IExamSettings
    {
        public int WarningLimit => 20;
        public int MaxMcqOptions => maxMcqOptions;
    }

    private sealed class Caller : ICurrentUser
    {
        public Guid UserId => Guid.Parse("11111111-1111-1111-1111-111111111111");
        public string Role => "Instructor";
        public string SecurityStamp => "stamp";
    }
}
