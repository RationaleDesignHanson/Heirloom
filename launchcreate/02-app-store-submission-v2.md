# App Store Submission Guide (Updated)

> **Purpose:** Complete metadata, privacy questionnaire, screenshot specs, and submission checklist for Heirloom's first App Store submission.
>
> **Cross-references:**
> - Screenshot captures: See `04-manual-tasks-and-creative.md` Section A
> - Landing page URLs: See `03-landing-pages.md`
> - Onboarding changes: See `01-app-onboarding-changes.md`

---

## A. Metadata Table

| Field | Value |
|-------|-------|
| **App Name** | Heirloom |
| **Subtitle** | Save recipes from anywhere |
| **Primary Category** | Food & Drink |
| **Secondary Category** | Lifestyle |
| **Age Rating** | 4+ |
| **Copyright** | © 2026 Rationale Design Limited Licensing Corporation |
| **SKU** | com.rationaledesign.heirloom |
| **Bundle ID** | com.rationaledesign.heirloom |

### Subtitle Options (Ranked)

1. **"Save recipes from anywhere"** (27 chars) - Recommended
   - Clear value prop, includes "recipe" keyword
2. "Your personal recipe box" (25 chars)
   - Emotional, but less actionable
3. "Recipe box for family favorites" (33 chars)
   - Too long, may be truncated

### Keywords (100 character limit)

**Selected (97 chars):**
```
recipe,cookbook,meal,cooking,food,video,scan,import,organize,family,share,save,kitchen,voice,ai
```

### Full Description

```
Heirloom is your personal recipe box — finally. Save recipes from links, videos, and cookbook pages in one tap. Keep your family favorites organized and private by default.

SAVE FROM ANYWHERE
- Paste a link from any recipe website
- Import from TikTok, Instagram, and YouTube videos
- Scan cookbook pages with your camera
- Dictate recipes aloud with voice capture
- Generate new recipes with AI

ORGANIZED YOUR WAY
- Create collections for any occasion
- Search across all your recipes instantly
- Tag and filter to find what you need
- Works offline — your recipes are always with you

SHARE WITH INTENTION
- Send recipes to friends and family
- Shared recipes stay organized in their box too
- Private by default — you control what's shared
- Optional: Share to the public Discover feed

PREMIUM FEATURES
- Video-to-recipe import (audio + ASMR modes)
- Bulk cookbook scanning from PDFs
- Cloud sync across all devices
- Share recipes with connections
- Publish to the Discover feed
- 100 credits every month

FREE TIER
- Save from any link — always free
- Scan recipe cards with camera
- Generate recipes with AI
- 50 credits to start
- Manual recipe entry — unlimited
- Full search and organization

Premium: $6.99/month (7-day trial) or $39.99/year (14-day trial). Save 52%.
Lifetime access: $149 one-time purchase.

Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your account settings in the App Store after purchase.

Privacy Policy: https://heirloomrecipebox.app/privacy
Terms of Service: https://heirloomrecipebox.app/terms
```

### Promotional Text (170 chars max)

```
Save recipes from links, videos, and cookbooks in one tap. Dictate by voice. Generate with AI. Your private recipe box — 50 free credits to start.
```
(149 characters)

### What's New (Version 1.0)

```
Welcome to Heirloom!

Your personal recipe box is ready. Save recipes from:
- Any website link
- TikTok, Instagram, and YouTube videos
- Cookbook pages via camera
- Voice dictation
- AI generation from ingredients

Start with 50 free credits. Organize with collections. Share with friends and family.

Questions? Contact us at support@heirloomrecipebox.app
```

---

## B. Required URLs

| URL Type | URL |
|----------|-----|
| **Privacy Policy** | https://heirloomrecipebox.app/privacy |
| **Terms of Service** | https://heirloomrecipebox.app/terms |
| **Support URL** | https://heirloomrecipebox.app/support |
| **Marketing URL** | https://heirloomrecipebox.app |

### Email Addresses

| Purpose | Email |
|---------|-------|
| Support | support@heirloomrecipebox.app |
| Press | press@heirloomrecipebox.app |
| General | hello@heirloomrecipebox.app |

