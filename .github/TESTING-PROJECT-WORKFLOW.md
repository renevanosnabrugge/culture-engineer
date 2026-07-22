# Testing the Project-Driven Publishing Workflow

## Quick test (TL;DR)

```powershell
# 1 — Create draft card
pwsh .github/scripts/New-DraftCard.ps1 -FilePath '_posts/2025-05-28-is-devops-dead-or-just-evolving.md' -PublishDate '2026-08-04'
# → Note the issue number printed (e.g. #23)

# 2 — In GitHub: drag card to "To Be Published" (or skip — -Force bypasses the check)

# 3 — Create social sub-issues
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 23 -Force
# → Should print [Social 1/2/3] numbers and "Done. 3 social sub-issues created."

# 4 — Verify: open issue #23 — check metadata block, 'approve' label, 3 sub-issues
gh browse --repo renevanosnabrugge/culture-engineer
```

---

## Full guide

## Prerequisites

### 1 — PowerShell 7+

```powershell
pwsh --version   # should be 7.x
```

Download from <https://github.com/PowerShell/PowerShell/releases> if needed.

### 2 — GitHub CLI (`gh`)

```powershell
gh --version     # should be 2.x
```

Install via `winget install GitHub.cli` or <https://cli.github.com/>.

Authenticate:

```powershell
gh auth login    # choose GitHub.com → HTTPS → browser
gh auth status   # verify: logged in to github.com
```

### 3 — Two tokens

You need **two different tokens** because project mutations require a PAT with `project` scope, which `GITHUB_TOKEN` (from Actions) does not have.

| Env var | Token type | Required scopes |
|---|---|---|
| `GH_TOKEN` | PAT (classic) or `gh` session | `repo` |
| `GH_PROJECT_TOKEN` | PAT (classic) | `project`, `repo` |

Create the PAT at <https://github.com/settings/tokens> → **Generate new token (classic)** → check `repo` + `project`.

Set them in your shell for this session:

```powershell
$env:GH_TOKEN           = 'ghp_...'   # or skip — gh CLI uses its own auth
$env:GH_PROJECT_TOKEN   = 'ghp_...'   # REQUIRED for project field updates
$env:GITHUB_REPOSITORY  = 'renevanosnabrugge/culture-engineer'
```

> **Tip:** Add these to your PowerShell profile (`$PROFILE`) or a local `.env.ps1` file (gitignored) so you don't have to re-set them each session.

### 4 — Work from the repository root

All script paths are relative to the repo root.

```powershell
cd C:\Users\rvano\Source\Repos\GitHub\culture-engineer
```

---

## One-time project setup: "Post File" field

The scripts store the file path in a custom project field for visibility in the board view.

1. Open the **Content Calendar** project: <https://github.com/users/renevanosnabrugge/projects/9>
2. Click **⋯ (Menu)** → **Settings**
3. Under **Fields**, click **+ Add field**
4. Choose **Text**, name it exactly **`Post File`**, save

The scripts work without this field (path falls back to the issue body) but the board column will be empty.

---

## Script 1: `New-DraftCard.ps1`

**What it does:** Creates a `[Post] Title` issue for an existing file and adds it to the project in **Draft Posts**, with the file path set in the "Post File" field.

### Step 1 — Choose a test file

Use an existing post that is not yet in the project:

```powershell
# List posts
Get-ChildItem _posts/ | Select-Object Name
```

Pick one, e.g. `_posts/2025-05-28-is-devops-dead-or-just-evolving.md`.

### Step 2 — Dry-run: inspect what the script will do

Read the file to confirm the title will be extracted correctly:

```powershell
Select-String -Path '_posts/2025-05-28-is-devops-dead-or-just-evolving.md' -Pattern '^title:'
```

Expected output:
```
title: Is DevOps Dead, or Just Evolving?
```

### Step 3 — Run the script

```powershell
pwsh .github/scripts/New-DraftCard.ps1 `
  -FilePath '_posts/2025-05-28-is-devops-dead-or-just-evolving.md'
