using System.Runtime.CompilerServices;
using ExamProctoring.Application.Abstractions;
using ExamProctoring.Application.Exams;
using ExamProctoring.Application.Exams.Import;
using Microsoft.Extensions.Logging.Abstractions;

namespace ExamProctoring.UnitTests.Exams.Import;

// Regression tests for ordinary, naturally written exam documents: section headings, "س12:" Arabic numbering, essay
// questions without a "Type:" line, trailing text, bare numbering, inline points, and other answer spellings.
// The fixture Fixtures/Examora_Word_Import_Test_Questions.docx is the sample file the first version failed on.
public sealed class NaturalDocumentTests
{
    private static ParsedQuestionDocument Parse(params string[] lines) =>
        QuestionDocumentParser.Parse(lines.Select((text, index) => new SourceLine(index + 1, text)).ToList(), maxOptions: 8);

    private static string[] Errors(ImportedQuestion question) =>
        question.Issues.Where(i => i.Severity == ImportSeverity.Error).Select(i => i.Code).ToArray();

    private static string[] Codes(ImportedQuestion question) => question.Issues.Select(i => i.Code).ToArray();

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

    // ---- The real sample file, through the whole upload path ----

    [Fact]
    public async Task TheSampleFile_IsPreviewedAsValid_With13QuestionsInTheRightShape()
    {
        var path = Path.Combine(SourceDirectory(), "Fixtures", "Examora_Word_Import_Test_Questions.docx");
        var settings = new Settings();
        var service = new QuestionImportService(new QuestionRequestValidator(settings), settings, new Caller(), NullLogger<QuestionImportService>.Instance);
        var bytes = await File.ReadAllBytesAsync(path);

        var result = await service.PreviewAsync(new MemoryStream(bytes), "Examora_Word_Import_Test_Questions.docx", bytes.Length, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var preview = result.Value!;
        var problems = string.Join("; ", preview.Questions.SelectMany(q => q.Issues).Concat(preview.Issues)
            .Where(i => i.Severity == ImportSeverity.Error).Select(i => i.Message));
        Assert.True(preview.IsValid, problems);
        Assert.Equal(13, preview.Questions.Count);
        Assert.Equal(Enumerable.Range(1, 13), preview.Questions.Select(q => q.Number));
        Assert.Equal(Enumerable.Repeat("Mcq", 10).Append("Essay").Concat(["Mcq", "Mcq"]), preview.Questions.Select(q => q.Type));

        // Q1 and Q10: ordinary English multiple choice.
        Assert.Equal("What does CPU stand for?", preview.Questions[0].Text);
        Assert.Equal("Central Processing Unit", preview.Questions[0].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal("PRIMARY KEY", preview.Questions[9].Options.Single(o => o.IsCorrect).Text);
        Assert.All(preview.Questions.Where(q => q.Type == "Mcq"), q => Assert.Equal(4, q.Options.Count));
        Assert.All(preview.Questions.Where(q => q.Type == "Mcq"), q => Assert.Single(q.Options, o => o.IsCorrect));

        // The section headings are not part of any question.
        Assert.DoesNotContain(preview.Questions, q => q.Text.Contains("Section", StringComparison.OrdinalIgnoreCase));
        Assert.DoesNotContain(preview.Questions.SelectMany(q => q.Options), o => o.Text.Contains("Section", StringComparison.OrdinalIgnoreCase));

        // Q11: the essay, with its model answer and 5 points; no options.
        var essay = preview.Questions[10];
        Assert.Equal("Explain the difference between a stack and a queue.", essay.Text);
        Assert.Empty(essay.Options);
        Assert.StartsWith("A stack follows Last In, First Out", essay.ModelAnswer);
        Assert.Equal(5m, essay.Marks);

        // Q12 and Q13: Arabic numbering "س12:", Arabic option labels, and an Arabic letter after "Correct Answer:".
        var arabic = preview.Questions[11];
        Assert.Equal("ما الوظيفة الأساسية لنظام إدارة قواعد البيانات؟", arabic.Text);
        Assert.Equal(["A", "B", "C", "D"], arabic.Options.Select(o => o.Label));
        Assert.Equal("تخزين البيانات وتنظيمها", arabic.Options.Single(o => o.IsCorrect).Text);
        var second = preview.Questions[12];
        Assert.Equal("أي من التالي يُستخدم لتنسيق صفحات الويب؟", second.Text);
        Assert.Equal("CSS", second.Options.Single(o => o.IsCorrect).Text);
        Assert.Equal("C#", second.Options[2].Text);

        // The last question does not swallow "End of test file" as an error.
        Assert.Empty(Errors(second));
    }

    // ---- The individual causes, as small cases ----

    [Theory]
    [InlineData("Section 2: Essay Question")]
    [InlineData("Section 2")]
    [InlineData("Part B: Short answers")]
    [InlineData("القسم الثاني: الأسئلة المقالية")]
    [InlineData("الجزء 3")]
    public void ASectionHeadingBetweenQuestions_EndsTheQuestion_AndIsNotAnError(string heading)
    {
        var result = Parse("Q1: One?", "A) a", "B) b", "Correct Answer: A", "Points: 1", heading, "Q2: Two?", "A) a", "B) b", "Correct Answer: B");

        Assert.Equal(2, result.Questions.Count);
        Assert.Empty(Errors(result.Questions[0]));
        Assert.Empty(Codes(result.Questions[0]));
        Assert.Equal("Two?", result.Questions[1].Text);
    }

    [Fact]
    public void AnEssaySectionHeading_MakesTheFollowingOptionLessQuestionsEssays_WithoutAWarning()
    {
        var result = Parse("Section 2: Essay Questions", "Q1: Explain RAM.", "Points: 5", "Q2: Explain ROM.");

        Assert.All(result.Questions, q => Assert.Equal("Essay", q.Type));
        Assert.All(result.Questions, q => Assert.Empty(q.Issues));
    }

    [Fact]
    public void AQuestionWithOptions_InsideAnEssaySection_IsStillMultipleChoice()
    {
        var result = Parse("Section 2: Essay Questions", "Q1: Pick one.", "A) x", "B) y", "Correct Answer: A");

        Assert.Equal("Mcq", Assert.Single(result.Questions).Type);
    }

    [Fact]
    public void AnMcqSectionHeading_DoesNotTurnABrokenQuestionIntoAnEssay()
    {
        var result = Parse("Section 1: Multiple Choice Questions", "Q1: No options here.");

        var question = Assert.Single(result.Questions);
        Assert.Equal("Mcq", question.Type);
        Assert.Contains(ImportIssueCodes.OptionsMissing, Errors(question));
    }

    [Theory]
    [InlineData("س12: ما هي عاصمة فرنسا؟", 12)]
    [InlineData("س ١٣: ما هي عاصمة فرنسا؟", 13)]
    [InlineData("س1) ما هي عاصمة فرنسا؟", 1)]
    [InlineData("س.4 ما هي عاصمة فرنسا؟", 4)]
    [InlineData("سؤال 5: ما هي عاصمة فرنسا؟", 5)]
    [InlineData("السؤال 6- ما هي عاصمة فرنسا؟", 6)]
    public void ArabicQuestionPrefixes_AreRecognised(string line, int number)
    {
        var question = Assert.Single(Parse(line, "أ) باريس", "ب) لندن", "Correct Answer: أ").Questions);

        Assert.Equal(number, question.Number);
        Assert.Equal("ما هي عاصمة فرنسا؟", question.Text);
        Assert.Empty(Errors(question));
    }

    [Fact]
    public void AnArabicQuestionAfterAnEssay_DoesNotBecomePartOfTheEssay()
    {
        var result = Parse(
            "Q11: Explain.", "Type: Essay", "Model Answer: Because.", "Points: 5",
            "س12: سؤال؟", "أ) نعم", "ب) لا", "Correct Answer: أ");

        Assert.Equal(2, result.Questions.Count);
        Assert.Equal("Essay", result.Questions[0].Type);
        Assert.Empty(Errors(result.Questions[0]));
        Assert.Equal(["A", "B"], result.Questions[1].Options.Select(o => o.Label));
    }

    [Theory]
    [InlineData("End of test file")]
    [InlineData("Good luck!")]
    [InlineData("--- end ---")]
    public void TrailingText_AfterTheLastQuestion_IsAWarning_NotAnError(string trailing)
    {
        var question = Assert.Single(Parse("Q1: One?", "A) a", "B) b", "Correct Answer: A", "Points: 1", trailing).Questions);

        Assert.Empty(Errors(question));
        Assert.Contains(question.Issues, i => i.Code == ImportIssueCodes.UnexpectedLine && i.Severity == ImportSeverity.Warning);
    }

    // ---- Flexible numbering, labels and answers ----

    [Theory]
    [InlineData("1. What is 2+2?")]
    [InlineData("1) What is 2+2?")]
    [InlineData("1- What is 2+2?")]
    [InlineData("١. What is 2+2?")]
    [InlineData("Q1. What is 2+2?")]
    [InlineData("Q 1 What is 2+2?")]
    [InlineData("Question 1 - What is 2+2?")]
    [InlineData("Question No. 1: What is 2+2?")]
    [InlineData("Question #1: What is 2+2?")]
    public void QuestionNumberingStyles_AreAllRecognised(string line)
    {
        var question = Assert.Single(Parse(line, "A) 3", "B) 4", "Correct Answer: B").Questions);

        Assert.Equal(1, question.Number);
        Assert.Equal("What is 2+2?", question.Text);
        Assert.Empty(Errors(question));
    }

    [Fact]
    public void BareNumberedQuestions_AreSeparatedFromEachOther()
    {
        var result = Parse("1. One?", "a. x", "b. y", "Answer: a", "2. Two?", "a. x", "b. y", "Answer: b", "3. Three?");

        Assert.Equal([1, 2, 3], result.Questions.Select(q => q.Number));
        Assert.Equal(["A", "B"], result.Questions[1].Options.Select(o => o.Label));
        Assert.Equal("y", result.Questions[1].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal("Essay", result.Questions[2].Type); // no options and no answer: an essay, flagged
        Assert.Contains(ImportIssueCodes.InferredEssay, Codes(result.Questions[2]));
    }

    [Theory]
    [InlineData("Correct Answer: B")]
    [InlineData("Answer: B")]
    [InlineData("Ans: B")]
    [InlineData("Ans. B")]
    [InlineData("Correct: B")]
    [InlineData("Correct option: B")]
    [InlineData("Right answer: (B)")]
    [InlineData("Answer is B")]
    [InlineData("Key: b")]
    [InlineData("Answer: B) Queue")]
    [InlineData("Answer: Option B")]
    [InlineData("Answer: Queue")]
    [InlineData("الإجابة الصحيحة: ب")]
    [InlineData("الاجابة: ب")]
    [InlineData("الجواب الصحيح: (ب)")]
    public void CorrectAnswerSpellings_AreAllUnderstood(string line)
    {
        var question = Assert.Single(Parse("Q1: FIFO?", "A) Stack", "B) Queue", "C) Tree", line).Questions);

        Assert.Empty(Errors(question));
        Assert.Equal("Queue", question.Options.Single(o => o.IsCorrect).Text);
    }

    [Fact]
    public void AnAnswerThatMatchesNoOptionAndNoLetter_IsStillReported()
    {
        var question = Assert.Single(Parse("Q1: FIFO?", "A) Stack", "B) Queue", "Answer: Heap").Questions);

        Assert.Contains(ImportIssueCodes.CorrectAnswerInvalid, Errors(question));
        Assert.All(question.Options, o => Assert.False(o.IsCorrect));
    }

    [Theory]
    [InlineData("*B) Queue", "B) Queue")]
    [InlineData("B) Queue *", "B) Queue")]
    [InlineData("B) Queue ✓", "B) Queue")]
    [InlineData("✔ B) Queue", "B) Queue")]
    [InlineData("B) Queue (correct)", "B) Queue")]
    [InlineData("B) Queue [correct]", "B) Queue")]
    [InlineData("B) Queue (الصحيحة)", "B) Queue")]
    public void ACorrectMarkOnTheOption_IsUnderstood_WithoutAnAnswerLine(string optionLine, string _)
    {
        var question = Assert.Single(Parse("Q1: FIFO?", "A) Stack", optionLine, "C) Tree").Questions);

        Assert.Empty(Errors(question));
        var correct = Assert.Single(question.Options, o => o.IsCorrect);
        Assert.Equal("Queue", correct.Text);
    }

    [Fact]
    public void TwoMarkedOptions_OrAMarkAndADifferentAnswerLine_AreReported()
    {
        var two = Assert.Single(Parse("Q1: Q?", "*A) x", "*B) y").Questions);
        var conflict = Assert.Single(Parse("Q1: Q?", "*A) x", "B) y", "Answer: B").Questions);

        Assert.Contains(ImportIssueCodes.MultipleCorrectAnswers, Errors(two));
        Assert.Contains(ImportIssueCodes.MultipleCorrectAnswers, Errors(conflict));
    }

    [Fact]
    public void OptionsOnOneLine_AreSplit()
    {
        var question = Assert.Single(Parse("Q1: Capital of France?", "A) Paris   B) London   C) Rome   D) Berlin", "Answer: A").Questions);

        Assert.Equal(["Paris", "London", "Rome", "Berlin"], question.Options.Select(o => o.Text));
        Assert.Empty(Errors(question));
    }

    [Fact]
    public void ALetterInsideAnOptionsText_IsNotSplitOff()
    {
        var question = Assert.Single(Parse("Q1: Q?", "A) Vitamin B) is not a vitamin", "B) y", "Answer: B").Questions);

        Assert.Equal("Vitamin B) is not a vitamin", question.Options[0].Text);
    }

    [Theory]
    [InlineData("Q1: What is 2+2? (2 points)", "What is 2+2?", 2)]
    [InlineData("Q1: What is 2+2? [3 marks]", "What is 2+2?", 3)]
    [InlineData("Q1: What is 2+2? (1.5 pts)", "What is 2+2?", 1.5)]
    [InlineData("س1: كم ناتج 2+2؟ (3 درجات)", "كم ناتج 2+2؟", 3)]
    public void PointsAtTheEndOfTheQuestionLine_AreUnderstood(string line, string text, double points)
    {
        var question = Assert.Single(Parse(line, "A) 3", "B) 4", "Answer: B").Questions);

        Assert.Equal(text, question.Text);
        Assert.Equal((decimal)points, question.Marks);
        Assert.False(question.MarksDefaulted);
    }

    [Theory]
    [InlineData("Mark: 2")]
    [InlineData("Grade: 2")]
    [InlineData("Marks = 2")]
    [InlineData("Points – 2")]
    [InlineData("الدرجة : ٢")]
    public void MorePointsSpellings_AreUnderstood(string line)
    {
        var question = Assert.Single(Parse("Q1: Q?", "A) x", "B) y", "Answer: A", line).Questions);

        Assert.Equal(2m, question.Marks);
        Assert.Empty(Errors(question));
    }

    // ---- Essays ----

    [Fact]
    public void AnAnswerLineOfAnEssay_IsItsModelAnswer_AlsoOverSeveralLines()
    {
        var question = Assert.Single(Parse("Q1: Explain RAM.", "Type: Essay", "Answer: Fast temporary memory.", "that is volatile.").Questions);

        Assert.Equal("Essay", question.Type);
        Assert.Equal("Fast temporary memory.\nthat is volatile.", question.ModelAnswer);
        Assert.Empty(Errors(question));
    }

    [Fact]
    public void TheTypeLine_MayComeAfterTheAnswer()
    {
        var question = Assert.Single(Parse("Q1: Explain RAM.", "Answer: Fast memory.", "Type: Essay").Questions);

        Assert.Equal("Essay", question.Type);
        Assert.Equal("Fast memory.", question.ModelAnswer);
    }

    [Theory]
    [InlineData("Q1: Explain RAM. (Essay)")]
    [InlineData("Q1: [Essay] Explain RAM.")]
    [InlineData("Essay Q1: Explain RAM.")]
    public void AnEssayMarkedInTheQuestionLine_IsAnEssay(string line)
    {
        var question = Assert.Single(Parse(line).Questions);

        Assert.Equal("Essay", question.Type);
        Assert.Equal("Explain RAM.", question.Text);
        Assert.Empty(Codes(question));
    }

    [Fact]
    public void AnOptionLessQuestionWithoutAnyMarker_BecomesAnEssay_ButIsFlaggedForReview()
    {
        var question = Assert.Single(Parse("Q1: Discuss the role of the CPU.").Questions);

        Assert.Equal("Essay", question.Type);
        var issue = Assert.Single(question.Issues);
        Assert.Equal(ImportIssueCodes.InferredEssay, issue.Code);
        Assert.Equal(ImportSeverity.Warning, issue.Severity);
    }

    [Fact]
    public void AnOptionLessQuestionWithAnAnswerLetter_IsNotTurnedIntoAnEssay()
    {
        var question = Assert.Single(Parse("Q1: Broken?", "Correct Answer: A").Questions);

        Assert.Equal("Mcq", question.Type);
        Assert.Contains(ImportIssueCodes.OptionsMissing, Errors(question));
    }

    // ---- Titles and headings ----

    [Fact]
    public void TheFirstLineOfTheDocument_IsTheExamTitle_WhenThereIsNoTitleLine()
    {
        var result = Parse("Examora – Word Import Test Questions", "Sample file for testing", "Q1: One?", "A) a", "B) b", "Answer: A");

        Assert.Equal("Examora – Word Import Test Questions", result.ExamTitle);
        Assert.Contains(result.Issues, i => i.Code == ImportIssueCodes.TextOutsideQuestion && i.Line == 2);
        Assert.DoesNotContain(result.Issues, i => i.Line == 1);
    }

    [Fact]
    public void AnExplicitTitleLine_WinsOverTheFirstLine()
    {
        var result = Parse("Some heading", "Exam Title: Real title", "Q1: One?", "A) a", "B) b", "Answer: A");

        Assert.Equal("Real title", result.ExamTitle);
    }

    // ---- The existing strict format keeps working ----

    [Fact]
    public void TheOriginalDocumentedFormat_IsUnchanged()
    {
        var result = Parse(
            "Exam Title: Introduction to Computer Science",
            "Question 1: What does CPU stand for?", "A) Central Processing Unit", "B) Computer Personal Unit",
            "Correct Answer: A", "Points: 2",
            "Question 2: Which is a language?", "A) HTML", "B) Python", "Correct Answer: B");

        Assert.Equal("Introduction to Computer Science", result.ExamTitle);
        Assert.Empty(result.Issues);
        Assert.Equal(2, result.Questions.Count);
        Assert.All(result.Questions, q => Assert.Empty(q.Issues));
    }
}
