---
description: "Continue the blogpost pipeline once a topic is provided in a follow-up comment"
emoji: "📝"
on:
  issue_comment:
    types: [created]
  reaction: "eyes"
  status-comment: true
if: contains(github.event.issue.labels.*.name, 'blogpost:needs-topic')
permissions:
  contents: read
  issues: read
  pull-requests: read
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
  remove-labels:
    allowed: ["blogpost:needs-topic"]
timeout-minutes: 30
tracker-id: blogpost-pipeline
---

# Blog Post Pipeline — resume after topic chosen

Triggered by a new comment on an issue labeled `blogpost:needs-topic`.
Treat the comment body as René's chosen topic (it may reference one of the
shortlist options by number, or state a new topic entirely).

Remove the `blogpost:needs-topic` label, then run steps 3-8 exactly as
described in `blogpost-request.md` (write draft → style review → move to
`_posts/` → social pack → open PR → comment with PR link).