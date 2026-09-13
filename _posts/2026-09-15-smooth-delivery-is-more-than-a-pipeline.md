---
layout: post
title: "Smooth Delivery Is More Than a Pipeline"
date: 2026-09-15 09:00:00 +0200
tags: [delivery, engineering-culture, devops, leadership]
image: "/assets/images/smooth-delivery-is-more-than-a-pipeline.png"
image_prompt: "Abstract illustration of a winding river merging from many smaller streams into one smooth channel, with a few visible checkpoints or lock gates along the way, deep blue and warm amber palette, no text, 1024x1536 landscape format, geometric-conceptual style, linked-in banner size"
excerpt: >
  Every time I hear someone talk about smooth delivery, the conversation drifts to CI/CD within a minute. Pipelines are the easy part. The hard part is everything around them.
published: false
---

Every time I hear someone talk about smooth delivery, the conversation drifts to CI/CD within a minute. Build faster. Deploy faster. Automate the infrastructure. And sure, that matters. But I have sat in enough rooms with architecture boards, approval gates, and testers to know that the pipeline was rarely the thing slowing anyone down.

Smooth delivery is one of the pillars of the Engineering Culture Model, and when I walk people through it, I notice the same reflex every time. Someone nods, says "so we need better CI/CD," and starts sketching a new deployment pipeline on the whiteboard. That is not wrong, it is just incomplete. A fast pipeline moving code through a slow process is like adding a faster elevator to a building where you still need six signatures to open the front door.

## The value stream nobody draws

If you actually want to speed up delivery, start somewhere less exciting than tooling: draw the value stream. Not the technical one, the organizational one. Who touches a change between the moment a developer commits it and the moment a user benefits from it? Which approvals does it need? Which board reviews it? Which tester signs off, and why?

I have seen teams with beautifully automated pipelines that still take three weeks to ship a one-line fix, because the change has to pass an architecture board that meets biweekly, then wait for a change advisory board rooted in an ITIL process nobody has revisited since it was written. The pipeline runs in four minutes. The wait around it takes three weeks. Nobody measures that gap, so nobody fixes it.

## Not every gate is the enemy

This is not an argument for removing every approval and testing step. Some of them exist for good reasons: regulatory requirements, genuine risk, hard-won lessons from a past incident. The point is not to tear down every gate you find. The point is to know which gates actually reduce risk and which ones just reduce accountability, spread thin across a committee so no single person has to own a decision.

Ask, for every checkpoint in your value stream: what risk does this remove, and could we remove that risk closer to the work instead? Automated testing can replace a manual sign-off. A well-run architecture guild that pairs with teams early can replace a board that reviews finished designs. Trust, once earned, can replace a checklist. None of that shows up in a pipeline diagram, and all of it shows up in your lead time.

## Where I tell CIOs to start

When I talk to a CIO or CTO who wants faster delivery, I do not start by asking about their tooling. I ask them to map the full journey of a single, ordinary change, from idea to production, and mark every point where it waits for a person or a committee. Most leaders have never seen that picture. They have dashboards for build times and deployment frequency, but no visibility into the approval queue sitting in someone's inbox for eleven days.

Once that map exists, the priorities usually reorder themselves. The pipeline that takes four minutes stops being the target, and the nine-day wait for an approval nobody remembers requesting becomes the thing everyone wants fixed.

Coding often is not even the majority of a developer's job, and shipping code is even less of the majority of a delivery process. If you want smooth delivery, the pipeline is the visible ten percent. The value stream is the other ninety, and it lives in your org chart, your risk appetite, and your habit of approving things in meetings instead of in the flow of work.

Fix the pipeline if it is broken. But if you really want to move faster, go find out who has to say yes before code reaches your customers, and ask each of them what would happen if they said yes a little sooner.
