# Content Workflow Guide

A plain-English map of every pipeline, agent, and automation in this repo — so
you know what happens when, and how to drive it.

---

## The Big Picture

```
WRITE                  REVIEW & SCHEDULE             DISTRIBUTE
─────                  ──────────────────             ──────────
Create GitHub issue    PR lands in project: Draft    content-scheduler runs daily
   |                      |                           sets published: true → deploy
   ▼                      ▼                                |
Agent writes draft    Merge PR → verify               linkedin-poster runs daily
+ hero image          published: false               posts variant on social dates
+ social pack              |
   |                       ▼
Opens a PR +          Fill in variants, set dates
[Content] issue       move card to To Be Published
[Social N] cards           |  add 'approve' label
                           ▼
                      Scheduler picks it up
                      on publish-date
```

> **The `approve` label is the on/off switch for all automation.**  
> Moving a card to *To Be Published* on the board is visual only. To activate  
> the scheduler and LinkedIn poster you must also have the `approve` label on  
> the `[Content]` issue. Use a GitHub Projects automation (Settings → Workflows)  
> to add the label automatically when the card status changes.

---

## Path 1 — New Blog Post (from scratch)

### Step 1 — Create a GitHub issue

Go to **github.com → Issues → New issue**, or use the `gh` CLI:

```powershell
gh issue create --repo renevanosnabrugge/culture-engineer \
  --title "Post: Why engineering culture is a board-level risk" \
  --body "Angle: executives underestimate culture debt the same way they underestimate technical debt." \
  --label blogpost
```

**Labels that trigger the agent:**

| Label | What it writes |
|-------|----------------|
| `blogpost` | Blog post in `_posts/` |
| `book` | Book summary in `_books/` |
| `model` | Model page in `_models/` |

If the body is empty or vague, the agent suggests topics and waits for your reply.

### Step 2 — Agent runs automatically (GitHub Actions)

The `blogpost-request.lock.yml` workflow fires as soon as the label is applied.
It calls the **Writer** agent (Claude), which:

1. Reads your brief and existing posts to avoid repeats
2. Drafts the post following the voice rules in `.github/instructions/blog-style.instructions.md`
3. Hands off to the **Style Editor** agent for a style review
4. Generates a hero image via `scripts/generate-image.ps1` → `assets/images/<slug>.png`
5. Generates a social pack (3 LinkedIn variants + image prompt) written into the **trigger issue body** — not a separate file
6. Creates a **`[Content]` tracking issue** with placeholder variant sections (labels: `content-calendar`, `content-type:blog`, `approve`)
7. Creates **three `[Social N]` project cards** (one per LinkedIn variant) with default scheduled dates
8. Adds all cards to **GitHub Project #9** in **Draft** status
9. Opens a **Pull Request** (`[blogpost] <title>`) with the draft post

### Step 3 — You review the PR

- Read the draft and make any edits directly on the branch
- **Before merging: verify the front matter contains `published: false`** — the agent is instructed to set it, but double-check before you merge
- Approve and merge the PR

> The post is now on `main` but not live. The content scheduler sets `published: true` on the publish date.

### Step 4 — Fill in the tracking issue, set dates, activate automation

The `[Content]` tracking issue and three `[Social N]` cards were created with placeholder text. You fill them in and activate scheduling:

1. Open the **`[Content]` tracking issue**
2. Copy the three LinkedIn variants from the **trigger issue body** (where the agent wrote them)
3. Paste each variant under the matching `## LinkedIn — Variant N` section
4. Set the `publish-date` in the metadata block
5. Set the **Publish Date** on each `[Social N]` project card to the date you want that variant posted
6. If you changed a social date on the board, also update the matching `social-N-date` line in the metadata block — the LinkedIn poster reads from there
7. Move the `[Content]` card to **To Be Published** on the project board
8. Verify the `[Content]` issue has the **`approve`** label — this is what activates the daily scheduler. The agent adds it automatically; if missing, add it manually

> **Why two steps for activation?** The project board column is visual only. The `approve` label is the actual signal the scheduler reads. You can configure a GitHub Projects automation (Project Settings → Workflows → *Item status changed*) to add the `approve` label automatically when a card moves to *To Be Published*.

