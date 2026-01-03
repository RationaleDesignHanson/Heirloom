# Heirloom - TestFlight Beta

**Version:** 1.1.4 (Build 20)
**Release Date:** December 31, 2024

---

## 🎉 Welcome Beta Testers!

Thank you for helping test Heirloom! This build represents a major milestone with Firebase authentication, enhanced AI features, and polished UX throughout.

---

## 🆕 What's New in This Build

### 🔐 Firebase Authentication at Launch
- **Sign in with Apple** - Native iOS authentication
- **Sign in with Google** - NEW! Multi-provider support for broader reach
- Seamless login on app launch (no more digging through Settings)
- Existing sessions restore immediately
- Fixed bug where users had to login multiple times

### 📸 Enhanced OCR
- **Improved image quality** - PNG-first processing for better text recognition
- Deterministic progress indicators show actual steps:
  - Optimizing image quality...
  - Detecting recipes...
  - Extracting recipe details...
- Smarter button labels ("Retake Photo" vs "Replace Photo" based on source)

### 🤖 AI Spelling Suggestions
- **Real-time spell checking** for ingredient text as you type
- Inline suggestion chips appear 1 second after you stop typing
- One-tap corrections for misspellings and incorrect abbreviations
- Example: "1 cup fIour" → Suggestion: "1 cup flour"

### 🎯 Recipe Versioning
- **Track recipe changes over time** with full version history
- Visual diff highlighting shows what changed between versions
- See who made changes and when
- Example: "Shared by Mom, edited from Grandma's original"

### 🍽️ Dinner Party Improvements
- **Precise scaling** - No more confusing ranges like "1.5/2 cups"
- Scales show exact values users want for their guest count
- Multi-recipe planning with smart timelines
- Consolidated shopping lists

### 📱 Multi-Recipe Import
- Enhanced header acknowledges multiple recipes detected
- Full-width accordion button makes expanding/collapsing obvious
- Deterministic import progress shows "Importing 1/3..." with progress bar

### 🔧 Performance & Polish
- Share extension restored for importing from Safari
- Removed unused features (JSON import, Test AI API)
- Better image display on recipe cards (no more placeholders)
- Debounced spell checking reduces API calls
- MainActor coordination prevents UI glitches

---

## 🧪 What to Test

### Priority 1: Authentication Flow
**Test both sign-in methods:**
1. Launch app on a fresh install
2. Try "Sign in with Apple" - Should work seamlessly
3. Sign out in Settings
4. Try "Sign in with Google" - Should also work seamlessly
5. Force quit and relaunch - Should restore session immediately

**What to look for:**
- Any login loops or multiple prompts
- Session restoration speed
- Error messages if sign-in fails

### Priority 2: OCR Quality
**Scan various cookbooks:**
1. Open app → Tap "+" → "Scan Cookbook"
2. Try different types:
   - Printed cookbooks with photos
   - Old recipe cards (printed text)
   - Magazine recipes
   - Handwritten notes (if legible)
3. Note the progress steps shown
4. Check accuracy of extracted data

**What to look for:**
- Text recognition accuracy
- Image quality in final recipe
- Progress indicator clarity
- Any crashes during processing

### Priority 3: AI Spelling Suggestions
**Test ingredient editor:**
1. Create or edit a recipe
2. Add ingredients with intentional typos:
   - "1 cup fIour" (lowercase L instead of 1)
   - "2 tblspoons sugr" (abbreviation + typo)
   - "1/2 teaspon salt" (misspelling)
3. Wait 1 second after typing
4. Look for inline suggestion chips
5. Tap to apply corrections

**What to look for:**
- Suggestions appear after ~1 second
- Corrections are accurate
- One-tap application works
- No performance issues

### Priority 4: Recipe Versions
**Track changes:**
1. Import or create a recipe
2. Edit it (change ingredient, update instructions)
3. Save changes
4. Tap the version selector in recipe detail view
5. View different versions
6. Notice diff highlighting (green = added, red = removed)

**What to look for:**
- Versions save correctly
- Diff view is readable
- Provenance tracking works ("Shared by X")
- Can switch between versions smoothly

### Priority 5: Dinner Party Mode
**Plan a multi-recipe meal:**
1. Go to Dinner Party tab
2. Create a new party (set date, guest count)
3. Add 2-3 recipes
4. Check ingredient scaling (should be precise numbers, no ranges)
5. View cooking timeline
6. Generate shopping list

