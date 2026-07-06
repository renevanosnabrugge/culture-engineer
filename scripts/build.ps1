#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build the Jekyll site for local inspection or production preview.
.DESCRIPTION
    Runs `bundle exec jekyll build`.
    Output lands in _site/ which is gitignored.
.PARAMETER Production
    Set JEKYLL_ENV=production (minifies output, disables draft posts).
.EXAMPLE
    .\scripts\build.ps1
    .\scripts\build.ps1 -Production
#>
param(
    [switch]$Production
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

Write-Host ""
Write-Host "  Culture Engineers — Build" -ForegroundColor Cyan
Write-Host "  ─────────────────────────" -ForegroundColor DarkGray

if (-not (Get-Command bundle -ErrorAction SilentlyContinue)) {
    Write-Error "Bundler not found. Run: gem install bundler"
}

if (-not (Test-Path "$repoRoot\Gemfile.lock")) {
    Write-Host "  Running bundle install..." -ForegroundColor Yellow
    bundle install
}

if ($Production) {
    $env:JEKYLL_ENV = "production"
    Write-Host "  Mode: production" -ForegroundColor Yellow
    bundle exec jekyll build --config "_config.yml"
} else {
    $env:JEKYLL_ENV = "development"
    Write-Host "  Mode: development" -ForegroundColor Green
    bundle exec jekyll build --config "_config.yml,_config.development.yml"
}

$siteDir = Join-Path $repoRoot "_site"
Write-Host ""
Write-Host "  Build complete -> $siteDir" -ForegroundColor Green
Write-Host ""
