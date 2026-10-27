Build Examora — the Flutter mobile app of an AI-based exam proctoring system,
a university graduation project. Build the whole thing: there is no existing
Flutter code to extend.

The app runs STANDALONE. There is no backend, none is reachable, and you
must not assume one. Accounts, exams, attempts, results and proctoring
records all live in local storage on the device. Everything must work, and
be demonstrable, with no server running at all.

A backend IS being built in parallel, and the app must be ready to connect
to it the day it is finished — with no rewrite. That readiness is a hard
requirement of this build, not a later clean-up:

  * Every data operation sits behind a repository INTERFACE in the feature's
    domain layer. Screens and controllers depend only on the interface and
    must never know where data came from.
  * Each interface gets TWO implementations from the start: a Local one that
    the app uses today, and an Api one written against HTTP. Both live in
    the tree and both compile.
  * A single Riverpod provider per repository chooses between them. Swapping
    the whole app to the server must be an edit to those providers and
    nothing else — no screen, no controller, no model may change.
  * Build the HTTP plumbing now even though nothing calls it: a typed API
    client, RFC 9457 ProblemDetails parsing (the human-readable text lives in
    `detail`, with a stable `code` extension and field errors under `errors`
    keyed in camelCase), typed failure mapping, timeouts, bearer-token
    attachment, and single-flight token refresh with one retry.
  * Models carry fromJson/toJson even where only local storage reads them,
    so the wire format is settled before the server exists.
  * An Api implementation that has no endpoint yet must REFUSE, naming the
    endpoint it needs, and must never fall back to the local one. Keep that
    list of missing endpoints in one file so the backend team has a single
    source for what to build.
  * Test the Api implementations now, against a mocked HTTP client, asserting
    the exact request shapes and response parsing. On the day the server
    arrives, those tests are what tell you whether it matches.

=========================================================================
THE ONE RULE THAT OUTRANKS EVERYTHING
=========================================================================

Never fabricate. This is an exam-integrity product: a number it shows can
decide whether a student passes, and a record it shows can start a
misconduct hearing.

  * Never invent a mark, an answer key, a detection, a video clip or an
    evidence reference.
  * Never report that something was saved to a server when it was not.
  * When a capability does not exist, say so in the UI, in plain words, and
    name what is missing. A feature that cannot work must fail visibly, not
    quietly return something plausible.
  * Where a value is defaulted because the source did not supply one, say
    so and make the user confirm it.

If you cannot build something honestly, leave it unbuilt and write down why.

=========================================================================
ROLES AND THE THREE ACCOUNTS
=========================================================================

Three roles: Student, Instructor, Administrator.

NOBODY SIGNS THEMSELVES UP. There is no registration screen and no sign-up
link. An administrator creates every account and hands over a temporary
password. Build the login screen with no "create account" path, and say on
it: "Accounts are created by your administrator."

Seed exactly these three accounts on first launch, idempotently, never
overwriting an account whose password has since been changed:

  Student        student@examora.app     Examora#2026   Malk Mostafa
  Instructor     instructor@examora.app  Examora#2026   Ahmed Zahran
  Administrator  admin@examora.app       Examora#2026   Mohamed Hatem

Store only a salted PBKDF2 hash, never the password. A wrong password and an
unknown email must give the SAME message ("Incorrect email or password."),
so the screen cannot be used to discover who has an account.

=========================================================================
STACK AND ARCHITECTURE
=========================================================================

Flutter stable, Dart 3. Packages — add nothing else without justifying it:

  flutter_riverpod ^3   state AND dependency injection, one library not two
  go_router ^18         declarative routes with a redirect guard
  flutter_secure_storage  session material only
  shared_preferences    non-sensitive local data
  http                  the future API client
  file_picker, archive, xml   .docx import
  camera, permission_handler, connectivity_plus
  url_launcher          handing credentials to a mail app
  uuid, intl, collection, meta, crypto

