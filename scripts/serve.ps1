#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Start a local Jekyll development server with live-reload.
.DESCRIPTION
    Runs `bundle exec jekyll serve --livereload` with sensible defaults.
    The site is available at http://localhost:4000 by default.
.PARAMETER Port
    Port to listen on. Default: 4000
.PARAMETER Host
    Host to bind to. Default: 127.0.0.1
.EXAMPLE
    .\scripts\serve.ps1
    .\scripts\serve.ps1 -Port 4001
#>
param(
    [int]   $Port = 4000,
    [string]$BindHost = "127.0.0.1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Resolve repo root (one level up from scripts/)
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

Write-Host ""
Write-Host "  Culture Engineers — Local Dev Server" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray

# Check Ruby
if (-not (Get-Command ruby -ErrorAction SilentlyContinue)) {
    Write-Error "Ruby not found. Install it from https://rubyinstaller.org/ (choose the version with DevKit)."
}

# Check Bundler
if (-not (Get-Command bundle -ErrorAction SilentlyContinue)) {
    Write-Host "  Bundler not found — installing..." -ForegroundColor Yellow
    gem install bundler
}

# Install / update gems if Gemfile.lock is missing or outdated
if (-not (Test-Path "$repoRoot\Gemfile.lock")) {
    Write-Host "  Running bundle install..." -ForegroundColor Yellow
    bundle install
}

Write-Host "  Starting server at http://$($BindHost):$Port" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

bundle exec jekyll serve `
    --livereload `
    --host $BindHost `
    --port $Port `
    --config "_config.yml,_config.development.yml"
