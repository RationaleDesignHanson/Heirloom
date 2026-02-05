# Landing Pages Implementation Guide

> **Purpose:** Cursor prompts for building the heirloomrecipebox.app marketing site with Next.js, including landing variants, legal pages, and email capture.
>
> **Cross-references:**
> - URLs needed for App Store: See `02-app-store-submission.md` Section B
> - Creative assets: See `04-manual-tasks-and-creative.md` Section B

---

## Overview

### Site Structure

```
heirloomrecipebox.app/
├── /                    # Main landing page
├── /lp/video           # Video-to-recipe landing
├── /lp/scan            # Scan-to-recipe landing
├── /lp/generate        # AI generation landing
├── /lp/share           # Sharing landing
├── /privacy            # Privacy Policy
├── /terms              # Terms of Service
├── /support            # Support page (App Store requirement)
├── /community          # Discord/community guide
└── /presskit           # Press resources
```

### Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS
- **Deployment:** Netlify
- **Email:** TBD (Resend, ConvertKit, or simple form)
- **Analytics:** Plausible or Fathom (privacy-focused)

---

## Prompt 0: Repository Setup

### Cursor Prompt

```
Create a new Next.js project for the Heirloom marketing site:

1. Initialize Next.js with App Router:
   - TypeScript enabled
   - Tailwind CSS configured
   - ESLint enabled
   - src/ directory structure

2. Project structure:
   ```
   src/
   ├── app/
   │   ├── layout.tsx           # Root layout with fonts, metadata
   │   ├── page.tsx             # Home page
   │   ├── lp/
   │   │   ├── video/page.tsx
   │   │   ├── scan/page.tsx
   │   │   ├── generate/page.tsx
   │   │   └── share/page.tsx
   │   ├── privacy/page.tsx
   │   ├── terms/page.tsx
   │   ├── support/page.tsx
   │   ├── community/page.tsx
   │   └── presskit/page.tsx
   ├── components/
   │   ├── ui/                  # Reusable UI components
   │   ├── sections/            # Page sections
   │   └── layout/              # Layout components
   ├── config/
   │   └── site.ts              # Site configuration
   ├── lib/
   │   └── utils.ts             # Utility functions
   └── styles/
       └── globals.css          # Global styles + Tailwind
   ```

3. Configure Tailwind with Heirloom design tokens:
   - Colors: cream (#FAF5F0), tomato (#E05A3A), green (#4CAF50), charcoal (#2C2C2C)
   - Fonts: System fonts for now (SF Pro, -apple-system)
   - Spacing scale matching app

4. Create netlify.toml:
   ```toml
   [build]
     command = "npm run build"
     publish = ".next"

   [[plugins]]
     package = "@netlify/plugin-nextjs"

   [[redirects]]
     from = "/*"
     to = "/404"
     status = 404
   ```

5. SEO setup in root layout:
   - Default metadata with title template
   - Open Graph defaults
   - Twitter card defaults
   - Favicon configuration

6. Create placeholder image system:
   - public/images/placeholders/ directory
   - SVG placeholders for hero, features, screenshots
   - Named convention: placeholder-{name}.svg

7. Add .env.example with:
   ```
   NEXT_PUBLIC_SITE_URL=https://heirloomrecipebox.app
   NEXT_PUBLIC_APP_STORE_URL=https://apps.apple.com/app/heirloom/id0000000000
   ```

Initialize git repo, commit initial setup.
```

---

## Prompt 1: Landing Template (Golden Template)

### Cursor Prompt

