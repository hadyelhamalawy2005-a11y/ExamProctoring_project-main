using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace ExamProctoring.Application.Exams.Import;

// The result of reading the lines of a question document: the exam title if there is one, the questions in document order,
// and the problems that belong to the document as a whole.
public sealed record ParsedQuestionDocument(
    string? ExamTitle,
    IReadOnlyList<ImportedQuestion> Questions,
    IReadOnlyList<ImportIssue> Issues);

// Turns the lines of an ordinary Word exam document into questions. The accepted writing styles are listed in
// docs/Word_Import_Format.md. In short:
//
//   * A question starts with "Question 1:", "Q1.", "1.", "1)", "س12:", "السؤال 3 -" ... (bare numbers must follow on from the
//     previous question, or start a document or a section).
//   * Options are "A)", "A.", "(A)", "a:", "أ)" ... one per line, or several on one line separated by tabs or wide spaces.
//   * The correct answer is "Correct Answer: B", "Answer: B", "Ans: B", "الإجابة الصحيحة: ب" (a letter, or the exact text of
//     an option), or a mark on the option itself: "*B) ...", "B) ... ✓", "B) ... (correct)".
//   * "Points: 2", "Marks: 2", "الدرجة: 2" on its own line, or "(2 points)" at the end of the question line.
//   * Headings such as "Section 2: Essay Questions", "Part B", "القسم الثاني" end the previous question. A heading that names
//     a type ("Essay", "Multiple Choice") is the default type of the questions after it.
//   * An essay is "Type: Essay", "(Essay)" in the question line, an essay heading, or a question with no options and no
//     answer letter (that last case is imported as an essay but flagged for review). Its "Model Answer:" / "Answer:" text
//     is the model answer.
//
// The parser never silently guesses: a missing or ambiguous correct answer, option or point value is reported as an issue
// and nothing is filled in, except the documented default marks. Text that fits nowhere (a closing remark, a signature) is
// kept out of the questions and reported as a warning.
public static partial class QuestionDocumentParser
{
    private const string Digits = @"[0-9٠-٩۰-۹]";

    // A single option letter: Latin, or an Arabic letter in the traditional order (alef beh jeem dal heh waw zain hah teh yeh).
    private const string Letter = @"[A-Za-zاأبجدهوزحطي]";

    private const string Number = Digits + "+(?:[.,\\u066B]" + Digits + "+)?";

    private const string PointsUnit = @"points?|pts?|marks?|درجات|درجة|نقاط|نقطة";

    private const RegexOptions Flags = RegexOptions.IgnoreCase | RegexOptions.CultureInvariant;

    [GeneratedRegex(@"^(?:exam\s+title|test\s+title|title|عنوان\s+الامتحان|عنوان\s+الاختبار)\s*[:：]\s*(?<v>.*)$", Flags, 1000)]
    private static partial Regex TitleLine();

    // "Section 2: Essay Questions", "Part B", "الجزء 3", "القسم الثاني: ...". The number/letter is required, so a sentence that
    // merely starts with "Part" is not a heading.
    [GeneratedRegex(
        @"^(?:(?:section|part|chapter|unit)\s*(?:" + Digits + @"+|[A-Za-z]|[IVXivx]+)|(?:القسم|الجزء|الباب|الفصل)\s*(?:" + Digits
        + @"+|الأول|الثاني|الثالث|الرابع|الخامس|السادس|السابع|الثامن|التاسع|العاشر|[أ-ي]))\s*(?:[:：.\-–—]\s*(?<t>.*))?$",
        Flags, 1000)]
    private static partial Regex SectionLine();

    // A line that only names a type: "Multiple Choice Questions", "MCQ", "Essay", "الأسئلة المقالية", "أسئلة اختيار من متعدد".
    [GeneratedRegex(
        @"^(?:(?<k>multiple[\s-]*choice|mcq|essay|written)(?:\s+(?:questions?|items?|section|part|only))*"
        + @"|(?:ال)?(?:أسئلة|اسئلة)\s+(?:ال)?(?<k>مقالية|مقالي|اختيار\s+من\s+متعدد)|(?<k>مقالي|اختيار\s+من\s+متعدد))\s*[:：]?\s*$",
        Flags, 1000)]
    private static partial Regex TypeHeadingLine();