```

Expected output (abbreviated):
```
Title : Is DevOps Dead, or Just Evolving?
File  : _posts/2025-05-28-is-devops-dead-or-just-evolving.md
Creating GitHub issue...
Issue #XX created: https://github.com/renevanosnabrugge/culture-engineer/issues/XX
Fetching project #9 metadata...
Project    : PVT_xxxx
Status fld : PVTSSF_xxxx  (Draft option: xxxxxxxx)
Date field : PVTF_xxxx
PostFile   : PVTF_xxxx           ← only if "Post File" field exists
Adding issue to project...
Item ID: PVTI_xxxx
Status → Draft Posts
Post File → _posts/2025-05-28-is-devops-dead-or-just-evolving.md
Done. Draft card created: https://github.com/renevanosnabrugge/culture-engineer/issues/XX
```

### Step 4 — Verify in GitHub

1. Open the project board and confirm the card appears in **Draft Posts**
2. Open the issue — confirm the body has the `<!-- POST-FILE: ... -->` comment and the link
3. If the "Post File" field was set up: confirm the field value shows the file path on the card

### Step 5 — Test with a publish date

```powershell
pwsh .github/scripts/New-DraftCard.ps1 `
  -FilePath '_posts/2025-05-28-is-devops-dead-or-just-evolving.md' `
  -PublishDate '2026-08-04'
```

Expected additional line: `Publish Date → 2026-08-04`

> **Cleanup:** If you want to delete the test issue: `gh issue close XX --repo renevanosnabrugge/culture-engineer`

---

## Script 2: `New-SocialSubIssues.ps1`

**What it does:** For a `[Post]` issue in **To Be Published**, creates `[Social 1/2/3]` sub-issues with the variant text from the social pack file, sets publish dates, and moves everything in the project.

### Step 1 — Set up a test scenario

You need an issue that:
- Was created by `New-DraftCard.ps1` (or has `<!-- POST-FILE: path -->` in its body)
- Has a **Publish Date** set in the project field (or `<!-- publish-date: YYYY-MM-DD -->` in the body)

**Option A — Use the issue from Script 1 above:**
Set a publish date on it if you haven't already:

```powershell
# Open the project board and set the Publish Date field on the card
# OR use the script with -PublishDate when creating it
```

**Option B — Manually add the date to the issue body for testing:**

```powershell
$issueNum = 42   # replace with your test issue number
$body = gh issue view $issueNum --repo renevanosnabrugge/culture-engineer --json body --jq .body
# Then edit the issue in the browser and add: <!-- publish-date: 2026-08-04 -->
```

### Step 2 — Confirm a social pack file exists

The script looks for a social pack file matching the post's slug:

```powershell
# For _posts/2025-05-28-is-devops-dead-or-just-evolving.md the slug is:
# is-devops-dead-or-just-evolving
# Script checks (in order):
#   drafts/2025-05-28-is-devops-dead-or-just-evolving-social.md
#   drafts/social-is-devops-dead-or-just-evolving.md
#   drafts/is-devops-dead-or-just-evolving-social.md

Get-ChildItem drafts/ | Where-Object { $_.Name -like '*devops*' }
```

If no social file exists, sub-issues are created with `[Add LinkedIn Variant N text here]` placeholders — which is fine for testing.

### Step 3 — Run in scan mode (no issue number)

This mode scans all **To Be Published** items in the project:

```powershell
pwsh .github/scripts/New-SocialSubIssues.ps1
```

Expected output:
```
New-SocialSubIssues.ps1 — 2026-07-20 10:30
Project #9 : PVT_xxxx
...
Mode: scanning project for 'To Be Published' items without social sub-issues...
Found 1 post item(s) in 'To Be Published'.

── Processing issue #42 ──────────────────────────────────────────
  File         : _posts/2025-05-28-is-devops-dead-or-just-evolving.md
  Publish date : 2026-08-04
  Social pack  : (no file found — using placeholders)
  Creating [Social 1] (2026-08-04)...
    Issue #43: https://github.com/.../issues/43
  Creating [Social 2] (2026-08-11)...
    Issue #44: https://github.com/.../issues/44
  Creating [Social 3] (2026-08-18)...
    Issue #45: https://github.com/.../issues/45
  Main issue body updated with metadata block.
  Added 'approve' label to main issue.
  Done. 3 social sub-issues created.