---

## C. App Privacy Nutrition Label

### Data Collection Summary

| Data Type | Collected | Linked to User | Used for Tracking |
|-----------|-----------|----------------|-------------------|
| Contact Info (Email) | Yes | Yes | No |
| User Content (Recipes, Photos) | Yes | Yes | No |
| Identifiers (User ID) | Yes | Yes | No |
| Usage Data | Yes | Yes | No |
| Diagnostics (Crash Logs) | Yes | No | No |

### Detailed Questionnaire

#### Contact Info
- **Email Address:** Collected for account creation and authentication
- **Linked to User:** Yes (required for account)
- **Used for Tracking:** No

#### User Content
- **Photos:** Collected for recipe images (user-provided)
- **Linked to User:** Yes (stored in their account)
- **Used for Tracking:** No

#### Identifiers
- **User ID:** Firebase Authentication UID
- **Linked to User:** Yes
- **Used for Tracking:** No

#### Usage Data
- **Product Interaction:** Recipe saves, collections created, features used
- **Linked to User:** Yes (for improving experience)
- **Used for Tracking:** No

#### Diagnostics
- **Crash Data:** Collected via Firebase Crashlytics
- **Linked to User:** No (anonymized)
- **Used for Tracking:** No

### Third-Party Processors

| Service | Purpose | Data Processed |
|---------|---------|----------------|
| Firebase Authentication | Account management | Email, User ID |
| Firebase Firestore | Data storage | Recipes, Collections |
| Firebase Storage | Image storage | Recipe photos |
| Firebase Crashlytics | Crash reporting | Device info, crash logs |
| Mixpanel | Analytics | Usage events (anonymized option available) |
| Anthropic | AI extraction | Recipe text (not stored by Anthropic) |

### Tracking Declaration

**Do you use data for tracking?** No

Heirloom does not track users across apps or websites. All analytics are first-party and used solely to improve the Heirloom experience.

---

## D. App Review Notes

### Demo Account

```
Email: demo@heirloomrecipebox.app
Password: HeirloomDemo2026!

This account has:
- 15 sample recipes across 3 collections
- Premium subscription active
- Example shared recipes
```

### Premium/Credits Explanation

```
Heirloom uses a hybrid credits + subscription model:
- New users get 50 credits at signup (no daily reset)
- Premium subscribers get 100 credits/month
- Credits purchase: 25 for $5 or 100 for $15

Credit costs:
- PDF import: 1-5 credits depending on scan complexity
- Video import (audio): 1 credit
- Video import (ASMR/silent): 5 credits
- URL/link import: FREE (no credits)
- Manual entry: FREE
- Voice dictation: FREE
- AI generation: FREE

Premium ($6.99/mo or $39.99/yr) unlocks:
- Video ASMR import mode
- Bulk PDF cookbook scanning
- Cloud sync
- Sharing to connections
- Publishing to Discover feed

To test premium features:
1. Use the demo account (already has premium)
2. Or: Go to Settings > Subscription > Start Free Trial
```

### Content Moderation

```
Heirloom includes a public discovery feed where users can share recipes.

Moderation approach:
1. Ownership attestation required before publishing
2. Camera-origin verification (screenshots/downloads blocked)
3. User reporting system for inappropriate content
4. Manual review queue for flagged content
5. Automated content filtering for obvious violations

Only camera-captured photos of real recipes can be published publicly.
AI-generated and web-imported recipes are limited to private sharing.
```

### Voice-to-Recipe Feature (Read Recipe)

```
The Read Recipe feature allows users to dictate a recipe by voice. They tap
the microphone button, speak the recipe aloud, and Heirloom transcribes and
structures it automatically into a complete recipe card.

This feature is free (no credits required) and works offline via Apple's
on-device speech recognition.
```

### Testing Instructions

