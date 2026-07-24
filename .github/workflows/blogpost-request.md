---
description: "Turn an issue labeled 'blogpost' into a draft post, style review, and social pack via a pull request"
emoji: "📝"
on:
  issues:
    types: [labeled]
  reaction: "eyes"
  status-comment: true
if: github.event.label.name == 'blogpost' || github.event.label.name == 'book' || github.event.label.name == 'model'
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
      description: "Create a content calendar tracking issue with social variants in the body, add it to the GitHub Project in To Be Published status"
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
          description: "Issue body with metadata block, content tracking table, and LinkedIn variant sections"
          required: true
          type: string
        labels:
          description: "Comma-separated labels, e.g. content-calendar,content-type:blog,approve"
          required: false
          type: string
        post_file:
          description: "Path to the content file, e.g. _posts/2026-08-11-my-post.md"
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

            # Ensure all labels exist before creating the issue
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
              Write-Host "::error::gh issue create returned no URL -- aborting."
              exit 1
            }
            Write-Host "Issue created: $issueUrl"

            # Add to project in "To Be Published" status with optional file path
            $addArgs = @()
            if ($item.post_file) { $addArgs += '-PostFile'; $addArgs += $item.post_file }
            pwsh .github/scripts/add-to-project.ps1 @addArgs $issueUrl
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

3. **Determine content type and prepare the intro block.**

   Inspect the issue label and body:

   - If labeled `book`:
     - The issue body must name the book (title or slug). Read the matching
       file from `_books/` to get its title, author, and slug (the filename
       without `.md`).
     - Place the following block verbatim at the very top of the post body
       (after the front matter), formatted as a Markdown blockquote:

       > I have always liked reading, but I did not find the time for it. About 10 years ago, I started to listen to books in the car. I have a lot of travel time and listening to books just works for me. I tend to switch between (science-)fiction and non-fiction.
       >
       > When I encounter a problem or a new situation, read or hear something about a new model or framework, I'll find a book and "read" it. Over the years I gathered quite a long list of books that helped me a lot in my daily work. In one on one talks with people, in explaining situations to customers, dealing with problems or just let me grow as an individual. When I talk to people I often hear myself saying. I read a book, where... But no clue in which book this was. That's why I started this list of books. To have a library for myself, the lessons from each book as a quick summary, but also to be able to share it with others. I hope you enjoy it and find it useful. If you want to learn about more books, visit the [Books section](/inspiration/books/) of this site.

     - Somewhere in the post body (naturally, e.g. after the intro or at
       the first mention of the book title), add a link to the book detail
       page: `/inspiration/books/<slug>/`

   - If labeled `model`:
     - The issue body must name the model (title or slug). Read the matching
       file from `_models/` to get its title and slug (the filename without
       `.md`).
     - Place the following block verbatim at the very top of the post body
       (after the front matter), formatted as a Markdown blockquote:

       > Some colleagues tease me about it. "You probably have a model for that," they say and honestly, they are not wrong.
       >
       > Over the years I have developed what you might call a fondness for models and frameworks. Not because I think reality fits neatly into boxes, but because a good model gives me an umbrella. A place to start reasoning, a shared language to explain what I am seeing. Handlebars for situations that would otherwise feel slippery and hard to grip.
       >
       > And sometimes a model does something even more useful: it gives words to something I already sensed but could not articulate. That moment of recognition. That YES!, that is exactly what is happening here, is worth a lot when you are trying to get a team or a leadership table aligned.
       >
       > This is one of those models. I use it regularly, share it often, and it has served me well. I hope it does the same for you. If you want to learn about more models, visit the [Models section](/inspiration/models/) of this site.

     - Somewhere in the post body (naturally, e.g. after the intro or at
       the first mention of the model name), add a link to the model detail
       page: `/inspiration/models/<slug>/`

   - If labeled `blogpost` (no book or model): no intro block needed.

4. Write a full draft following `.github/agents/writer.agent.md`
   conventions. Save it to `drafts/`. The post should draw from the
   content in the matched `_books/` or `_models/` file (key lessons,
   excerpt, tags) when writing a book or model post.

5. Review the draft against `.github/skills/style-review/SKILL.md` and
   apply the suggested edits directly (René reviews the final diff in the
   PR, so don't pause for interactive confirmation here).

6. Move the finished post into `_posts/` with correct Jekyll front matter
   per `.github/skills/publish-jekyll/SKILL.md` — skip any git push step,
   the safe-outputs PR mechanism handles that.

7. Run `.github/skills/social-pack/SKILL.md` against the finished post,
   saving output as `drafts/social-<post-slug>.md`.

7.5. **Trigger hero image generation** by calling the `generate-hero-image` safe-output job with:
   - `prompt`: the `image_prompt` value from the post's front matter
   - `slug`: the post slug (filename without date prefix and `.md`)

   Also ensure the post front matter includes:
   ```yaml
   image: /assets/images/<slug>.png
   ```
   (The actual file is generated and committed to the PR branch by the safe-output job — you do not need to run a script yourself.)

8. Open a pull request (via safe-outputs) containing the new post file and
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

9. Comment on the original issue linking to the PR.

10. After the PR is created and commented on (step 9), create the content
   calendar tracking issue. Use the GitHub MCP tools (or bash `gh` CLI)
   to perform each of these actions:

   a. **Ensure labels exist** in the repo (create if missing):
      `content-calendar`, `content-type:blog`, `content-type:book`,
      `content-type:model`, `approve`

   b. **Determine content type** from the issue title / body:
      - `blog`  — regular blog post (default)
      - `book`  — book summary (file in `_books/`)
      - `model` — model page (file in `_models/`)

   c. **Read the social pack** from `drafts/social-<post-slug>.md` and
      extract the three LinkedIn variants. You will include them in the
      issue body.

   d. **Create the tracking issue and add it to the project** by calling
      the `create-calendar-card` safe-output job with these exact fields:
      - `title`: `[Content] <Post Title>`
      - `labels`: `content-calendar,content-type:<type>,approve`
      - `post_file`: the content file path (e.g. `_posts/2026-08-11-my-post.md`)
      - `body` (exact format — do NOT deviate):
        ```
        <!-- CONTENT CALENDAR METADATA
        file: <content file path>
        type: <blog | book | model>
        publish-date: YYYY-MM-DD
        image: <image path, e.g. assets/images/slug.png>
        post-url:
        -->

        ## Content Tracking

        | Field | Value |
        |-------|-------|
        | Trigger issue | #<original issue number> |
        | Pull Request  | <PR URL> |
        | Draft file    | `<file path>` |
        | Content type  | <blog | book | model> |

        > Set the **Publish Date** in the project board, then the content
        > scheduler and LinkedIn poster will handle the rest automatically.

        ## LinkedIn — Variant 1 (Contrarian hook)

        <variant 1 text from social pack>

        ---

        ## LinkedIn — Variant 2 (Story format)

        <variant 2 text from social pack>

        ---

        ## LinkedIn — Variant 3 (Question format)

        <variant 3 text from social pack>
        ```

      The `create-calendar-card` job will create the issue AND add it to
      the GitHub Project #9 in "To Be Published" status automatically.
      Do NOT call `gh issue create` or `add-to-project.ps1` separately.

   e. **Comment on the main tracking issue** with:
      ```
      **Next step:** Set the publish date in the project board. The content scheduler will publish on that date and LinkedIn variants will be posted automatically.
      ```

Never push directly to `main`. Never call the LinkedIn API — posting to
LinkedIn is handled automatically by the daily `linkedin-poster` workflow.