Feature-first layout. Each feature splits into domain (models and rules),
data (repositories), presentation (controllers and screens):

  lib/app/        app.dart, configuration/, router/, theme/
  lib/core/       errors/, result/, network/, storage/, security/,
                  validation/, utilities/, widgets/
  lib/features/   authentication, student_dashboard, instructor_dashboard,
                  admin, exams, word_import, exam_session, proctoring,
                  incident_review, results, profile

Decisions to follow, with the reasons that make them non-negotiable:

  * Result<T> instead of exceptions across repository boundaries. A sealed
    Ok/Err pair makes Dart's exhaustive switch turn a missed failure case
    into a compile error. Failures are a sealed AppFailure hierarchy, each
    carrying a message written to be shown to a user.
  * No code generation. Hand-written fromJson/toJson. Slightly more typing,
    no build_runner step to break for a student team.
  * Typed JSON everywhere. Nothing indexes a raw map. A JsonReader validates
    each field's presence and type and names the offending field on failure.
    An unrecognised role is a HARD PARSE ERROR, never a default — so a bad
    payload can never hand a student instructor privileges.
  * An injected clock (AppClock). The exam timer and the sustained-behaviour
    threshold are then tested with a fake clock and no real delays.
  * Every repository is behind an interface with a local implementation now
    and an API implementation later. Both exist in the tree; a provider
    chooses. Switching sources must never change a screen.
  * English only. No localisation system, no language picker.

analysis_options.yaml must go beyond flutter_lints: un-awaited futures,
uncancelled subscriptions, unclosed sinks, and BuildContext use after an
await are ERRORS, not hints. Public API documentation is enforced.
`flutter analyze` must finish with zero issues at every stage.

=========================================================================
ROUTING — 27 ROUTES, ONE GUARD
=========================================================================

  /                                     splash, session restore
  /login                                /forgot-password
  /change-password                      forced or voluntary

  /student/dashboard  /student/exams  /student/results  /student/profile
  /student/exams/:examId               briefing
  /student/exams/:examId/consent       /student/exams/:examId/system-check
  /student/attempts/:attemptId         player
  /student/attempts/:attemptId/result

  /instructor/dashboard  /instructor/exams  /instructor/incidents
  /instructor/profile
  /instructor/exams/new/method          choose creation method
  /instructor/exams/:examId/edit        authoring wizard
  /instructor/exams/:examId/import      Word import
  /instructor/exams/:examId/attempts
  /instructor/incidents/:incidentId

  /admin/accounts  /admin/accounts/:accountId
  /admin/instructors/new  /admin/profile

One top-level redirect, in this order:

  1. While the stored session is being resolved, hold on the splash screen,
     so a signed-in user is never flashed the login screen on launch.
  2. Not signed in → only the auth routes are reachable.
  3. A pending password change outranks everything: the ONLY reachable
     screen is /change-password. It explains why and offers signing out.
  4. Role separation: each role reaches only its own area; anything else
     redirects to that role's home rather than to a dead end.

Student and instructor areas use a bottom-navigation shell. The admin area
does not, so EVERY admin screen must be PUSHED, never `go` — replacing the
route there leaves the user stranded with no back button. Declare literal
paths like `/instructor/exams/new/method` and `/admin/instructors/new`
BEFORE their `:id` siblings, or `new` is read as an id.

Deep links must obey all of this. Test it.

=========================================================================
FEATURES
=========================================================================

-------------------------------------------------------------------------
1. AUTHENTICATION
-------------------------------------------------------------------------
Login, splash/session restore, logout, change password, a forgot-password
screen that explains there is no automatic reset and to ask an administrator.

Sessions live in secure storage and expire after 12 hours. Restoring
re-reads the account, so a role or password change elsewhere in the app is
reflected after a restart; if the account is gone, the session is cleared.

Signing out always succeeds locally. The user asked to leave; a failure
elsewhere must not trap them.

A temporary password sets mustChangePassword, and the router then allows
only the change-password screen.

