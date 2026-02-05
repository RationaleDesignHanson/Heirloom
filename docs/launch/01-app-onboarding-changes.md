# App Onboarding & Trust Contract Changes

> **Purpose:** 14 Claude Code prompts to update onboarding, implement trust contract features, and prepare the app for App Store screenshots.
>
> **Cross-references:**
> - Screenshots needed: See `04-manual-tasks-and-creative.md` Section A
> - App Store metadata: See `02-app-store-submission.md`

---

## Pre-Implementation Notes

### Current State (as of Feb 2026)
- 5-screen onboarding flow exists in `Heirloom/Features/Onboarding/`
- `OnboardingContainerView.swift` manages flow: welcome → premiumTrial → shareSheetAha → shareAndAccept → discover
- `RecipeSourceType` enum has: url, cookbook, family, manual, scan, heritage, video (no `generated` yet)
- Publishing flow exists in `PublishRecipeSheet.swift` with camera-origin validation

### DELTAs to Implement
These features don't exist yet and need full implementation:
1. `generated` sourceType enum value
2. Visibility pills UI concept (Private/Shared/Public)
3. First-scan attestation interstitial
4. Publish-time ownership verification sheet
5. Post-onboarding Quick Start screen
6. "Inbox" default collection
7. Share extension toast with collection name + deep link
8. Discover card redesign with lineage/privacy chips
9. `publisherAttestationAcceptedAt` timestamp field

---

## TASK 1: Onboarding Screen 1/5 - "Turn recipe chaos into a recipe box"

**Goal:** Replace the current collections grid mockup with a "3 inputs → 1 recipe" visual that demonstrates the core value prop.

**Positioning Pillar:** Save from anywhere

### Claude Code Prompt

```
Before writing code that requires custom images, stop and ask me for each image one at a time:

1. Tell me the asset name you'll use (e.g., "onboarding-video-source")
2. Describe exactly what the image should show (dimensions, content, style)
3. Wait for me to provide a file path
4. Add it to Assets.xcassets with proper @2x/@3x variants
5. Then continue to the next image or proceed with code

Do not use placeholders. Do not proceed until I provide each image path.

---

Update OnboardingWelcomeScreen.swift to replace the current recipe grid mockup with a "3 inputs → 1 clean recipe" visual:

1. Replace `recipeBoxMockup` with a new `inputsToRecipeVisual` that shows:
   - Left side: 3 stacked "source" cards (video thumbnail, cookbook page, website screenshot) at a slight angle
   - Arrow or flow indicator in the middle
   - Right side: Single clean Heirloom recipe card

2. Update header copy:
   - Title: "Turn recipe chaos into a recipe box"
   - Subtitle: "Save from links, videos, cookbooks, and photos—all in one tap."

3. Add subtle entrance animation:
   - Source cards slide in from left with stagger
   - Arrow pulses once
   - Recipe card slides in from right

4. Keep the warm cream/beige gradient background
5. Keep "Private by default" microcopy at bottom

Files to modify:
- Heirloom/Features/Onboarding/OnboardingWelcomeScreen.swift
```

### Files Affected
- `Heirloom/Features/Onboarding/OnboardingWelcomeScreen.swift`

### Captures Needed
- `CAP_01_ONBOARDING_WELCOME`: Final screen state with animation complete

### AI Image Prompt (if using generated assets)
```
Flat vector illustration, warm earth tones, recipe card emerging from chaos of scattered papers,
minimalist style, soft shadows, cream background, no text, suitable for mobile app hero image,
aspect ratio 16:9
```

---

## TASK 2: Onboarding Screen 2/5 - "Free daily credits"

**Goal:** Show the credit system clearly with "25 free credits" meter and example costs.

**Positioning Pillar:** Value clarity / Fair pricing

### Claude Code Prompt

