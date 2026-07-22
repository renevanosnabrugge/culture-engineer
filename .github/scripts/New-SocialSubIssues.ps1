#!/usr/bin/env pwsh
<#
.SYNOPSIS
Creates [Social 1], [Social 2], [Social 3] sub-issues for a content calendar
main issue when it is moved to "To Be Published" in the GitHub Project.

Reads social variant text from the matching social pack file in drafts/:
  drafts/YYYY-MM-DD-<slug>-social.md  OR  drafts/social-<slug>.md

Called automatically by project-transition.yml (scheduled + workflow_dispatch).
Can also be run standalone for testing.

USAGE:
  # Process a specific issue
  pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42

  # Scan the entire project for "To Be Published" items missing social sub-issues
  pwsh .github/scripts/New-SocialSubIssues.ps1

REQUIRES:
  GH_TOKEN (or GITHUB_TOKEN) — repo scope (issues: write, contents: read)
  GH_PROJECT_TOKEN           — PAT with 'project' scope (for Projects v2 GraphQL)
  GITHUB_REPOSITORY          — owner/repo (set automatically in workflows)
  gh CLI installed

PARAMETERS:
  -IssueNumber   Number of the main content issue to process (0 = scan all)
  -Force         Skip the "To Be Published" status check (useful for re-running)

ENV VARS (set by project-transition.yml from event payload):
  ISSUE_NUMBER     — issue number (overridden by -IssueNumber if supplied)
  ITEM_NODE_ID     — project item GraphQL node ID (used by event-triggered path)
  CONTENT_NODE_ID  — issue GraphQL node ID (used by event-triggered path)

SOCIAL SCHEDULE:
  Social 1 → publish date  (same day as post, contrarian hook)
  Social 2 → publish + 7 days
  Social 3 → publish + 14 days
#>

param(
    [int]    $IssueNumber = 0,
    [switch] $Force
)
$ErrorActionPreference = 'Stop'

# Load local secrets if present (gitignored .env.ps1 in repo root)
$_envFile = Join-Path (Split-Path (Split-Path $PSScriptRoot)) '.env.ps1'
if (Test-Path $_envFile) { . $_envFile }

$REPO           = $env:GITHUB_REPOSITORY ?? 'renevanosnabrugge/culture-engineer'
$OWNER          = $REPO.Split('/')[0]
$REPO_NAME      = $REPO.Split('/')[1]
$PROJECT_NUMBER = 9

# Fail fast if project token is missing
if (-not ($env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN)) {
    Write-Error "No token found. Set `$env:GH_PROJECT_TOKEN` to a PAT with 'project' + 'repo' scopes.`nCreate one at: https://github.com/settings/tokens"
}

# ── helpers ───────────────────────────────────────────────────────────────────

function Invoke-Gh {
    param([string[]]$Arguments)
    $out = & gh @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Warning "gh $($Arguments -join ' '): $out" }
    return $out -join "`n"
}

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    $token = $env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN
    $resp  = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
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

# ── resolve project metadata (fields + options) ───────────────────────────────

function Get-ProjectMeta {
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            id
            fields(first: 30) {
              nodes {
                ... on ProjectV2SingleSelectField { __typename id name options { id name } }
                ... on ProjectV2Field             { __typename id name dataType }
              }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }

    $proj   = $data.data.user.projectV2
    $result = @{
        ProjectId             = $proj.id
        StatusFieldId         = $null
        ToBePublishedOptionId = $null
        DraftOptionId         = $null
        DateFieldId           = $null
        PostFileFieldId       = $null
    }

    foreach ($f in $proj.fields.nodes) {
        if (-not $f -or -not $f.name) { continue }
        $n = $f.name.ToLower()
        if ($n -eq 'status') {
            $result.StatusFieldId = $f.id
            foreach ($opt in $f.options) {
                if ($opt.name -match 'to.?be|publish') { $result.ToBePublishedOptionId = $opt.id }
                if ($opt.name -match 'draft')           { $result.DraftOptionId         = $opt.id }
            }
        }
        if ($f.__typename -eq 'ProjectV2Field' -and $f.dataType -eq 'DATE' -and $n -like '*publish*') {
            $result.DateFieldId = $f.id
        }
        if ($f.__typename -eq 'ProjectV2Field' -and $f.dataType -eq 'TEXT' -and
            ($n -like '*post*file*' -or $n -like '*file*path*' -or $n -eq 'post file' -or $n -eq 'file')) {
            $result.PostFileFieldId = $f.id
        }
    }
    return $result
}

