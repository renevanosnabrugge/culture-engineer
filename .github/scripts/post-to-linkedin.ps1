#!/usr/bin/env pwsh
<#
.SYNOPSIS
LinkedIn Poster: posts scheduled social variants to LinkedIn on their target dates.

Handles two issue formats:
  NEW  - issues titled "[Social N] <Title>" labeled content-calendar + approve
         Body: optional metadata block followed by the variant text.
  OLD  - single issues labeled content-calendar + approve + published
         Body: CONTENT CALENDAR METADATA block + three ## LinkedIn sections.

Manual override via env vars FORCE_ISSUE and FORCE_VARIANT (set by workflow_dispatch).
#>

param()
$ErrorActionPreference = 'Stop'

$TODAY         = (Get-Date).ToString('yyyy-MM-dd')
$REPO          = $env:GITHUB_REPOSITORY
$TOKEN         = $env:LINKEDIN_ACCESS_TOKEN
$PERSON_URN    = $env:LINKEDIN_PERSON_URN
$FORCE_ISSUE   = $env:FORCE_ISSUE?.Trim()
$FORCE_VARIANT = $env:FORCE_VARIANT?.Trim()

$LI_HEADERS = @{
    Authorization                   = "Bearer $TOKEN"
    'Content-Type'                  = 'application/json'
    'X-Restli-Protocol-Version'     = '2.0.0'
    'LinkedIn-Version'              = '202401'
}

# ── helpers ──────────────────────────────────────────────────────────────────

function Invoke-Gh {
    param([string[]]$Arguments)
    $out = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Warning "gh: $out" }
    return $out -join "`n"
}

function ConvertFrom-Metadata {
    param([string]$Body)
    $meta = @{}
    if ($Body -match '(?s)<!-- CONTENT CALENDAR METADATA\r?\n(.*?)-->') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^([^:\s]+):\s*(.*)$') {
                $meta[$Matches[1]] = $Matches[2].Trim()
            }
        }
    }
    return $meta
}

function Get-VariantText {
    # Old format: extract section N from the issue body
    param([string]$Body, [int]$N)
    $pattern = "(?s)## LinkedIn — Variant $N [^\n]+\n\n(?:> [^\n]+\n\n)?(.*?)(?=\n---\n|\n## LinkedIn|\z)"
    if ($Body -match $pattern) {
        $text = $Matches[1].Trim() -replace '\[Paste variant here\]', '' | ForEach-Object { $_.Trim() }
        return $text
    }
    return $null
}

function Get-SubIssueText {
    # New format: everything after the metadata block IS the variant text
    param([string]$Body)
    $text = $Body -replace '(?s)^<!--\s*CONTENT CALENDAR METADATA[\s\S]*?-->\s*', ''
    return $text.Trim()
}

function Invoke-ImageUpload {
    param([string]$ImagePath)
    if (-not $ImagePath -or -not (Test-Path $ImagePath)) {
        Write-Host "  Image not found: '$ImagePath' — posting without image"
        return $null
    }
    try {
        $regPayload = @{
            registerUploadRequest = @{
                recipes              = @('urn:li:digitalmediaRecipe:feedshare-image')
                owner                = $PERSON_URN
                serviceRelationships = @(@{
                    relationshipType = 'OWNER'
                    identifier       = 'urn:li:userGeneratedContent'
                })
            }
        } | ConvertTo-Json -Depth 5

        $reg  = Invoke-RestMethod -Uri 'https://api.linkedin.com/v2/assets?action=registerUpload' `
                    -Method POST -Headers $LI_HEADERS -Body $regPayload
        $url  = $reg.value.uploadMechanism.'com.linkedin.digitalmedia.uploading.MediaUploadHttpRequest'.uploadUrl
        $asset = $reg.value.asset

        $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $ImagePath).ProviderPath)
        Invoke-RestMethod -Uri $url -Method PUT `
            -Headers @{ Authorization = "Bearer $TOKEN" } -Body $bytes | Out-Null

        Write-Host "  Image uploaded: $asset"
        return $asset
    } catch {
        Write-Host "  Image upload failed: $_"
        return $null
    }
}