```
Create the main landing page template at src/app/page.tsx with 8 reusable sections:

1. HERO SECTION
   - Full-width warm gradient background (cream to soft terracotta)
   - Headline: "Your recipes, finally organized"
   - Subhead: "Save from links, videos, and cookbooks in one tap. Private by default."
   - Primary CTA: "Download on the App Store" (App Store badge)
   - Secondary CTA: Email capture input with "Notify me" button
   - Hero image: iPhone mockup showing app (placeholder for now)
   - Subtle floating recipe card elements in background

2. PROBLEM/SOLUTION SECTION
   - "The problem" (scattered screenshots, bookmarks chaos)
   - "The solution" (organized recipe box visual)
   - Clean before/after or comparison layout

3. FEATURES GRID (3-4 features)
   - "Save from anywhere" with share extension visual
   - "Videos become recipes" with video import visual
   - "Scan any cookbook" with camera visual
   - "Share with intention" with P2P visual
   - Each: icon, title, description, optional image

4. HOW IT WORKS (3 steps)
   - Step 1: "Find a recipe"
   - Step 2: "Share to Heirloom"
   - Step 3: "It's yours forever"
   - Simple numbered steps with icons

5. SOCIAL PROOF (placeholder)
   - Quote section for testimonials
   - "Loved by X home cooks" (placeholder number)
   - Star rating visual

6. PRICING/CREDITS SECTION
   - "Free to start" emphasis
   - 25 daily credits explanation
   - Premium benefits ($5.99/mo or $39.99/yr)
   - Feature comparison table

7. FAQ SECTION
   - Expandable accordion
   - 5-6 common questions
   - Privacy/data questions included

8. FINAL CTA SECTION
   - Repeat App Store badge
   - Email capture
   - "Private by default. Your recipe box awaits."

Design system:
- Use CSS variables for colors
- Responsive: mobile-first
- Smooth scroll between sections
- Subtle animations on scroll (fade-in)
- All images use next/image with placeholder

Components to create:
- src/components/ui/Button.tsx
- src/components/ui/Input.tsx
- src/components/ui/Badge.tsx
- src/components/sections/Hero.tsx
- src/components/sections/Features.tsx
- src/components/sections/HowItWorks.tsx
- src/components/sections/Pricing.tsx
- src/components/sections/FAQ.tsx
- src/components/sections/CTA.tsx
- src/components/layout/Header.tsx
- src/components/layout/Footer.tsx
```

---

## Prompt 2: Landing Page Variants

### Cursor Prompt

```
Create 4 landing page variants that reuse components but customize for specific use cases:

1. /lp/video - Video-to-Recipe Landing
   - Hero focuses on video import
   - Headline: "Turn cooking videos into recipes"
   - Subhead: "TikTok, Instagram, YouTube—extract any recipe in seconds"
   - Hero shows video thumbnail → recipe card transformation
   - Features: video platforms supported, how extraction works, example results
   - FAQ focused on video import questions

2. /lp/scan - Scan-to-Recipe Landing
   - Hero focuses on cookbook scanning
   - Headline: "Digitize your cookbooks"
   - Subhead: "Point your camera at any recipe. Instant digital copy."
   - Hero shows cookbook page → clean recipe card
   - Features: accuracy, handwritten support, page detection
   - FAQ focused on scanning questions

3. /lp/generate - AI Generation Landing
   - Hero focuses on AI recipe creation
   - Headline: "Tell us what you have. Get a recipe."
   - Subhead: "Describe ingredients or a craving. AI creates the perfect recipe."
   - Hero shows text input → recipe output
   - Features: ingredient-based, cuisine styles, dietary preferences
   - FAQ focused on AI generation questions

4. /lp/share - Sharing Landing
   - Hero focuses on recipe sharing
   - Headline: "Share recipes that stick"
   - Subhead: "Send to friends and family. They'll have it forever—organized."
   - Hero shows send/receive flow
   - Features: P2P sharing, no account needed to receive, stays organized
   - FAQ focused on sharing/privacy questions

Implementation:
- Create src/app/lp/layout.tsx for shared LP layout
- Each variant page imports shared components
- Customize Hero, Features based on variant
- Reuse Pricing, FAQ (with variant-specific questions), CTA
- Add UTM tracking support via searchParams
- Set unique metadata/OG for each variant
```

---

## Prompt 3: Support & Community Pages

### Cursor Prompt

