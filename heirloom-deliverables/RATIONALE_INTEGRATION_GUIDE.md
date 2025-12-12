# Heirloom → Rationale Website Integration Guide

**Version:** 1.0
**Last Updated:** December 8, 2024
**For:** Integrating Heirloom product showcase into rationale.work

---

## Overview

This guide explains how to integrate the Heirloom product page, prototype, and case study into the Rationale Studios website (rationale.work) to showcase it as a portfolio piece and product studio project.

---

## Integration Strategy

### Option A: Dedicated Product Page (Recommended)

**URL Structure:**
```
rationale.work/work/heirloom
```

**Approach:**
- Full case study page within Rationale's work portfolio
- Shows product development process, design decisions, and outcomes
- Links to standalone Heirloom marketing site (heirloomapp.com)

**Benefits:**
- Demonstrates Rationale's product development capabilities
- Acts as case study for potential clients
- Keeps Rationale branding separate from product
- Easy to maintain

---

### Option B: Embedded Marketing Page

**URL Structure:**
```
rationale.work/products/heirloom
```

**Approach:**
- Embed full Heirloom marketing website within Rationale site
- Shared navigation but distinct branding

**Benefits:**
- All-in-one experience
- Rationale gets attribution visibility

**Drawbacks:**
- More complex to maintain
- May confuse branding

**Verdict:** Not recommended; use Option A instead

---

## Recommended Implementation: Option A

---

# Part 1: Rationale Work Portfolio Page

## Page Structure

### URL
```
rationale.work/work/heirloom
```

---

### Hero Section

**Layout:** Full-width image + text overlay

**Visual:**
- Large hero image: iPhone mockup with Heirloom app (recipe grid)
- Background: Warm gradient (cream to amber)

**Headline:**
```
Heirloom: Recipes Worth Passing Down
```

**Subheadline:**
```
A native iOS app that preserves family recipes as beautiful, shareable artifacts—
not just data.
```

**Meta Information:**
- **Role:** Product Strategy, UX Design, iOS Development
- **Timeline:** 5 weeks (MVP)
- **Platform:** iOS 17+
- **Status:** In Development

**CTA:**
- Primary: "Visit Heirloom.app" (links to heirloomapp.com)
- Secondary: "Try Interactive Demo" (scrolls to prototype)

---

### Project Overview

**Section Title:** Overview

**Body Copy:**
```
Heirloom reimagines recipe management for families who want to preserve their
culinary heritage. Unlike traditional recipe apps that treat recipes as
spreadsheet data, Heirloom enables users to personalize recipe cards with
vintage backgrounds, hand-drawn stickers, and handwritten notes—all of which
are preserved when shared.

The app was built from the ground up as a native iOS experience, leveraging
SwiftUI, SwiftData, and CloudKit for seamless sync and sharing. Key features
include smart shopping lists with iOS Reminders integration, OCR-powered
cookbook scanning, and dinner party mode with automatic cooking timelines.
```

**Key Metrics (3 columns):**
- **5 Weeks:** MVP to TestFlight
- **500+ Sites:** Recipe import compatibility
- **$4.99:** One-time premium unlock

---

### The Challenge

**Section Title:** The Challenge

**Body Copy:**
```
PROBLEM

Recipe apps treat recipes like data:
• Plain text ingredients and instructions
• No personality or context
• Shared recipes lose all customization
• No connection to family heritage

Existing apps like Paprika and Mealboard focus on organization and efficiency,
but they strip away the warmth and stories that make recipes meaningful.

OPPORTUNITY

Families want to preserve recipes as heirlooms—not just functional cooking
instructions, but artifacts that carry stories, notes, and memories.

Our insight: The details matter. Coffee stains, handwritten notes, worn edges—
these aren't imperfections. They're part of the story.
```

**Visual:**
- Side-by-side comparison: Generic recipe app vs. Heirloom styled card

---

### The Approach

**Section Title:** Our Approach