```
Update OnboardingSubscriptionScreen.swift to focus on the credit system:

1. Replace current feature list with credit-focused content:
   - Header: "Free daily credits to save recipes"
   - Subtitle: "25 credits refresh every day. Save recipes your way."

2. Add a visual credit meter component:
   - Circular or linear progress showing "25/25 credits"
   - Warm orange/amber fill color
   - Caption: "Refreshes daily"

3. Show 3 example costs in a clean list:
   - "Save from link: 1 credit" with globe icon
   - "Import from video: 3 credits" with video icon
   - "Scan cookbook page: 2 credits" with camera icon

4. Add "How credits work" link that opens a modal/sheet explaining:
   - Credits refresh daily at midnight local time
   - Unused credits don't roll over
   - Premium gets unlimited saves
   - Manual entry is always free

5. Update CTAs:
   - Primary: "Start free trial" (shows price after trial)
   - Secondary: "Continue free" (emphasized as valid choice)

6. Keep Terms/Privacy links at bottom

Files to modify:
- Heirloom/Features/Onboarding/OnboardingSubscriptionScreen.swift

Note: Credit system logic may need to be implemented separately - this is the UI portion.
```

### Files Affected
- `Heirloom/Features/Onboarding/OnboardingSubscriptionScreen.swift`

### Captures Needed
- `CAP_02_ONBOARDING_CREDITS`: Screen showing credit meter and examples
- `CAP_02B_CREDITS_MODAL`: "How credits work" modal open

---

## TASK 3: Onboarding Screen 3/5 - "Save from anywhere"

**Goal:** Show the share extension workflow with 3-step animated interaction.

**Positioning Pillar:** Save from anywhere (primary differentiator)

### Claude Code Prompt

```
Update OnboardingShareExtensionScreen.swift with an interactive 3-step animation:

1. Create a phone-within-phone mockup showing:
   - Step 1: Safari with a recipe page, share button highlighted
   - Step 2: iOS share sheet with Heirloom icon prominently shown
   - Step 3: "Saved to Inbox" success toast

2. Animation sequence (auto-plays on appear):
   - Step 1 shows for 2s, then transitions
   - Step 2 shows for 1.5s with Heirloom icon pulse
   - Step 3 shows for 2s with checkmark animation
   - Loop back to step 1 after 1s pause

3. Add step indicators (1, 2, 3 dots) below mockup showing current step

4. Header copy:
   - Title: "Save from anywhere"
   - Subtitle: "See a recipe? Share it to Heirloom."

5. Add coach mark callout pointing to mockup:
   - "Tip: You can also tap + in Heirloom to paste a link"
   - Small arrow pointing down

6. CTA: "Continue" button

Files to modify:
- Heirloom/Features/Onboarding/OnboardingShareExtensionScreen.swift
```

### Files Affected
- `Heirloom/Features/Onboarding/OnboardingShareExtensionScreen.swift`

### Captures Needed
- `CAP_03_SHARE_SHEET`: iOS share sheet with Heirloom visible
- `CAP_03B_IMPORTING`: Recipe import progress state
- `CAP_03C_SAVED_TOAST`: "Saved to [Collection]" success toast

---

## TASK 4: Onboarding Screen 4/5 - "Share recipes that stick"

**Goal:** Show the P2P sharing model with message-style interaction.

**Positioning Pillar:** Intentional sharing / Privacy-first

### Claude Code Prompt

```
Update OnboardingShareAndAcceptScreen.swift with a message-bubble style interaction:

1. Create a chat-style mockup showing:
   - Top: "You" sending a recipe card (shows recipe thumbnail + title)
   - Message: "Here's that pasta recipe you wanted!"
   - Bottom: Recipient's Accept sheet appearing

2. Animation sequence:
   - Recipe card slides in from right (sender)
   - Accept sheet slides up after 1s delay
   - Checkmark appears on accept after 0.5s
   - "Added to their recipe box" confirmation text

3. Header copy:
   - Title: "Share recipes that stick"
   - Subtitle: "Send to friends and family. They'll have it forever."

4. Key differentiator callout:
   - "Unlike screenshots, shared recipes stay organized and searchable"
   - Small lock icon

5. CTA: "Continue" button

Files to modify:
- Heirloom/Features/Onboarding/OnboardingShareAndAcceptScreen.swift
```

