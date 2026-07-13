---
name: generate-image
description: Generate a hero image via Azure AI Foundry and save it to assets/images/.
---

# Generate Image Skill

## Purpose

Call the Azure AI Foundry image-generation endpoint, download the result,
and write it as a PNG to `assets/images/<slug>.png`.

## Prerequisites

| Requirement | Detail |
|---|---|
| PowerShell (`pwsh`) | Available on all platforms and GitHub Actions runners |
| `AZURE_IMAGE_GEN_KEY` | Repository secret / local env var (never hardcode) |

## How to invoke

```powershell
.\scripts\generate-image.ps1 -Prompt "<prompt>" -Slug "<slug>"
```

| Argument | Example |
|---|---|
| `-Prompt` | The image prompt string from the social-pack skill |
| `-Slug` | The post slug, e.g. `engineering-culture-board-level-risk` |

## Image specification

| Parameter | Value |
|---|---|
| Endpoint | `https://culture-engineer-ai.services.ai.azure.com/openai/v1/images/generations` |
| Model | `gpt-image-1` |
| Size | `1024x1536` (portrait, optimised for LinkedIn) |
| Quality | `medium` |
| Output | `assets/images/<slug>.png` |

## Security notes

- `AZURE_IMAGE_GEN_KEY` must **never** appear in source code or logs.
- For local use: set it as a shell environment variable before running.
- For GitHub Actions: add it as a repository secret named `AZURE_IMAGE_GEN_KEY`
  and declare it in the workflow frontmatter under `secrets:`.
