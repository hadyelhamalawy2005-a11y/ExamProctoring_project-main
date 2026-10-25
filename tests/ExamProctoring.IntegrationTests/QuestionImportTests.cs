using System.Net;
using System.Runtime.CompilerServices;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ExamProctoring.Application.Common;
using ExamProctoring.Domain.Exams;
using ExamProctoring.Domain.Users;
using ExamProctoring.Infrastructure.Persistence;
using ExamProctoring.IntegrationTests.TestSupport;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using static ExamProctoring.IntegrationTests.TestSupport.AuthApi;

namespace ExamProctoring.IntegrationTests;

// The Word import in two steps: POST /api/questions/import/preview (reads a .docx, saves nothing) and
// POST /api/exams/{examId}/questions/import (saves the reviewed questions, all or none).
[Collection(ApiCollection.Name)]
public sealed class QuestionImportTests(ApiFactory factory)
{
    private const string PreviewPath = "/api/questions/import/preview";

    private static readonly string[] ValidDocument =
    [
        "Exam Title: Introduction to Computer Science",
        "Question 1: What does CPU stand for?", "A) Central Processing Unit", "B) Computer Personal Unit",
        "C) Central Program Utility", "D) Control Processing User", "Correct Answer: A", "Points: 2",
        "Question 2: Which of the following is a programming language?", "A) HTML", "B) Python", "C) HTTP", "D) SQL Server",
        "Correct Answer: B",
    ];

    private readonly AuthApi _api = new(factory);

    private static CancellationToken Ct => TestContext.Current.CancellationToken;

    // ---- Preview ----

    [Fact]
    public async Task Preview_OfAValidDocument_Returns200_WithTheQuestions_AndSavesNothing()
    {
        var (instructor, token) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);
        var before = await QuestionCountAsync();

        var response = await PreviewAsync(token, DocxBuilder.Build(ValidDocument));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var json = await JsonAsync(response);
        var root = json.RootElement;
        Assert.Equal("Introduction to Computer Science", root.GetProperty("examTitle").GetString());
        Assert.True(root.GetProperty("isValid").GetBoolean());
        Assert.Equal(1, root.GetProperty("defaultMarks").GetDecimal());
        Assert.Equal(0, root.GetProperty("issues").GetArrayLength());

        var questions = root.GetProperty("questions").EnumerateArray().ToList();
        Assert.Equal(2, questions.Count);
        Assert.Equal("Mcq", questions[0].GetProperty("type").GetString());
        Assert.Equal("What does CPU stand for?", questions[0].GetProperty("text").GetString());
        Assert.Equal(2, questions[0].GetProperty("marks").GetDecimal());
        Assert.False(questions[0].GetProperty("marksDefaulted").GetBoolean());
        Assert.True(questions[1].GetProperty("marksDefaulted").GetBoolean());
        var options = questions[0].GetProperty("options").EnumerateArray().ToList();
        Assert.Equal(["A", "B", "C", "D"], options.Select(o => o.GetProperty("label").GetString()));
        Assert.Equal([true, false, false, false], options.Select(o => o.GetProperty("isCorrect").GetBoolean()));

