# Manual Tasks & Creative Assets

> **Purpose:** Detailed instructions for screenshots, AI image generation, design templates, and all manual pre-launch tasks.
>
> **Cross-references:**
> - Screenshot usage: See `02-app-store-submission.md` Section G
> - Onboarding captures: See `01-app-onboarding-changes.md`
> - Landing page images: See `03-landing-pages.md`

---

## A. App Screenshots to Capture (23 captures)

> **Master Usage Map:** See `05-video-creative-production.md` **Section E** for a comprehensive table showing where each capture is used across screenshots, video, and landing pages.

### Capture Environment Setup

**Device:** iPhone 15 Pro Max Simulator (or physical device)
**Mode:** Light Mode
**Time:** 9:41 AM (Apple convention)
**Battery:** 100% / Full
**Carrier:** Hidden or "Carrier"
**WiFi:** Full signal
**Notifications:** Do Not Disturb enabled

### Capture Instructions

For each capture:
1. Set up the exact app state described
2. Use Cmd+S in Simulator to capture (or physical screenshot)
3. Save with the specified filename
4. Note any issues for later

---

### CAP_01: Onboarding Welcome Screen

**Filename:** `CAP_01_ONBOARDING_WELCOME.png`
**App State:** First onboarding screen after fresh install
**Setup Steps:**
1. Delete app and reinstall (or reset UserDefaults)
2. Launch app
3. Wait for animations to complete
4. Capture

**Used In:** SS_01 (possibly), Landing hero

---

### CAP_02: Onboarding Credits Screen

**Filename:** `CAP_02_ONBOARDING_CREDITS.png`
**App State:** Screen 2/5 showing credit meter
**Setup Steps:**
1. From CAP_01, tap "Continue"
2. Wait for credit meter animation
3. Capture with meter showing 25/25

**Used In:** SS_10

---

### CAP_02B: Credits Modal

**Filename:** `CAP_02B_CREDITS_MODAL.png`
**App State:** "How credits work" modal open
**Setup Steps:**
1. From CAP_02 screen, tap "How credits work" link
2. Wait for modal to appear
3. Capture

**Used In:** Internal reference

---

### CAP_03: iOS Share Sheet with Heirloom

**Filename:** `CAP_03_SHARE_SHEET.png`
**App State:** Safari showing recipe, share sheet open with Heirloom visible
**Setup Steps:**
1. Open Safari in Simulator
2. Navigate to a recipe website (e.g., seriouseats.com)
3. Tap Share button
4. Ensure Heirloom icon is visible (may need to enable in More)
5. Capture share sheet

**Used In:** SS_02, Onboarding mockup

---

### CAP_03B: Import Progress

**Filename:** `CAP_03B_IMPORT_PROGRESS.png`
**App State:** Recipe import in progress
**Setup Steps:**
1. From share sheet, tap Heirloom
2. Capture during loading/extraction phase
3. Should show progress indicator

**Used In:** Onboarding animation

---

### CAP_03C: Saved Toast

**Filename:** `CAP_03C_SAVED_TOAST.png`
**App State:** "Saved to [Collection]" success toast
**Setup Steps:**
1. Complete a recipe save
2. Capture immediately when toast appears
3. Should show collection name

**Used In:** SS_02, Onboarding

---

### CAP_04: Share Send Flow

**Filename:** `CAP_04_SHARE_SEND.png`
**App State:** Sending a recipe to a friend
**Setup Steps:**
1. Open any recipe
2. Tap Share → "Send to Friend"
3. Enter a sample email
4. Capture before sending

**Used In:** SS_07

---

### CAP_04B: Accept Sheet (Recipient View)

**Filename:** `CAP_04B_ACCEPT_SHEET.png`
**App State:** Recipient's accept recipe sheet
**Setup Steps:**
1. Send a recipe from one account
2. Open accept link on different device/account
3. Capture the accept confirmation sheet

**Used In:** SS_07, Onboarding

---

### CAP_04C: Added Success

**Filename:** `CAP_04C_ADDED_SUCCESS.png`
**App State:** "Added to your recipe box" success
**Setup Steps:**
1. Accept a shared recipe
2. Capture success confirmation

**Used In:** Onboarding

---

### CAP_05: Visibility Pills

