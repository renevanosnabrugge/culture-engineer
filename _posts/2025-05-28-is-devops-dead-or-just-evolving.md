---
layout: post
title: "Is DevOps Dead? Or Just Evolving?"
date: 2025-05-28 09:00:00 +0200
tags: [devops, platform-engineering, culture, architecture]
canonical_url: "https://roadtoalm.com/2025/05/28/is-devops-dead-or-just-evolving/"
image_prompt: "Illustration of the classic DevOps infinity loop symbol transforming and morphing into an interconnected gear-and-platform mechanism, mid-transformation glow in orange, dark navy background, minimal flat editorial style, no text, 16:9"
excerpt: >
  "DevOps is dead. Long live platform engineering." I've heard this phrase at conferences
  and in vendor pitches. It made me think. After years of championing DevOps principles,
  was the industry ready to throw them away?
---

When I first heard the phrase "DevOps is dead. Long live platform engineering," I was actually a bit surprised. It is something that has been floating around at conferences, on blogs, in vendor pitches over the last year or so, and it made me think. I have been a big supporter of DevOps. The principles made sense. The results were real. So hearing that it was "dead" felt like the industry was ready to throw away something we just barely got right.

But after thinking it through — and discussing it at length on the LEAD podcast — the conclusion is not so dramatic. DevOps is not dead. It is just evolving. And maybe that is a good thing.

## The Problem Is Not DevOps — It's How Heavy It's Become

When DevOps first became popular, the goal was clear: break the silos. Get development and operations to work together. Let teams take full ownership of what they build, from idea to running system. It worked. It still works. When you give teams that responsibility, they make better decisions. They care more about reliability. They feel more connected to what they deliver.

But we have also seen the other side. Not every team is equipped to take on all those responsibilities. The list of things a modern team needs to handle keeps growing. Cloud infrastructure, CI/CD pipelines, monitoring, security, compliance, cost tracking, networking, provisioning. It is a lot. And even if you have smart, motivated people, it is not realistic for every team to be great at all of it.

So we started seeing cracks. Teams struggling to get their environments running. Developers overwhelmed by tasks outside their core focus. Platforms built by developers who never wanted to think about infrastructure. And on top of that, the industry started calling everything DevOps, really watering down the true meaning of the word.

## Platform Engineering Doesn't Kill DevOps — It Supports It

This is where platform engineering comes in. Not as a replacement, but as an enabler. The whole point of platform engineering is to reduce the cognitive load on teams. To help them focus. To let them keep owning their applications without needing to reinvent the wheel every time.

A platform team builds internal products. Templates, services, and tools that help other teams move faster. Instead of every team setting up their own infrastructure for an API, the platform team builds a standard approach. Instead of every team managing their own firewall rules through tickets and waiting three days, the platform team builds a self-service interface that takes care of it in minutes.

But here is the important part: the platform is optional. The team using it still owns their app. They can extend the templates. Or choose not to use them at all, as long as they stay within the broader boundaries set by security or compliance. That is not top-down control. That is support with autonomy.

## What Makes a Good Platform Team

A good platform team does not push their tools onto others. They act like a product team. They have users — the developers and engineers building business features. So the platform team listens to them. They look for the pain points. They ask where time is being wasted. And they build solutions to solve those problems.

That sounds obvious. But it often goes wrong. I have seen too many platform teams form out of old operations teams. They rebrand, but keep doing the same thing. Lots of tickets (or their equivalent), long lead times, tight control. That is not a platform. That is a new bottleneck.

Instead, a good platform should act like any other cloud service. Easy to use, well-documented, with clear value. If teams do not want to use it, that is a sign something is off. And if they do want to use it, they should be able to contribute to it too. Internal open source is a great model here. The platform team owns the code, but other teams can submit improvements or add what they need.

## Start with the Problems, Not the Tools

If you are thinking about building a platform team, do not start by picking a tool or copying what someone else did. Start by talking to your developers. Ask them where they are losing time. What tasks feel repetitive. What is blocking them from moving faster.

Maybe it is setting up new environments. Maybe it is getting approvals for security changes. Maybe it is building the same CI/CD pipeline over and over again. Whatever it is, start there. Fix one thing. Then another. Measure the impact. Keep talking to the teams. Keep improving.

And do not build everything all at once. You can start small. You probably already have what you need. Git, pipelines, some YAML files. Use what is there. Build something that works. And when that works, invest in something more.

## So, Is DevOps Dead?

No. Not at all.

DevOps is still the goal. Teams owning what they build. Fast feedback. End-to-end responsibility. But we have learned that it is not enough to just say "you build it, you run it" and expect everyone to figure it out on their own.

Platform engineering is one way to support that model. It gives teams the tools and standards they need to succeed. It removes some of the overhead. It creates guardrails without taking away control.

In the end, DevOps and platform engineering are not opposites. They go together. They solve different parts of the same problem. One sets the mindset, the other supports the execution.

**DevOps is not dead. It is just growing up.**