```
Create support and community pages:

1. /support - Support Page (App Store requirement)
   Location: src/app/support/page.tsx

   Content:
   - Header: "How can we help?"
   - Search bar (can be placeholder initially)

   - FAQ section (expandable):
     - "How do I save a recipe from a website?"
     - "Why did my video import fail?"
     - "How do I share a recipe with someone?"
     - "Can I use Heirloom offline?"
     - "How do I cancel my subscription?"
     - "How do I delete my account?"

   - Contact section:
     - Email: support@heirloomrecipebox.app
     - Response time: "Usually within 24 hours"
     - Bug report form (simple: email, description, optional screenshot)

   - Quick links:
     - Privacy Policy
     - Terms of Service
     - App Store page

2. /community - Community Page
   Location: src/app/community/page.tsx

   Content:
   - Header: "Join the Heirloom community"

   - Discord section:
     - Discord invite link (placeholder)
     - What to expect: recipe sharing, feature requests, cooking tips
     - Community guidelines summary

   - Social links:
     - Instagram: @heirloomrecipes
     - TikTok: @heirloomrecipes
     - Twitter/X: @heirloomapp

   - Feature requests:
     - "Have an idea? We'd love to hear it"
     - Link to feedback form or Discord channel

   - Newsletter signup:
     - "Get cooking tips and updates"
     - Email input + subscribe button

Design:
- Match main site styling
- Mobile-friendly
- Simple, scannable layout
```

---

## Prompt 4: Privacy & Terms Pages (MDX)

### Cursor Prompt

```
Create Privacy Policy and Terms of Service pages using MDX:

1. Set up MDX support:
   - Install @next/mdx and related packages
   - Configure next.config.js for MDX
   - Create MDX components for styling (headings, lists, links)

2. /privacy - Privacy Policy
   Location: src/app/privacy/page.tsx (renders MDX)
   Content file: src/content/privacy.mdx

   Structure:
   - Last updated date
   - Introduction (what Heirloom is, commitment to privacy)
   - Information We Collect:
     - Account information (email, name)
     - Recipe data (titles, ingredients, photos)
     - Usage data (features used, errors)
     - Device information (for support)
   - How We Use Information:
     - Provide the service
     - Improve the app
     - Send important updates
     - NOT for advertising or selling
   - Information Sharing:
     - Third-party processors list:
       - Firebase (Google) - authentication, storage
       - OpenAI - recipe extraction (not stored)
       - RevenueCat - subscription management
       - Mixpanel - analytics (can be disabled)
     - Legal requirements
     - With your consent only
   - Data Security:
     - Encryption in transit (HTTPS)
     - Secure storage (Firebase)
     - Access controls
   - Your Rights:
     - Access your data
     - Export your data
     - Delete your data
     - Opt out of analytics
   - Children's Privacy (no under-13 accounts)
   - International Users (data may be processed in US)
   - Changes to Policy
   - Contact: privacy@heirloomrecipebox.app

3. /terms - Terms of Service
   Location: src/app/terms/page.tsx
   Content file: src/content/terms.mdx

   Structure:
   - Last updated date
   - Acceptance of Terms
   - Description of Service
   - Account Registration
   - User Content:
     - You own your recipes
     - License grant for service operation
     - Public sharing responsibilities
     - Prohibited content
   - Intellectual Property
   - Subscription & Payments:
     - Pricing ($5.99/mo, $39.99/yr)
     - Free tier limitations
     - Billing through Apple
     - Cancellation policy
     - Refunds (through Apple)
   - Termination
   - Disclaimers
   - Limitation of Liability
   - Governing Law
   - Changes to Terms
   - Contact: legal@heirloomrecipebox.app

Styling:
- Clean typography for readability
- Proper heading hierarchy
- Anchor links for sections
- Print-friendly
- Last updated prominently displayed
```

---

## Prompt 5: Placeholder Imagery Generator

### Cursor Prompt