        Assert.Equal(before, await QuestionCountAsync());
        Assert.Empty(await StoredQuestionsAsync(exam.Id));
    }

    // The sample exam the first parser failed on (section headings, "س12:" Arabic numbering, an essay, a closing line),
    // uploaded the way the dashboard does.
    [Fact]
    public async Task Preview_OfTheRealSampleFile_ReadsAllThirteenQuestions_WithoutErrors()
    {
        var (_, token) = await InstructorAsync();
        var path = Path.GetFullPath(Path.Combine(SourceDirectory(), "..", "ExamProctoring.UnitTests", "Exams", "Import", "Fixtures",
            "Examora_Word_Import_Test_Questions.docx"));

        var response = await PreviewAsync(token, await File.ReadAllBytesAsync(path), "Examora_Word_Import_Test_Questions.docx");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var json = await JsonAsync(response);
        Assert.True(json.RootElement.GetProperty("isValid").GetBoolean(), json.RootElement.GetRawText());
        var questions = json.RootElement.GetProperty("questions").EnumerateArray().ToList();
        Assert.Equal(13, questions.Count);
        Assert.Equal(["Essay"], questions.Select(q => q.GetProperty("type").GetString()).Where(t => t == "Essay"));
        Assert.Equal("ما الوظيفة الأساسية لنظام إدارة قواعد البيانات؟", questions[11].GetProperty("text").GetString());
        Assert.Equal(12, questions[11].GetProperty("number").GetInt32());
        Assert.All(questions, q => Assert.DoesNotContain(q.GetProperty("issues").EnumerateArray(), i => i.GetProperty("severity").GetString() == "error"));
    }

    private static string SourceDirectory([CallerFilePath] string path = "") => Path.GetDirectoryName(path)!;

    [Fact]
    public async Task Preview_KeepsArabicTextExactly()
    {
        var (_, token) = await InstructorAsync();
        var document = DocxBuilder.Build(
            ["السؤال 1: ما هي عاصمة فرنسا؟ (Paris)", "أ) باريس", "ب) لندن", "الإجابة الصحيحة: أ", "الدرجة: 3"], rightToLeft: true);

        var response = await PreviewAsync(token, document);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var json = await JsonAsync(response);
        var question = json.RootElement.GetProperty("questions")[0];
        Assert.Equal("ما هي عاصمة فرنسا؟ (Paris)", question.GetProperty("text").GetString());
        Assert.Equal(["باريس", "لندن"], question.GetProperty("options").EnumerateArray().Select(o => o.GetProperty("text").GetString()));
        Assert.Equal(3, question.GetProperty("marks").GetDecimal());
    }

    [Fact]
    public async Task Preview_OfADocumentWithAProblem_Returns200_NotValid_WithTheIssueOnTheQuestion()
    {
        var (_, token) = await InstructorAsync();

        var response = await PreviewAsync(token, DocxBuilder.Build(["Question 1: Q?", "A) x", "B) y"]));

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using var json = await JsonAsync(response);
        Assert.False(json.RootElement.GetProperty("isValid").GetBoolean());
        var issue = Assert.Single(json.RootElement.GetProperty("questions")[0].GetProperty("issues").EnumerateArray());
        Assert.Equal("correct_answer_missing", issue.GetProperty("code").GetString());
        Assert.Equal("error", issue.GetProperty("severity").GetString());
        Assert.Equal(1, issue.GetProperty("question").GetInt32());
    }

    [Fact]
    public async Task Preview_WithNoFile_Returns400_OnTheFileField()
    {
        var (_, token) = await InstructorAsync();

        // A form that has other fields but no "file" part.
        var response = await SendAsync(HttpMethod.Post, PreviewPath, token, new MultipartFormDataContent { { new StringContent("hello"), "note" } });

        using var problem = await AssertProblemAsync(response, HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("A .docx file is required.", FieldError(problem, "file"));
    }

    public static TheoryData<string, string> BadFiles() => new()
    {
        { "notes.txt", "Only .docx files are supported." },
        { "exam.doc", "Only .docx files are supported." },
        { "exam.docx", "The file is not a valid Word (.docx) document." },
    };

    [Theory]
    [MemberData(nameof(BadFiles))]
    public async Task Preview_OfAFileThatIsNotADocx_Returns400_AndSavesNothing(string fileName, string message)
    {
        var (_, token) = await InstructorAsync();
        var before = await QuestionCountAsync();

        var response = await PreviewAsync(token, "Question 1: plain text"u8.ToArray(), fileName);

        using var problem = await AssertProblemAsync(response, HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal(message, FieldError(problem, "file"));
        Assert.Equal(before, await QuestionCountAsync());
    }

    [Fact]
    public async Task Preview_OfAnEmptyFile_Returns400()
    {
        var (_, token) = await InstructorAsync();

        var response = await PreviewAsync(token, [], "exam.docx");

        using var problem = await AssertProblemAsync(response, HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("The file is empty.", FieldError(problem, "file"));
    }

    [Fact]
    public async Task Preview_OfACorruptedDocx_Returns400_NotAServerError()
    {
        var (_, token) = await InstructorAsync();
        var bytes = DocxBuilder.Build(ValidDocument);

        var response = await PreviewAsync(token, bytes[..(bytes.Length / 2)]);

        using var problem = await AssertProblemAsync(response, HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("The file is not a valid Word (.docx) document.", FieldError(problem, "file"));
    }

    [Fact]
    public async Task Preview_OfAFileOverTheLimit_Returns413()
    {
        var (_, token) = await InstructorAsync();
        var bytes = new byte[(int)(10 * 1024 * 1024) + 1];
        bytes[0] = 0x50;
        bytes[1] = 0x4B;

        var response = await PreviewAsync(token, bytes);

        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
    }

    // ---- Confirm ----

    [Fact]
    public async Task Confirm_SavesTheQuestions_AfterTheExistingOnes_InOrder_AndReturns201()
    {
        var (instructor, token) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);
        await InsertQuestionAsync(exam.Id, 1);

        var response = await ConfirmAsync(token, exam.Id, new
        {
            questions = new object[]
            {
                Mcq("  First?  ", 2.5m, [("One", true), ("Two", false)]),
                Essay("Second?", 10m, "Because."),
                Mcq("ما هي عاصمة فرنسا؟", 1m, [("باريس", true), ("لندن", false), ("روما", false)]),
            },
        });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        using var json = await JsonAsync(response);
        var items = json.RootElement.GetProperty("items").EnumerateArray().ToList();
        Assert.Equal([2, 3, 4], items.Select(i => i.GetProperty("position").GetInt32()));
        Assert.All(items, i => Assert.Equal(exam.Id, i.GetProperty("examId").GetGuid()));

        var stored = await StoredQuestionsAsync(exam.Id);
        Assert.Equal([1, 2, 3, 4], stored.Select(s => s.Question.Position));
        Assert.Equal(["Question 1", "First?", "Second?", "ما هي عاصمة فرنسا؟"], stored.Select(s => s.Question.Text));
        Assert.Equal(QuestionType.Essay, stored[2].Question.Type);
        Assert.Empty(stored[2].Options);
        Assert.Equal(2.5m, stored[1].Question.Marks);
        Assert.Equal(["باريس", "لندن", "روما"], stored[3].Options.Select(o => o.Text));
        Assert.Equal([true, false, false], stored[3].Options.Select(o => o.IsCorrect));
    }

    [Fact]
    public async Task PreviewThenConfirm_StoresWhatTheDocumentSaid()
    {
        var (instructor, token) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);
        using var preview = await JsonAsync(await PreviewAsync(token, DocxBuilder.Build(ValidDocument)));
        var questions = preview.RootElement.GetProperty("questions").EnumerateArray().Select(q => new
        {
            type = q.GetProperty("type").GetString(),
            text = q.GetProperty("text").GetString(),
            marks = q.GetProperty("marks").GetDecimal(),
            modelAnswer = (string?)null,
            options = q.GetProperty("options").EnumerateArray()
                .Select(o => new { text = o.GetProperty("text").GetString(), isCorrect = o.GetProperty("isCorrect").GetBoolean() })
                .ToList(),
        }).ToList();

        var response = await ConfirmAsync(token, exam.Id, new { questions });

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var stored = await StoredQuestionsAsync(exam.Id);
        Assert.Equal(["What does CPU stand for?", "Which of the following is a programming language?"], stored.Select(s => s.Question.Text));
        Assert.Equal("Central Processing Unit", stored[0].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal("Python", stored[1].Options.Single(o => o.IsCorrect).Text);
        Assert.Equal([2m, 1m], stored.Select(s => s.Question.Marks));
    }

    [Fact]
    public async Task Confirm_WithOneInvalidQuestion_Returns400_NamesIt_AndSavesNone()
    {
        var (instructor, token) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);

        var response = await ConfirmAsync(token, exam.Id, new
        {
            questions = new object[]
            {
                Mcq("Fine?", 1m, [("a", true), ("b", false)]),
                Mcq("Broken?", 1m, [("a", true), ("  ", false)]),
                Mcq("No correct answer?", 1m, [("a", false), ("b", false)]),
            },
        });

        using var problem = await AssertProblemAsync(response, HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("Option text is required.", FieldError(problem, "questions[1].options[1].text"));
        Assert.Equal("An MCQ question needs exactly one correct option.", FieldError(problem, "questions[2].options"));
        Assert.DoesNotContain(problem.RootElement.GetProperty("errors").EnumerateObject(), p => p.Name.StartsWith("questions[0]", StringComparison.Ordinal));
        Assert.Empty(await StoredQuestionsAsync(exam.Id));
    }

    [Fact]
    public async Task Confirm_WithNoQuestionsOrTooMany_Returns400()
    {
        var (instructor, token) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);

        using var none = await AssertProblemAsync(await ConfirmAsync(token, exam.Id, new { questions = Array.Empty<object>() }),
            HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("At least one question is required.", FieldError(none, "questions"));

        var many = Enumerable.Range(0, 201).Select(_ => Essay("Q?", 1m, null)).ToArray();
        using var tooMany = await AssertProblemAsync(await ConfirmAsync(token, exam.Id, new { questions = many }),
            HttpStatusCode.BadRequest, ErrorCodes.ValidationFailed);
        Assert.Equal("At most 200 questions can be imported at once.", FieldError(tooMany, "questions"));
        Assert.Empty(await StoredQuestionsAsync(exam.Id));
    }

    [Fact]
    public async Task Confirm_OnAnExamThatCannotBeChanged_Returns409_AndSavesNothing()
    {
        var (instructor, token) = await InstructorAsync();
        var started = await InsertExamAsync(instructor.Id, e => e.StartsAt = DateTimeOffset.UtcNow.AddHours(-1));
        var cancelled = await InsertExamAsync(instructor.Id, e => e.Status = ExamStatus.Cancelled);
        var body = new { questions = new object[] { Essay("Q?", 1m, null) } };

        using var one = await AssertProblemAsync(await ConfirmAsync(token, started.Id, body), HttpStatusCode.Conflict, ErrorCodes.ExamNotEditable);
        using var two = await AssertProblemAsync(await ConfirmAsync(token, cancelled.Id, body), HttpStatusCode.Conflict, ErrorCodes.ExamNotEditable);

        Assert.Empty(await StoredQuestionsAsync(started.Id));
        Assert.Empty(await StoredQuestionsAsync(cancelled.Id));
    }

    [Fact]
    public async Task Confirm_OnAnotherInstructorsExam_AnUnknownExam_OrNotAnId_Returns404()
    {
        var (owner, _) = await InstructorAsync();
        var (_, otherToken) = await InstructorAsync();
        var exam = await InsertExamAsync(owner.Id);
        var body = new { questions = new object[] { Essay("Q?", 1m, null) } };

        foreach (var id in new[] { exam.Id.ToString(), Guid.NewGuid().ToString(), "not-an-id" })
        {
            using var problem = await AssertProblemAsync(await ConfirmAsync(otherToken, id, body), HttpStatusCode.NotFound, ErrorCodes.ExamNotFound);
        }

        Assert.Empty(await StoredQuestionsAsync(exam.Id));
    }

    // ---- Authorization ----

    [Theory]
    [InlineData("preview")]
    [InlineData("confirm")]
    public async Task WithoutAToken_Returns401TokenInvalid(string endpoint)
    {
        using var _ = await AssertProblemAsync(await CallAsync(endpoint, accessToken: null), HttpStatusCode.Unauthorized, ErrorCodes.TokenInvalid);
    }

    [Theory]
    [InlineData("preview", RoleNames.Student)]
    [InlineData("preview", RoleNames.Admin)]
    [InlineData("confirm", RoleNames.Student)]
    [InlineData("confirm", RoleNames.Admin)]
    public async Task StudentsAndAdmins_Get403_AndChangeNothing(string endpoint, string role)
    {
        var (instructor, _) = await InstructorAsync();
        var exam = await InsertExamAsync(instructor.Id);
        var caller = await _api.CreateUserAsync(role);
        var session = await _api.LoginAsync(caller);

        var response = await CallAsync(endpoint, session.AccessToken, exam.Id);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        Assert.Empty(await StoredQuestionsAsync(exam.Id));
    }

    [Theory]
    [InlineData("preview")]
    [InlineData("confirm")]
    public async Task AnInstructorWhoMustChangeTheirPassword_Gets403PasswordChangeRequired(string endpoint)
    {
        var instructor = await _api.CreateUserAsync(RoleNames.Instructor, mustChangePassword: true);
        var session = await _api.LoginAsync(instructor);

        using var _ = await AssertProblemAsync(await CallAsync(endpoint, session.AccessToken), HttpStatusCode.Forbidden, ErrorCodes.PasswordChangeRequired);
    }

    // ---- Helpers ----

    private static object Mcq(string text, decimal marks, (string Text, bool IsCorrect)[] options) =>
        new { type = "Mcq", text, marks, modelAnswer = (string?)null, options = options.Select(o => new { text = o.Text, isCorrect = o.IsCorrect }) };

    private static object Essay(string text, decimal marks, string? modelAnswer) =>
        new { type = "Essay", text, marks, modelAnswer, options = Array.Empty<object>() };

    private Task<HttpResponseMessage> CallAsync(string endpoint, string? accessToken, Guid? examId = null) => endpoint == "preview"
        ? SendAsync(HttpMethod.Post, PreviewPath, accessToken, UploadContent(DocxBuilder.Build(ValidDocument), "exam.docx"))
        : SendAsync(HttpMethod.Post, ImportPath((examId ?? Guid.NewGuid()).ToString()), accessToken,
            JsonContent.Create(new { questions = new object[] { Essay("Q?", 1m, null) } }));

    private static string ImportPath(string examId) => $"/api/exams/{examId}/questions/import";

    private static MultipartFormDataContent UploadContent(byte[] bytes, string fileName)
    {
        var content = new MultipartFormDataContent();
        var file = new ByteArrayContent(bytes);
        file.Headers.ContentType = new MediaTypeHeaderValue("application/vnd.openxmlformats-officedocument.wordprocessingml.document");
        content.Add(file, "file", fileName);
        return content;
    }

    private Task<HttpResponseMessage> PreviewAsync(string accessToken, byte[] bytes, string fileName = "exam.docx") =>
        SendAsync(HttpMethod.Post, PreviewPath, accessToken, UploadContent(bytes, fileName));

    private Task<HttpResponseMessage> ConfirmAsync(string accessToken, Guid examId, object body) => ConfirmAsync(accessToken, examId.ToString(), body);

    private Task<HttpResponseMessage> ConfirmAsync(string accessToken, string examId, object body) =>
        SendAsync(HttpMethod.Post, ImportPath(examId), accessToken, JsonContent.Create(body));

    private Task<HttpResponseMessage> SendAsync(HttpMethod method, string path, string? accessToken, HttpContent? content = null)
    {
        var client = factory.CreateClient();
        if (accessToken is not null)
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        return client.SendAsync(new HttpRequestMessage(method, path) { Content = content }, Ct);
    }

    private async Task<(ApplicationUser User, string AccessToken)> InstructorAsync()
    {
        var user = await _api.CreateUserAsync(RoleNames.Instructor);
        return (user, (await _api.LoginAsync(user)).AccessToken);
    }

    private static async Task<JsonDocument> JsonAsync(HttpResponseMessage response) =>
        JsonDocument.Parse(await response.Content.ReadAsStringAsync(Ct));

    private static string? FieldError(JsonDocument problem, string field) =>
        Assert.Single(problem.RootElement.GetProperty("errors").GetProperty(field).EnumerateArray()).GetString();

    private async Task<Exam> InsertExamAsync(Guid instructorId, Action<Exam>? change = null)
    {
        var exam = new Exam
        {
            Id = Guid.NewGuid(),
            InstructorId = instructorId,
            Title = "Import test exam",
            StartsAt = DateTimeOffset.FromUnixTimeSeconds(DateTimeOffset.UtcNow.ToUnixTimeSeconds()).AddDays(1),
            DurationMinutes = 60,
            WarningLimit = 20,
        };
        change?.Invoke(exam);
        await SaveAsync(db => db.Exams.Add(exam));
        return exam;
    }

    private async Task InsertQuestionAsync(Guid examId, int position)
    {
        var question = new Question { Id = Guid.NewGuid(), ExamId = examId, Type = QuestionType.Essay, Text = $"Question {position}", Marks = 1m, Position = position };
        await SaveAsync(db => db.Questions.Add(question));
    }

    private async Task SaveAsync(Action<AppDbContext> change)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        change(db);
        await db.SaveChangesAsync(Ct);
    }

    private async Task<int> QuestionCountAsync()
    {
        await using var scope = factory.Services.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<AppDbContext>().Questions.CountAsync(Ct);
    }

    private sealed record StoredQuestion(Question Question, List<QuestionOption> Options);

    private async Task<List<StoredQuestion>> StoredQuestionsAsync(Guid examId)
    {
        await using var scope = factory.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var questions = await db.Questions.AsNoTracking().Where(q => q.ExamId == examId).OrderBy(q => q.Position).ToListAsync(Ct);
        var ids = questions.Select(q => q.Id).ToList();
        var options = await db.QuestionOptions.AsNoTracking().Where(o => ids.Contains(o.QuestionId)).ToListAsync(Ct);
        return questions.Select(q => new StoredQuestion(q, options.Where(o => o.QuestionId == q.Id).OrderBy(o => o.Position).ToList())).ToList();
    }
}
