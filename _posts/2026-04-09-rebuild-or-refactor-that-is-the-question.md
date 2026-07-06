---
layout: post
title: "Rebuild or Refactor? That is the question!"
date: 2026-04-09 09:00:00 +0200
tags: [architecture, software, strategy, legacy]
canonical_url: "https://roadtoalm.com/2026/04/09/rebuild-or-refactor-that-is-the-question/"
image_prompt: "Editorial illustration of two diverging paths in a futuristic city: one leads to a gleaming new glass skyscraper (rebuild), the other shows a classic building wrapped in renovation scaffolding (refactor), dark navy sky, orange neon accents, isometric perspective, no text, 16:9"
excerpt: >
  Sooner or later every team faces the same question: should we rebuild this software
  from scratch, or refactor our way out of the mess? The answer is rarely as simple as
  it looks.
---

Sooner or later, you will encounter the question: Rebuild or Refactor? Software that has been in use for several years will inevitably cause issues. Maybe the software is hard to maintain, or perhaps it is difficult to add new features, which slows down development. Your development teams might spend more time fixing issues than adding new features, making changes both hard and expensive. Developers may suggest starting over because the software is unmaintainable, while the business pushes back to maintain velocity.

Regardless of the reason, the question will arise: Should we rebuild the software? How long will it take? And how much will it cost?

These are important and seemingly straightforward questions, but the answers are not always simple or concrete. There is more to consider than just time and resources.

In this session — which I delivered at devCampNoord 2026 and Techorama Netherlands 2024 — we explore this question in more detail. We discuss some challenges and considerations involved in making the business decision to rebuild or refactor an application. Furthermore, we explore how to proceed once the decision has been made.

## The Business Tension

The moment a team suggests starting over, the conversation changes. Stakeholders hear "months of work with no new features." Developers hear "finally, a chance to do it right." Both perspectives are valid — and both are incomplete.

A rebuild is not a technical decision. It is a business decision with technical implications. Before you can answer "how long will it take," you need to answer harder questions:

- What is the cost of *not* rebuilding? How much does the current system slow you down each quarter?
- What knowledge lives only in the current code, and what happens when that code goes away?
- Can the organisation sustain two systems running in parallel during a transition?
- What does "done" look like, and how will you know when you get there?

## Why Refactoring is Not Always the Safe Option

Many teams choose refactoring because it feels less risky. You keep the system running, you improve it gradually, you avoid the "big bang" rewrite. That logic holds — until it doesn't.

Incremental refactoring only works when the codebase has enough structure to build on. If the architecture is fundamentally flawed, if the domain model is wrong, if the coupling between components makes every change a system-wide risk — then refactoring can become an endless treadmill. You make things better locally, but the system as a whole keeps deteriorating.

The strangler fig pattern can help here. Rather than replacing everything at once, you build new capability alongside the old system, gradually routing traffic away from legacy components. But even this requires discipline, investment, and organisational patience that many teams underestimate.

## When Rebuilding Makes Sense

Rebuilding makes sense when:

- The current technology stack is no longer supported or cannot hire for
- The domain model is so wrong that every new feature fights the existing design
- Security or compliance requirements cannot be met without fundamental changes
- The cost of change has reached a point where maintaining the system costs more than rebuilding it

The last point is the hardest to measure, but often the most important. When a team spends 70% of their sprint capacity on maintenance, bugs, and workarounds, and only 30% on new value — that is a signal worth taking seriously.

## The Decision Framework

Rather than treating this as a binary choice, I encourage teams to think along three axes:

1. **Technical health** — How broken is the code, really? A codebase with high test coverage and clear module boundaries is far more salvageable than one without.
2. **Business continuity** — How much disruption can the business absorb? A mission-critical system serving thousands of users every day needs a different transition strategy than an internal tool.
3. **Team capability** — Do you have the people, skills, and organisational support to see a rebuild through? Many rebuilds fail not because the idea was wrong, but because the team ran out of time, budget, or executive backing.

The answer to "rebuild or refactor" is almost never obvious from the outside. It requires an honest assessment of all three — and the courage to name what you actually find.

---

*This post is based on my conference session of the same name. The slides are available for download — see the [presentations page](/presentations/).*