```
Create a placeholder image generation system for development:

1. Create placeholder SVG templates:
   Location: src/lib/placeholders.ts

   Function to generate SVG data URIs:
   ```typescript
   export function generatePlaceholder(
     width: number,
     height: number,
     label: string,
     variant: 'hero' | 'feature' | 'screenshot' | 'icon'
   ): string
   ```

2. Placeholder styles:
   - Warm gradient background (cream → terracotta)
   - Ceramic speckle texture overlay (CSS pattern)
   - Centered label text
   - Rounded corners
   - Subtle shadow

3. Create React component:
   Location: src/components/ui/Placeholder.tsx

   Props:
   - width, height
   - label (text to display)
   - variant (determines colors/style)
   - className (for additional styling)

4. Pre-made placeholders for common uses:
   - placeholder-hero.svg (1200x800)
   - placeholder-iphone.svg (390x844 - iPhone frame)
   - placeholder-feature.svg (600x400)
   - placeholder-icon.svg (64x64)
   - placeholder-screenshot.svg (1290x2796)

5. Usage example:
   ```tsx
   <Placeholder
     width={600}
     height={400}
     label="Video Import Feature"
     variant="feature"
   />
   ```

6. CSS for ceramic speckle effect:
   ```css
   .ceramic-texture {
     background-image: url("data:image/svg+xml,...");
     /* or CSS noise filter */
   }
   ```

This allows development to proceed without final images.
```

---

## Prompt 6: Email Capture System

### Cursor Prompt

```
Implement email capture for launch notifications:

1. Create email capture component:
   Location: src/components/ui/EmailCapture.tsx

   Features:
   - Email input with validation
   - Submit button with loading state
   - Success message after submission
   - Error handling
   - Honeypot field for spam prevention

   UI:
   - Inline form (input + button side by side)
   - Or stacked for mobile
   - Subtle styling matching site design
   - "We'll notify you when we launch" microcopy

2. API route for submissions:
   Location: src/app/api/subscribe/route.ts

   Features:
   - Email validation
   - Honeypot check (reject if filled)
   - Rate limiting (by IP, max 5/hour)
   - Store in simple solution:
     - Option A: Netlify Forms (built-in)
     - Option B: Google Sheets via API
     - Option C: Simple JSON file (for MVP)
     - Option D: Resend/ConvertKit integration

3. Rate limiting implementation:
   - Use Netlify Edge Functions or
   - Simple in-memory store with cleanup

4. Form validation:
   - Client-side: email format
   - Server-side: email format, honeypot, rate limit

5. Success/error states:
   - Success: "Thanks! We'll be in touch."
   - Already subscribed: "You're already on the list!"
   - Rate limited: "Too many requests. Try again later."
   - Error: "Something went wrong. Please try again."

6. Privacy considerations:
   - GDPR consent checkbox if needed
   - Link to privacy policy
   - Clear what emails they'll receive

7. Integration points:
   - Hero section (primary)
   - Final CTA section (secondary)
   - Support page (newsletter)

No complex email service needed initially - just collect emails for manual outreach at launch.
```

---

## Prompt 7: Site Configuration File

### Cursor Prompt

