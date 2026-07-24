#!/usr/bin/env pwsh
<#
.SYNOPSIS
Adds GitHub issue URLs to the Content Calendar project (#9) and sets their
status, publish date, and post file path via dynamic field lookup.

USAGE:
  pwsh .github/scripts/add-to-project.ps1 <issue-url> [<issue-url> ...]

  # Override default "To Be Published" status:
  pwsh .github/scripts/add-to-project.ps1 -Status "Draft Posts" <issue-url>

  # Set publish date and post file:
  pwsh .github/scripts/add-to-project.ps1 -PublishDate "2026-08-11" -PostFile "_posts/slug.md" <issue-url>

REQUIRES:
  GH_TOKEN (or GITHUB_TOKEN) -- with repo scope
  GH_PROJECT_TOKEN           -- PAT with 'project' scope (for Projects v2 GraphQL)
  gh CLI installed
#>

param(
    [string]$Status = 'To Be Published',
    [string]$PublishDate = '',
    [string]$PostFile = '',
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$IssueUrls
)
$ErrorActionPreference = 'Stop'

$PROJECT_NUMBER = 9
$OWNER          = 'renevanosnabrugge'
$REPO_NAME      = 'culture-engineer'

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    $token = $env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
        -Method POST `
        -Headers @{
            Authorization  = "******"
            'Content-Type' = 'application/json'
            'User-Agent'   = 'culture-engineer-bot'
        } `
        -Body $body
    if ($resp.errors) {
        Write-Warning "GraphQL errors: $($resp.errors | ConvertTo-Json -Compress)"
    }
    return $resp
}

# ── Fetch project metadata dynamically ────────────────────────────────────────

Write-Host "Fetching project #$PROJECT_NUMBER metadata..."
$projData = Invoke-GHGraphQL -Query @'
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

$proj      = $projData.data.user.projectV2
$projectId = $proj.id

$statusFieldId   = $null
$statusOptionId  = $null
$dateFieldId     = $null
$postFileFieldId = $null

foreach ($f in $proj.fields.nodes) {
    if (-not $f -or -not $f.name) { continue }
    $n = $f.name.ToLower()
    if ($n -eq 'status') {
        $statusFieldId = $f.id
        $opt = $f.options | Where-Object { $_.name -match $Status } | Select-Object -First 1
        if ($opt) { $statusOptionId = $opt.id }
    }
    if ($f.__typename -eq 'ProjectV2Field' -and $f.dataType -eq 'DATE' -and $n -like '*publish*') {
        $dateFieldId = $f.id
    }
    if ($f.__typename -eq 'ProjectV2Field' -and $f.dataType -eq 'TEXT' -and
        ($n -like '*post*file*' -or $n -like '*file*path*' -or $n -eq 'post file' -or $n -eq 'file')) {
        $postFileFieldId = $f.id
    }
}

Write-Host "Project ID   : $projectId"
Write-Host "Status field : $statusFieldId (option '$Status': $statusOptionId)"
Write-Host "Date field   : $dateFieldId"
Write-Host "PostFile     : $(if ($postFileFieldId) { $postFileFieldId } else { '(not found)' })"

if (-not $projectId)     { Write-Error "Project #$PROJECT_NUMBER not found." }
if (-not $statusFieldId) { Write-Error "No 'Status' field found in project." }
if (-not $statusOptionId){ Write-Warning "Status option '$Status' not found -- will skip status update." }

$setField = @'
  mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
    updateProjectV2ItemFieldValue(input: {
      projectId: $project itemId: $item fieldId: $field value: $value
    }) { projectV2Item { id } }
  }
'@

# ── Add each issue to the project and set fields ─────────────────────────────

foreach ($issueUrl in $IssueUrls) {
    Write-Host ""
    Write-Host "Adding: $issueUrl"

    $issueNumber = [int]($issueUrl -replace '.+/issues/(\d+)$', '$1')
    $nodeData = Invoke-GHGraphQL -Query @'
      query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
          issue(number: $number) { id }
        }
      }
'@ -Variables @{ owner = $OWNER; repo = $REPO_NAME; number = $issueNumber }
    $issueNodeId = $nodeData.data.repository.issue.id
    if (-not $issueNodeId) {
        Write-Warning "Could not resolve node ID for $issueUrl -- skipping"
        continue
    }
    Write-Host "  Issue node ID: $issueNodeId"

    $addResp = Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: { projectId: $project contentId: $contentId }) {
          item { id }
        }
      }
'@ -Variables @{ project = $projectId; contentId = $issueNodeId }
    $itemId = $addResp.data.addProjectV2ItemById.item.id
    if (-not $itemId) {
        Write-Warning "addProjectV2ItemById returned no item ID -- skipping field updates"
        continue
    }
    Write-Host "  Project item ID: $itemId"

    # Status
    if ($statusOptionId) {
        Invoke-GHGraphQL -Query $setField -Variables @{
            project = $projectId; item = $itemId
            field   = $statusFieldId
            value   = @{ singleSelectOptionId = $statusOptionId }
        } | Out-Null
        Write-Host "  Status -> $Status"
    }

    # Post File
    if ($postFileFieldId -and $PostFile) {
        Invoke-GHGraphQL -Query $setField -Variables @{
            project = $projectId; item = $itemId
            field   = $postFileFieldId
            value   = @{ text = $PostFile }
        } | Out-Null
        Write-Host "  Post File -> $PostFile"
    }

    # Publish Date
    if ($dateFieldId -and $PublishDate) {
        Invoke-GHGraphQL -Query $setField -Variables @{
            project = $projectId; item = $itemId
            field   = $dateFieldId
            value   = @{ date = $PublishDate }
        } | Out-Null
        Write-Host "  Publish Date -> $PublishDate"
    }
}

Write-Host ""
Write-Host "Done."
