---
name: schedule-existing-content
description: >
  Schedule an already-written post, book, or model for publishing and
  LinkedIn distribution — without re-writing. Reads the file, generates
  a social pack and hero image, creates the full content calendar issue
  structure, and adds everything to the GitHub Project.
---

# Schedule Existing Content Skill

Use this skill when a content file already exists in `_posts/`, `_books/`,
or `_models/` with `published: false` in its front matter and you want to
schedule it for publishing without running the full writing pipeline.

---

## Input

The issue that triggered this skill must contain a line of the form:

```
file: _posts/2025-05-28-is-devops-dead-or-just-evolving.md
```

Acceptable formats for the file path:
- `_posts/YYYY-MM-DD-slug.md`
- `_books/slug.md`
- `_models/slug.md`

The path is relative to the repo root.

---

## Steps

### 1. Resolve the file

Extract the `file:` value from the issue body. Verify the file exists in
the repository by reading it via the GitHub API or bash. If it cannot be
found, comment on the issue with a clear error and stop.

Determine content type from path:
- `_posts/` → `blog`
- `_books/` → `book`
- `_models/` → `model`

Derive the slug from the filename (strip the `YYYY-MM-DD-` prefix and `.md`).

### 2. Generate social pack

Derive the canonical URL for the content from the file path:
- `_posts/YYYY-MM-DD-slug.md` → `https://culture-engineers.nl/blog/YYYY/MM/DD/slug/`
- `_books/slug.md` → `https://culture-engineers.nl/inspiration/books/slug/`
- `_models/slug.md` → `https://culture-engineers.nl/inspiration/models/slug/`

Run `.github/skills/social-pack/SKILL.md` against the file content,
passing the derived URL so each variant ends with the correct link.
Save the result to `drafts/social-<slug>.md` using the same format as
other social pack files.

### 3. Generate hero image (if not already present)

Check whether the front matter already has an `image:` field with a real
path (not empty). If the image is missing:

1. Use the `image_prompt` field from front matter if present; otherwise
   derive an image prompt from the post content using the social-pack output.
2. Run:
   ```
   pwsh scripts/generate-image.ps1 -Prompt "<image prompt>" -Slug "<slug>"
   ```
3. If the script succeeds, note the image path. If it fails, continue
   without an image — log the error in the main issue body.

### 4. Open a pull request

If the social pack file is new OR the front matter `image:` field needs
to be added, open a PR via `safe-outputs` containing:
- `drafts/social-<slug>.md` (the social pack)
- The updated content file with `image: /assets/images/<slug>.png` added
  to its front matter (only if image generation succeeded)

PR title: `[schedule] <post title>`

PR description must include:
- Link to the trigger issue
- All three LinkedIn variants inline under `## 📱 Social Pack`
- The image prompt under `## 🎨 Image Prompt`
- A note: "Post is already written — this PR only adds the social pack
  and image. Merge when ready."

If no files changed (image already existed, social pack already exists),
skip the PR and note that in the comment.

### 5. Create content calendar issue structure

Follow the same steps as in `.github/workflows/blogpost-request.md`
step 9 (a–f), using the data resolved above:

a. Ensure labels `content`, `content-calendar`, `content-type:<type>`,
   `scheduled` exist in the repo.

b. Create the main `[Content] <Post Title>` tracking issue:
   - Labels: `content`, `content-type:<type>`
   - Body with links to: trigger issue, PR (if opened), file path
   - `<!-- publish-date: YYYY-MM-DD -->` placeholder

c. Create 4 sub-issues:
   - `[Post] <Title>` — body: file path + PR link; label: `content-calendar`
   - `[Social 1] <Title>` — body: Contrarian hook variant; label: `content-calendar`
   - `[Social 2] <Title>` — body: Story format variant; label: `content-calendar`
   - `[Social 3] <Title>` — body: Question format variant; label: `content-calendar`

d. Add all 5 issues to the GitHub Project #9 in "Draft Posts":
   ```
   pwsh .github/scripts/add-to-project.ps1 <url1> <url2> <url3> <url4> <url5>
   ```

e. Comment on the main tracking issue with the sub-issue checklist and
   instructions for setting the publish date.

### 6. Comment on the trigger issue

Add a single comment with:
- Link to the main `[Content]` tracking issue
- Link to the PR (if created)
- Reminder: "Edit the publish date in the [Content] issue body, then add
  the `scheduled` label to set all dates automatically."

---

## Notes

- Never call the LinkedIn API directly.
- Never push directly to `main`.
- The `GH_PROJECT_TOKEN` secret must be set — it is injected via the
  workflow for the `add-to-project.ps1` call.
- If `published: true` is already set in the front matter, stop and
  comment: "This post is already published. Nothing to schedule."
