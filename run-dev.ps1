<#
.SYNOPSIS
  Starts the whole web project for development: the ASP.NET Core API and the React (Vite) site.

.DESCRIPTION
  Run from the repository root:   .\run-dev.ps1

  - Backend : dotnet run --project src/ExamProctoring.Api --launch-profile http   -> http://localhost:5168
  - Frontend: npm run dev (in frontend/)                                          -> http://localhost:5173
  Both write to this window. If either stops, the other is stopped too and the reason is printed.
  Ctrl+C stops both. Only the processes this script started are ever stopped.
  If a port is already in use (for example you already run the API), that service is reused and left alone.

.PARAMETER SkipBackend
  Start only the React site (it expects the API on port 5168).

.PARAMETER SkipFrontend
  Start only the API.

.PARAMETER Https
  Start the API with the "https" launch profile (https://localhost:7046 and http://localhost:5168).
#>
[CmdletBinding()]
param(
  [switch]$SkipBackend,
  [switch]$SkipFrontend,
  [switch]$Https
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$apiProject = Join-Path $root 'src\ExamProctoring.Api'
$webDir = Join-Path $root 'frontend'
$apiPort = 5168
$webPort = 5173
$apiUrl = "http://localhost:$apiPort"
$webUrl = "http://localhost:$webPort"

function Write-Step([string]$text) { Write-Host "[run-dev] $text" -ForegroundColor Cyan }
function Write-Problem([string]$text) { Write-Host "[run-dev] ERROR: $text" -ForegroundColor Red }

function Test-PortInUse([int]$port) {
  [bool](Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
}

function Test-Tool([string]$name, [string]$hint) {
  if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
    Write-Problem "'$name' was not found. $hint"
    exit 1
  }
}

# Stops a process and everything it started (dotnet run starts the real server as a child). Only used on our own PIDs.
function Stop-Tree([System.Diagnostics.Process]$process) {
  if ($null -eq $process) { return }
  try {
    if (-not $process.HasExited) { & taskkill.exe /PID $process.Id /T /F 2>&1 | Out-Null }
  } catch { }
}

# ---- prerequisites ----
if (-not $SkipBackend) { Test-Tool 'dotnet' 'Install the .NET SDK version named in global.json (https://dotnet.microsoft.com/download).' }
if (-not $SkipFrontend) {
  Test-Tool 'node' 'Install Node.js 22.12 or later (24 LTS recommended).'
  Test-Tool 'npm.cmd' 'npm comes with Node.js.'
}

$started = @()   # [pscustomobject]@{ Name; Process }
$reused = @()

try {
  # ---- backend ----
  if (-not $SkipBackend) {
    if (Test-PortInUse $apiPort) {
      Write-Step "Port $apiPort is already in use: assuming the API is already running and reusing it (it will not be stopped)."
      $reused += 'API'
    } else {
      $launchProfile = if ($Https) { 'https' } else { 'http' }
      Write-Step "Starting the API ($launchProfile profile) on $apiUrl ..."
      $api = Start-Process -FilePath 'dotnet' -ArgumentList @('run', '--project', $apiProject, '--launch-profile', $launchProfile) `
        -WorkingDirectory $root -NoNewWindow -PassThru
      $started += [pscustomobject]@{ Name = 'API'; Process = $api }
    }
  }

  # ---- frontend ----
  if (-not $SkipFrontend) {
    if (Test-PortInUse $webPort) {
      Write-Step "Port $webPort is already in use: assuming the React site is already running and reusing it (it will not be stopped)."
      $reused += 'React site'
    } else {
      if (-not (Test-Path (Join-Path $webDir 'node_modules'))) {
        Write-Step 'Installing the frontend packages (first run only): npm ci ...'
        Push-Location $webDir
        try {
          & npm.cmd ci
          if ($LASTEXITCODE -ne 0) { Write-Problem "npm ci failed (exit code $LASTEXITCODE)."; exit 1 }
        } finally { Pop-Location }
      }
      Write-Step "Starting the React site on $webUrl ..."
      $web = Start-Process -FilePath 'npm.cmd' -ArgumentList @('run', 'dev') -WorkingDirectory $webDir -NoNewWindow -PassThru
      $started += [pscustomobject]@{ Name = 'React site'; Process = $web }
    }
  }

  if ($started.Count -eq 0) {
    Write-Step 'Nothing to start: everything requested is already running.'
    Write-Step "Open $webUrl"
    exit 0
  }

  # ---- wait until the API answers, then say where to go ----
  $announced = $false
  $deadline = (Get-Date).AddSeconds(90)
  while ($true) {
    foreach ($item in $started) {
      if ($item.Process.HasExited) {
        Write-Problem "$($item.Name) stopped with exit code $($item.Process.ExitCode). Stopping the rest."
        if ($item.Name -eq 'API') {
          Write-Host '  Common causes: the SQL Server connection string is not configured (user secrets key ConnectionStrings:Default),' -ForegroundColor Yellow
          Write-Host '  the database is not reachable, or no admin exists and Seed:AdminEmail / Seed:AdminPassword are not set.' -ForegroundColor Yellow
          Write-Host '  See RUNNING_THE_PROJECT.md, "If something does not start".' -ForegroundColor Yellow
        } else {
          Write-Host '  Common causes: port 5173 is taken by another program, or the frontend packages are broken (delete frontend\node_modules and run again).' -ForegroundColor Yellow
        }
        exit 1
      }
    }

    if (-not $announced) {
      $apiReady = $SkipBackend -or ($reused -contains 'API')
      if (-not $apiReady) {
        try { $apiReady = (Invoke-WebRequest -Uri "$apiUrl/health" -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $apiReady = $false }
      }
      $webReady = $SkipFrontend -or ($reused -contains 'React site') -or (Test-PortInUse $webPort)
      if ($apiReady -and $webReady) {
        Write-Host ''
        Write-Step "Ready.  Open the website:  $webUrl     (API: $apiUrl, health: $apiUrl/health)"
        Write-Step 'Press Ctrl+C to stop what this script started.'
        Write-Host ''
        $announced = $true
      } elseif ((Get-Date) -gt $deadline) {
        Write-Step "Still starting after 90 seconds. Check the log lines above; the script keeps waiting."
        $announced = $true
      }
    }
    Start-Sleep -Seconds 1
  }
}
finally {
  if ($started.Count -gt 0) {
    Write-Host ''
    Write-Step 'Stopping what this script started ...'
    foreach ($item in $started) { Stop-Tree $item.Process }
    Write-Step 'Stopped.'
  }
}
