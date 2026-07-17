---
layout: model
title: "The Three Ways — DevOps"
origin: "Gene Kim, Jez Humble, Patrick Debois, John Willis"
tags: [devops, flow, feedback, learning]
excerpt: "Three principles that underpin every high-performing technology organisation."
learn_more: "https://itrevolution.com/articles/the-three-ways-the-principles-underpinning-devops/"
published: false
---

The Three Ways are the foundational principles of the DevOps movement, introduced in The Phoenix Project and expanded in The DevOps Handbook. They describe how work should flow, how feedback should travel, and how organisations should learn.

## The First Way — Flow

Optimise the flow of work from development through operations to the customer. Make work visible, limit work-in-process, reduce batch sizes, and eliminate handoff delays.

The key insight: a system's throughput is determined by its constraint, not by the performance of individual stages. Speeding up development while operations is the bottleneck produces more work queued in front of the constraint, not more value delivered to customers.

**Practices that enable it:** Continuous integration, deployment pipelines, feature flags, trunk-based development.

## The Second Way — Feedback

Create fast feedback loops at every stage so problems are detected and corrected immediately, not discovered by customers six months later. Amplify feedback from downstream processes.

The key insight: the cost of fixing a defect increases exponentially the later it is found. Feedback loops that catch problems at the source are orders of magnitude cheaper than feedback loops at the end of a waterfall.

**Practices that enable it:** Automated testing, monitoring, observability, canary releases, production telemetry.

## The Third Way — Continual Learning and Experimentation

Build a culture of experimentation and learning from failure. Allocate time for improvement. Create rituals that amplify learning across the organisation.

The key insight: the organisations that improve fastest are the ones that learn fastest — and learning requires psychological safety to surface failures rather than suppress them.

**Practices that enable it:** Blameless post-mortems, game days, innovation time, Communities of Practice.

## How I use this model

The Three Ways give technology leaders a vocabulary for explaining why culture and technical practice are not separate concerns. The Third Way in particular makes the link explicit: you cannot sustain Continuous Delivery without a culture that treats failure as information.
