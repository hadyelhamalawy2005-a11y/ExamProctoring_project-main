# Examora - Flutter app

The mobile app of the AI-based exam proctoring system (graduation project). It runs **standalone**: accounts, exams, attempts,
results and proctoring records live in local storage on the device, and no server is needed or assumed. It is wired so that the
day the backend is ready, the app can switch to it by editing providers only (see "Connecting to the backend").

The specification is `FRONTEND_BUILD_PROMPT.md` (a copy of the text the project owner supplied). Where this build departs from it,
see `DECISIONS.md`. Everything under "What is built" works and is covered by automated tests; everything under "What is NOT
built or not possible" does not, and the app says so where it matters.

## Run it

Requires Flutter 3.47 or newer (Dart 3.13), because the specification's package versions (`flutter_riverpod 3`, `go_router 18`)
need it.

```bash
cd examora_app
flutter pub get
flutter run                    # picks a connected device or emulator
flutter test                   # the automated tests
flutter analyze                # must report "No issues found"
```

On Windows, building an app that uses plugins needs **Developer Mode** (it allows symbolic links): run `start ms-settings:developers`
and switch it on. `flutter test` and `flutter analyze` do not need it.

## The three accounts (created on first launch)

| Role | Email | Password | Name |
|---|---|---|---|
| Student | `student@examora.app` | `Examora#2026` | Malk Mostafa |
| Instructor | `instructor@examora.app` | `Examora#2026` | Ahmed Zahran |
| Administrator | `admin@examora.app` | `Examora#2026` | Mohamed Hatem |

Nobody signs themselves up: there is no registration screen. They are created once, never overwrite an account whose password has
since been changed, and only a salted PBKDF2-HMAC-SHA256 hash is stored (never the password).

## What is built

- **Foundation**: feature-first layout, `Result<T>` / sealed `AppFailure`, hand-written typed JSON, injected clock, strict lints,
  design tokens and shared widgets, English and Arabic (right-to-left), text scaling capped at 1.6.
- **Authentication** (Local; the Api version is written against the real `AuthController`): sign-in, 12-hour session restore,
  sign-out, forced and voluntary password change, lockout after five wrong passwords, no registration screen.
- **Routing**: all 26 routes with real screens, one guard (splash, signed-out, forced password change, role separation), deep links
  remembered through sign-in, every screen has a way back out.
- **Administrator**: paged account list with search and filters, account detail, create instructor and create student (one-time
  temporary-password sheet), deactivate / reactivate with a reason. An administrator cannot deactivate themselves.
- **Instructor, exams**: dashboard with real counts, exam list, two ways to create (manual wizard or Word import), five-step wizard
  (details, questions, settings, schedule, review), publish with every blocking problem listed, return to draft, archive, delete a
  draft, a new version when a published exam's content changes.
- **Word import (.docx)**: reads a template-based document, shows a review of every question with its problems, never guesses an
  answer key or a mark, and reports tables, images and equations it could not import. The template is bundled (`assets/templates`).
- **Student**: dashboard, exam list, briefing, consent, system check (camera test, no video kept), exam player (timer from an
  absolute deadline, every answer saved, resume after a restart, question palette, flag for review, scientific calculator, one-time
  submit, auto-submit at the deadline), result screen and results list. The student never receives the answer key.
- **Marking**: single and multiple choice are marked automatically (all-or-nothing); short answers wait for the instructor, who marks
  them on the attempt review screen (marks above the question's maximum are limited, and the screen says so).
- **Proctoring (what a phone can honestly detect)**: app left the foreground, copy / paste / bulk insertion refused in answer fields,
  connectivity loss, camera unavailable, screenshot blocking (Android FLAG_SECURE channel in `MainActivity.kt`). A sustained-behaviour
  threshold, a warning count and a limit that is announced but never ends the exam. **Proctoring never changes a mark.**
- **Incident review**: queue with filters, incident detail with the whole timeline and warnings, evidence status in words, and a
  decision (violation confirmed / no violation / needs follow-up) with notes. It is the instructor's decision, not a verdict by the app.
- **Local storage**: all of the above works without a server. Each repository has a Local and an Api implementation chosen by one provider.

## What is NOT built or not possible (and why)

| Item | Reason |
|---|---|
| **Retrospective video clips** (evidence) | No Flutter camera plugin keeps a rolling buffer; it needs native MediaCodec / AVAssetWriter. Evidence is shown as "unavailable" and is never fabricated. |
| **Face absent, multiple faces, gaze away, speech, microphone, device interruptions** | No detector exists. These rules are listed in the exam settings as inactive and cannot be switched on. |
| Screenshot *detection* | Android blocks screenshots (FLAG_SECURE) but this build does not report an attempt. |
| Biometric identity check, MFA, kiosk lockdown | Out of scope in the specification. |
| Api repositories for exams, attempts and incidents | The .NET backend lacks the endpoints (see `lib/core/network/missing_endpoints.dart`). The Api classes refuse and name the endpoint; they never fall back to local data. |
| Android and iOS runs | **Not verified.** The Android emulator was not run; the Kotlin channel and the camera were not tried on a device; iOS cannot be built on Windows. Only the web build and the automated tests were run. |
| Camera and screenshot guard on the web | Not available there; the system check says so. |

Three small files are unused since the placeholder screens were replaced (`planned_feature.dart`, `feature_not_built_view.dart`,
`role_dashboard.dart`). They were left because deleting files was not authorised.

## Connecting to the backend

`lib/app/configuration/data_source.dart` holds `dataSourceProvider`; every repository provider switches on it. To move the app to the
server: build with `--dart-define=API_BASE_URL=<address>` and change that provider to `DataSource.api`. No screen, controller or model
changes. An Api repository whose endpoint does not exist refuses with that endpoint's name (shown in the UI) and never falls back to
local data. `lib/core/network/missing_endpoints.dart` is the single list of what the backend team still needs to build.

Note: the existing .NET API has real authentication endpoints, but exam, question, attempt and incident models differ from this app's
(different question types, no settings, no versioning, no attempts or incidents). Those differences are recorded as each feature is built.

## Tests

`flutter test` runs everything. Widget tests build the **real** app (real router, guard, controllers and screens) and replace only
storage, the clock and the cost of password hashing (`test/support/test_harness.dart`).
