#!/usr/bin/env pwsh
<#
.SYNOPSIS
Adds GitHub issue URLs to the Content Calendar project (#9) and sets their
Status to "Draft Posts".

USAGE:
  pwsh .github/scripts/add-to-project.ps1 <issue-url> [<issue-url> ...]

  Example:
    pwsh .github/scripts/add-to-project.ps1 \
      https://github.com/renevanosnabrugge/culture-engineer/issues/42 \
      https://github.com/renevanosnabrugge/culture-engineer/issues/43

REQUIRES:
  GH_TOKEN (or GITHUB_TOKEN) — with repo scope
  GH_PROJECT_TOKEN           — PAT with 'project' scope (for Projects v2 GraphQL)
  gh CLI installed
#>

param(
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$IssueUrls
)
$ErrorActionPreference = 'Stop'

$PROJECT_NUMBER = 9
$OWNER          = 'renevanosnabrugge'

# Hardcoded constants — avoids a flaky runtime metadata lookup.
# Re-run `gh project field-list 9 --owner renevanosnabrugge --format json` to refresh.
$PROJECT_ID      = 'PVT_kwHOAFx9Ws4Bdpjc'
$STATUS_FIELD_ID = 'PVTSSF_lAHOAFx9Ws4BdpjczhYJnrk'
$DRAFT_OPTION_ID = 'f75ad846'   # "Draft Posts"

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
    # Always use the project-scoped token for GraphQL; fall back gracefully
    $token = $env:GH_PROJECT_TOKEN ?? $env:GH_TOKEN ?? $env:GITHUB_TOKEN
    $resp = Invoke-RestMethod -Uri 'https://api.github.com/graphql' `
        -Method POST `
        -Headers @{
            Authorization  = "Bearer $token"
            'Content-Type' = 'application/json'
            'User-Agent'   = 'culture-engineer-bot'
        } `
        -Body $body
    if ($resp.errors) {
        Write-Warning "GraphQL errors: $($resp.errors | ConvertTo-Json -Compress)"
    }
    return $resp
}

Write-Host "Project ID   : $PROJECT_ID"
Write-Host "Status field : $STATUS_FIELD_ID"
Write-Host "Draft option : $DRAFT_OPTION_ID"

# ── Add each issue to the project and set status ──────────────────────────────

foreach ($issueUrl in $IssueUrls) {
    Write-Host ""
    Write-Host "Adding: $issueUrl"

    # Resolve the issue's global node ID from its URL
    $issueNumber = [int]($issueUrl -replace '.+/issues/(\d+)$', '$1')
    $nodeData = Invoke-GHGraphQL -Query @'
      query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
          issue(number: $number) { id }
        }
      }
'@ -Variables @{ owner = $OWNER; repo = 'culture-engineer'; number = $issueNumber }
    $issueNodeId = $nodeData.data.repository.issue.id
    if (-not $issueNodeId) {
        Write-Warning "Could not resolve node ID for $issueUrl — skipping"
        continue
    }
    Write-Host "  Issue node ID: $issueNodeId"

    # Add the issue to the project
    $addResp = Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $contentId: ID!) {
        addProjectV2ItemById(input: { projectId: $project contentId: $contentId }) {
          item { id }
        }
      }
'@ -Variables @{ project = $PROJECT_ID; contentId = $issueNodeId }
    $itemId = $addResp.data.addProjectV2ItemById.item.id
    if (-not $itemId) {
        Write-Warning "addProjectV2ItemById returned no item ID — skipping status update"
        continue
    }
    Write-Host "  Project item ID: $itemId"

    # Set status to "Draft Posts"
    Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@ -Variables @{
        project = $PROJECT_ID
        item    = $itemId
        field   = $STATUS_FIELD_ID
        value   = @{ singleSelectOptionId = $DRAFT_OPTION_ID }
    } | Out-Null
    Write-Host "  Status set to 'Draft Posts'"
}

Write-Host ""
Write-Host "Done."
