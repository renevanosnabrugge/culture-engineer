#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Compile GitHub Agentic Workflows (gh-aw) markdown sources into their
    executable .lock.yml files.
.DESCRIPTION
    Runs `gh aw compile`, which reads every workflow .md file in
    .github/workflows/ and (re)generates the matching .lock.yml — the file
    GitHub Actions actually executes. Compilation only needs to be re-run when
    a workflow's YAML frontmatter changes (permissions, tools, safe-outputs,
    triggers, etc.) — the markdown instructions body is loaded at runtime and
    can be edited without recompiling.

    The generated/updated .lock.yml files (and .github/aw/actions-lock.json,
    which pins action SHAs) must be committed — GitHub Actions has no
    knowledge of gh-aw or .md workflows, it only runs the compiled .yml files.

    This script does not commit or push anything itself — review the diff and
    commit manually once you're happy with it.
.PARAMETER Workflow
    Compile a single workflow by name (e.g. "blogpost-request") instead of
    every workflow in .github/workflows/.
.PARAMETER Strict
    Run compilation with enhanced security validation (`gh aw compile --strict`).
.EXAMPLE
    .\scripts\compile-workflows.ps1
.EXAMPLE
    .\scripts\compile-workflows.ps1 -Workflow blogpost-request
.EXAMPLE
    .\scripts\compile-workflows.ps1 -Strict
#>
param(
    [string]$Workflow,
    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

Write-Host ""
Write-Host "  Culture Engineers — Compile Agentic Workflows" -ForegroundColor Cyan
Write-Host "  ───────────────────────────────────────────────" -ForegroundColor DarkGray

# Check the gh CLI itself
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) not found. Install it from https://cli.github.com/"
}

# Check the gh-aw extension is installed
$extensions = gh extension list 2>$null
if (-not ($extensions -match "gh-aw")) {
    Write-Error "The gh-aw extension isn't installed. Run: gh extension install github/gh-aw"
}

$compileArgs = @("aw", "compile")
if ($Workflow) { $compileArgs += $Workflow }
if ($Strict)   { $compileArgs += "--strict" }

Write-Host "  Running: gh $($compileArgs -join ' ')" -ForegroundColor Yellow
Write-Host ""

& gh @compileArgs
$exitCode = $LASTEXITCODE

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "  Compile succeeded." -ForegroundColor Green

    # Show what changed so it's obvious what to review/commit
    $changed = git status --porcelain -- '.github/workflows/*.lock.yml' '.github/aw/actions-lock.json' 2>$null
    if ($changed) {
        Write-Host ""
        Write-Host "  Changed files (review, then commit manually):" -ForegroundColor Cyan
        $changed | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    } else {
        Write-Host "  No changes to .lock.yml or actions-lock.json — already up to date." -ForegroundColor DarkGray
    }
} else {
    Write-Host "  Compile failed (exit code $exitCode). See errors above." -ForegroundColor Red
}

Write-Host ""
Pop-Location
exit $exitCode
