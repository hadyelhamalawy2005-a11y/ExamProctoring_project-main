# Frontend features waiting for the backend or an AI service

The React frontend shows these features, but they do not work end to end yet. None of them pretends to: nothing is
simulated, no fake data is shown, and no request is sent to an endpoint that does not exist.

## 1. Student accounts are created by an administrator, with identity documents

The public student sign-up page (`/register`, `POST /api/auth/register` from the web app) was removed from the frontend.
Student login is unchanged. The backend sign-up endpoint still exists and was not touched.

The Administrator screen **New student** (`/admin/students/new`, in the admin navigation and on the accounts screen) is
built. It asks for the full name, the email and identity documents:

- **National ID card:** a photo and the National ID number printed on it.
- **College ID card:** a photo and the college student ID printed on it.
- At least one complete pair (photo and number) is required; both may be given. A number without its photo, or a photo
  without its number, is refused. Photos must be JPG, PNG or WebP and at most 5 MB. These are convenience checks in the
  browser only; the backend must repeat every one of them.

**The backend has no student creation endpoint** (`AdminAccountsController` has only `POST /api/admin/instructors`, which is
JSON and has no document fields), so by default the form checks the input and says that nothing was created or uploaded.
It sends no request, shows no success and stores nothing. The identity images and numbers are kept in memory only (never in
localStorage or sessionStorage, never logged); preview URLs are released as soon as a file is replaced, removed or the page
closes. Create Instructor is unchanged.

### Backend work needed

`POST /api/admin/students`, Admin role only, `Content-Type: multipart/form-data`:

| Part | Type | Rule |
|---|---|---|
| `fullName` | text | required; same rules as `CreateInstructorRequest` |
| `email` | text | required; same rules; unique |
| `nationalIdNumber` | text | optional, but required together with `nationalIdImage` |
| `nationalIdImage` | file | optional, but required together with `nationalIdNumber` |
| `collegeStudentId` | text | optional, but required together with `collegeIdImage` |
| `collegeIdImage` | file | optional, but required together with `collegeStudentId` |

- At least one complete pair (`nationalIdNumber` with `nationalIdImage`, or `collegeStudentId` with `collegeIdImage`) must be
  present; both pairs are allowed. Otherwise `400` with field errors keyed by the part names above.
- The frontend sends a pair only when both of its parts are filled in, and sends no role.
- Validate each file on the server: allowed types by content (JPG, PNG, WebP), not by file name or the client's
  `Content-Type`; a size limit (the frontend uses 5 MB); reject empty or corrupt images. Validate the ID numbers' length and
  characters (the frontend allows at most 30 characters, no control characters, and does not assume a national format).
- Store the images securely (outside the web root or in protected storage, random file names, encrypted at rest where
  possible), and the numbers as sensitive data. Do not serve them publicly. Only authorized Admins may read them, through an
  authenticated and audited endpoint. Do not log their contents or the ID numbers.
- Response `201`: `{ id, fullName, email, role: "Student", temporaryPassword, temporaryPasswordExpiresAt }`. It must not
  contain the images, their paths or URLs, or the ID numbers. The account is `Active` and must change its temporary password
  at first sign-in. The role is set by the server from the endpoint.
- `409 duplicate_account` for an existing email. Consider also rejecting an ID number already used by another student.
- Create the account and store the documents atomically: if storing a document fails, no account is created.
- Rate-limit the endpoint and set a request-size limit for the multipart body.

To switch the screen on after the backend ships: build the frontend with `VITE_ADMIN_CREATE_STUDENT=true`. Keep it off
until then.

Optional later: an Admin screen to view a student's identity documents (not built, and not part of the creation response).

## 2. Auto-Completion setting of a code question

- Frontend property: `autoCompletionEnabled: boolean` (`src/types/code.ts`). It replaces the old `autocomplete` flag and the
  removed Evaluation option (`evaluation`). Questions saved earlier in the browser are read into the new shape.
- It controls the editor's own suggestions (CodeMirror: words from the code and the language's keywords). It is not AI
  code completion and it is not grading.
- Code questions are still stored in the browser only (`src/local/examExtras.ts`); no API field is sent.
- Future contract: a boolean `autoCompletionEnabled` on the code question resource, defaulting to `true`.

## 3. Starter code

The manual Starter Code field was removed. The form shows a note that starter code will be generated automatically.
Students currently start with an empty editor.

Needed: an AI service that returns starter code from the question text and the selected language, and a backend endpoint
that stores or serves it. The frontend has no generation call and no sample output.

## 4. Finished exam status

Frontend: `ExamStatus` includes `'Finished'`; the status badge, the Finished tab in Exam Management and the actions of a
finished exam (no publish, unpublish, cancel, delete or edit; an explanatory note) are in place. The browser clock is never
used to decide that an exam is finished.

Backend change needed to activate it:

1. `GET /api/exams` and `GET /api/exams/{id}` return `status: "Finished"` when the exam's scheduled end (`startsAt` plus
   `durationMinutes`) has passed. It should be derived or persisted by the server, not set by clients.
2. `GET /api/exams?status=Finished` is accepted as a filter. Today the backend rejects it ("Status must be Draft, Published
   or Cancelled.").
3. Decide how Finished relates to Cancelled (a cancelled exam should stay Cancelled) and to the existing `phase` value.

Until then the Finished tab is shown but never asks the server for it, and says that the server does not report finished
exams. When the backend is ready, build the frontend with `VITE_FINISHED_STATUS=true` so the tab sends
`status=Finished`. The Home page has no Finished card for the same reason.