**Filename:** `CAP_05_VISIBILITY_PILLS.png`
**App State:** Privacy screen showing Private/Shared/Public pills
**Setup Steps:**
1. Navigate to onboarding screen 5/5
2. Or: Recipe privacy settings if implemented
3. Capture showing all three options

**Used In:** SS_08

---

### CAP_05B: Private Pill Selected

**Filename:** `CAP_05B_PILL_PRIVATE.png`
**App State:** Private option highlighted/selected
**Setup Steps:**
1. From visibility pills screen
2. Ensure "Private" is selected/filled
3. Capture

**Used In:** Privacy explanation

---

### CAP_05C: Public Pill Selected

**Filename:** `CAP_05C_PILL_PUBLIC.png`
**App State:** Public option highlighted/selected
**Setup Steps:**
1. From visibility pills screen
2. Select "Public" option
3. Capture

**Used In:** Privacy explanation

---

### CAP_06: Quick Start Screen

**Filename:** `CAP_06_QUICK_START.png`
**App State:** Post-onboarding Quick Start with two cards
**Setup Steps:**
1. Complete full onboarding flow
2. Capture Quick Start screen before dismissing

**Used In:** Internal reference

---

### CAP_07: Collections Empty State

**Filename:** `CAP_07_COLLECTIONS_EMPTY.png`
**App State:** Collections view with only Inbox, no recipes
**Setup Steps:**
1. Fresh account with no recipes
2. Navigate to Collections tab
3. Should show Inbox + empty state CTA

**Used In:** Onboarding reference

---

### CAP_07B: Collections Populated

**Filename:** `CAP_07B_COLLECTIONS_POPULATED.png`
**App State:** Collections view with 6-10 collections
**Setup Steps:**
1. Use demo account or create collections:
   - Inbox (2 recipes)
   - Weeknight Dinners (6 recipes)
   - Holiday Baking (4 recipes)
   - Quick Lunches (3 recipes)
   - Desserts (5 recipes)
   - Family Favorites (4 recipes)
2. Capture showing grid of collections

**Used In:** SS_01

---

### CAP_07C: Quick Actions Bar

**Filename:** `CAP_07C_QUICK_ACTIONS.png`
**App State:** Collections view with quick action chips visible
**Setup Steps:**
1. Fresh account with few recipes
2. Quick action bar should be visible
3. Capture showing "+ Save from link" etc.

**Used In:** Activation flow reference

---

### CAP_08: Scan Attestation

**Filename:** `CAP_08_SCAN_ATTESTATION.png`
**App State:** First-scan attestation interstitial
**Setup Steps:**
1. Fresh account (never scanned)
2. Tap + → Scan Recipe
3. Attestation sheet should appear
4. Capture before dismissing

**Used In:** Trust contract reference

---

### CAP_09: Ownership Verification

**Filename:** `CAP_09_OWNERSHIP_VERIFY.png`
**App State:** Ownership verification sheet before publishing
**Setup Steps:**
1. Open a camera-captured recipe
2. Tap ... → "Share Publicly"
3. Ownership sheet should appear
4. Capture with checkbox visible

**Used In:** SS_09

---

### CAP_10: AI Generated Badge

**Filename:** `CAP_10_GENERATED_BADGE.png`
**App State:** Recipe detail showing "AI Generated" source
**Setup Steps:**
1. Generate a recipe using AI
2. Open recipe detail
3. Source should show "AI Generated" with sparkles icon
4. Capture

**Used In:** SS_06

---

### CAP_11: Share Extension Toast

**Filename:** `CAP_11_SHARE_TOAST.png`
**App State:** Success toast with collection name
**Setup Steps:**
1. Save recipe via share extension
2. Capture toast immediately: "Saved to [Collection Name]"
3. "View in Heirloom" link visible

**Used In:** SS_02

---

### CAP_12: Video Import Result

**Filename:** `CAP_12_VIDEO_RESULT.png`
**App State:** Video import result showing extracted recipe
**Setup Steps:**
1. Import recipe from TikTok or YouTube
2. Wait for extraction to complete
3. Capture result showing:
   - Recipe title
   - "Source: Video" badge
   - @creator attribution

**Used In:** SS_03

---

### CAP_13: Discover Card with Attribution

**Filename:** `CAP_13_DISCOVER_CARD.png`
**App State:** Discover feed showing cards with creator names
**Setup Steps:**
1. Navigate to Discover tab
2. Ensure cards show:
   - Recipe title
   - Creator name ("by @username")
   - Public badge
   - Save count (if applicable)
