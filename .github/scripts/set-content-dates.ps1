#!/usr/bin/env pwsh
<#
.SYNOPSIS
Sets content calendar dates when the 'scheduled' label is added to a main
content issue, then moves all project cards to "To Be Published".

Steps:
  1. Parse publish-date from main issue body (<!-- publish-date: YYYY-MM-DD -->)
  2. Find sub-issues via GitHub GraphQL
  3. Calculate per-sub-issue target dates:
       [Post]     → publish-date
       [Social 1] → publish-date
       [Social 2] → publish-date + 7 days
       [Social 3] → publish-date + 14 days
  4. Extract file path + image from the [Post] sub-issue body / file front matter
  5. Prepend CONTENT CALENDAR METADATA blocks to sub-issue bodies
  6. Add 'approve' label to all sub-issues
  7. Set "Publish Date" field in GitHub Project for each item
  8. Move each project card to "To Be Published" status
  9. Comment on main issue with date summary

Required env vars:
  GH_TOKEN          — GITHUB_TOKEN (issues: write)
  GH_PROJECT_TOKEN  — PAT with 'project' scope (for Projects v2 GraphQL)
  GITHUB_REPOSITORY — owner/repo
  ISSUE_NUMBER      — number of the main content issue
  ISSUE_BODY        — body of the main issue (may be truncated; re-fetched if needed)
#>

param()
$ErrorActionPreference = 'Stop'

$REPO           = $env:GITHUB_REPOSITORY
$OWNER          = $REPO.Split('/')[0]
$REPO_NAME      = $REPO.Split('/')[1]
$ISSUE_NUMBER   = [int]$env:ISSUE_NUMBER
$PROJECT_NUMBER = 9

# ── helpers ──────────────────────────────────────────────────────────────────

function Invoke-Gh {
    param([string[]]$Arguments, [string]$Token)
    $saved = $env:GH_TOKEN
    if ($Token) { $env:GH_TOKEN = $Token }
    $out = & gh @Arguments 2>&1
    if ($Token) { $env:GH_TOKEN = $saved }
    if ($LASTEXITCODE -ne 0) { Write-Warning "gh: $out" }
    return $out -join "`n"
}

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    $headers = @{
        Authorization  = "Bearer $env:GH_PROJECT_TOKEN"
        'Content-Type' = 'application/json'
        'User-Agent'   = 'culture-engineer-bot'
    }
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
                -Method POST -Headers $headers -Body $body
    if ($resp.errors) { Write-Warning "GraphQL errors: $($resp.errors | ConvertTo-Json -Compress)" }
    return $resp
}

# ── 1. Resolve publish-date ───────────────────────────────────────────────────

function Get-PublishDate {
    param([string]$Body)
    if ($Body -match '<!--\s*publish-date:\s*(\d{4}-\d{2}-\d{2})\s*-->') {
        return [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
    }
    return $null
}

$issueBody = $env:ISSUE_BODY ?? ''
$publishDate = Get-PublishDate -Body $issueBody

if (-not $publishDate) {
    # Re-fetch in case env var was truncated
    $raw = Invoke-Gh @('issue', 'view', $ISSUE_NUMBER, '--repo', $REPO,
        '--json', 'body') -Token $env:GH_TOKEN
    $publishDate = Get-PublishDate -Body (($raw | ConvertFrom-Json).body ?? '')
}

if (-not $publishDate) {
    $msg = @"
## ⚠️ Could not set dates

No ``<!-- publish-date: YYYY-MM-DD -->`` found in the issue body.

Add a line like:
```
<!-- publish-date: 2026-08-11 -->
```
then remove and re-add the ``scheduled`` label.
"@
    Invoke-Gh @('issue', 'comment', $ISSUE_NUMBER, '--repo', $REPO, '--body', $msg) -Token $env:GH_TOKEN
    Write-Error 'No publish-date found.'
}

$dates = @{
    post     = $publishDate
    'social 1' = $publishDate
    'social 2' = $publishDate.AddDays(7)
    'social 3' = $publishDate.AddDays(14)
}
Write-Host "Publish date: $($publishDate.ToString('yyyy-MM-dd'))"

# ── 2. Find sub-issues ────────────────────────────────────────────────────────

Write-Host 'Fetching sub-issues...'
$subData = Invoke-GHGraphQL -Query @'
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        subIssues(first: 20) {
          nodes { number title url body }
        }
      }
    }
  }