    // "Question 1:", "Q1.", "Q 1 text", "Question No. 1 -", "Question #1", "Essay Q2:", "س12:", "س.4 text", "السؤال 6-".
    [GeneratedRegex(
        @"^(?:(?<ek>essay|mcq)\s+)?(?:question|quest|q|السؤال|سؤال|س)\s*(?:no\.?|number|num\.?|#|رقم)?\s*[.:]?\s*(?<n>" + Digits
        + @"+)\s*(?:[:：.)\-–—]\s*|(?=\s)|$)(?<t>.*)$",
        Flags, 1000)]
    private static partial Regex QuestionLine();

    // "1. text", "1) text", "1- text", "١. text". The separator must be followed by a space (so "1.5 points" is not a question).
    [GeneratedRegex(@"^(?<n>" + Digits + @"+)\s*(?:[.)\-–—:]\s+|\)\s*)(?<t>\S.*)$", Flags, 1000)]
    private static partial Regex BareNumberLine();

    [GeneratedRegex(@"^(?:question\s+type|type|نوع\s+السؤال|النوع)\s*[:：]\s*(?<v>.*)$", Flags, 1000)]
    private static partial Regex TypeLine();

    [GeneratedRegex(
        @"^(?:correct\s+(?:answer|option|choice)|right\s+(?:answer|option|choice)|answer|ans|correct|key"
        + @"|الإجابة\s+الصحيحة|الاجابة\s+الصحيحة|الجواب\s+الصحيح|الإجابة|الاجابة|الجواب|الحل)"
        + @"\s*(?:[:：=.\-–—]|\bis\b\s*[:：]?)\s*(?<v>.*)$",
        Flags, 1000)]
    private static partial Regex AnswerLine();

    [GeneratedRegex(
        @"^(?:model\s+answer|sample\s+answer|expected\s+answer|الإجابة\s+النموذجية|الاجابة\s+النموذجية|نموذج\s+الإجابة|نموذج\s+الاجابة)\s*[:：]\s*(?<v>.*)$",
        Flags, 1000)]
    private static partial Regex ModelAnswerLine();

    [GeneratedRegex(
        @"^(?:points?|marks?|score|grade|degree|الدرجة|الدرجات|درجة|النقاط|العلامة|العلامات)\s*[:：=\-–—]\s*(?<v>.*)$", Flags, 1000)]
    private static partial Regex PointsLine();

    [GeneratedRegex(@"^(?<n>" + Number + @")(?:\s*(?:" + PointsUnit + @"))?$", Flags, 1000)]
    private static partial Regex PointsValue();

    // "(2 points)" or "[3 marks]" at the end of the question text.
    [GeneratedRegex(@"\s*[(\[]\s*(?<n>" + Number + @")\s*(?:" + PointsUnit + @")\s*[)\]]\s*$", Flags, 1000)]
    private static partial Regex PointsSuffix();

    [GeneratedRegex(@"^\s*[(\[]\s*(?:essay|مقالي)\s*[)\]]\s*", Flags, 1000)]
    private static partial Regex EssayMarkPrefix();

    [GeneratedRegex(@"\s*[(\[]\s*(?:essay|مقالي)\s*[)\]]\s*$", Flags, 1000)]
    private static partial Regex EssayMarkSuffix();

    // "A) text", "A. text", "A: text", "A- text", "(A) text". After . : or - a space is required, so "B-52 bomber" is text.
    [GeneratedRegex(@"^(?:\((?<l1>" + Letter + @")ـ?\)|(?<l2>" + Letter + @")ـ?(?:\)|[.:：\-–—](?=\s|$)))\s*(?<t>.*)$", Flags, 1000)]
    private static partial Regex OptionLine();

