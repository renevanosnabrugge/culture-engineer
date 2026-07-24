---
mode: ask
---

You are helping René van Osnabrugge — Consulting Director at Xebia, Technology & Transformation Executive — outline an original book on engineering culture for executive readers (CIO, CDO, Chief of Transformation, public sector and healthcare leaders).

## Context: René's operational model library

René has built, applied, and annotated five operational frameworks in practice. Unlike the books in his library (which are conceptual and narrative), these models are diagnostic tools he actually uses with clients. The new book must show executives how these models interconnect — and why no single model is sufficient on its own.

---

### ADKAR (Prosci / Jeff Hiatt)
A sequential individual-change model: **Awareness → Desire → Knowledge → Ability → Reinforcement**
- Change fails at the human layer, not the process layer
- Most initiatives stall at Desire — people understand what is changing but never genuinely committed to it
- Reinforcement is almost always skipped: teams declare success at go-live and wonder why people revert
- ADKAR is diagnostic: when a transformation stalls, identify *which* element is the constraint
- Complements: Bridges' Transition Model, Kotter's 8 Steps, Five Dysfunctions (when resistance traces to team dynamics)

### DORA Metrics (Google/DORA Research)
Four measures of software delivery performance: **Deployment Frequency, Lead Time for Changes, Change Failure Rate, Mean Time to Restore**
- Backed by six years of research across thousands of organisations
- High performers achieve high throughput *and* high stability simultaneously — these are not a trade-off
- Low performers treat them as a trade-off, which is itself a cultural symptom
- Translates engineering culture into board-level language: delivery predictability + operational risk
- Correlation between DORA performance and employee satisfaction, lower burnout, commercial outcomes

### The Five Dysfunctions (Lencioni)
A diagnostic pyramid: **Trust → Conflict → Commitment → Accountability → Results**
- The board always sees the top (missed results); the root cause is at the base (absence of trust)
- Sequential: you cannot fix accountability without addressing commitment; cannot fix commitment without honest conflict; cannot have productive conflict without trust
- Common failure: leaders try to fix accountability while the trust problem is still live
- Boards see the outputs; the dynamics producing them have been building for years at the base
- Complement: Brené Brown's work on vulnerability is the repair manual; Lencioni describes the dysfunction

### Theory of Constraints (Eliyahu Goldratt)
Five focusing steps: **Identify → Exploit → Subordinate → Elevate → Repeat**
- Every system has exactly one constraint; improving anything else does not increase output
- Most dangerous failure mode: optimising individual stages without understanding the system constraint
- In software: the constraint is often not where leaders think (approvals, security reviews, a single overloaded person)
- Local optimisation is not neutral — it creates waste and obscures the real problem
- The Phoenix Project applies this directly to IT; Brent is the constraint

### The Three Ways (Gene Kim et al.)
Three DevOps principles: **Flow → Feedback → Continual Learning**
- First Way (Flow): optimise the system, not the stage; throughput is determined by the constraint
- Second Way (Feedback): cost of a defect increases exponentially the later it is found
- Third Way (Continual Learning): organisations that improve fastest are those that learn fastest — and learning requires psychological safety
- The Third Way makes the explicit link: you cannot sustain Continuous Delivery without a culture that treats failure as information
- Bridges technical practice and organisational culture into a single framework

---

## The synthesis problem

None of these models alone is sufficient:
- DORA tells you *what* to measure but not *why* the organisation cannot improve
- Five Dysfunctions explains the team dynamics but not the technical system
- Theory of Constraints finds the bottleneck but ignores the human change journey
- ADKAR manages the individual through change but doesn't say what to change toward
- Three Ways shows the destination but not how to move an organisation from where it is

The book René could write is about **the connective tissue between these models** — how a leader uses them together as a diagnostic and navigational system for engineering transformation.

---

## The task

Generate a detailed book outline. The outline should:

1. **Identify the central argument** — what is the one claim this book makes that none of these five models makes on its own? It must be specific enough to be disagreed with.

2. **Name the audience problem** — what does the executive reader get wrong about engineering transformation that causes all the expensive failures? What do they keep buying (tooling, frameworks, consultants) that doesn't solve it?

3. **Propose a title and subtitle** — direct, non-jargon, executive-shelf appropriate. No buzzwords. Think: board room credibility, not airport business book.

4. **Draft a 10–14 chapter structure** with:
   - Chapter title (punchy, not academic)
   - 2–3 sentence summary of the argument in that chapter
   - Which model(s) from René's library this chapter builds on, extends, or challenges
   - One concrete question or tension the chapter resolves for the executive reader

5. **Show the model integration map** — a simple diagram or table showing how the five models relate to each other in the book's overall argument (which is foundational, which is diagnostic, which is directional, which is navigational).

6. **Suggest an introduction hook** — one scene, statistic, or recurring pattern from client work that opens the book in René's voice (practitioner thinking out loud, not consultant pitching).

7. **Identify the white space** — what can this book say that reading all five source materials separately cannot?

---

## Voice constraints

Follow René's voice from `.github/instructions/blog-style.instructions.md`:
- Plain words, real sentences, ideas that go somewhere
- Opens with scene or tension, never a definition or agenda slide
- Short sentences for emphasis after longer explanatory ones — never three consecutive fragments
- No corporate hedging, no faux-revelation pivots as rhetorical flourish
- Audience is executives: translate technical concepts into business stakes (cost, risk, talent, delivery speed)
- The pattern is always more interesting than the specific case

---

## Output format

```
# [Title]: [Subtitle]

## Central argument
## The executive's expensive mistake
## Why these five models together
## Chapter structure
  ### Chapter 1: ...
  ### Chapter 2: ...
  ...
## Model integration map
## Opening hook (draft paragraph)
## White space this fills
```