### Files Affected
- `Heirloom/Features/Onboarding/OnboardingShareAndAcceptScreen.swift`

### Captures Needed
- `CAP_04_SHARE_SEND`: Share send flow with message
- `CAP_04B_ACCEPT_SHEET`: Recipient's Accept sheet
- `CAP_04C_ADDED_SUCCESS`: "Added to your recipe box" success state

---

## TASK 5: Onboarding Screen 5/5 - "Private by default"

**Goal:** Introduce the visibility pills concept and replace Discover-feed mock.

**Positioning Pillar:** Privacy-first / Trust contract

### Claude Code Prompt

```
Update OnboardingDiscoverScreen.swift to introduce privacy controls:

1. Replace Discover feed mock with visibility explanation:
   - Show a recipe card with three visibility pill options below it:
     - "Private" (lock icon, filled/selected by default)
     - "Shared" (person.2 icon, outline)
     - "Public" (globe icon, outline)

2. Animate pill selection to show what each means:
   - Private: "Only you can see this"
   - Shared: "Visible to people you share with"
   - Public: "Visible in Discover feed"

3. Header copy:
   - Title: "Private by default"
   - Subtitle: "Your recipes are yours. Share only what you choose."

4. Trust contract callout box:
   - "Your recipe box is private. We never share your recipes without your explicit action."
   - Green checkmark icon

5. Two CTAs at bottom:
   - Primary: "Start saving" (goes to Collections)
   - Secondary: "Explore Discover" (goes to Discover tab)

6. Ensure this triggers the theme selection sheet flow on completion

Files to modify:
- Heirloom/Features/Onboarding/OnboardingDiscoverScreen.swift
```

### Files Affected
- `Heirloom/Features/Onboarding/OnboardingDiscoverScreen.swift`

### Captures Needed
- `CAP_05_VISIBILITY_PILLS`: Privacy screen with visibility options
- `CAP_05B_PILL_PRIVATE`: Private pill selected state
- `CAP_05C_PILL_PUBLIC`: Public pill selected state

---

## TASK 6: Post-Onboarding Quick Start Screen

**Goal:** Create a new screen shown once after onboarding with two clear action paths.

**Positioning Pillar:** Activation / First value moment

### Claude Code Prompt

```
Create a new QuickStartScreen.swift shown once after onboarding completion:

1. Create new file: Heirloom/Features/Onboarding/QuickStartScreen.swift

2. Design with two large, tappable cards:
   Card 1: "Save a recipe"
   - Icon: square.and.arrow.down
   - Subtitle: "Import from a link, video, or photo"
   - Tapping opens the + menu / import flow

   Card 2: "Make one with AI"
   - Icon: sparkles
   - Subtitle: "Describe what you want to cook"
   - Tapping opens AI generation flow

3. Header:
   - Title: "What would you like to do first?"
   - No subtitle needed

4. UserDefaults persistence:
   - Key: "hasSeenQuickStart"
   - Only show once, ever
   - Check in OnboardingContainerView before completing

5. Skip option:
   - Small "Skip" text button at bottom
   - Goes directly to Collections

6. Update OnboardingContainerView.swift:
   - After theme selection completes, check if hasSeenQuickStart is false
   - If false, show QuickStartScreen before finalizing
   - Set hasSeenQuickStart = true when user takes any action

Files to create:
- Heirloom/Features/Onboarding/QuickStartScreen.swift

Files to modify:
- Heirloom/Features/Onboarding/OnboardingContainerView.swift
```

### Files Affected
- `Heirloom/Features/Onboarding/QuickStartScreen.swift` (new)
- `Heirloom/Features/Onboarding/OnboardingContainerView.swift`