    // The next option on the same line, separated by a tab or at least two spaces: "A) Paris   B) London   *C) Rome".
    [GeneratedRegex(@"(?:\t|\s{2,})(?<m>[*✓✔☑]\s*)?\(?(?<l>" + Letter + @")ـ?\)\s*", Flags, 1000)]
    private static partial Regex NextInlineOption();

    [GeneratedRegex(@"^[*✓✔☑]+\s*", Flags, 1000)]
    private static partial Regex LeadingCorrectMark();

    [GeneratedRegex(
        @"(?:\s*[*✓✔☑]+|\s*[(\[]\s*(?:correct(?:\s+answer)?|right|الإجابة\s+الصحيحة|الصحيحة|صحيحة)\s*[)\]])\s*$", Flags, 1000)]
    private static partial Regex TrailingCorrectMark();

    [GeneratedRegex(@"^(?:(?:option|choice|الخيار|الاختيار)\s*)?\(?(?<l>" + Letter + @")ـ?\)?(?:\s*[).:\-–—]\s*.*)?$", Flags, 1000)]
    private static partial Regex AnswerLetter();

    private static readonly Dictionary<char, char> ArabicLetters = new()
    {
        ['ا'] = 'A', ['أ'] = 'A', ['ب'] = 'B', ['ج'] = 'C', ['د'] = 'D',
        ['ه'] = 'E', ['و'] = 'F', ['ز'] = 'G', ['ح'] = 'H', ['ط'] = 'I', ['ي'] = 'J',
    };

    // Invisible direction marks that Word and keyboards add around Arabic and mixed text.
    private static readonly char[] DirectionMarks =
        ['‎', '‏', '؜', '‪', '‫', '‬', '‭', '‮', '⁦', '⁧', '⁨', '⁩', '﻿'];

    private const string Mcq = "Mcq";
    private const string Essay = "Essay";

    private enum Target { None, Text, Option, Model, Answer }

    private sealed class OptionBuilder(string label, string text, bool marked)
    {
        public string Label { get; } = label;
        public StringBuilder Text { get; } = new(text);
        public bool Marked { get; } = marked;
    }

    private sealed class QuestionBuilder(int number, int line, string? sectionKind)
    {
        public int Number { get; } = number;
        public int Line { get; } = line;
        public string? SectionKind { get; } = sectionKind;
        public string? Kind { get; set; } // from a Type line, an "Essay Q1" prefix or an "(Essay)" mark
        public bool KindSeen { get; set; }
        public List<string> TextLines { get; } = [];
        public List<OptionBuilder> Options { get; } = [];
        public List<(string Value, int Line)> Answers { get; } = [];
        public List<(string Text, int Line)> AnswerExtra { get; } = [];
        public decimal? Points { get; set; }
        public bool PointsSeen { get; set; }
        public bool ModelSeen { get; set; }
        public List<string> ModelLines { get; } = [];
        public List<ImportIssue> Issues { get; } = [];
        public Target Last { get; set; } = Target.None;
    }