> **Image required:** every `[Content]` issue must have an `image:` value in the metadata block pointing to a PNG in `assets/images/`. The same image is used in the blog post and on LinkedIn. If the image is missing, the LinkedIn post will still go out but without the image, and a warning will be posted as a comment.

#### If social cards were NOT created automatically

Run this manually (from the repo root, with tokens set):

```powershell
# publish-date must already be set in the [Content] issue metadata block
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42
```

Or trigger it via GitHub Actions: **Actions → Create Social Cards → Run workflow**.

### Step 5 — Automation takes over

**Every day at 07:00 UTC (09:00 CEST):**

- `content-scheduler.yml` scans all issues labeled **`content-calendar + approve`**
  - If `publish-date` = today → sets `published: true`, commits, pushes → triggers deploy
  - Adds `published` label, comments with the live URL, moves card to *Published*
- `linkedin-poster.yml` scans the same issues
  - If a variant's scheduled date = today → first ensures the content file is `published: true` (commits if needed so the link resolves), then posts to LinkedIn
  - If the image in the metadata block is missing or broken, posts a warning comment and continues without the image
  - Adds `social-N-posted` label per posted variant
  - Closes the issue when all three variants are posted and the content is published

---

## Path 2 — Existing Content (already written)

Use this when a file already exists in `_posts/`, `_books/`, or `_models/`
with `published: false`, and you just want to schedule it without rewriting.

### Step 1 — Create a GitHub issue with label `existingcontent`

```powershell
gh issue create --repo renevanosnabrugge/culture-engineer \
  --title "Schedule: is-devops-dead-or-just-evolving" \
  --body "file: _posts/2025-05-28-is-devops-dead-or-just-evolving.md" \
  --label existingcontent
```

The `file:` line in the body is required.

### Step 2 — Agent runs (`existing-content-request.lock.yml`)

The agent:
1. Reads the existing file
2. Generates a social pack (3 LinkedIn variants)
3. Generates a hero image if the front matter has no `image:` field
4. Creates a `[Content]` tracking issue and adds it to the project
5. Opens a PR with the social pack file (no post rewrite)

### Steps 3–5 — Same as Path 1

Review the PR, set the Publish Date, automation handles the rest.

---

## Path 3 — Write in VS Code with Copilot Agents

You can drive everything locally without creating GitHub issues.

### Available agents (VS Code chat — type `@AgentName`)

| Agent | What it does |
|-------|-------------|
| **Writer** | Drafts a full post in `drafts/` from a topic brief |
| **Style Editor** | Reviews a draft against René's voice rules |
| **Image Generator** | Generates a hero image via Azure AI Foundry |
| **Social Creator** | Generates 3 LinkedIn variants + image prompt |
| **Publisher** | Verifies front matter, builds, shows diff, pushes after your confirmation |

### Typical local flow

```
@Writer "Write a post about X"
  → saves to drafts/YYYY-MM-DD-slug.md

@Style Editor  (review draft)
  → flags voice deviations

@Image Generator  (generate hero image)
  → saves to assets/images/<slug>.png

@Social Creator  (generate variants)
  → saves to drafts/social-<slug>.md

@Publisher  (publish)
  → moves to _posts/, asks for confirmation, pushes
```

After the Publisher pushes, `deploy.yml` runs on GitHub and the site rebuilds.
You still need to create the `[Content]` tracking issue manually (or run the
`existingcontent` GitHub issue path) to get LinkedIn scheduling.

---

## Path 4 — Manual Triggers

Trigger any step immediately from your terminal:

```powershell
# Publish all due content now (don't wait for 07:00)
gh workflow run content-scheduler.yml --repo renevanosnabrugge/culture-engineer

# Post a specific LinkedIn variant right now
gh workflow run linkedin-poster.yml `
  --repo renevanosnabrugge/culture-engineer `
  --field issue_number=42 `
  --field variant=1