-------------------------------------------------------------------------
2. ADMINISTRATION — the only way accounts exist
-------------------------------------------------------------------------
  * Account list: filter by role (Student / Instructor) and by status
    (Active / Deactivated), paged, newest first. Administrators are never
    listed — one must not be able to deactivate another or lock themselves
    out. Badge locked and must-change-password accounts rather than hiding
    them. The filter bar must WRAP, not scroll horizontally: four chips plus
    a clear button overflow a phone's width and the last controls become
    unreachable.
  * Account detail: every field, times in the device's zone with the zone
    named. Actions: issue temporary password, deactivate, reactivate.
  * Create account: ONE screen, with a segmented control choosing Instructor
    or Student. Both are real.
  * Deactivation REQUIRES a reason, 1–500 characters. Reactivation's reason
    is optional. The dialog must own its TextEditingController in a
    StatefulWidget — disposing it from the future's whenComplete is used
    after disposal while the dialog animates away.
  * Changing a status that already matches is reported as a conflict, not
    swallowed as a no-op.

THE TEMPORARY PASSWORD IS SHOWN ONCE. A bottom sheet that cannot be
dismissed by tapping outside or swiping, saying plainly it will not be shown
again, with: Copy, "Send by email" (opens the admin's own mail app with a
prefilled message via url_launcher — there is no server to send mail, and
SMTP credentials must never live in a mobile app), and "I have saved it".
Never persist, cache or log the password.

A created account must REALLY be able to sign in with the password shown.
Test that end to end — otherwise the administrator has handed someone a dead
account.

-------------------------------------------------------------------------
3. EXAM AUTHORING
-------------------------------------------------------------------------
"Create exam" opens a method choice with EXACTLY TWO options:
  * Create manually
  * Import from Word
Do NOT offer AI generation from lecture PDFs. It is a separate planned
feature with no implementation anywhere; offering it promises something
nothing can do.

Both methods go to the wizard FIRST, to capture the exam details. Opening
the importer for an unsaved, untitled exam ends in a save failure the
instructor cannot act on, because nothing ever asked them for a title.

Wizard steps: details → questions → settings → schedule → review/publish.

Exam: title, course name, description, instructions, duration, availability
window, pass mark, status (draft / scheduled / ongoing / completed /
archived), version, questions, settings.

Settings: randomize question order, randomize option order, calculator
enabled, allow backward navigation, show result immediately, show
explanations with result, enabled proctoring rules, sustained-behaviour
threshold (default 10s), evidence buffer (default 3s), max warnings.

Question types: singleChoice, multipleChoice (ALL-OR-NOTHING scoring —
partial credit is a course policy, not an app decision), shortText (never
auto-graded; flagged for manual marking). Options carry STABLE IDS.

Publishing is refused, with the specific reason, when: there are no
questions; a question has no correct answer; a question is still flagged for
review; the answer key is stale; the start time has passed.

An exam's version increments when student-visible content changes, so an
attempt that began against an older snapshot is detectable.

-------------------------------------------------------------------------
4. WORD IMPORT (.docx) — real parsing, on the device
-------------------------------------------------------------------------
Read a genuine .docx: open the ZIP, parse word/document.xml, rejoin split
runs, ignore tracked-change deletions. Reject an older .doc or a PDF renamed
.docx with an explanation. Maximum 10 MB, checked before parsing.

Template: `Question 1 [MCQ]`, `A.` options, `Correct Answer: C`, `Marks: 1`,
optional `Difficulty:` and `Topic:`. Ship the template as an asset and show
it from a help button.

Review screen:
  * Summary: "N found · X ready · Y need attention · Z not imported".
  * A filter for only the questions needing attention.
  * Per question: status as a WORD not just a colour, type, editable text,
    options with exactly one correct for single choice, marks, model answer,
    localized issue messages, and a collapsible "As written in the document"
    showing the verbatim source — so an edit can always be told apart from
    what the file actually said.
  * Sections for text that belonged to no question, and for content that
    could not be imported (images, tables, equations). Report them; a
    silently dropped paragraph is how a question goes missing.

NEVER invent a missing mark or infer an answer key. A question with no
`Marks:` line must raise a visible warning and must not reach "ready" — a
silent default puts a number on a paper that nobody chose.