```
Create a centralized configuration file for all site constants:

Location: src/config/site.ts

```typescript
export const siteConfig = {
  // Basic info
  name: 'Heirloom',
  tagline: 'Your recipes, finally organized',
  description: 'Save recipes from links, videos, and cookbooks in one tap. Private by default.',

  // URLs
  url: process.env.NEXT_PUBLIC_SITE_URL || 'https://heirloomrecipebox.app',
  appStoreUrl: process.env.NEXT_PUBLIC_APP_STORE_URL || '#',

  // Contact
  email: {
    support: 'support@heirloomrecipebox.app',
    press: 'press@heirloomrecipebox.app',
    privacy: 'privacy@heirloomrecipebox.app',
    legal: 'legal@heirloomrecipebox.app',
    general: 'hello@heirloomrecipebox.app',
  },

  // Social
  social: {
    twitter: 'https://twitter.com/heirloomapp',
    instagram: 'https://instagram.com/heirloomrecipes',
    tiktok: 'https://tiktok.com/@heirloomrecipes',
    discord: '#', // Placeholder
  },

  // Legal
  legal: {
    companyName: 'Rationale Design Limited Licensing Corporation',
    copyright: `© ${new Date().getFullYear()} Rationale Design Limited Licensing Corporation`,
  },

  // Pricing (display values)
  pricing: {
    monthly: '$5.99',
    annual: '$39.99',
    annualMonthly: '$3.33', // $39.99/12
    savings: '44%',
    trialDays: 14,
    freeCredits: 25,
  },

  // Features list (for landing pages)
  features: [
    {
      id: 'save-anywhere',
      title: 'Save from anywhere',
      description: 'Paste a link, share from Safari, or scan a cookbook page.',
      icon: 'share',
    },
    {
      id: 'video-import',
      title: 'Videos become recipes',
      description: 'Extract recipes from TikTok, Instagram, and YouTube.',
      icon: 'video',
    },
    {
      id: 'scan',
      title: 'Scan any cookbook',
      description: 'Point your camera at any recipe page. Done.',
      icon: 'camera',
    },
    {
      id: 'share',
      title: 'Share with intention',
      description: 'Send to friends and family. Private by default.',
      icon: 'heart',
    },
  ],

  // FAQ items
  faq: [
    {
      question: 'Is Heirloom really free?',
      answer: 'Yes! You get 25 free credits daily to save recipes. Manual entry is always free. Premium unlocks unlimited saves and advanced features.',
    },
    {
      question: 'What happens to my recipes if I cancel Premium?',
      answer: 'Your recipes are yours forever. You keep everything. You just return to the daily credit limit for new saves.',
    },
    // ... more FAQ items
  ],

  // SEO defaults
  seo: {
    titleTemplate: '%s | Heirloom',
    defaultTitle: 'Heirloom - Your recipes, finally organized',
    defaultDescription: 'Save recipes from links, videos, and cookbooks in one tap. Private by default.',
    ogImage: '/images/og-default.png',
  },
}

export type SiteConfig = typeof siteConfig
```

Usage:
```tsx
import { siteConfig } from '@/config/site'

// In components:
<a href={siteConfig.appStoreUrl}>Download</a>
<p>{siteConfig.pricing.monthly}/month</p>
```
```

---

## Post-Prompt Checklist

### After Building Landing Pages

1. **Update App Store Connect URLs:**
   - Privacy Policy: https://heirloomrecipebox.app/privacy
   - Terms of Service: https://heirloomrecipebox.app/terms
   - Support URL: https://heirloomrecipebox.app/support
   - Marketing URL: https://heirloomrecipebox.app

2. **Configure DNS:**
   - Point heirloomrecipebox.app to Netlify
   - Set up www redirect
   - Enable HTTPS (automatic with Netlify)

3. **Set up Analytics:**
   - Add Plausible or Fathom script
   - Configure custom events for:
     - App Store clicks
     - Email signups
     - Landing variant views

4. **Test All Pages:**
   - Mobile responsiveness
   - All links work
   - Forms submit correctly
   - Images load (or placeholders show)
   - Legal pages are complete

5. **SEO Verification:**
   - Meta tags present
   - OG images configured
   - Sitemap generated
   - robots.txt configured

---

## Pre-Paste Checklist

Before copying these prompts to Cursor, verify:

- [ ] Node.js installed (v18+)
- [ ] Netlify account created
- [ ] Domain registered (heirloomrecipebox.app)
- [ ] DNS access available
- [ ] Basic familiarity with Next.js
- [ ] Tailwind CSS understanding
- [ ] Final copy ready for legal pages (or placeholders OK)

---

## Deployment Checklist

### Before Going Live

- [ ] All placeholder images replaced (or acceptable)
- [ ] Privacy policy content finalized
- [ ] Terms of service content finalized
- [ ] Support page content complete
- [ ] Email capture working
- [ ] App Store URL ready (or placeholder acceptable)
- [ ] DNS configured and propagated
- [ ] HTTPS working
- [ ] Mobile testing complete
- [ ] Load testing passed
- [ ] Analytics configured
- [ ] 404 page styled

### After Deployment

- [ ] Verify all URLs accessible
- [ ] Test email signup flow
- [ ] Verify in App Store Connect (URLs resolve)
- [ ] Share preview links for final review
- [ ] Set up monitoring/uptime alerts
