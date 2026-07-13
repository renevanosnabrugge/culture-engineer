#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate a hero image via Azure AI Foundry and save it to assets/images/.
.DESCRIPTION
    Calls the Azure AI Foundry image-generation endpoint, downloads the result,
    and writes it as a PNG to assets/images/<Slug>.png.

    The API key is read from the AZURE_IMAGE_GEN_KEY environment variable.
    Never hardcode the key in this file or any other source file.
.PARAMETER Prompt
    The image generation prompt (required).
.PARAMETER Slug
    The post slug used as the output filename, e.g. "engineering-culture-board-level-risk".
    Must not contain path separators.
.EXAMPLE
    .\scripts\generate-image.ps1 -Prompt "Abstract concept of trust and hierarchy" -Slug "engineering-culture-board-level-risk"
.NOTES
    Local:          $env:AZURE_IMAGE_GEN_KEY = "<your-key>"
    GitHub Actions: add AZURE_IMAGE_GEN_KEY as a repository secret
#>
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [Parameter(Mandatory)]
    [string]$Slug
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Constants ────────────────────────────────────────────────────────────────
$Endpoint = "https://culture-engineer-ai.services.ai.azure.com/openai/v1/images/generations"
$Model    = "gpt-image-2"
$Size     = "1024x1536"

# ── Resolve repo root ────────────────────────────────────────────────────────
$repoRoot  = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot "assets\images"

Write-Host ""
Write-Host "  Culture Engineers — Image Generator" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────" -ForegroundColor DarkGray

# ── Validate inputs ──────────────────────────────────────────────────────────
if ([string]::IsNullOrWhiteSpace($Prompt)) {
    Write-Error "ERROR: -Prompt must not be empty."
}
if ([string]::IsNullOrWhiteSpace($Slug) -or $Slug -match '[/\\]') {
    Write-Error "ERROR: -Slug must be a simple filename without path separators."
}

# ── Read API key from environment ────────────────────────────────────────────
$apiKey = $env:AZURE_IMAGE_GEN_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host ""
    Write-Error @"
ERROR: AZURE_IMAGE_GEN_KEY environment variable is not set.
  - Locally:          `$env:AZURE_IMAGE_GEN_KEY = '<your-key>'
  - GitHub Actions:   add it as a repository secret named AZURE_IMAGE_GEN_KEY
"@
}

# ── Build request ────────────────────────────────────────────────────────────
$body = @{
    model              = $Model
    prompt             = $Prompt
    n                  = 1
    size               = $Size
    output_format      = "png"
    output_compression = 100
} | ConvertTo-Json -Depth 3

$headers = @{
    "Authorization" = "Bearer $apiKey"
    "Content-Type"  = "application/json"
}

Write-Host ""
Write-Host "  Generating image…" -ForegroundColor DarkGray
Write-Host "  Prompt : $($Prompt.Substring(0, [Math]::Min(80, $Prompt.Length)))…" -ForegroundColor DarkGray
Write-Host "  Size   : $Size  Format: png (compression 100)" -ForegroundColor DarkGray

# ── Call Azure AI Foundry ────────────────────────────────────────────────────
try {
    $response = Invoke-RestMethod `
        -Uri     $Endpoint `
        -Method  Post `
        -Headers $headers `
        -Body    $body `
        -TimeoutSec 120
} catch {
    $statusCode = $_.Exception.Response?.StatusCode.value__
    $detail     = $_.ErrorDetails?.Message
    Write-Error "ERROR: Image generation failed — HTTP $statusCode`n$detail"
}

# ── Decode and save ──────────────────────────────────────────────────────────
$item = $response.data[0]

if ($item.b64_json) {
    $imageBytes = [Convert]::FromBase64String($item.b64_json)
} elseif ($item.url) {
    Write-Host "  Downloading image from URL…" -ForegroundColor DarkGray
    $imageBytes = (Invoke-WebRequest -Uri $item.url -TimeoutSec 60).Content
} else {
    Write-Error "ERROR: Unexpected response format — no b64_json or url in data[0]."
}

if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

$outputPath = Join-Path $outputDir "$Slug.png"
[IO.File]::WriteAllBytes($outputPath, $imageBytes)

# ── Report result ────────────────────────────────────────────────────────────
$relativePath = "assets/images/$Slug.png"
Write-Host ""
Write-Host "  Image saved successfully." -ForegroundColor Green
Write-Host ""

# Structured output line for calling agents to parse
Write-Output "IMAGE_PATH: $relativePath"