```
Heirloom does not require an account for core features.
Sign in with Apple is optional for cloud sync.

To test key features:

1. SAVE FROM LINK:
   - Tap + button > "From Link"
   - Paste: https://www.seriouseats.com/the-best-slow-cooked-bolognese-sauce-recipe
   - Watch extraction and result

2. SHARE EXTENSION:
   - Open Safari to any recipe website
   - Tap Share > Heirloom
   - Recipe saves to Inbox collection

3. VIDEO IMPORT (Premium):
   - Tap + button > "From Video"
   - Paste TikTok or YouTube cooking video URL
   - Watch extraction (takes 30-60 seconds)

4. SCAN RECIPE (Premium):
   - Tap + button > "Scan Recipe"
   - Point camera at cookbook page
   - Capture and review extraction

5. VOICE DICTATION:
   - Tap + button > "Read Recipe"
   - Speak a recipe aloud
   - Review transcription and structured result

6. SHARE TO FRIEND:
   - Open any recipe
   - Tap Share button > "Send to Friend"
   - Enter recipient email
   - They receive link to accept

7. PUBLISH TO DISCOVER:
   - Open a camera-captured recipe
   - Tap ... menu > "Share Publicly"
   - Complete ownership verification
   - Recipe appears in Discover feed

Premium features (video import, PDF scanning, sync, sharing) require
subscription. Free users get 50 credits to try premium features.

Demo account with premium active:
Email: demo@heirloomrecipebox.app
Password: HeirloomDemo2026!

Questions? support@heirloomrecipebox.app
```

---

## E. TestFlight Beta Test Information

### Beta App Information

| Field | Value |
|-------|-------|
| **Feedback Email** | support@heirloomrecipebox.app |
| **Beta App Description** | Heirloom is your personal recipe box. Save recipes from links, videos, cookbook scans, voice dictation, and AI generation. Organize with collections, share with friends and family. Private by default. |
| **Marketing URL** | https://heirloomrecipebox.app |
| **Privacy Policy URL** | https://heirloomrecipebox.app/privacy |

### Beta App Review Information

| Field | Value |
|-------|-------|
| **First Name** | Matt |
| **Last Name** | Hanson |
| **Email** | *(your contact email)* |
| **Phone Number** | *(your phone number)* |

### Review Notes

```
Heirloom does not require an account for core features.
Sign in with Apple is optional for cloud sync.

To test key features:
1. SAVE FROM LINK: Tap + > "From Link" > paste any recipe URL
2. SHARE EXTENSION: Open Safari to a recipe site > Share > Heirloom
3. VIDEO IMPORT (Premium): Tap + > "From Video" > paste a TikTok/YouTube cooking video URL
4. VOICE DICTATION: Tap + > "Read Recipe" > speak a recipe aloud
5. AI GENERATION: Tap + > "Generate" > enter ingredients

Premium features (video import, PDF scanning, sync, sharing) require
subscription. Free users get 50 credits to try premium features.

Demo account with premium active:
Email: demo@heirloomrecipebox.app
Password: HeirloomDemo2026!

Questions? support@heirloomrecipebox.app
```

### Sign-in Required

**OFF** — Core features work without sign-in. Sign in with Apple is optional for cloud sync.

---

## F. In-App Purchase Configuration

### Products

| Product ID | Type | Price | Trial |
|------------|------|-------|-------|
| `com.rationaledesign.heirloom.premium.monthly.v2` | Auto-Renewable | $6.99/month | 7 days |
| `com.rationaledesign.heirloom.premium.annual.v2` | Auto-Renewable | $39.99/year | 14 days |
| `com.rationaledesign.heirloom.premium.lifetime.v2` | Non-Consumable | $149 | N/A |

### Monthly Subscription

**Reference Name:** Heirloom Premium Monthly
**Product ID:** `com.rationaledesign.heirloom.premium.monthly.v2`
**Price:** $6.99
**Subscription Duration:** 1 Month
**Free Trial:** 7 days
**Introductory Offer:** None

**Display Name:** Premium Monthly
**Description:** 100 credits/month, video import (audio + ASMR), bulk PDF scanning, cloud sync, sharing, and Discover feed publishing. Renews monthly.

### Annual Subscription

**Reference Name:** Heirloom Premium Annual
**Product ID:** `com.rationaledesign.heirloom.premium.annual.v2`
**Price:** $39.99
**Subscription Duration:** 1 Year
**Free Trial:** 14 days
**Introductory Offer:** None