**What to look for:**
- Scaling accuracy (no "1.5/2 cups" confusion)
- Timeline makes sense
- Shopping list combines ingredients correctly
- Guest count changes update immediately

### Priority 6: Multi-Recipe Import
**Import multiple recipes from one source:**
1. Take photo with multiple recipes (if you have one)
2. Watch for detection acknowledgment
3. Expand/collapse accordion to see recipe details
4. Select which recipes to import
5. Watch import progress

**What to look for:**
- Detection works with 2+ recipes
- Accordion button is obvious
- Progress shows "Importing X/Y"
- All selected recipes import correctly

---

## 🐛 Known Issues

**Minor Issues (Being Tracked):**
- First-time Firebase sync may take a few moments
- Some obscure recipe websites may not import correctly
- Google Sign-In requires Firebase Console configuration (done by developer)

**Expected Behavior:**
- OCR works best with printed text (handwritten may have errors)
- Spell checking requires internet (uses AI)
- Import needs internet connection
- Requires iOS 17+ (uses latest SwiftUI features)

---

## 📝 How to Give Feedback

### In-App Feedback (Preferred)
1. Open Settings tab
2. Tap "Send Feedback"
3. Describe the issue or suggestion
4. Include screenshots if relevant

### TestFlight Feedback
1. Open TestFlight app
2. Select Heirloom
3. Tap "Send Beta Feedback"
4. Describe your experience

### Direct Email
support@heirloomapp.com

**What helps us most:**
- Specific recipes that failed to import (include URL if web)
- Steps to reproduce bugs
- Screenshots or screen recordings
- Device model and iOS version
- What you expected vs what happened

---

## 💡 Testing Tips

**General:**
- Test on multiple devices if possible (iPhone + iPad)
- Try both Wi-Fi and cellular data
- Test with airplane mode to see offline behavior
- Force quit and relaunch between major test scenarios

**OCR Testing:**
- Use good lighting when photographing recipes
- Hold camera steady for 1-2 seconds
- Try recipes with different layouts (single column, multi-column)
- Test both color and black-and-white cookbook pages

**Performance Testing:**
- Import 10+ recipes to test at scale
- Create shopping lists with 5+ recipes
- Try scaling recipes from 1 to 12 servings
- Test sync between devices (requires 2 devices with same account)

**Edge Cases:**
- Recipes with no images
- Recipes with missing metadata (no prep time, etc.)
- Unusual measurements (pinch, dash, to taste)
- Very long recipes (20+ ingredients, 15+ steps)

---

## 🎯 Focus Areas for This Beta

**Critical:**
1. Authentication stability (no login loops)
2. OCR accuracy on your cookbooks
3. Spell checking usefulness

**Important:**
4. Version tracking reliability
5. Dinner party scaling precision
6. Multi-recipe import success rate

**Nice to Have:**
7. General UI/UX feedback
8. Feature requests
9. Performance observations

---

## 🚀 What's Coming Next

**Planned for v1.2:**
- Handwritten recipe recognition improvements
- Recipe sharing via public links
- Meal planning calendar view
- Enhanced search with filters

**On the Roadmap:**
- Multi-language support (Spanish, French, German)
- Apple Watch cooking mode
- Voice control for hands-free cooking
- Nutritional information extraction

---

## 🙏 Thank You!

Your feedback is invaluable in making Heirloom the best recipe app for preserving family culinary traditions. We read every piece of feedback and prioritize based on what will help the most users.

Special thanks to our beta testers who've been with us from the beginning. This app wouldn't exist without your input.

**Happy cooking!**
— The Heirloom Team

---

## 📊 App Information

**Requirements:**
- iOS 17.0 or later
- iPhone or iPad
- Internet connection (for AI features, import, sync)
- Firebase account (automatic with Apple/Google sign-in)

**Permissions:**
- Camera (optional, for cookbook scanning)
- Photo Library (optional, for importing recipe images)
- Reminders (optional, for shopping list export)
- Notifications (optional, for cooking timers)

**Size:** ~40MB

**Privacy:**
- Your recipes are stored in your Firebase account
- API keys stored securely in iOS Keychain
- Analytics are anonymous (Mixpanel)
- No data sold to third parties
- AI processing via Anthropic (recipes not used for training)

---

**TestFlight Build:** 20
**Expiration:** 90 days from release
**Support:** support@heirloomapp.com