'@ -Variables @{ owner = $OWNER; repo = $REPO_NAME; number = $ISSUE_NUMBER }

$subIssues = $subData.data.repository.issue.subIssues.nodes ?? @()
Write-Host "Found $($subIssues.Count) sub-issue(s): $($subIssues.title -join ', ')"

function Get-Category {
    param([string]$Title)
    $t = $Title.ToLower()
    if ($t -like '*[social 3]*' -or $t -like '*social 3*') { return 'social 3' }
    if ($t -like '*[social 2]*' -or $t -like '*social 2*') { return 'social 2' }
    if ($t -like '*[social 1]*' -or $t -like '*social 1*') { return 'social 1' }
    if ($t -like '*[post]*'     -or $t -like 'post*')       { return 'post' }
    return $null
}

# ── 3. Read file info from [Post] sub-issue ────────────────────────────────

$postSubIssue = $subIssues | Where-Object { (Get-Category $_.title) -eq 'post' } | Select-Object -First 1
$filePath  = ''
$imagePath = ''

if ($postSubIssue) {
    # Extract file path from body (backtick-quoted)
    if ($postSubIssue.body -match '`((?:_posts|_books|_models)/[^`\s]+\.md)`') {
        $filePath = $Matches[1]
        # Read image from file front matter
        if (Test-Path $filePath) {
            $fm = Get-Content $filePath -Raw
            if ($fm -match '(?m)^image:\s*([^\r\n]+)') {
                $imagePath = $Matches[1].Trim().TrimStart('/')
            }
        }
    }
}
Write-Host "File: $filePath | Image: $imagePath"

# ── 4. Fetch project metadata ─────────────────────────────────────────────────

Write-Host 'Fetching project metadata...'
$projData = Invoke-GHGraphQL -Query @'
  query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        id
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              __typename id name options { id name }
            }
            ... on ProjectV2Field {
              __typename id name dataType
            }
          }
        }
      }
    }
  }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }

$proj          = $projData.data.user.projectV2
$projectId     = $proj.id
$statusFieldId = $null
$toBePublishedOptionId = $null
$dateFieldId   = $null

foreach ($f in $proj.fields.nodes) {
    if (-not $f) { continue }
    $n = $f.name.ToLower()
    if ($n -eq 'status') {
        $statusFieldId = $f.id
        $opt = $f.options | Where-Object { $_.name -match 'to be|publish' } | Select-Object -First 1
        if ($opt) { $toBePublishedOptionId = $opt.id }
    }
    if ($n -like '*publish*' -and $f.dataType -eq 'DATE') { $dateFieldId = $f.id }
}

Write-Host "Project: $projectId | Status field: $statusFieldId | Date field: $dateFieldId"

function Get-ProjectItemId {
    param([int]$IssueNumber)
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            items(first: 100) {
              nodes { id content { ... on Issue { number } } }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }
    $items = $data.data.user.projectV2.items.nodes
    $match = $items | Where-Object { $_.content.number -eq $IssueNumber } | Select-Object -First 1
    return $match?.id
}

function Set-ProjectDate {
    param([string]$ItemId, [string]$IsoDate)
    if (-not $dateFieldId) { return }
    Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@ -Variables @{
        project = $projectId
        item    = $ItemId
        field   = $dateFieldId
        value   = @{ date = $IsoDate }
    } | Out-Null
}

