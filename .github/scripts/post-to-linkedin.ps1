#!/usr/bin/env pwsh
<#
.SYNOPSIS
LinkedIn Poster: posts standalone scheduled social variants to LinkedIn.

Reads [Social N] project items only when their Status is "To Be Published" and
Publish Date is today. Each social item must provide its own Post File project
field and LinkedIn text in its issue body.

Manual selection via env vars FORCE_ISSUE and FORCE_VARIANT (set by workflow_dispatch)
still requires the social item to be in the "To Be Published" project column.
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

$TODAY          = (Get-Date).ToString('yyyy-MM-dd')
$REPO           = $env:GITHUB_REPOSITORY
$OWNER          = $REPO.Split('/')[0]
$SITE_URL       = 'https://culture-engineers.nl'
$PROJECT_NUMBER = 9
$TOKEN          = $env:LINKEDIN_ACCESS_TOKEN
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

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $token = $env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN
    if (-not $token) { return $null }
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
        -Method POST `
        -Headers @{
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
            'User-Agent'   = 'culture-engineer-bot'
        } `
        -Body $bodyBytes
    if ($resp.errors) { Write-Warning "GraphQL: $($resp.errors | ConvertTo-Json -Depth 10 -Compress)" }
    return $resp
}

function Get-SocialBodyText {
    # Returns variant text stored after the '---' separator in a [Social N] issue body
    param([string]$Body)
    if ($Body -match '(?s)\n---\n\n(.+)$') {
        $text = $Matches[1].Trim()
        if ($text -and $text -notmatch '^\[.*here.*\]$') { return $text }
    }
    return $null
}

function Get-FrontMatterField {
    # Reads a single key from a file's YAML front matter
    param([string]$FilePath, [string]$Key)
    if (-not $FilePath) { return $null }
    $fp = $FilePath.TrimStart('/')
    if (-not (Test-Path $fp)) { return $null }
    $inFM = $false
    foreach ($line in (Get-Content $fp -Encoding UTF8)) {
        if ($line -eq '---') {
            if (-not $inFM) { $inFM = $true; continue } else { break }
        }
        if ($inFM -and $line -match "^${Key}:\s*(.+)$") { return $Matches[1].Trim() }
    }
    return $null
}

function Get-PostUrl {
    param([string]$FilePath)
    if (-not $FilePath) { return '' }
    $leaf = Split-Path ($FilePath.TrimStart('/')) -Leaf
    if ($leaf -match '^(\d{4})-(\d{2})-(\d{2})-(.+)\.md$') {
        return "$SITE_URL/$($Matches[1])/$($Matches[2])/$($Matches[3])/$($Matches[4])/"
    }
    return ''
}

function Get-AllProjectItems {
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            items(first: 100) {
              nodes {
                id
                fieldValues(first: 20) {
                  nodes {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      field { ... on ProjectV2SingleSelectField { name } }
                      name
                    }
                    ... on ProjectV2ItemFieldDateValue {
                      field { ... on ProjectV2Field { name } }
                      date
                    }
                    ... on ProjectV2ItemFieldTextValue {
                      field { ... on ProjectV2Field { name } }
                      text
                    }
                  }
                }
                content {
                  ... on Issue {
                    number title body
                    labels(first: 20) { nodes { name } }
                  }
                }
              }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }
    return $data?.data.user.projectV2.items.nodes ?? @()
}

function Get-FieldValue {
    param([array]$FieldValues, [string]$NamePattern)
    foreach ($fv in ($FieldValues ?? @())) {
        if (-not $fv -or -not $fv.field) { continue }
        if ($fv.field.name -match $NamePattern) {
            return ($fv.name ?? $fv.date ?? $fv.text)
        }
    }
    return $null
}