Scan complete.
```

### Step 4 — Run for a specific issue number

```powershell
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42
```

The script skips if sub-issues already exist (idempotent).

### Step 5 — Re-run with `-Force` (bypass status check)

Useful if the card is still in **Draft Posts** but you want to test the sub-issue creation:

```powershell
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42 -Force
```

### Step 6 — Verify in GitHub

1. Open issue #42 — confirm the metadata block was added to the body and `approve` label is present
2. Check **sub-issues** on the issue page — should show [Social 1], [Social 2], [Social 3]
3. On the project board — all four cards should appear in **To Be Published** with their dates set

---

## Script 3: `publish-content.ps1`

**What it does:** Publishes posts where `publish-date = today` by setting `published: true` in the file, committing, pushing, and moving the project card to **Published**.

> **Warning:** This script commits and pushes to `main`. Use a test branch or set `publish-date` to a future date to prevent accidental publishing during a test.

### Safe test approach

Set `publish-date` to **today's date** only on a post that already has `published: true` (it will be skipped with "Already published:true"). Or temporarily fake today's date:

```powershell
# Preview what would run today without actually publishing
# The script uses (Get-Date).ToString('yyyy-MM-dd') — you can't override it without editing,
# so the safest test is to use a future date and confirm the issue is found but skipped.
```

### Step 1 — Check what the script sees

Ensure at least one issue exists with `content-calendar + approve` labels, a `publish-date` in its metadata, and a valid file path:

```powershell
gh issue list --repo renevanosnabrugge/culture-engineer `
  --label content-calendar --label approve `
  --state open --json number,title,labels `
  --limit 10
```

### Step 2 — Run the script

```powershell
$env:GITHUB_REPOSITORY = 'renevanosnabrugge/culture-engineer'
$env:GH_TOKEN          = 'ghp_...'
$env:GH_PROJECT_TOKEN  = 'ghp_...'

pwsh .github/scripts/publish-content.ps1
```

Expected output if no items are due today:
```
Content Scheduler — 2026-07-20
Found 3 approved calendar issue(s)
  #42: missing metadata — skipping      ← if metadata not yet set
  #43: publish-date 2026-08-04 ≠ today — skipping
...
```

---

## Full end-to-end flow test

This runs through the complete lifecycle from file → card → social posts.

```powershell
# 0. Set env vars
$env:GITHUB_REPOSITORY = 'renevanosnabrugge/culture-engineer'
$env:GH_PROJECT_TOKEN  = 'ghp_...'

# 1. Create draft card for a post
pwsh .github/scripts/New-DraftCard.ps1 `
  -FilePath '_posts/2025-05-28-is-devops-dead-or-just-evolving.md' `
  -PublishDate '2026-08-04'

# Note the issue number printed — e.g. #42

# 2. In the GitHub project UI: drag card to "To Be Published"
#    (or use workflow_dispatch on project-transition.yml)

# 3. Run sub-issue creation (simulates the hourly schedule job)
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42 -Force

# 4. Verify on GitHub:
#    - Issue #42 has 3 sub-issues
#    - All 4 project cards are in "To Be Published" with dates set
#    - Issue #42 body has the CONTENT CALENDAR METADATA block
#    - Issue #42 has the 'approve' label

# 5. (Optional) Trigger publish manually — only do this with a file already published: true
pwsh .github/scripts/publish-content.ps1
```

---

## Triggering the workflow manually (without waiting for the schedule)

Once the scripts work locally, you can also trigger the GitHub Actions workflow directly:

```powershell
# Scan all "To Be Published" items
gh workflow run project-transition.yml --repo renevanosnabrugge/culture-engineer

# Process a specific issue
gh workflow run project-transition.yml `
  --repo renevanosnabrugge/culture-engineer `
  -f issue_number=42

# Force-run (skip status check)
gh workflow run project-transition.yml `
  --repo renevanosnabrugge/culture-engineer `
  -f issue_number=42 `
  -f force=true

# Check the run logs
gh run list --repo renevanosnabrugge/culture-engineer --workflow project-transition.yml --limit 5
gh run view --repo renevanosnabrugge/culture-engineer   # pick the latest run ID
```

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Project #9 not found` | `GH_PROJECT_TOKEN` missing or wrong scope | Create PAT with `project` + `repo` scope |
| `No 'Draft Posts' option found` | Status option name mismatch | Open project → field options and check exact name |
| `No file path found` | Issue has neither POST-FILE comment nor Post File field value | Edit issue body or set the field in the project |
| `No publish date found` | Publish Date not set in project or issue body | Set the Publish Date field on the project card |
| Social sub-issues created with placeholder text | No social pack file found in `drafts/` | Generate a social pack first, or edit the sub-issues manually |
| Script creates duplicate sub-issues | Ran without existing sub-issues being linked as sub-issues | The script checks `subIssues` via GraphQL; if the link wasn't created, delete the duplicates and re-run |
| `addSubIssue mutation error` | GitHub sub-issues API not available on this plan | Check GitHub plan — sub-issues require GitHub Issues (not classic issues) |
