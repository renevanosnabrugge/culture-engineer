#!/usr/bin/env pwsh
<#
.SYNOPSIS
LinkedIn Poster: posts scheduled social variants to LinkedIn on their target dates.

Reads [Social N] project items with Publish Date = today from GitHub Projects.
Gets variant text from the [Social N] issue body (fallback: parent [Content]
issue's "## LinkedIn — Variant N" sections). Reads the image from the content
file's front matter and derives the post URL from the file path.

Falls back to the label-based approach for content without [Social N] project
items (backward compatible).

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
    $token = $env:GH_PROJECT_TOKEN
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
    if ($resp.errors) { Write-Warning "GraphQL: $($resp.errors | ConvertTo-Json -Compress)" }
    return $resp
}

# Ensures the content file is published (published: true) before socials go out,
# so every LinkedIn link resolves immediately.
function Set-ContentPublished {
    param([string]$FilePath)
    if (-not $FilePath) { return }
    if (-not (Test-Path $FilePath)) {
        Write-Host "  Content file not found: '$FilePath' -- skipping publish check"
        return
    }
    $content = Get-Content $FilePath -Raw
    if ($content -match 'published:\s*true') { return }  # already live
    if ($content -notmatch 'published:\s*false') { return }  # no field, skip
    Write-Host "  Content not yet published -- setting published: true in $FilePath"
    $updated = $content -replace 'published:\s*false', 'published: true'
    Set-Content $FilePath $updated -NoNewline
    git config user.email "github-actions[bot]@users.noreply.github.com" 2>$null
    git config user.name  "github-actions[bot]" 2>$null
    git add $FilePath
    git commit -m "chore: publish $FilePath before LinkedIn post [skip ci]"
    git push
    Write-Host "  Committed published: true for $FilePath"
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

function ConvertFrom-SocialMetadata {
    param([string]$Body)
    $meta = @{}
    if ($Body -match '(?s)<!-- SOCIAL METADATA\r?\n(.*?)-->') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^([^:\s]+):\s*(.*)$') {
                $meta[$Matches[1]] = $Matches[2].Trim()
            }
        }
    }
    return $meta
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
                    labels { nodes { name } }
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
    # Reads variant text from [Social N] issue body; image from content file front matter.
    param([pscustomobject]$Item, [hashtable]$ProjMap, [string]$ForceVariant = '')

    $body   = $Item.content.body ?? ''
    $num    = [string]$Item.content.number
    $labels = $Item.content.labels.nodes | ForEach-Object { $_.name }

    $sm        = ConvertFrom-SocialMetadata -Body $body
    $parentNum = [int]($sm['parent'] -replace '[^0-9]', '')
    $variantN  = [int]($sm['variant'])

    # Fall back to title: "[Social 2] Title"
    if (-not $variantN -and $Item.content.title -match '\[Social\s+(\d)\]') {
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

    # Variant text: from [Social N] body, or fall back to parent's ## LinkedIn -- Variant N section
    $text       = Get-SocialBodyText -Body $body
    $parentBody = $null
    if (-not $text -and $parentNum) {
        $pr = Invoke-Gh @('issue', 'view', $parentNum, '--repo', $REPO, '--json', 'body')
        if ($pr) {
            $parentBody = ($pr | ConvertFrom-Json).body
            $text = Get-VariantText -Body $parentBody -N $variantN
        }
    }

    if (-not $text) {
        Write-Host "  #${num}: no variant $variantN text found -- skipping"
        return
    }

    # File path: parent project card Post File -> parent metadata block
    $postFile = if ($parentNum -and $ProjMap.ContainsKey($parentNum)) {
        $ProjMap[$parentNum].PostFile
    } else { $null }

    if (-not $postFile -and $parentNum) {
        if (-not $parentBody) {
            $pr2 = Invoke-Gh @('issue', 'view', $parentNum, '--repo', $REPO, '--json', 'body')
            if ($pr2) { $parentBody = ($pr2 | ConvertFrom-Json).body }
        }
        $postFile = (ConvertFrom-Metadata -Body ($parentBody ?? ''))['file']
    }
    if ($postFile) { $postFile = $postFile.TrimStart('/') }

    Set-ContentPublished -FilePath $postFile

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
    Write-Host "[Social $variantN] #${num}: Variant $variantN (parent #$parentNum)"
    Write-Host "  Posting variant ${variantN}..."

    $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $imagePath -PostUrl $postUrl

    if ($ok) {
        Invoke-Gh @('issue', 'edit', $num, '--repo', $REPO, '--add-label', $labelName)
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO,
            '--body', "\u2705 LinkedIn Variant $variantN posted on $TODAY.")
        if ($parentNum) {
            Invoke-Gh @('issue', 'edit', $parentNum, '--repo', $REPO, '--add-label', $labelName)
        }
        Invoke-Gh @('issue', 'close', $num, '--repo', $REPO, '--reason', 'completed')
        Write-Host "  Variant $variantN posted -- #${num} closed"

        # Close parent [Content] issue when all 3 variants posted and content is published
        if ($parentNum) {
            $pRaw = Invoke-Gh @('issue', 'view', $parentNum, '--repo', $REPO, '--json', 'labels,state')
            if ($pRaw) {
                $pData       = $pRaw | ConvertFrom-Json
                $pLabels     = $pData.labels | ForEach-Object { $_.name }
                $allPosted   = (1..3 | Where-Object { "social-$_-posted" -notin $pLabels }).Count -eq 0
                $isPublished = 'published' -in $pLabels
                if ($allPosted -and $isPublished -and $pData.state -ne 'CLOSED') {
                    Invoke-Gh @('issue', 'edit', $parentNum, '--repo', $REPO, '--add-label', 'done')
                    Invoke-Gh @('issue', 'close', $parentNum, '--repo', $REPO, '--reason', 'completed')
                    Write-Host "  All variants + published -- parent #$parentNum closed"
                }
            }
        }
    } else {
        $msg = "LinkedIn Variant $variantN failed on $TODAY.`n`nResponse: ``$($resp.Substring(0, [Math]::Min(300, $resp.Length)))``"
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $msg)
        Write-Host "  Variant $variantN failed"
    }
}

