# Heirloom v1.1.0 Beta Testing Plan

**Release**: v1.1.0 - AI-Powered Recipe Intelligence
**Build**: 3
**TestFlight**: [Join Beta](https://testflight.apple.com/join/gs6EU81Z)
**Focus**: AI cookbook scanning + bulk URL import

---

## What's New in v1.1.0

### 🤖 AI-Powered Features

**Vision-Based Cookbook Scanner**
- Snap a photo of any cookbook recipe page
- Automatic OCR text extraction with iOS Vision framework
- AI-powered recipe structuring from messy OCR text
- Fixes common OCR errors automatically (fractions, spacing, formatting)
- Extracts: title, servings, prep/cook times, ingredients, instructions, notes
- No manual editing required—recipes ready to use immediately

**Smart Ingredient Parsing**
- AI-powered ingredient text parsing with Claude
- Intelligent detection of quantities, units, and ingredient names
- Handles complex formats: ranges (1-2 cups), fractions (1/4 tsp), mixed units
- Automatic fallback to regex parser when AI unavailable

**Bulk URL Import**
- Import multiple recipe URLs at once
- Paste multiple links separated by newlines
- All recipes processed in parallel for faster import
- Works with 500+ supported recipe sites

**AI Configuration & Monitoring**
- Complete settings UI for AI features (Settings → AI Features)
- Secure API key storage in iOS Keychain
- Real-time token usage tracking
- Feature toggles: parsing, categories, enhancement
- Connection test button to verify API setup
- Free Anthropic API key available at console.anthropic.com

---

## Updated Testing Focus

### Core Features (Existing - Still Test)
✅ Recipe card personalization (vintage backgrounds, stickers, handwriting)
✅ iOS Reminders integration for shopping lists
✅ CloudKit sharing with provenance tracking
✅ Single URL recipe import (500+ sites)
✅ Dinner Party Mode (multi-recipe planning)
✅ Privacy-first design (on-device processing)

### New AI Features (v1.1.0 - Primary Focus)
🆕 **Cookbook scanner accuracy** - Test various cookbook types (printed, handwritten, old/new)
🆕 **Bulk URL import** - Test importing 3-5 URLs at once
🆕 **AI ingredient parsing** - Test complex ingredient formats (fractions, ranges, measurements)
🆕 **Error handling** - Test behavior when AI unavailable (airplane mode, no API key)
🆕 **Settings UI** - Test API key setup flow and feature toggles
🆕 **Token tracking** - Monitor usage displayed in settings

---

## How to Test AI Features

### 1. Set Up AI (First Time Only)

1. Open **Heirloom** → **Settings** → **AI Features**
2. Tap **"Set API Key"**
3. Visit [console.anthropic.com](https://console.anthropic.com) to create free account
4. Copy your API key and paste in Heirloom
5. Enable desired AI features with toggles
6. Tap **"Test Connection"** to verify setup

### 2. Test Cookbook Scanner

1. Open **Add Recipe** → **"Scan Cookbook"**
2. Take clear photo of recipe page (well-lit, flat page)
3. Wait for OCR extraction + AI structuring
4. Verify:
   - Title extracted correctly
   - Ingredients parsed into structured list
   - Instructions captured accurately
   - Servings, times, notes included
   - Common OCR errors fixed (l→1, O→0, fractions)
5. Try different cookbook types:
   - Modern printed cookbooks
   - Vintage cookbooks (1950s-1980s)
   - Magazine recipe pages
   - Printed internet recipes
   - Handwritten recipes (may have reduced accuracy)

### 3. Test Bulk URL Import

1. Open **Add Recipe** → **"Import from URL"**
2. Paste 3-5 recipe URLs (one per line):
   ```
   https://www.seriouseats.com/recipe1
   https://www.bonappetit.com/recipe2
   https://www.nytimes.com/recipe3
   ```
3. Tap **"Import All"**
4. Verify all recipes imported successfully
5. Check each recipe for accuracy

### 4. Test AI Ingredient Parsing

Test with complex ingredient formats:
- Ranges: "1-2 cups flour"
- Fractions: "1/4 teaspoon salt"
- Mixed units: "2 tablespoons (1/4 stick) butter"
- Parenthetical notes: "1 cup (240ml) milk"
- Alternatives: "1 cup sugar or honey"

### 5. Test Error Handling

1. Enable Airplane Mode
2. Try to scan cookbook or import recipe
3. Verify graceful fallback (regex parser used, clear error message)
4. Disable Airplane Mode and retry
5. Remove API key from settings
6. Verify AI features disabled with helpful guidance

---

## Known Limitations

- **OCR works best with printed text** - Handwritten recipes may have reduced accuracy
- **Requires Anthropic API key** - Free tier available with generous credit
- **Internet connection required** - AI features need network access
- **Non-English recipes** - May have reduced parsing accuracy
- **Image storage** - Recipe photos stored locally (not synced to iCloud to save space)

---

## Feedback We Need

### Cookbook Scanner
- Which cookbook types work well? Which struggle?
- Are OCR errors fixed correctly by AI?
- Are ingredients parsed accurately?
- Is the scan→recipe flow intuitive?

### Bulk URL Import
- How many URLs can you realistically import at once?
- Is the UI clear for multi-URL entry?
- Do all recipes parse correctly in parallel?

### AI Configuration
- Is the API key setup flow clear?
- Are the feature toggles useful?
- Is token usage tracking helpful?

### General
- Performance issues with AI features?
- Privacy concerns about API usage?
- Feature requests for AI capabilities?
- Cost concerns or usage patterns?

---

## Privacy & Security

- API keys stored securely in iOS Keychain (never in code or cloud)
- All AI processing via Anthropic's secure API
- **Your recipes are NOT used for AI training**
- No data shared with third parties
- Local image storage (not synced to iCloud)

---

## Technical Stack

- **AI Models**: Anthropic Claude (Haiku 3 for fast tasks, Sonnet 3.5 for complex)
- **OCR**: iOS Vision framework
- **Storage**: SwiftData for persistence
- **Sync**: CloudKit for cross-device
- **Concurrency**: Swift async/await

---

## Questions or Issues?

- **In-app**: Check Settings → AI Features → "About AI Features"
- **TestFlight**: Use feedback form in TestFlight app
- **Direct**: Contact support through Heirloom settings

Thank you for testing! Your feedback helps us build a better recipe app. 🙏
