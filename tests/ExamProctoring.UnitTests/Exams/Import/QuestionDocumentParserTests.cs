using ExamProctoring.Application.Exams.Import;

namespace ExamProctoring.UnitTests.Exams.Import;

// The documented question format (docs/Word_Import_Format.md): what is read, what is defaulted, and what is reported instead
// of guessed.
public sealed class QuestionDocumentParserTests
{
    private static ParsedQuestionDocument Parse(params string[] lines) =>
        QuestionDocumentParser.Parse(lines.Select((text, index) => new SourceLine(index + 1, text)).ToList(), maxOptions: 8);

    private static string[] Codes(ImportedQuestion question) => question.Issues.Select(i => i.Code).ToArray();

    private static readonly string[] Sample =
    [
        "Exam Title: Introduction to Computer Science",
        "Question 1: What does CPU stand for?",
        "A) Central Processing Unit",
        "B) Computer Personal Unit",
        "C) Central Program Utility",
        "D) Control Processing User",
        "Correct Answer: A",
        "Points: 2",
        "Question 2: Which of the following is a programming language?",
        "A) HTML",
        "B) Python",
        "C) HTTP",
        "D) SQL Server",
        "Correct Answer: B",
        "Points: 1",
    ];

    // ---- The documented example ----

    [Fact]
    public void TheDocumentedExample_IsReadCompletely()
    {
        var result = Parse(Sample);

        Assert.Equal("Introduction to Computer Science", result.ExamTitle);
        Assert.Empty(result.Issues);
        Assert.Equal(2, result.Questions.Count);

        var first = result.Questions[0];
        Assert.Equal(1, first.Number);
        Assert.Equal("Mcq", first.Type);
        Assert.Equal("What does CPU stand for?", first.Text);
        Assert.Equal(2m, first.Marks);
        Assert.False(first.MarksDefaulted);
        Assert.Empty(first.Issues);
        Assert.Equal(["A", "B", "C", "D"], first.Options.Select(o => o.Label));
        Assert.Equal(["Central Processing Unit", "Computer Personal Unit", "Central Program Utility", "Control Processing User"], first.Options.Select(o => o.Text));
        Assert.Equal([true, false, false, false], first.Options.Select(o => o.IsCorrect));

        var second = result.Questions[1];
        Assert.Equal("Python", second.Options.Single(o => o.IsCorrect).Text);
        Assert.Equal(1m, second.Marks);
    }

    [Fact]
    public void PointsAreOptional_AndTheDefaultIsMarked()
    {
        var result = Parse("Question 1: Q?", "A) x", "B) y", "Correct Answer: B");

        var question = Assert.Single(result.Questions);
        Assert.Empty(question.Issues);
        Assert.Equal(QuestionImportLimits.DefaultMarks, question.Marks);
        Assert.True(question.MarksDefaulted);
    }

    [Theory]
    [InlineData("Points: 2.5", 2.5)]
    [InlineData("points: 3", 3)]
    [InlineData("Marks: 1,5", 1.5)]
    [InlineData("Score: ١٢", 12)]
    [InlineData("الدرجة: ٢", 2)]
    [InlineData("النقاط: 0.25", 0.25)]
    public void PointsKeywordsAndNumbers_AreUnderstood(string line, double expected)
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y", "Correct Answer: A", line).Questions);

