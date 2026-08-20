# Content Calendar -- How It Works

This document describes the end-to-end content flow for culture-engineers.nl:
from a single GitHub issue to a published blog post, hero image, and three
LinkedIn variants posted over two weeks.

---

## Overview

```
You create a GitHub issue (label: blogpost / book / model / existingcontent)
        |
        v
[Agent] Writes post -> reviews -> generates image -> writes social pack
        Creates [Content] issue with social variants in the body
        Adds to project "To Be Published"
        Opens a Pull Request
        |
        v
You review and approve the PR
(published: false stays in front matter -- post is not yet live)
        |
        v
You set the Publish Date in the project board
        |
        v
On publish-date  -> content-scheduler sets published: true, commits, deploys
On social dates  -> linkedin-poster posts each LinkedIn variant from the issue body
```

---

## Triggering the Agent

### New content
Create a GitHub issue with the label **`blogpost`**, **`book`**, or **`model`**.

The issue body should contain the topic or a clear writing brief:

```
Write a post about why engineering culture is a board-level risk.
Angle: executives underestimate culture debt the same way they underestimate technical debt.
```

If the body is empty or vague, the agent will suggest topics and wait for your reply.

### Existing content
Create an issue with the label **`existingcontent`** and include the file path
(e.g. `_posts/2026-07-13-my-post.md`). The agent generates a social pack
without rewriting the post.

---

## What the Agent Creates

### Pull Request
Contains the draft post (new content) or just the social pack file (existing content).

### Tracking issue -- `[Content] <Title>`
Labels: `content-calendar`, `content-type:blog` (or `book` / `model`), `approve`

The issue body contains everything in one place:
- A `<!-- CONTENT CALENDAR METADATA -->` block with file path, type, and dates
- A content tracking table (trigger issue, PR, file path)
- Three LinkedIn variant sections that you can edit directly

The issue is added to the **Content Calendar** project (#9) in the
**To Be Published** column.

---

## Setting the Publish Date

Set the **Publish Date** field on the project card. That's it.

Social dates are calculated automatically:
- **Variant 1** -> publish date (same day)
- **Variant 2** -> publish date + 7 days
- **Variant 3** -> publish date + 14 days

To override social dates, add explicit entries in the metadata block:
```
<!-- CONTENT CALENDAR METADATA
file: _posts/2026-08-11-my-post.md
type: blog
publish-date: 2026-08-11
social-1-date: 2026-08-11
social-2-date: 2026-08-20
social-3-date: 2026-08-29
image: assets/images/my-post.png
post-url:
-->
```

---

## Automated Publishing

### Content Scheduler (`content-scheduler.yml`)
Runs daily at 07:00 UTC. For each issue labeled `content-calendar + approve`:
- If `publish-date` matches today -> sets `published: true` in the content file
- Commits and pushes -> triggers `deploy.yml` -> GitHub Pages rebuild
- Adds `published` label and comments with the live URL
- Moves the project card to **Published**

### LinkedIn Poster (`linkedin-poster.yml`)
Runs daily at 07:00 UTC. For each issue labeled `content-calendar + approve`:
- Calculates social dates from `publish-date` (or reads explicit overrides)
- If a variant's date matches today -> posts the variant text to LinkedIn
- Adds `social-N-posted` label for each posted variant
- Closes the issue when all variants are posted and content is published

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
Remove the `approve` label from an issue to stop all automation for it.
Re-add it to resume.

---

## Labels Reference

| Label | Applied to | Meaning |
|-------|-----------|---------|
| `blogpost` | Trigger issue | Starts the full write + schedule agent pipeline |
| `book` / `model` | Trigger issue | Starts agent pipeline for book/model content |
| `existingcontent` | Trigger issue | Starts schedule-only pipeline (existing content) |
| `content-calendar` | Tracking issue | Marks issues managed by content automation |
| `content-type:blog` / `book` / `model` | Tracking issue | Content type |
| `approve` | Tracking issue | Activates automation (publishing + LinkedIn) |
| `published` | Tracking issue | Blog post is live |
| `social-N-posted` | Tracking issue | LinkedIn Variant N has been posted |
| `done` | Tracking issue | All variants posted + content published |

---

## Project Board Columns

| Column | Issues land here when... |
|--------|----------------------|
| **To Be Published** | Agent creates the tracking issue |
| **Published** | Content scheduler publishes the post |

---

## Required Secrets

Go to **Settings -> Secrets and variables -> Actions** and add:

| Secret | Purpose |
|--------|---------|
| `GH_PROJECT_TOKEN` | PAT with `project` scope -- for Projects v2 GraphQL |
| `LINKEDIN_ACCESS_TOKEN` | OAuth 2.0 token with `w_member_social` scope |
| `LINKEDIN_PERSON_URN` | Your LinkedIn member URN: `urn:li:person:XXXXXXXXX` |
| `AZURE_IMAGE_GEN_KEY` | Azure AI Foundry key for hero image generation |

> **LinkedIn token expiry:** tokens expire after 60 days. Set a reminder to refresh before expiry.
> The poster workflow fails gracefully and comments on the issue if the token is stale.

---

## Issue Body Format (reference)

### `[Content]` tracking issue
```
<!-- CONTENT CALENDAR METADATA
file: _posts/2026-08-11-my-post.md
type: blog
publish-date: 2026-08-11
image: assets/images/my-post.png
post-url:
-->

## Content Tracking

| Field | Value |
|-------|-------|
| Trigger issue | #42 |
| Pull Request  | https://github.com/.../pull/43 |
| Draft file    | `_posts/2026-08-11-my-post.md` |
| Content type  | blog |

> Set the **Publish Date** in the project board, then the content
> scheduler and LinkedIn poster will handle the rest automatically.

## LinkedIn -- Variant 1 (Contrarian hook)

[Variant text -- posted verbatim to LinkedIn on publish-date]

---

## LinkedIn -- Variant 2 (Story format)

[Variant text -- posted on publish-date + 7 days]

---

## LinkedIn -- Variant 3 (Question format)

[Variant text -- posted on publish-date + 14 days]
```
