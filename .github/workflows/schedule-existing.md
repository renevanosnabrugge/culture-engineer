---
description: "Schedule an existing post/book/model for publishing — generates social pack, hero image, and content calendar issues without re-writing the content"
emoji: "📅"
on:
  issues:
    types: [labeled]
  reaction: "eyes"
  status-comment: true
if: github.event.label.name == 'schedule-content'
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
  GH_PROJECT_TOKEN:
    value: ${{ secrets.GH_PROJECT_TOKEN }}
network:
  allowed:
    - defaults
    - culture-engineer-ai.services.ai.azure.com
safe-outputs:
  create-pull-request:
    title-prefix: "[schedule] "
  add-comment:
    max: 1
  add-labels:
    allowed: ["schedule-content:error"]
timeout-minutes: 30
tracker-id: schedule-existing-content
---

# Schedule Existing Content — entry point

Triggered by an issue labeled `schedule-content`. The issue body must contain
a `file:` reference to an existing content file in the repo.

1. Read `.github/copilot-instructions.md` and
   `.github/instructions/blog-style.instructions.md` for context.

2. Follow all steps in `.github/skills/schedule-existing-content/SKILL.md`
   exactly.

   The skill will:
   - Resolve and validate the file path from the issue body
   - Generate a social pack for the existing content
   - Generate a hero image if not already present
   - Open a PR for the social pack file (and image front matter update if needed)
   - Create the full content calendar issue structure ([Content] + 4 sub-issues)
   - Add all 5 issues to GitHub Project #9 in "Draft Posts"
   - Comment on the trigger issue with a summary and next steps

3. If the `file:` line is missing or the file cannot be found, add the label
   `schedule-content:error` and comment on the issue explaining what is needed.

Never re-write or modify the post content itself. The post is final; this
workflow only handles scheduling, social pack, and project card creation.