3. Capture

**Used In:** SS_09

---

### CAP_14: Publishing Rules Sheet

**Filename:** `CAP_14_PUBLISHING_RULES.png`
**App State:** Publishing rules info sheet
**Setup Steps:**
1. Navigate to Discover
2. Tap info button / "What can I publish?"
3. Capture rules explanation sheet

**Used In:** Internal reference

---

### CAP_15: Recipe Detail with Source

**Filename:** `CAP_15_RECIPE_DETAIL.png`
**App State:** Full recipe detail view
**Setup Steps:**
1. Open any recipe with complete info
2. Scroll to show:
   - Image
   - Title
   - Source attribution
   - Metadata (time, servings)
3. Capture

**Used In:** General marketing

---

### CAP_16: + Menu Open

**Filename:** `CAP_16_PLUS_MENU.png`
**App State:** Add recipe menu showing all options
**Setup Steps:**
1. From Collections, tap + button
2. Menu should show all import options
3. Capture

**Used In:** Feature demonstration

---

### CAP_17: Camera Scan UI

**Filename:** `CAP_17_CAMERA_SCAN.png`
**App State:** Camera viewfinder for cookbook scan
**Setup Steps:**
1. Tap + → Scan Recipe
2. Point at cookbook page (or any text)
3. Capture viewfinder with detection overlay

**Used In:** SS_04

---

### CAP_18: Scan Result

**Filename:** `CAP_18_SCAN_RESULT.png`
**App State:** Result after scanning cookbook page
**Setup Steps:**
1. Complete a cookbook scan
2. Capture extracted recipe result

**Used In:** SS_04

---

### CAP_19: Read Aloud UI

**Filename:** `CAP_19_READ_ALOUD.png`
**App State:** Recipe with read aloud mode active
**Setup Steps:**
1. Open any recipe
2. Tap "Read Aloud" or speaker icon
3. Capture with current step highlighted
4. Play/pause controls visible

**Used In:** SS_05

---

### CAP_20: Generate Input

**Filename:** `CAP_20_GENERATE_INPUT.png`
**App State:** AI generation input screen
**Setup Steps:**
1. Tap + → "Make with AI" (or similar)
2. Enter sample ingredients or description
3. Capture before generating

**Used In:** SS_06

---

### CAP_21: Premium Paywall

**Filename:** `CAP_21_PREMIUM_PAYWALL.png`
**App State:** Premium upgrade screen
**Setup Steps:**
1. As free user, trigger paywall (try premium feature)
2. Capture upgrade screen showing:
   - Features list
   - Pricing ($5.99/mo, $39.99/yr)
   - Start trial CTA

**Used In:** SS_10

---

### CAP_22: Credits Quota Display

**Filename:** `CAP_22_CREDITS_QUOTA.png`
**App State:** Credits remaining display
**Setup Steps:**
1. Use some credits (save a few recipes)
2. Find credits display (Settings or home)
3. Capture showing "15/25 credits" or similar

**Used In:** Credits explanation

---

### CAP_23: Buy More Credits Sheet

**Filename:** `CAP_23_BUY_CREDITS.png`
**App State:** Credit pack purchase options
**Setup Steps:**
1. Exhaust daily credits (or simulate)
2. Tap "Get more" or trigger purchase sheet
3. Capture credit pack options (if applicable)

**Used In:** Pricing reference

---

## B. AI Image Generation Prompts (9 assets)

### AI_01: Onboarding Hero Illustration

**Filename:** `AI_01_onboarding_hero.png`
**Dimensions:** 1200 x 800 px
**Usage:** Onboarding Screen 1 hero area

**Prompt:**
```
Flat vector illustration of a recipe card emerging from chaos, warm earth tones
palette (cream, terracotta, sage green), scattered ingredients and papers on
left side transforming into organized clean recipe card on right, minimalist
style, soft shadows, no text, suitable for mobile app, warm and inviting mood,
cooking and home kitchen theme
```

**Negative Prompt:**
```
3D render, photorealistic, dark colors, cold colors, blue, purple, cluttered,
busy, text, words, logos, faces, people, hands
```

**Style Notes:**
- Should feel warm and approachable
- Communicate "chaos → order" transformation
- Match Heirloom's warm ceramic aesthetic

---

### AI_02: Collection Header - Weeknight Dinners

