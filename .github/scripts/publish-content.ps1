#!/usr/bin/env pwsh
<#
.SYNOPSIS
Content Scheduler: publishes content by setting published: true on the publish-date.

Reads [Content] issues labeled content-calendar + approve.
Each issue contains a CONTENT CALENDAR METADATA block with file path and
publish-date. When publish-date matches today, sets published: true in the
content file, commits, pushes (triggers deploy), adds the 'published' label,
comments with the live URL, and moves the project card to Published.
#>

param()
$ErrorActionPreference = 'Stop'

$TODAY          = (Get-Date).ToString('yyyy-MM-dd')
$REPO           = $env:GITHUB_REPOSITORY
$SITE_URL       = 'https://culture-engineers.nl'
$OWNER          = $REPO.Split('/')[0]
$PROJECT_NUMBER = 9

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
    if (-not $token) { return $null }  # Skip project updates if token not provided
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

# Resolve project metadata (done once, lazily)
$script:ProjectMeta = $null
function Get-ProjectMeta {
    if ($script:ProjectMeta) { return $script:ProjectMeta }
    $data = Invoke-GHGraphQL -Query @'
      query($owner: String!, $number: Int!) {
        user(login: $owner) {
          projectV2(number: $number) {
            id
            fields(first: 20) {
              nodes {
                ... on ProjectV2SingleSelectField { __typename id name options { id name } }
              }
            }
          }
        }
      }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }
    if (-not $data) { return $null }
    $proj    = $data.data.user.projectV2
    $status  = $proj.fields.nodes | Where-Object { $_.name -and $_.name.ToLower() -eq 'status' } | Select-Object -First 1
    $pubOpt  = $status?.options | Where-Object { $_.name -match 'publish' -and $_.name -notmatch 'to.?be' } | Select-Object -First 1
    $script:ProjectMeta = @{
        ProjectId        = $proj.id
        StatusFieldId    = $status?.id
        PublishedOptId   = $pubOpt?.id
    }
    return $script:ProjectMeta
}

function Set-ProjectItemPublished {
    param([int]$IssueNumber)
    $m = Get-ProjectMeta
    if (-not $m -or -not $m.StatusFieldId -or -not $m.PublishedOptId) { return }

    # Find item in project
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
    $match = $data?.data.user.projectV2.items.nodes |
             Where-Object { $_.content.number -eq $IssueNumber } |
             Select-Object -First 1
    if (-not $match) { return }

    Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@ -Variables @{
        project = $m.ProjectId
        item    = $match.id
        field   = $m.StatusFieldId
        value   = @{ singleSelectOptionId = $m.PublishedOptId }
    } | Out-Null
    Write-Host "  Project item #$IssueNumber → Published"
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

function Get-PostUrl {
    param([string]$FilePath)
    $leaf = Split-Path $FilePath -Leaf
    if ($leaf -match '^(\d{4})-(\d{2})-(\d{2})-(.+)\.md$') {
        return "$SITE_URL/$($Matches[1])/$($Matches[2])/$($Matches[3])/$($Matches[4])/"
    }
    return ''
}

function Set-PublishedFlag {
    param([string]$FilePath)
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    if ($content -match 'published:\s*true') {
        Write-Host "  Already published:true — $FilePath"
        return $false
    }
    if ($content -match 'published:\s*false') {
        $updated = $content -replace 'published:\s*false', 'published: true'
    } else {
        # Insert before the closing --- of front matter
        $updated = [regex]::Replace(
            $content,
            '(?s)(---\r?\n(?:(?!---\r?\n)[\s\S])*?)(---\r?\n)',
            { param($m) "$($m.Groups[1].Value)published: true`n$($m.Groups[2].Value)" },
            1
        )
    }
    [System.IO.File]::WriteAllText((Resolve-Path $FilePath), $updated, [System.Text.Encoding]::UTF8)
    return $true
}

# ── main ─────────────────────────────────────────────────────────────────────

Write-Host "Content Scheduler — $TODAY"

$raw = Invoke-Gh @(
    'issue', 'list', '--repo', $REPO,
    '--label', 'content-calendar', '--label', 'approve',
    '--state', 'open',
    '--json', 'number,title,labels,body',
    '--limit', '50'
)
$issues = if ($raw) { $raw | ConvertFrom-Json } else { @() }
Write-Host "Found $($issues.Count) approved calendar issue(s)"

foreach ($issue in $issues) {
    $labels = $issue.labels | ForEach-Object { $_.name }

    # Skip already published
    if ('published' -in $labels) { continue }

    $meta        = ConvertFrom-Metadata -Body ($issue.body ?? '')
    $publishDate = $meta['publish-date']
    $filePath    = $meta['file']

    if (-not $publishDate -or -not $filePath) {
        Write-Host "  #$($issue.number): missing metadata — skipping"
        continue
    }
    if ($publishDate -ne $TODAY) { continue }

    Write-Host ""
    Write-Host "Publishing #$($issue.number): $($issue.title)"
    Write-Host "  File: $filePath"

    if (-not (Test-Path $filePath)) {
        $msg = "⚠️ Cannot publish: \`$filePath\` not found. Ensure the draft is merged into \`_posts/\`."
        Write-Host "  ERROR: $msg"
        Invoke-Gh @('issue', 'comment', $issue.number, '--repo', $REPO, '--body', $msg)
        continue
    }

    $changed = Set-PublishedFlag -FilePath $filePath
    if (-not $changed) {
        Invoke-Gh @('issue', 'edit', $issue.number, '--repo', $REPO, '--add-label', 'published')
        continue
    }

    git config user.name  'github-actions[bot]'
    git config user.email 'github-actions[bot]@users.noreply.github.com'
    git add $filePath
    git commit -m "publish: $($issue.title)"
    git push

    $postUrl = Get-PostUrl -FilePath $filePath

    Invoke-Gh @('issue', 'edit', $issue.number, '--repo', $REPO, '--add-label', 'published')

    # Move project card to Published
    Set-ProjectItemPublished -IssueNumber $issue.number

    if ($postUrl) {
        # Update post-url in issue body metadata
        $newBody = $issue.body -replace '(?m)(post-url:)\s*$', "post-url: $postUrl"
        if ($newBody -ne $issue.body) {
            Invoke-Gh @('issue', 'edit', $issue.number, '--repo', $REPO, '--body', $newBody)
        }
    }

    $comment = @"
✅ **Published:** $postUrl

Push triggered ``deploy.yml``. LinkedIn Variant 1 will post today via ``linkedin-poster``.
"@
    Invoke-Gh @('issue', 'comment', $issue.number, '--repo', $REPO, '--body', $comment)
    Write-Host "  ✓ $postUrl"
}