Continue only when at least one question remains and all retained questions
pass the same validation manual authoring uses.

-------------------------------------------------------------------------
5. EXAM SESSION
-------------------------------------------------------------------------
Briefing → consent → system check → player.

  * The timer is recomputed from the DEADLINE, never counted down from a
    duration. Backgrounding the app, killing it, or changing the device
    clock must not gain a single second.
  * Autosave every answer. Resuming restores the answers and does NOT extend
    the deadline.
  * Auto-submit fires exactly once at the deadline.
  * Submitting twice returns the original result; it never grades twice.
  * ANSWERS REFERENCE OPTION IDS, NEVER POSITIONS. This is what makes
    randomisation safe. Prove with a test that a randomised attempt grades
    identically to an ordered one.
  * A scientific calculator: arithmetic with correct precedence,
    trigonometry in degrees and radians, division by zero and domain errors
    handled. Write your own expression evaluator — it must be impossible to
    evaluate anything resembling code.
  * Copy and paste blocked in the app's own answer fields, and bulk text
    insertion detected.

-------------------------------------------------------------------------
6. PROCTORING — build only what is real
-------------------------------------------------------------------------
IMPLEMENT:
  * A consent screen before any camera use.
  * A system check that genuinely initialises and previews the camera, and
    reports honestly when there is no camera.
  * App-lifecycle monitoring: leaving the app is DETECTED, not prevented.
  * Clipboard restriction and bulk-insertion detection.
  * Connectivity monitoring — losing the network must not end the exam.
  * Android FLAG_SECURE to block screenshots.
  * THE SUSTAINED-BEHAVIOUR THRESHOLD: a behaviour must persist for the
    configured time (default 10s) before it is an incident. The timer resets
    when the behaviour stops, so nine separate one-second glances never
    accumulate into one. Some categories bypass it and fire immediately.
    This is the single most-tested piece of logic in the app.

DO NOT IMPLEMENT, AND SAY SO IN THE UI:
  * The retrospective video buffer. No Flutter camera plugin supports
    retroactive capture; it needs Android MediaCodec with a circular buffer
    and iOS AVAssetWriter. Define the interface, have it report
    "unavailable", and NEVER fabricate a clip. The repository must reject
    any attempt to mark evidence as captured without a real reference.
  * Face, gaze and speech detection. Define the detector interfaces, wire up
    a NullDetectorSuite that produces nothing, and state that those rules
    are inactive. Never present a no-op as a working AI detector.
  * Biometric identity verification, MFA, kiosk lockdown.

Impossible for any app, so out of scope and worth stating: a second device,
a photograph of the screen, a person off-camera, notes on paper.

Incident categories: appBackgrounded, windowFocusLost, deviceInterrupted,
clipboardAttempt, screenshotDetected, cameraUnavailable,
microphoneUnavailable, networkLost, gazeAway, faceAbsent, multipleFaces,
speechDetected. Severity: low / medium / high / critical. Detection source
must be recorded honestly: appLifecycle, platformApi, appUi, deviceHardware,
connectivity, aiDetector, manual.

-------------------------------------------------------------------------
7. INCIDENT REVIEW, GRADING AND RESULTS
-------------------------------------------------------------------------
  * An instructor reviews incidents for exams they own: a queue, a detail
    screen with the timeline and evidence STATUS, and a decision
    (noViolation / violationConfirmed / inconclusive) with notes.
  * Grading: single choice and multiple choice all-or-nothing, short text
    flagged for manual marking, marks clamped to what the question offers.
  * PROCTORING WARNINGS MUST NEVER CHANGE A MARK. Not a deduction, not a
    cap. Write a test that asserts it.
  * Student results, and per-exam attempts for the instructor.

-------------------------------------------------------------------------
8. DASHBOARDS AND PROFILE
-------------------------------------------------------------------------
A home and a profile for each role. The profile shows identity, where data
lives, a privacy summary of what is collected during an exam, change
password, and sign out. Every list has correct loading, empty, error and
offline states — an empty list must never be shown where an error belongs,
because "you have no exams" is a very different statement from "this did not
load".

