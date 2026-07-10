<#
.SYNOPSIS
    Fetches Microsoft Clarity live-insights data and stores results as
    per-day JSON files in data/clarity-history/<YYYY-MM-DD>.json.

.DESCRIPTION
    Works both in GitHub Actions (credentials via environment variables) and
    locally (credentials via env vars OR interactive prompt).

    Clarity Data Export API constraints:
      - Returns the last 1-3 days of data only (numOfDays 1-3).
      - Maximum 1,000 rows per request.
      - Maximum 10 requests per day per project — the script skips dates
        that already have a file to protect this quota.

    Credentials (in order of precedence):
      1. Environment variables:  CLARITY_API_TOKEN, CLARITY_PROJECT_ID
      2. Interactive prompt      (only when running in a real terminal)

.PARAMETER NumDays
    How many days of history to request from the API (1-3). Each day is
    stored as a separate file. Defaults to 1 (yesterday only).
    Use 3 for an initial local backfill.

.PARAMETER Force
    Re-fetch and overwrite even if a file for that date already exists.
    Useful for correcting a partial download.

.EXAMPLE
    # Typical daily run (also used by GitHub Actions):
    pwsh scripts/fetch_clarity_data.ps1

.EXAMPLE
    # Local backfill — fetch the last 3 days, overwrite anything stale:
    pwsh scripts/fetch_clarity_data.ps1 -NumDays 3 -Force

.EXAMPLE
    # Set credentials first, then run:
    $env:CLARITY_API_TOKEN  = "your-token"
    $env:CLARITY_PROJECT_ID = "xk5gdi38n4"
    pwsh scripts/fetch_clarity_data.ps1 -NumDays 3
#>
[CmdletBinding()]
param(
    # Number of days to fetch (1-3, limited by the Clarity API).
    [ValidateRange(1, 3)]
    [int]$NumDays = 1,

    # Overwrite existing files instead of skipping them.
    [switch]$Force
)

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------

$apiBase   = "https://www.clarity.ms/export-data/api/v1/project-live-insights"
$outputDir = Join-Path $PSScriptRoot ".." "data" "clarity-history"

# ---------------------------------------------------------------------------
# 1. Resolve credentials
#    Priority: env var → interactive prompt (local only; CI has no stdin)
# ---------------------------------------------------------------------------

$token     = $env:CLARITY_API_TOKEN
$projectId = $env:CLARITY_PROJECT_ID

# Detect whether we are running interactively (not in CI / piped input)
$isInteractive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

if ([string]::IsNullOrWhiteSpace($token)) {
    if ($isInteractive) {
        Write-Host "CLARITY_API_TOKEN env var not set."
        $secureToken = Read-Host "Enter your Clarity API token" -AsSecureString
        # Convert SecureString → plain text (stays in-process, never written to disk)
        $bstr  = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    } else {
        Write-Error "CLARITY_API_TOKEN environment variable is not set. Aborting."
        exit 1
    }
}

if ([string]::IsNullOrWhiteSpace($projectId)) {
    if ($isInteractive) {
        Write-Host "CLARITY_PROJECT_ID env var not set."
        $projectId = Read-Host "Enter your Clarity project ID"
    } else {
        Write-Error "CLARITY_PROJECT_ID environment variable is not set. Aborting."
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 2. Ensure output directory exists
# ---------------------------------------------------------------------------

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "Created directory: $outputDir"
}

# ---------------------------------------------------------------------------
# 3. Loop over each requested day and fetch
#    Day offset 1 = yesterday, 2 = day before yesterday, etc.
# ---------------------------------------------------------------------------

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept"        = "application/json"
}

for ($dayOffset = 1; $dayOffset -le $NumDays; $dayOffset++) {

    $targetDate = (Get-Date).ToUniversalTime().AddDays(-$dayOffset).ToString("yyyy-MM-dd")
    $outputFile = Join-Path $outputDir "$targetDate.json"

    # ---- Skip if file already exists and -Force was not given ----
    if ((Test-Path $outputFile) -and -not $Force) {
        Write-Host "[$targetDate] File already exists — skipping (use -Force to overwrite)."
        continue
    }

    Write-Host "[$targetDate] Fetching data (numOfDays=1) ..."

    # The project is identified by the Bearer token itself — no project ID in
    # the URL path.  numOfDays=1 returns the most-recent day of data.
    $uri = "$apiBase`?numOfDays=1"

    try {
        $response = Invoke-RestMethod `
            -Uri         $uri `
            -Method      GET `
            -Headers     $headers `
            -ErrorAction Stop

    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__

        # 429 = Too Many Requests (rate limit: 10 req/day per project)
        if ($statusCode -eq 429) {
            Write-Warning "[$targetDate] Rate limit reached (HTTP 429) — 10 requests/day cap hit. Stopping here."
            break   # no point trying remaining days; break out of the loop
        }

        # 401 / 403 = authentication problems
        if ($statusCode -in @(401, 403)) {
            Write-Error "[$targetDate] Authentication failed (HTTP $statusCode). Check your CLARITY_API_TOKEN."
            exit 1
        }

        # Any other HTTP / network error
        Write-Error "[$targetDate] API call failed: $_"
        exit 1
    }

    # ---- Persist the response wrapped in a metadata envelope ----
    $envelope = @{
        collectedAt = (Get-Date).ToUniversalTime().ToString("o")  # ISO-8601
        targetDate  = $targetDate
        projectId   = $projectId
        data        = $response
    }

    $envelope | ConvertTo-Json -Depth 20 | Set-Content -Path $outputFile -Encoding UTF8

    Write-Host "[$targetDate] Saved to: $outputFile"
}

Write-Host "Done."
