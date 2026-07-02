---
layout: post
title: "DORA Metrics: What They Are and Why They Matter"
subtitle: "Using data to understand and improve your software delivery performance"
date: 2026-06-15 09:00:00 +0200
tags: [devops, metrics, dora, continuous-delivery]
excerpt: >
  The four DORA metrics — deployment frequency, lead time for changes, change failure rate,
  and time to restore service — are the best predictors of software delivery performance
  and organisational success. Here's how to start using them.
---

The four DORA metrics — **deployment frequency**, **lead time for changes**,
**change failure rate**, and **time to restore service** — have become the de facto standard
for measuring software delivery performance. But many teams collect them without knowing
what to do with the data.

Let me break down what each metric means, what it tells you, and how to use them effectively.

## The Four Metrics

### 1. Deployment Frequency

*How often does your team deploy to production?*

This is the most visible metric. Elite teams deploy multiple times per day.
Low performers deploy less than once per month.

But frequency alone isn't the goal — it's a proxy for your ability to respond quickly
to user needs and market changes.

### 2. Lead Time for Changes

*How long does it take from a commit to running in production?*

This captures your entire delivery pipeline efficiency. Long lead times signal manual
handoffs, large batch sizes, slow review processes, or fragile deployments.

### 3. Change Failure Rate

*What percentage of production deployments cause an incident?*

This is your quality metric. Elite teams have change failure rates below 5%.
If yours is high, look at your testing strategy, code review practices, and deployment process.

### 4. Time to Restore Service

*When something breaks, how quickly can you recover?*

This measures your operational maturity and your ability to detect, diagnose, and resolve
production incidents. Invest in observability and incident response long before you need it.

## Using Them Together

The power of DORA metrics comes from using them as a system, not as individual KPIs:

- **High frequency + low lead time** = fast, continuous flow
- **Low change failure rate + low MTTR** = reliable, resilient delivery

Teams that perform well on all four metrics are **2x more likely** to meet their reliability
targets and **1.5x more likely** to meet their business objectives.

## Getting Started

1. **Measure before you optimise** — instrument your pipelines and incident tracking
2. **Focus on trends, not benchmarks** — compare yourself to yourself, not industry averages
3. **Improve the bottleneck** — use the metrics to identify your biggest constraint
4. **Share the data widely** — transparency creates accountability and shared purpose

The metrics won't tell you *what* to fix, but they will tell you *where* to look.

Start there.
