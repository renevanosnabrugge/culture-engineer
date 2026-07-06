---
layout: post
title: "Aligned Autonomy in Practice"
date: 2023-01-19 09:00:00 +0200
tags: [culture, engineering, operating-model, architecture]
canonical_url: "https://roadtoalm.com/2023/01/19/aligned-autonomy-in-practice/"
image_prompt: "Abstract editorial illustration of a spectrum slider between two poles — rigid control on the left (dark, constrained grid) and pure chaos on the right (scattered particles) — with the sweet-spot centre glowing orange, dark navy background, no text, minimal 16:9"
excerpt: >
  Full autonomy gives teams freedom but risks fragmentation. Pure alignment gives
  predictability but kills ownership. The answer — aligned autonomy — is easier to say
  than to implement. Here is a practical model that actually works.
image: "/assets/images/aligned-autonomy-inpractice.png"
---

In my previous post about [building an engineering culture](/blog/2023/01/17/building-an-engineering-culture/), I talked about how important it is to embrace the fact that you need to behave like a software company. In this post I want to go deeper into one specific aspect of the "Empowering Operating Model" pillar.

When it comes to the operating model of a software company, I truly believe in autonomy — putting responsibility and decisions as close as possible to the place where the actual work is done. That means software engineers and others doing the real work need to be empowered to make decisions. And with the power to make decisions comes responsibility and accountability.

To implement this, I find value stream-aligned teams, platform teams, and end-to-end responsible teams to be the right approach. Organising teams around a value stream, and putting the roles and people in the team that are necessary to do the job, is key.

## The Problem with Full Autonomy

However, when you have multiple teams and multiple products at any meaningful scale, full autonomy is not ideal. You might end up with five different software stacks, or suddenly have an accidental multi-cloud strategy. Henrik Kniberg's famous picture from his time at Spotify describes this problem perfectly with the concept of **"Aligned Autonomy."**

The picture shows a spectrum. At one end: too much alignment. Everyone does exactly what they are told. Every decision needs approval. You get what you *want* but not what you *need*. Ownership disappears. Teams wait instead of moving.

At the other end: only autonomy. Everybody does as they like. The team does what seems right at the moment. Organisational goals and standards are not needed — because autonomy. The result: fragmentation, technical debt, and an organisation that cannot coordinate.

The ideal is **aligned autonomy**: clear guardrails, organisational goals, vision and purpose — so that teams can make their own decisions that remain in line with the bigger picture.

## Decision Type 1 and Decision Type 2

Here is a practical model from a colleague who struggled with achieving alignment in his team. To make it clear for everyone when it was the right time to seek input or approval, he introduced two decision types.

**Decision type 1** covers all decisions that can be reversed within one or two weeks, or that are low-cost (less than two days of effort). A simple tool, a package dependency, a licence, a conference. *Do not ask. Just decide. Make the call. Do not get delayed.*

**Decision type 2** covers decisions that are not easy to roll back, or that need upfront thinking. Which cloud provider? Which tech stack will be the standard? What major tool will we adopt? Those decisions need to be visible to management — and when management decides something, they need to communicate it clearly.

## The Advice Process

For decision type 2, I found [Martin Fowler's advice process model](https://martinfowler.com/articles/scaling-architecture-conversationally.html) particularly useful. Summarised:

1. Someone has an idea or a decision of type 2
2. They discuss it with a subject matter expert
3. They record the pre-decision in an [Architectural Decision Record (ADR)](https://adr.github.io/)
4. They present it in a forum with like-minded peers
5. They adjust where needed and decide

This approach gives teams real autonomy without management losing touch. No single person is a bottleneck. Decisions are visible, documented, and challenged constructively before they are locked in.

## Summary

By making it clear that there are different types of decisions, and surrounding that with sensible guardrails, it becomes easier for people to understand and embrace aligned autonomy. When you further implement the advice process, you give teams a great foundation for moving fast — without the organisation losing coherence in the process.

The goal is never control. The goal is coordination at speed.
