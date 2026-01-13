# Heirloom Feature Definition Guide
**Recipes Worth Passing Down**

**Version**: 1.1.4 (Build 20)
**Platform**: iOS 17+
**Last Updated**: January 13, 2026

---

## Executive Summary

Heirloom is a native iOS recipe management app that bridges analog and digital cooking traditions. The app combines powerful AI-driven recipe acquisition with deeply personal customization, creating a digital recipe box that feels as warm and lived-in as the handwritten recipe cards passed down through generations.

### Core Philosophy

**Preserve, Don't Replace**: Heirloom doesn't try to replace your grandmother's stained recipe card or your favorite dog-eared cookbook. Instead, it helps you bring those treasured recipes into the digital age while preserving their character, history, and emotional significance.

### What Makes Heirloom Different

1. **Intelligence Without Intrusion**: AI handles tedious tasks (parsing ingredients, scanning cookbooks, spell checking) so users can focus on cooking and customization.

2. **Personalization That Travels**: Coffee stains, handwritten notes, and sticker decorations sync across devices and travel with shared recipes, preserving the personal touch.

3. **Family Tree Tracking**: Unlike generic recipe apps, Heirloom tracks how recipes evolve across generations, showing who adapted what and when.

4. **No Subscription for Core Features**: Default AI key included (100 recipes/day), cross-device sync via Firebase, full feature access without monthly fees.

5. **Deterministic Progress**: No vague "Loading..." spinners. Users see exactly what's happening ("Optimizing image quality... 67%").

### Target Audience

- **Home cooks** who collect recipes from multiple sources (web, cookbooks, family, videos)
- **Recipe hoarders** with hundreds of bookmarked recipes across browsers and apps
- **Family historians** who want to preserve and share heritage recipes
- **Dinner party hosts** who need to plan multi-course meals with precise ingredient scaling
- **Cookbook enthusiasts** frustrated by manual recipe transcription

### Use Cases

1. **Digitizing Heritage**: Scan grandmother's handwritten recipe cards with OCR, add family stories as annotations
2. **Party Planning**: Plan a 6-course dinner party with automatic cooking timeline and consolidated shopping list
3. **Recipe Discovery**: Import recipes from any website with one tap, no manual copying
4. **Family Sharing**: Share your adapted lasagna recipe with cousins, track how each family branch modifies it
5. **Video Learning**: Convert TikTok cooking videos to structured recipes with ingredient quantities

---

## Feature Categories

# 1. Getting Started

## Sign in with Apple

**One-Line**: Seamless, privacy-first authentication using your Apple ID.

### Value Proposition

Sign in instantly using Face ID or Touch ID without creating yet another account or remembering another password. Apple doesn't share your real email with Heirloom (you can use a private relay), and your authentication is backed by Apple's industry-leading security. For users who value privacy and simplicity, this is the fastest path from download to cooking.

### How It Works

1. User downloads Heirloom from the App Store
2. On first launch, the authentication screen appears with "Sign in with Apple" button prominently displayed
3. User taps the button
4. iOS shows the standard Apple authentication sheet (Face ID / Touch ID prompt)
5. User authenticates with biometrics
6. Heirloom creates a Firebase account linked to the Apple ID
7. User lands on the main recipe library (empty state with quick-start tips)
8. On subsequent launches, the app instantly opens to the last viewed screen (no login required)

### Key Capabilities

- **One-tap authentication**: No email, no password, no forms
- **Private email relay**: Option to hide real email address from Heirloom
- **Biometric security**: Face ID / Touch ID for device-level protection
- **Persistent sessions**: Stay signed in across app launches indefinitely
- **Cross-device sync**: Same Apple ID works on iPhone and iPad with data sync
- **No password recovery needed**: Apple handles all credential management

### UX Story

"Emma downloads Heirloom after seeing a friend's beautifully customized recipe card. She taps 'Sign in with Apple,' glances at her phone for Face ID, and she's in. No forms, no email confirmation, no password to remember. Thirty seconds from download to browsing her first recipe collection. When she opens the app on her iPad that evening, she's already signed in and sees the three recipes she imported earlier on her iPhone."

### Visual Opportunities

- **Screenshot 1**: Clean authentication screen with "Sign in with Apple" button (emphasize simplicity)
- **Screenshot 2**: Apple authentication sheet with Face ID prompt (show seamless flow)
- **Video capture**: Download → Tap button → Face ID → Instant access (< 10 seconds end-to-end)
- **Before/After comparison**: Traditional signup form vs. one-tap Apple authentication

### Marketing Angles

- **Privacy differentiation**: "We never see your real email address. Apple handles everything."
- **Speed positioning**: "From download to cooking in 30 seconds, not 30 minutes."
- **Friction elimination**: "No password to remember. Your face is your key."
- **Apple ecosystem play**: "Made for iPhone and iPad. Built with Apple's latest security."

### Technical Notes

- Requires iOS 13+ (Heirloom targets iOS 17+, so this is always available)
- Firebase Authentication backend handles Apple ID tokens
- Session persists until user explicitly signs out
- Account linking: If user later signs in with Google using same email, accounts merge automatically
- Privacy relay emails end in `@privaterelay.appleid.com`

---

## Sign in with Google

**One-Line**: Multi-provider flexibility for users with existing Google accounts.

### Value Proposition

Not everyone uses an Apple device exclusively. For users who prefer Google services or share devices across Android and iOS ecosystems, Google authentication provides familiar one-tap access. This broadens Heirloom's reach to users who may not have an Apple ID or prefer consolidated identity management through Google.

### How It Works

1. User taps "Sign in with Google" button on authentication screen
2. iOS opens the Google authentication sheet (via GoogleSignIn SDK)
3. User selects their Google account from the list or enters credentials
4. Google returns authentication token
5. Heirloom creates Firebase account linked to Google ID
6. User lands on main recipe library
7. Sessions persist across launches like Apple authentication

### Key Capabilities

- **One-tap authentication**: Choose from logged-in Google accounts
- **Familiar flow**: Same Google authentication users see in Gmail, YouTube, etc.
- **Cross-platform potential**: Same credentials work if Android version launched in future
- **Account consolidation**: Links with Apple ID if same email is used
- **Profile photo sync**: Optional profile picture from Google account
- **Persistent sessions**: Stay signed in indefinitely

### UX Story

"Marcus uses a work iPhone but his personal devices are all Android. He wants recipes available everywhere. He taps 'Sign in with Google,' selects his personal Gmail account, and he's ready to import recipes. When his family eventually gets the Android version, his entire recipe library will already be there, synced via Firebase."

### Visual Opportunities

- **Screenshot 1**: Authentication screen showing both Apple and Google options (user choice)
- **Screenshot 2**: Google account picker showing multiple accounts
- **Screenshot 3**: Confirmation screen after successful Google sign-in
- **Comparison shot**: Side-by-side Apple vs. Google sign-in (both one-tap)

### Marketing Angles

- **Inclusivity**: "Whatever account you prefer, Heirloom welcomes you."
- **Cross-platform readiness**: "Today's iPhone user might be tomorrow's Android user. Your recipes go where you go."
- **Choice positioning**: "We don't lock you into one identity provider. You choose."
- **Flexibility**: "Switching from Apple to Google? Your recipes stay with you."

### Technical Notes

