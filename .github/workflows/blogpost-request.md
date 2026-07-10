---
description: "Turn an issue labeled 'blogpost' into a draft post, style review, and social pack via a pull request"
emoji: "📝"
on:
  issues:
    types: [labeled]
  reaction: "eyes"
  status-comment: true
if: github.event.label.name == 'blogpost'
permissions:
  contents: read
  issues: read
  pull-requests: read
  copilot-requests: write
engine: copilot
tools:
  edit:
  bash: ["git", "bundle exec jekyll build"]
  github:
    toolsets: [default]
network:
  allowed:
    - defaults
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

Triggered by an issue labeled `blogpost`. The issue body may or may not
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
   saving output as `drafts/<post-slug>-social.md`.

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

Never push directly to `main`. Never call any LinkedIn or image-generation
API — out of scope for this workflow.