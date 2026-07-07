---
layout: page
title: About Me
subtitle: Technology & Transformation Executive | Speaker | Microsoft MVP
permalink: /about/
---

<div class="about-grid">
  <div>
    <h2 class="about-name">{{ site.author.name }}</h2>
    <p class="about-role">{{ site.author.title }}</p>
    <p class="about-bio">
      A technology executive with 25+ years of experience helping complex organizations become
      sharper, faster and more effective — while moving the people inside them along the way.
      Currently Global Consulting Director at Xebia &middot; Microsoft Services (Xpirit), leading
      consulting strategy, delivery and talent across four international entities with a primary
      focus on the Benelux region.
    </p>
    <p class="about-bio">
      I operate where strategy, execution and people leadership come together, turning ambition
      into real change instead of slideware. Regulated, high-continuity environments are
      familiar territory — places where standing still isn’t an option but neither is breaking things.
    </p>
    <p class="about-bio">
      I have a soft spot for organizations where technology matters to people’s lives: healthcare,
      government, education. I am known for stepping beyond formal role boundaries to fix what
      is systemically broken and for being consistently drawn into the strategic and creative
      work that moves organizations forward.
    </p>
    <blockquote style="border-left:3px solid var(--accent,#e85d04);padding-left:1rem;margin:1.5rem 0;font-style:italic;color:var(--slate-600)">
      &ldquo;Most technology problems are culture problems in disguise.&rdquo;
    </blockquote>
    <div class="about-actions">
      <a href="{{ site.author.linkedin }}" class="btn btn-dark" target="_blank" rel="noopener noreferrer">Connect on LinkedIn</a>
    </div>
  </div>
  <div>
    <div class="about-photo-wrap">
      {% if site.author.photo %}
      <img src="{{ site.author.photo | relative_url }}" alt="{{ site.author.name }}" class="about-photo">
      {% else %}
      <div class="about-photo-placeholder">
        <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1" opacity=".4">
          <circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/>
        </svg>
        <span>Add profile photo to<br><code>assets/images/profile.jpg</code></span>
      </div>
      {% endif %}
    </div>
  </div>
</div>

## Areas of Expertise

<div class="expertise-list">
  <span class="expertise-tag">Strategy &amp; Direction</span>
  <span class="expertise-tag">Transformation at Scale</span>
  <span class="expertise-tag">Engineering Culture</span>
  <span class="expertise-tag">DevOps &amp; Cloud</span>
  <span class="expertise-tag">Operating Models</span>
  <span class="expertise-tag">People &amp; Leadership</span>
  <span class="expertise-tag">Governance &amp; Compliance</span>
  <span class="expertise-tag">Azure &amp; Microsoft Stack</span>
  <span class="expertise-tag">Organizational Design</span>
  <span class="expertise-tag">Public Speaking</span>
  <span class="expertise-tag">FinOps</span>
  <span class="expertise-tag">Site Reliability Engineering</span>
</div>

## Conference Experience

International speaker on 50+ stages, including:

- **Techorama** — Belgium &amp; Netherlands (multiple years)
- **NDC Conferences** — Porto, Oslo, London
- **Visual Studio Live!** — Las Vegas, San Diego
- **Live! 360 Tech Con** — Orlando, FL
- **All Day DevOps** — Online (multiple years)
- **devCampNoord** — Groningen, Netherlands
- **CloudBrew** — Mechelen, Belgium
- **GitHub Universe** — San Francisco

Topics include DevOps transformation, engineering culture, cloud strategy, FinOps,
Site Reliability Engineering, and the people side of technology change.

## Background

With 25+ years in the industry, my career has grown from hands-on software development
through ALM and DevOps consulting to executive leadership:
**Programming → ALM → DevOps → DevOps Strategy → CTO**.

I served as **Interim CTO at Wigo4IT** (2020–2022), the shared IT organization for
Amsterdam, Rotterdam, The Hague and Utrecht, where I led a full technology transformation
and reduced platform costs by approximately 50% while maintaining service continuity.
I also advised **Maersk** on establishing their Cloud Centre of Excellence.

Previously, as Senior DevOps &amp; Cloud Consultant at Xebia/Xpirit (2009–2020),
I worked with organizations including Rabobank, Philips Healthcare, ABN AMRO, ONVZ,
Gasunie, and Glencore.

I am the **Founder of the Global DevOps Bootcamp &amp; Experience** — a community event
running across 30+ countries with 10,000+ participants. I hold the **Microsoft MVP** award
continuously since 2012.

<div class="video-embed">
  <iframe src="https://www.youtube.com/embed/KshDghBwk8M" title="Global DevOps Bootcamp" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</div>

---

<div class="contact-grid">
  <div>
    <h2 class="contact-section-heading">Get in Touch</h2>
    <p class="contact-intro">
      I'm always open to speaking invitations, consulting conversations, and connecting with
      fellow practitioners who care about building great engineering organizations.
    </p>

    <div class="contact-item">
      <div class="contact-icon">in</div>
      <div>
        <h4>LinkedIn</h4>
        <a href="{{ site.author.linkedin }}" target="_blank" rel="noopener noreferrer">{{ site.author.linkedin | remove: "https://" }}</a>
      </div>
    </div>

    {% if site.author.twitter %}
    <div class="contact-item">
      <div class="contact-icon">&#120143;</div>
      <div>
        <h4>Twitter / X</h4>
        <a href="{{ site.author.twitter }}" target="_blank" rel="noopener noreferrer">{{ site.author.twitter | remove: "https://twitter.com/" | prepend: "@" }}</a>
      </div>
    </div>
    {% endif %}

    {% if site.author.github %}
    <div class="contact-item">
      <div class="contact-icon">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
      </div>
      <div>
        <h4>GitHub</h4>
        <a href="{{ site.author.github }}" target="_blank" rel="noopener noreferrer">{{ site.author.github | remove: "https://github.com/" | prepend: "@" }}</a>
      </div>
    </div>
    {% endif %}
  </div>

  <div class="contact-topics-box">
    <h3>Topics I speak about</h3>
    <div class="expertise-list">
      <span class="expertise-tag">Enterprise Architecture</span>
      <span class="expertise-tag">Platform Engineering</span>
      <span class="expertise-tag">DevOps Transformation</span>
      <span class="expertise-tag">Engineering Culture</span>
      <span class="expertise-tag">Psychological Safety</span>
      <span class="expertise-tag">DORA Metrics</span>
      <span class="expertise-tag">Cloud &amp; Azure</span>
      <span class="expertise-tag">Organizational Design</span>
      <span class="expertise-tag">Technical Leadership</span>
    </div>
    <div class="contact-topics-footer">
      <p>Ready to book a talk or start a conversation?</p>
      <a href="{{ site.author.linkedin }}" class="btn btn-dark" target="_blank" rel="noopener noreferrer">Send me a message</a>
    </div>
  </div>
</div>