**Display Name:** Premium Annual
**Description:** Save 52% with annual billing. 100 credits/month, video import (audio + ASMR), bulk PDF scanning, cloud sync, sharing, and Discover feed publishing. Includes 14-day free trial.

### Lifetime Purchase

**Reference Name:** Heirloom Premium Lifetime
**Product ID:** `com.rationaledesign.heirloom.premium.lifetime.v2`
**Price:** $149
**Type:** Non-Consumable

**Display Name:** Premium Lifetime
**Description:** One-time purchase for lifetime access to all premium features. Never pay again.

### Auto-Renewal Disclosure Text

```
• Payment will be charged to your Apple ID account at confirmation of purchase
• Subscription automatically renews unless canceled at least 24 hours before the end of the current period
• Your account will be charged for renewal within 24 hours prior to the end of the current period at the cost of the chosen plan
• You can manage and cancel your subscriptions by going to your App Store account settings after purchase
• Any unused portion of a free trial period will be forfeited when purchasing a subscription
```

---

## G. Export Compliance & Content Rights

### Encryption

**Does your app use encryption?** Yes

**Does your app qualify for any exemptions?** Yes

**Exemption:** Standard HTTPS/TLS for network communication

We use only standard iOS-provided encryption (HTTPS) for:
- Firebase Authentication
- Firebase Firestore
- Firebase Storage
- API calls to Anthropic (via Firebase Cloud Functions)

No custom encryption algorithms are implemented.

### Content Rights

**Does your app contain, display, or access third-party content?** Yes

**How do you have rights to this content?**
```
User-generated content with moderation:

1. Users import their own recipes from various sources
2. Users photograph their own cookbooks/recipe cards
3. For public sharing, users must attest to ownership
4. Camera-origin verification prevents screenshot sharing
5. Reporting system for copyright violations
6. DMCA takedown process available

All publicly shared content requires:
- Camera-captured photos (not screenshots)
- Ownership attestation at publish time
- Attribution to original creator when known
```

---

## H. Screenshot Creative Plan (10 Screenshots)

