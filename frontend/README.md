# Exam Proctoring – instructor web dashboard

A React (TypeScript, Vite) dashboard for instructors to manage their exams on the ASP.NET Core backend in `../src`:
sign in, list and filter exams, create and edit exams, manage MCQ and Essay questions, and publish, unpublish or
cancel exams. It also has a **student sign-up page** (`/register`) and is available in **Arabic (right-to-left, the
default) and English (left-to-right)**.

The student exam-taking pages are **not** built. The backend has no student exam endpoints yet: Step 2.5 is blocked
by the open decision in `architecture-proposal.md` §2.4.

## Backend endpoints used

Every request and response type is in `src/types/api.ts`, mirroring the backend DTOs.

| Area | Endpoints |
|---|---|
| Authentication | `POST /api/auth/login`, `POST /api/auth/refresh`, `POST /api/auth/change-password`, `POST /api/auth/logout` |
| Student sign-up | `POST /api/auth/register` with exactly `fullName`, `email`, `password`, `confirmPassword` (page: `/register`) |
| Exams | `GET /api/exams?status=&page=&pageSize=`, `POST /api/exams`, `GET /api/exams/{id}`, `PUT /api/exams/{id}`, `DELETE /api/exams/{id}` |
| Lifecycle | `POST /api/exams/{id}/publish`, `/unpublish`, `/cancel` |
| Questions | `GET` and `POST /api/exams/{id}/questions`, `PUT` and `DELETE /api/questions/{id}` |

## Requirements

- Node.js 22.12 or later (24 LTS recommended), which includes npm.
- The backend running locally, with its database migrated and a first admin seeded (see below).

## Local development

**1. Start the backend** from the repository root, with the `http` launch profile (the default for this project):

```bash
dotnet run --project src/ExamProctoring.Api --launch-profile http
```

- It listens on `http://localhost:5168` (`src/ExamProctoring.Api/Properties/launchSettings.json`). Check `http://localhost:5168/health`.
- It refuses to start while the database has no admin and `Seed:AdminEmail` and `Seed:AdminPassword` are not configured (User Secrets).
- The optional `https` profile (`--launch-profile https`) listens on `https://localhost:7046` and `http://localhost:5168`. See "Using the HTTPS profile" below.

**2. Install the frontend** (one time):

```bash
cd frontend
npm install
```

An `.env.local` file is **optional**: without it the dev proxy already targets `http://localhost:5168`. To change a setting, copy `.env.example` to `.env.local` and edit it.

**3. Start the frontend:**

```bash
npm run dev
```

Then open `http://localhost:5173` (the port is fixed; the server stops if it is taken).

**Why requests go through a proxy:** in development the Vite server forwards `/api/*` to the backend, so the browser only talks to its own origin and the backend needs no CORS entry.

### Environment variables

All `VITE_*` values are public (they are part of the browser code). Never put secrets in them. They are read from `.env.local` (ignored by Git) or the shell.

| Variable | Default | Meaning |
|---|---|---|
| `VITE_DEV_PROXY_TARGET` | `http://localhost:5168` | Where the dev server forwards `/api`. The backend's `http` profile. |
| `VITE_DEV_PROXY_VERIFY_TLS` | `false` | Only matters for an `https` target. `false` skips the certificate check in the local dev proxy, because Node.js doesn't trust the ASP.NET Core development certificate. |
| `VITE_API_BASE_URL` | empty | Empty = same origin (through the proxy). Set it only to call the backend directly (see below). |

### Using the HTTPS profile

Start the backend with `--launch-profile https` and set, in `.env.local`:

```
VITE_DEV_PROXY_TARGET=https://localhost:7046
```

With this profile, requests to `http://localhost:5168` are redirected to HTTPS, so use the HTTPS URL as the proxy target. The browser still talks only to `http://localhost:5173`.

**4. Sign in with an instructor account.**
1. An admin creates the instructor (`POST /api/admin/instructors`).
2. The instructor signs in with the temporary password.
3. The dashboard then asks for a new password.

### Calling the backend directly (without the proxy)