    public static ParsedQuestionDocument Parse(IReadOnlyList<SourceLine> lines, int maxOptions)
    {
        var documentIssues = new List<ImportIssue>();
        var questions = new List<ImportedQuestion>();
        var numbers = new HashSet<int>();
        string? title = null;
        string? firstLine = null;
        string? sectionKind = null;
        QuestionBuilder? current = null;
        var lastNumber = 0;

        void Finish()
        {
            if (current is null)
                return;
            questions.Add(Build(current, maxOptions, numbers));
            current = null;
        }

        void Start(int number, int line, string? text, string? kind)
        {
            Finish();
            lastNumber = number;
            current = new QuestionBuilder(number, line, sectionKind) { Kind = kind, KindSeen = kind is not null };
            var first = TrimMarks(text ?? string.Empty);
            if (first.Length > 0)
                current.TextLines.Add(first);
            current.Last = Target.Text;
        }

        foreach (var source in lines)
        {
            var raw = TrimMarks(source.Text);
            if (raw.Length == 0)
                continue;
            var text = raw.Replace('\t', ' ');

            if (TitleLine().Match(text) is { Success: true } titleMatch)
            {
                var value = TrimMarks(titleMatch.Groups["v"].Value);
                if (title is null || title == firstLine)
                    title = value.Length > 0 ? value : title;
                else
                    documentIssues.Add(new ImportIssue(ImportIssueCodes.DuplicateTitle, ImportSeverity.Warning,
                        "The document has more than one exam title; the first one is used.", null, source.Number));
                continue;
            }

            // A heading ends the question before it and may set the default type of the questions after it.
            if (SectionLine().Match(text) is { Success: true } section)
            {
                Finish();
                sectionKind = KindOf(section.Groups["t"].Value);
                continue;
            }

            if (TypeHeadingLine().Match(text) is { Success: true } heading)
            {
                Finish();
                sectionKind = KindOf(heading.Groups["k"].Value);
                continue;
            }

            if (QuestionLine().Match(text) is { Success: true } questionMatch)
            {
                var kind = questionMatch.Groups["ek"].Success ? KindOf(questionMatch.Groups["ek"].Value) : null;
                Start(ParseNumber(questionMatch.Groups["n"].Value, questions.Count + 1), source.Number, questionMatch.Groups["t"].Value, kind);
                continue;
            }

            // A bare number starts a question only where one can start: at the beginning or after a heading, or when it follows
            // on from the previous question. Other numbered lines ("1. First step" inside a model answer) stay in their text.
            if (BareNumberLine().Match(text) is { Success: true } bare
                && int.TryParse(NormalizeDigits(bare.Groups["n"].Value), NumberStyles.None, CultureInfo.InvariantCulture, out var bareNumber)
                && (current is null || (bareNumber == lastNumber + 1 && StartsHere(current, bare.Groups["t"].Value))))
            {
                Start(bareNumber, source.Number, bare.Groups["t"].Value, null);
                continue;
            }

            if (current is null)
            {
                // Before the first question: the first line of the document is taken as the exam title; the rest is reported.
                if (firstLine is null && questions.Count == 0 && title is null && raw.Length <= 200)
                {
                    firstLine = raw;
                    title = raw;
                }
                else
                {
                    documentIssues.Add(new ImportIssue(ImportIssueCodes.TextOutsideQuestion, ImportSeverity.Warning,
                        $"Line {source.Number} is outside any question and was ignored: \"{Excerpt(text)}\".", null, source.Number));
                }

                continue;
            }

            Classify(current, text, raw, source.Number);
        }

        Finish();

        if (questions.Count == 0)
            documentIssues.Add(new ImportIssue(ImportIssueCodes.NoQuestions, ImportSeverity.Error,
                "No questions were found. Each question must start with a number or a line such as \"Question 1: ...\".", null, null));

        if (questions.Count > QuestionImportLimits.MaxQuestions)
        {
            documentIssues.Add(new ImportIssue(ImportIssueCodes.TooManyQuestions, ImportSeverity.Error,
                $"The document has {questions.Count} questions; at most {QuestionImportLimits.MaxQuestions} can be imported at once.", null, null));
            questions.RemoveRange(QuestionImportLimits.MaxQuestions, questions.Count - QuestionImportLimits.MaxQuestions);
        }

        return new ParsedQuestionDocument(title, questions, documentIssues);
    }

    // Inside a model answer or answer text, "2. Second point" is a list item, not the next question, unless it reads like a
    // question (ends with a question mark or colon).
    private static bool StartsHere(QuestionBuilder current, string text)
    {
        if (current.Last is not (Target.Model or Target.Answer))
            return true;
        var trimmed = TrimMarks(text);
        return trimmed.EndsWith('?') || trimmed.EndsWith('؟') || trimmed.EndsWith(':');
    }