**Filename:** `AI_02_collection_weeknight.png`
**Dimensions:** 800 x 400 px
**Usage:** Collection card background

**Prompt:**
```
Abstract warm illustration of simple weeknight dinner ingredients, pasta and
vegetables loosely arranged, muted earth tones, cream background with soft
terracotta accents, minimalist food illustration style, no text, horizontal
composition for card header
```

**Negative Prompt:**
```
photorealistic, busy, cluttered, cold colors, text, people
```

---

### AI_03: Collection Header - Holiday Baking

**Filename:** `AI_03_collection_holiday.png`
**Dimensions:** 800 x 400 px
**Usage:** Collection card background

**Prompt:**
```
Abstract warm illustration of holiday baking elements, cookies and pie shapes,
cinnamon sticks, star anise, warm spice colors, cream and rich brown tones,
festive but subtle, minimalist food illustration style, no text, horizontal
composition
```

**Negative Prompt:**
```
photorealistic, Christmas specific imagery, snow, red and green only, text
```

---

### AI_04: Collection Header - Quick Lunches

**Filename:** `AI_04_collection_lunches.png`
**Dimensions:** 800 x 400 px
**Usage:** Collection card background

**Prompt:**
```
Abstract warm illustration of quick lunch elements, sandwich shapes, fresh
greens, simple shapes, light and fresh feeling, cream and sage green palette,
minimalist food illustration style, no text, horizontal composition
```

**Negative Prompt:**
```
photorealistic, busy, heavy, dark colors, text
```

---

### AI_05: Collection Header - Family Favorites

**Filename:** `AI_05_collection_family.png`
**Dimensions:** 800 x 400 px
**Usage:** Collection card background

**Prompt:**
```
Abstract warm illustration evoking family cooking, vintage recipe card shapes,
heart elements subtly included, nostalgic warm palette of cream, soft orange,
and muted red, minimalist illustration style, no text, horizontal composition,
feels like passed-down recipes
```

**Negative Prompt:**
```
photorealistic, modern, cold, text, specific faces or people
```

---

### AI_06: Open Graph Image

**Filename:** `AI_06_og_image.png`
**Dimensions:** 1200 x 630 px
**Usage:** Social sharing preview

**Prompt:**
```
Heirloom app marketing image, warm cream background, stylized recipe box with
cards emerging, mobile app feel, clean and inviting, terracotta and cream
color palette, minimalist, space for text overlay on left third, professional
app marketing style
```

**Negative Prompt:**
```
cluttered, dark, cold colors, text, screenshots
```

**Notes:**
- Leave space for "Heirloom" logo and tagline overlay
- Should work with dark text overlaid

---

### AI_07: Screenshot Frame Background

**Filename:** `AI_07_screenshot_bg.png`
**Dimensions:** 1290 x 2796 px (iPhone 15 Pro Max)
**Usage:** App Store screenshot backgrounds

**Prompt:**
```
Subtle warm gradient background for app store screenshot, cream to soft
terracotta gradient, subtle ceramic texture, professional and clean, no
distinct objects, suitable as background for device mockup, vertical
orientation
```

**Negative Prompt:**
```
busy, patterns, objects, text, illustrations
```

**Notes:**
- Should be subtle enough not to distract from device screenshot
- May need variants with different gradient directions

---

### AI_08: Landing Page Hero Background

**Filename:** `AI_08_landing_hero_bg.png`
**Dimensions:** 1920 x 1080 px
**Usage:** Website hero section background

**Prompt:**
```
Warm abstract background for marketing website, soft gradient from cream to
pale terracotta, subtle organic shapes suggesting kitchen warmth, very minimal
and professional, suitable as background for text and device mockups,
horizontal composition
```

**Negative Prompt:**
```
busy, illustrations, food, objects, text, dark
```

---

### AI_09: Press Kit Header

**Filename:** `AI_09_presskit_header.png`
**Dimensions:** 1200 x 400 px
**Usage:** Press kit page header

**Prompt:**
```
Professional header image for app press kit, warm brand colors (cream,
terracotta, sage), abstract recipe-themed shapes, clean and press-worthy,
minimalist style, horizontal banner composition, space for text overlay
```

**Negative Prompt:**
```
casual, playful, busy, cold colors
```

---

## C. Design Templates to Create

### Template 1: Screenshot Frame (Figma)

