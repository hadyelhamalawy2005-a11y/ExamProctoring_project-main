# Importing questions from a Word (.docx) file

Instructors can import questions from a Microsoft Word `.docx` file in the dashboard (**Import from Word**, or the same
button on an exam's page). The file is read first and shown for review; **nothing is saved until the instructor confirms.**

A ready-made sample is available in the dashboard ("Download the sample template") and in the repository at
`frontend/public/question-import-template.docx`.

## The format

Write the document the way you normally write an exam; the import understands the usual styles. Each part of a question is
on its own line (its own paragraph, or a line break inside a paragraph). Keywords are not case-sensitive. English and Arabic
can be mixed in one document, and digits can be Western (`1 2 3`) or Arabic-Indic (`١ ٢ ٣`).

```
Examora - Midterm Exam                         <- the first line is suggested as the exam title

Section 1: Multiple Choice Questions
Q1: What does CPU stand for?
A) Central Processing Unit
B) Computer Personal Unit
C) Central Program Utility
D) Control Processing User
Correct Answer: A
Points: 2

س2: ما هي عاصمة فرنسا؟
أ) لندن
ب) باريس
ج) برلين
الإجابة الصحيحة: ب

3. Which is a language? (2 points)             <- bare numbering (1.  2)  3-); points at the end of the line
a. HTML
*b. Python                                      <- a mark on the option instead of an answer line
c. HTTP

Section 2: Essay Questions
Q4: Explain the difference between RAM and storage. (5 points)
Model Answer: RAM is fast temporary memory; storage keeps data permanently.
```

| Part | Accepted writing |
|---|---|
| **Section headings** | `Section 2: Essay Questions`, `Part B`, `Chapter 3`, `القسم الثاني: ...`, `الجزء 3`; also a line that only names a type: `Multiple Choice Questions`, `MCQ`, `Essay`, `الأسئلة المقالية`. A heading ends the previous question and is not part of any question. A heading that names a type is the default type of the questions after it. |
| **Exam title** | `Exam Title: ...` / `عنوان الامتحان: ...`. Without it, the first line of the document is suggested as the title. |
| **Question** | `Question 1:` `Q1.` `Q 1 ...` `Question No. 1 -` `Question #1` `1.` `1)` `1-` `س12:` `س.4` `سؤال 5:` `السؤال 6 -`. The text can continue on the next lines. A bare number (`1.`) starts a question at the start of the document, after a heading, or when it is the next number in sequence. |
| **Option** | `A)` `A.` `A:` `A-` `(A)` `a)` `أ)` `ب)` `ج)` `د)` `هـ)`. Labels A, B, C … in order. Several options on one line are split when separated by a tab or two or more spaces (`A) Paris   B) London`). After `.` `:` `-` a space is required, so `B-52 is a plane` is text. An option can continue on the next lines. |
| **Correct answer** | `Correct Answer: B`, `Answer: B`, `Ans: B`, `Correct: B`, `Correct option: B`, `Answer is B`, `Key: B`, `الإجابة الصحيحة: ب`, `الإجابة: ب`, `الجواب الصحيح: ب`. The value is a letter (`B`, `(b)`, `Option B`, `B) Queue`) **or the exact text of one option** (`Answer: Queue`). Or mark the option itself: `*B) ...`, `B) ... *`, `✓`, `(correct)`, `[correct]`, `(الصحيحة)`. |
| **Points** | `Points: 2`, `Marks: 1.5`, `Score`, `Grade`, `Mark = 2`, `Points - 2`, `الدرجة: 2`, `النقاط: 2`; or at the end of the question line: `(2 points)`, `[3 marks]`, `(3 درجات)`. A positive number, at most 9999.99, at most 2 decimals. **1 is used when missing** (shown in the review, and editable). |
| **Essay** | `Type: Essay`, `(Essay)` in the question line, `Essay Q3:`, an essay heading, or a question that has no options and no answer letter (see below). Its model answer is `Model Answer: ...` or `Answer: ...` (it can continue on several lines). |
| **Type** | `Type: Mcq` / `Type: Essay` / `النوع: مقالي`. Optional. |

Multiple-choice questions need **at least 2 options** and at most the server's maximum (default 8; the dashboard's manual form
has the same limits). An essay question has no options.

