---
description: "Turn an issue labeled 'blogpost' into a draft post, style review, and social pack via a pull request"
emoji: "📝"
on:
  issues:
    types: [labeled]
  reaction: "eyes"
  status-comment: true
if: contains(['blogpost', 'book', 'model'], github.event.label.name)
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
    - culture-engineer-ai.services.ai.azure.com
safe-outputs:
  create-pull-request:
    title-prefix: "[blogpost] "
  add-comment:
    max: 1
  add-labels:
    allowed: ["blogpost:needs-topic", "blogpost:in-progress"]
  jobs:
    generate-hero-image:
      description: "Generate a hero image and commit it to the PR branch. Call this after the PR is created."
      runs-on: ubuntu-latest
      needs: safe_outputs
      permissions:
        contents: write
        pull-requests: read
      inputs:
        prompt:
          description: "The image generation prompt (from image_prompt in the post front matter)"
          required: true
          type: string
        slug:
          description: "Post slug used as the image filename (without .png)"
          required: true
          type: string
      steps:
        - uses: actions/checkout@v4
          with:
            token: ${{ secrets.GITHUB_TOKEN }}
            fetch-depth: 0
        - name: Generate image and commit to PR branch
          shell: pwsh
          env:
            AZURE_IMAGE_GEN_KEY: ${{ secrets.AZURE_IMAGE_GEN_KEY }}
            GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: |
            $data = Get-Content $env:GH_AW_AGENT_OUTPUT | ConvertFrom-Json
            $item = $data.items | Where-Object type -eq 'generate_hero_image' | Select-Object -First 1
            if (-not $item) { Write-Host "No generate-hero-image request found."; exit 0 }
            $slug   = $item.slug
            $prompt = $item.prompt

            # Find the PR created by this workflow run
            $prs = gh pr list --state open --search '"gh-aw-tracker-id: blogpost-pipeline" in:body' `
              --json number,headRefName -L 3 | ConvertFrom-Json
            if (-not $prs) { Write-Host "No matching open PR found, skipping image generation."; exit 0 }
            $branch = $prs[0].headRefName

            # Checkout the PR branch
            git fetch origin $branch
            git checkout $branch

            # Generate image (AZURE_IMAGE_GEN_KEY is in env)
            pwsh scripts/generate-image.ps1 -Prompt $prompt -Slug $slug

            # Commit and push if the image was created
            $imagePath = "assets/images/${slug}.png"
            if (Test-Path $imagePath) {
              git config user.email "github-actions[bot]@users.noreply.github.com"
              git config user.name "github-actions[bot]"
              git add $imagePath
              git commit -m "chore: add hero image for ${slug} [skip ci]"
              git push origin $branch
              Write-Host "Hero image committed to branch $branch"
            } else {
              Write-Host "Image file not found at $imagePath after generation, skipping commit."
            }
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
            if ($item.labels) { $ghArgs += '--label'; $ghArgs += $item.labels }
            $issueUrl = gh @ghArgs
            Write-Host "Issue created: $issueUrl"

            pwsh .github/scripts/add-to-project.ps1 $issueUrl
timeout-minutes: 30
tracker-id: blogpost-pipeline
---

# Blog Post Pipeline — entry point

Triggered by an issue labeled `blogpost`, `book` or `model`. The issue body may or may not
already state a clear topic.

1. Read `.github/copilot-instructions.md` and
   `.github/instructions/blog-style.instructions.md` for voice and context.

2. **Check whether the issue body states a specific, usable topic.**
   - If NO clear topic is given (e.g. body just says "suggest topics" or
     is empty): run the logic in `.github/skills/topic-research/SKILL.md`,
     post the shortlist as a comment on the issue, add the label
     `blogpost:needs-topic`, and STOP. Do not write anything further.
   - If a clear topic IS given: add the label `blogpost:in-progress` and
     continue to step 3.

3. Write a full draft following `.github/agents/writer.agent.md`
   conventions. Save it to `drafts/`.

4. Review the draft against `.github/skills/style-review/SKILL.md` and
   apply the suggested edits directly (René reviews the final diff in the
   PR, so don't pause for interactive confirmation here).

5. Move the finished post into `_posts/` with correct Jekyll front matter
   per `.github/skills/publish-jekyll/SKILL.md` — skip any git push step,
   the safe-outputs PR mechanism handles that.

6. Run `.github/skills/social-pack/SKILL.md` against the finished post,
   saving output as `drafts/social-<post-slug>.md`.

6.5. **Trigger hero image generation** by calling the `generate-hero-image` safe-output job with:
   - `prompt`: the `image_prompt` value from the post's front matter
   - `slug`: the post slug (filename without date prefix and `.md`)

   Also ensure the post front matter includes:
   ```yaml
   image: /assets/images/<slug>.png
   ```
   (The actual file is generated and committed to the PR branch by the safe-output job — you do not need to run a script yourself.)

7. Open a pull request (via safe-outputs) containing the new post file and
   the social pack file. The PR **description must include the full
   content inline** — reviewers should be able to read everything without
   opening a single file:

   - The complete blog post text, rendered as Markdown, under a
     `## 📝 Post Preview` heading
   - All three LinkedIn variants under a `## 📱 Social Pack` heading, each
     clearly labeled (Contrarian hook / Story format / Question format)
   - The image prompt under a `## 🎨 Image Prompt` heading
   - A short note that image generation and LinkedIn publishing are manual
     next steps
   - A one-line summary of the topic and why it was chosen, at the top

   Keep the actual files in `drafts/`/`_posts/` as the source of truth —
   the PR body is a readable copy for review convenience, not a
   replacement for the diff.

8. Comment on the original issue linking to the PR.

9. After the PR is created and commented on (step 8), create the content
   calendar tracking structure. Use the GitHub MCP tools (or bash `gh` CLI)
   to perform each of these actions:

   a. **Ensure labels exist** in the repo (create if missing):
      `content`, `content-calendar`, `content-type:blog`, `content-type:book`,
      `content-type:model`, `scheduled`

   b. **Determine content type** from the issue title / body:
      - `blog`  — regular blog post (default)
      - `book`  — book summary (file in `_books/`)
      - `model` — model page (file in `_models/`)

   c. **Create a main tracking issue and add it to the project** by calling
      the `create-calendar-card` safe-output job with these exact fields:
      - `title`: `[Content] <Post Title>`
      - `labels`: `content,content-type:<type>` (e.g. `content,content-type:blog`)
      - `body` (exact format — do NOT deviate):
        ```
        ## Content Tracking

        | Field | Value |
        |-------|-------|
        | Trigger issue | #<original issue number> |
        | Pull Request  | <PR URL> |
        | Draft file    | `<file path>` |
        | Content type  | <blog \| book \| model> |

        ## Schedule

        <!-- publish-date: YYYY-MM-DD -->

        > Set the publish date above, then add the label `scheduled` to
        > trigger automatic date distribution to all sub-issues.
        ```

      The `create-calendar-card` job will create the issue AND add it to
      the GitHub Project #9 in "Draft Posts" status automatically.
      Do NOT call `gh issue create` or `add-to-project.ps1` separately.

   d. **Comment on the main tracking issue** with:
      ```
      **Next step:** Edit the post date in the issue in the project to set the schedule. Then add the item to the To be published column
      ```

Never push directly to `main`. Never call the LinkedIn API — posting to
LinkedIn is a manual step.