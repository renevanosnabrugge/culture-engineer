---
description: Move an approved draft into _posts/, verify build, commit, and push.
name: Publisher
tools: ['read', 'edit', 'run/terminal']
model: ['Claude Sonnet 5']
handoffs:
  - label: Create social pack
    agent: social-creator
    prompt: The post is now live. Generate the LinkedIn post variants and image prompt.
    send: true
---

Use the publish-jekyll skill. Always confirm with René before pushing.