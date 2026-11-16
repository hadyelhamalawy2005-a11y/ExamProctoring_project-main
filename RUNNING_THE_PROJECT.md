# Running the project

One command, from the repository root, starts the API and the website:

```powershell
.\run-dev.ps1
```

If PowerShell refuses to run scripts ("running scripts is disabled"):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run-dev.ps1
```

When the log says **Ready**, open **http://localhost:5173** in the browser.

| What | Address |
|---|---|
| Website (React, Vite dev server) | http://localhost:5173 |
| API (ASP.NET Core, `http` launch profile) | http://localhost:5168 |
| API health check | http://localhost:5168/health |

The website talks to the API through Vite's proxy (`/api` -> port 5168), so no CORS setup is needed in development.

## What the script does

- Starts `dotnet run --project src/ExamProctoring.Api --launch-profile http` and `npm run dev` (in `frontend/`), with both logs in the same window.
- Installs the frontend packages with `npm ci` the first time (when `frontend/node_modules` is missing).
- If port 5168 or 5173 is already in use, it assumes that service is already running, reuses it, and **never stops it**.
- If either process stops, it prints the exit code and the likely cause, stops the other one and exits with code 1.
- `-SkipBackend` starts only the website, `-SkipFrontend` only the API, `-Https` uses the `https` launch profile (https://localhost:7046 and http://localhost:5168).
- You can still run each part on its own, exactly as before (see `frontend/README.md`).

## Prerequisites

- **.NET SDK** matching `global.json` (10.0.402 or a later patch).
- **Node.js 22.12 or later** (24 LTS recommended), which includes npm.
- **SQL Server** reachable from your machine, with the API's connection string set once in User Secrets:
  ```powershell
  dotnet user-secrets set "ConnectionStrings:Default" "Server=localhost;Database=ExamProctoring;Trusted_Connection=True;TrustServerCertificate=True" --project src/ExamProctoring.Api
  ```
- A first administrator. The API refuses to start while the database has no admin and these are not set:
  ```powershell
  dotnet user-secrets set "Seed:AdminEmail" "you@example.com" --project src/ExamProctoring.Api
  dotnet user-secrets set "Seed:AdminPassword" "<a password that meets the policy>" --project src/ExamProctoring.Api
  ```
  (The database schema is created with the EF Core migrations in `src/ExamProctoring.Infrastructure`; this script does not run or change migrations.)

## Stopping

Press **Ctrl+C** in the window where `run-dev.ps1` runs. It stops the API and the website it started (and everything those started). A service it only reused is left running. If you closed the window without Ctrl+C, check for leftovers:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 5168,5173
```

## If something does not start

| Symptom | Likely cause and fix |
|---|---|
| `'dotnet' was not found` / `'node' was not found` | Install the SDK / Node.js from the prerequisites and open a new terminal. |
| The API stops right away, with "Connection string 'Default' is not configured" | Set `ConnectionStrings:Default` in User Secrets (above). |
| The API stops with a SQL Server error | SQL Server is not running or the connection string is wrong. |
| The API stops with "No admin account exists..." | Set `Seed:AdminEmail` and `Seed:AdminPassword` (above). |
| The site opens but sign-in says it cannot reach the server | The API is not running or not on port 5168. Check http://localhost:5168/health. |
| "Port 5173 is already in use" / the website stops at once | Another program uses 5173 (the Vite config uses `strictPort`). Close it, or run only the API with `-SkipFrontend` and start the site yourself. |
| Packages fail to install | Delete `frontend\node_modules` and run the script again. |
| `Build FAILED` because files are locked | An old API process is still running. Stop it (Ctrl+C in its window) and run again. |

## Checking the project

```powershell
cd frontend; npm run typecheck; npm test; npm run build
cd ..; dotnet build ExamProctoring.slnx
dotnet test tests/ExamProctoring.UnitTests
```

The integration tests (`tests/ExamProctoring.IntegrationTests`) create and delete a separate SQL Server database named `ExamProctoring_Tests`, so run them deliberately, not as part of start-up.