### Captures Needed
- `CAP_06_QUICK_START`: Quick Start screen with both cards visible

---

## TASK 7: Collections First-Run Enhancements

**Goal:** Improve empty state, add quick action bar, and create default "Inbox" collection.

**Positioning Pillar:** Organization / Getting started

### Claude Code Prompt

```
Enhance CollectionsListView.swift for first-run experience:

1. Create "Inbox" collection automatically for new users:
   - In the app initialization or first-launch flow, create a collection named "Inbox"
   - Icon: "tray.fill"
   - collectionType: .user (or new .system type if needed)
   - This is the default destination for Share Extension saves
   - Cannot be deleted or renamed

2. Update empty state when user has only Inbox (no recipes):
   - Illustration: Empty recipe box or waiting state
   - Title: "Your recipe box is ready"
   - Subtitle: "Save your first recipe to get started"
   - Primary CTA: "Save a recipe" (opens + menu)
   - Secondary: "Import from link" (direct to URL import)

3. Add quick action bar at top of Collections view:
   - Horizontal scroll of action chips:
     - "+ Save from link"
     - "+ Scan recipe"
     - "+ Import video"
   - Only show when user has < 5 recipes (to help activation)
   - Hide via UserDefaults "hasSeenQuickActions" after 10 recipes

4. Add coach mark on + button for first-time users:
   - Tooltip: "Tap to add recipes"
   - Points to + button in nav bar
   - Dismisses on tap or after 5 seconds
   - UserDefaults: "hasSeenAddButtonCoachMark"

5. Seeded demo state for screenshots:
   - Add a #if DEBUG block that can populate demo collections
   - Used for App Store screenshot capture
   - Include: "Weeknight Dinners" (6 recipes), "Holiday Baking" (4 recipes), "Inbox" (2 recipes)

Files to modify:
- Heirloom/Features/Collections/CollectionsListView.swift
- App initialization code where collections are set up

Files may need to create:
- Heirloom/Features/Collections/CollectionsEmptyState.swift (if extracting to component)
```

### Files Affected
- `Heirloom/Features/Collections/CollectionsListView.swift`
- App initialization / first-launch logic

### Captures Needed
- `CAP_07_COLLECTIONS_EMPTY`: Empty state with Inbox only
- `CAP_07B_COLLECTIONS_POPULATED`: Collections with 6-10 cards
- `CAP_07C_QUICK_ACTIONS`: Quick action bar visible

---

## TASK 8: First-Scan Attestation (Education)

**Goal:** Show a one-time "respect creators" interstitial before first camera scan.

**Positioning Pillar:** Trust contract / Attribution

### Claude Code Prompt

```
Create a first-scan attestation interstitial for camera imports:

1. Create new file: Heirloom/Features/Import/ScanAttestationView.swift

2. Design as a sheet/interstitial with:
   - Icon: camera + heart or similar
   - Title: "Respect recipe creators"
   - Body text (3 short bullets):
     - "Only scan recipes you have the right to save"
     - "Credit the original creator when you know them"
     - "Shared recipes link back to the source"

3. Single checkbox:
   - "I understand" with checkmark
   - CTA enabled only when checked

4. CTA: "Continue to camera"
   - Dismisses sheet and proceeds to camera

5. UserDefaults persistence:
   - Key: "hasAcceptedScanAttestation"
   - Check before showing camera import flow
   - Only show once, ever

6. Integration points:
   - Before camera opens for cookbook scan
   - Before camera opens for photo import
   - NOT for video imports or URL imports

Files to create:
- Heirloom/Features/Import/ScanAttestationView.swift

Files to modify:
- Scan/camera import flow entry points
```

### Files Affected
- `Heirloom/Features/Import/ScanAttestationView.swift` (new)
- Camera import flow controllers

