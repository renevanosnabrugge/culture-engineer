---
name: social-pack
description: Turn a published or draft blog post into LinkedIn post variants and an image prompt.
---

# Social Pack Skill

Input: a blog post (draft or published URL).

Output:
1. Three LinkedIn post variants (see labels below), each under 200 words,
   native-post style (no "click the link" as the hook — save the link for
   the end):
   - "Contrarian hook" — leads with the surprising/pushback angle
   - "Story format" — leads with a concrete scene (Wigo4it, a client
     conversation, a personal moment)
   - "Question format" — opens with a direct question to the reader

   Each variant **must end** with a short closing line that mentions the
   content type and links to it. Use plain text, not markdown hyperlinks
   (LinkedIn renders raw URLs). The phrasing should be natural and brief:
   - Blog post: `I wrote about this on my blog: https://culture-engineers.nl/blog/YYYY/MM/DD/slug/`
   - Book summary: `I wrote a full summary on my blog: https://culture-engineers.nl/inspiration/books/slug/`
   - Model page: `I mapped this out on my blog: https://culture-engineers.nl/inspiration/models/slug/`

   If the content is not yet published (i.e. `published: false` in front
   matter), still include the URL — it will resolve once the post goes live.
2. One image prompt suitable for an AI image generator (portrait 1024×1536,
   professional, abstract/metaphorical rather than literal — avoid stock-photo
   clichés like handshakes or lightbulbs). The prompt will be passed directly
   to the Image Generator agent (`image-generator`) to produce the actual PNG
   file — so write it as a complete, self-contained generation prompt.
3. Suggested posting day per the Mon/Wed/Fri rhythm already agreed.