---
layout: model
title: "Theory of Constraints"
origin: "Eliyahu M. Goldratt"
tags: [operations, flow, systems-thinking]
excerpt: "Every system has exactly one constraint. Improve anything else and output doesn't change."
learn_more: "https://www.toc-goldratt.com/en/theory-of-constraints"
---

Every system has exactly one constraint — the single factor that limits its total throughput. Improving any other part of the system does not increase output; it only increases work queued in front of the constraint.

Goldratt introduced the Theory of Constraints in *The Goal* (1984) through a business novel about a failing factory. The core logic is simple and powerful enough to have spread across manufacturing, software, project management, and organisational design.

## The five focusing steps

1. **Identify** the constraint — find the one element limiting total throughput.
2. **Exploit** the constraint — maximise its output without spending money. Ensure it never waits.
3. **Subordinate** everything else — stop optimising non-constraints. Their job is to serve the constraint.
4. **Elevate** the constraint — if it is still the limiting factor, invest to increase its capacity.
5. **Prevent inertia** — once the constraint moves, find the new one. Repeat.

## Application to software delivery

The Phoenix Project explicitly applies Theory of Constraints to IT. In that book, the constraint is Brent — a single person who is the only one who knows how to do certain critical tasks. Every improvement elsewhere just creates more work queued behind Brent.

The translation to software organisations is direct:
- **Constraint identification**: Where does work pile up? What is the step that limits the whole pipeline?
- **Exploitation**: Ensure the constraint is never blocked — pair it, protect it, remove interruptions.
- **Subordination**: If the constraint is testing, don't optimise deployment pipelines — they will only deliver more work to the test bottleneck faster.

## Why local optimisation is dangerous

The most common failure mode I see in technology transformation is improving individual stages without understanding the system constraint. Teams get faster. Build pipelines get faster. And delivery doesn't improve because the constraint is somewhere else — often in approval gates, security reviews, or a single overloaded person.

Systemic thinking starts with asking: where is the constraint? Everything else follows from that answer.