        Assert.Empty(question.Issues);
        Assert.Equal((decimal)expected, question.Marks);
    }

    // ---- Labels, keywords and spelling variants ----

    [Theory]
    [InlineData("A) text")]
    [InlineData("A. text")]
    [InlineData("A: text")]
    [InlineData("A- text")]
    [InlineData("(A) text")]
    [InlineData("a) text")]
    public void OptionLabelStyles_AreAllUnderstood(string option)
    {
        var question = Assert.Single(Parse("Question 1: Q?", option, "B) other", "Correct Answer: A").Questions);

        Assert.Empty(question.Issues);
        Assert.Equal("text", question.Options[0].Text);
        Assert.True(question.Options[0].IsCorrect);
    }

    [Fact]
    public void QuestionLabelVariants_AreUnderstood()
    {
        var result = Parse("Q1: One?", "A) a", "B) b", "Correct Answer: A", "q 2. Two?", "A) a", "B) b", "Correct Answer: B");

        Assert.Equal([1, 2], result.Questions.Select(q => q.Number));
        Assert.Equal(["One?", "Two?"], result.Questions.Select(q => q.Text));
    }

    [Fact]
    public void ALineLikeB52_IsTextNotAnOption()
    {
        var question = Assert.Single(Parse("Question 1: Which plane?", "B-52 is a bomber.", "A) one", "B) two", "Correct Answer: A").Questions);

        Assert.Equal("Which plane?\nB-52 is a bomber.", question.Text);
        Assert.Equal(2, question.Options.Count);
    }

    [Fact]
    public void TextContinuesOnTheNextLines_ForQuestionAndOptions()
    {
        var question = Assert.Single(Parse(
            "Question 1: First line", "second line", "A) Option one", "continues here", "B) Option two", "Correct Answer: B").Questions);

        Assert.Equal("First line\nsecond line", question.Text);
        Assert.Equal("Option one continues here", question.Options[0].Text);
        Assert.Empty(question.Issues);
    }

    [Fact]
    public void QuestionTextMayStartOnTheNextLine()
    {
        var question = Assert.Single(Parse("Question 1:", "What is 2 + 2?", "A) 3", "B) 4", "Correct Answer: B").Questions);

        Assert.Equal("What is 2 + 2?", question.Text);
        Assert.Empty(question.Issues);
    }

    // ---- Arabic and mixed text ----

    [Fact]
    public void ArabicDocument_IsReadWithArabicKeywordsLettersAndDigits()
    {
        var result = Parse(
            "عنوان الامتحان: مقدمة في علوم الحاسب",
            "السؤال ١: ما هي عاصمة فرنسا؟",
            "أ) لندن",
            "ب) باريس",
            "ج) برلين",
            "د) روما",
            "الإجابة الصحيحة: ب",
            "الدرجة: ٢");

        Assert.Equal("مقدمة في علوم الحاسب", result.ExamTitle);
        var question = Assert.Single(result.Questions);
        Assert.Empty(question.Issues);
        Assert.Equal(1, question.Number);
        Assert.Equal("ما هي عاصمة فرنسا؟", question.Text);
        Assert.Equal(["A", "B", "C", "D"], question.Options.Select(o => o.Label));
        Assert.Equal(["لندن", "باريس", "برلين", "روما"], question.Options.Select(o => o.Text));
        Assert.Equal("باريس", question.Options.Single(o => o.IsCorrect).Text);
        Assert.Equal(2m, question.Marks);
    }

    [Fact]
    public void MixedArabicAndEnglish_KeepsEveryCharacter_AndIgnoresInvisibleDirectionMarks()
    {
        var text = "ما هو معنى \"CPU\" في (الحاسوب)؟";
        var result = Parse("‏Question 1: " + text + "‏", "‏أ) Central Processing Unit — وحدة المعالجة‏", "B) لا شيء", "Correct Answer: ‏أ");

        var question = Assert.Single(result.Questions);
        Assert.Empty(question.Issues);
        Assert.Equal(text, question.Text);
        Assert.Equal("Central Processing Unit — وحدة المعالجة", question.Options[0].Text);
        Assert.True(question.Options[0].IsCorrect);
    }

    // ---- Essay questions ----

    [Fact]
    public void AnEssayQuestion_IsKeptAsAnEssay_WithItsModelAnswer()
    {
        var question = Assert.Single(Parse(
            "Question 1: Explain photosynthesis.", "Type: Essay", "Points: 10", "Model Answer: Plants turn light", "into sugar.").Questions);

        Assert.Empty(question.Issues);
        Assert.Equal("Essay", question.Type);
        Assert.Empty(question.Options);
        Assert.Equal("Plants turn light\ninto sugar.", question.ModelAnswer);
        Assert.Equal(10m, question.Marks);
    }

    [Fact]
    public void AnArabicEssayType_IsUnderstood()
    {
        var question = Assert.Single(Parse("السؤال 1: اشرح.", "النوع: مقالي").Questions);

        Assert.Equal("Essay", question.Type);
        Assert.Empty(question.Issues);
    }

    [Fact]
    public void AQuestionWithoutOptionsOrAnAnswer_IsImportedAsAnEssay_ButFlaggedForReview()
    {
        // Changed on purpose (natural documents): an option-less question is an essay, with a visible warning.
        var question = Assert.Single(Parse("Question 1: Just text").Questions);

        Assert.Equal("Essay", question.Type);
        Assert.Equal([ImportIssueCodes.InferredEssay], Codes(question));
        Assert.Equal(ImportSeverity.Warning, question.Issues[0].Severity);
    }

    [Fact]
    public void AnEssayWithOptionsOrACorrectAnswer_IsReported()
    {
        var question = Assert.Single(Parse("Question 1: Essay?", "Type: Essay", "A) x", "Correct Answer: A").Questions);

        Assert.Contains(ImportIssueCodes.EssayHasOptions, Codes(question));
        Assert.Contains(ImportIssueCodes.EssayHasAnswer, Codes(question));
    }

    // ---- Problems are reported, never guessed ----

    [Fact]
    public void AMissingCorrectAnswer_IsReported_AndNoOptionIsMarkedCorrect()
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y").Questions);

        Assert.Equal([ImportIssueCodes.CorrectAnswerMissing], Codes(question));
        Assert.All(question.Options, o => Assert.False(o.IsCorrect));
        Assert.Equal(1, question.Issues[0].Question);
        Assert.Contains("Question 1", question.Issues[0].Message);
    }

    [Theory]
    [InlineData("Correct Answer: E", ImportIssueCodes.CorrectAnswerInvalid)]
    [InlineData("Correct Answer: Paris", ImportIssueCodes.CorrectAnswerInvalid)]
    [InlineData("Correct Answer: A, B", ImportIssueCodes.CorrectAnswerInvalid)]
    [InlineData("Correct Answer: ", ImportIssueCodes.CorrectAnswerInvalid)]
    public void AnInvalidCorrectAnswer_IsReported(string answer, string code)
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y", answer).Questions);

        Assert.Contains(code, Codes(question));
        Assert.All(question.Options, o => Assert.False(o.IsCorrect));
    }

    [Fact]
    public void TwoCorrectAnswerLines_AreReportedOnce_AndTheFirstIsNotTrusted()
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y", "Correct Answer: A", "Correct Answer: B", "Answer: A").Questions);

        Assert.Equal(1, Codes(question).Count(c => c == ImportIssueCodes.MultipleCorrectAnswers));
    }

    [Fact]
    public void DuplicateAndOutOfOrderOptionLabels_AreReported()
    {
        var duplicate = Assert.Single(Parse("Question 1: Q?", "A) x", "A) y", "Correct Answer: A").Questions);
        var outOfOrder = Assert.Single(Parse("Question 1: Q?", "A) x", "C) y", "Correct Answer: A").Questions);

        Assert.Contains(ImportIssueCodes.DuplicateOptionLabel, Codes(duplicate));
        Assert.DoesNotContain(ImportIssueCodes.OptionLabelsOutOfOrder, Codes(duplicate));
        Assert.Contains(ImportIssueCodes.OptionLabelsOutOfOrder, Codes(outOfOrder));
    }

    [Fact]
    public void TooFewOrTooManyOptions_AreReported()
    {
        var one = Assert.Single(Parse("Question 1: Q?", "A) x", "Correct Answer: A").Questions);
        var nine = Assert.Single(QuestionDocumentParser.Parse(
            new[] { "Question 1: Q?" }
                .Concat("ABCDEFGHI".Select(letter => $"{letter}) option {letter}"))
                .Append("Correct Answer: A")
                .Select((text, index) => new SourceLine(index + 1, text)).ToList(), maxOptions: 8).Questions);

        Assert.Contains(ImportIssueCodes.OptionsMissing, Codes(one));
        Assert.Contains(ImportIssueCodes.TooManyOptions, Codes(nine));
    }

    [Fact]
    public void AnOptionWithoutText_IsReported()
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A)", "B) y", "Correct Answer: B").Questions);

        Assert.Contains(ImportIssueCodes.OptionTextMissing, Codes(question));
    }

    [Fact]
    public void AMissingQuestionText_IsReported()
    {
        var question = Assert.Single(Parse("Question 1:", "A) x", "B) y", "Correct Answer: A").Questions);

        Assert.Contains(ImportIssueCodes.QuestionTextMissing, Codes(question));
    }

    [Theory]
    [InlineData("Points: abc")]
    [InlineData("Points: 1.2.3")]
    [InlineData("Points: -")]
    [InlineData("Points:")]
    public void InvalidPoints_AreReported_NotReplacedSilently(string line)
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y", "Correct Answer: A", line).Questions);

        Assert.Contains(ImportIssueCodes.PointsInvalid, Codes(question));
    }

    [Fact]
    public void ADuplicateQuestionNumber_IsReported()
    {
        var result = Parse("Question 1: One?", "A) a", "B) b", "Correct Answer: A", "Question 1: Two?", "A) a", "B) b", "Correct Answer: A");

        Assert.Equal(2, result.Questions.Count);
        Assert.DoesNotContain(ImportIssueCodes.DuplicateQuestionNumber, Codes(result.Questions[0]));
        Assert.Contains(ImportIssueCodes.DuplicateQuestionNumber, Codes(result.Questions[1]));
    }

    [Fact]
    public void ALineThatBelongsNowhere_IsReported_NotDropped()
    {
        var question = Assert.Single(Parse("Question 1: Q?", "A) x", "B) y", "Correct Answer: A", "stray words").Questions);

        Assert.Contains(ImportIssueCodes.UnexpectedLine, Codes(question));
        Assert.Contains("stray words", question.Issues.Single(i => i.Code == ImportIssueCodes.UnexpectedLine).Message);
    }

    [Fact]
    public void AnUnknownType_IsReported()
    {
        var question = Assert.Single(Parse("Question 1: Q?", "Type: True/False", "A) x", "B) y", "Correct Answer: A").Questions);

        Assert.Contains(ImportIssueCodes.UnknownType, Codes(question));
    }

    [Fact]
    public void TextBeforeTheFirstQuestion_IsAWarning_NotAnError_AndTheFirstLineIsTheTitle()
    {
        var result = Parse("Midterm exam - Spring", "Read the instructions carefully", "Question 1: Q?", "A) x", "B) y", "Correct Answer: A");

        Assert.Equal("Midterm exam - Spring", result.ExamTitle);
        var issue = Assert.Single(result.Issues);
        Assert.Equal(ImportIssueCodes.TextOutsideQuestion, issue.Code);
        Assert.Equal(ImportSeverity.Warning, issue.Severity);
        Assert.Single(result.Questions);
    }

    [Fact]
    public void ADocumentWithoutQuestions_IsReported()
    {
        var result = Parse("Nothing to see", "here");

        Assert.Empty(result.Questions);
        Assert.Contains(result.Issues, i => i.Code == ImportIssueCodes.NoQuestions && i.Severity == ImportSeverity.Error);
    }

    [Fact]
    public void MoreQuestionsThanTheLimit_AreReported_AndOnlyTheLimitIsReturned()
    {
        var lines = Enumerable.Range(1, QuestionImportLimits.MaxQuestions + 1)
            .SelectMany(n => new[] { $"Question {n}: Q{n}?", "A) a", "B) b", "Correct Answer: A" })
            .ToArray();

        var result = Parse(lines);

        Assert.Equal(QuestionImportLimits.MaxQuestions, result.Questions.Count);
        Assert.Contains(result.Issues, i => i.Code == ImportIssueCodes.TooManyQuestions);
    }

    [Fact]
    public void QuestionsAreReturnedInDocumentOrder_WithTheirLineNumbers()
    {
        var result = Parse(Sample);

        Assert.Equal([2, 9], result.Questions.Select(q => q.Line));
    }
}