# ── get project item data (id + field values) for a given issue number ────────
# Queries via issue.projectItems — works regardless of total project size.

function Get-ProjectItem {
    param([int]$IssNum, [string]$ProjectId, [string]$StatusFieldId, [string]$DateFieldId, [string]$PostFileFieldId)
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
          issue(number: $number) {
            projectItems(first: 10) {
              nodes {
                id
                project { number }
                fieldValues(first: 20) {
                  nodes {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      field { ... on ProjectV2SingleSelectField { id name } }
                      name optionId
                    }
                    ... on ProjectV2ItemFieldDateValue {
                      field { ... on ProjectV2Field { id name } }
                      date
                    }
                    ... on ProjectV2ItemFieldTextValue {
                      field { ... on ProjectV2Field { id name } }
                      text
                    }
                  }
                }
              }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; repo = $REPO_NAME; number = $IssNum }

    # Return the item that belongs to our specific project
    $allNodes = $data.data.repository.issue.projectItems.nodes
    $projItem = $allNodes | Where-Object { $_.project.number -eq $PROJECT_NUMBER } | Select-Object -First 1
    # Deep-clone via JSON to materialise all arrays and prevent lazy-enumerator consumption
    if ($projItem) { $projItem = $projItem | ConvertTo-Json -Depth 10 | ConvertFrom-Json }
    return $projItem
}

# ── get all project items with status "To Be Published" ──────────────────────

function Get-ToBePublishedItems {
    param([string]$ToBePublishedOptionId)
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            items(last: 200) {
              nodes {
                id
                content {
                  ... on Issue { number title }
                }
                fieldValues(first: 20) {
                  nodes {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      field { ... on ProjectV2SingleSelectField { name } }
                      optionId
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
              }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }

    return $data.data.user.projectV2.items.nodes | Where-Object {
        $_.content -and $_.content.number -and
        ($_.fieldValues.nodes | Where-Object {
            $_.field.name -eq 'Status' -and $_.optionId -eq $ToBePublishedOptionId
        })
    }
}

# ── set a project field value ─────────────────────────────────────────────────

$SetFieldMutation = @'
  mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $project itemId: $item fieldId: $field value: $value
    }) { projectV2Item { id } }
  }
'@

function Set-ProjectField {
    param([string]$ProjectId, [string]$ItemId, [string]$FieldId, $Value)
    Invoke-GHGraphQL -Query $SetFieldMutation -Variables @{
        project = $ProjectId; item = $ItemId; field = $FieldId; value = $Value
    } | Out-Null
}

# ── get issue GraphQL node ID ─────────────────────────────────────────────────

function Get-IssueNodeId {
    param([int]$Number)
    $data = Invoke-GHGraphQL -Query @'
      query($o: String!, $r: String!, $n: Int!) {
        repository(owner: $o, name: $r) { issue(number: $n) { id } }
      }
'@ -Variables @{ o = $OWNER; r = $REPO_NAME; n = $Number }
    return $data.data.repository.issue.id
}

# ── add sub-issue link ────────────────────────────────────────────────────────

function Add-SubIssueLink {
    param([string]$ParentNodeId, [string]$ChildNodeId)
    $result = Invoke-GHGraphQL -Query @'
      mutation($parentId: ID!, $childId: ID!) {
        addSubIssue(input: { issueId: $parentId, subIssueId: $childId }) {
          issue { number }
        }
      }
'@ -Variables @{ parentId = $ParentNodeId; childId = $ChildNodeId }
    if ($result.errors) { Write-Warning "addSubIssue: $($result.errors | ConvertTo-Json -Compress)" }
}

# ── get existing sub-issues ───────────────────────────────────────────────────

