using System.Runtime.CompilerServices;
using ExamProctoring.Application.Abstractions;
using ExamProctoring.Application.Exams;
using ExamProctoring.Application.Exams.Import;
using Microsoft.Extensions.Logging.Abstractions;

namespace ExamProctoring.UnitTests.Exams.Import;

// One MCQ type for single- and multiple-answer questions ("Correct Answer: B" or "Correct Answer: A, C"), the "[MCQ]" and
// "[Short]" markers, and old documents that still carry Difficulty and Topic lines.
public sealed class MultipleAnswerImportTests
{
    private static ParsedQuestionDocument Parse(params string[] lines) =>
        QuestionDocumentParser.Parse(lines.Select((text, index) => new SourceLine(index + 1, text)).ToList(), maxOptions: 8);

    private static string[] Errors(ImportedQuestion q) => q.Issues.Where(i => i.Severity == ImportSeverity.Error).Select(i => i.Code).ToArray();

    private static string[] Mcq(string answer, params string[] extra) =>
    [
        "Question 1 [MCQ]", "Which are prime?", "A. 2", "B. 4", "C. 5", "D. 9", $"Correct Answer: {answer}", .. extra, "Marks: 2",
    ];

    private static bool[] Correct(ImportedQuestion q) => [.. q.Options.Select(o => o.IsCorrect)];

    private static string SourceDirectory([CallerFilePath] string path = "") => Path.GetDirectoryName(path)!;

    private sealed class Settings : IExamSettings
    {
        public int WarningLimit => 20;
        public int MaxMcqOptions => 8;
    }

    private sealed class Caller : ICurrentUser
    {
        public Guid UserId => Guid.Parse("11111111-1111-1111-1111-111111111111");
        public string Role => "Instructor";
        public string SecurityStamp => "stamp";
    }

    // ---- Correct answers ----

    [Fact]
    public void ASingleAnswer_IsStillOneCorrectOption()
    {
        var q = Assert.Single(Parse(Mcq("C")).Questions);

        Assert.Equal("Mcq", q.Type);
        Assert.Equal([false, false, true, false], Correct(q));
        Assert.Empty(q.Issues);
    }

    [Theory]
    [InlineData("A, C")]
    [InlineData("A,C")]
    [InlineData("A,  C")]
    [InlineData("  A ,   C  ")]
    [InlineData("a, c")]
    public void SeveralAnswers_AreTrimmed_AndStayTheSameMcqType(string answer)
    {
        var q = Assert.Single(Parse(Mcq(answer)).Questions);

        Assert.Equal("Mcq", q.Type);
        Assert.Equal([true, false, true, false], Correct(q));
        Assert.Empty(q.Issues);
        Assert.Equal(2m, q.Marks);
    }

    [Fact]
    public void SeveralAnswers_CanBeGivenAsOptionText()
    {
        var q = Assert.Single(Parse(Mcq("2, 5")).Questions);

        Assert.Equal([true, false, true, false], Correct(q));
    }

    [Fact]
    public void SeveralMarkedOptions_AreSeveralCorrectAnswers()
    {
        var q = Assert.Single(Parse("Question 1 [MCQ]", "Which?", "*A. a", "B. b", "*C. c", "Marks: 1").Questions);

        Assert.Equal([true, false, true], Correct(q));
        Assert.Empty(Errors(q));
    }

    [Fact]
    public void MarkedOptions_ThatDisagreeWithTheAnswerLine_AreReported_NotMerged()
    {
        var q = Assert.Single(Parse("Question 1 [MCQ]", "Which?", "*A. a", "B. b", "C. c", "Correct Answer: A, C", "Marks: 1").Questions);

        Assert.Contains(ImportIssueCodes.MultipleCorrectAnswers, Errors(q));
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Theory]
    [InlineData("A, E", "E")]
    [InlineData("A, Z", "Z")]
    [InlineData("E", "E")]
    public void AnAnswerThatMatchesNoOption_IsReported_AndNothingIsMarked(string answer, string offending)
    {
        var q = Assert.Single(Parse(Mcq(answer)).Questions);

        var error = Assert.Single(q.Issues, i => i.Code == ImportIssueCodes.CorrectAnswerInvalid);
        Assert.Contains($"\"{offending}\"", error.Message);
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Theory]
    [InlineData("A, A")]
    [InlineData("A, C, a")]
    public void ADuplicateAnswer_IsReported(string answer)
    {
        var q = Assert.Single(Parse(Mcq(answer)).Questions);

        Assert.Contains(ImportIssueCodes.DuplicateCorrectAnswer, Errors(q));
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Theory]
    [InlineData("A,,C")]
    [InlineData("A, C,")]
    [InlineData(",A")]
    public void AnEmptyEntry_IsReported(string answer)
    {
        var q = Assert.Single(Parse(Mcq(answer)).Questions);

        Assert.Contains(ImportIssueCodes.CorrectAnswerInvalid, Errors(q));
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Fact]
    public void ANeverGivenAnswer_IsReported_AndNothingIsInferred()
    {
        var q = Assert.Single(Parse("Question 1 [MCQ]", "Which?", "A. a", "B. b", "Marks: 1").Questions);

        Assert.Contains(ImportIssueCodes.CorrectAnswerMissing, Errors(q));
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Fact]
    public void TwoAnswerLines_AreStillRefused_NotMergedIntoTwoAnswers()
    {
        var q = Assert.Single(Parse("Question 1 [MCQ]", "Which?", "A. a", "B. b", "Correct Answer: A", "Correct Answer: B", "Marks: 1").Questions);

        Assert.Contains(ImportIssueCodes.MultipleCorrectAnswers, Errors(q));
        Assert.All(q.Options, o => Assert.False(o.IsCorrect));
    }

