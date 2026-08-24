#!/usr/bin/env pwsh
<#
.SYNOPSIS
LinkedIn Poster: posts scheduled social variants to LinkedIn on their target dates.

Reads [Content] issues labeled content-calendar + approve. Each issue body
contains a CONTENT CALENDAR METADATA block with publish-date (and optionally
explicit social-N-date overrides) plus three LinkedIn variant sections.

Social dates default to:
  Variant 1 -> publish-date
  Variant 2 -> publish-date + 7 days
  Variant 3 -> publish-date + 14 days

Manual override via env vars FORCE_ISSUE and FORCE_VARIANT (set by workflow_dispatch).
#>

param(
    [switch]$DryRun = $false,
    [string]$ForceIssue,
    [string]$ForceVariant
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

# ── dry-run guard ─────────────────────────────────────────────────────────────
if ($DryRun -or $env:DRY_RUN -eq '1') {
    $DryRun = $true
    Write-Host ''
    Write-Host '  DRY RUN -- no posts will be made to LinkedIn' -ForegroundColor Yellow
    Write-Host ''
}

$TODAY         = (Get-Date).ToString('yyyy-MM-dd')
$REPO          = $env:GITHUB_REPOSITORY
$TOKEN         = $env:LINKEDIN_ACCESS_TOKEN
$PERSON_URN    = $env:LINKEDIN_PERSON_URN
$FORCE_ISSUE   = if ($ForceIssue)   { $ForceIssue.Trim() }   else { ([string]$env:FORCE_ISSUE).Trim() }
$FORCE_VARIANT = if ($ForceVariant) { $ForceVariant.Trim() } else { ([string]$env:FORCE_VARIANT).Trim() }

$LI_HEADERS = @{
    Authorization                   = "******"
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

function Get-SocialDate {
    param([hashtable]$Meta, [int]$N)
    # Explicit override: social-N-date in metadata
    $explicit = $Meta["social-$N-date"]
    if ($explicit) { return $explicit }
    # Default: publish-date + (N-1)*7 days
    $pub = $Meta['publish-date']
    if (-not $pub) { return $null }
    $base = [datetime]::ParseExact($pub, 'yyyy-MM-dd', $null)
    return $base.AddDays(($N - 1) * 7).ToString('yyyy-MM-dd')
}

function Get-VariantText {
    # Extract ## LinkedIn -- Variant N section text from issue body
    param([string]$Body, [int]$N)
    $pattern = "(?s)## LinkedIn [^\n]*Variant $N[^\n]*\n(?:>\s*[^\n]*\n)*\s*(.*?)(?=\n---\n|\n## LinkedIn|\z)"
    if ($Body -match $pattern) {
        $text = $Matches[1].Trim()
        if ($text -and $text -notmatch '^\[.*here\]$') { return $text }
    }
    return $null
}

function Invoke-ImageUpload {
    param([string]$ImagePath)
    if (-not $ImagePath -or -not (Test-Path $ImagePath)) {
        Write-Host "  Image not found: '$ImagePath' -- posting without image"
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
            -Headers @{ Authorization = "******" } -Body $bytes | Out-Null

        Write-Host "  Image uploaded: $asset"
        return $asset
    } catch {
        Write-Host "  Image upload failed: $_"
        return $null
    }
}

function Invoke-LinkedInPost {
    param([string]$Text, [string]$ImagePath, [string]$PostUrl)

    $fullText = $Text.Trim()
    if ($PostUrl) { $fullText += "`n`n$PostUrl" }

    if ($DryRun) {
        Write-Host '  [DRY RUN] Would post the following text:'
        Write-Host ('-' * 60)
        Write-Host $fullText
        Write-Host ('-' * 60)
        if ($ImagePath) { Write-Host "  [DRY RUN] Image: $ImagePath" }
        return $true, 'dry-run'
    }

    if (-not $TOKEN -or $TOKEN -in @('', 'your-token-here')) {
        Write-Host '  LINKEDIN_ACCESS_TOKEN not configured -- skipping'
        return $false, 'Token not configured'
    }
    if (-not $PERSON_URN) {
        Write-Host '  LINKEDIN_PERSON_URN not configured -- skipping'
        return $false, 'URN not configured'
    }

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
        Write-Host "  Author URN : $PERSON_URN"
        Write-Host "  Text length: $($fullText.Length) chars"

        $resp = Invoke-RestMethod -Uri 'https://api.linkedin.com/v2/ugcPosts' `
                    -Method POST -Headers $LI_HEADERS -Body $payload `
                    -ResponseHeadersVariable respHeaders -StatusCodeVariable statusCode
        Write-Host "  HTTP $statusCode"
        return $true, ($resp | ConvertTo-Json -Compress)
    } catch {
        $errBody = $_.ErrorDetails.Message
        Write-Host "  HTTP ERROR: $($_.Exception.Message)"
        Write-Host "  Body: $errBody"
        return $false, $errBody
    }
}

# ── process issue ─────────────────────────────────────────────────────────────

function Invoke-IssuePost {
    param($Issue, [string]$ForceVariant = '')

    $labels  = $Issue.labels | ForEach-Object { $_.name }
    $body    = $Issue.body ?? ''
    $num     = [string]$Issue.number
    $meta    = ConvertFrom-Metadata -Body $body

    # Skip already-published issues
    if ('published' -in $labels) { return }

    # Must have a publish-date to determine social dates
    if (-not $meta['publish-date']) {
        Write-Host "  #${num}: no publish-date in metadata -- skipping"
        return
    }

    # Determine which variants to post
    $variantsToPost = @()
    if ($ForceVariant) {
        $variantsToPost = @([int]$ForceVariant)
    } else {
        foreach ($v in 1..3) {
            $targetDate = Get-SocialDate -Meta $meta -N $v
            if ($targetDate -eq $TODAY -and "social-$v-posted" -notin $labels) {
                $variantsToPost += $v
            }
        }
    }
    if ($variantsToPost.Count -eq 0) { return }

    Write-Host ""
    Write-Host "Issue #${num}: $($Issue.title) -- variants: $($variantsToPost -join ',')"

    foreach ($v in $variantsToPost) {
        $text = Get-VariantText -Body $body -N $v
        if (-not $text) { Write-Host "  Variant ${v}: no text -- skipping"; continue }

        Write-Host "  Posting variant ${v}..."
        $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $meta['image'] -PostUrl $meta['post-url']

        if ($ok) {
            Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', "social-$v-posted")
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO,
                '--body', "LinkedIn Variant $v posted on $TODAY.")
            Write-Host "  Variant $v posted"
        } else {
            $msg = "LinkedIn Variant $v failed on $TODAY.`n`nResponse: ``$($resp.Substring(0, [Math]::Min(300, $resp.Length)))``"
            Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $msg)
            Write-Host "  Variant $v failed"
        }
    }

    # Close issue when all 3 variants posted and content is published
    $updatedRaw = Invoke-Gh @('issue', 'view', $num, '--repo', $REPO, '--json', 'labels')
    if ($updatedRaw) {
        $finalLabels = ($updatedRaw | ConvertFrom-Json).labels | ForEach-Object { $_.name }
        $allPosted   = (1..3 | Where-Object { "social-$_-posted" -notin $finalLabels }).Count -eq 0
        $isPublished = 'published' -in $finalLabels
        if ($allPosted -and $isPublished) {
            Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', 'done')
            Invoke-Gh @('issue', 'close', $num, '--repo', $REPO, '--reason', 'completed')
            Write-Host "  All variants posted + published -- issue #${num} closed"
        }
    }
}

# ── main ─────────────────────────────────────────────────────────────────────

Write-Host "LinkedIn Poster -- $TODAY"

if ($FORCE_ISSUE) {
    $raw = Invoke-Gh @('issue', 'view', $FORCE_ISSUE, '--repo', $REPO,
        '--json', 'number,title,labels,body')
    if ($raw) { Invoke-IssuePost -Issue ($raw | ConvertFrom-Json) -ForceVariant $FORCE_VARIANT }
    return
}

# Find all content-calendar + approve issues
$raw = Invoke-Gh @(
    'issue', 'list', '--repo', $REPO,
    '--label', 'content-calendar', '--label', 'approve',
    '--state', 'open',
    '--json', 'number,title,labels,body',
    '--limit', '50'
)
$issues = if ($raw) { $raw | ConvertFrom-Json } else { @() }
Write-Host "Found $($issues.Count) approved calendar issue(s)"

foreach ($issue in $issues) { Invoke-IssuePost -Issue $issue }