Set `VITE_API_BASE_URL=http://localhost:5168` (or `https://localhost:7046` with the `https` profile). The backend must then allow the frontend's origin. Today `Cors:WebExamOrigins` in `src/ExamProctoring.Api/appsettings.json` is empty, so browsers block these calls. Adding the origin is a backend configuration change (decision D24) and needs approval. A narrowly scoped development value would be `http://localhost:5173`.

## Languages and right-to-left

- Arabic is the default on a first visit. The toggle ("العربية" / "English") is in the header and on the sign-in, sign-up, change-password and access-denied pages. Switching is instant, keeps the current page and typed input, and does not touch the session.
- Only the language code (`ar` or `en`) is stored, in `localStorage` under `lang`. If storage is blocked the app still works (Arabic, or the last choice until reload).
- `<html lang dir>` is set to `ar`/`rtl` or `en`/`ltr`. The stylesheet uses logical CSS properties (`margin-inline-start`, `text-align: start`, ...); arrows are mirrored in right-to-left. Emails, passwords and times are shown left-to-right; exam and question text uses `dir="auto"`.
- Dates use the browser's time zone and the active language's month names, with Western digits (matching the inputs and the backend). The Arabic font stack uses fonts already on the system (Segoe UI, Tahoma, Noto Naskh/Sans Arabic); no font package is installed.
- Texts live in `src/i18n/en.ts` and `src/i18n/ar.ts`. `ar.ts` is typed from `en.ts`, so a missing or extra key is a TypeScript error (and a test checks that both have the same keys and placeholders).
- **Server messages:** the backend answers in English. Known messages (validation rules, exam conflicts, sign-in errors) are translated in `src/i18n/serverMessages.ts`; error codes and field names are never changed. An unknown message is shown as the server sent it, as left-to-right text.
- To add a text: add the key to `en.ts`, then to `ar.ts`, then use `t('your.key')` from `useI18n()`.

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` | Development server with the API proxy |
| `npm run typecheck` | TypeScript check |
| `npm test` | Unit and component tests (Vitest, Testing Library, jsdom) |
| `npm run build` | Type check, then the production build into `dist/` |

## How the frontend uses authentication

- The access token (15 minutes) is kept **in memory** and sent as `Authorization: Bearer …`.
- The refresh token (7 days) is kept in **sessionStorage**, so a reload in the same tab can continue the session; it is cleared when the tab closes.
- Before the access token expires (30 seconds early), or after a `401 token_invalid`, the client refreshes **once** and retries the request once.
  - The backend rotates refresh tokens and treats a reused one as theft, so refreshes never run in parallel: all requests share one refresh.
- What happens when a refresh fails:

| Server answer to the refresh | What the app does |
|---|---|
| `401 token_invalid` / `refresh_token_reused`, `403 account_deactivated` / `temporary_password_expired`, or any other rejection (for example `400`, `413`) | The session is ended: tokens are cleared and the user is sent to sign in. |
| No answer (network error), `429` (rate limit) or `5xx` (server error) | The session is **kept**; nothing is discarded. If the current access token has **not expired**, the original request is still sent with it. If it has expired, it is never sent: the user sees the error ("Too many attempts", "Cannot reach the server" or "The server had a problem") and can try again. |

- After a page reload the stored refresh token is exchanged once to restore the session ("Restoring your session…").
  - If the server **rejects** the token, the sign-in page opens with the message "Your session has ended. Please sign in again." (only then; a visitor without a session, or a user who clicks Sign out, never sees it).
  - If the restore fails **temporarily** (network, `429`, `5xx`), a "Could not restore your session" screen offers **Try again** and **Sign out**. The stored token is kept, so a retry can succeed.
- `403 account_locked` on change-password is shown as a message; it does not sign the user out.

**Limitation:** any script running on the page could read sessionStorage. The app renders only plain text (React escapes it). The safer alternative, an HttpOnly cookie, would need backend changes; the backend currently returns tokens only in JSON.

**Role check:** the role check in the UI (instructors only) is for convenience. The backend enforces roles, account status and ownership on every request.

## Times

Exam times are entered and shown in the browser's local time zone.
- **Sending:** the start time is sent with the local offset, for example `2026-11-01T09:00:00+03:00`. The backend requires an explicit offset and stores UTC.
- **Receiving:** responses are in UTC and are displayed in local time.