**Filename:** `Heirloom_Screenshot_Template.fig`

**Components:**
1. Device frame (iPhone 15 Pro Max, Space Black)
2. Text block component (headline + subhead)
3. Background variants (10 color combinations)
4. Layout grid guides

**Specifications:**
- Canvas: 1290 x 2796 px
- Device positioned: centered, 180px from top
- Headline: SF Pro Display Bold, 72pt, centered
- Subhead: SF Pro Display Regular, 42pt, centered

---

### Template 2: App Preview Video Project

**Filename:** `Heirloom_AppPreview.fcpxproj` (or Premiere/DaVinci)

**Timeline:**
- 25 seconds total
- 30fps
- 1290 x 2796 resolution
- H.264 export preset

**Segments marked:**
- 0:00-0:04 - Hook
- 0:04-0:08 - Save
- 0:08-0:13 - Video
- 0:13-0:17 - Scan
- 0:17-0:21 - Share
- 0:21-0:25 - CTA

---

### Template 3: OG Image Template (Figma)

**Filename:** `Heirloom_OG_Template.fig`

**Variants:**
1. Default (site root)
2. Landing variants (/lp/video, /lp/scan, etc.)
3. Support/legal pages

**Specifications:**
- Canvas: 1200 x 630 px
- Logo placement: top-left or centered
- Headline area: lower third
- Background: AI_06 base image

---

## D. Accounts & Configuration Checklist

### Apple Developer

- [ ] Developer Program membership active ($99/year)
- [ ] App ID registered
- [ ] Provisioning profiles created
- [ ] Push notification certificates configured
- [ ] App Store Connect record created
- [ ] IAP products submitted for review

### App Store Connect

- [ ] App listing created
- [ ] App name reserved: "Heirloom"
- [ ] Bundle ID confirmed
- [ ] Primary category: Food & Drink
- [ ] Secondary category: Lifestyle
- [ ] Screenshots uploaded (all sizes)
- [ ] App Preview uploaded
- [ ] Description entered
- [ ] Keywords configured
- [ ] Privacy policy URL verified
- [ ] Support URL verified
- [ ] Pricing tier set (Free with IAP)

### Netlify

- [ ] Account created
- [ ] Site deployed from git repo
- [ ] Custom domain configured: heirloomrecipebox.app
- [ ] HTTPS enabled (automatic)
- [ ] Deploy previews enabled
- [ ] Build notifications configured

### DNS (Domain Registrar)

- [ ] Domain registered: heirloomrecipebox.app
- [ ] A record pointing to Netlify
- [ ] CNAME for www → main domain
- [ ] MX records for email (if using custom email)
- [ ] SPF/DKIM for email deliverability

### Email Setup

- [ ] support@heirloomrecipebox.app functional
- [ ] press@heirloomrecipebox.app functional
- [ ] hello@heirloomrecipebox.app functional
- [ ] privacy@heirloomrecipebox.app functional
- [ ] Auto-responder configured (optional)

### Discord Server

- [ ] Server created
- [ ] Channels configured:
  - #welcome
  - #general
  - #feature-requests
  - #recipe-sharing
  - #support
- [ ] Roles configured (Member, Beta Tester, Team)
- [ ] Invite link generated
- [ ] Server rules posted

### Demo Account

- [ ] Account created: demo@heirloomrecipebox.app
- [ ] Password documented securely
- [ ] Premium subscription applied
- [ ] Sample recipes added (15 recipes, 3 collections)
- [ ] Sample shared recipe set up
- [ ] Tested login works

---

## E. Content to Write/Finalize

### Legal (Needs Legal Review)

- [ ] Privacy Policy final text
- [ ] Terms of Service final text
- [ ] GDPR compliance verification
- [ ] CCPA compliance verification
- [ ] App tracking transparency disclosure

### App Store

- [ ] App description (4000 chars)
- [ ] Keywords (100 chars)
- [ ] Promotional text (170 chars)
- [ ] What's New text
- [ ] App Review notes
- [ ] Demo account credentials documented

### Marketing

- [ ] Homepage headline/subhead finalized
- [ ] Feature descriptions (4 features)
- [ ] FAQ answers (8-10 questions)
- [ ] Email capture success message
- [ ] Social media bios

### Support

- [ ] FAQ content (10 questions minimum)
- [ ] Support page content
- [ ] Bug report form questions
- [ ] Auto-reply template for support emails