function Invoke-LinkedInPost {
    param([string]$Text, [string]$ImagePath, [string]$PostUrl)

    if (-not $TOKEN -or $TOKEN -in @('', 'your-token-here')) {
        Write-Host '  LINKEDIN_ACCESS_TOKEN not configured — skipping'
        return $false, 'Token not configured'
    }
    if (-not $PERSON_URN) {
        Write-Host '  LINKEDIN_PERSON_URN not configured — skipping'
        return $false, 'URN not configured'
    }

    $fullText = $Text.Trim()
    if ($PostUrl) { $fullText += "`n`n$PostUrl" }

    $asset = Invoke-ImageUpload -ImagePath $ImagePath

    $shareContent = @{
        shareCommentary    = @{ text = $fullText }
        shareMediaCategory = if ($asset) { 'IMAGE' } else { 'NONE' }
    }
    if ($asset) { $shareContent['media'] = @(@{ status = 'READY'; media = $asset }) }

    $payload = @{
        author           = $PERSON_URN
        lifecycleState   = 'PUBLISHED'
        specificContent  = @{ 'com.linkedin.ugc.ShareContent' = $shareContent }
        visibility       = @{ 'com.linkedin.ugc.MemberNetworkVisibility' = 'PUBLIC' }
    } | ConvertTo-Json -Depth 8

    try {
        $resp = Invoke-RestMethod -Uri 'https://api.linkedin.com/v2/ugcPosts' `
                    -Method POST -Headers $LI_HEADERS -Body $payload
        return $true, ($resp | ConvertTo-Json -Compress)
    } catch {
        return $false, $_.Exception.Message
    }
}

# ── process issue ─────────────────────────────────────────────────────────────

function Invoke-IssuePost {
    param($Issue, [string]$ForceVariant = '')

    $labels  = $Issue.labels | ForEach-Object { $_.name }
    $body    = $Issue.body ?? ''
    $num     = [string]$Issue.number
    $meta    = ConvertFrom-Metadata -Body $body

    # ── NEW format: [Social N] sub-issue ──────────────────────────────────────
    if ($Issue.title -match '^\[Social (\d)\]') {
        $N = [int]$Matches[1]
        if ($ForceVariant) { $N = [int]$ForceVariant }

        $dateKey    = "social-$N-date"
        $postedKey  = "social-$N-posted"
        $targetDate = $meta[$dateKey]

        if (-not $ForceVariant -and $targetDate -ne $TODAY) { return }
        if ($postedKey -in $labels) { return }

        Write-Host ""
        Write-Host "Issue #${num}: $($Issue.title)"

        $text = Get-SubIssueText -Body $body
        if (-not $text) { Write-Host '  No variant text found — skipping'; return }

        Write-Host "  Posting Social $N..."
        $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $meta['image'] -PostUrl $meta['post-url']

        if ($ok) {
            Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', $postedKey)
            Invoke-Gh @('issue', 'close', $num, '--repo', $REPO, '--reason', 'completed')
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO,
                '--body', "✅ LinkedIn Social $N posted on $TODAY.")
            Write-Host "  ✓ Social $N posted — issue closed"
        } else {
            $msg = "⚠️ LinkedIn Social $N failed on $TODAY.``n``nResponse: ``$($resp.Substring(0, [Math]::Min(300, $resp.Length)))``"
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $msg)
            Write-Host "  ✗ Social $N failed"
        }
        return
    }

    # ── OLD format: single issue with all 3 variants ──────────────────────────
    if (-not ($meta.Count -gt 0)) { Write-Host "  #${num}: no metadata block — skipping"; return }

    $variantsToPost = @()
    if ($ForceVariant) {
        $variantsToPost = @([int]$ForceVariant)
    } else {
        foreach ($v in 1..3) {
            $key = "social-$v-date"
            if ($meta[$key] -eq $TODAY -and "social-$v-posted" -notin $labels) {
                $variantsToPost += $v
            }
        }
    }
    if ($variantsToPost.Count -eq 0) { return }

    Write-Host ""
    Write-Host "Issue #${num}: $($Issue.title) — variants: $($variantsToPost -join ',')"

    foreach ($v in $variantsToPost) {
        $text = Get-VariantText -Body $body -N $v
        if (-not $text) { Write-Host "  Variant $v: no text — skipping"; continue }

        Write-Host "  Posting variant $v..."
        $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $meta['image'] -PostUrl $meta['post-url']

        if ($ok) {
            Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', "social-$v-posted")
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO,
                '--body', "✅ LinkedIn Variant $v posted on $TODAY.")
            Write-Host "  ✓ Variant $v posted"
        } else {
            $msg = "⚠️ LinkedIn Variant $v failed on $TODAY.`n`nResponse: ``$($resp.Substring(0, [Math]::Min(300, $resp.Length)))``"
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $msg)
            Write-Host "  ✗ Variant $v failed"
        }
    }

    # Close old-format issue when all 3 variants posted
    $updatedRaw = Invoke-Gh @('issue', 'view', $num, '--repo', $REPO, '--json', 'labels')
    if ($updatedRaw) {
        $finalLabels = ($updatedRaw | ConvertFrom-Json).labels | ForEach-Object { $_.name }
        if ((1..3 | Where-Object { "social-$_-posted" -notin $finalLabels }).Count -eq 0) {
            Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', 'done')
            Invoke-Gh @('issue', 'close', $num, '--repo', $REPO, '--reason', 'completed')
            Write-Host "  All variants posted — issue #${num} closed"
        }
    }
}

# ── main ─────────────────────────────────────────────────────────────────────

Write-Host "LinkedIn Poster — $TODAY"

if ($FORCE_ISSUE) {
    $raw = Invoke-Gh @('issue', 'view', $FORCE_ISSUE, '--repo', $REPO,
        '--json', 'number,title,labels,body')
    if ($raw) { Invoke-IssuePost -Issue ($raw | ConvertFrom-Json) -ForceVariant $FORCE_VARIANT }
    return
}

# NEW format: [Social N] sub-issues — labeled content-calendar + approve
$rawNew = Invoke-Gh @(
    'issue', 'list', '--repo', $REPO,
    '--label', 'content-calendar', '--label', 'approve',
    '--state', 'open',
    '--json', 'number,title,labels,body',
    '--limit', '50'
)
$newIssues = if ($rawNew) { ($rawNew | ConvertFrom-Json) | Where-Object { $_.title -match '^\[Social' } } else { @() }
Write-Host "Found $($newIssues.Count) [Social N] issue(s)"
foreach ($issue in $newIssues) { Invoke-IssuePost -Issue $issue }

# OLD format: single issues — labeled content-calendar + approve + published
$rawOld = Invoke-Gh @(
    'issue', 'list', '--repo', $REPO,
    '--label', 'content-calendar', '--label', 'approve', '--label', 'published',
    '--state', 'open',
    '--json', 'number,title,labels,body',
    '--limit', '50'
)
$oldIssues = if ($rawOld) { ($rawOld | ConvertFrom-Json) | Where-Object { $_.title -notmatch '^\[Social' } } else { @() }
Write-Host "Found $($oldIssues.Count) legacy calendar issue(s)"
foreach ($issue in $oldIssues) { Invoke-IssuePost -Issue $issue }