function Get-SubIssues {
    param([int]$Number)
    $data = Invoke-GHGraphQL -Query @'
      query($o: String!, $r: String!, $n: Int!) {
        repository(owner: $o, name: $r) {
          issue(number: $n) {
            subIssues(first: 20) { nodes { number title } }
          }
        }
      }
'@ -Variables @{ o = $OWNER; r = $REPO_NAME; n = $Number }
    return $data.data.repository.issue.subIssues.nodes ?? @()
}

# ── extract file path from issue ──────────────────────────────────────────────

function Get-FilePath {
    param($ProjectItem, [string]$PostFileFieldId, [string]$IssueBody)

    # Priority 1: Project "Post File" TEXT field
    if ($PostFileFieldId) {
        $val = $ProjectItem?.fieldValues.nodes |
               Where-Object { $_.field.id -eq $PostFileFieldId } |
               Select-Object -First 1
        if ($val?.text) { return $val.text }
    }

    # Priority 2: <!-- POST-FILE: path --> comment in body (New-DraftCard.ps1 format)
    if ($IssueBody -match '<!--\s*POST-FILE:\s*([^\s>]+)\s*-->') {
        return $Matches[1].Trim()
    }

    # Priority 3: file: path in old CONTENT CALENDAR METADATA block
    if ($IssueBody -match '(?m)^file:\s*([^\r\n]+)') {
        return $Matches[1].Trim()
    }

    return ''
}

# ── extract publish date from issue ──────────────────────────────────────────

function Get-PublishDate {
    param($ProjectItem, [string]$DateFieldId, [string]$IssueBody)

    # Priority 1: Project "Publish Date" DATE field
    if ($DateFieldId) {
        $val = $ProjectItem?.fieldValues.nodes |
               Where-Object { $_.field.id -eq $DateFieldId } |
               Select-Object -First 1
        if ($val?.date) {
            return [datetime]::ParseExact($val.date.Substring(0,10), 'yyyy-MM-dd', $null)
        }
    }

    # Priority 2: <!-- publish-date: YYYY-MM-DD --> in body
    if ($IssueBody -match '<!--\s*publish-date:\s*(\d{4}-\d{2}-\d{2})\s*-->') {
        return [datetime]::ParseExact($Matches[1], 'yyyy-MM-dd', $null)
    }

    return $null
}

# ── find social pack file ─────────────────────────────────────────────────────