    [Fact]
    public void AnOptionTextThatContainsACommaIsStillOneOption()
    {
        var q = Assert.Single(Parse("Question 1 [MCQ]", "Capital?", "A. Paris, France", "B. Lyon, France", "Correct Answer: Paris, France", "Marks: 1").Questions);

        Assert.Equal([true, false], Correct(q));
        Assert.Empty(Errors(q));
    }

    // ---- "[MCQ]" and "[Short]" ----

    [Fact]
    public void TheBracketMarkers_SetTheType_AndAreNotPartOfTheQuestionText()
    {
        var result = Parse(
            "Question 1 [MCQ]", "Pick one?", "A. x", "B. y", "Correct Answer: B", "Marks: 1",
            "Question 2 [Short]", "Explain recursion.", "Model Answer: A function that calls itself.", "Marks: 5");

        Assert.Equal(["Mcq", "Essay"], result.Questions.Select(q => q.Type));
        Assert.Equal("Pick one?", result.Questions[0].Text);
        Assert.Equal("Explain recursion.", result.Questions[1].Text);
        Assert.Equal("A function that calls itself.", result.Questions[1].ModelAnswer);
        Assert.Equal(5m, result.Questions[1].Marks);
        Assert.Empty(result.Questions[1].Options);
        Assert.All(result.Questions, q => Assert.Empty(q.Issues));
    }

    [Fact]
    public void AMultipleMarker_IsNotAnotherType_AndStaysPartOfTheText()
    {
        var q = Assert.Single(Parse("Question 1 [Multiple]", "Pick?", "A. x", "B. y", "Correct Answer: A", "Marks: 1").Questions);

        Assert.Equal("Mcq", q.Type);
        Assert.StartsWith("[Multiple]", q.Text);
    }

    // ---- Difficulty and Topic (old documents) ----

