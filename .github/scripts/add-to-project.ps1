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

function Invoke-GHGraphQL {
    param([string]$Query, [hashtable]$Variables = @{})
    $body = [System.Text.Encoding]::UTF8.GetBytes(
        (@{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 15)
    )
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

# ── 1. Get project ID and Status field metadata ───────────────────────────────

Write-Host "Fetching project #$PROJECT_NUMBER metadata..."
$projData = Invoke-GHGraphQL -Query @'
  query($owner: String!, $number: Int!) {
    user(login: $owner) {
      projectV2(number: $number) {
        id
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id name options { id name }
            }
          }
        }
      }
    }
  }
'@ -Variables @{ owner = $OWNER; number = $PROJECT_NUMBER }

$proj           = $projData.data.user.projectV2
$projectId      = $proj.id
$statusField    = $proj.fields.nodes | Where-Object { $_.name -and $_.name.ToLower() -eq 'status' } | Select-Object -First 1
$statusFieldId  = $statusField?.id
$draftOption    = $statusField?.options | Where-Object { $_.name -match 'draft' } | Select-Object -First 1
$draftOptionId  = $draftOption?.id

if (-not $projectId -or -not $statusFieldId -or -not $draftOptionId) {
    Write-Error "Could not resolve project, Status field, or 'Draft Posts' option.`nProject data: $($projData | ConvertTo-Json -Depth 5)"
}

Write-Host "Project ID   : $projectId"
Write-Host "Status field : $statusFieldId"
Write-Host "Draft option : $draftOptionId ($($draftOption.name))"

# ── 2. Add each issue to the project and set status ───────────────────────────

foreach ($issueUrl in $IssueUrls) {
    Write-Host ""
    Write-Host "Adding: $issueUrl"

    # gh project item-add returns JSON with the item id
    $addOutput = & gh project item-add $PROJECT_NUMBER `
        --owner $OWNER --url $issueUrl --format json 2>&1
    $itemId = $null

    try {
        $itemId = ($addOutput | ConvertFrom-Json).id
    } catch {
        # item-add succeeded but output not JSON — query for the item id
        Write-Host "  Resolving item id via GraphQL..."
        $issueNumber = [int]($issueUrl -replace '.+/issues/(\d+)', '$1')

        $itemsData = Invoke-GHGraphQL -Query @'
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

        $match  = $itemsData.data.user.projectV2.items.nodes |
                  Where-Object { $_.content.number -eq $issueNumber } |
                  Select-Object -First 1
        $itemId = $match?.id
    }

    if (-not $itemId) {
        Write-Warning "Could not get item ID for $issueUrl — skipping status update"
        continue
    }

    Write-Host "  Item ID: $itemId — setting status to 'Draft Posts'..."
    Invoke-GHGraphQL -Query @'
      mutation($project: ID!, $item: ID!, $field: ID!, $value: ProjectV2FieldValue!) {
        updateProjectV2ItemFieldValue(input: {
          projectId: $project itemId: $item fieldId: $field value: $value
        }) { projectV2Item { id } }
      }
'@ -Variables @{
        project = $projectId
        item    = $itemId
        field   = $statusFieldId
        value   = @{ singleSelectOptionId = $draftOptionId }
    } | Out-Null
    Write-Host "  Status set to 'Draft Posts'"
}

Write-Host ""
Write-Host "Done."
