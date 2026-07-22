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
secrets:
  AZURE_IMAGE_GEN_KEY:
    value: ${{ secrets.AZURE_IMAGE_GEN_KEY }}
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

6.5. Generate the hero image by running the image generation script using
   the image prompt from step 6 and the post slug:
   ```
   pwsh scripts/generate-image.ps1 -Prompt "<image prompt>" -Slug "<slug>"
   ```
   The script reads `AZURE_IMAGE_GEN_KEY` from the environment (injected via
   repository secret). If the script fails, log the error in the PR description
   under `## ⚠️ Image Generation Error` but do NOT abort the pipeline — the
   PR should still be opened without the image.
   If the script succeeds, note the saved path in the PR description under
   `## 🖼️ Hero Image` and add the image to the post's front matter as
   `image: /<saved-path>`.

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

   c. **Create a main tracking issue** (this is the content calendar card):
      - Title: `[Content] <Post Title>`
      - Labels: `content`, `content-type:<type>`
      - Body (exact format — do NOT deviate):
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

   d. **Add main issue to the GitHub Project** #9 (owner: renevanosnabrugge,
      project: "Content Calendar · Culture Engineers") and set the
      status to "Draft Posts". Run the helper script:
      ```bash
      pwsh .github/scripts/add-to-project.ps1 <issue-url-1> <issue-url-2> ...
      ```
      Pass all the main issue URL as separate arguments.

   f. **Comment on the main tracking issue** with a checklist summary:
      ```
      **Next step:** Edit the post date in the issue in the project to set the schedule. Then add the item to the To be published column
      ```

Never push directly to `main`. Never call the LinkedIn API — posting to
LinkedIn is a manual step.