**How the question type is decided.** An explicit marker (`Type:`, `(Essay)`, `Essay Q3:`) wins. Otherwise a question with options
is multiple choice. A question without options takes the type of the heading above it (an `Essay` heading → essay; a
`Multiple Choice` heading → still multiple choice, so missing options are reported). With no heading, a question that has no
options **and no answer letter** is imported as an **essay and flagged** ("no options were found, imported as an essay — check
it") so the instructor can confirm or remove it. A question with an answer letter but no options is an error, never an essay.

**Lines that fit nowhere** (a closing remark, a signature, instructions before the first question) are never added to a
question. They are shown as warnings and do not block the import.

## What is checked

The backend reports each problem against its question (`Question 2: the correct answer is missing.`):

- missing question text, missing or unknown type
- fewer than 2 options, more than the maximum, a missing option text
- repeated or out-of-order option labels (`A, A` / `A, C`)
- missing correct answer, an answer that is not an existing option letter (`E`, `Paris`, `A, B`), more than one answer line
- invalid or repeated points
- a line that belongs nowhere (a warning, not an error)
- an answer that names no option, two different correct answers (answer lines and marks that disagree)
- repeated question numbers
- the same rules as the manual question form: text up to 4000 characters, option text up to 1000, marks range and decimals,
  no repeated option text

A question with a problem is still shown in the review. It is marked **Needs attention** and cannot be imported until the
instructor edits it (for example selects the correct option) or removes it from the import. After an edit the question is
checked again, here and by the server when importing.

## File limits and safety

- `.docx` only, at most **10 MB**, at most **200 questions** per import. The content must really be a Word package (a zip
  archive with `word/document.xml`), not just a renamed file.
- Only the text of `word/document.xml` is read. Macros, embedded objects, images and external links are never opened or run.
  XML DTDs and external entities are disabled, and the document part is limited to 20 MB uncompressed (zip-bomb protection).
- Text in tables and text boxes is read; deleted text from tracked changes is not.
- Invisible direction marks (RLM/LRM and similar) at the start or end of a line are ignored; the text itself, Arabic or
  mixed with English, is kept exactly.

## API

Both endpoints are for the **Instructor** role only (Admins and Students get 403; no token gets 401 `token_invalid`).

### 1. `POST /api/questions/import/preview` (nothing is saved)

`multipart/form-data` with one file field named **`file`**.

`200`:

```json
{
  "examTitle": "Introduction to Computer Science",
  "defaultMarks": 1,
  "maxOptions": 8,
  "isValid": true,
  "questions": [
    {
      "number": 1, "line": 2, "type": "Mcq", "text": "What does CPU stand for?",
      "marks": 2, "marksDefaulted": false, "modelAnswer": null,
      "options": [ { "label": "A", "text": "Central Processing Unit", "isCorrect": true } ],
      "issues": []
    }
  ],
  "issues": []
}
```

An issue is `{ "code": "correct_answer_missing", "severity": "error" | "warning", "message": "...", "question": 2, "line": 8 }`.
`isValid` is true when there is at least one question and no issue has severity `error`.

Errors: `400 validation_failed` with the field `file` (no file, empty, not `.docx`, not a valid Word document, too complex);
`413` file or request over 10 MB; `401`; `403`.

### 2. `POST /api/exams/{examId}/questions/import` (saves, all or none)

JSON body: the reviewed questions in the same shape as `POST /api/exams/{id}/questions`:

```json
{ "questions": [ { "type": "Mcq", "text": "…", "marks": 2, "modelAnswer": null,
                   "options": [ { "text": "…", "isCorrect": true }, { "text": "…", "isCorrect": false } ] } ] }
```

`201 { "items": [ QuestionResponse … ] }`, appended after the exam's last question, in order, in one transaction.

Errors: `400 validation_failed` with keys such as `questions[2].options[1].text` (nothing is saved); `404 exam_not_found`
(unknown exam, or another instructor's); `409 exam_not_editable` (cancelled, or already started); `401`; `403`.

Repeating the same request adds the questions again (there is no duplicate detection); the dashboard prevents double
submits by disabling the button and allowing one request at a time.

### Creating a new exam

The Word file has no start time or duration, so for a new exam the dashboard asks for them and then calls the existing
`POST /api/exams` followed by the import above. If the import fails after the exam was created, retrying imports into that
same exam (a second exam is not created); the empty draft can be deleted from the exam page.

## Code

- Backend: `src/ExamProctoring.Application/Exams/Import/` (`DocxTextExtractor`, `QuestionDocumentParser`,
  `QuestionImportService`, models), `QuestionService.ImportAsync`, `src/ExamProctoring.Api/Controllers/QuestionImportController.cs`.
- Tests: `tests/ExamProctoring.UnitTests/Exams/Import/`, `tests/ExamProctoring.IntegrationTests/QuestionImportTests.cs`.
- Frontend: `frontend/src/pages/ImportQuestionsPage.tsx`, `components/ImportQuestionCard.tsx`, `api/questionImport.ts`,
  `utils/importDraft.ts`.