=========================================================================
DESIGN
=========================================================================

A design-token file: AppColors, AppSpacing, AppRadii, AppIconSizes,
AppDimensions, AppDurations, AppTypography. No literal colours or spacings
in widgets.

Shared widgets: AppButton (with a busy state), AppCard, AppTextField,
AppDialogs, AppLoadingView, AppEmptyView, AppErrorView (with retry),
ResponsiveContent, AppSectionHeader.

Mobile-first: design at 420×900 and check it. Prefer Wrap over Row where
content can grow. Status must never be carried by colour alone — always a
word as well. Assert the WCAG contrast ratios you claim, in tests. Cap text
scaling at 1.6 so an exam's layout cannot break at the largest accessibility
sizes.

AppErrorView should show the missing endpoint when a failure carries one:
"this has not been built yet" is a different conversation from "it broke".

=========================================================================
TESTING
=========================================================================

Aim for 400+ tests. Run `flutter analyze` and `flutter test` after each
feature and keep both green. Never weaken an assertion, skip a test or
delete one to get a green run — if a test fails, either the code is wrong or
the test was, and you must say which.

Must be covered:
  * The three seeded accounts each sign in through the REAL login screen and
    land on the right home; a wrong password and an unknown email give the
    same message.
  * An account created by the administrator can actually sign in with the
    password shown.
  * Routing: deep links cannot bypass login; roles cannot cross; the
    forced-password-change gate; every screen has a way back out.
  * The sustained-behaviour threshold: fires at the threshold not before,
    resets when the behaviour stops, nine one-second glances never
    accumulate, immediate categories bypass it.
  * The timer: recomputed from the deadline so backgrounding gains nothing;
    auto-submit fires once.
  * Grading: every type, all-or-nothing, manual marking, clamping, and that
    warnings never change marks.
  * Randomisation: a randomised attempt grades identically to an ordered one.
  * The calculator: arithmetic, precedence, trig in both units, division by
    zero, domain errors, and that nothing resembling code can be evaluated.
  * Word import: the documented template parses; a missing or ambiguous
    answer is FLAGGED, NEVER GUESSED; a renamed .doc and a PDF are rejected;
    split runs rejoin; tracked deletions are ignored.
  * Attempts: resume keeps answers and does not extend the deadline;
    duplicate submission returns the original result.
  * Security: a student cannot obtain an answer key, read another student's
    attempt, or review their own incident; an instructor cannot touch
    another's exam.
  * Design tokens: every contrast ratio you quote.
  * The Api repositories, against a mocked HTTP client: exact request shapes,
    response parsing, ProblemDetails mapping, and that an endpoint which does
    not exist refuses by name instead of falling back to local data.

Use a widget-test harness that builds the REAL app with the real router and
real screens, replacing only storage, the clock and platform services. A
routing test must exercise the guard the app actually uses, not a copy.

=========================================================================
WHAT NOT TO DO
=========================================================================

  * No registration or sign-up anywhere.
  * No demo-mode labelling and no second "fake" data source. There is one
    source today: the device. Do not add a banner implying the data is not
    real.
  * No AI-generation option in the UI.
  * No localisation system; English only.
  * No hard-coded IP addresses, secrets or tokens. The future API base URL
    comes from --dart-define and nothing else.
  * Never log a password, a token or a question paper.
  * Do not commit, push or reset anything without being asked.

=========================================================================
DELIVERABLES
=========================================================================

1. The app, running on at least one simulator, with the three accounts
   working.
2. A README: how to run it, the three accounts, what each role can do, and
   an HONEST list of what is not implemented with the blocker for each.
3. One file listing every endpoint the Api implementations need but the
   backend does not yet provide — the handover list for the backend team.
4. A report: every command you ran and its REAL output; the test count; what
   you verified and on what (simulator is not a physical device, and a
   passing test is not a working camera); and every assumption you made.

Say plainly what you did not verify. An untested claim is worse than no
claim — especially in a system that decides whether someone passed.