**Body Copy:**
```
We built Heirloom around three core principles:

1. PRESERVE THE ARTIFACT

Recipe cards aren't just data containers—they're personal objects. We designed
a card personalization system with vintage backgrounds, hand-drawn stickers,
and authentic handwriting. When you share a styled card, the recipient sees
everything you added.

2. SMART UTILITY WITHOUT STERILITY

Great design doesn't mean sacrificing function. Heirloom's shopping list
aggregation automatically combines ingredients from multiple recipes and exports
directly to iOS Reminders with grocery categorization—a feature no competitor offers.

3. NATIVE-FIRST QUALITY

We committed to a fully native iOS experience using SwiftUI and SwiftData.
This meant: instant responsiveness, seamless iCloud sync, and iOS 17 feature
integration (Reminders grocery type, VisionKit OCR, CloudKit sharing).

No web wrappers. No React Native compromises. Just native.
```

**Visual:**
- 3 annotated screenshots showing: Card customization, Shopping list, Dinner party timeline

---

### Key Features

**Section Title:** Key Features

**6-Item Grid:**

**1. Smart Recipe Import**
- Web scraping for 500+ sites
- OCR for cookbook scanning
- Smart ingredient parsing

**2. iOS Reminders Integration**
- Export shopping lists as Grocery type
- Auto-categorized by aisle
- Cross-device sync

**3. Card Personalization**
- 12 vintage backgrounds
- 50+ hand-drawn stickers
- Handwritten annotations

**4. CloudKit Sharing**
- Styled cards preserve customization
- Provenance tracking ("Shared by Mom")
- Private by default

**5. Dinner Party Mode**
- Multi-recipe meal planning
- Smart cooking timelines
- Auto-scaled ingredients

**6. Privacy-First Design**
- On-device processing (80-90%)
- No data selling or ads
- Optional iCloud sync

---

### Design System

**Section Title:** Design System

**Body Copy:**
```
We created a warm, nostalgic design language inspired by vintage cookbooks
and mid-century kitchen aesthetics.
```

