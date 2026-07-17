---
description: Schedule an existing post, book, or model for publishing — generates social pack, hero image, and content calendar issues without re-writing the content.
mode: agent
tools: ['read', 'edit', 'bash', 'github']
---

Follow the skill at `.github/skills/schedule-existing-content/SKILL.md` exactly.

The file to schedule is:

```
${input:file:File path relative to repo root, e.g. _posts/2025-05-28-is-devops-dead-or-just-evolving.md}
```

Do not rewrite or edit the post content. Generate only the social pack, hero image (if missing), content calendar issues, and project cards.
