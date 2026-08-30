#!/usr/bin/env pwsh
<#
.SYNOPSIS
Creates three [Social N] project cards (one per LinkedIn variant) for a [Content]
tracking issue, so each variant can be scheduled and tracked independently on the
GitHub Project board.

USAGE:
  pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42
  pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42 -Force

PARAMETERS:
  -IssueNumber  The [Content] tracking issue number (required).
  -Force        Skip confirmation prompt.

EFFECT:
  - Creates issues [Social 1], [Social 2], [Social 3] referencing the parent.
  - Adds each to GitHub Project #9 with the scheduled publish date.
  - Updates social-N-date lines in the parent issue metadata block.
  - Comments on the parent issue with links to the three new issues.

The LinkedIn poster reads the Publish Date from each [Social N] project card.
Social dates default to publish-date, +7, and +14 days from the [Content]
project card's Publish Date field.

REQUIRES:
  GH_TOKEN (or GITHUB_TOKEN) -- repo scope (issues: write)
  GH_PROJECT_TOKEN           -- PAT with 'project' scope (for Projects v2 GraphQL)
  gh CLI installed
#>

param(
    [Parameter(Mandatory)]
    [int]$IssueNumber,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8

$_envFile = Join-Path (Split-Path (Split-Path $PSScriptRoot)) '.env.ps1'
if (Test-Path $_envFile) { . $_envFile }

$REPO           = $env:GITHUB_REPOSITORY ?? 'renevanosnabrugge/culture-engineer'
$OWNER          = $REPO.Split('/')[0]
$REPO_NAME      = $REPO.Split('/')[1]
$PROJECT_NUMBER = 9

$VARIANT_LABELS = @{
    1 = 'Contrarian hook'
    2 = 'Story format'
    3 = 'Question format'
}

# ── helpers ───────────────────────────────────────────────────────────────────

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $token = $env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN
    if (-not $token) { Write-Error "No token. Set GH_PROJECT_TOKEN to a PAT with 'project' + 'repo' scopes." }
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
        -Method POST `
        -Headers @{
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
            'User-Agent'   = 'culture-engineer-bot'
        } `
        -Body $body
    if ($resp.errors) { Write-Warning "GraphQL: $($resp.errors | ConvertTo-Json -Compress)" }
    return $resp
}

function ConvertFrom-Metadata {
    param([string]$Body)
    $meta = @{}
    if ($Body -match '(?s)<!-- CONTENT CALENDAR METADATA\r?\n(.*?)-->') {
        foreach ($line in ($Matches[1] -split '\r?\n')) {
            if ($line -match '^([^:\s]+):\s*(.*)$') { $meta[$Matches[1]] = $Matches[2].Trim() }
        }
    }
    return $meta
}

function Get-ProjectFieldValue {
    param([array]$FieldValues, [string]$NamePattern)
    foreach ($fv in ($FieldValues ?? @())) {
        if (-not $fv -or -not $fv.field) { continue }
        if ($fv.field.name -match $NamePattern) {
            return ($fv.name ?? $fv.date ?? $fv.text)
        }
    }
    return $null
}

function Get-VariantText {
    param([string]$Body, [int]$N)
    $pattern = "(?s)## LinkedIn[^\n]*Variant $N[^\n]*\n+(.*?)(?=\n---\n|\n## LinkedIn|\z)"
    if ($Body -match $pattern) {
        $text = $Matches[1].Trim()
        if ($text -and $text -notmatch '^<!--') { return $text }
    }
    return $null
}

