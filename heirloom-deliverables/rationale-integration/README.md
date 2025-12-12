# Heirloom Case Study - Rationale Website Integration

**Ready to Deploy:** Complete Next.js implementation
**Interactive Prototypes:** 2 working demos (Card Customization + Shopping List)
**Status:** Ready for `/work/heirloom` integration

---

## 📦 Package Contents

```
rationale-integration/
├── page.tsx                          # Main case study page
├── components/
│   ├── HeroSection.tsx              # Hero with device mockup ✅
│   ├── ProjectOverview.tsx          # Overview + metrics ✅
│   ├── ChallengeSection.tsx         # Problem/opportunity ✅
│   ├── ApproachSection.tsx          # 3 core principles ✅
│   ├── FeatureGrid.tsx              # 6 key features ✅
│   ├── PrototypeEmbed-Updated.tsx   # Tab-based interactive demos ✅
│   ├── FinalCTA.tsx                 # Work with us CTA ✅
│   └── _StubComponents.tsx          # Stub sections to expand
├── prototypes/
│   ├── CardCustomizationDemo.tsx    # Interactive card customization ✅
│   └── ShoppingListDemo.tsx         # Interactive shopping list ✅
└── README.md                         # This file
```

---

## 🚀 Quick Start (5 Steps)

### Step 1: Copy Files to Rationale Project

```bash
# From this directory
cp -r rationale-integration/* ~/rationale-public/app/work/heirloom/
```

**File Structure:**
```
rationale-public/
└── app/
    └── work/
        └── heirloom/
            ├── page.tsx
            ├── components/
            │   └── [all component files]
            └── prototypes/
                └── [interactive demos]
```

---

### Step 2: Add Required Dependencies

Check if you need to add these fonts to your project:

**In `app/layout.tsx` or global CSS:**
```tsx
import { Caveat } from 'next/font/google'

const caveat = Caveat({ subsets: ['latin'], variable: '--font-caveat' })

// In <html> tag:
<html className={caveat.variable}>
```

**Or in CSS:**
```css
@import url('https://fonts.googleapis.com/css2?family=Caveat:wght@400;700&display=swap');
```

---

### Step 3: Update PrototypeEmbed Component

Replace the original `PrototypeEmbed.tsx` with `PrototypeEmbed-Updated.tsx`:

```bash
mv app/work/heirloom/components/PrototypeEmbed-Updated.tsx \
   app/work/heirloom/components/PrototypeEmbed.tsx
```

---

### Step 4: Add to Work Portfolio Grid

**In `app/work/page.tsx` (or wherever your work grid is):**

```tsx
const projects = [
  // ... existing projects
  {
    id: 'heirloom',
    title: 'Heirloom',
    subtitle: 'iOS Recipe App',
    description: 'Native app for preserving family recipes with smart shopping lists and card personalization.',
    image: '/images/work/heirloom/thumbnail.png',
    tags: ['iOS', 'Product Design', 'Native App', 'SwiftUI'],
    href: '/work/heirloom',
    year: 2025,
    featured: true, // if you have featured projects
  },
]
```

---

### Step 5: Add Images (Placeholders Provided)

**Required images to add:**

```
public/images/work/heirloom/
├── hero-mockup.png           # iPhone with app (2400×1600)
├── og-image.png              # OpenGraph card (1200×630)
├── twitter-card.png          # Twitter card (1200×675)
├── thumbnail.png             # Work grid thumbnail (600×400)
└── feature-*.png             # Optional feature screenshots
```

**Placeholder paths are already in components - just drop images in.**

---

## 🎨 Interactive Prototypes

### What's Included

**1. Card Customization Demo** (`CardCustomizationDemo.tsx`)
- ✅ Choose background colors (4 options)
- ✅ Add stickers (6 emoji stickers)
- ✅ Write handwritten annotations
- ✅ Click stickers to remove
- ✅ Fully responsive

**2. Shopping List Demo** (`ShoppingListDemo.tsx`)
- ✅ Select multiple recipes
- ✅ Auto-aggregate ingredients
- ✅ Organize by grocery aisle
- ✅ Show which recipes use each ingredient
- ✅ Interactive checkboxes

### How They Work

Both prototypes are **pure React/Next.js** - no external dependencies, no Figma embeds. They work instantly and are fast.

**Key Features:**
- Client-side only (`'use client'`)
- No API calls required
- Mobile responsive
- Tailwind CSS styled (matches your design system)

---

## 🎯 What to Customize

### 1. Update Links

**In `page.tsx` and `FinalCTA.tsx`:**
```tsx
// Update these URLs:
'https://heirloomapp.com'  // Replace with actual domain when ready
'/contact'                  // Update if your contact page is elsewhere
'/work'                     // Update if your work page is elsewhere
```

### 2. Add Real Images

**Priority Order:**
1. **Hero mockup** (`hero-mockup.png`) - Most important, shows first
2. **OG image** (`og-image.png`) - For social sharing
3. **Thumbnail** (`thumbnail.png`) - For work grid
4. **Feature screenshots** - Optional, can add later

