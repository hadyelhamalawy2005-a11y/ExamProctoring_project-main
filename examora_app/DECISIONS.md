# Decisions and deviations

Where this build differs from `FRONTEND_BUILD_PROMPT.md`, and why. Nothing here was decided silently.

## 1. Arabic and English instead of "English only" (owner decision)

The specification says twice: "English only. No localisation system, no language picker." The project owner then asked for
"Arabic/English support" for the Flutter app and, when asked which governs, chose **English + Arabic (RTL)**. So the spec's
English-only rule is overridden. Consequences:

- A typed text interface (`AppStrings`) with `EnglishStrings` and `ArabicStrings`. A text missing from either is a compile error.
  No code generation and no extra package (`flutter_localizations` is part of the Flutter SDK; it makes Material widgets speak Arabic).
- A language switcher on sign-in, forgot-password, change-password and the profile. Only the language code is stored
  (`preferences.language`). With nothing chosen the app follows the device language (Arabic device -> Arabic, otherwise English).
- Every contract text the specification fixes in English ("Incorrect email or password.", "Accounts are created by your
  administrator.") exists in English exactly as written, and in Arabic.
- Server text (always English) is shown as sent, isolated left-to-right inside Arabic text. It is never translated by guessing.

## 2. The specification file

`docs/FRONTEND_BUILD_PROMPT.md` was named in one request but does not exist in the repository. The specification text pasted by the
owner is the authority; it is saved unchanged as `examora_app/FRONTEND_BUILD_PROMPT.md`.

## 3. Route count

The specification says "27 routes" but its table lists **26** (4 shared, 9 student, 9 instructor, 4 administrator). All 26 listed
routes are implemented. If a 27th was intended, it is not in the text.

## 4. Flutter version

Flutter 3.24.5 (the version first installed) cannot resolve `flutter_riverpod ^3` or `go_router ^18`. Flutter 3.47.8 (Dart 3.13.7) was
installed side by side at `C:\flutter\sdk-3.47.8` (checksum verified); the older SDK and the global PATH were not touched.

## 5. PBKDF2 cost

The spec requires a salted PBKDF2 hash. Pure-Dart PBKDF2 is slower than native, so the cost is 120,000 iterations of HMAC-SHA256 (OWASP
recommends 600,000 for native code), run in a background isolate. The iteration count is stored inside each hash, so it can be raised
later without invalidating existing hashes. It is checked against the published PBKDF2-HMAC-SHA256 test vectors.

## 6. Account lockout

Five wrong passwords lock an account for 15 minutes (mirroring the backend). A locked account answers differently from a wrong
password, so after five attempts on a real address that address can be told apart from an unknown one. The specification's "same
message" rule applies to a wrong password and an unknown email, and that holds.

## 7. Placeholder screens (replaced)

Every route now has a real screen. The old placeholder widgets are unused and were left in place (deleting files was not authorised).

## 8. Which proctoring rules can be switched on

Only six rules have a detector a phone can honestly run (`IncidentCategory.hasDetector`). The rest (device interruption, microphone,
gaze, face absent, multiple faces, speech) are listed but inactive. The detector and evidence interfaces exist, with a
`NullDetectorSuite` and an `UnavailableEvidenceBuffer`, so a real detector can be added later without touching the screens.

## 9. The warning limit

Reaching the limit is announced once and flagged for the instructor. Nothing ends the exam: an automated rule must not decide a
student's exam. Proctoring never affects marks (the grader has no incident input).

## 10. Camera

The camera is only tested before the exam (a preview, no frames kept). No video is recorded or stored.

## 11. Results

A result with a short answer still waiting is shown as not final. A held-back result is not sent to the student at all, and the
student types have no answer-key fields.

## 12. Editing a published exam

Until it opens, content changes bump the version. Attempts keep a snapshot of the exam they started, so later edits never change a
started attempt.

## 13. Word import

Marks are never defaulted, answer keys are never inferred, a guessed question type must be confirmed by the instructor, and
everything not imported (tables, images, equations, deleted or hidden text) is reported.

## 14. Backend gaps

`lib/core/network/missing_endpoints.dart` lists every endpoint the .NET backend lacks. Each Api repository refuses with the
missing endpoint's name instead of falling back to local data.