    [Fact]
    public void DifficultyAndTopic_AreIgnored_WithoutWarnings_AndNeverAttachedToAnythingElse()
    {
        var result = Parse(
            "Question 1 [MCQ]", "Which layer routes packets?", "A. Physical", "B. Network", "C. Transport", "Correct Answer: B", "Marks: 1",
            "Difficulty: Easy", "Topic: Networking",
            "Question 2 [Short]", "Explain recursion.", "Model Answer: A function that calls itself.", "Marks: 5",
            "Difficulty: Medium", "Topic: Programming");

        Assert.Empty(result.Issues);
        Assert.All(result.Questions, q => Assert.Empty(q.Issues));
        Assert.Equal("Which layer routes packets?", result.Questions[0].Text);
        Assert.Equal("Network", result.Questions[0].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal("A function that calls itself.", result.Questions[1].ModelAnswer); // not "... Difficulty: Medium"
        Assert.Equal(5m, result.Questions[1].Marks);
    }

    [Theory]
    [InlineData("Difficulty: Hard", "Topic: Sorting")]
    [InlineData("DIFFICULTY : Hard", "topic = Sorting")]
    [InlineData("الصعوبة: صعب", "الموضوع: الفرز")]
    public void DifficultyAndTopic_AreIgnoredInAnyPlace_AndInArabic(string difficulty, string topic)
    {
        var result = Parse([difficulty, topic, .. Mcq("A", difficulty, topic)]);

        Assert.Empty(result.Issues);
        var q = Assert.Single(result.Questions);
        Assert.Empty(q.Issues);
        Assert.Equal([true, false, false, false], Correct(q));
    }

    // ---- The real file, through preview ----

    [Fact]
    public async Task TheCleanedTemplate_IsRecognised_With6McqAnd3Short_AndTheMultipleAnswersAreKept()
    {
        var path = Path.Combine(SourceDirectory(), "Fixtures", "Examora_Custom_Import_Template_Clean.docx");
        var settings = new Settings();
        var service = new QuestionImportService(new QuestionRequestValidator(settings), settings, new Caller(), NullLogger<QuestionImportService>.Instance);
        var bytes = await File.ReadAllBytesAsync(path);

        var result = await service.PreviewAsync(new MemoryStream(bytes), "Examora_Custom_Import_Template_Clean.docx", bytes.Length, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var preview = result.Value!;
        var all = preview.Questions.SelectMany(q => q.Issues).Concat(preview.Issues).ToList();
        Assert.True(preview.IsValid, string.Join("; ", all.Select(i => i.Message)));
        Assert.Empty(all); // no warnings at all
        Assert.Equal("Midterm Examination - Computer Science 101", preview.ExamTitle);
        Assert.Equal(9, preview.Questions.Count);
        Assert.Equal(Enumerable.Range(1, 9), preview.Questions.Select(q => q.Number));
        Assert.Equal(["Mcq", "Mcq", "Mcq", "Mcq", "Mcq", "Mcq", "Essay", "Essay", "Essay"], preview.Questions.Select(q => q.Type));

        // Single answer: Questions 1 to 3 (B).
        foreach (var index in new[] { 0, 1, 2 })
        {
            Assert.Equal([false, true, false, false], preview.Questions[index].Options.Select(o => o.IsCorrect));
            Assert.Equal(1m, preview.Questions[index].Marks);
        }

        // Several answers: Questions 4 to 6, "A, C" / "A, B" / "A, C".
        Assert.Equal([true, false, true, false], preview.Questions[3].Options.Select(o => o.IsCorrect));
        Assert.Equal([true, true, false, false], preview.Questions[4].Options.Select(o => o.IsCorrect));
        Assert.Equal([true, false, true, false], preview.Questions[5].Options.Select(o => o.IsCorrect));
        Assert.Equal(["2", "5"], preview.Questions[3].Options.Where(o => o.IsCorrect).Select(o => o.Text));
        Assert.Equal(["MongoDB", "Cassandra"], preview.Questions[5].Options.Where(o => o.IsCorrect).Select(o => o.Text));
        Assert.All(new[] { 3, 4, 5 }, i => Assert.Equal(2m, preview.Questions[i].Marks));

        // Short questions: text, model answer and marks, no options.
        foreach (var index in new[] { 6, 7, 8 })
        {
            var q = preview.Questions[index];
            Assert.Empty(q.Options);
            Assert.False(string.IsNullOrWhiteSpace(q.ModelAnswer));
            Assert.Equal(5m, q.Marks);
        }

        Assert.Equal("Explain in your own words what recursion is.", preview.Questions[6].Text);
        Assert.StartsWith("A function that solves a problem by calling itself", preview.Questions[6].ModelAnswer);
    }

    [Fact]
    public async Task TheMultipleAnswers_SurviveTheWholePath_IntoTheRequestsThatAreSaved()
    {
        // The confirm step saves exactly the questions the preview returned (QuestionRequest per question). Building those
        // requests from the preview keeps every correct option, and the validator accepts them.
        var path = Path.Combine(SourceDirectory(), "Fixtures", "Examora_Custom_Import_Template_Clean.docx");
        var settings = new Settings();
        var validator = new QuestionRequestValidator(settings);
        var service = new QuestionImportService(validator, settings, new Caller(), NullLogger<QuestionImportService>.Instance);
        var bytes = await File.ReadAllBytesAsync(path);
        var preview = (await service.PreviewAsync(new MemoryStream(bytes), "t.docx", bytes.Length, CancellationToken.None)).Value!;

        foreach (var q in preview.Questions)
        {
            var request = new QuestionRequest(
                q.Type, q.Text, q.Marks, q.ModelAnswer,
                q.Options.Count == 0 ? [] : [.. q.Options.Select(o => (QuestionOptionRequest?)new QuestionOptionRequest(o.Text, o.IsCorrect))]);
            var verdict = await validator.ValidateAsync(request);
            Assert.True(verdict.IsValid, string.Join("; ", verdict.Errors.Select(e => e.ErrorMessage)));
            Assert.Equal(q.Options.Count(o => o.IsCorrect), request.Options?.Count(o => o!.IsCorrect == true) ?? 0);
        }
    }
}