**Recommended Tool for Mockups:**
- Figma with iPhone frame templates
- https://mockuphone.com (free, browser-based)
- Placeit.net (subscription, very fast)

### 3. Expand Stub Sections

**In `_StubComponents.tsx`:**

Fill in these sections with actual content from `MARKETING_WEBSITE.md`:
- `DesignSystem` - Add color palette, typography, components
- `TechnicalStack` - Add architecture diagram and tech list
- `Timeline` - Add 5-week development timeline
- `Outcomes` - Add metrics and results
- `LessonsLearned` - Add 3-column lessons

**Template for each:**
```tsx
export function DesignSystem() {
  return (
    <section className="bg-white py-20 md:py-28">
      <div className="container mx-auto px-6 md:px-12 lg:px-16">
        <h2 className="mb-12 text-4xl font-bold text-[#2D2D2D] md:text-5xl">
          Design System
        </h2>

        {/* Your content here */}
        <div className="grid gap-8 md:grid-cols-3">
          {/* Color palette */}
          {/* Typography scale */}
          {/* Component examples */}
        </div>
      </div>
    </section>
  )
}
```

---

## 🌈 Tailwind Color Tokens

**Heirloom Brand Colors** (used throughout components):

```js
// Add to tailwind.config.js if you want semantic names:
module.exports = {
  theme: {
    extend: {
      colors: {
        heirloom: {
          cream: '#FBF8F3',
          tomato: '#E85D4D',
          amber: '#F4A460',
          sage: '#8B9F8D',
          charcoal: '#2D2D2D',
        },
      },
    },
  },
}
```

**Or use hex values directly** (current approach in components).

---

## 📱 Responsive Design

All components are mobile-first and responsive:

- **Mobile (< 768px):** Single column, stacked layout
- **Tablet (768px - 1024px):** 2-column grids
- **Desktop (> 1024px):** Full 3-column layouts

**Test on:**
- iPhone (375px width)
- iPad (768px width)
- Desktop (1280px+ width)

---

## 🔍 SEO Optimized

**Already included in `page.tsx`:**
- ✅ Meta title and description
- ✅ OpenGraph tags (Facebook, LinkedIn)
- ✅ Twitter Card tags
- ✅ JSON-LD structured data
- ✅ Semantic HTML5

**To verify:**
```bash
# Check meta tags
curl https://rationale.work/work/heirloom | grep "<meta"

# Test social cards
# Facebook: https://developers.facebook.com/tools/debug/
# Twitter: https://cards-dev.twitter.com/validator
# LinkedIn: https://www.linkedin.com/post-inspector/
```

---

## 🎭 Interactive Demo Features

### Card Customization Demo

**What Users Can Do:**
1. Select background (4 colors with textures)
2. Click stickers to add them (random position)
3. Click placed stickers to remove
4. Type handwritten notes
5. See real-time updates

**Limitations:**
- Stickers placed at random (not draggable)
- Fixed sticker set (6 emojis)
- Text annotations (not truly handwritten)

**Future Enhancements:**
- Add drag-and-drop for stickers
- Expand sticker library (use actual designs)
- Add sticker rotation/resize
- Add more backgrounds

### Shopping List Demo

**What Users Can Do:**
1. Select 2-3 recipes
2. Generate aggregated shopping list
3. See intelligent ingredient combining (e.g., "garlic" from all recipes)
4. See automatic aisle categorization
5. See which recipes use each ingredient

**Limitations:**
- Simple keyword matching (not full NLP)
- Fixed recipe set (3 recipes)
- No actual Reminders export

**Future Enhancements:**
- Better ingredient parsing algorithm
- User-added custom recipes
- Export to actual iOS Reminders (requires native)
- Quantity aggregation (2 cups + 1 cup = 3 cups)

---

## 🧪 Testing Checklist

Before going live:

**Functional:**
- [ ] All internal links work (`/contact`, `/work`)
- [ ] External link to heirloomapp.com works (or update when ready)
- [ ] Both prototypes render correctly
- [ ] Prototype tabs switch smoothly
- [ ] Mobile navigation works
- [ ] Images load (or placeholders show)

**Visual:**
- [ ] Hero section looks good on mobile
- [ ] Feature grid aligns properly
- [ ] Prototypes are centered and responsive
- [ ] CTAs are prominent and clickable
- [ ] Colors match Rationale brand (or intentionally differ)

**Performance:**
- [ ] Page loads in < 2 seconds
- [ ] Images are optimized (WebP if possible)
- [ ] No console errors
- [ ] Lighthouse score > 90

---

## 📊 Analytics Tracking

**Recommended events to track:**

```tsx
// Example with Plausible or Google Analytics

// Track CTA clicks
const handleCTAClick = (label: string) => {
  if (window.plausible) {
    window.plausible('CTA Click', { props: { label } })
  }
  // Navigate...
}

// Track prototype interactions
const handlePrototypeSwitch = (demo: string) => {
  if (window.plausible) {
    window.plausible('Prototype Switch', { props: { demo } })
  }
  setActiveDemo(demo)
}
```

