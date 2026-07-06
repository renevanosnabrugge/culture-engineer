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

| Content type | File |
|---|---|
| Site metadata & author info | `_config.yml` |
| Presentations & conference talks | `_data/presentations.yml` |
| Publications | `_data/publications.yml` |
| Inspiration (books / blogs / videos) | `_data/inspiration.yml` |
| Blog posts | `_posts/YYYY-MM-DD-title.md` |

### Adding a blog post

Create a file in `_posts/` following the naming convention `YYYY-MM-DD-post-title.md` with this front matter:

```yaml
---
layout: post
title: "Your Post Title"
subtitle: "Optional subtitle"
date: 2026-01-01 09:00:00 +0200
tags: [devops, culture]
excerpt: >
  A short description shown in post listings.
---

Your content here in Markdown.
```

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

## Deployment

The site is configured for GitHub Pages. Push to the `main` branch and enable GitHub Pages in repository settings (source: `/(root)` or `gh-pages` branch).

## License

MIT

