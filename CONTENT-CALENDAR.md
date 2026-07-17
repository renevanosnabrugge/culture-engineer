# Content Calendar — How It Works

This document describes the end-to-end content flow for culture-engineers.nl:
from a single GitHub issue to a published blog post, hero image, and three
LinkedIn variants posted over two weeks.

---

## Overview

```
You create a GitHub issue (label: blogpost)
        │
        ▼
[Agent] Writes post → reviews → generates image → writes social pack
        Creates [Content] issue + 4 sub-issues → adds to project "Draft Posts"
        Opens a Pull Request
        │
        ▼
You review and approve the PR
(published: false stays in front matter — post is not yet live)
        │
        ▼
You set the publish date in the [Content] issue body:
  <!-- publish-date: YYYY-MM-DD -->
Then add the label: scheduled
        │
        ▼
[Action] content-schedule-dates
  • Writes dates to all sub-issues
  • Adds "approve" label to all sub-issues
  • Moves all 5 cards to "To Be Published" in the project
        │
        ▼
On publish-date  → content-scheduler sets published: true, commits, deploys
On social dates  → linkedin-poster posts each LinkedIn variant
```

---

## Triggering the Agent

Create a GitHub issue with the label **`blogpost`**.

The issue body should contain the topic or a clear writing brief:

```
Write a post about why engineering culture is a board-level risk.
Angle: executives underestimate culture debt the same way they underestimate technical debt.
```

If the body is empty or vague, the agent will suggest topics and wait for your reply
before writing.

---

## What the Agent Creates

After writing the draft, the agent creates a structured set of GitHub issues:

### Main tracking issue — `[Content] <Title>`
Labels: `content`, `content-type:blog` (or `book` / `model`)

Body includes:
- Links to the trigger issue, the PR, and the draft file
- A `<!-- publish-date: YYYY-MM-DD -->` placeholder for you to fill in

### Sub-issues (all labeled `content-calendar`)
| # | Title | Content |
|---|-------|---------|
| 1 | `[Post] <Title>` | File path, PR link |
| 2 | `[Social 1] <Title>` | Contrarian hook variant |
| 3 | `[Social 2] <Title>` | Story format variant |
| 4 | `[Social 3] <Title>` | Question format variant |

All 5 issues are added to the **Content Calendar** project (#9) in the **Draft Posts** column.

---

## Scheduling a Post

1. Open the `[Content]` main issue
2. Edit the body — replace `<!-- publish-date: YYYY-MM-DD -->` with the real date:
   ```
   <!-- publish-date: 2026-08-11 -->
   ```
3. Add the label **`scheduled`**

This triggers the **content-schedule-dates** workflow which:
- Sets individual dates on all sub-issues:
  - `[Post]` and `[Social 1]` → publish-date
  - `[Social 2]` → publish-date + 7 days
  - `[Social 3]` → publish-date + 14 days
- Adds the `approve` label to all sub-issues (activates the automations)
- Moves all 5 project cards to **To Be Published**
- Comments on the main issue with a date summary

> To change dates: edit `<!-- publish-date: ... -->`, remove the `scheduled` label, then re-add it.

---

## Automated Publishing

### Content Scheduler (`content-scheduler.yml`)
Runs daily at 07:00 UTC. For each `[Post]` issue labeled `content-calendar + approve`:
- If `publish-date` matches today → sets `published: true` in the content file
- Commits and pushes → triggers `deploy.yml` → GitHub Pages rebuild
- Adds `published` label and comments with the live URL

### LinkedIn Poster (`linkedin-poster.yml`)
Runs daily at 07:00 UTC. For each `[Social N]` issue labeled `content-calendar + approve`:
- If `social-N-date` matches today → posts the variant text to LinkedIn
- Adds `social-N-posted` label and closes the sub-issue

---

## Manual Overrides

### Trigger publish now
```pwsh
gh workflow run content-scheduler.yml --repo renevanosnabrugge/culture-engineer
```

### Post a specific LinkedIn variant now
```pwsh
gh workflow run linkedin-poster.yml `
  --repo renevanosnabrugge/culture-engineer `
  --field issue_number=42 `
  --field variant=1
```

### Pause automation
Remove the `approve` label from any sub-issue to stop that specific action.
Re-add it to resume.

---

## Labels Reference

| Label | Applied to | Meaning |
|-------|-----------|---------|
| `blogpost` | Trigger issue | Starts the agent pipeline |
| `content` | Main tracking issue | Marks the content calendar card |
| `content-type:blog` / `book` / `model` | Main issue | Content type |
| `content-calendar` | All sub-issues | Picked up by scheduler + poster |
| `scheduled` | Main issue | Triggers date-setting workflow |
| `approve` | Sub-issues | Activates automation (set by date workflow) |
| `published` | `[Post]` sub-issue | Blog post is live |
| `social-N-posted` | `[Social N]` sub-issue | That variant has been posted |

---

## Project Board Columns

| Column | Issues land here when… |
|--------|----------------------|
| **Draft Posts** | Agent creates the issues |
| **To Be Published** | `scheduled` label triggers date workflow |
| **Published** | *(move manually after post goes live)* |

---

## Required Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Purpose |
|--------|---------|
| `GH_PROJECT_TOKEN` | PAT with `project` scope — for Projects v2 GraphQL (date-setting workflow) |
| `LINKEDIN_ACCESS_TOKEN` | OAuth 2.0 token with `w_member_social` scope |
| `LINKEDIN_PERSON_URN` | Your LinkedIn member URN: `urn:li:person:XXXXXXXXX` |
| `AZURE_IMAGE_GEN_KEY` | Azure AI Foundry key for hero image generation |

> **LinkedIn token expiry:** tokens expire after 60 days. Set a reminder to refresh before expiry.
> The poster workflow fails gracefully and comments on the issue if the token is stale.

---

## Issue Body Formats (reference)

### Main `[Content]` issue
```
## Content Tracking

| Field | Value |
|-------|-------|
| Trigger issue | #42 |
| Pull Request  | https://github.com/.../pull/43 |
| Draft file    | `_posts/2026-08-11-my-post.md` |
| Content type  | blog |

## Schedule

<!-- publish-date: 2026-08-11 -->

> Set the publish date above, then add the label `scheduled`.
```

### `[Post]` sub-issue (after scheduling)
```
<!-- CONTENT CALENDAR METADATA
file: _posts/2026-08-11-my-post.md
type: blog
publish-date: 2026-08-11
social-1-date: 2026-08-11
social-2-date: 2026-08-18
social-3-date: 2026-08-25
image: assets/images/my-post.png
post-url:
-->

| Pull Request | #43 |
| File | `_posts/2026-08-11-my-post.md` |
```

### `[Social N]` sub-issue (after scheduling)
```
<!-- CONTENT CALENDAR METADATA
social-1-date: 2026-08-11
image: assets/images/my-post.png
post-url:
-->

[LinkedIn variant text here — posted verbatim to LinkedIn]
```