# Trigger a full site deploy
gh workflow run deploy.yml --repo renevanosnabrugge/culture-engineer
```

---

## Pausing & Resuming Automation

- **Pause all automation for a post**: remove the `approve` label from its tracking issue
- **Resume**: re-add `approve`
- **Stop a LinkedIn variant**: remove `approve` before its scheduled date

---

## Labels Reference

| Label | Applied to | Meaning |
|-------|-----------|---------|
| `blogpost` | Trigger issue | Starts full write + schedule pipeline |
| `book` / `model` | Trigger issue | Starts pipeline for book/model content |
| `existingcontent` | Trigger issue | Schedule-only pipeline (no rewrite) |
| `content-calendar` | Tracking / Social issue | Managed by content automation |
| `content-type:blog` / `book` / `model` | Tracking issue | Content type |
| `social-post` | Social variant issue | Created by `New-SocialSubIssues.ps1` |
| `approve` | Tracking issue | Activates publishing + LinkedIn automation |
| `published` | Tracking issue | Blog post is live |
| `social-1-posted` / `social-2-posted` / `social-3-posted` | Tracking issue | LinkedIn variant posted |
| `done` | Tracking issue | All variants posted + content published |

---

## Files & Folders

| Path | Purpose |
|------|---------|
| `_posts/` | Live and staged posts (published: true/false) |
| `drafts/` | Work-in-progress posts and social packs |
| `assets/images/` | Hero images (PNG, 1024×1536) |
| `.github/skills/` | Copilot skill definitions (writer, publisher, etc.) |
| `.github/agents/` | VS Code agent definitions |
| `.github/workflows/blogpost-request.md` | Agent workflow definition for new posts |
| `.github/workflows/existing-content-request.md` | Agent workflow definition for existing content |
| `.github/workflows/content-scheduler.yml` | Daily publish automation |
| `.github/workflows/linkedin-poster.yml` | Daily LinkedIn automation |
| `.github/workflows/deploy.yml` | GitHub Pages build + deploy |
| `.github/scripts/publish-content.ps1` | Script run by content-scheduler |
| `.github/scripts/post-to-linkedin.ps1` | Script run by linkedin-poster |
| `.github/scripts/New-SocialSubIssues.ps1` | Creates 3 `[Social N]` project cards with dates |
| `.github/scripts/New-DraftCard.ps1` | Manually creates a `[Content]` tracking issue |
| `scripts/generate-image.ps1` | Local + CI image generation |
| `CONTENT-CALENDAR.md` | Additional details on the content calendar |

---

## Required Secrets (GitHub Actions)

| Secret | Used by |
|--------|---------|
| `AZURE_IMAGE_GEN_KEY` | Image generation via Azure AI Foundry |
| `LINKEDIN_ACCESS_TOKEN` | Posting to LinkedIn |
| `LINKEDIN_PERSON_URN` | LinkedIn person identifier |
| `GH_PROJECT_TOKEN` | Moving cards on the GitHub Project board |

---

## Checklist — New Post End-to-End

- [ ] Create GitHub issue with topic brief + label `blogpost`
- [ ] Wait for agent to open a PR and create the `[Content]` + `[Social N]` cards in **Draft** status (~5–10 min)
- [ ] If social cards are missing: **Actions → Create Social Cards** or run `New-SocialSubIssues.ps1 -IssueNumber <n>`
- [ ] **Verify `published: false` in the PR front matter before merging**
- [ ] Review and edit the draft in the PR, then merge
- [ ] Copy LinkedIn variants from the trigger issue body into the `[Content]` tracking issue
- [ ] Set `publish-date` in the tracking issue metadata block
- [ ] Set **Publish Date** on each `[Social N]` project card; update `social-N-date` in the metadata block to match
- [ ] Verify `image:` is set in the metadata block (same PNG as the blog post)
- [ ] Move `[Content]` card to **To Be Published** + confirm `approve` label is present
- [ ] On publish-date at 09:00 CEST: post goes live automatically
- [ ] Variant 1 posts to LinkedIn on the date you set (content is published first automatically)
- [ ] Variant 2 posts on the date you set
- [ ] Variant 3 posts on the date you set
- [ ] Issue closes automatically when all steps complete