### Pricing (Confirmed)

| Item | Value |
|------|-------|
| Monthly | $5.99/month |
| Annual | $39.99/year |
| Annual trial | 14 days |
| Lifetime | $99.99 (optional) |
| Free credits | 25/day |

### Beta User Testimonials

- [ ] Collect 3-5 testimonials from beta testers
- [ ] Get permission to use with name/initials
- [ ] Format for website use

---

## F. App Preview Video Recording Plan

### Equipment

- iPhone 15 Pro Max (or latest)
- Mac with QuickTime
- Lightning/USB-C cable
- Clean desk background (not visible in recording)

### Recording Steps

**Segment 1: Hook (4 seconds)**
1. Start on populated Collections view
2. Slow scroll down to show recipes
3. End on a specific collection

**Segment 2: Save (4 seconds)**
1. Open Safari with recipe website
2. Tap Share button
3. Tap Heirloom in share sheet
4. Show saving animation
5. Show success toast

**Segment 3: Video Import (5 seconds)**
1. Tap + button
2. Select "From Video"
3. Paste TikTok URL
4. Show extraction progress
5. Show result

**Segment 4: Scan (4 seconds)**
1. Tap + button
2. Select "Scan Recipe"
3. Point camera at cookbook page
4. Capture animation
5. Show result

**Segment 5: Share (4 seconds)**
1. Open a recipe
2. Tap Share → Send to Friend
3. Show send animation
4. (Optional) Show accept on recipient

**Segment 6: CTA (4 seconds)**
1. Show app icon centered
2. Text overlay: "Download Heirloom"
3. Fade to end

### Export Settings

- Format: H.264
- Resolution: 1290 x 2796
- Frame rate: 30fps
- Audio: None (or subtle background)
- Duration: Exactly 25 seconds

---

## G. Pre-Submission Checklist (Final Gate)

### Creative Checklist

- [ ] All 10 App Store screenshots created
- [ ] Screenshots assembled in frames
- [ ] App Preview video edited and exported
- [ ] OG images created for all landing pages
- [ ] Collection header images created
- [ ] Landing page hero images ready

### Web Checklist

- [ ] Landing page deployed and live
- [ ] Privacy policy page live
- [ ] Terms of service page live
- [ ] Support page live
- [ ] All URLs verified accessible
- [ ] Email capture working
- [ ] Mobile responsive verified

### App Store Connect Checklist

- [ ] All metadata entered
- [ ] All screenshots uploaded
- [ ] App Preview uploaded
- [ ] All IAP products approved
- [ ] Privacy questionnaire complete
- [ ] Export compliance answered
- [ ] Build uploaded and processed
- [ ] App Review notes complete

### App Checklist

- [ ] Onboarding flow complete
- [ ] All new features working
- [ ] No crashes on main flows
- [ ] Premium features work
- [ ] Share extension works
- [ ] Deep links work
- [ ] Analytics verified
- [ ] Crash reporting verified

### Final Verification

- [ ] Demo account tested
- [ ] Fresh install tested
- [ ] Upgrade flow tested
- [ ] Support email tested
- [ ] Landing page CTA clicks tracked
- [ ] Team sign-off obtained

---

## Asset Naming Convention

| Prefix | Type | Example |
|--------|------|---------|
| CAP_ | App capture/screenshot | CAP_01_ONBOARDING_WELCOME |
| AI_ | AI-generated image | AI_01_onboarding_hero |
| SS_ | App Store screenshot | SS_01_collections_home |
| OG_ | Open Graph image | OG_default |
| TMPL_ | Design template | TMPL_screenshot_frame |

### Cross-Reference Table

| Capture | Used In Screenshot | Used In Landing |
|---------|-------------------|-----------------|
| CAP_07B | SS_01 | Homepage hero |
| CAP_03 + CAP_11 | SS_02 | /lp/scan |
| CAP_12 | SS_03 | /lp/video |
| CAP_17 + CAP_18 | SS_04 | /lp/scan |
| CAP_19 | SS_05 | - |
| CAP_10 + CAP_20 | SS_06 | /lp/generate |
| CAP_04 | SS_07 | /lp/share |
| CAP_05 | SS_08 | Homepage |
| CAP_13 + CAP_09 | SS_09 | - |
| CAP_02 + CAP_21 | SS_10 | Homepage pricing |