# ── fallback poster (label/metadata-block based) ────────────────────────────────

function Invoke-IssuePost {
    # Fallback: used for content without [Social N] project items.
    param($Issue, [string]$ForceVariant = '')

    $labels  = $Issue.labels | ForEach-Object { $_.name }
    $body    = $Issue.body ?? ''
    $num     = [string]$Issue.number
    $meta    = ConvertFrom-Metadata -Body $body

    # [Social N] issues are project cards only \u2014 variant text lives in [Content] issues
    if ('social-post' -in $labels -or $Issue.title -like '[Social *') { return }

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

    # Ensure the content file is live before any social link goes out
    Set-ContentPublished -FilePath $meta['file']

    # Normalize image path and warn if missing
    $imagePath = $meta['image']
    if ($imagePath) { $imagePath = $imagePath.TrimStart('/') }
    if (-not $imagePath -or -not (Test-Path $imagePath)) {
        $warnMsg = "⚠️ LinkedIn Variant(s) will post **without an image** — no image found at ``$($meta['image'])``. Add an image and update the ``image:`` field in the metadata block."
        Write-Host "  WARNING: $warnMsg"
        Invoke-Gh @('issue', 'comment', $num, '--repo', $REPO, '--body', $warnMsg)
    }

    foreach ($v in $variantsToPost) {
        $text = Get-VariantText -Body $body -N $v
        if (-not $text) { Write-Host "  Variant ${v}: no text -- skipping"; continue }

        Write-Host "  Posting variant ${v}..."
        $ok, $resp = Invoke-LinkedInPost -Text $text -ImagePath $imagePath -PostUrl (Get-PostUrl -FilePath $meta['file'])

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

# Query project items once: build Publish Date + Post File lookup for [Content] issues
$allItems = @()
$projMap  = @{}
if ($env:GH_PROJECT_TOKEN) {
    $allItems = Get-AllProjectItems
    foreach ($it in $allItems) {
        if (-not $it.content?.number) { continue }
        $fvs = $it.fieldValues.nodes ?? @()
        $projMap[[int]$it.content.number] = @{
            PostFile    = Get-FieldValue $fvs '(?i)post.?file'
            PublishDate = Get-FieldValue $fvs '(?i)publish.?date'
        }
    }
}

if ($FORCE_ISSUE) {
    $raw = Invoke-Gh @('issue', 'view', $FORCE_ISSUE, '--repo', $REPO,
        '--json', 'number,title,labels,body')
    if ($raw) {
        $forced  = $raw | ConvertFrom-Json
        $fLabels = $forced.labels | ForEach-Object { $_.name }
        if ('social-post' -in $fLabels -or $forced.title -like '[Social *') {
            $fakeItem = [pscustomobject]@{
                id          = ''
                content     = $forced
                fieldValues = [pscustomobject]@{ nodes = @() }
            }
            Invoke-SocialItemPost -Item $fakeItem -ProjMap $projMap -ForceVariant $FORCE_VARIANT
        } else {
            # [Content] issue forced -- post its [Social N] children
            $found = $false
            foreach ($it in $allItems) {
                if (-not $it.content) { continue }
                $itL = $it.content.labels.nodes | ForEach-Object { $_.name }
                if ('social-post' -notin $itL -and $it.content.title -notlike '[Social *') { continue }
                $sm = ConvertFrom-SocialMetadata -Body ($it.content.body ?? '')
                if ([int]($sm['parent'] -replace '[^0-9]', '') -eq [int]$FORCE_ISSUE) {
                    Invoke-SocialItemPost -Item $it -ProjMap $projMap -ForceVariant $FORCE_VARIANT
                    $found = $true
                }
            }
            if (-not $found) { Invoke-IssuePost -Issue $forced -ForceVariant $FORCE_VARIANT }
        }
    }
    return
}

# Scheduled run: find [Social N] project items with Publish Date = today
$socialsDue = @($allItems | Where-Object {
    if (-not $_.content) { return $false }
    $l = $_.content.labels.nodes | ForEach-Object { $_.name }
    if ('social-post' -notin $l -and $_.content.title -notlike '[Social *') { return $false }
    return (Get-FieldValue ($_.fieldValues.nodes ?? @()) '(?i)publish.?date') -eq $TODAY
})
Write-Host "Found $($socialsDue.Count) [Social N] item(s) due today"

if ($socialsDue.Count -gt 0) {
    foreach ($item in $socialsDue) {
        Invoke-SocialItemPost -Item $item -ProjMap $projMap
    }
} else {
    # Fallback: [Content] issues with social-N-date in metadata block (pre-project approach)
    Write-Host "No project-based social items due -- falling back to label-based scan"
    $raw = Invoke-Gh @(
        'issue', 'list', '--repo', $REPO,
        '--label', 'content-calendar', '--label', 'approve',
        '--state', 'open',
        '--json', 'number,title,labels,body',
        '--limit', '50'
    )
    $issues = if ($raw) { $raw | ConvertFrom-Json } else { @() }
    Write-Host "Found $($issues.Count) approved calendar issue(s) in fallback"
    foreach ($issue in $issues) { Invoke-IssuePost -Issue $issue }
}