function Invoke-ImageUpload {
    param([string]$ImagePath)
    # Strip leading slash so the path resolves correctly from the repo root
    if ($ImagePath) { $ImagePath = $ImagePath.TrimStart('/') }
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

# ── primary poster (project-field based) ──────────────────────────────────────────────

function Invoke-SocialItemPost {
    # Reads variant text from a standalone [Social N] issue body.
    param([pscustomobject]$Item, [string]$ForceVariant = '')

    $body   = $Item.content.body ?? ''
    $num    = [string]$Item.content.number
    $labels = $Item.content.labels.nodes | ForEach-Object { $_.name }

    $variantN = 0
    if ($Item.content.title -match '\[Social\s+(\d+)\]') {
        $variantN = [int]$Matches[1]
    }

    if (-not $variantN) {
        Write-Host "  #${num}: cannot determine variant number -- skipping"
        return
    }
    if ($ForceVariant -and $ForceVariant -ne [string]$variantN) { return }

    $labelName = "social-$variantN-posted"
    if ($labelName -in $labels) {
        Write-Host "  #${num}: Variant $variantN already posted -- skipping"
        return
    }

    $text = Get-SocialBodyText -Body $body
    if (-not $text) {
        Write-Host "  #${num}: no variant $variantN text found -- skipping"
        return
    }

    $postFile = Get-FieldValue ($Item.fieldValues.nodes ?? @()) '(?i)post.?file'
    if ($postFile) { $postFile = $postFile.TrimStart('/') }
    if (-not $postFile) {
        Write-Host "  #${num}: no Post File on social project card -- skipping"
        return
    }

    # Image from content file front matter (no need for image: in the issue body)
    $imagePath = Get-FrontMatterField -FilePath $postFile -Key 'image'
    if ($imagePath) { $imagePath = $imagePath.TrimStart('/') }
    if (-not $imagePath -or -not (Test-Path $imagePath)) {
        $warnMsg = "\u26a0\ufe0f LinkedIn Variant $variantN will post **without an image** -- no ``image:`` in content file front matter."
        Write-Host "  WARNING: $warnMsg"
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $warnMsg)
        $imagePath = $null
    }

    $postUrl = Get-PostUrl -FilePath $postFile

    Write-Host ""
    Write-Host "[Social $variantN] #${num}: Variant $variantN"
    Write-Host "  Posting variant ${variantN}..."

    $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $imagePath -PostUrl $postUrl

    if ($ok) {
        Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', $labelName)
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO,
            '--body', "\u2705 LinkedIn Variant $variantN posted on $TODAY.")
        Invoke-Gh @('issue', 'close', $num, '--repo', $REPO, '--reason', 'completed')
        Write-Host "  Variant $variantN posted -- #${num} closed"
    } else {
        $msg = "LinkedIn Variant $variantN failed on $TODAY.`n`nResponse: ``$($resp.Substring(0, [Math]::Min(300, $resp.Length)))``"
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $msg)
        Write-Host "  Variant $variantN failed"
    }
}

# ── main ─────────────────────────────────────────────────────────────────────

Write-Host "LinkedIn Poster -- $TODAY"

# Query standalone social project items.
$allItems = @()
if ($env:GH_PROJECT_TOKEN -or $env:GH_TOKEN -or $env:GITHUB_TOKEN) {
    $allItems = Get-AllProjectItems
}

if ($FORCE_ISSUE) {
    $forcedItem = $allItems | Where-Object { $_.content.number -eq [int]$FORCE_ISSUE } | Select-Object -First 1
    if (-not $forcedItem) {
        Write-Host "#${FORCE_ISSUE}: not found in Project #$PROJECT_NUMBER -- skipping"
        return
    }
    $forcedLabels = $forcedItem.content.labels.nodes | ForEach-Object { $_.name }
    $forcedStatus = Get-FieldValue ($forcedItem.fieldValues.nodes ?? @()) '(?i)^status$'
    if (('social-post' -notin $forcedLabels -and $forcedItem.content.title -notlike '[Social *') -or
        $forcedStatus -ine 'To Be Published') {
        Write-Host "#${FORCE_ISSUE}: not a standalone social item in To Be Published -- skipping"
        return
    }
    Invoke-SocialItemPost -Item $forcedItem -ForceVariant $FORCE_VARIANT
    return
}

# Scheduled run: only standalone [Social N] items in To Be Published with today's date.
$socialsDue = @($allItems | Where-Object {
    if (-not $_.content) { return $false }
    $l = $_.content.labels.nodes | ForEach-Object { $_.name }
    if ('social-post' -notin $l -and $_.content.title -notlike '[Social *') { return $false }
    $fields = $_.fieldValues.nodes ?? @()
    if ((Get-FieldValue $fields '(?i)^status$') -ine 'To Be Published') { return $false }
    return (Get-FieldValue $fields '(?i)publish.?date') -eq $TODAY
})
Write-Host "Found $($socialsDue.Count) [Social N] item(s) due today"

if ($socialsDue.Count -gt 0) {
    foreach ($item in $socialsDue) {
        Invoke-SocialItemPost -Item $item
    }
} else {
    Write-Host "No standalone social items in To Be Published are due today"
}
