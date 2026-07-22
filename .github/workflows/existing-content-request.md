---
description: "Wire an existing post into the content calendar: write (or reuse) a social pack and open a PR"
emoji: "🗂️"
on:
  issues:
    types: [labeled]
  reaction: "eyes"
  status-comment: true
if: github.event.label.name == 'existingcontent'
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write
engine: copilot
tools:
  edit:
  bash: true
  github:
    toolsets: [default]
network:
  allowed:
    - defaults
safe-outputs:
  create-pull-request:
    title-prefix: "[existing] "
  add-comment:
    max: 1
  add-labels:
    allowed: ["existingcontent:in-progress"]
  jobs:
    create-calendar-card:
      description: "Create a content calendar tracking issue and add it to the GitHub Project in Draft Posts status"
      runs-on: ubuntu-latest
      permissions:
        contents: read
        issues: write
      inputs:
        title:
          description: "Issue title, e.g. [Content] My Post Title"
          required: true
          type: string
        body:
          description: "Issue body with content tracking table and schedule section"
          required: true
          type: string
        labels:
          description: "Comma-separated labels, e.g. content,content-type:blog"
          required: false
          type: string
      steps:
        - uses: actions/checkout@v4
        - name: Create issue and add to project
          shell: pwsh
          env:
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
            GH_PROJECT_TOKEN: ${{ secrets.GH_PROJECT_TOKEN }}
          run: |
            $data = Get-Content $env:GH_AW_AGENT_OUTPUT | ConvertFrom-Json
            $item = $data.items | Where-Object type -eq 'create_calendar_card' | Select-Object -First 1
            if (-not $item) { Write-Host "No create-calendar-card payload found."; exit 0 }

            $ghArgs = @('issue','create','--title',$item.title,'--body',$item.body)
            if ($item.labels) {
              $labelList = $item.labels -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
              foreach ($lbl in $labelList) {
                $exists = gh label list --json name | ConvertFrom-Json | Where-Object name -eq $lbl
                if (-not $exists) {
                  Write-Host "Creating missing label: $lbl"
                  gh label create $lbl --color '#0075ca' | Out-Null
                }
                $ghArgs += '--label'
                $ghArgs += $lbl
              }
            }

            $issueUrl = (gh @ghArgs 2>&1 | Select-String 'https://').ToString().Trim()
            if (-not $issueUrl) {
              Write-Host "::error::gh issue create returned no URL — aborting."
              exit 1
            }
            Write-Host "Issue created: $issueUrl"

            pwsh .github/scripts/add-to-project.ps1 $issueUrl
timeout-minutes: 20
tracker-id: existing-content-pipeline
---

# Existing Content Pipeline

Triggered by an issue labeled `existingcontent`. The issue body contains
the path to an **already published or committed** post file (e.g.
`_posts/2026-07-13-engineering-culture-board-level-risk.md`).

The goal is **not** to write a new post — the post already exists. The goal
is to produce a social pack and create the content calendar tracking
structure so the post can move through the same publishing workflow as new
posts.

1. Read `.github/copilot-instructions.md` and
   `.github/instructions/blog-style.instructions.md` for voice and context.

2. **Extract the post file path** from the issue body. Trim any whitespace
   or backtick fences. The path should start with `_posts/`, `_books/`, or
   `_models/`.

3. **Determine the post slug**: the filename without the date prefix and
   `.md` extension.
   Example: `_posts/2026-07-13-engineering-culture-board-level-risk.md`
   → slug = `engineering-culture-board-level-risk`

4. **Read the post file** to extract:
   - `title` from front matter
   - `categories` or tags to infer content type (blog / book / model)
   - Full post body for social pack generation

5. **Social pack**:

   a. Check whether `drafts/social-<slug>.md` already exists.

   b. **If it exists**: read its contents. Log a message: "Reusing existing
      social pack at drafts/social-<slug>.md". Skip writing.

   c. **If it does NOT exist**: run `.github/skills/social-pack/SKILL.md`
      against the post content, then save the result as
      `drafts/social-<slug>.md`.

6. **Open a pull request** (via safe-outputs) that contains:
   - The social pack file `drafts/social-<slug>.md` (whether new or
     unchanged — always include it in the diff so the PR is not empty)
   - PR description:
     - One-line summary at the top: "Social pack for: _<Post Title>_"
     - `## 📱 Social Pack` — all three LinkedIn variants (Contrarian hook /
       Story format / Question format), clearly labeled
     - `## 📄 Linked post` — the file path and a reminder that the post
       itself is NOT changed by this PR

7. **Comment on the original issue** linking to the PR.

8. **Create the content calendar tracking structure**:

   a. Determine content type:
      - `blog`  — file in `_posts/`
      - `book`  — file in `_books/`
      - `model` — file in `_models/`

   b. Ensure these labels exist (create if missing): `content`,
      `content-calendar`, `content-type:blog`, `content-type:book`,
      `content-type:model`, `scheduled`

   c. **Call the `create-calendar-card` safe-output job** with:
      - `title`: `[Content] <Post Title>`
      - `labels`: `content,content-type:<type>`
      - `body` (exact format — do NOT deviate):
        ```
        ## Content Tracking

        | Field | Value |
        |-------|-------|
        | Trigger issue | #<original issue number> |
        | Pull Request  | <PR URL> |
        | Draft file    | `<post file path>` |
        | Content type  | <blog \| book \| model> |

        ## Schedule

        <!-- publish-date: YYYY-MM-DD -->

        > Set the publish date above, then add the label `scheduled` to
        > trigger automatic date distribution to all sub-issues.
        ```

      The `create-calendar-card` job creates the issue AND adds it to
      GitHub Project #9 in "Draft Posts" status.
      Do NOT call `gh issue create` or `add-to-project.ps1` separately.

   d. **Comment on the tracking issue**:
      ```
      **Next step:** Set the publish date on the project card, then move
      it to "To be published" to automatically create the social sub-issues.
      ```

Never push directly to `main`. Never call the LinkedIn API.
