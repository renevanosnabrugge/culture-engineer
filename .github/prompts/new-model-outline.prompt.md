---
mode: agent
tools: ['read', 'edit', 'create']
---

You are helping René van Osnabrugge add a new model page to culture-engineers.nl. The site is a Jekyll static site. Model files live in `_models/` and use `layout: model`.

## Step 1 — Gather information

Ask René the following questions. Do NOT generate the file until all answers are provided.

1. **Model name** — Full title of the model or framework.
2. **Origin** — Who created it? (person and/or organisation, e.g. "Jeff Hiatt / Prosci" or "Google DORA team").
3. **Tags** — 2–4 tags from this list: `change`, `adoption`, `transformation`, `devops`, `measurement`, `performance`, `teams`, `culture`, `trust`, `operations`, `flow`, `systems-thinking`, `leadership`. Suggest the most relevant ones and ask René to confirm.
4. **Excerpt** — One crisp sentence: what the model does or diagnoses. This appears as the subtitle on the page.
5. **Learn more URL** — A canonical external URL (official site, original paper, or publisher page).
6. **Stages or elements** — The key components, stages, or dimensions with a one-line description of each.
7. **How René uses it** — How does he apply this model in transformation work? What does it diagnose or unlock?
8. **Common mistakes** — What do practitioners (or leaders) typically get wrong about this model?

---

## Step 2 — Create the model file

Once René has answered all questions:

1. Derive a filename slug: lowercase, hyphens only, no special characters.
   Example: "Cynefin Framework" → `cynefin-framework.md`

2. Read one existing model file (e.g. `_models/adkar.md`) to confirm the formatting conventions.

3. Create `_models/<slug>.md` using this template, filled with René's answers:

```markdown
---
layout: model
title: "<Model Name>"
origin: "<Creator / Organisation>"
tags: [tag1, tag2, tag3]
excerpt: "<One-sentence description.>"
learn_more: "<URL>"
published: false
---

<Opening paragraph — what the model is, where it comes from, and why it matters. 3–5 sentences. Plain language, no consultant jargon.>

## The <stages/elements/dimensions/keys>

| <Stage/Element> | <What it means or asks> |
|---|---|
| **<Name>** | <One-line description> |
| **<Name>** | <One-line description> |

## How I use it

<How René applies this model in practice. What it diagnoses, what it unlocks. 2–4 sentences grounded in his transformation work.>

## Common mistakes

<Two or three named mistakes practitioners make with this model. Use bold headers for each mistake followed by a short explanation.>
```

4. After creating the file, report the path and a one-line summary of what was created.

---

## Voice constraints

- Plain words, real sentences. No buzzwords or framework-sales language.
- Write to executives, not developers: frame every element in terms of what it diagnoses, what risk it reveals, or what it enables.
- Follow the patterns in `_models/adkar.md` and `_models/dora-metrics.md` as style references.