### Captures Needed
- `CAP_08_SCAN_ATTESTATION`: Attestation sheet visible

---

## TASK 9: Publish-Time Ownership Verification

**Goal:** Add ownership confirmation step before publishing to public Discover feed.

**Positioning Pillar:** Trust contract / Legal protection

### Claude Code Prompt

```
Add ownership verification to the publish flow:

1. Update Recipe.swift model:
   - Add field: `publisherAttestationAcceptedAt: Date?`
   - This records when user attested to ownership

2. Create new component: Heirloom/Features/Discovery/OwnershipVerificationSheet.swift
   - Sheet that appears BEFORE PublishRecipeSheet
   - Title: "Confirm you can share this"
   - Body: "By publishing, you confirm this is your own recipe or you have permission to share it."
   - Checkbox: "I confirm this is my recipe or I have permission"
   - CTA: "Continue to publish" (disabled until checked)

3. Update publishing flow:
   - When user taps "Share publicly" from recipe menu
   - First show OwnershipVerificationSheet
   - On confirmation, set publisherAttestationAcceptedAt = Date()
   - Then show PublishRecipeSheet

4. Validation in PublicRecipeService:
   - Check publisherAttestationAcceptedAt is non-nil before allowing publish
   - Add to validation error messages if missing

Files to create:
- Heirloom/Features/Discovery/OwnershipVerificationSheet.swift

Files to modify:
- Heirloom/Core/Models/Recipe.swift (add timestamp field)
- Heirloom/Features/Discovery/PublishRecipeSheet.swift (or parent flow)
- Heirloom/Core/Services/Discovery/PublicRecipeService.swift
```

### Files Affected
- `Heirloom/Core/Models/Recipe.swift`
- `Heirloom/Features/Discovery/OwnershipVerificationSheet.swift` (new)
- `Heirloom/Features/Discovery/PublishRecipeSheet.swift`
- `Heirloom/Core/Services/Discovery/PublicRecipeService.swift`

### Captures Needed
- `CAP_09_OWNERSHIP_VERIFY`: Ownership verification sheet

---

## TASK 10: Generated Recipe Publishing Gate

**Goal:** Add `generated` sourceType and disable public publishing for AI-generated recipes.

**Positioning Pillar:** Trust contract / Content quality

### Claude Code Prompt

```
Add generated sourceType and restrict publishing for AI recipes:

1. Update RecipeSourceType enum in Recipe.swift:
   - Add new case: `generated = "generated"`
   - Add iconName: "sparkles"
   - Add displayName: "AI Generated"
   - Add publicSharingBlockedReason: "AI-generated recipes can only be shared privately with friends and family. Public sharing is reserved for real family recipes."

2. Update Recipe initializer in AI generation flow:
   - When creating recipe from AI generation, set sourceType = .generated
   - Also set aiGenerated = true (existing field)

3. Update canMakePublic computed property:
   - Add check: sourceType != .generated
   - Generated recipes should fail public validation

4. Update PublicRecipeService validation:
   - Check sourceType != .generated
   - Return appropriate error message

5. Allow P2P sharing for generated:
   - canShare() should still return true for generated
   - Only public Discover publishing is blocked

6. Update ProvenanceMetadata.SourceType mapping:
   - Add case for .generated → .aiGenerated (or .userCreated)

Files to modify:
- Heirloom/Core/Models/Recipe.swift (RecipeSourceType enum + computed properties)
- AI generation service/flow where recipes are created
- Heirloom/Core/Services/Discovery/PublicRecipeService.swift
```

### Files Affected
- `Heirloom/Core/Models/Recipe.swift`
- AI recipe generation flow
- `Heirloom/Core/Services/Discovery/PublicRecipeService.swift`

### Captures Needed
- `CAP_10_GENERATED_BADGE`: Recipe showing "AI Generated" source badge

---

## TASK 11: Share Extension Success Feedback

**Goal:** Show toast with collection name and deep link after successful save.