function Add-ToProject {
    param([string]$IssueUrl, [string]$PublishDate)

    $num = [int]($IssueUrl -replace '.+/issues/(\d+)$', '$1')

    $nodeId = (Invoke-GHGraphQL -Query @'
      query($o: String!, $r: String!, $n: Int!) {
        repository(owner: $o, name: $r) { issue(number: $n) { id } }
      }
'@ -Variables @{ o = $OWNER; r = $REPO_NAME; n = $num }).data.repository.issue.id

    if (-not $nodeId) { Write-Warning "  Could not resolve node ID for #$num"; return }

    $itemId = (Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $content: ID!) {
        addProjectV2ItemById(input: { projectId: $project contentId: $content }) {
          item { id }
        }
      }
'@ -Variables @{ project = $script:projectId; content = $nodeId }).data.addProjectV2ItemById.item.id

    if (-not $itemId) { Write-Warning "  Could not add #$num to project"; return }

    $setField = @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@
    # Status → To Be Published
    if ($script:statusFieldId -and $script:statusOptionId) {
        Invoke-GHGraphQL -Query $setField -Variables @{
            project = $script:projectId; item = $itemId
            field   = $script:statusFieldId
            value   = @{ singleSelectOptionId = $script:statusOptionId }
        } | Out-Null
    }

    # Publish Date
    if ($script:dateFieldId -and $PublishDate -and $PublishDate -ne 'YYYY-MM-DD') {
        Invoke-GHGraphQL -Query $setField -Variables @{
            project = $script:projectId; item = $itemId
            field   = $script:dateFieldId
            value   = @{ date = $PublishDate }
        } | Out-Null
        Write-Host "  Publish Date -> $PublishDate"
    }
}

# ── 1. Read parent issue ──────────────────────────────────────────────────────

Write-Host "Reading issue #$IssueNumber..."
$parentRaw = & gh issue view $IssueNumber --repo $REPO --json number,title,body,url 2>&1
if ($LASTEXITCODE -ne 0) { Write-Error "Could not read issue #${IssueNumber}: $parentRaw" }
$parent      = $parentRaw | ConvertFrom-Json
$parentTitle = $parent.title -replace '^\[Content\]\s*', ''
$parentBody  = $parent.body ?? ''
$meta        = ConvertFrom-Metadata -Body $parentBody

Write-Host "Title: $parentTitle"

# ── 2. Validate and calculate social dates ────────────────────────────────────

$publishDate = $null
$socialDates = @{ 1 = $null; 2 = $null; 3 = $null }

if (-not $Force) {
    Write-Host ""
    $ans = Read-Host "Create 3 social cards? [Y/n]"
    if ($ans -match '^[Nn]') { Write-Host "Aborted."; exit 0 }
}

# ── 3. Fetch project metadata ─────────────────────────────────────────────────

Write-Host ""
Write-Host "Fetching project #$PROJECT_NUMBER metadata..."
$projData  = Invoke-GHGraphQL -Query @'
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

$proj                   = $projData.data.user.projectV2
$script:projectId       = $proj.id
$script:statusFieldId   = $null
$script:statusOptionId  = $null
$script:dateFieldId     = $null

foreach ($f in $proj.fields.nodes) {
    if (-not $f -or -not $f.name) { continue }
    $n = $f.name.ToLower()
    if ($n -eq 'status') {
        $script:statusFieldId = $f.id
        $opt = $f.options | Where-Object { $_.name -match '(?i)to.?be' } | Select-Object -First 1
        if ($opt) { $script:statusOptionId = $opt.id }
    }
    if ($f.__typename -eq 'ProjectV2Field' -and $f.dataType -eq 'DATE' -and $n -like '*publish*') {
        $script:dateFieldId = $f.id
    }
}

if (-not $script:projectId) { Write-Error "Project #$PROJECT_NUMBER not found. Check GH_PROJECT_TOKEN." }

# Read the parent card's Publish Date from the project. Metadata remains a
# backwards-compatible fallback for cards created before project fields existed.
$parentItemData = Invoke-GHGraphQL -Query @'
  query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        items(first: 100) {
          nodes {
            fieldValues(first: 20) {
              nodes {
                ... on ProjectV2ItemFieldDateValue {
                  field { ... on ProjectV2Field { name } }
                  date
                }
              }
            }
            content { ... on Issue { number } }
          }
        }
      }
    }
  }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }
$parentItem = $parentItemData?.data.user.projectV2.items.nodes |
    Where-Object { $_.content.number -eq $IssueNumber } |
    Select-Object -First 1
if ($parentItem) {
    $publishDate = Get-ProjectFieldValue -FieldValues $parentItem.fieldValues.nodes -NamePattern '(?i)publish.?date'
} else {
    Write-Warning "Project card for #$IssueNumber was not found; falling back to issue metadata."
}
if (-not $publishDate) { $publishDate = $meta['publish-date'] }
if (-not $publishDate -or $publishDate -eq 'YYYY-MM-DD') {
    Write-Error "No Publish Date found on project card for #$IssueNumber. Set it in the GitHub Project before creating social cards."
}
try {
    $publishDateValue = [datetime]::ParseExact($publishDate, 'yyyy-MM-dd', $null)
    $publishDate = $publishDateValue.ToString('yyyy-MM-dd')
} catch {
    Write-Error "Invalid Publish Date '$publishDate' on project card for #$IssueNumber. Use YYYY-MM-DD."
}
foreach ($v in 1..3) {
    $socialDates[$v] = $publishDateValue.AddDays(($v - 1) * 7).ToString('yyyy-MM-dd')
}
Write-Host "Parent Publish Date: $publishDate"

