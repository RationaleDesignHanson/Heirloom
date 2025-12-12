# Heirloom: Complete Design Assets & Specifications

**Version:** 1.0
**Last Updated:** December 8, 2024

---

# Part 1: App Icon Design Specifications

## Overview

The Heirloom app icon should feel warm, nostalgic, and immediately convey "recipes" or "family cooking" without being literal or cliché. It must stand out on the iOS home screen while feeling cohesive with Apple's design language.

---

## Design Requirements

### Technical Specifications
- **Size:** 1024×1024px (App Store)
- **Format:** PNG with transparency (alpha channel)
- **Color Space:** sRGB
- **Corner Radius:** None (iOS applies automatically)
- **Safe Area:** Keep critical elements within center 80% (edges may be cropped)

### iOS Size Variants Required
- 1024×1024 - App Store
- 180×180 - iPhone (@3x)
- 120×120 - iPhone (@2x)
- 87×87 - iPad Pro (@3x)
- 80×80 - iPad (@2x)
- 76×76 - iPad (@1x)
- 60×60 - iPhone (@2x)
- 58×58 - Settings (@2x)
- 40×40 - Spotlight (@2x)
- 29×29 - Settings (@1x)

---

## Design Direction

### Concept A: Recipe Card (Recommended)

**Visual:**
- Stylized recipe card at slight angle (5-10° tilt)
- Warm cream background color
- Handwritten "Heirloom" text in script font
- Small tomato illustration in corner
- Subtle paper texture