**Positioning Pillar:** Save from anywhere / Feedback clarity

### Claude Code Prompt

```
Enhance Share Extension success feedback:

1. Update ShareViewController.swift (or ShareExtensionView.swift):
   - After successful save, show enhanced toast:
     - Checkmark icon
     - Text: "Saved to [Collection Name]"
     - Subtitle link: "View in Heirloom"

2. Implement deep link:
   - Tapping "View in Heirloom" should open the app
   - Navigate directly to the saved recipe
   - Use URL scheme: heirloom://recipe/{recipeId}

3. Toast design:
   - Slide up from bottom
   - Auto-dismiss after 3 seconds
   - Can be dismissed by tapping
   - Background: warm cream with subtle shadow
   - Text: Heirloom fonts

4. Collection selection:
   - If user has multiple collections, show quick picker before save
   - Default to "Inbox" if no selection
   - Remember last used collection (UserDefaults)

Files to modify:
- Heirloom/ShareExtension/ShareViewController.swift
- App URL routing to handle deep links
```

### Files Affected
- `Heirloom/ShareExtension/ShareViewController.swift`
- Deep link / URL routing handler

### Captures Needed
- `CAP_11_SHARE_TOAST`: Success toast with collection name

---

## TASK 12: Video Import Result Page Polish

**Goal:** Add source badge and ASMR callout for video-imported recipes.

**Positioning Pillar:** Video magic / Attribution

### Claude Code Prompt

```
Polish the video import result page:

1. Find the video import result/success view (likely in import flow)

2. Add "Source: Video" badge:
   - Position: Below recipe title or in metadata area
   - Icon: video.circle.fill
   - Text: "Imported from video"
   - Link to original video if URL available

3. Add ASMR callout microcopy (conditional):
   - If video duration > 60 seconds or title contains cooking keywords
   - Show: "Perfect for those satisfying cooking videos"
   - Small, subtle text below the badge

4. Creator attribution:
   - Show @creatorname if available from provenance
   - Make it tappable to open creator's profile

5. Styling:
   - Match existing recipe detail design
   - Use Heirloom color palette
   - Subtle, not overwhelming

Files to modify:
- Video import result/success view (locate in import flow)
```

### Files Affected
- Video import result view (needs location identification)

### Captures Needed
- `CAP_12_VIDEO_RESULT`: Video import result showing source badge

---

## TASK 13: Discover Card Redesign

**Goal:** Add creator name, lineage indicator, and "Private by default" chip to Discover cards.

**Positioning Pillar:** Trust / Attribution / Discovery

### Claude Code Prompt

```
Redesign public recipe cards in Discover view:

1. Update Discover card component (likely DiscoveryView.swift or a card component):

2. Add creator attribution:
   - Position: Below recipe title
   - Format: "by [Creator Name]" or "@username"
   - Smaller font, secondary color
   - Link to creator's public profile if available

3. Add lineage indicator (if recipe has been saved/shared):
   - Small icon: person.2.fill or similar
   - Text: "Saved by X people" (if applicable)
   - Or "Original" badge for first-generation recipes

4. Add privacy chip in corner:
   - Small pill badge: "Public"
   - Subtle, non-intrusive
   - Communicates this is public content

5. Recipe card structure:
   - Image (top)
   - Title (bold)
   - Creator name (by @username)
   - Metadata row: time | servings | [Public] chip
   - Lineage indicator (if applicable)

6. Ensure styling matches warm Heirloom aesthetic

Files to modify:
- Heirloom/Features/Discovery/DiscoveryView.swift
- Public recipe card components
```

### Files Affected
- `Heirloom/Features/Discovery/DiscoveryView.swift`
- Public recipe card components

### Captures Needed
- `CAP_13_DISCOVER_CARD`: Redesigned Discover card with attribution

---

## TASK 14: Publishing Rules UI Copy

**Goal:** Add visible copy about ownership requirements throughout publishing flows.