    // One line inside a question block: a keyword line, an option, or the continuation of the previous text.
    private static void Classify(QuestionBuilder q, string text, string raw, int lineNumber)
    {
        if (TypeLine().Match(text) is { Success: true } type)
        {
            q.Last = Target.None;
            if (q.KindSeen)
            {
                Warn(q, ImportIssueCodes.DuplicateType, $"Question {q.Number}: the question type is given more than once.", lineNumber, error: true);
                return;
            }

            q.KindSeen = true;
            var value = TrimMarks(type.Groups["v"].Value);
            var kind = KindOf(value);
            if (kind is null)
                Warn(q, ImportIssueCodes.UnknownType,
                    $"Question {q.Number}: the type \"{Excerpt(value)}\" is not supported. Use \"Mcq\" or \"Essay\".", lineNumber, error: true);
            q.Kind = kind;
            return;
        }

        if (ModelAnswerLine().Match(text) is { Success: true } model)
        {
            if (q.ModelSeen)
            {
                q.Last = Target.None;
                Warn(q, ImportIssueCodes.DuplicateModelAnswer, $"Question {q.Number}: the model answer is given more than once.", lineNumber, error: true);
                return;
            }

            q.ModelSeen = true;
            q.Last = Target.Model;
            var first = TrimMarks(model.Groups["v"].Value);
            if (first.Length > 0)
                q.ModelLines.Add(first);
            return;
        }

        if (AnswerLine().Match(text) is { Success: true } answer)
        {
            q.Last = Target.Answer;
            q.Answers.Add((TrimMarks(answer.Groups["v"].Value), lineNumber));
            return;
        }

        if (PointsLine().Match(text) is { Success: true } points)
        {
            q.Last = Target.None;
            if (q.PointsSeen)
            {
                Warn(q, ImportIssueCodes.DuplicatePoints, $"Question {q.Number}: the points are given more than once.", lineNumber, error: true);
                return;
            }

            q.PointsSeen = true;
            var value = TrimMarks(points.Groups["v"].Value);
            if (PointsValue().Match(value) is { Success: true } number && TryParseMarks(number.Groups["n"].Value, out var parsed))
            {
                q.Points = parsed;
            }
            else
            {
                Warn(q, ImportIssueCodes.PointsInvalid,
                    $"Question {q.Number}: the points \"{Excerpt(value)}\" are not a number such as 2 or 1.5.", lineNumber, error: true);
            }

            return;
        }

        if (TryParseOptions(raw) is { } options)
        {
            foreach (var option in options)
            {
                if (q.Options.Any(o => o.Label == option.Label))
                    Warn(q, ImportIssueCodes.DuplicateOptionLabel,
                        $"Question {q.Number}: the option label {option.Label} is used more than once.", lineNumber, error: true);
                q.Options.Add(new OptionBuilder(option.Label, option.Text, option.Marked));
            }

            q.Last = Target.Option;
            return;
        }

        switch (q.Last)
        {
            case Target.Text:
                q.TextLines.Add(text);
                break;
            case Target.Option:
                var last = q.Options[^1].Text;
                if (last.Length > 0)
                    last.Append(' ');
                last.Append(text);
                break;
            case Target.Model:
                q.ModelLines.Add(text);
                break;
            case Target.Answer:
                q.AnswerExtra.Add((text, lineNumber));
                break;
            default:
                Warn(q, ImportIssueCodes.UnexpectedLine,
                    $"Question {q.Number}: line {lineNumber} does not belong to the question and was not imported: \"{Excerpt(text)}\".",
                    lineNumber, error: false);
                break;
        }
    }