- Requires `REVERSED_CLIENT_ID` in Config.xcconfig (from Firebase Console)
- GoogleSignIn-iOS SDK handles OAuth flow
- Firebase automatically merges accounts if email matches across providers
- Session tokens refresh automatically in background
- Works on iOS 12+ (exceeds Heirloom's iOS 17+ requirement)

---

## Session Persistence

**One-Line**: Instant app access on every launch - no repeated logins required.

### Value Proposition

Heirloom remembers you. Unlike apps that log you out after a week or require re-authentication for security theater, Heirloom trusts your device-level security (Face ID, passcode). Open the app, start cooking. No friction, no delays, no "Forgot password?" links. This is especially important for a cooking app—when your hands are covered in flour, you need instant access, not a login prompt.

### How It Works

1. User signs in once with Apple or Google
2. Firebase generates a persistent authentication token
3. Token is stored in iOS Keychain (encrypted, secure)
4. On subsequent app launches, Firebase checks for valid token
5. If token exists and hasn't been revoked, user is instantly authenticated
6. App opens to last viewed screen (recipe detail, shopping list, etc.)
7. Token refreshes automatically in background, never expires unless user signs out

### Key Capabilities

- **Indefinite sessions**: Never logs out unless user explicitly chooses to
- **Instant cold start**: From app icon tap to recipe view in < 1 second
- **Secure storage**: Authentication tokens in iOS Keychain, not accessible to other apps
- **Background refresh**: Token validity checked silently, user never sees this
- **Graceful degradation**: If session expires (rare), user sees authentication screen with explanation
- **Multi-device consistency**: Same session behavior on iPhone and iPad

### UX Story

"Sophie is making her grandmother's pie crust. She opens Heirloom while measuring flour, checks the ingredient ratio, then minimizes the app to set a timer. An hour later, she opens Heirloom again to check baking temperature. Instant access both times. The next morning, she opens the app on her iPad to browse for dinner ideas. Still signed in. Three weeks later, same instant access. She's never seen a login screen since that first day."

### Visual Opportunities

- **Video capture**: Close Heirloom, wait a few days, open again → instant access (time-lapse style)
- **Screenshot sequence**: App icon → Recipe library (< 1 second transition)
- **Comparison**: Heirloom instant access vs. competitor app requiring re-login
- **Security visualization**: iOS Keychain icon + encrypted token diagram (for technical audiences)

### Marketing Angles

- **Friction elimination**: "Your recipes, instantly available. Always."
- **Trust positioning**: "We trust your device security, so you can trust us with your recipes."
- **Cooking context**: "No typing passwords with flour-covered hands."
- **Reliability**: "Opened Heirloom 100 times this month? Logged in once."

### Technical Notes

- iOS Keychain storage with `kSecAttrAccessibleAfterFirstUnlock` attribute
- Firebase Authentication handles automatic token refresh
- Sessions persist through app updates and iOS updates
- Device-level security (Face ID / passcode) protects Keychain data
- User can explicitly sign out from Settings if sharing device
- Session survives app deletion and reinstallation (if iCloud Keychain enabled)

---

# 2. Recipe Acquisition

## Web Import from 500+ Sites

**One-Line**: Import any web recipe with one tap—no copying, no pasting.

### Value Proposition

The average home cook has recipes bookmarked across dozens of websites, buried in browser tabs, or saved in read-it-later apps. Heirloom brings them all together in one beautiful, ad-free, standardized format. No more scrolling past life stories to find ingredients. No more ads blocking the recipe. No more losing recipes when websites redesign or shut down. Import from AllRecipes, NYT Cooking, Serious Eats, Bon Appétit, food blogs, or virtually any recipe site—Heirloom extracts the structured data and saves it permanently.

### How It Works

1. User finds a recipe on any website (Safari, Chrome, in-app browser)
2. User copies the URL or uses the Share Extension (see next section)
3. In Heirloom, user taps "+" → "Import from URL"
4. User pastes the URL into the text field
5. Heirloom sends URL to Cloud Function (Firebase) for parsing
6. Cloud Function analyzes the page:
   - Checks for JSON-LD structured data (schema.org Recipe format)
   - Falls back to site-specific parsers for known sites (NYT Cooking, AllRecipes, etc.)
   - Falls back to microdata parsing if needed
7. Cloud Function returns structured recipe data (title, ingredients, instructions, image, etc.)
8. Heirloom shows preview of extracted data
9. User reviews and taps "Save"
10. Recipe appears in library with image, ready to customize

**Fallback**: If Cloud Function fails (rate limit, network error), Heirloom automatically tries local HTML parsing as backup.

### Key Capabilities

- **500+ supported sites**: All major recipe sites plus thousands of food blogs
- **Smart parsing**: Prioritizes JSON-LD (most reliable) → site-specific parsers → microdata
- **Image extraction**: Captures high-resolution recipe photo from page
- **Metadata capture**: Servings, prep time, cook time, author, source attribution
- **Paywall handling**: Detects paywalled sites (NYT Cooking) and notifies user
- **Bulk import**: Paste multiple URLs at once (see Bulk Import section)
- **Import history**: Track all imports with success rate and confidence scores
- **Local fallback**: Never fails completely—always tries local parser if cloud fails

### UX Story

"Liam has 47 recipe tabs open in Safari and 200+ bookmarks in his "Recipes" folder. He discovers Heirloom and spends an evening importing his collection. He opens each tab, taps Share → Heirloom, and watches each recipe appear perfectly formatted in seconds. NYT Cooking recipes? Imported. His favorite food blogger? Imported. Even his aunt's recipe on her Blogspot from 2008? Imported. By the end of the night, he's closed all 47 tabs, cleared his bookmarks, and has a beautifully organized digital recipe box with zero ads."

### Visual Opportunities

- **Screenshot 1**: URL import field with example URL
- **Screenshot 2**: Loading state with parsed preview (before/after)
- **Screenshot 3**: Saved recipe in library (clean, ad-free)
- **Video capture**: Find recipe on web → Copy URL → Paste in Heirloom → Preview → Save (< 30 seconds)
- **Before/After comparison**: Cluttered recipe website vs. clean Heirloom recipe card
- **Grid view**: Collection of imported recipes from various sources

### Marketing Angles

- **Ad elimination**: "All the recipes, none of the ads."
- **Consolidation**: "47 browser tabs → one beautiful app."
- **Permanence**: "Websites shut down. Your recipes live forever."
- **Format standardization**: "Every recipe looks consistent, no matter where it came from."
- **Time savings**: "Import in 10 seconds what would take 5 minutes to copy-paste."

### Technical Notes

- Cloud Function endpoint: `https://importrecipe-7kk7et3yua-uc.a.run.app`
- Requires Premium subscription (soft paywall—free tier allows limited imports)
- Local fallback parser uses SwiftSoup for HTML parsing
- Supports JSON-LD schema.org Recipe vocabulary
- Handles recipe sites with anti-scraping measures (mobile user-agent, timeout handling)
- Imports are tracked in analytics for accuracy monitoring
- Average confidence score: 0.85-0.95 for structured sites, 0.60-0.75 for blogs

---

## Share Extension (Import from Safari)

**One-Line**: Import recipes without leaving your browser—one tap from any website.

### Value Proposition

Context switching kills momentum. Finding a recipe, copying the URL, opening Heirloom, pasting—that's four steps. The Share Extension collapses this to one: tap Share → Heirloom. Done. The recipe imports in the background while you continue browsing. Perfect for recipe discovery sessions where you're browsing multiple sites and want to quickly save interesting finds without breaking your flow.

### How It Works

1. User finds a recipe on any website in Safari (or any browser that supports Share Sheets)
2. User taps the Share button (square with arrow)
3. iOS shows Share Sheet with app icons
4. User taps "Heirloom" icon
5. Share Extension launches in overlay (doesn't leave browser)
6. Extension extracts URL from current page
7. Extension shows "Importing..." progress indicator
8. Extension sends URL to Heirloom's Cloud Function (same as manual import)
9. Recipe is imported and saved to library
10. Extension shows "Saved!" confirmation
11. User dismisses extension and continues browsing
12. Later, user opens Heirloom and finds recipe waiting in library

### Key Capabilities

- **One-tap import**: Share button → Heirloom → Done (3 taps total)
- **Background processing**: Import happens while you continue browsing
- **Universal compatibility**: Works in Safari, Chrome, Firefox, in-app browsers
- **Batch workflow**: Import 10 recipes in 2 minutes without leaving browser
- **Error handling**: If import fails, extension notifies user with retry option
- **URL pre-population**: No copying, no pasting—extension auto-extracts URL
- **Toast notification**: Small success message doesn't block browsing

### UX Story

"Maya is planning next week's dinner parties and finds herself on a food blog deep dive. She discovers 12 amazing recipes across 5 different sites. Instead of bookmarking them all (and forgetting about them), she taps Share → Heirloom on each recipe. By the time she's done browsing 20 minutes later, all 12 recipes are in her Heirloom library, fully formatted, images downloaded, ready to organize into her 'Dinner Party Ideas' collection. She never left Safari once."

### Visual Opportunities

- **Screenshot 1**: Safari showing recipe with Share Sheet overlay
- **Screenshot 2**: Heirloom Share Extension overlay with progress indicator
- **Screenshot 3**: Success confirmation in extension
- **Video capture**: Browse recipe → Tap Share → Tap Heirloom → Continue browsing (seamless flow)
- **Split-screen**: Safari on left, Heirloom on right showing recipe appearing
- **Animation**: Recipe "flying" from browser into Heirloom app (metaphorical)

### Marketing Angles

- **Flow preservation**: "Don't break your recipe discovery flow. Save and keep browsing."
- **Speed**: "Found 12 recipes in 20 minutes. Saved all 12 without opening Heirloom once."
- **Convenience**: "The Share button you already use, now imports recipes instantly."
- **Batch efficiency**: "Import now, organize later. Perfect for recipe browsing sessions."

### Technical Notes

- iOS Share Extension target with access to shared URLs (`UTType.url`)
- App Groups entitlement for data sharing between extension and main app
- Extension uses same Cloud Function as main app import
- Extension has 10MB memory limit (iOS restriction)
- Deep link opens main app if needed for complex imports
- Extension appears in Share Sheet after first use (iOS learns user preference)
- Works on iOS 13+ (Heirloom targets iOS 17+)

---

## Bulk Import

**One-Line**: Paste 50 URLs at once—import your entire recipe backlog in minutes.

### Value Proposition

You have 200 bookmarked recipes. Importing them one by one would take an hour. Bulk Import takes 5 minutes. Perfect for the initial migration from browser bookmarks, recipe apps, or email collections. Paste any list of URLs (comma-separated, line-separated, even mixed with text), let Heirloom extract and clean them, then import everything in parallel with progress tracking. It's the difference between "I should do this someday" and "I did this tonight."

### How It Works

1. User exports bookmarks from browser or copies URLs from old recipe app
2. In Heirloom, user taps "+" → "Bulk Import"
3. User pastes the URL list into the text area (any format: commas, newlines, spaces, mixed with text)
4. Heirloom's `URLNormalizer.extractURLs()` finds all URLs automatically
5. Heirloom shows preview: "Found 47 URLs" with list view
6. User optionally taps "Clean Up" to remove duplicates or non-recipe URLs
7. User taps "Start Import"
8. `ImportJobManager` handles parallel imports:
   - Shows overall progress (23 / 47 complete)
   - Shows per-recipe progress (importing, success, failed)
   - Respects API rate limits (doesn't overload server)
9. Import continues in background if user navigates away
10. Completion notification shows: "42 recipes imported, 5 failed"
11. User can tap failed recipes to retry individually

### Key Capabilities

- **Auto URL extraction**: Paste any text, Heirloom finds URLs automatically
- **Format flexibility**: Supports comma-separated, line-separated, space-separated, or mixed
- **URL normalization**: Adds `https://` if missing, handles shortened URLs
- **Duplicate detection**: "Clean Up" button removes duplicate URLs
- **Parallel processing**: Imports 5-10 recipes simultaneously (respects rate limits)
- **Progress tracking**: Real-time status for each recipe (pending, importing, success, failed)
- **Failure recovery**: Failed imports can be retried without restarting entire batch
- **Background operation**: Import continues if user leaves screen or minimizes app
- **Cost awareness**: Shows estimated API cost before starting (for users with custom keys)

### UX Story

"Carlos has 156 recipes bookmarked in Chrome over 3 years. He exports his bookmarks to a text file, opens it, selects all, and copies. In Heirloom's Bulk Import screen, he pastes the giant wall of text. Heirloom instantly says 'Found 156 URLs.' He taps 'Clean Up' and it removes 8 duplicates. He taps 'Start Import' and watches the progress bar fill up over the next 10 minutes. He makes a coffee. When he comes back, 149 recipes are in his library, 7 failed (paywalled sites). He retries the 7 manually later. His entire 3-year collection is now in Heirloom, organized and ad-free."

### Visual Opportunities

- **Screenshot 1**: Text area with messy pasted URLs
- **Screenshot 2**: "Found 156 URLs" confirmation with preview list
- **Screenshot 3**: Progress screen showing individual recipe statuses
- **Screenshot 4**: Success summary with statistics
- **Video capture**: Paste giant text blob → Extract URLs → Import progress → Success (time-lapse)
- **Before/After**: 156 browser bookmarks → 149 organized Heirloom recipes

### Marketing Angles

- **Migration made easy**: "Moving from browser bookmarks? Import everything in one go."
- **Time savings**: "1 hour of manual work → 5 minutes of automated import."
- **Intelligent parsing**: "Just paste. We'll figure out the rest."
- **Perfect for new users**: "Import your entire collection on day one."

### Technical Notes

- Uses `ImportJobManager` service for parallel processing with concurrency limits
- Default concurrency: 5 simultaneous imports (configurable)
- URL extraction regex: `https?://[^\s]+` with normalization
- Rate limiting: Respects Cloud Function quotas (1000 imports/day for free tier)
- Failed imports include error messages (paywall, network, invalid HTML, etc.)
- Import history saved with batch ID for analytics
- Background processing uses `URLSession` with background configuration
- Progress updates via `@Published` properties for SwiftUI reactivity

---

## Cookbook Scanning (OCR)

**One-Line**: Photograph any cookbook page—AI extracts recipes with ingredients and instructions.

### Value Proposition

Your most treasured recipes live in physical cookbooks: grandmother's handwritten cards, vintage Betty Crocker, stained church fundraiser collections. Manually typing these recipes takes 10-15 minutes each. Cookbook scanning takes 30 seconds. Take a photo, watch Heirloom's AI extract the structured recipe, review and save. The original stays pristine on your shelf; the digital copy lives in your pocket forever. Perfect for preserving heritage recipes before the ink fades or the paper crumbles.

### How It Works

1. User taps "+" → "Scan Cookbook"
2. Camera opens with capture guidance overlay
3. User frames the cookbook page (real-time quality feedback shows if lighting/focus is good)
4. User taps capture button
5. **Image preprocessing** begins with deterministic progress:
   - Phase 1 (2s): "Optimizing image quality..." (perspective correction, contrast enhancement, sharpening)
   - Phase 2 (3s): "Detecting recipes..." (AI identifies recipe boundaries on page)
   - Phase 3 (4s): "Extracting recipe details..." (OCR + Claude extracts title, ingredients, instructions)
6. If multiple recipes detected (e.g., vintage cookbook page with 3 recipes), user selects which to import
7. Heirloom shows structured preview with extracted data
8. User reviews and corrects any OCR errors (AI spell checker suggests fixes)
9. User taps "Save" → Recipe appears in library with original photo

**Technical magic**: PNG-first processing (lossless) for maximum OCR accuracy, then JPEG compression only if needed. Claude Sonnet 4 vision model analyzes image directly instead of relying solely on basic OCR.

### Key Capabilities

- **Multi-recipe detection**: Identifies 2-6 recipes on single page (vintage cookbooks)
- **Handwritten text support**: Works with cursive handwriting (accuracy varies by legibility)
- **Quality feedback**: Real-time overlay shows lighting/focus issues before capture
- **Image preprocessing**: Auto-corrects perspective, enhances contrast, reduces noise
- **PNG-first OCR**: Preserves maximum detail for text recognition
- **Vision-powered extraction**: Claude Sonnet 4 "reads" images like a human, handling unusual formats
- **Spell checking integration**: Suggests corrections for OCR errors in ingredients
- **Original photo retention**: Saves scanned image alongside structured data
- **Batch scanning**: Take 10 photos, process them all in queue
- **Deterministic progress**: No vague spinners—shows exact steps with percentages

### UX Story

"Yuki's grandmother passed away, leaving behind 3 handwritten recipe notebooks spanning 40 years. Yuki wants to preserve them digitally before the ink fades further. Over a weekend, she photographs each page in Heirloom. The app extracts 87 recipes with surprising accuracy—even grandmother's cursive handwriting. Yuki reviews each one, fixing a few OCR mistakes (Claude flagged most of them automatically). Now the recipes are preserved forever, organized by cuisine and occasion, with grandmother's original handwriting visible in the photos. When Yuki's cousins ask for copies, she shares the digital versions—complete with the original images and family stories she added as annotations."

### Visual Opportunities

- **Screenshot 1**: Camera view with guidance overlay and quality indicators
- **Screenshot 2**: Progress screen showing "Detecting recipes... 58%"
- **Screenshot 3**: Multi-recipe selection screen (vintage page with 3 recipes detected)
- **Screenshot 4**: Extracted recipe preview with original photo thumbnail
- **Screenshot 5**: Side-by-side comparison of handwritten original vs. extracted text
- **Video capture**: Photograph cookbook → AI extraction process → Review → Save (60 seconds time-lapse)
- **Before/After**: Physical cookbook collection → Digital recipe library

### Marketing Angles

- **Heritage preservation**: "Digitize grandmother's recipes before they fade."
- **Time savings**: "10 minutes of typing → 30 seconds of photography."
- **AI accuracy**: "Reads even grandma's cursive. Spell checks it too."
- **Permanence**: "Paper decays. Digital lasts forever."
- **Family sharing**: "One scan, endless digital copies for all the cousins."

### Technical Notes

- Uses Apple Vision framework (`VNRecognizeTextRequest`) for OCR
- Claude Sonnet 4 (`claude-sonnet-4-20250514`) for vision-based extraction
- Recognition level: `.accurate` (slower but better for handwriting)
- Supports English language (multi-language coming soon)
- PNG-first strategy: Tries PNG (lossless), falls back to JPEG 95% quality if file > 5MB
- Image preprocessing: Perspective correction, contrast 1.3x, noise reduction, sharpening
- Quality assessment: Brightness, sharpness, contrast analysis → recommendations
- Cost: ~$0.02 per image with Claude Sonnet 4 (covered by default API key)
- Batch processing: Queues up to 20 images with progress tracking

---

## Video-to-Recipe Import

**One-Line**: Convert YouTube, TikTok, or Instagram cooking videos into structured recipes.

### Value Proposition

Social media cooking content is exploding—TikTok recipe videos, YouTube tutorials, Instagram reels. But watching a 5-minute video to find one ingredient measurement is frustrating. Heirloom extracts the recipe from the video transcript, uses AI to structure ingredients and instructions, and even detects the creator's username from watermarks for attribution. Save viral recipes as permanent, searchable text instead of scrolling through your saves folder trying to remember which video had the buffalo cauliflower.

### How It Works

1. User finds a cooking video on YouTube, TikTok, Instagram, or any platform
2. User copies the video URL or uses Share Extension
3. In Heirloom, user taps "+" → "Import from Video"
4. User pastes URL (or Share Extension auto-fills it)
5. Heirloom downloads video audio (or transcript if available)
6. **WhisperKit** (Apple's on-device speech recognition) transcribes audio to text
7. **Claude analyzes transcript** to extract recipe structure:
   - Title (what's being cooked)
   - Ingredients with quantities
   - Step-by-step instructions
   - Cooking times and temperatures
8. **Vision API analyzes video frames** for watermarks:
   - Detects creator username (@username)
   - Identifies platform (TikTok, YouTube, Instagram icons)
9. **Recipe augmentation service** searches web for similar recipes to verify quantities (TikTok videos often skip exact measurements)
10. Heirloom shows extracted recipe with confidence indicators:
    - High confidence (green): "1 cup flour" explicitly stated
    - Medium confidence (yellow): "A cup of flour" → normalized to "1 cup"
    - Low confidence (orange): "Some flour" → AI estimated based on similar recipes
11. User reviews, edits, and saves
12. Recipe includes clickable creator attribution link (e.g., "@gordonramsay on TikTok")

### Key Capabilities

- **Multi-platform support**: YouTube, TikTok, Instagram, Vimeo, Facebook
- **On-device transcription**: WhisperKit runs locally (private, fast, works offline)
- **Multi-language detection**: Auto-detects video language (English, Spanish, French, etc.)
- **Smart quantity extraction**: Handles casual speech ("a bit of salt" → "1/4 tsp salt")
- **Recipe augmentation**: Searches web to validate quantities against similar recipes
- **Watermark detection**: Extracts creator username and platform from video frames
- **Creator attribution**: Clickable links to creator profile
- **Confidence indicators**: Color-coded trust levels for each ingredient
- **Substitution tracking**: Captures "or you could use..." suggestions
- **Multi-recipe detection**: If video includes 2 recipes, extracts both
- **Cost-optimized**: WhisperKit is free (on-device), Claude calls are batched efficiently

### UX Story

"Priya scrolls TikTok and finds an amazing 60-second butter chicken recipe with 2M likes. The chef rattles off ingredients quickly and never shows quantities on screen. She taps Share → Heirloom. Thirty seconds later, Heirloom shows her a structured recipe with all ingredients listed (including '2 tbsp butter' that the chef only said verbally). The quantities are flagged with confidence levels: butter is high confidence (explicitly stated), garam masala is medium confidence (inferred from context). The recipe credits '@chefmeena' with a link back to her TikTok. Priya saves it, makes it that night, and it's perfect. She never has to scrub through the video again to find the butter measurement."

### Visual Opportunities

- **Screenshot 1**: Video URL import screen
- **Screenshot 2**: Transcription progress with WhisperKit indicator
- **Screenshot 3**: Extracted recipe with confidence indicators (green/yellow/orange)
- **Screenshot 4**: Creator attribution card with clickable TikTok username
- **Screenshot 5**: Side-by-side comparison of video still vs. extracted recipe
- **Video capture**: Paste video URL → AI extraction → Review → Save (demo with popular TikTok recipe)
- **Animation**: Video frames "transforming" into structured recipe text

### Marketing Angles

- **Social media bridge**: "Turn viral videos into permanent recipes."
- **Quantity inference**: "We figure out the measurements even when creators don't mention them."
- **Creator respect**: "Full attribution with links back to the original creator."
- **Search**: "Find that buffalo cauliflower video from 3 months ago—instantly."
- **Privacy**: "Transcription happens on your device. Your cooking habits stay private."

### Technical Notes

- WhisperKit SDK for on-device speech-to-text (Apple's Core ML model)
- Claude Sonnet 4 for recipe structuring (~$0.01 per video transcript)
- Claude Vision API for watermark detection (~$0.01 per frame analyzed)
- Recipe augmentation via web search (optional, adds ~$0.01)
- Total average cost: $0.027 per 15-minute video
- Transcription speed: ~2x realtime (10-minute video transcribed in 5 minutes)
- Supports videos up to 30 minutes (longer videos chunked)
- Saved creator attribution includes: username, platform, video URL, detected logo
- Confidence scoring algorithm: explicit mention (1.0), implied (0.7), estimated (0.4)
- Augmentation uses similarity matching against 500K+ web recipes

---

## Manual Recipe Entry

**One-Line**: Traditional typing with AI assistance—spell check and parsing as you go.

### Value Proposition

Not every recipe exists online or in a scannable format. Sometimes you need to type it manually: recipes from cooking classes, grandmother's verbal instructions you transcribed, adjustments to existing recipes. Manual entry in Heirloom isn't just a plain text field—it's supercharged with AI assistance. Type ingredients and watch the spell checker suggest corrections in real-time. Type instructions and let AI parse quantities automatically. It's the baseline feature that makes everything else possible, done better than generic note-taking apps.

### How It Works

1. User taps "+" → "New Recipe"
2. Editor opens with structured form:
   - **Title** (required)
   - **Source type** dropdown: Manual / Family / Cooking Class / Restaurant / Other
   - **Photo** (optional, from camera or library)
   - **Ingredients** (list with AI spell check)
   - **Instructions** (numbered steps)
   - **Notes** (personal annotations)
   - **Metadata** (servings, prep time, cook time)
3. As user types ingredients, **AI spell checker runs** (debounced 1 second after typing stops):
   - "fower" → Suggests "flour"
   - "teasp" → Suggests "tsp"
   - Confidence scores shown as inline badges
4. User can tap suggestions to auto-correct
5. When user types instructions, AI detects implicit quantities and offers to add to ingredients:
   - "Mix in 2 cups flour" → Suggests adding "2 cups flour" to ingredient list
6. User taps "Save" → Recipe is inserted into SwiftData and syncs to Firebase

### Key Capabilities

- **Structured form**: Not a blank canvas—organized fields guide user
- **AI spell checking**: Real-time ingredient validation with suggestions
- **Smart quantity detection**: Finds quantities in instructions and offers to add as ingredients
- **Source attribution**: Track where recipe came from (family, class, restaurant, etc.)
- **Photo support**: Add recipe photo from camera or library
- **Auto-save drafts**: Work in progress saved automatically every 30 seconds
- **Rich text notes**: Supports basic formatting in notes field
- **Ingredient reordering**: Drag to reorder ingredients in list
- **Instruction numbering**: Auto-numbers steps, user just types
- **Duplicate detection**: Warns if similar recipe title already exists

### UX Story

"David takes a pasta-making class. The chef shares a carbonara recipe verbally while demonstrating. David opens Heirloom on his phone and starts typing ingredients as the chef calls them out. He types 'peccorino romano' wrong ('pecorino romano'), but Heirloom's spell checker flags it with a suggestion. He taps the fix. He types the instructions step-by-step. When he types 'Add 4 egg yolks,' Heirloom suggests adding '4 egg yolks' to the ingredient list. He taps 'Add.' By the end of class, the recipe is complete, spell-checked, and organized. He adds a photo of his finished dish and saves."

### Visual Opportunities

- **Screenshot 1**: Clean editor form with structured fields
- **Screenshot 2**: Ingredient field with spell check suggestion bubble
- **Screenshot 3**: Instruction parsing suggestion ("Add to ingredients?")
- **Screenshot 4**: Completed manual recipe with photo
- **Video capture**: Type ingredients with typos → See suggestions → Accept → Type instructions → Save

### Marketing Angles

- **Enhanced baseline**: "Manual entry, supercharged with AI."
- **Spell check trust**: "Never type 'cinamon' wrong again."
- **Smart parsing**: "We catch quantities even in your instructions."
- **Cooking class companion**: "Perfect for capturing recipes as chefs teach them."

### Technical Notes

- Uses `AIIngredientSpellChecker` service with Claude Haiku (fast, cheap)
- Spell check debounced to 1 second after typing stops (prevents API spam)
- Confidence threshold: 0.7 (only shows high-confidence suggestions)
- Quantity detection regex: `\d+[\s\/]*\w+\s+\w+` (captures "2 cups flour", "1/2 tsp salt", etc.)
- Auto-save interval: 30 seconds (uses `Timer` publisher)
- Draft storage in SwiftData with `isDraft` flag
- HTML sanitization on all text inputs (`HTMLSanitizer.shared.stripAllHTML()`)
- Image storage via `ImageStorageService` (file system, not database)

---

# 3. AI Intelligence

## Ingredient Parsing

**One-Line**: Extract quantity, unit, and name from messy ingredient text automatically.

### Value Proposition

Recipes don't follow standard formats. One recipe says "2 cups all-purpose flour, sifted." Another says "flour (all purpose) - 2c." Parsing this manually is tedious. Heirloom's AI parser normalizes all ingredient strings into structured data: quantity (2), unit (cup), name (all-purpose flour). This enables accurate recipe scaling (double servings = 4 cups flour), shopping list consolidation (two recipes need flour = combined amount), and smart search (find all recipes with "flour"). Users never see this magic happening—it just works.

### How It Works

1. When recipe is imported (web, OCR, video, manual), ingredient text arrives as raw strings:
   - "2 cups all-purpose flour, sifted"
   - "1/2 teaspoon salt"
   - "3 eggs, beaten"
2. Heirloom sends ingredient strings to `AIIngredientParser` service
3. **Claude Haiku analyzes text** (temperature 0.3 for consistency):
   - Extracts quantity: 2, 0.5, 3
   - Extracts unit: cup, teaspoon, (none for eggs)
   - Extracts name: all-purpose flour, salt, eggs
   - Removes descriptors: "sifted", "beaten" → saved as modifiers
4. Parser handles special cases:
   - Fractions: "1/2" → 0.5, "2 1/4" → 2.25
   - Ranges: "2-3 cups" → quantity=2, quantityMax=3
   - Alternatives: "butter or margarine" → name="butter", notes="or margarine"
   - Conversions: "tbsp" → "tablespoon", "oz" → "ounce"
5. Parsed data is stored in `Ingredient` model (linked to Recipe)
6. User sees clean ingredient list in recipe view
7. When scaling recipe (2x servings), quantities auto-adjust (2 cups → 4 cups)

**Fallback**: If AI parsing fails, uses regex-based `IngredientParser` for basic extraction.

### Key Capabilities

- **Fraction parsing**: Converts "1/2", "3/4", "2 1/4" to decimals
- **Range handling**: "2-3 cups" → stores min and max
- **Unit normalization**: "tbsp" → "tablespoon", "c" → "cup"
- **Name extraction**: Removes descriptors, preserves core ingredient
- **Alternative detection**: "butter or margarine" → captures both
- **Descriptor separation**: "sifted", "diced", "beaten" stored separately
- **Batch processing**: Parses up to 4 ingredients in single API call (efficiency)
- **Smart fallback**: AI failure → regex parser (always gets something)
- **Cost optimization**: Uses Haiku (fast, $0.25/1M tokens) not Sonnet

### UX Story

"Rachel imports a cake recipe from a vintage cookbook. The ingredients say '2c sugar', '1/2c butter (softened)', and 'flour - 3 cups'. Heirloom's AI parser converts these to structured data: 2 cups sugar, 0.5 cups butter, 3 cups flour. When Rachel scales the recipe to make 2 cakes, the quantities automatically update: 4 cups sugar, 1 cup butter, 6 cups flour. When she adds this recipe to her shopping list alongside a cookie recipe that also needs flour, Heirloom consolidates: '5 cups flour total (3 for cake, 2 for cookies).' Rachel never had to manually parse or calculate anything."

### Visual Opportunities

- **Diagram**: Messy ingredient text → AI parser → Structured data (quantity/unit/name)
- **Screenshot 1**: Raw imported ingredient list (before parsing)
- **Screenshot 2**: Clean parsed ingredient list (after parsing)
- **Screenshot 3**: Recipe scaling showing auto-updated quantities
- **Screenshot 4**: Shopping list consolidation showing combined flour amounts
- **Animation**: Ingredient string "transforming" into structured fields

### Marketing Angles

- **Invisible magic**: "You never see it working, but every recipe scales perfectly."
- **Accuracy**: "Handles fractions, ranges, and weird vintage formats."
- **Universal compatibility**: "Works with recipes from any source, any format."
- **Shopping intelligence**: "Enables smart list consolidation and auto-calculations."

### Technical Notes

- Service: `AIIngredientParser` (Claude Haiku model)
- Temperature: 0.3 (low for consistent parsing)
- Batch size: Up to 4 ingredients per API call
- Timeout: 30 seconds single, 60 seconds batch
- Fallback: Regex-based parser with pattern matching
- Success rate: ~92% with AI, ~78% with regex fallback
- Cost: ~$0.0001 per ingredient (negligible)
- Regex patterns: `(\d+[\s\/\d]*)\s*([a-z]+)?\s+(.+)` (simplified example)
- Analytics tracked: success rate, has_quantity, has_unit flags

---

## Real-Time Spell Checking

**One-Line**: As-you-type ingredient suggestions catch typos before you save.

### Value Proposition

Typos in recipes are embarrassing and can cause actual cooking failures. "Cinamon" instead of "cinnamon" is obvious, but "baking power" instead of "baking powder" could ruin a cake. Heirloom's spell checker flags these as you type and suggests corrections with explanations. It runs only on ingredients (not instructions) to avoid false positives, uses AI that understands food context (not generic spell check), and shows suggestions inline so you can accept or ignore with one tap. This makes manual recipe entry and OCR correction fast and accurate.

### How It Works

1. User types ingredient in editor (manual entry or OCR correction)
2. After user stops typing for 1 second (debounced), spell checker activates
3. Ingredient text sent to `AIIngredientSpellChecker` service
4. **Claude Haiku analyzes text** (temperature 0.2, very low for consistency):
   - Detects misspellings: "fower" → "flour", "suger" → "sugar"
   - Detects wrong abbreviations: "tbs" → "tbsp", "teasp" → "tsp"
   - Detects common typos: "reciepe" → "recipe", "cinamon" → "cinnamon"
   - Provides reason: "Common misspelling", "Incorrect abbreviation"
   - Assigns confidence: 0.0-1.0 (only shows suggestions > 0.7)
5. Suggestion appears inline as small badge next to ingredient field
6. User taps badge to see details (original, correction, reason)
7. User taps "Fix" to auto-correct or "Ignore" to dismiss
8. Correction is applied and ingredient list is updated
9. Brand names and proper nouns are preserved (e.g., "Kraft" not corrected to "craft")

**Smart batching**: If user types 3+ ingredients quickly, spell checker batches them into single API call for efficiency.

### Key Capabilities

- **Debounced checking**: Waits 1 second after typing stops (prevents API spam)
- **Food context**: Knows "cilantro" not "cylinder", "turmeric" not "tumor"
- **Abbreviation knowledge**: "tsp" = teaspoon, "tbsp" = tablespoon, "oz" = ounce
- **Confidence filtering**: Only shows high-confidence suggestions (> 0.7)
- **Batch processing**: Multiple ingredients checked in single API call (efficient)
- **Brand name preservation**: "Hellmann's", "Kraft", "Bob's Red Mill" not corrected
- **Non-intrusive**: Suggestions are optional, user can ignore all
- **Reason explanations**: "Common misspelling", "Incorrect abbreviation", "Did you mean..."

### UX Story

"Tom is manually entering his mom's handwritten pie recipe. He types 'fower' instead of 'flour.' After 1 second, a small orange badge appears next to the ingredient: 'Did you mean flour?' He taps it and sees the explanation: 'Common misspelling.' He taps 'Fix' and the text updates to 'flour.' Later, he types 'teasp salt.' Another suggestion appears: 'tsp (teaspoon) is the standard abbreviation.' He fixes it. The recipe is saved with correct spellings and proper abbreviations, all without opening a dictionary."

### Visual Opportunities

- **Screenshot 1**: Ingredient field with typo and suggestion badge
- **Screenshot 2**: Expanded suggestion showing original, correction, and reason
- **Screenshot 3**: Before/after of corrected ingredient list
- **Screenshot 4**: Multiple suggestions at once (batch checking)
- **GIF animation**: Type typo → Wait 1 second → Badge appears → Tap fix → Text corrects

### Marketing Angles

- **Quality assurance**: "Never publish recipes with typos again."
- **Learning**: "Teaches you correct abbreviations as you type."
- **Food intelligence**: "Understands food context better than generic spell checkers."
- **Non-intrusive**: "Suggests fixes, never forces them."

### Technical Notes

- Service: `AIIngredientSpellChecker` (Claude Haiku)
- Temperature: 0.2 (very low for consistency)
- Debounce delay: 1 second (Combine `.debounce(for: 1, scheduler: DispatchQueue.main)`)
- Confidence threshold: 0.7 (filters low-confidence suggestions)
- Batch mode: 3+ ingredients use single API call
- Timeout: 30 seconds
- Cost: ~$0.0001 per ingredient (negligible)
- Analytics: tracks success rate, has_issues flag, suggestion count
- Preserves proper nouns via capitalization heuristic (capital + trademark symbols)

---

## Multi-Recipe Detection

**One-Line**: Identifies multiple recipes on single cookbook page—you choose which to save.

### Value Proposition

Vintage cookbooks pack 2-6 recipes per page to save paper. Scanning one page should capture all recipes, not just the first one. Heirloom's multi-recipe detection uses Claude's vision capabilities to identify recipe boundaries, extract each recipe separately, and let you import one or all. Perfect for church cookbooks, Betty Crocker classics, and Depression-era cookbooks where recipes are densely packed.

### How It Works

1. User scans cookbook page (see Cookbook Scanning section)
2. During "Detecting recipes..." phase, Claude Vision API analyzes image
3. AI identifies distinct recipes by looking for:
   - Title headers (different fonts, underlines, bold text)
   - Ingredient list boundaries (new ingredient section = new recipe)
   - Instruction separations (numbered steps restarting at 1)
   - Visual layout changes (columns, boxes, dividers)
4. For each detected recipe, AI creates bounding box (x%, y%, width%, height%)
5. Heirloom shows selection grid with thumbnails of each recipe
6. User taps recipes to select (single or multiple)
7. Selected recipes are extracted and imported as separate Recipe objects
8. Each recipe links back to same original scanned image

**Important**: AI is trained to distinguish recipe sections from single recipes:
- "Crust" and "Filling" = ONE recipe (pie), not two
- "For the dough" and "For the topping" = ONE recipe
- "Buffalo Wings" and "Fried Chicken" on same page = TWO recipes

### Key Capabilities

- **Boundary detection**: Identifies 2-6 recipes per page reliably
- **Smart section merging**: Knows "crust" + "filling" = one pie recipe
- **Confidence scoring**: Each detected recipe has confidence score (0-1)
- **Visual selection**: Thumbnail grid shows where each recipe is on page
- **Batch import**: Select all or subset of detected recipes
- **Shared image**: All recipes from same page link to one scanned image file
- **Fallback**: If detection fails, treats entire page as single recipe

### UX Story

"Linda scans a page from her 1950s Betty Crocker cookbook that has 4 dessert recipes in tiny print. Heirloom detects all 4: Apple Pie, Cherry Cobbler, Lemon Bars, and Vanilla Pudding. She sees a grid with 4 recipe thumbnails, each showing where it appears on the page. She taps Apple Pie and Lemon Bars (already made the others), then hits 'Import Selected.' Both recipes appear in her library, each with the full page photo attached. When she views Apple Pie later, she can still see the other recipes on the scanned page—helpful for context."

### Visual Opportunities

- **Screenshot 1**: Selection grid showing 4 detected recipes with bounding boxes
- **Screenshot 2**: Highlighted recipe boundaries overlaid on original scanned page
- **Screenshot 3**: Two imported recipes both showing same scanned page thumbnail
- **Video capture**: Scan page → Detection phase → Selection grid → Import multiple
- **Before/After**: Dense cookbook page → 4 separate clean recipe cards

### Marketing Angles

- **Efficiency**: "One scan, four recipes. Vintage cookbook magic."
- **Smart detection**: "Knows 'crust' + 'filling' = one pie, not two recipes."
- **User control**: "AI finds them. You choose which to keep."
- **Heritage optimization**: "Perfect for dense vintage cookbooks where paper was precious."

### Technical Notes

- Claude Vision API (`claude-sonnet-4-20250514`) for detection
- Bounding box format: `{x: 0.0-1.0, y: 0.0-1.0, width: 0.0-1.0, height: 0.0-1.0}` (percentages)
- Section merging logic: If "title A" followed by "ingredient section A" followed by "title A cont." = merge into one recipe
- Confidence threshold: 0.4 (below this, treats as single recipe)
- Max detected recipes: 6 (more than 6 = treats as single recipe to avoid false positives)
- Cost: ~$0.02 per page (same as single recipe detection)
- Image cropping: Each recipe thumbnail generated by cropping original image using bounding box

---

## Deterministic Progress Indicators

**One-Line**: No vague spinners—every AI operation shows exact steps and percentages.

### Value Proposition

"Loading..." spinners create anxiety and uncertainty. Is it frozen? How long will this take? Should I wait or restart? Heirloom eliminates this anxiety with deterministic progress: "Optimizing image quality... 58%". Users see exactly what's happening and how far along the process is. This is especially important for AI operations that can take 5-30 seconds—users need reassurance that work is happening. The progress isn't random; it's based on estimated phase durations calibrated from real API latency data.

### How It Works

1. AI operation begins (OCR scan, video transcription, recipe extraction)
2. Heirloom identifies operation phases:
   - Cookbook scanning: Optimizing (2s) → Detecting (3s) → Extracting (4s)
   - Video import: Transcribing (varies) → Structuring (4s) → Augmenting (3s)
   - Web import: Fetching (2s) → Parsing (3s)
3. `PhotoProgressInterpolator` service manages progress display:
   - Each phase has estimated duration (calibrated from analytics)
   - Progress updates every 0.5 seconds with smooth interpolation
   - Uses ease-out curve for natural feel: `1 - (1 - ratio)^2`
   - Caps at 95% of target until operation actually completes (prevents hitting 100% early)
4. When operation completes, progress jumps to 100% with completion message
5. Users see:
   - Current phase name ("Optimizing image quality...")
   - Current phase percentage (58%)
   - Overall progress bar filling smoothly
   - Time estimates are implicit in progress speed (not shown explicitly to avoid setting expectations)

### Key Capabilities

- **Phase-based progress**: Clear step names, not vague "Loading..."
- **Smooth interpolation**: Updates every 0.5s with ease-out animation
- **Calibrated estimates**: Based on real API latency data from analytics
- **Never lies**: Caps at 95% until confirmed completion (prevents "100% but still loading" frustration)
- **Context-aware**: Different phases for different operations
- **Graceful handling**: If operation takes longer than estimated, progress slows but never stops
- **Completion confirmation**: Explicit "Complete!" message when done

### UX Story

"Marcus scans a stained recipe card from his grandmother. Instead of seeing a spinner, he sees:
- 'Optimizing image quality... 45%' (2 seconds)
- 'Detecting recipes... 72%' (3 seconds)
- 'Extracting recipe details... 89%' (4 seconds)
- 'Complete!' (flash of green)
The entire process takes 9 seconds, but Marcus never felt anxious because he knew exactly what was happening at each moment. Compare this to a competitor app that just says 'Processing...' with a spinning circle—Marcus would have restarted it after 5 seconds thinking it was frozen."

### Visual Opportunities

- **Screenshot 1**: Cookbook scan progress showing "Detecting recipes... 58%"
- **Screenshot 2**: Video import showing "Transcribing audio... 34%"
- **Screenshot 3**: Web import showing "Parsing recipe data... 91%"
- **Video comparison**: Heirloom deterministic progress vs. competitor vague spinner (side-by-side)
- **Animation**: Progress bar smoothly filling with phase text updating
- **Diagram**: Phase timeline showing estimated durations

### Marketing Angles

- **Anxiety reduction**: "Know exactly what's happening. No wondering if it's frozen."
- **Trust building**: "We show our work. No black box AI."
- **UX polish**: "The small details matter. Progress that feels right."
- **Differentiation**: "Other apps say 'Loading...' We say 'Detecting recipes... 58%'"

### Technical Notes

- Service: `PhotoProgressInterpolator` with Timer publisher
- Update frequency: 0.5 seconds (500ms)
- Interpolation curve: Ease-out (`1 - (1 - ratio)^2`)
- Progress cap: 95% until confirmed completion
- Phase durations (estimates from analytics):
  - Optimizing: 2.0 seconds
  - Detecting: 3.0 seconds
  - Extracting: 4.0 seconds
  - Transcribing: Varies by video length (1-10 minutes)
- Timer cleanup: Cancels when view disappears (prevents memory leaks)
- Analytics: Tracks actual completion times to improve estimates

---

## Default API Key Included

**One-Line**: 100 recipes per day included—no credit card, no subscription, just cook.

### Value Proposition

AI-powered features usually require expensive subscriptions or per-use fees. Heirloom includes a default Anthropic API key in the app bundle, giving every user 100 free AI recipe operations per day. That's enough for most home cooks who import 2-5 recipes daily. Power users can add their own API key for unlimited usage. This removes the biggest barrier to AI adoption: fear of unexpected costs. Try features risk-free, upgrade only if you need more.

### How It Works

1. User downloads Heirloom (no account setup required yet)
2. App includes default Anthropic API key in `Config.xcconfig` (excluded from git, included in bundle)
3. When user performs AI operation (scan cookbook, import video, parse ingredients):
   - App checks `AIConfiguration.shared.dailyRequestCount`
   - If count < 100, uses default key
   - If count >= 100, shows soft paywall: "Daily limit reached. Add your own API key or wait until tomorrow."
4. Request count increments with each operation
5. Count resets at midnight (stored in UserDefaults with date stamp)
6. User can bypass limit by:
   - Adding personal Anthropic key (Settings → AI → Add API Key)
   - Waiting until tomorrow (automatic reset)
7. Personal keys have unlimited usage (user pays Anthropic directly, ~$0.02/recipe)

### Key Capabilities

- **100 recipes/day free**: Covers typical home cook usage (2-5 recipes/day)
- **No credit card required**: Download and use immediately
- **Soft limit**: Informative message, not hard block
- **Midnight reset**: Fresh 100 requests every day
- **Transparent counter**: Settings shows "47 AI recipes remaining today"
- **Personal key option**: Power users can add their own key for unlimited
- **Cost visibility**: Shows estimated costs for personal keys
- **Secure storage**: API keys in iOS Keychain, never in code or UserDefaults

### UX Story

"Zoe downloads Heirloom and imports 12 recipes from Pinterest using web import (AI parsing). She scans 5 cookbook pages (OCR + extraction). She imports 2 TikTok videos (transcription + structuring). Total: 19 AI operations out of 100. She checks Settings → AI and sees "81 AI recipes remaining today." She's impressed that all these features work without entering a credit card. The next day, her counter resets to 100. Three months later, she's importing 15 recipes per day for a cookbook project. She adds her own Anthropic API key ($20/month budget for unlimited), and the limit disappears."

### Visual Opportunities

- **Screenshot 1**: Settings screen showing "72 AI recipes remaining today"
- **Screenshot 2**: Soft paywall message "Daily limit reached" with options
- **Screenshot 3**: API key addition screen with cost calculator
- **Screenshot 4**: Success message "Personal API key added - unlimited recipes!"
- **Diagram**: Default key flow vs. personal key flow

### Marketing Angles

- **Risk-free trial**: "Use AI features for free. No credit card required."
- **Fair limits**: "100 recipes/day is enough for most people. Only power users need more."
- **Transparent pricing**: "Want unlimited? Add your own key for ~$0.02 per recipe."
- **No surprises**: "See exactly how many AI operations you have left."

### Technical Notes

- Default key stored in `Config.xcconfig`: `DEFAULT_ANTHROPIC_KEY = sk-ant-api03-...`
- Request counter in UserDefaults: `dailyRequestCount` + `lastResetDate`
- Reset logic: `if Calendar.current.isDateInToday(lastResetDate) == false { dailyRequestCount = 0 }`
- Personal key storage: iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`
- Cost calculation: Input tokens * $3/1M + Output tokens * $15/1M (Sonnet pricing)
- API key validation: Checks prefix `sk-ant-` or `sk-` before saving
- Masked display: Shows "sk-ant-...X7Qs" (first 8 + last 4 characters)
- Rate limit sharing: All users share same default key quota (distributed across user base)

---

# 4. Recipe Management

## Recipe Editor

**One-Line**: Comprehensive editing with AI assistance—title, ingredients, instructions, source, and metadata.

**Value**: Edit recipes anytime with structured form guidance, AI spell checking, and smart quantity detection.

**Key Capabilities**: Structured fields (title, ingredients, instructions, notes), AI spell check, source type dropdown (URL/Cookbook/Family/Manual), photo support, auto-save drafts, ingredient reordering, duplicate detection.

**UX Story**: "Emily imports a web recipe but wants to adjust it. She taps Edit, changes '2 cups butter' to '1 cup butter', adds a personal note about using salted vs. unsalted, uploads a photo of her finished dish, and saves. The changes sync to her iPad instantly."

**Visual Opportunities**: Clean editor form, AI suggestions inline, before/after edits, cross-device sync demonstration.

---

## Collections & Tags

**One-Line**: Organize recipes by theme, occasion, cuisine, or any custom category.

**Value**: Collections (Summer Entertaining, 5-Ingredient Meals) and tags (Italian, Vegetarian, Kid-Friendly) make large recipe libraries manageable.

**Key Capabilities**: Create unlimited collections, add recipes to multiple collections, visual collection covers, smart collections based on tags, search and filter by collection/tag, collection sharing.

**UX Story**: "Nina has 400 recipes. She creates collections: 'Weeknight Dinners' (120 recipes), 'Holiday Baking' (45 recipes), 'Grandma's Recipes' (32 recipes). She tags recipes with cuisines and dietary needs. Now when she needs a vegetarian weeknight dinner, she filters: Weeknight Dinners + Vegetarian tag = 18 perfect options."

**Visual Opportunities**: Collection grid view, recipe multi-select for adding to collections, filter UI, collection covers.

---

## Recipe Versioning

**One-Line**: Track recipe changes across generations with attribution and field-level diffs.

**Value**: When you share grandma's lasagna, your cousin modifies it, and you want to see what changed—versioning tracks every edit.

**Key Capabilities**: Base version (original), contributor versions (modifications), field-level change tracking, visual diff highlighting, version selector, attribution labels ("Mom '15"), per-version cooking stats.

**UX Story**: "Grace shares her lasagna recipe with her sister Ann. Ann adjusts the cheese blend and saves a new version. Later, Grace views the recipe and sees 'Version: Ann '24' with a dropdown. She compares Ann's version to the original and sees highlighted changes: 'ricotta + mozzarella' → 'ricotta + mozzarella + parmesan'. She tries Ann's version and loves it, so she switches her default to Ann's."

**Visual Opportunities**: Version selector dropdown, diff view with highlighting, family tree of versions, attribution badges.

---

## Lineage Tracking & Family Tree

**One-Line**: Visualize how recipes evolve across generations with interactive family tree graphs.

**Value**: Heritage recipes deserve heritage tracking. See who adapted what, when, and how recipes branch across family lines.

**Key Capabilities**: Interactive lineage graph (pinch-to-zoom, pan), generation badges (Gen 0, Gen 1, Gen 2+), modification history, provenance metadata (SHA256 hash for root tracking), multi-device sync of lineage data, clickable nodes for recipe details.

**UX Story**: "Jake's grandmother created a apple pie recipe in 1985 (Gen 0). She shared it with Jake's mom who added cinnamon (Gen 1). Jake's mom shared with Jake who reduced sugar (Gen 2). Jake shares with his cousins Amy and Ben who each modify it (Gen 3). Jake opens the lineage graph and sees the full family tree: Grandma at the root, mom and three cousins as branches, each node color-coded by generation. He taps Amy's node to see her changes: 'reduced sugar 25%' → '50%'."

**Visual Opportunities**: Interactive tree graph, generation color coding, modification timeline, node details on tap.

---

## Source Attribution

**One-Line**: Always remember where recipes came from—website, cookbook, person, or platform.

**Value**: "Where did I get this recipe?" never happens. Every recipe preserves its origin.

**Key Capabilities**: Source types (URL, Cookbook, Family, Manual, Scan, Heritage, Video), source metadata (URL, book title/author/page, person name/date/story, video creator/@username), clickable links back to source, provenance display badges.

**UX Story**: "Leo has 300 recipes from diverse sources. When he cooks a killer curry, he thinks 'Where did I get this?' He opens the recipe and sees source: '@chef_sanjay on TikTok' with a clickable link. He taps it, watches the original video again, and remembers why he saved it."

**Visual Opportunities**: Source badges on recipe cards, detail view showing full source info, clickable creator links.

---

# 5. Personalization

## Card Backgrounds

**One-Line**: 12 vintage patterns, colors, and textures make every recipe card uniquely yours.

**Value**: Digital doesn't have to mean sterile. Add warmth with cream, peach, mint backgrounds and vintage paper textures.

**Key Capabilities**: 8 solid colors (cream, warm white, vanilla, linen, peach, light blue, mint, tan), patterns (dots, lines, grid, vintage), textures (paper, fabric, kraft, parchment), gradient options, per-recipe customization.

**UX Story**: "Sophia sets her grandma's recipes with 'parchment' texture, her Italian recipes with cream + vintage pattern, and her modern recipes with clean white. Her recipe library looks like a physical box of treasured cards."

**Visual Opportunities**: Background picker with live preview, recipe grid showing diverse backgrounds.

---

## Stickers & Decorations

**One-Line**: 50+ hand-drawn stickers—tomatoes, herbs, utensils, seasonal elements—add personality.

**Value**: Analog recipe cards have stickers. Digital can too. Position, scale, rotate, and tint stickers.

**Key Capabilities**: 50+ hand-drawn stickers, categories (Food, Seasonal, Cooking Tools), position/scale/rotate controls, color tinting, opacity adjustment, recently used stickers, favorites, search by name, custom sticker import.

**UX Story**: "Mia decorates her pasta recipes with tomato and basil stickers, her holiday recipes with snowflakes and holly, and her cocktail recipes with lemon slices. She scales them small for subtle accents, large for bold statements."

**Visual Opportunities**: Sticker picker grid, decorated recipe cards, customization controls (scale/rotate/color).

---

## Handwritten Annotations

**One-Line**: Add personal notes in handwritten, sticky note, or marker styles—positioned anywhere.

**Value**: "Use butter!" or "Double the garlic!" deserve to be on the recipe card, not hidden in notes.

**Key Capabilities**: 3 styles (handwritten, sticky note, marker), position anywhere (X/Y coordinates), font sizes (12-24pt), 7 colors (yellow, red, turquoise, mint, coral, lavender, pink), rotation (0-360°), HTML sanitization for security.

**UX Story**: "Ben adds a yellow sticky note annotation on his chili recipe: 'Add extra cumin!' positioned near the spice list. Later, his brother cooks it and immediately sees the tip without scrolling through notes."

**Visual Opportunities**: Annotation styles comparison, positioned annotations on recipe card, customization interface.

---

## Love Marks (Coffee Stains & Worn Edges)

**One-Line**: Add authenticity with coffee stains, worn edges, and vintage weathering.

**Value**: Treasured recipes look lived-in. Love marks add character automatically based on times cooked.

**Key Capabilities**: Coffee stain positions (5 locations), worn edge intensity (0-1.0), auto love marks (adds stain after 5+ cooks), manual positioning, removal option.

**UX Story**: "After Lisa cooks her mom's lasagna recipe 10 times, Heirloom automatically adds subtle worn edges and a coffee stain to the card. It looks cherished, not pristine. Perfect."

**Visual Opportunities**: Before/after love marks, auto-generation after cooking milestones.

---

## Card Back Customization

**One-Line**: Flip cards have backs—customize with comments, ratings, cooking notes, and more stickers.

**Value**: Physical recipe cards have backs for notes. Digital ones should too.

**Key Capabilities**: Flip animation (tap to flip), independent styling (colors, stickers for back), comments section, personal rating, cooking history, custom layouts, everything travels when shared.

**UX Story**: "Tom flips his favorite cookie recipe to the back and sees: 5-star rating, 'Baked 23 times', and a note from his sister: 'Try brown butter!' All on the card back, accessible with one tap."

**Visual Opportunities**: Flip animation video, card front vs. back comparison, shared cards showing customizations.

---

## Customizations Travel with Shares

**One-Line**: Your stickers, annotations, and styling sync across devices and travel with shared recipes.

**Value**: Personal touches shouldn't be lost. When you share a decorated recipe, customizations go with it.

**Key Capabilities**: CRDT-enabled sync (conflict-free multi-device), Firebase Firestore serialization, share options include stickers flag, recipient sees your customizations (optional), multi-device consistency.

**UX Story**: "Anna decorates a pie recipe with stickers and annotations on her iPhone. When she opens Heirloom on her iPad, the decorations are there. She shares it with her mom (includeStickers: true), and her mom sees the same decorated card."

**Visual Opportunities**: Cross-device sync demonstration, shared recipe showing decorations intact.

---

# 6. Meal Planning

## Dinner Party Mode

**One-Line**: Plan multi-recipe meals with automatic guest scaling, cooking timeline, and consolidated shopping.

**Value**: Hosting a 6-course dinner for 8 guests requires coordination. Dinner Party mode calculates everything.

**Key Capabilities**: Add multiple recipes, set guest count, automatic timeline generation (longest cook time starts first), per-recipe scaling factors, active cooking mode with real-time countdown, consolidated shopping list, past/upcoming/active party views.

**UX Story**: "Raj plans a 4-course dinner for 12 guests (appetizer, salad, main, dessert). He adds recipes, sets guest count to 12, and Heirloom scales all ingredients (salmon recipe serves 6 → scales to 12). The timeline shows: dessert starts 3 hours before meal time, main starts 2 hours, salad starts 1 hour, appetizer starts 30 minutes. Perfect synchronization."

**Visual Opportunities**: Timeline view with start times, scaling calculations, active cooking mode, shopping list generation.

---

## Cooking Timeline

**One-Line**: Automatic start times ensure all dishes finish simultaneously—no cold sides.

**Value**: Multi-dish cooking is stressful. The timeline removes guesswork.

**Algorithm**: Sort recipes by total time (prep + cook) descending. Longest starts first, shortest last. Each recipe's start time = meal time - total time.

**UX Story**: "Dinner at 7pm. Roast (2 hours) starts at 5pm, sides (45 min) start at 6:15pm, salad (10 min) starts at 6:50pm. All finish at 7pm. No math required."

---

## Recipe Scaling

**One-Line**: Adjust servings precisely—ingredients auto-calculate with no confusing ranges.

**Value**: Scaling recipes manually is error-prone. Heirloom does the math instantly.

**Key Capabilities**: Precise multipliers (not ranges), fraction handling (1/2 cup → 1 cup), intelligent rounding (2.33 tbsp → 2 1/3 tbsp), scaling validation (checks if recipe is scalable), minimum/maximum serving limits, scaling notes from AI.

**UX Story**: "A cookie recipe serves 24. Emma needs 60. Heirloom calculates 2.5x multiplier, updates all ingredients: 2 cups flour → 5 cups, 1 egg → 2.5 eggs (rounds to 3 with note: 'Or 2 eggs + 1 yolk')."

**Visual Opportunities**: Scaling slider, before/after quantities, intelligent rounding explanations.

---

# 7. Shopping

## Smart Shopping Lists

**One-Line**: Auto-generated from recipes with intelligent category grouping and duplicate consolidation.

**Value**: Manual shopping lists are tedious. Heirloom creates them instantly from recipes.

**Key Capabilities**: Add recipes to shopping cart, ingredient consolidation (2 recipes need flour = combined total), category grouping (produce, dairy, meat, pantry), check-off tracking, recipe attribution per ingredient ("Used in: lasagna, cookies"), bulk operations (check all, clear all).

**UX Story**: "Kim adds 5 recipes to her shopping list. Heirloom combines: '2 cups flour (cookies) + 3 cups flour (bread) = 5 cups flour total' grouped under Pantry. She checks items off as she shops."

**Visual Opportunities**: Grouped ingredient list, recipe attribution ("Used in..."), check-off animations.

---

## Export to iOS Reminders

**One-Line**: Send shopping list to Apple Reminders for native iOS integration and Siri access.

**Value**: Shopping in the grocery store? Use Reminders for check-off notifications and Apple Watch integration.

**Key Capabilities**: One-tap export, creates Grocery list type (Reminders app recognizes this), preserves categories as sublists, "Hey Siri, add milk to my Groceries" works.

**UX Story**: "Tom exports his list to Reminders. In the store, he asks his Apple Watch: 'What's on my groceries list?' It reads the items. He checks them off on his Watch."

**Visual Opportunities**: Export flow screenshot, Reminders app showing Heirloom list, Apple Watch integration.

---

## Dinner Party Shopping Sync

**One-Line**: Guest count changes update shopping list automatically—no manual recalculation.

**Value**: "Actually, 10 guests, not 8" shouldn't require re-doing the shopping list.

**Key Capabilities**: Auto-update on guest count change, MAX servings rule when recipe in multiple parties, real-time quantity adjustments, change notifications (toast: "Shopping list updated for 10 guests").

**UX Story**: "Dinner party for 8 → shopping list ready. Guest count changes to 12 → shopping list updates automatically (flour 4 cups → 6 cups). No manual work."

**Visual Opportunities**: Real-time update animation, guest count slider affecting shopping list.

---

# 8. Social & Sharing

## Heirloom Shares (Tracked Modifications)

**One-Line**: Share recipes with full modification tracking across generations—see how family adapts them.

**Value**: Heritage recipes evolve. Heirloom shares track every modification so you see your recipe's journey.

**Key Capabilities**: Generation tracking (Gen 0, 1, 2+), modification history (who changed what when), lineage graph visualization, bidirectional visibility (original creator sees all descendants), recipient can modify and contribute back, provenance metadata preserved.

**UX Story**: "Sarah shares her pie recipe (Gen 0) with her sister Kate (Gen 1). Kate adjusts the sugar and shares with her daughter Emma (Gen 2). Sarah sees the full modification history: Kate reduced sugar 20%, Emma added lemon zest. Sarah tries Emma's version and adopts it."

**Visual Opportunities**: Generation badges, modification timeline, family tree graph.

---

## Generic Shares (One-Time Copy)

**One-Line**: Share recipes without tracking—recipient gets a clean copy, no ongoing connection.

**Value**: Not every share needs lineage tracking. Generic shares are simpler for casual sharing.

**Key Capabilities**: One-time copy (no modification tracking), expiration dates (7-day default, customizable), personal messages included, share options (include card back, ratings, notes), QR code generation for in-person sharing.

**UX Story**: "Leo finds a great taco recipe online, imports it, and shares with his coworker via QR code. His coworker scans, saves, and they're disconnected. Leo doesn't see if coworker modifies it. Simple."

**Visual Opportunities**: QR code generation, expiration countdown, share options screen.

---

## Customizable Share Options

**One-Line**: Granular control over what's shared—card back, ratings, notes, stickers, comments, history.

**Value**: Share what you want, keep what you don't. Full control.

**Key Capabilities**: Toggles for: card back, rating, notes, pinned comments, all comments, cooking history, stickers, annotations, re-sharing permission, personal message field, expiration duration, share type (heirloom vs. generic).

**UX Story**: "Nina shares her lasagna with customizations visible (stickers, notes) but hides her personal rating. She sets expiration to 30 days and adds message: 'Try this for Sunday dinner!'"

**Visual Opportunities**: Share options screen with toggles, live preview showing what recipient sees, privacy levels.

---

## Provenance Metadata

**One-Line**: Always know where recipes came from—original source, generations, share history.

**Value**: "Where did this recipe originate?" is always answerable.

**Key Capabilities**: Root provenance hash (SHA256 of original), generation counter, parent share ID, creator attribution, source URL/person/book, aggregated metrics (total shares, total cooks, average rating), trending score.

**UX Story**: "A recipe has been shared 47 times across 5 generations. The original creator sees: '47 family members have this recipe, cooked 234 times total, 4.7★ average rating.' Full provenance preserved."

**Visual Opportunities**: Provenance badge, metrics dashboard, trending indicator.

---

# 9. Cooking Experience

## Cooking Mode

**One-Line**: Full-screen, kitchen-optimized view with large fonts, timers, and step-by-step guidance.

**Value**: Cooking with phone on counter requires readability at a distance and hands-free-friendly UX.

**Key Capabilities**: Full-screen layout, large text (18-24pt), ingredient scaling on-the-fly, step highlighting (current step emphasized), timer integration, voice control (via Siri), mark as cooked button, dark mode for evening cooking.

**UX Story**: "Cooking pasta at 6pm. Phone on counter, hands covered in flour. Tom glances at screen from 3 feet away and clearly sees current step: 'Boil water (10 minutes)'. Large timer counts down. No squinting."

**Visual Opportunities**: Full-screen cooking mode, timer interface, large text demonstration.

---

## Mark as Cooked & Favorites

**One-Line**: Track cooking history and favorite recipes for quick access and recommendations.

**Value**: "What should I make tonight?" answered by "Here are your most-cooked recipes."

**Key Capabilities**: Mark as cooked increments counter, last cooked date stored, favorite toggle (star icon), favorites collection auto-created, sort by times cooked, sort by recently cooked, cooking streak tracking.

**UX Story**: "Sarah cooks her lasagna recipe 15 times over a year. It shows 'Cooked 15 times, last on Jan 5.' She favorites it. Later, when browsing, she filters by Favorites and sees her go-to recipes instantly."

**Visual Opportunities**: Cooking history timeline, favorites view, most-cooked leaderboard.

---

# 10. Sync & Data

## Firebase Real-Time Sync

**One-Line**: Changes on iPhone appear on iPad instantly—true multi-device consistency.

**Value**: Edit on phone while shopping, cook from iPad at home. Always in sync.

**Key Capabilities**: Firebase Firestore backend, real-time listeners, automatic conflict resolution, offline mode (edit without internet, syncs later), CRDT for customizations (conflict-free), sync status indicator, background sync.

**UX Story**: "Emma adds a recipe on her iPhone while commuting. At home, she opens Heirloom on her iPad and the recipe is already there, including the stickers she added on the train. Real-time sync."

**Visual Opportunities**: Cross-device sync demonstration, offline mode indicator, sync status indicator.

---

## Cloud Image Storage

**One-Line**: Recipe photos stored in Firebase Storage—never lose images across devices or reinstalls.

**Value**: Local-only storage fails if phone breaks. Cloud storage preserves memories.

**Key Capabilities**: Firebase Storage backend, automatic upload on save, high-resolution preservation, progressive loading (blurhash placeholders), thumbnail generation, automatic cleanup on recipe delete, image URLs in Firestore documents.

**UX Story**: "Phone breaks. New phone, reinstall Heirloom, sign in. All 300 recipes appear with images intact. Cloud storage saved everything."

**Visual Opportunities**: Progressive image loading (blurhash → full image), cloud upload indicator.

---

## Privacy & Security

**One-Line**: Your data, your Firebase account, your control—Heirloom doesn't mine your recipes.

**Value**: Recipe apps shouldn't sell your data or train AI on your family recipes.

**Key Capabilities**: Firebase Authentication (Apple ID, Google), Keychain storage for API keys, recipes NOT used for AI training (Anthropic policy), no ads, no third-party tracking beyond Mixpanel analytics (anonymous), user owns Firebase data, export recipes anytime (JSON), delete account deletes all data.

**UX Story**: "Privacy-conscious users choose Heirloom because: Sign in with Apple (private email relay), recipes sync to their own Firebase account (not Heirloom's servers), API keys in iOS Keychain (encrypted), Anthropic doesn't train on their recipes."

**Visual Opportunities**: Privacy policy highlights, data ownership diagram, export options.

---

# Appendix

## Design System Reference

### Color Palette
- **Cream** (#FDF6E3): Card backgrounds, warm base
- **Tomato** (#E54B4B): Primary actions, CTA buttons
- **Amber** (#D4A574): Accents, highlights
- **Charcoal** (#3D3D3D): Body text, readable contrast
- **Family Green** (#2D5A27): Heritage indicators, special badges

### Typography
- **Serif** (default system serif): Recipe titles, headers—warm and classic
- **Sans-serif** (SF Pro): Body text, ingredients, instructions—clean and readable
- **Monospaced** (SF Mono): Code-like elements, technical details

### Aesthetic Principles
- **Vintage warmth**: Inspired by physical recipe cards, not clinical apps
- **Heirloom quality**: Feels treasured, not disposable
- **Family-oriented**: Emphasizes sharing, generations, heritage
- **Nostalgic but modern**: Classic aesthetics with iOS 17 polish

---

## Technical Specifications

### Platform Requirements
- **iOS**: 17.0+ (SwiftData requirement)
- **Devices**: iPhone, iPad (universal)
- **Architecture**: SwiftUI + SwiftData + Firebase
- **Languages**: English (additional languages planned)

### Backend Services
- **Firebase Authentication**: Apple Sign-In, Google Sign-In
- **Firebase Firestore**: Real-time database for recipes, collections, lineage
- **Firebase Storage**: Cloud image hosting
- **Firebase Functions**: Recipe import Cloud Functions (Node.js/TypeScript)

### AI Services
- **Anthropic Claude**: Haiku (parsing), Sonnet 4 (vision, extraction)
- **Apple Vision**: On-device OCR (`VNRecognizeTextRequest`)
- **WhisperKit**: On-device speech-to-text for video transcription

### Key Dependencies
- Firebase iOS SDK (Auth, Firestore, Storage)
- GoogleSignIn-iOS
- SwiftSoup (HTML parsing)
- WhisperKit (on-device AI)

### Performance Metrics
- **App size**: ~40MB
- **Cold start**: < 1s to authentication, < 2s to recipe library
- **Recipe import**: 5-30s depending on source
- **Image processing**: 2-10s for OCR
- **Video transcription**: ~2x realtime (10min video = 5min processing)

---

## Supported Platforms & Integrations

### Import Sources
- 500+ recipe websites (AllRecipes, NYT Cooking, Serious Eats, Bon Appétit, food blogs)
- Physical cookbooks (OCR)
- Video platforms (YouTube, TikTok, Instagram, Vimeo, Facebook)
- Manual entry
- Share extension (Safari, Chrome, in-app browsers)

### Export Destinations
- iOS Reminders (native integration)
- JSON export (backup, portability)
- Recipe sharing via Firebase (Heirloom or generic shares)
- QR codes (in-person sharing)

### Cross-Platform Status
- **iOS**: Full support (iPhone, iPad)
- **Android**: Not yet (Firebase backend is cross-platform ready)
- **Web**: Not yet (all data accessible via Firebase)
- **Apple Watch**: Not yet (planned)

---

## Feature Comparison Matrix

| Feature | Heirloom | Paprika | Mela | Cooklist |
|---------|----------|---------|------|----------|
| AI Recipe Import | ✅ (Claude) | ✅ (Basic) | ✅ (Basic) | ❌ |
| OCR Cookbook Scanning | ✅ (Vision + Claude) | ✅ (Basic) | ❌ | ❌ |
| Video-to-Recipe | ✅ (WhisperKit + Claude) | ❌ | ❌ | ❌ |
| Multi-Recipe Detection | ✅ (Claude Vision) | ❌ | ❌ | ❌ |
| Lineage Tracking | ✅ (Full family tree) | ❌ | ❌ | ❌ |
| Recipe Versioning | ✅ (Field-level diffs) | ❌ | ❌ | ❌ |
| Customization (Stickers/Annotations) | ✅ (50+ stickers, 3 styles) | ❌ | ❌ | ❌ |
| Dinner Party Mode | ✅ (Timeline + scaling) | ✅ (Basic) | ✅ (Basic) | ❌ |
| Shopping List | ✅ (Smart consolidation) | ✅ | ✅ | ✅ |
| Cross-Device Sync | ✅ (Firebase realtime) | ✅ (CloudKit) | ✅ (iCloud) | ✅ |
| Default API Key | ✅ (100/day free) | ❌ | ❌ | ❌ |
| No Subscription | ✅ (Core features free) | ❌ ($3-5/mo) | ❌ ($6/mo) | ❌ ($5/mo) |

---

## Marketing Messaging Framework

### Core Value Propositions
1. **Preserve heritage**: "Digitize grandma's recipes before they fade."
2. **Eliminate friction**: "Import in seconds, not minutes. Scan, don't type."
3. **Track evolution**: "See how recipes evolve across generations."
4. **Personal touch**: "Digital recipes that feel warm, not sterile."
5. **No hidden costs**: "100 AI recipes/day free. Core features forever."

### Target Audience Personas

**1. Heritage Preserver (Emma, 35)**
- Has grandmother's handwritten recipes
- Wants to preserve before paper decays
- Values family history and stories
- **Hook**: "OCR that reads grandma's cursive."

**2. Recipe Hoarder (Mike, 42)**
- 200+ browser bookmarks, 47 open tabs
- Collects recipes but never organizes
- **Hook**: "Close all those tabs. One beautiful app."

**3. Dinner Party Host (Sophia, 38)**
- Entertains frequently, multi-course meals
- Stresses about timing and quantities
- **Hook**: "Automatic cooking timelines. All dishes finish together."

**4. Social Sharer (Priya, 29)**
- Shares recipes with friends/family often
- Wants customizations to travel
- **Hook**: "Your stickers and notes go with the recipe."

**5. Video Learner (Carlos, 24)**
- Learns from TikTok/YouTube cooking videos
- Frustrated by re-watching for measurements
- **Hook**: "Turn videos into searchable text recipes."

### Key Differentiators
1. **AI intelligence without subscription**: Default key included
2. **Heritage focus**: Lineage tracking, versioning, provenance
3. **Customization that travels**: Stickers, annotations sync and share
4. **Deterministic progress**: No anxiety-inducing spinners
5. **Video-to-recipe**: Unique feature, no competitors

### Emotional Messaging
- **Nostalgia**: "Recipes worth passing down" (tagline)
- **Family**: "Your family tree grows. So should your recipes."
- **Trust**: "Preserve memories, not just measurements."
- **Warmth**: "Digital doesn't have to mean cold."
- **Permanence**: "Websites shut down. Your recipes live forever."

---

## Success Metrics

### User Engagement
- **Recipe imports**: Average 12 recipes in first week
- **AI usage**: 73% of users use AI features within 24 hours
- **Customization**: 45% add stickers or annotations to at least one recipe
- **Sharing**: 28% share at least one recipe in first month
- **Retention**: 68% 7-day retention, 52% 30-day retention

### Technical Performance
- **Import success**: 94% web import success rate
- **OCR accuracy**: 87% ingredient accuracy, 92% instruction accuracy
- **Video transcription**: 91% word accuracy (English)
- **Sync reliability**: 99.2% uptime (Firebase SLA)

### User Satisfaction (TestFlight Feedback)
- **Overall**: 4.7★ average (237 ratings)
- **Most loved**: "OCR that actually works" (mentioned 89 times)
- **Most requested**: "Android version" (mentioned 54 times), "Meal planning calendar" (mentioned 41 times)

---

## Version History

### v1.1.4 (Build 20) - Current
- Firebase migration complete (from CloudKit)
- Apple Sign-In at launch
- Google Sign-In added
- Recipe lineage tracking
- Visual diff highlighting
- Deterministic progress indicators
- PNG-first OCR

### v1.3.1 - Recent
- Video-to-recipe import
- Watermark detection for creator attribution
- Clickable creator links on recipe cards

### Upcoming Features (Roadmap)
- Multi-language support (Spanish, French, German)
- Meal planning calendar view
- Apple Watch complication for cooking mode
- Voice control for hands-free cooking
- Nutritional information extraction
- Community recipe sharing (opt-in)

---

**End of Guide**
**Last Updated**: January 13, 2026
**Guide Version**: 1.0
**Document Length**: ~11,500 words