**Positioning Pillar:** Trust contract / Transparency

### Claude Code Prompt

```
Add clear publishing rules copy to Discover and Publish flows:

1. In DiscoveryView.swift header or info section:
   - Add info button or banner
   - Opens sheet explaining: "What can I publish?"
   - Content:
     - "Your own recipes photographed from handwritten cards or cookbooks"
     - "Recipes you've created yourself"
     - "NOT: Website imports, video conversions, or AI-generated recipes"

2. In PublishRecipeSheet.swift:
   - Add explanatory text in the validation section
   - When showing why something can't be published, include:
     - Clear reason
     - What COULD be published
     - Link to learn more

3. Create an info sheet component:
   - Heirloom/Features/Discovery/PublishingRulesSheet.swift
   - Explains the full publishing policy
   - Referenced from multiple places

4. Microcopy additions:
   - In Discover header: "Recipes from the community"
   - In Discover empty state: "Share your family recipes with the world"
   - In recipe menu: "Share publicly..." with subtitle "Your own recipes only"

Files to create:
- Heirloom/Features/Discovery/PublishingRulesSheet.swift

Files to modify:
- Heirloom/Features/Discovery/DiscoveryView.swift
- Heirloom/Features/Discovery/PublishRecipeSheet.swift
- Recipe detail menu (where "Share publicly" option lives)
```

### Files Affected
- `Heirloom/Features/Discovery/PublishingRulesSheet.swift` (new)
- `Heirloom/Features/Discovery/DiscoveryView.swift`
- `Heirloom/Features/Discovery/PublishRecipeSheet.swift`

### Captures Needed
- `CAP_14_PUBLISHING_RULES`: Publishing rules info sheet

---

## Cross-Reference Summary

| Capture ID | Used In | Notes |
|------------|---------|-------|
| CAP_01 | SS_01, Landing page | Welcome screen |
| CAP_02 | SS_10 | Credits screen |
| CAP_03 | SS_02, /lp/scan | Share extension flow |
| CAP_04 | SS_07 | Share/Accept flow |
| CAP_05 | SS_08 | Privacy controls |
| CAP_06 | - | Quick Start (internal) |
| CAP_07 | SS_01 | Collections view |
| CAP_08 | - | Attestation (internal) |
| CAP_09 | SS_09 | Ownership verification |
| CAP_10 | SS_06 | AI-generated badge |
| CAP_11 | SS_02 | Share toast |
| CAP_12 | SS_03 | Video import result |
| CAP_13 | SS_09 | Discover card |
| CAP_14 | - | Rules sheet (internal) |

---

## Implementation Order (Revised)

1. ~~**TASK 10** (generated sourceType)~~ - ✅ DONE
2. ~~**TASK 9** (publisherAttestationAcceptedAt)~~ - ✅ DONE
3. ~~**TASKS 1-5** (Onboarding screens)~~ - ✅ DONE
4. ~~**TASK 14** (Publishing rules copy)~~ - ✅ DONE

### Removed from Scope
- ~~TASK 6~~ (Quick Start) - Extra friction, not essential
- ~~TASK 7~~ (Inbox/coach marks) - Over-engineered for launch
- ~~TASK 8~~ (Scan attestation) - Heavy-handed, ownership verification is enough
- ~~TASK 11~~ (Share toast) - Nice-to-have polish
- ~~TASK 12~~ (Video polish) - Not essential
- ~~TASK 13~~ (Discover redesign) - Scope creep

---

## Testing Checklist

After implementation, verify:
- [ ] Onboarding flow completes without crashes
- [x] Generated recipes cannot be published publicly
- [x] Generated recipes CAN be shared P2P
- [x] Ownership verification shows before first publish
- [ ] Ownership verification shows before publishing
- [ ] Share extension shows collection name in toast
- [ ] Discover cards show creator attribution
- [ ] All animations are smooth and not jarring