    // One option line, possibly several options side by side. Returns null when the line is not an option.
    private static List<(string Label, string Text, bool Marked)>? TryParseOptions(string raw)
    {
        var marked = false;
        var line = raw;
        if (LeadingCorrectMark().Match(line) is { Success: true, Length: > 0 } leading)
        {
            marked = true;
            line = line[leading.Length..];
        }

        if (OptionLine().Match(line.Replace('\t', ' ') == line ? line : line) is not { Success: true } match)
            return null;

        var label = Canonical((match.Groups["l1"].Success ? match.Groups["l1"] : match.Groups["l2"]).Value[0]);
        var rest = match.Groups["t"].Value;

        // Split further options written on the same line: only the next letter in sequence counts, after a tab or two spaces.
        var segments = new List<(char Label, string Text, bool Marked)>();
        var currentLabel = label;
        var currentMarked = marked;
        var expected = (char)(label + 1);
        while (true)
        {
            Match? next = null;
            foreach (Match candidate in NextInlineOption().Matches(rest))
            {
                if (Canonical(candidate.Groups["l"].Value[0]) == expected)
                {
                    next = candidate;
                    break;
                }
            }

            if (next is null)
                break;

            segments.Add((currentLabel, rest[..next.Index], currentMarked));
            currentLabel = expected;
            currentMarked = next.Groups["m"].Success;
            rest = rest[(next.Index + next.Length)..];
            expected = (char)(expected + 1);
        }

        segments.Add((currentLabel, rest, currentMarked));

        return segments
            .Select(segment =>
            {
                var textPart = TrimMarks(segment.Text.Replace('\t', ' '));
                var isMarked = segment.Marked;
                if (TrailingCorrectMark().Match(textPart) is { Success: true, Length: > 0 } trailing)
                {
                    isMarked = true;
                    textPart = TrimMarks(textPart[..^trailing.Length]);
                }

                return (segment.Label.ToString(), textPart, isMarked);
            })
            .ToList();
    }

