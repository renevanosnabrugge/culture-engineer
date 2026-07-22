# Culture Engineers

A static portfolio website for a software architect, speaker, and culture engineer. Built with [Jekyll](https://jekyllrb.com/) and deployed to GitHub Pages.

## Features

- Minimalist design — white, light gray, and blue accent colour
- Responsive layout using CSS Grid & Flexbox with subtle hover effects
- **About Me** — biography, expertise, conference experience
- **Presentations & Conferences** — talks grouped by year with slide/video links; upcoming events loaded from `_data/presentations.yml`
- **Publications** — articles, whitepapers with summaries and external links from `_data/publications.yml`
- **Inspiration** — books, blogs, and videos with short reviews from `_data/inspiration.yml`
- **Blog** — Markdown posts with tags, pagination, and recent posts automatically shown in the navigation dropdown

## Local Development

### 1. Install Ruby (Windows)

Download and run **RubyInstaller with DevKit** from <https://rubyinstaller.org/>  
(e.g. `Ruby+Devkit 3.2.x (x64)`). Accept the defaults and let it run `ridk install` at the end.

Verify the install:

```powershell
ruby -v    # e.g. ruby 3.2.x
gem -v
```

### 2. Install Bundler

```powershell
gem install bundler
```

### 3. Serve with live-reload (recommended)

```powershell
.\scripts\serve.ps1
```

The script installs gems automatically on first run, then starts Jekyll at  
**http://localhost:4000** with live-reload. The browser refreshes automatically when you save a file.

The serve script layers `_config.development.yml` on top of `_config.yml`, so `site.url` is set to `http://localhost:4000` locally while `_config.yml` keeps the production value `https://culture-engineers.nl`.

Custom port if 4000 is taken:

```powershell
.\scripts\serve.ps1 -Port 4001
```

### 4. Build only (no server)

```powershell
.\scripts\build.ps1              # development build
.\scripts\build.ps1 -Production  # production build (JEKYLL_ENV=production)
```

Output goes to `_site/` (gitignored).

> **Tip — allow scripts:** if PowerShell blocks the scripts, run once:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

---

## Deploy to GitHub Pages

### One-time setup (do this once per repo)

1. Go to **Settings → Pages** in your GitHub repository.
2. Under **Build and deployment**, set **Source** to **GitHub Actions**.
3. Save.

That's it. The workflow at [.github/workflows/deploy.yml](.github/workflows/deploy.yml) handles everything else.

### How it works

```
push to main
    └─> Actions: build job
            ├─ checkout code
            ├─ setup Ruby 3.2 + bundle install (cached)
            ├─ configure-pages  (auto-detects the correct baseurl)
            ├─ jekyll build --baseurl <base_path>
            └─> deploy job
                    └─ publish _site/ to Pages
```

Every push to `main` triggers a new deploy. You can also trigger manually from the **Actions** tab → **Deploy to GitHub Pages** → **Run workflow**.

### Custom domain

This repository is served at **https://culture-engineers.nl** via the `CNAME` file in the repository root. GitHub Pages reads the `CNAME` file from the deployed artifact and configures the custom domain automatically.

If you need to change the custom domain, update the `CNAME` file and the `url` field in `_config.yml`.

### Verify the deployment

After the workflow completes (≈ 1–2 min), your site is live at:

```
https://culture-engineers.nl
```

---

## Content Management

### Site data files

| Content type | File |
|---|---|
| Site metadata & author info | `_config.yml` |
| Presentations & conference talks | `_data/presentations.yml` |
| Publications | `_data/publications.yml` |
| Inspiration (books / blogs / videos) | `_data/inspiration.yml` |

### Content workflows

All content is driven by GitHub Issues + the **Content Calendar project (#9)**. The project is the single source of truth for planning. See **[CONTENT-CALENDAR.md](CONTENT-CALENDAR.md)** for the full reference.

---

#### Step 1 — Create a draft card

Every post needs a draft card in the project's **Draft Posts** column. Two ways to create one:

**A. Via script (existing or new content file):**
```powershell
# Creates a [Post] issue, adds it to the project in "Draft Posts", and sets the Post File field
pwsh .github/scripts/New-DraftCard.ps1 -FilePath "_posts/2026-07-20-my-post.md"

# Optionally set the publish date right away
pwsh .github/scripts/New-DraftCard.ps1 -FilePath "_posts/2026-07-20-my-post.md" -PublishDate "2026-07-28"
```

**B. Via agentic workflow:**
The write/schedule agents call `New-DraftCard.ps1` automatically after creating the post file.

> **Project setup (one-time):** Add a TEXT field named **`Post File`** in the project settings
> (Project → ⋯ → Settings → Fields → + Add field → Text). The script will warn but still work without it.

---

#### Step 2 — Set publish date + move to "To Be Published"

1. Open the draft card in the project, set the **Publish Date** field
2. Drag the card to the **To Be Published** column

Within ~1 hour (or immediately on `workflow_dispatch`), `project-transition.yml` will:
- Read the social pack file from `drafts/` (e.g. `2026-07-20-my-post-social.md`)
- Create **[Social 1]**, **[Social 2]**, **[Social 3]** sub-issues with variant text + dates
- Add all items to the project with their dates
- Add the `approve` label to activate automation

To trigger immediately or re-run for a specific issue:
```powershell
# Run locally
pwsh .github/scripts/New-SocialSubIssues.ps1 -IssueNumber 42

# Or trigger via GitHub Actions → Project Transition → Run workflow
```

---

#### Step 3 — Automated publishing (daily at 09:00 CEST)

| Workflow | What it does |
|---|---|
| `content-scheduler` | Sets `published: true` on the post file when `publish-date` = today; moves project card to **Published** |
| `linkedin-poster` | Posts the LinkedIn variant on its scheduled date (publish day, +7 days, +14 days) |

Remove the `approve` label from any sub-issue to pause it without affecting the others.

---

#### Labels at a glance

| Label | Purpose |
|---|---|
| `blogpost` | Triggers the full write + schedule agent pipeline |
| `schedule-content` | Triggers schedule-only pipeline (existing content) |
| `content-calendar` | Marks issues managed by the content automation |
| `approve` | Activates a sub-issue for automated publishing/posting |
| `published` | Added after a post goes live |

### Adding a presentation

Add an entry to `_data/presentations.yml`:

```yaml
- title: "Talk Title"
  event: "Conference Name"
  location: "City, Country"
  date: "2026-09-01"
  year: 2026
  upcoming: false          # true = shown in Upcoming section
  slides: "https://..."
  video: "https://..."
  description: "Optional description."
```

## Required Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Purpose |
|---|---|
| `GH_PROJECT_TOKEN` | PAT with `project` scope — for Projects v2 date/status updates |
| `LINKEDIN_ACCESS_TOKEN` | OAuth 2.0 token with `w_member_social` scope |
| `LINKEDIN_PERSON_URN` | Your LinkedIn URN: `urn:li:person:XXXXXXXXX` |
| `AZURE_IMAGE_GEN_KEY` | Azure AI Foundry key for hero image generation |

## License

MIT

