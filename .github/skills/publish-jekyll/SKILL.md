---
name: publish-jekyll
description: Finalize a post's front matter, commit, and push to GitHub Pages.
---

# Publish Skill

1. Verify front matter matches existing post conventions (title, date,
   categories, tags) — infer categories/tags from post content and existing
   taxonomy in `_posts/`.
2. Run any local Jekyll build check if available (`bundle exec jekyll build`)
   to catch errors before pushing.
3. Stage only the new/changed post file(s) — never git add -A blindly.
4. Show the diff and ask René to confirm before committing.
5. Commit message format: "Add post: <title>"
6. Push only after explicit confirmation.