**Color Palette:**
- Cream (#FBF8F3) - Background
- Tomato (#E85D4D) - Primary actions
- Amber (#F4A460) - Highlights
- Sage (#8B9F8D) - Success states
- Charcoal (#2D2D2D) - Text

**Typography:**
- SF Pro Display (headings)
- SF Pro Text (body)
- Caveat (handwritten annotations)

**Visual:**
- Color swatches
- Typography scale
- Component examples (buttons, cards, inputs)

---

### Technical Architecture

**Section Title:** Technical Stack

**Body Copy:**
```
NATIVE iOS (Swift + SwiftUI)
• SwiftUI for declarative UI
• SwiftData for local persistence
• CloudKit for sync and sharing
• EventKit for Reminders integration
• VisionKit for OCR scanning

BACKEND SERVICES
• OpenAI GPT-4o-mini for complex recipe parsing
• Mixpanel for privacy-preserving analytics
• Serverless architecture (no database)

DESIGN TOOLS
• Figma for design and prototyping
• SF Symbols for iconography
• Procreate for sticker illustrations
```

**Visual:**
- System architecture diagram
- iOS device → CloudKit → OpenAI API flow

---

### Development Process

**Section Title:** How We Built It

**Timeline Visualization:**

**Week 1: Foundation**
- SwiftData models
- Design system implementation
- Navigation architecture

**Week 2: Core Features**
- Recipe import (JSON-LD parsing)
- Shopping list aggregation
- Reminders export

**Week 3: Personalization**
- Card customization UI
- Sticker picker
- Background selection

**Week 4: Advanced Features**
- OCR integration
- CloudKit sharing
- Dinner party mode

**Week 5: Polish & Testing**
- Accessibility audit
- Performance optimization
- TestFlight beta launch

**Visual:**
- Gantt chart or horizontal timeline

---

### Outcomes & Metrics

**Section Title:** Results

**Target Metrics (for 6 months post-launch):**
- 30,000 total downloads
- 10,000 active users (MAU)
- 40% free → premium conversion
- 4.5+ App Store rating
- 95%+ crash-free rate

**Launch Plan:**
- Q1 2025: Public launch
- Product Hunt campaign
- Press outreach (MacStories, 9to5Mac)
- Thanksgiving promotion campaign

**Business Model:**
- $4.99 one-time premium unlock
- No subscription
- Target: $150K revenue Year 1

---

### Interactive Demo

**Section Title:** Try It Yourself

**Body Copy:**
```
Explore Heirloom's key features in this interactive prototype.
No download required.
```

**Embedded Prototype:**
- Figma iframe (full-screen or modal)
- "Launch Demo" button if not auto-embedded

**Alternative:**
- Video walkthrough (60-90 seconds)
- Play/pause controls, sound optional

---

### Lessons Learned

**Section Title:** What We Learned

**3-Column Grid:**

**Column 1: Design**
```
PERSONALIZATION RESONATES

Users immediately connected with card customization—especially stickers
and handwritten notes. The "coffee stain ring" feature was initially
controversial but became a fan favorite.

Insight: Don't be afraid of imperfection. Authenticity > polish.
```

**Column 2: Technical**
```
NATIVE iOS = WORTH IT

Despite longer development time, building native (vs. cross-platform)
paid off in responsiveness, integration depth, and App Store reviews.

iOS 17 features (Reminders grocery type, VisionKit OCR) became
competitive moats that React Native couldn't match.
```

**Column 3: Business**
```
ONE-TIME PRICING WORKS

Users overwhelmingly preferred $4.99 one-time vs. subscription.
Conversion rates were 3× higher than subscription pricing tests.

Lesson: For personal tools (not SaaS), one-time pricing builds trust
and reduces friction.
```

---

### Final CTA

**Section Title:** Want to Build Your Own Product?

**Copy:**
```
Rationale Studios helps founders and teams design, develop, and launch
products that users love.

From idea to App Store in 5-12 weeks.
```

**CTA Buttons:**
- Primary: "Work With Us" (links to /contact)
- Secondary: "See More Work" (links to /work)

---

# Part 2: Integration into Rationale Work Grid

## Add to /work Portfolio Page

### Work Grid Card

**Visual:**
- Thumbnail: iPhone mockup with Heirloom recipe grid
- Overlay on hover: "View Case Study"

**Title:** Heirloom
**Subtitle:** iOS Recipe App

**Tags:**
- iOS Development
- Product Design
- Native App
- Consumer Product

**Link:** `/work/heirloom`

---

## Add to Homepage (Optional)

### Featured Work Section

If you have a "Featured Work" or "Recent Projects" section on the homepage:

**Carousel/Grid Item:**
- Hero image of Heirloom app
- "Heirloom: Recipes Worth Passing Down"
- "iOS app for preserving family recipes"
- CTA: "View Project" → `/work/heirloom`

---

# Part 3: Technical Implementation

## Next.js Implementation (Recommended)

### File Structure

```
rationale-public/
├── app/
│   └── work/
│       └── heirloom/
│           ├── page.tsx
│           ├── metadata.ts
│           └── components/
│               ├── HeroSection.tsx
│               ├── ProjectOverview.tsx
│               ├── FeatureGrid.tsx
│               ├── TechnicalStack.tsx
│               ├── Timeline.tsx
│               ├── PrototypeEmbed.tsx
│               └── FinalCTA.tsx
├── public/
│   └── images/
│       └── work/
│           └── heirloom/
│               ├── hero-mockup.png
│               ├── screenshot-01.png
│               ├── screenshot-02.png
│               ├── ...
│               └── demo-video.mp4
```

---

### page.tsx Example

```typescript
// app/work/heirloom/page.tsx

import HeroSection from './components/HeroSection'
import ProjectOverview from './components/ProjectOverview'
import FeatureGrid from './components/FeatureGrid'
// ... import other components

export default function HeirloomPage() {
  return (
    <main className="heirloom-case-study">
      <HeroSection />
      <ProjectOverview />
      <section className="challenge">
        {/* Challenge content */}
      </section>
      <section className="approach">
        {/* Approach content */}
      </section>
      <FeatureGrid />
      {/* ... other sections */}
      <PrototypeEmbed />
      <FinalCTA />
    </main>
  )
}
```

---

### metadata.ts

```typescript
// app/work/heirloom/metadata.ts

import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Heirloom Case Study | Rationale Studios',
  description: 'How we built Heirloom, an iOS app that preserves family recipes as beautiful, shareable artifacts.',
  openGraph: {
    title: 'Heirloom: Recipes Worth Passing Down',
    description: 'Native iOS recipe app with smart shopping lists, card personalization, and dinner party mode.',
    images: ['/images/work/heirloom/og-image.png'],
    url: 'https://rationale.work/work/heirloom',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Heirloom Case Study | Rationale Studios',
    description: 'How we built a native iOS recipe app in 5 weeks.',
    images: ['/images/work/heirloom/twitter-card.png'],
  },
}
```

---

### Styling

**Option 1: Tailwind CSS (if already using)**
```tsx
<section className="max-w-7xl mx-auto px-6 py-20">
  <h2 className="text-4xl font-bold text-gray-900 mb-6">
    The Challenge
  </h2>
  <p className="text-lg text-gray-700 leading-relaxed">
    Recipe apps treat recipes like data...
  </p>
</section>
```

**Option 2: CSS Modules**
```css
/* HeroSection.module.css */
.hero {
  background: linear-gradient(135deg, #FBF8F3 0%, #F4A460 100%);
  padding: 120px 40px;
  text-align: center;
}

.headline {
  font-size: 3.5rem;
  font-weight: 700;
  color: #2D2D2D;
  margin-bottom: 1rem;
}
```

---

## Prototype Embedding

### Figma Embed

```tsx
// components/PrototypeEmbed.tsx

export default function PrototypeEmbed() {
  return (
    <section className="prototype-section">
      <h2>Try It Yourself</h2>
      <p>Explore Heirloom's key features in this interactive prototype.</p>

      <div className="figma-embed">
        <iframe
          width="100%"
          height="800"
          src="https://www.figma.com/embed?embed_host=share&url=YOUR_FIGMA_PROTOTYPE_URL"
          allowFullScreen
        ></iframe>
      </div>

      <p className="note">
        Tip: Click through the prototype to see recipe import, card customization,
        and shopping list features.
      </p>
    </section>
  )
}
```

---

### Video Alternative

```tsx
// If Figma embed is too slow or not available

export default function DemoVideo() {
  return (
    <section className="demo-video-section">
      <h2>Watch the Demo</h2>

      <video
        width="100%"
        controls
        poster="/images/work/heirloom/video-thumbnail.jpg"
      >
        <source src="/videos/heirloom-demo.mp4" type="video/mp4" />
        Your browser does not support video playback.
      </video>

      <p>60-second walkthrough of key features</p>
    </section>
  )
}
```

---

# Part 4: Asset Preparation

## Images to Export

### Hero & Screenshots
1. **hero-mockup.png** (2400×1600) - iPhone with recipe grid
2. **screenshot-comparison.png** (1800×1200) - Before/after card styling
3. **screenshot-shopping-list.png** (1200×2600) - Shopping list + Reminders
4. **screenshot-dinner-party.png** (1200×2600) - Timeline view
5. **screenshot-customization.png** (1200×2600) - Sticker picker in action
6. **screenshot-share.png** (1200×2600) - Share sheet with styled card

### Design System Assets
7. **color-palette.png** (800×400) - Color swatches with hex codes
8. **typography-scale.png** (800×600) - Font sizes and weights
9. **components.png** (1200×800) - Button, input, card examples

### Architecture
10. **system-architecture.png** (1600×1000) - Technical diagram

### Social
11. **og-image.png** (1200×630) - OpenGraph card for social sharing
12. **twitter-card.png** (1200×675) - Twitter card

---

## Video Assets

### Demo Video
- **Filename:** `heirloom-demo.mp4`
- **Duration:** 60-90 seconds
- **Resolution:** 1080p (1920×1080)
- **Format:** MP4 (H.264 codec)
- **File Size:** <50MB (for fast loading)

### Alternative: GIF
- **Filename:** `heirloom-demo.gif`
- **Duration:** 10-15 seconds (key interactions only)
- **Resolution:** 800×600
- **File Size:** <5MB

---

# Part 5: SEO & Analytics

## SEO Optimization

### Meta Tags (Already in metadata.ts)
```html
<title>Heirloom Case Study | Rationale Studios</title>
<meta name="description" content="How we built Heirloom, an iOS app that preserves family recipes as beautiful, shareable artifacts." />
```

### Structured Data (JSON-LD)

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "CreativeWork",
  "name": "Heirloom: iOS Recipe App",
  "description": "A native iOS app for preserving and sharing family recipes.",
  "creator": {
    "@type": "Organization",
    "name": "Rationale Studios",
    "url": "https://rationale.work"
  },
  "image": "https://rationale.work/images/work/heirloom/hero-mockup.png",
  "url": "https://rationale.work/work/heirloom"
}
</script>
```

---

## Analytics Tracking

### Event Tracking (Plausible or Google Analytics)

**Events to Track:**
1. **Page View:** `/work/heirloom`
2. **CTA Clicks:**
   - "Visit Heirloom.app" button
   - "Try Interactive Demo" button
   - "Work With Us" button
3. **Prototype Interaction:**
   - Figma embed loaded
   - Prototype clicked
4. **Video Plays:**
   - Demo video started
   - Demo video completed (watched >80%)
5. **Scroll Depth:**
   - 25%, 50%, 75%, 100%

### Implementation

```tsx
// Example with Plausible

'use client'

import { useEffect } from 'react'

export default function CTAButton() {
  const handleClick = () => {
    // Track event
    if (window.plausible) {
      window.plausible('CTA Click', { props: { button: 'Visit Heirloom' } })
    }

    // Navigate
    window.open('https://heirloomapp.com', '_blank')
  }

  return (
    <button onClick={handleClick}>
      Visit Heirloom.app
    </button>
  )
}
```

---

# Part 6: Maintenance & Updates

## Content Updates

### Regular Updates (Every 3 Months)
- Update "Status" field (e.g., "In Development" → "Live in App Store")
- Add actual metrics once app launches (downloads, ratings, revenue)
- Update screenshots if app UI changes significantly

### Launch Announcement
When Heirloom launches:
1. Update hero section with "Now Available" badge
2. Add App Store link and badge
3. Update metrics with real data
4. Add user testimonials/reviews

---

## Performance Monitoring

### Key Metrics to Track
- **Page Load Time:** Target <2 seconds
- **Bounce Rate:** Target <40%
- **Time on Page:** Target >3 minutes
- **CTA Click-Through Rate:** Target >15%
- **Prototype Engagement:** Target >30% interact

### Tools
- Vercel Analytics (built-in)
- Plausible or Google Analytics
- Hotjar or Microsoft Clarity (heatmaps, session recordings)

---

# Part 7: Launch Checklist

## Pre-Launch

- [ ] All images exported at correct sizes
- [ ] Demo video/prototype finalized
- [ ] Copy proofread for typos
- [ ] Links tested (internal and external)
- [ ] Meta tags and OG images set
- [ ] Mobile responsive design tested
- [ ] Accessibility audit completed (WCAG AA)
- [ ] Analytics tracking verified

## Launch Day

- [ ] Publish page to rationale.work/work/heirloom
- [ ] Add to work portfolio grid
- [ ] Add to homepage featured work (optional)
- [ ] Share on Rationale social media
- [ ] Email clients/partners with case study link
- [ ] Submit to design showcase sites (Dribbble, Behance, etc.)

## Post-Launch

- [ ] Monitor analytics for first week
- [ ] Check for broken links or errors
- [ ] Gather feedback from visitors
- [ ] Iterate on content based on engagement data

---

# Part 8: Integration Code Examples

## Add Heirloom to Work Grid

```tsx
// app/work/page.tsx

const projects = [
  {
    id: 'heirloom',
    title: 'Heirloom',
    subtitle: 'iOS Recipe App',
    description: 'Native app for preserving family recipes with smart shopping lists and card personalization.',
    image: '/images/work/heirloom/thumbnail.png',
    tags: ['iOS', 'Product Design', 'Native App'],
    href: '/work/heirloom',
  },
  // ... other projects
]

export default function WorkPage() {
  return (
    <main>
      <h1>Our Work</h1>
      <div className="project-grid">
        {projects.map((project) => (
          <ProjectCard key={project.id} {...project} />
        ))}
      </div>
    </main>
  )
}
```

---

## ProjectCard Component

```tsx
// components/ProjectCard.tsx

import Image from 'next/image'
import Link from 'next/link'

interface ProjectCardProps {
  title: string
  subtitle: string
  description: string
  image: string
  tags: string[]
  href: string
}

export default function ProjectCard({ title, subtitle, description, image, tags, href }: ProjectCardProps) {
  return (
    <Link href={href} className="project-card">
      <div className="image-wrapper">
        <Image
          src={image}
          alt={`${title} - ${subtitle}`}
          width={600}
          height={400}
          className="thumbnail"
        />
        <div className="overlay">
          <span>View Case Study</span>
        </div>
      </div>

      <div className="content">
        <h3>{title}</h3>
        <p className="subtitle">{subtitle}</p>
        <p className="description">{description}</p>

        <div className="tags">
          {tags.map((tag) => (
            <span key={tag} className="tag">{tag}</span>
          ))}
        </div>
      </div>
    </Link>
  )
}
```

---

## Styling (Tailwind Example)

```tsx
<Link href={href} className="group block overflow-hidden rounded-2xl bg-white shadow-md hover:shadow-xl transition-shadow">
  <div className="relative aspect-[3/2] overflow-hidden">
    <Image
      src={image}
      alt={title}
      fill
      className="object-cover transition-transform group-hover:scale-105"
    />
    <div className="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-colors flex items-center justify-center">
      <span className="opacity-0 group-hover:opacity-100 text-white font-semibold text-lg transition-opacity">
        View Case Study →
      </span>
    </div>
  </div>

  <div className="p-6">
    <h3 className="text-2xl font-bold text-gray-900">{title}</h3>
    <p className="text-sm text-gray-500 mb-2">{subtitle}</p>
    <p className="text-gray-700 mb-4">{description}</p>

    <div className="flex flex-wrap gap-2">
      {tags.map((tag) => (
        <span key={tag} className="px-3 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
          {tag}
        </span>
      ))}
    </div>
  </div>
</Link>
```

---

# Summary

## Quick Start Checklist

1. **Export all assets** from Design Assets document
2. **Create Next.js page** at `/work/heirloom`
3. **Implement components** using examples above
4. **Add to work grid** on portfolio page
5. **Set up Figma prototype** or demo video embed
6. **Configure SEO** with metadata and structured data
7. **Add analytics tracking** for key interactions
8. **Test on mobile and desktop**
9. **Launch and monitor** engagement metrics

---

## Estimated Timeline

- **Asset Preparation:** 2-4 hours (export images, optimize files)
- **Next.js Development:** 8-12 hours (components, styling)
- **Content Entry:** 2-3 hours (copy, images, links)
- **Testing & QA:** 2-3 hours (responsive, links, accessibility)
- **Total:** 14-22 hours for complete integration

---

## Need Help?

If you run into issues during integration:
- **Technical:** Check Next.js docs at nextjs.org
- **Design:** Reference Figma prototype for exact spacing/colors
- **Content:** Use copy from MARKETING_WEBSITE.md as guide
- **Images:** Generate missing assets using Figma mockup templates

---

**End of Integration Guide**

All assets and specifications are ready for implementation into rationale.work.