> **Device:** iPhone 15 Pro Max (6.7")
> **Resolution:** 1290 x 2796 pixels
> **Format:** PNG, sRGB
> **See:** `04-manual-tasks-and-creative.md` for capture instructions

### Screenshot 1: Collections / Home

**Filename:** `SS_01_collections_home.png`
**Headline:** Your Recipe Box
**Subhead:** All your favorites, organized your way

**App State:**
- Collections list view with 6-8 collections
- Mix of populated collections with recipe counts
- Warm, inviting appearance

**Capture Source:** `CAP_07B_COLLECTIONS_POPULATED`

**Frame Background:**
```
Warm ceramic texture, soft gradient from cream to light terracotta,
subtle grain, food photography studio lighting feel
```

---

### Screenshot 2: One-Tap Save

**Filename:** `SS_02_save_from_link.png`
**Headline:** Save in One Tap
**Subhead:** From any link, video, or cookbook

**App State:**
- Share extension visible or + menu open
- "Saved to Inbox" toast visible
- Clean, fast feeling

**Capture Source:** `CAP_03_SHARE_SHEET` + `CAP_11_SHARE_TOAST`

**Frame Background:**
```
Light sage green gradient, suggesting freshness and ease,
subtle paper texture overlay
```

---

### Screenshot 3: Video to Recipe

**Filename:** `SS_03_video_import.png`
**Headline:** Videos Become Recipes
**Subhead:** TikTok, Instagram, YouTube—instant

**App State:**
- Video import result showing extracted recipe
- "Source: Video" badge visible
- @creator attribution shown

**Capture Source:** `CAP_12_VIDEO_RESULT`

**Frame Background:**
```
Energetic gradient, coral to warm pink,
subtle video frame graphic element
```

---

### Screenshot 4: Scan Cookbook Pages

**Filename:** `SS_04_scan_cookbook.png`
**Headline:** Scan Any Cookbook
**Subhead:** Point, shoot, done

**App State:**
- Camera viewfinder with cookbook page
- Or: Scan result showing extracted recipe

**Capture Source:** `CAP_09_SCAN_RESULT` (see 04-manual-tasks-and-creative.md)

**Frame Background:**
```
Warm brown gradient evoking old cookbook pages,
subtle aged paper texture
```

---

### Screenshot 5: Speak Your Recipe (Voice Capture)

**Filename:** `SS_05_read_recipe.png`
**Headline:** Speak Your Recipe
**Subhead:** Dictate — Heirloom writes it down

**App State:**
- ReadRecipeView showing large microphone button in recording state (red)
- Real-time transcription text appearing below
- Recording duration timer visible (e.g., "00:42")
- Mid-dictation with partial recipe text in transcription box

**Capture Source:** `CAP_22_READ_RECIPE`

**Frame Background:**
```
Soft blue gradient, subtle audio wave element
```

---

### Screenshot 6: Generate from Ingredients

**Filename:** `SS_06_ai_generate.png`
**Headline:** Make Something New
**Subhead:** Tell us what you have—get a recipe

**App State:**
- AI generation input showing ingredient list
- Or: Generated recipe result with "AI Generated" badge

**Capture Source:** `CAP_10_GENERATED_BADGE`

**Frame Background:**
```
Gradient with sparkle/magic feel, soft purple to warm gold,
suggesting AI creativity
```

---

### Screenshot 7: Share That Sticks

**Filename:** `SS_07_share_with_friends.png`
**Headline:** Share Recipes That Stick
**Subhead:** Friends keep them forever

**App State:**
- Share send flow with recipient
- Or: Accept sheet on recipient side
- Message-style UI

**Capture Source:** `CAP_04_SHARE_SEND`

**Frame Background:**
```
Warm family feeling, soft orange gradient,
subtle connection/sharing visual element
```

---

### Screenshot 8: Private by Default

**Filename:** `SS_08_private_by_default.png`
**Headline:** Private by Default
**Subhead:** You control what's shared

**App State:**
- Visibility pills showing Private/Shared/Public
- Privacy explanation visible

**Capture Source:** `CAP_05_VISIBILITY_PILLS`

**Frame Background:**
```
Secure feeling, deep green to cream gradient,
subtle lock/shield element
```

---

### Screenshot 9: Attribution & Provenance

**Filename:** `SS_09_attribution.png`
**Headline:** Credit Where It's Due
**Subhead:** Track where recipes come from

**App State:**
- Discover card showing creator attribution
- Or: Recipe detail with provenance info

**Capture Source:** `CAP_13_DISCOVER_CARD`

**Frame Background:**
```
Trust-building warm gold gradient,
subtle family tree or lineage element
```

---

### Screenshot 10: Premium + Credits

**Filename:** `SS_10_premium.png`
**Headline:** Start Free, Go Premium
**Subhead:** 50 trial credits included. Unlimited with Premium.

**App State:**
- OnboardingSubscriptionScreen showing: "Always free" features list, "Premium unlocks" list
- 50 credits trial mention
- Pricing ($6.99/mo or $39.99/yr)
- OR: Settings subscription section + credits balance indicator

**Capture Source:** `CAP_02_ONBOARDING_CREDITS` or `CAP_21_CREDITS`

**Frame Background:**
```
Premium feeling, warm gold to cream gradient,
subtle crown or premium badge element
```

---

## I. App Preview Video Storyboard (25 seconds)

### Technical Specifications

- **Resolution:** 1290 x 2796 (iPhone 15 Pro Max)
- **Frame Rate:** 30 fps
- **Codec:** H.264
- **Duration:** 25-30 seconds (target: 30 seconds)
- **Audio:** None (muted autoplay)

### Storyboard (Corrected)

| Segment | Duration | Content | Capture IDs | Notes |
|---------|----------|---------|-------------|-------|
| 1 | 0:00-0:04 | **Hook:** "Your recipes, finally organized" over collections grid | CAP_07B | Slight zoom in on populated collections |
| 2 | 0:04-0:08 | **Save:** Safari share sheet > tap Heirloom > "Saved" toast | CAP_03, CAP_03B, CAP_11 | Screen-record the full share extension flow |
| 3 | 0:08-0:13 | **Video:** Paste video URL > import progress > recipe result | CAP_12 | Screen-record video import flow end-to-end |
| 4 | 0:13-0:17 | **Scan:** Camera scan of cookbook page > extracted recipe | CAP_17, CAP_18 | Screen-record camera > result |
| 5 | 0:17-0:21 | **Voice:** Voice dictation: tap mic > speak > transcription appears | CAP_22 | Screen-record ReadRecipeView in action |
| 6 | 0:21-0:25 | **Trust:** Privacy pills + "Private by default" | CAP_05 | Brief, reassuring |
| 7 | 0:25-0:30 | **CTA:** "Download Heirloom" + app icon + App Store badge | -- | End card from AE template |

### Recording Instructions

1. Use iPhone 15 Pro Max in Light Mode
2. Set time to 9:41 AM (Apple convention)
3. Full battery indicator
4. Strong WiFi signal
5. No notifications during recording
6. Use QuickTime screen recording via Mac
7. Record each segment separately
8. Edit in Final Cut Pro or iMovie

---

## Pre-Submission Checklist

### App Store Connect Setup

- [ ] App record created with Bundle ID
- [ ] App name reserved
- [ ] Primary and secondary categories selected
- [ ] Age rating questionnaire completed
- [ ] Pricing set (Free with IAP)
- [ ] Availability configured (all territories or specific)
- [ ] App Privacy questionnaire completed

### Metadata

- [ ] App name (30 chars max)
- [ ] Subtitle (30 chars max)
- [ ] Description (4000 chars max)
- [ ] Keywords (100 chars max)
- [ ] Promotional text (170 chars max)
- [ ] What's New text
- [ ] Copyright string
- [ ] Support URL live and accessible
- [ ] Privacy Policy URL live and accessible
- [ ] Marketing URL live and accessible

### Screenshots

- [ ] All 10 screenshots created (6.7" iPhone)
- [ ] Screenshots meet resolution requirements
- [ ] No alpha channels in PNG files
- [ ] Accurate device frames
- [ ] Text is readable and not truncated
- [ ] iPad screenshots (if supporting iPad)

### App Preview

- [ ] Video meets technical specs
- [ ] Duration under 30 seconds
- [ ] Demonstrates key features
- [ ] No third-party content/music issues

### In-App Purchases

- [ ] All products created in App Store Connect
- [ ] Products approved (may take 24-48 hours)
- [ ] Subscription group configured
- [ ] Free trial configured for annual
- [ ] Auto-renewal terms in app and description

### Build

- [ ] Archive uploaded to App Store Connect
- [ ] Build processed successfully
- [ ] No missing compliance info
- [ ] All required capabilities configured

### Review Notes

- [ ] Demo account credentials provided
- [ ] Testing instructions clear
- [ ] Any special features explained
- [ ] Content moderation described

### Legal

- [ ] Privacy Policy reviewed by legal
- [ ] Terms of Service reviewed by legal
- [ ] GDPR compliance confirmed
- [ ] CCPA compliance confirmed
- [ ] Export compliance completed

---

## Post-Submission

### After Submitting

1. Monitor App Store Connect for status changes
2. Check email for review team communications
3. Be prepared to respond within 24 hours
4. Have builds ready for quick fixes if rejected

### Common Rejection Reasons to Avoid

1. **Guideline 2.1 - Crashes:** Test thoroughly on real devices
2. **Guideline 3.1.1 - IAP:** Ensure all purchases go through Apple
3. **Guideline 5.1.1 - Privacy:** Privacy policy must be accessible
4. **Guideline 4.0 - Design:** Follow HIG, don't mimic system UI
5. **Metadata Issues:** Screenshots must be accurate, no placeholders

### Timeline Expectations

- **First submission:** 24-48 hours for initial review
- **Expedited review:** Request only if critical bug fix needed
- **Rejection response:** 24-48 hours after resubmission
- **Approval to live:** Usually immediate after approval