    // Checks one finished question block and turns it into the result.
    private static ImportedQuestion Build(QuestionBuilder q, int maxOptions, HashSet<int> numbers)
    {
        if (!numbers.Add(q.Number))
            Warn(q, ImportIssueCodes.DuplicateQuestionNumber, $"Question {q.Number}: the question number is used more than once.", q.Line, error: true);

        var text = string.Join('\n', q.TextLines).Trim();

        // "(2 points)" at the end of the question, and "(Essay)" / "[مقالي]" at either end.
        var points = q.Points;
        if (PointsSuffix().Match(text) is { Success: true } suffix && TryParseMarks(suffix.Groups["n"].Value, out var inline))
        {
            points ??= inline;
            text = text[..suffix.Index].TrimEnd();
        }

        var kind = q.Kind;
        if (EssayMarkPrefix().Match(text) is { Success: true } prefix)
        {
            kind ??= Essay;
            text = text[prefix.Length..].TrimStart();
        }

        if (EssayMarkSuffix().Match(text) is { Success: true } endMark)
        {
            kind ??= Essay;
            text = text[..endMark.Index].TrimEnd();
        }

        if (text.Length == 0)
            Warn(q, ImportIssueCodes.QuestionTextMissing, $"Question {q.Number}: the question text is missing.", q.Line, error: true);

        var options = q.Options.Select(o => (o.Label, Text: o.Text.ToString().Trim(), o.Marked)).ToList();

        // Which kind of question this is. An explicit marker wins; options mean multiple choice; otherwise the section heading
        // decides; otherwise a question with neither options nor an answer letter is an essay, flagged for the instructor.
        if (kind is null)
        {
            if (options.Count > 0)
                kind = Mcq;
            else if (q.SectionKind is not null)
                kind = q.SectionKind;
            else if (q.Answers.Count == 0 || !q.Answers.Any(a => IsLetterAnswer(a.Value)))
            {
                kind = Essay;
                Warn(q, ImportIssueCodes.InferredEssay,
                    $"Question {q.Number}: no options or answer letter were found, so it is imported as an essay question. Check it.", q.Line, error: false);
            }
            else
                kind = Mcq;
        }

        var isEssay = kind == Essay;
        var correct = -1;
        string? modelAnswer = null;

        if (isEssay)
        {
            if (options.Count > 0)
                Warn(q, ImportIssueCodes.EssayHasOptions, $"Question {q.Number}: an essay question has no options.", q.Line, error: true);

            // "Answer: ..." of an essay is its model answer. A bare option letter is not an essay answer.
            var modelLines = q.ModelLines.ToList();
            foreach (var answer in q.Answers)
            {
                if (IsLetterAnswer(answer.Value))
                    Warn(q, ImportIssueCodes.EssayHasAnswer,
                        $"Question {q.Number}: an essay question has no correct-answer letter; use \"Model Answer:\".", answer.Line, error: true);
                else if (answer.Value.Length > 0)
                    modelLines.Add(answer.Value);
            }

            modelLines.AddRange(q.AnswerExtra.Select(extra => extra.Text));
            var joined = string.Join('\n', modelLines).Trim();
            modelAnswer = joined.Length > 0 ? joined : null;
        }
        else
        {
            if (options.Count < 2)
                Warn(q, ImportIssueCodes.OptionsMissing,
                    $"Question {q.Number}: a multiple-choice question needs at least 2 options (found {options.Count}).", q.Line, error: true);
            else if (options.Count > maxOptions)
                Warn(q, ImportIssueCodes.TooManyOptions,
                    $"Question {q.Number}: a multiple-choice question can have at most {maxOptions} options (found {options.Count}).", q.Line, error: true);

            foreach (var option in options.Where(o => o.Text.Length == 0))
                Warn(q, ImportIssueCodes.OptionTextMissing, $"Question {q.Number}: option {option.Label} has no text.", q.Line, error: true);

            var hasDuplicateLabel = options.Select(o => o.Label).Distinct().Count() != options.Count;
            if (!hasDuplicateLabel && options.Count > 0
                && !options.Select(o => o.Label).SequenceEqual(Enumerable.Range(0, options.Count).Select(i => ((char)('A' + i)).ToString())))
                Warn(q, ImportIssueCodes.OptionLabelsOutOfOrder,
                    $"Question {q.Number}: the options must be labelled A, B, C ... in order (found {string.Join(", ", options.Select(o => o.Label))}).", q.Line, error: true);

            correct = ResolveCorrectOption(q, options, out var resolved) ? resolved : -1;

            foreach (var extra in q.AnswerExtra)
                Warn(q, ImportIssueCodes.UnexpectedLine,
                    $"Question {q.Number}: line {extra.Line} does not belong to the question and was not imported: \"{Excerpt(extra.Text)}\".", extra.Line, error: false);

            var modelText = string.Join('\n', q.ModelLines).Trim();
            modelAnswer = modelText.Length > 0 ? modelText : null;
        }

        var marks = points ?? QuestionImportLimits.DefaultMarks;
        var imported = isEssay
            ? []
            : options.Select((o, index) => new ImportedOption(o.Label, o.Text, index == correct)).ToList();

        return new ImportedQuestion(
            q.Number,
            q.Line,
            isEssay ? Essay : Mcq,
            text,
            marks,
            MarksDefaulted: points is null,
            modelAnswer,
            imported,
            q.Issues);
    }

    // Finds the one correct option from the marks on options and the answer lines, reporting anything missing, invalid or in
    // conflict. Returns false when no option can be named.
    private static bool ResolveCorrectOption(QuestionBuilder q, List<(string Label, string Text, bool Marked)> options, out int index)
    {
        index = -1;
        var marked = options.Select((o, i) => (o.Marked, i)).Where(x => x.Marked).Select(x => x.i).ToList();

        if (marked.Count > 1 || q.Answers.Count > 1)
        {
            Warn(q, ImportIssueCodes.MultipleCorrectAnswers,
                $"Question {q.Number}: more than one correct answer is given. A question has exactly one.", q.Line, error: true);
            return false;
        }

        var fromAnswer = -1;
        if (q.Answers.Count == 1)
        {
            var (value, line) = q.Answers[0];
            fromAnswer = FindOption(value, options);
            if (fromAnswer < 0)
            {
                Warn(q, ImportIssueCodes.CorrectAnswerInvalid,
                    value.Length == 0
                        ? $"Question {q.Number}: the correct answer is empty."
                        : $"Question {q.Number}: the correct answer \"{Excerpt(value)}\" is not the letter or the text of one of the options.",
                    line, error: true);
                return false;
            }
        }

        if (marked.Count == 1 && fromAnswer >= 0 && marked[0] != fromAnswer)
        {
            Warn(q, ImportIssueCodes.MultipleCorrectAnswers,
                $"Question {q.Number}: the marked option and the \"Correct Answer\" line disagree.", q.Line, error: true);
            return false;
        }

        index = marked.Count == 1 ? marked[0] : fromAnswer;
        if (index < 0)
            Warn(q, ImportIssueCodes.CorrectAnswerMissing, $"Question {q.Number}: the correct answer is missing.", q.Line, error: true);
        return index >= 0;
    }