function Find-SocialPackFile {
    param([string]$PostFilePath)
    $leaf   = Split-Path $PostFilePath -Leaf
    $slug   = ($leaf -replace '^\d{4}-\d{2}-\d{2}-', '') -replace '\.md$', ''
    $prefix = if ($leaf -match '^(\d{4}-\d{2}-\d{2})-') { $Matches[1] } else { '' }

    $candidates = @(
        if ($prefix) { "drafts/$prefix-$slug-social.md" }
        "drafts/social-$slug.md"
        "drafts/$slug-social.md"
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

# ── parse social variants from social pack file ───────────────────────────────

function Get-SocialVariants {
    param([string]$FilePath)
    $text     = Get-Content $FilePath -Raw -Encoding UTF8
    $variants = @{}

    # Match: ## Variant N: Title   or   ## LinkedIn — Variant N ...
    $pattern = '(?s)##\s+(?:Variant|LinkedIn[^\n]*Variant)\s*(\d)[^\n]*\n\n(.*?)(?=\n---\n|\n##\s|\z)'
    foreach ($m in [regex]::Matches($text, $pattern)) {
        $n              = $m.Groups[1].Value
        $variants["$n"] = $m.Groups[2].Value.Trim()
    }
    return $variants
}

# ── add issue to project + set fields ────────────────────────────────────────

function Add-IssueToProject {
    param([int]$IssueNum, [string]$ProjectId,
          [string]$StatusFieldId, [string]$StatusOptionId,
          [string]$DateFieldId,   [string]$IsoDate)

    # Get issue node ID
    $nodeData = Invoke-GHGraphQL -Query @'
      query($o: String!, $r: String!, $n: Int!) {
        repository(owner: $o, name: $r) { issue(number: $n) { id } }
      }
'@ -Variables @{ o = $OWNER; r = $REPO_NAME; n = $IssueNum }
    $issueNodeId = $nodeData.data.repository.issue.id

    # Add to project via mutation (no gh CLI project scope needed)
    $addResult = Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $content: ID!) {
        addProjectV2ItemById(input: { projectId: $project contentId: $content }) {
          item { id }
        }
      }
'@ -Variables @{ project = $ProjectId; content = $issueNodeId }
    $itemId = $addResult.data.addProjectV2ItemById.item.id

    if (-not $itemId) { Write-Warning "Could not add issue #$IssueNum to project"; return }

    if ($StatusFieldId -and $StatusOptionId) {
        Set-ProjectField -ProjectId $ProjectId -ItemId $itemId `
            -FieldId $StatusFieldId -Value @{ singleSelectOptionId = $StatusOptionId }
    }
    if ($DateFieldId -and $IsoDate) {
        Set-ProjectField -ProjectId $ProjectId -ItemId $itemId `
            -FieldId $DateFieldId -Value @{ date = $IsoDate }
    }
    return $itemId
}

# ── core: process a single issue ──────────────────────────────────────────────

function Invoke-ProcessIssue {
    param([int]$Number, [psobject]$Meta, [switch]$ForceRun)

    Write-Host ""
    Write-Host "── Processing issue #$Number ──────────────────────────────────────────"

    # Fetch issue details
    $issueRaw  = Invoke-Gh @('issue', 'view', $Number, '--repo', $REPO,
        '--json', 'number,title,body,labels,url')
    $mainIssue = $issueRaw | ConvertFrom-Json

    # Skip social sub-issues themselves
    if ($mainIssue.title -match '^\[Social') {
        Write-Host "  Skipping social sub-issue: $($mainIssue.title)"
        return
    }

    # Skip already published
    if ($mainIssue.labels | Where-Object { $_.name -eq 'published' }) {
        Write-Host "  Already published — skipping."
        return
    }

    # Check if social sub-issues already created
    $existingSubs = Get-SubIssues -Number $Number
    if ($existingSubs | Where-Object { $_.title -match '^\[Social' }) {
        Write-Host "  Social sub-issues already exist — skipping."
        return
    }

    # Verify status (skip check when -Force or called from workflow_dispatch without event)
    if (-not $ForceRun) {
        $projItem = Get-ProjectItem -IssNum $Number -ProjectId $Meta.ProjectId `
            -StatusFieldId $Meta.StatusFieldId -DateFieldId $Meta.DateFieldId `
            -PostFileFieldId $Meta.PostFileFieldId
        $statusName = ($projItem?.fieldValues.nodes |
            Where-Object { $_.field.name -eq 'Status' } |
            Select-Object -First 1)?.name
        if ($statusName -notmatch 'to.?be|publish') {
            Write-Host "  Status is '$statusName' — not 'To Be Published'. Use -Force to override."
            return
        }
    } else {
        $projItem = Get-ProjectItem -IssNum $Number -ProjectId $Meta.ProjectId `
            -StatusFieldId $Meta.StatusFieldId -DateFieldId $Meta.DateFieldId `
            -PostFileFieldId $Meta.PostFileFieldId
    }

    # ── resolve file path ────────────────────────────────────────────────────
    $filePath = Get-FilePath -ProjectItem $projItem -PostFileFieldId $Meta.PostFileFieldId `
        -IssueBody ($mainIssue.body ?? '')

    if (-not $filePath) {
        $msg = "⚠️ **Cannot create social sub-issues**: no file path found for issue #$Number.`n`nSet the **Post File** project field or add ``<!-- POST-FILE: _posts/slug.md -->`` to the issue body."
        Invoke-Gh @('issue', 'comment', $Number, '--repo', $REPO, '--body', $msg)
        Write-Warning "No file path for #$Number — skipping."
        return
    }

    # ── resolve publish date ──────────────────────────────────────────────────
    $publishDate = Get-PublishDate -ProjectItem $projItem -DateFieldId $Meta.DateFieldId `
        -IssueBody ($mainIssue.body ?? '')

    if (-not $publishDate) {
        $msg = "⚠️ **Cannot create social sub-issues**: no publish date found for issue #$Number.`n`nSet the **Publish Date** project field or add ``<!-- publish-date: YYYY-MM-DD -->`` to the issue body."
        Invoke-Gh @('issue', 'comment', $Number, '--repo', $REPO, '--body', $msg)
        Write-Warning "No publish date for #$Number — skipping."
        return
    }

    $dates = @{
        'social-1' = $publishDate
        'social-2' = $publishDate.AddDays(7)
        'social-3' = $publishDate.AddDays(14)
    }

    Write-Host "  File         : $filePath"
    Write-Host "  Publish date : $($publishDate.ToString('yyyy-MM-dd'))"

    # ── read image from file front matter ─────────────────────────────────────
    $imagePath = ''
    if (Test-Path $filePath) {
        $fm = Get-Content $filePath -Raw
        if ($fm -match '(?m)^image:\s*([^\r\n]+)') {
            $imagePath = $Matches[1].Trim().TrimStart('/')
        }
    }

    # ── find + parse social pack file ─────────────────────────────────────────
    $socialFile = Find-SocialPackFile -PostFilePath $filePath
    $variants   = @{}
    if ($socialFile) {
        Write-Host "  Social pack  : $socialFile"
        $variants = Get-SocialVariants -FilePath $socialFile
        Write-Host "  Variants     : $($variants.Keys -join ', ')"
    } else {
        Write-Warning "  No social pack file found for '$filePath'. Sub-issues will have placeholder text."
    }

    $postTitle = $mainIssue.title -replace '^\[Post\]\s*', ''

    # ── update main issue: add approve label + metadata block ─────────────────
    $hasApprove = $mainIssue.labels | Where-Object { $_.name -eq 'approve' }
    $hasMeta    = $mainIssue.body -match 'CONTENT CALENDAR METADATA'

    if (-not $hasMeta) {
        $metaBlock = @"
<!-- CONTENT CALENDAR METADATA
file: $filePath
type: blog
publish-date: $($publishDate.ToString('yyyy-MM-dd'))
social-1-date: $($dates['social-1'].ToString('yyyy-MM-dd'))
social-2-date: $($dates['social-2'].ToString('yyyy-MM-dd'))
social-3-date: $($dates['social-3'].ToString('yyyy-MM-dd'))
image: $imagePath
post-url:
-->

"@
        $newBody = $metaBlock + ($mainIssue.body ?? '')
        Invoke-Gh @('issue', 'edit', $Number, '--repo', $REPO, '--body', $newBody)
        Write-Host "  Main issue body updated with metadata block."
    }

    if (-not $hasApprove) {
        Invoke-Gh @('issue', 'edit', $Number, '--repo', $REPO, '--add-label', 'approve')
        Write-Host "  Added 'approve' label to main issue."
    }

    # ── create [Social N] sub-issues ──────────────────────────────────────────
    $parentNodeId  = Get-IssueNodeId -Number $Number
    $createdSocials = @()

    for ($n = 1; $n -le 3; $n++) {
        $key       = "social-$n"
        $targetDate = $dates[$key]
        $varText   = $variants["$n"] ?? "[Add LinkedIn Variant $n text here]"

        $body = @"
<!-- CONTENT CALENDAR METADATA
social-$n-date: $($targetDate.ToString('yyyy-MM-dd'))
image: $imagePath
post-url:
-->

$varText
"@

        Write-Host "  Creating [Social $n] ($($targetDate.ToString('yyyy-MM-dd')))..."
        $subUrl = & gh issue create `
            --repo  $REPO `
            --title "[Social $n] $postTitle" `
            --body  $body `
            --label 'content-calendar' `
            --label 'approve' 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Warning "gh issue create failed for Social ${n}: $subUrl"; continue }
        $subUrl    = $subUrl.Trim()
        $subNumber = [int](($subUrl -split '/')[-1])
        $sub = [pscustomobject]@{ url = $subUrl; number = $subNumber }
        Write-Host "    Issue #$($sub.number): $($sub.url)"

        # Link as sub-issue
        $childNodeId = Get-IssueNodeId -Number $sub.number
        Add-SubIssueLink -ParentNodeId $parentNodeId -ChildNodeId $childNodeId

        # Add to project with date + status
        Add-IssueToProject -IssueNum $sub.number `
            -ProjectId $Meta.ProjectId `
            -StatusFieldId $Meta.StatusFieldId -StatusOptionId $Meta.ToBePublishedOptionId `
            -DateFieldId   $Meta.DateFieldId   -IsoDate $targetDate.ToString('yyyy-MM-dd') | Out-Null

        $createdSocials += [pscustomobject]@{ Number = $sub.number; Date = $targetDate }
    }

    # ── ensure main issue is in "To Be Published" with date set ──────────────
    if ($projItem -and $Meta.StatusFieldId -and $Meta.ToBePublishedOptionId) {
        Set-ProjectField -ProjectId $Meta.ProjectId -ItemId $projItem.id `
            -FieldId $Meta.StatusFieldId -Value @{ singleSelectOptionId = $Meta.ToBePublishedOptionId }
    }
    if ($projItem -and $Meta.DateFieldId) {
        Set-ProjectField -ProjectId $Meta.ProjectId -ItemId $projItem.id `
            -FieldId $Meta.DateFieldId -Value @{ date = $publishDate.ToString('yyyy-MM-dd') }
    }

    # ── comment summary on main issue ─────────────────────────────────────────
    $rows = $createdSocials | ForEach-Object { $i = 0 } { $i++; "| [Social $i] #$($_.Number) | $($_.Date.ToString('yyyy-MM-dd')) |" }
    $comment = @"
## 📅 Social sub-issues created

| Issue | Scheduled date |
|-------|---------------|
| [Post] (this issue) | $($publishDate.ToString('yyyy-MM-dd')) |
$($rows -join "`n")

All items moved to **To Be Published** in the project.
Remove the ``approve`` label to pause any item.
"@
    Invoke-Gh @('issue', 'comment', $Number, '--repo', $REPO, '--body', $comment)
    Write-Host "  Done. $($createdSocials.Count) social sub-issues created."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

Write-Host "New-SocialSubIssues.ps1 — $(Get-Date -Format 'yyyy-MM-dd HH:mm')"

# Load project metadata once
$meta = Get-ProjectMeta
Write-Host "Project #$PROJECT_NUMBER : $($meta.ProjectId)"
Write-Host "Status field   : $($meta.StatusFieldId) (To Be Published: $($meta.ToBePublishedOptionId))"
Write-Host "Publish Date   : $($meta.DateFieldId)"
Write-Host "Post File      : $(if ($meta.PostFileFieldId) { $meta.PostFileFieldId } else { '(field not found)' })"

# Resolve issue number from env/param/event
if ($IssueNumber -eq 0) { $IssueNumber = [int]($env:ISSUE_NUMBER ?? 0) }

if ($IssueNumber -eq 0 -and $env:CONTENT_NODE_ID) {
    $nodeData    = Invoke-GHGraphQL -Query @'
      query($id: ID!) { node(id: $id) { ... on Issue { number } } }
'@ -Variables @{ id = $env:CONTENT_NODE_ID }
    $IssueNumber = [int]($nodeData.data.node.number ?? 0)
}

# ── SINGLE ISSUE MODE ─────────────────────────────────────────────────────────
if ($IssueNumber -gt 0) {
    Write-Host "Mode: single issue #$IssueNumber"
    Invoke-ProcessIssue -Number $IssueNumber -Meta $meta -ForceRun:$Force
    Write-Host "`nDone."
    exit 0
}

# ── SCAN MODE: iterate all "To Be Published" items ────────────────────────────
Write-Host "Mode: scanning project for 'To Be Published' items without social sub-issues..."

if (-not $meta.ToBePublishedOptionId) {
    Write-Error "Could not find 'To Be Published' option in Status field."
}

$items     = Get-ToBePublishedItems -ToBePublishedOptionId $meta.ToBePublishedOptionId
$postItems = $items | Where-Object { $_.content.title -notmatch '^\[Social' }

Write-Host "Found $($postItems.Count) post item(s) in 'To Be Published'."

foreach ($item in $postItems) {
    Invoke-ProcessIssue -Number $item.content.number -Meta $meta -ForceRun:$Force
}

Write-Host "`nScan complete."