foreach ($lbl in @('content-calendar', 'social-post')) {
    $exists = & gh label list --repo $REPO --json name | ConvertFrom-Json | Where-Object name -eq $lbl
    if (-not $exists) {
        Write-Host "Creating label: $lbl"
        & gh label create $lbl --repo $REPO --color '#0075ca' | Out-Null
    }
}

# ── 5. Create the three social issues ────────────────────────────────────────

$createdIssues = @{}

foreach ($v in 1..3) {
    $variantText = Get-VariantText -Body $parentBody -N $v
    $variantNote = if ($variantText) { $variantText } else { "<!-- Add LinkedIn variant $v text here -->" }

    $body = @"
<!-- SOCIAL METADATA
parent: #$($parent.number)
variant: $v
post-date: $($socialDates[$v])
-->

**Parent issue:** #$($parent.number) — $parentTitle
**Variant:** $v ($($VARIANT_LABELS[$v]))
**Scheduled:** $($socialDates[$v])

---

$variantNote
"@

    Write-Host ""
    Write-Host "Creating [Social $v] $parentTitle..."
    $issueUrl = & gh issue create `
        --repo  $REPO `
        --title "[Social $v] $parentTitle" `
        --body  $body `
        --label 'content-calendar' `
        --label 'social-post' 2>&1

    if ($LASTEXITCODE -ne 0) { Write-Warning "Failed to create [Social $v]: $issueUrl"; continue }
    $issueUrl = $issueUrl.Trim()
    $issueNum = [int]($issueUrl -replace '.+/issues/(\d+)$', '$1')
    Write-Host "  Issue #$issueNum created: $issueUrl"

    Add-ToProject -IssueUrl $issueUrl -PublishDate $socialDates[$v]
    $createdIssues[$v] = $issueNum
}

# ── 6. Update parent issue metadata block with social dates ───────────────────

Write-Host ""
Write-Host "Updating parent #$($parent.number) metadata block..."

$newMeta = $parentBody
if ($newMeta -match '(?m)^publish-date:') {
    $newMeta = $newMeta -replace '(?m)^publish-date:.*$', "publish-date: $publishDate"
}
foreach ($v in 1..3) {
    $date = $socialDates[$v]
    $key  = "social-$v-date"
    if ($newMeta -match "(?m)^${key}:") {
        # Replace existing line
        $newMeta = $newMeta -replace "(?m)^${key}:.*$", "${key}: $date"
    } else {
        # Insert after publish-date line
        $newMeta = $newMeta -replace "(?m)^(publish-date:.*)$", "`$1`n${key}: $date"
    }
}

# Write updated body back to the issue
$tmpFile = [System.IO.Path]::GetTempFileName()
Set-Content $tmpFile $newMeta -Encoding UTF8
& gh issue edit $parent.number --repo $REPO --body-file $tmpFile | Out-Null
Remove-Item $tmpFile
Write-Host "  social dates written to [Social N] project cards"

# Metadata block still updated for backward compat with label-based fallback path

$commentLines = @("Social cards created:")
foreach ($v in 1..3) {
    if ($createdIssues[$v]) {
        $commentLines += "- **Variant $v** ($($VARIANT_LABELS[$v])): #$($createdIssues[$v]) — scheduled $($socialDates[$v])"
    }
}
$commentLines += ""
$commentLines += "Set the Publish Date on each card in the project board to control when each variant goes out."

& gh issue comment $parent.number --repo $REPO --body ($commentLines -join "`n") | Out-Null

# ── summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Done. 3 social sub-issues created."
foreach ($v in 1..3) {
    if ($createdIssues[$v]) {
        Write-Host "  [Social $v] #$($createdIssues[$v])  $($socialDates[$v])  ($($VARIANT_LABELS[$v]))"
    }
}