    // An answer value is an option letter ("B", "(b)", "Option B", "B) Queue", "ب") or exactly one option's text.
    private static int FindOption(string value, List<(string Label, string Text, bool Marked)> options)
    {
        if (AnswerLetter().Match(value) is { Success: true } letter)
        {
            var label = Canonical(letter.Groups["l"].Value[0]).ToString();
            return options.FindIndex(o => o.Label == label);
        }

        var wanted = value.Trim().TrimEnd('.').Trim();
        if (wanted.Length == 0)
            return -1;
        var matches = options.Select((o, i) => (o.Text, i))
            .Where(x => string.Equals(x.Text.TrimEnd('.').Trim(), wanted, StringComparison.OrdinalIgnoreCase))
            .Select(x => x.i)
            .ToList();
        return matches.Count == 1 ? matches[0] : -1;
    }

    private static bool IsLetterAnswer(string value) => AnswerLetter().IsMatch(value);

    private static void Warn(QuestionBuilder q, string code, string message, int line, bool error) =>
        q.Issues.Add(new ImportIssue(code, error ? ImportSeverity.Error : ImportSeverity.Warning, message, q.Number, line));

    // "Essay", "essay questions", "مقالي" → Essay; "multiple choice", "MCQ", "اختيار من متعدد" → Mcq; otherwise null.
    private static string? KindOf(string value)
    {
        var lower = value.ToLowerInvariant();
        if (lower.Contains("essay") || lower.Contains("written") || lower.Contains("مقال"))
            return Essay;
        if (lower.Contains("mcq") || lower.Contains("multiple") || lower.Contains("اختيار"))
            return Mcq;
        return null;
    }

    private static int ParseNumber(string digits, int fallback) =>
        int.TryParse(NormalizeDigits(digits), NumberStyles.None, CultureInfo.InvariantCulture, out var number) ? number : fallback;

    private static bool TryParseMarks(string value, out decimal marks) =>
        decimal.TryParse(NormalizeDigits(value).Replace(',', '.'), NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out marks);

    private static char Canonical(char letter) =>
        ArabicLetters.TryGetValue(letter, out var latin) ? latin : char.ToUpperInvariant(letter);

    // Arabic-Indic and Extended Arabic-Indic digits become 0-9; the Arabic decimal separator becomes a dot.
    private static string NormalizeDigits(string value)
    {
        var builder = new StringBuilder(value.Length);
        foreach (var c in value)
        {
            builder.Append(c switch
            {
                >= '٠' and <= '٩' => (char)('0' + (c - '٠')),
                >= '۰' and <= '۹' => (char)('0' + (c - '۰')),
                '٫' => '.',
                _ => c,
            });
        }

        return builder.ToString();
    }

    private static string TrimMarks(string value)
    {
        var start = 0;
        var end = value.Length;
        while (start < end && IsPadding(value[start]))
            start++;
        while (end > start && IsPadding(value[end - 1]))
            end--;
        return value[start..end];
    }

    private static bool IsPadding(char c) => char.IsWhiteSpace(c) || Array.IndexOf(DirectionMarks, c) >= 0;

    private static string Excerpt(string value) => value.Length <= 60 ? value : value[..60] + "…";
}