**Key metrics:**
- Page views on `/work/heirloom`
- Time on page (target: >3 minutes)
- CTA click-through rate (target: >15%)
- Prototype engagement (target: >30% interact)
- "Work With Us" button clicks

---

## 🚧 Next Steps

### Immediate (This Week)
1. ✅ Copy files to Rationale project
2. ⏳ Add placeholder images (or real ones if ready)
3. ⏳ Update links (`heirloomapp.com` → actual domain)
4. ⏳ Test on localhost
5. ⏳ Deploy to staging

### Short-Term (Next 2 Weeks)
6. ⏳ Capture real iPhone screenshots
7. ⏳ Generate OG images (social cards)
8. ⏳ Expand stub sections (Design System, Timeline, etc.)
9. ⏳ Add to work portfolio grid
10. ⏳ Set up analytics tracking

### Long-Term (When Heirloom Launches)
11. ⏳ Update "In Development" badge to "Live in App Store"
12. ⏳ Add App Store link and badge
13. ⏳ Update metrics with real data (downloads, ratings)
14. ⏳ Add user testimonials/reviews
15. ⏳ Create video walkthrough (optional)

---

## 💡 Tips & Best Practices

### Image Optimization

```bash
# Optimize PNGs
pngquant --quality=80-90 --speed 1 input.png -o output.png

# Convert to WebP (Next.js does this automatically)
cwebp -q 85 input.png -o output.webp

# Or use Next.js Image component (already used everywhere)
<Image src="/path" width={600} height={400} alt="..." />
```

### Performance

**Current setup is already optimized:**
- ✅ Client components only where needed (`'use client'`)
- ✅ Server components by default (faster)
- ✅ Next.js Image for automatic optimization
- ✅ CSS-in-JS via Tailwind (no runtime cost)

**If you add more features:**
- Use dynamic imports for heavy components
- Lazy load images below the fold
- Consider skeleton loaders for demos

### Accessibility

**Already included:**
- ✅ Semantic HTML5 (`<section>`, `<h1>-<h6>`, `<nav>`)
- ✅ ARIA labels where needed
- ✅ Keyboard navigation support
- ✅ Focus states on all interactive elements
- ✅ Color contrast meets WCAG AA

**To verify:**
- Run Lighthouse audit
- Test with VoiceOver (Mac) or NVDA (Windows)
- Check color contrast with WebAIM tool

---

## 🐛 Troubleshooting

### "Module not found" errors

**If you see:**
```
Module not found: Can't resolve '../components/HeroSection'
```

**Fix:** Check file paths are correct relative to `page.tsx`.

---

### Tailwind classes not working

**If styles don't apply:**

1. Ensure Tailwind is configured in your project
2. Check `tailwind.config.js` includes the new paths:

```js
content: [
  './app/**/*.{js,ts,jsx,tsx,mdx}',
  './app/work/heirloom/**/*.{js,ts,jsx,tsx}', // Add this
],
```

3. Restart dev server after config changes

---

### Fonts not loading (Caveat)

**If handwritten annotations look wrong:**

1. Add Caveat font to your `layout.tsx`
2. Or use CSS import in global styles
3. Or fall back to `cursive` generic font

---

### Images not showing

**Placeholders included in code:**

All image paths have fallbacks:
```tsx
// If image doesn't exist, shows placeholder with text
<Image src="/images/work/heirloom/hero-mockup.png" ... />
// Falls back gracefully if missing
```

---

## 📞 Support

**Questions about integration?**
- Check `RATIONALE_INTEGRATION_GUIDE.md` for detailed instructions
- Review `MARKETING_WEBSITE.md` for content guidance
- Look at `DESIGN_ASSETS_COMPLETE.md` for design specs

**Need help with:**
- Image generation → Use mockup tools (mockuphone.com)
- Component customization → Tailwind docs (tailwindcss.com)
- Next.js questions → Next.js docs (nextjs.org)

---

## ✅ Launch Checklist

**Before going live:**

- [ ] All components render without errors
- [ ] Links updated (heirloomapp.com, /contact, /work)
- [ ] Images added (at least hero mockup + OG image)
- [ ] Mobile responsive tested
- [ ] SEO meta tags verified
- [ ] Analytics tracking configured
- [ ] Added to work portfolio grid
- [ ] Lighthouse score > 90
- [ ] Cross-browser tested (Chrome, Safari, Firefox)
- [ ] Shared on Rationale social media

---

## 🎉 You're Done!

Your Heirloom case study is ready to showcase on Rationale's website with working interactive prototypes.

**What you have:**
- ✅ Complete Next.js page structure
- ✅ 7 finished components + 5 stubs
- ✅ 2 interactive prototypes (no Figma needed!)
- ✅ SEO optimized
- ✅ Mobile responsive
- ✅ Fast and accessible

**Next:** Drop in images, deploy to staging, and test!