**Colors:**
- Background: Cream (#FBF8F3)
- Text: Charcoal (#2D2D2D)
- Accent: Tomato Red (#E85D4D)

**Why It Works:**
- Immediately recognizable as recipe-related
- Warm, inviting, nostalgic
- Simple enough to read at small sizes
- Differentiates from competitors (most use food photos or utensils)

**Mockup Description:**
```
[Cream rectangle, rotated 8°]
"Heirloom" in Caveat font, centered
Small tomato icon in top-right corner
Subtle linen texture background
Drop shadow for depth
```

---

### Concept B: Tomato Monogram

**Visual:**
- Large stylized tomato with leaf
- "H" letter integrated into tomato shape
- Minimalist, clean lines
- Solid colors, no gradients

**Colors:**
- Tomato: Red (#E85D4D)
- Leaf: Sage Green (#8B9F8D)
- Background: Cream (#FBF8F3)

**Why It Works:**
- Bold, memorable
- Tomato = fresh, homemade, cooking
- "H" integration is clever
- Scales well

---

### Concept C: Kitchen Window

**Visual:**
- Simple window frame (cross pattern)
- View through window shows:
  - Cooking steam rising
  - Warm kitchen glow
  - Recipe card on counter (blurred background)
- Cozy, inviting aesthetic

**Colors:**
- Frame: Charcoal (#2D2D2D)
- Glow: Amber (#F4A460)
- Background: Cream (#FBF8F3)

**Why It Works:**
- Evokes nostalgia (looking into grandma's kitchen)
- Unique concept among recipe apps
- Warm, emotional connection

---

## Recommended Choice

**Concept A: Recipe Card** is the strongest option because:
1. Immediately communicates "recipes"
2. Warm, approachable, nostalgic
3. Simple enough for small sizes
4. Differentiates from competitors

---

## Design Deliverables

### For Designer

**Package:**
- 1024×1024 master file (PSD or AI with layers)
- All iOS size variants exported
- App icon JSON for Xcode (Contents.json)
- Alternative color versions (dark mode, monochrome)

**Timeline:**
- Concepts: 1 week (3 directions)
- Revisions: 3-5 days
- Final assets: 2 days
- **Total:** 2-3 weeks

**Cost:**
- Freelance designer: $500-1,500
- Agency: $2,000-5,000
- DIY with Figma/Sketch: $0 (time investment)

---

# Part 2: Device Mockup Specifications

## Overview

Device mockups are used for:
- App Store screenshots
- Marketing website hero images
- Social media promotional graphics
- Press kit materials

---

## Required Mockups

### iPhone 15 Pro (6.7")
**Uses:**
- Primary App Store screenshots
- Website hero section
- Social media posts

**Specs:**
- Resolution: 1290×2796 (actual iPhone resolution)
- Device Frame: Official Apple mockup PSD/Sketch
- Background: Transparent or white/cream
- Shadow: Subtle drop shadow (optional)

**Scenes to Mockup:**
1. Recipe grid (homepage)
2. Recipe detail view
3. Shopping list
4. Card customization screen
5. Dinner party timeline
6. Share sheet

---

### iPhone SE (Compact)
**Uses:**
- Secondary App Store screenshots
- Showing compatibility with smaller devices

**Specs:**
- Resolution: 750×1334
- Same scenes as iPhone 15 Pro

---

### iPad Pro 12.9"
**Uses:**
- Website (optional)
- Press kit
- Showing iPad optimization

**Specs:**
- Resolution: 2048×2732 (portrait) or 2732×2048 (landscape)
- Show multi-column layouts

---

### Apple Watch (Future)
**Uses:**
- Showing timer/grocery list on watch
- Press kit for future Watch app

---

## Mockup Sources

### Option A: Official Apple Resources
**Pros:**
- Highest quality
- Accurate device dimensions
- Official designs

**Cons:**
- Limited availability (Apple design resources site)
- May not have latest models immediately

**Link:** https://developer.apple.com/design/resources/

---

### Option B: Figma Community / Sketch Resources
**Pros:**
- Free, high-quality mockups
- Easy to customize
- Regularly updated

**Cons:**
- Requires Figma/Sketch
- Quality varies

**Search:** "iPhone 15 Pro mockup" on Figma Community

---

### Option C: Commercial Mockup Services
**Services:**
- Mockuphone.com (free, browser-based)
- Placeit.net ($29/month subscription)
- Smartmockups.com ($19/month)

**Pros:**
- Fast, no design skills needed
- Variety of angles and contexts

**Cons:**
- Subscription cost
- Less customization

---

## Mockup Scenes Required

### Scene 1: Recipe Grid
- 6 recipe cards visible
- Mix of styled cards (backgrounds, stickers)
- Search bar at top
- "+" button visible
- Warm, inviting composition

---

### Scene 2: Recipe Detail
- Full recipe visible
- Ingredients section expanded
- Photo at top
- "Add to Shopping List" button prominent
- Scroll hint (partial view of instructions)

---

### Scene 3: Shopping List
- Multiple categories visible (Produce, Dairy, Meat)
- Some items checked off
- "Export to Reminders" button
- Category icons visible

---

### Scene 4: Card Customization
- Recipe card in center
- Sticker picker at bottom (partial view)
- Background selector visible
- Drag-and-drop in action

---

### Scene 5: Dinner Party Timeline
- 3-4 recipes with start times
- "Cook Now" section visible
- Progress bar showing 40% complete
- Time until next recipe starts

---

### Scene 6: Share Sheet
- Styled recipe card preview
- iOS share sheet overlay
- Messages, Mail, AirDrop options visible

---

## Export Formats

### For App Store
- PNG @1x (actual device resolution)
- No device frame (Apple applies)
- Portrait orientation only

### For Website
- PNG @2x (high-DPI displays)
- Device frame included
- Transparent background or white/cream
- 2000-3000px wide (for hero sections)

### For Social Media
- 1200×630 (Facebook/Twitter OG)
- 1080×1080 (Instagram square)
- 1080×1920 (Instagram story)

---

# Part 3: Professional Photography Brief

## Overview

Professional photography brings warmth, authenticity, and emotional resonance to the Heirloom brand. Photos should feel like they could be from a family photo album—not sterile stock photos.

---

## Photo Styles

### Style Direction: Warm, Nostalgic, Analog

**Characteristics:**
- Natural lighting (golden hour preferred)
- Shallow depth of field (blurred backgrounds)
- Warm color grading (amber/cream tones)
- Slightly desaturated (not hyper-vibrant)
- Authentic, lived-in spaces (real kitchens, not studios)
- Hands in frame (showing cooking action)

**Avoid:**
- Sterile, clinical lighting
- Overly styled (doesn't look real)
- Empty, staged spaces
- Perfectly centered compositions (too formal)
- Food that looks fake or plastic

---

## Photo Categories

### Category 1: Hero Images (5 photos)

**Photo 1: Recipe Card on Kitchen Counter**
- Handwritten recipe card in foreground (sharp focus)
- Blurred kitchen background (warm, inviting)
- Natural light from window
- Coffee cup in background (optional)
- Wooden spoon or utensil visible

**Photo 2: Hands Holding iPhone with Heirloom App**
- Close-up of hands holding phone
- Heirloom recipe grid visible on screen
- Kitchen counter in background
- Natural skin tones (diverse representation)
- Warm, soft lighting

**Photo 3: Family Cooking Together**
- Multi-generational (grandmother, mother, child)
- Preparing a recipe together
- Flour on hands, apron visible
- Laughter, connection
- Kitchen in background (not overly styled)

**Photo 4: Dinner Table Set for Family Meal**
- Dishes on table, ready to serve
- Recipe card visible at place setting
- Candles lit (warm glow)
- Shallow DOF (foreground sharp, background soft)
- Inviting, cozy atmosphere

**Photo 5: Cookbook with Handwritten Notes**
- Vintage cookbook open on counter
- Handwritten notes visible in margins
- Stained, worn pages (shows use and love)
- Wooden spoon resting on page
- Natural light, warm tones

---

### Category 2: Lifestyle Context (3 photos)

**Photo 6: Grocery Shopping with iPhone**
- Person checking phone in grocery store aisle
- Produce visible in cart
- Natural expression (not posed)
- Shows app in real-world context

**Photo 7: Dinner Party Hosting**
- Host bringing dish to table
- Guests visible in background (out of focus)
- Warm, inviting lighting
- Captures social aspect of cooking

**Photo 8: Weekend Morning Baking**
- Person baking in kitchen (morning light)
- iPhone on counter with recipe open
- Flour, rolling pin, cookie cutters visible
- Cozy, relaxed atmosphere

---

### Category 3: Detail Shots (2 photos)

**Photo 9: Handwritten Recipe Card Close-Up**
- Extreme close-up of handwritten text
- Visible ink, paper texture
- Coffee stain ring (intentional)
- Warm, nostalgic lighting

**Photo 10: Ingredients Arranged**
- Overhead shot of recipe ingredients
- Tomatoes, garlic, herbs artfully arranged
- Recipe card in corner
- Rustic wooden surface

---

## Technical Requirements

### File Specs
- **Format:** RAW + JPEG (for editing)
- **Resolution:** Minimum 4000×3000px (12 megapixels)
- **Aspect Ratios:** 16:9, 4:3, 1:1 (crop variations)
- **Color Space:** sRGB for web, Adobe RGB for print

### Licensing
- **Usage Rights:** Unlimited, perpetual, worldwide
- **Exclusivity:** Exclusive to Heirloom (photographer cannot resell)
- **Model Releases:** Required for all identifiable people
- **Property Releases:** If shooting in private homes

---

## Photography Options

### Option A: Professional Photographer
**Cost:** $2,000-5,000 for full shoot (10 photos)
**Timeline:** 2-3 weeks (scheduling, shoot, editing)
**Pros:** Highest quality, art direction control, custom to brand
**Cons:** Expensive, time-consuming

---

### Option B: Stock Photography (Curated)
**Cost:** $100-500 for 10 high-quality images
**Sources:** Unsplash (free), Adobe Stock, Pexels
**Pros:** Fast, affordable, good enough quality
**Cons:** Not exclusive, may appear generic

---

### Option C: AI-Generated + Touchup
**Cost:** $100 (Midjourney sub) + $500 (designer touchup)
**Pros:** Fast, affordable, fully customizable
**Cons:** May look slightly artificial, ethical concerns

---

## Recommended Approach

**For Bootstrap Launch:**
- Use curated stock photography (Option B)
- Budget: $300 for 10 images
- Mix Unsplash (free) + Adobe Stock (premium)

**For Funded Launch:**
- Commission professional photographer (Option A)
- Budget: $3,500 for custom shoot
- Authentic, brand-aligned imagery

---

# Part 4: Click-Through Prototype Specification

## Overview

A click-through prototype demonstrates key features without requiring a working app. Perfect for:
- Investor pitches
- User testing before development
- Marketing website demos
- Press demos

---

## Tool Recommendation

**Figma with Interactive Components**

**Why Figma:**
- Industry standard for prototyping
- Easy to share (web link, no app required)
- Interactive components for realism
- Can export to video for marketing

**Alternative:** Framer (more advanced animations)

---

## Prototype Flow

### Screen 1: Recipe Grid (Home)
**Elements:**
- 6 recipe cards in 2×3 grid
- Search bar at top
- "+" button (floating action button)
- Tab bar: Recipes, Shopping, Parties, Settings

**Interactions:**
- Tap recipe card → Transition to Screen 2 (Recipe Detail)
- Tap "+" → Modal appears (Import menu)
- Tap "Shopping" tab → Transition to Screen 4 (Shopping List)

---

### Screen 2: Recipe Detail
**Elements:**
- Hero image at top
- Recipe title, source attribution
- Servings, prep time, cook time
- Ingredient list (expandable)
- Instructions (step-by-step)
- "Add to Shopping List" button
- "Customize Card" button

**Interactions:**
- Tap "Add to Shopping List" → Success toast appears
- Tap "Customize Card" → Transition to Screen 3 (Card Customization)
- Back button → Return to Screen 1

---

### Screen 3: Card Customization
**Elements:**
- Recipe card in center (editable)
- Background selector at bottom
- Sticker picker (scrollable)
- "Done" button

**Interactions:**
- Tap background → Card background changes
- Tap sticker → Sticker appears on card (draggable)
- Tap "Done" → Save animation, return to Screen 2

---

### Screen 4: Shopping List
**Elements:**
- Ingredient categories (Produce, Dairy, Meat)
- Checkbox for each ingredient
- "Export to Reminders" button

**Interactions:**
- Tap checkbox → Item strikes through
- Tap "Export to Reminders" → Success animation, modal closes
- Back button → Return to Screen 1

---

### Screen 5: Dinner Party Timeline
**Elements:**
- Party name and meal time
- Timeline with 4 recipes
- "Cook Now" section (1 recipe)
- "Coming Up" section (2 recipes)
- "Completed" section (1 recipe)
- Progress bar (25% complete)

**Interactions:**
- Tap recipe → Open recipe detail
- Back button → Return to Screen 1

---

## Prototype States

### Happy Path (Primary Flow)
1. Start on Home (Screen 1)
2. Tap recipe → View detail (Screen 2)
3. Tap "Customize Card" → Customize (Screen 3)
4. Add sticker, change background
5. Tap "Done" → Return to detail
6. Tap "Add to Shopping List" → Success
7. Navigate to Shopping List (Screen 4)
8. Export to Reminders → Success
9. End

**Duration:** ~60 seconds

---

### Feature Showcase (Extended Flow)
1. Start on Home
2. Show Recipe Import (URL paste → auto-parse)
3. Show Card Customization (multiple stickers, background)
4. Show Shopping List (multiple recipes combined)
5. Show Dinner Party Timeline
6. Show Share Flow (CloudKit)
7. End

**Duration:** ~90 seconds

---

## Animations & Transitions

### Transitions
- **Screen Changes:** Slide from right (iOS standard)
- **Modals:** Slide up from bottom
- **Toasts:** Fade in, slide down, auto-dismiss (2s)

### Micro-interactions
- **Button Press:** Scale down slightly (0.95), haptic feedback
- **Checkbox:** Checkmark animation, strikethrough
- **Sticker Drag:** Shadow increases, snap to grid on release
- **Background Change:** Fade transition (300ms)

---

## Export Formats

### For Website
- **Figma Embed:** Paste Figma prototype link on website
- **Video Recording:** Record prototype, export as MP4 (60fps, 1080p)
- **GIF:** Key interactions only (max 5MB for web)

### For Pitch Deck
- **Static Screenshots:** 6-8 key screens
- **Video Walkthrough:** 60-90 second demo video
- **Annotations:** Add arrows, callouts for clarity

---

## Timeline & Cost

### DIY in Figma (Recommended)
- **Time:** 20-30 hours (design + interactions)
- **Cost:** $0 (Figma free tier) or $12/month (professional)
- **Skills:** Basic Figma knowledge required

### Hire Designer
- **Time:** 1-2 weeks
- **Cost:** $1,500-3,000
- **Deliverables:** Figma file + video exports

---

## Testing Plan

### User Testing
**Participants:** 5-10 users (mix of demographics)
**Tasks:**
1. Import a recipe from a website
2. Add 2 recipes to shopping list and export
3. Customize a recipe card
4. Share a styled card

**Metrics:**
- Task completion rate (target: 90%+)
- Time to complete (target: <2 minutes per task)
- Confusion points (note where users get stuck)
- Feedback (qualitative insights)

---

## Handoff to Development

Once prototype is validated:
1. **Design Tokens:** Export colors, typography, spacing
2. **Component Specs:** Document all UI components
3. **Interaction Notes:** Annotate animations, gestures
4. **Assets:** Export icons, images at @1x, @2x, @3x
5. **Figma Inspect:** Enable dev mode for measurements

---

**End of Design Assets Document**

---

**Next:** Rationale Website Integration Guide

