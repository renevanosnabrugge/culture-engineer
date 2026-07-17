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

All content (blog posts, book summaries, model pages) is driven by GitHub Issues and GitHub Actions. See **[CONTENT-CALENDAR.md](CONTENT-CALENDAR.md)** for the full reference.

#### Write a new post

1. Create a GitHub Issue — body contains the topic or writing brief
2. Add label **`blogpost`**
3. The agent writes the draft, reviews it, generates a hero image, creates a social pack, opens a PR, and creates the full content calendar issue structure automatically

#### Schedule an existing post

For content already written with `published: false`:

1. Create a GitHub Issue with this body:
   ```
   file: _posts/YYYY-MM-DD-slug.md
   ```
2. Add label **`schedule-content`**
3. The agent generates the social pack and hero image, then creates the content calendar issues without touching the post content

You can also trigger this from VS Code Copilot using the **`/schedule-existing`** prompt.

#### Set the publish date

Once the content calendar issues exist (either flow above):

1. Open the `[Content] <Title>` tracking issue
2. Edit the body — set `<!-- publish-date: YYYY-MM-DD -->`
3. Add label **`scheduled`**

The `content-schedule-dates` action distributes dates to all sub-issues, adds `approve`, and moves all cards to **To Be Published** in the project.

#### Automated publishing (daily at 09:00 CEST)

| Workflow | What it does |
|---|---|
| `content-scheduler` | Sets `published: true` on the content file when `publish-date` matches today |
| `linkedin-poster` | Posts the matching LinkedIn variant on each social date |

#### Labels at a glance

| Label | Purpose |
|---|---|
| `blogpost` | Triggers the full write + schedule pipeline |
| `schedule-content` | Triggers schedule-only pipeline (existing content) |
| `scheduled` | Triggers date distribution across sub-issues |
| `content` | Main tracking issue |
| `content-calendar` | Sub-issues picked up by the automation |
| `approve` | Activates automation for a sub-issue |

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