function Set-ProjectStatus {
    param([string]$ItemId)
    if (-not $statusFieldId -or -not $toBePublishedOptionId) { return }
    Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@ -Variables @{
        project = $projectId
        item    = $ItemId
        field   = $statusFieldId
        value   = @{ singleSelectOptionId = $toBePublishedOptionId }
    } | Out-Null
}

# ── 5. Process each item (main + sub-issues) ──────────────────────────────────

$summary = [ordered]@{}

# Main issue
$mainItemId = Get-ProjectItemId -IssueNumber $ISSUE_NUMBER
if ($mainItemId) {
    Set-ProjectDate   -ItemId $mainItemId -IsoDate $publishDate.ToString('yyyy-MM-dd')
    Set-ProjectStatus -ItemId $mainItemId
    Write-Host "Main issue #$ISSUE_NUMBER → $($publishDate.ToString('yyyy-MM-dd')) → To Be Published"
} else {
    Write-Warning "Main issue #$ISSUE_NUMBER not found in project"
}
$summary["#$ISSUE_NUMBER (Main)"] = $publishDate.ToString('yyyy-MM-dd')

# Sub-issues
foreach ($sub in $subIssues) {
    $cat = Get-Category -Title $sub.title
    if (-not $cat) { Write-Host "  Skipping unrecognised sub-issue: $($sub.title)"; continue }

    $targetDate = $dates[$cat]
    $isoDate    = $targetDate.ToString('yyyy-MM-dd')
    Write-Host "  #$($sub.number) [$cat] → $isoDate"

    # ── update sub-issue body with metadata block ──────────────────────────
    $existingBody = $sub.body ?? ''
    if ($existingBody -notmatch '<!-- CONTENT CALENDAR METADATA') {
        if ($cat -eq 'post') {
            $metaBlock = @"
<!-- CONTENT CALENDAR METADATA
file: $filePath
type: blog
publish-date: $isoDate
social-1-date: $($dates['social 1'].ToString('yyyy-MM-dd'))
social-2-date: $($dates['social 2'].ToString('yyyy-MM-dd'))
social-3-date: $($dates['social 3'].ToString('yyyy-MM-dd'))
image: $imagePath
post-url:
-->

"@
        } else {
            # social N: get the N from category
            $n = ($cat -replace 'social ', '')
            $metaBlock = @"
<!-- CONTENT CALENDAR METADATA
social-$n-date: $isoDate
image: $imagePath
post-url:
-->

"@
        }
        $newBody = $metaBlock + $existingBody
        Invoke-Gh @('issue', 'edit', $sub.number, '--repo', $REPO, '--body', $newBody) `
            -Token $env:GH_TOKEN
    }

    # ── add approve label ──────────────────────────────────────────────────
    Invoke-Gh @('issue', 'edit', $sub.number, '--repo', $REPO, '--add-label', 'approve') `
        -Token $env:GH_TOKEN

    # ── update project item ────────────────────────────────────────────────
    $itemId = Get-ProjectItemId -IssueNumber $sub.number
    if ($itemId) {
        Set-ProjectDate   -ItemId $itemId -IsoDate $isoDate
        Set-ProjectStatus -ItemId $itemId
    } else {
        Write-Warning "  #$($sub.number) not found in project"
    }

    $summary["#$($sub.number) $($sub.title)"] = $isoDate
}

# ── 6. Comment on main issue ──────────────────────────────────────────────────

$rows = $summary.GetEnumerator() | ForEach-Object { "| $($_.Key) | $($_.Value) |" }
$comment = @"
## ✅ Content Calendar Dates Set

| Issue | Publish Date |
|-------|--------------|
$($rows -join "`n")

All cards moved to **To Be Published** in the Content Calendar project.
`approve` label added to all sub-issues — automation is now active.

> To change dates: update ``<!-- publish-date: YYYY-MM-DD -->`` in this issue body, remove the ``scheduled`` label, then re-add it.
"@

Invoke-Gh @('issue', 'comment', $ISSUE_NUMBER, '--repo', $REPO, '--body', $comment) `
    -Token $env:GH_TOKEN

Write-Host "`nDone."
