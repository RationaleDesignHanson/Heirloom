# Multilingual Recipe Import: Claude Code Implementation Guide

> **Companion Document:** This implementation guide works alongside `docs/multilingual-import-spec.md` which contains complete design specifications, data models, and UI requirements.

---

## File Structure

```
docs/
├── multilingual-import-spec.md     ← Design specs (the "what")
└── multilingual-import-tasks.md    ← This file - Implementation tasks (the "how")
```

---

## Add to Your CLAUDE.md

Add this context to your project's `CLAUDE.md` file. If you're also implementing Heritage Collections, combine both feature sections:

```markdown
## Current Features in Development

### Reference Documents
- `docs/heritage-collections-spec.md` - Heritage collections design specs
- `docs/heritage-collections-tasks.md` - Heritage collections tasks
- `docs/multilingual-import-spec.md` - Multilingual import design specs
- `docs/multilingual-import-tasks.md` - Multilingual import tasks

---

## Feature: Multilingual Recipe Import

### Goal
Enable users to import recipes from foreign language sources (websites and scanned documents), preserve them in their original language, and optionally translate to English. Includes rock-solid metric/imperial unit conversion.

### Launch Languages
- **Latin script:** French, Spanish, German
- **CJK script:** Japanese, Mandarin, Korean

### Key Concepts
- **Original language preservation:** Recipes stored in source language first
- **Optional translation:** English translation is beta, with user feedback mechanism
- **Unit conversion:** Metric ↔ Imperial conversion must be rock-solid
- **Regional units:** Japanese/Korean cup = 200ml (not US 240ml)
- **Language detection:** Auto-detect from URL metadata or OCR content

### Services
- **Translation:** Claude API (claude-sonnet-4-20250514) with culinary-specific prompting
- **OCR (iOS):** Vision framework (VNRecognizeTextRequest)
- **OCR (cross-platform):** Google Cloud Vision API
- **Translation fallback:** Google Cloud Translation API

### API Keys Required
- `ANTHROPIC_API_KEY` — for translation
- `GOOGLE_CLOUD_API_KEY` — for Vision API (OCR) and Translation API (fallback)

---

## Feature: Heritage Collections (Cold Start)

### Goal
Replace the "Add" bottom tab with "Collections" and seed the app with 100 public domain heritage recipes organized into 4 founding collections.

### The Four Collections
1. **The Presidential Pantry** — White House recipes (National Archives, Library of Congress)
2. **The Literary Kitchen** — Authors' diaries/letters (Dickinson, Austen, Twain, Monet)
3. **The Ancient Table** — Roman (Apicius), Medieval (Forme of Cury)
4. **The American Foundation** — First African American cookbooks, Rosa Parks, suffrage cookbooks

### Key Concepts
- **Heritage recipes:** Read-only seed content with dual-view (original archaic text + modernized)
- **Heritage imagery:** AI-generated or archival images, warm/nostalgic aesthetic
- **Bulk organization:** Selection mode in collections for move/copy/remove operations

### Image Generation
- **Primary:** Google Imagen API via Vertex AI
- **Style:** Warm, nostalgic, painterly — NOT modern food photography
```

---

## Sequential Task Prompts

Run these as separate Claude Code sessions. The dependency graph shows what can be parallelized:

```
Task 1: Explore ─────────────────────────────────────────┐
                                                         │
Task 2: Data Models ─────────────────────────────────────┤
        │                                                │
        ├──→ Task 3: Language Detection                  │
        │                                                │
        ├──→ Task 4: Unit Parsing ──→ Task 5: Unit Conv  │
        │                                                │
        └──→ Task 6: Translation Service                 │
                                                         │
Task 7: OCR Extension (can parallel with 3-6) ───────────┤
                                                         │
Task 8: URL Import Flow (needs 2-6) ─────────────────────┤
                                                         │
Task 9: OCR Import Flow (needs 2-7) ─────────────────────┤
                                                         │
Task 10: Settings UI (needs 2) ──────────────────────────┤
                                                         │
Task 11: Translation Feedback UI (needs 2, 6) ───────────┤
                                                         │
Task 12: Dual Language Display (needs 2, 8 or 9) ────────┤
                                                         │
Task 13: Ingredient Display Component (needs 2, 5) ──────┤
                                                         │
Task 14-15: Testing (after relevant tasks complete) ─────┘
```

**Recommended order:** 1 → 2 → (3, 4, 6, 7 in parallel) → 5 → (8, 9, 10 in parallel) → (11, 12, 13) → (14, 15)

---

### Task 1: Explore Existing Import Flow

```
Explore the current recipe import implementation:

1. Find where URL-based recipe import is handled
2. Find where OCR/image-based recipe import is handled
3. Identify the Recipe model and how ingredients are stored
4. Find user settings storage pattern
5. Check what OCR library/service is currently used (if any)

Create a brief analysis at docs/multilingual-import-analysis.md covering:
- Current import architecture
- Where language-specific logic needs to be added
- Dependencies that may need updating
```

---

### Task 2: Data Model Extensions

```
Extend the Recipe and UserSettings models for multilingual support.
Reference: docs/multilingual-import-spec.md "Data Model Extensions" for complete schemas.

Add to Recipe model:
- sourceLanguage: string (ISO 639-1 code)
- sourceLanguageConfidence: number
- originalText: object with title, description, instructions, notes, languageCode
- translatedText: optional same structure for English translation
- translationMetadata: object tracking when/how translated and user feedback
- sourceUnitSystem: "metric" | "imperial" | "mixed" | "unknown"

Add to Ingredient model (or create LocalizedIngredient):
- original: string (raw text like "200g de farine")
- parsed: object { quantity, unit, unitNormalized, item, preparation, optional }
- translated: optional string
- convertedQuantity: object with both metric and imperial versions

Add to UserSettings:
- preferredUnitSystem: "metric" | "imperial"
- autoConvertUnits: boolean
- showOriginalUnits: boolean
- autoTranslateRecipes: boolean

Create any necessary TypeScript types/interfaces for type safety.
```

---

### Task 3: Language Detection Service

```
Create a language detection service at services/languageDetection.ts (or appropriate location).
Reference: docs/multilingual-import-spec.md "Language Detection" for strategy details.

The service should:

1. detectLanguageFromUrl(url: string, htmlContent: string) -> LanguageDetectionResult
   - Check HTML lang attribute first
   - Check meta Content-Language tag
   - Check URL TLD (.fr, .de, .es, etc.)
   - Fall back to content analysis using Claude API or a library like 'franc'

2. detectLanguageFromText(text: string) -> LanguageDetectionResult
   - For OCR results
   - Use character frequency analysis for Latin scripts
   - Detect script type (Latin, CJK, Devanagari, Arabic) first

3. detectScriptType(text: string) -> ScriptType
   - Return: "latin" | "cjk" | "devanagari" | "arabic" | "hebrew" | "unknown"
   - Use Unicode ranges to detect

Return type LanguageDetectionResult:
{
  detected: LanguageCode,
  confidence: number (0-1),
  method: "html_attr" | "meta_tag" | "tld" | "content_analysis" | "user_override",
  alternativeCandidates: Array<{ language: LanguageCode, confidence: number }>
}

Supported language codes: "en", "fr", "es", "de", "ja", "zh", "ko"

For CJK detection, use Unicode ranges:
- Japanese: Hiragana (3040-309F), Katakana (30A0-30FF), CJK (4E00-9FFF)
- Chinese: Primarily CJK unified (4E00-9FFF), check for Japanese-specific if mixed
- Korean: Hangul (AC00-D7AF, 1100-11FF)
```

---

### Task 4: Unit Parsing & Normalization

```
Create a unit parsing service at services/unitParser.ts.
Reference: docs/multilingual-import-spec.md "Unit Conversion System" for unit mappings and language-specific units.

The service should:

1. parseIngredientText(text: string, language: LanguageCode) -> ParsedIngredient
   - Extract quantity (handle fractions: ½, 1/2, etc.)
   - Extract unit with language-specific patterns
   - Extract item name
   - Extract preparation notes ("chopped", "sifted")
   - Handle ranges ("1-2 cups")

2. normalizeUnit(unit: string, language: LanguageCode) -> NormalizedUnit
   - Map language-specific abbreviations to standard units:
     French: "c. à soupe" -> "tablespoon", "cl" -> "centiliter"
     Spanish: "cucharada" -> "tablespoon", "taza" -> "cup"
     German: "EL" -> "tablespoon", "TL" -> "teaspoon"

3. detectUnitSystem(ingredients: ParsedIngredient[]) -> "metric" | "imperial" | "mixed"
   - Analyze all ingredients to determine source recipe's unit system

Unit mapping dictionary structure:
{
  "fr": {
    "g": "gram", "kg": "kilogram", "ml": "milliliter", "L": "liter",
    "c. à soupe": "tablespoon", "c. à café": "teaspoon", "cl": "centiliter"
  },
  "es": { 
    "cucharada": "tablespoon", "cucharadita": "teaspoon", "taza": "cup"
  },
  "de": { 
    "EL": "tablespoon", "TL": "teaspoon" 
  },
  "ja": {
    "カップ": "cup_jp",      // 200ml, not 240ml!
    "大さじ": "tablespoon",
    "小さじ": "teaspoon"
  },
  "zh": {
    "克": "gram", "毫升": "milliliter", "杯": "cup", "大匙": "tablespoon", "小匙": "teaspoon"
  },
  "ko": {
    "컵": "cup_jp",          // 200ml like Japanese
    "큰술": "tablespoon",
    "작은술": "teaspoon"
  }
}

CRITICAL: Japanese (カップ) and Korean (컵) cups are 200ml, not US 240ml.
Create separate unit type "cup_jp" that converts to 200ml, not 240ml.

Test with:
- "200g de farine" (French)
- "2 cucharadas de aceite" (Spanish) 
- "250ml Milch" (German)
- "小麦粉 2カップ" (Japanese: 2 cups flour)
- "설탕 1컵" (Korean: 1 cup sugar)
```

---

### Task 5: Unit Conversion Service

```
Create a unit conversion service at services/unitConverter.ts.
Reference: docs/multilingual-import-spec.md "Unit Conversion System" for conversion tables and ingredient-specific densities.

The service should:

1. convert(quantity: number, fromUnit: NormalizedUnit, toSystem: "metric" | "imperial") -> ConvertedQuantity
   - Handle metric -> imperial and imperial -> metric
   - Return both systems for storage

2. convertWithIngredientContext(quantity: number, fromUnit: NormalizedUnit, ingredientType: string, toSystem) -> ConvertedQuantity
   - Use ingredient density for volume <-> weight conversions
   - E.g., 1 cup flour = 125g, 1 cup sugar = 200g

3. formatQuantity(value: number, unit: string, system: "metric" | "imperial") -> string
   - Metric: Use decimals ("200g", "1.5L")
   - Imperial: Use fractions ("1¾ cups", "½ tsp")
   - Round to sensible precision

4. roundToFraction(value: number) -> string
   - Convert decimal to nearest fraction (⅛, ¼, ⅓, ½, ⅔, ¾, etc.)
   - Handle whole numbers + fractions ("2½")

Ingredient density table (cups to grams):
{
  "flour": 125,
  "sugar": 200,
  "powdered_sugar": 120,
  "butter": 227,
  "milk": 240,
  "water": 240,
  "rice": 185,
  "oats": 90,
  "honey": 340
}

Include comprehensive unit tests for edge cases:
- Very small quantities (pinch of salt)
- Large quantities (2kg flour)
- Fractions in input
- Ranges
```

---

### Task 6: Translation Service

```
Create a translation service at services/recipeTranslation.ts.
Reference: docs/multilingual-import-spec.md "Translation Service" for Claude API prompt and response format.

The service should:

1. translateRecipe(recipe: LocalizedRecipeText, sourceLanguage: LanguageCode) -> Promise<TranslationResult>
   - Use Claude API (claude-sonnet-4-20250514)
   - Apply culinary-specific system prompt (see spec)
   - Parse JSON response
   - Calculate confidence score
   - Handle errors gracefully

System prompt key points:
- Preserve cooking terminology (sauté, braise, julienne)
- Keep recognizable ingredient names in original when appropriate
- Do NOT convert units (that's handled separately)
- Flag untranslatable terms with [original]
- Return structured JSON

2. translateIngredients(ingredients: string[], sourceLanguage: LanguageCode) -> Promise<string[]>
   - Batch translate ingredient list
   - Preserve quantity/unit, translate item name only

3. Fallback: translateWithGoogle(text: string, from: LanguageCode, to: "en") -> Promise<string>
   - Use Google Cloud Translation API
   - For when Claude API is unavailable

Response structure:
{
  translated: { title, description, ingredients[], instructions[], notes },
  confidence: number,
  warnings: string[],
  untranslatableTerms: string[]
}
```

---

### Task 7: OCR Service Extension

```
Extend or create OCR service to support multiple languages including CJK.
Reference: docs/multilingual-import-spec.md "OCR Pipeline" for configuration by script type.

For iOS (Vision framework):

1. Modify existing OCR implementation to accept language hints:
   recognizeText(image: UIImage, languageHints?: LanguageCode[]) -> Promise<string>

2. Configure VNRecognizeTextRequest for Latin scripts:
   - recognitionLanguages: ["fr-FR", "es-ES", "de-DE", "en-US"]
   - recognitionLevel: .accurate
   - usesLanguageCorrection: true

3. Configure VNRecognizeTextRequest for CJK scripts:
   - recognitionLanguages: ["ja-JP", "zh-Hans", "zh-Hant", "ko-KR"]
   - Note: Vision framework handles CJK well on iOS 16+
   - No word boundaries needed—Vision segments automatically

4. Script detection to choose config:
   - Scan first ~100 characters for Unicode ranges
   - If CJK detected, use CJK language config
   - If Latin detected, use Latin language config
   - If mixed, include both

For cross-platform (Google Cloud Vision API):

1. Create wrapper:
   recognizeTextWithVision(imageData: base64, languageHints?: LanguageCode[]) -> Promise<string>

2. Google Vision handles all scripts with same API call
   - languageHints parameter improves accuracy
   - Returns text with automatic segmentation

Error handling:
- Image too blurry -> specific error type
- Low confidence -> return with warning flag
- Partial recognition -> return what was read with gaps marked

Test with actual images in each language to verify accuracy.
```

---

### Task 8: Integrate into URL Import Flow

```
Modify the URL import flow to support foreign language recipes.

Find the existing URL import handler and update to:

1. After fetching page content:
   - Call languageDetection.detectLanguageFromUrl(url, html)
   - Store detected language and confidence

2. After extracting recipe:
   - Parse ingredients with language-aware parser:
     unitParser.parseIngredientText(ingredient, detectedLanguage)
   - Detect unit system:
     unitParser.detectUnitSystem(parsedIngredients)

3. Before saving, show preview with language info:
   - "This recipe appears to be in French (98% confident)"
   - Options: [Import in French] [Translate to English (Beta)]

4. If user chooses translate:
   - Call recipeTranslation.translateRecipe()
   - Store both originalText and translatedText
   - Add translationMetadata

5. Apply unit conversion based on user settings:
   - If autoConvertUnits and sourceUnitSystem != preferredUnitSystem
   - Convert and store convertedQuantity on each ingredient

6. Save recipe with all new fields populated
```

---

### Task 9: Integrate into OCR Import Flow

```
Modify the OCR/image import flow to support foreign languages.

Update the OCR flow:

1. Before OCR:
   - Detect script type from image (if possible via quick pre-scan)
   - Or use user's defaultImportLanguage setting as hint

2. Run OCR with language hints:
   - Pass detected/hinted languages to OCR service
   - Get raw text result

3. After OCR:
   - Detect language from OCR'd text content
   - Parse recipe structure (this may need language-aware parsing)

4. Parse ingredients with language awareness:
   - Same as URL flow: use unitParser with detected language

5. Show preview with:
   - OCR'd text for user review
   - Detected language
   - Translation option

6. Same save flow as URL import
```

---

### Task 10: Settings UI for Units & Language

```
Add settings for unit preferences and language handling.
Reference: docs/multilingual-import-spec.md "Settings UI" for layout.

Create or modify settings screen sections:

MEASUREMENTS SECTION:
- "Unit System" picker: Imperial / Metric
- "When importing recipes" toggles:
  - Auto-convert to my preferred units (default: ON)
  - Show original measurements alongside (default: OFF)
- "Temperature display" picker: Fahrenheit / Celsius

RECIPE LANGUAGE SECTION:
- "When importing foreign recipes" radio:
  - Ask me each time (default)
  - Import in original language
  - Auto-translate to English (Beta)
- Link to "View my reported issues" (if any)

Wire up settings to UserSettings model.
Ensure settings are read during import flow.
```

---

### Task 11: Translation Feedback UI

```
Add UI for users to report translation issues.
Reference: docs/multilingual-import-spec.md "User Feedback System" for data model.

1. On translated recipe view, add a banner:
   "Translation (Beta) — [Looks good ✓] [Report issue]"

2. "Looks good" action:
   - Store positive feedback
   - Update translationMetadata.userVerified = true
   - Dismiss banner

3. "Report issue" action opens sheet/modal:
   - Select field type: Title / Ingredient / Instruction / Other
   - If Ingredient/Instruction: Show list to select specific one
   - Show original text and translation side by side
   - Text field for user comment (optional)
   - Text field for suggested translation (optional)
   - Submit button

4. Store TranslationFeedback:
   - Link to recipe
   - Store field, originalText, translatedText, userComment
   - Timestamp

5. Show confirmation: "Thanks for helping us improve!"

Consider: Analytics event for tracking feedback volume by language
```

---

### Task 12: Recipe Detail - Dual Language Display

```
Modify recipe detail view to handle bilingual recipes.

When recipe has both originalText and translatedText:

1. Add language toggle in header:
   [English] [Français] (or appropriate language name)
   
2. When viewing translated (English):
   - Show translatedText content
   - Show translation beta banner with feedback option
   - Ingredients show translated names with converted units

3. When viewing original:
   - Show originalText content
   - Ingredients show original text with original units

4. Unit display based on settings:
   - If showOriginalUnits AND viewing translated:
     "1¾ cups flour (200g)" or "200g flour (1¾ cups)"
   - Otherwise just show preferred system

5. Visual indicator for translated content:
   - Subtle "Translated" badge
   - Or different background tint
```

---

### Task 13: Ingredient Display Component

```
Create/modify ingredient display component to handle:
- Original language text
- Translated text
- Unit conversion display

Props:
- ingredient: LocalizedIngredient
- displayLanguage: "original" | "translated"
- unitSystem: "metric" | "imperial"
- showBothUnits: boolean

Render logic:
1. Get display text based on displayLanguage
2. Get quantity display based on unitSystem
3. If showBothUnits, format as: "primary (secondary)"

Examples:
- Metric user, French recipe, translated:
  "200g flour" or "200g (1¾ cups) flour"
  
- Imperial user, French recipe, translated:
  "1¾ cups flour" or "1¾ cups (200g) flour"
  
- Any user, viewing original:
  "200g de farine"

Handle edge cases:
- No quantity ("salt to taste") -> display as-is
- Unknown unit -> display original, no conversion
- Ingredient-specific conversion available -> use it
```

---

### Task 14: Testing - Unit Conversion

```
Create comprehensive tests for unit conversion.

Test file: __tests__/unitConversion.test.ts

Test categories:

1. Basic metric -> imperial:
   - 100g -> "3.5 oz"
   - 500ml -> "2 cups"
   - 1kg -> "2.2 lb"

2. Basic imperial -> metric:
   - 1 cup -> "240 ml"
   - 1 lb -> "454 g"
   - 1 oz -> "28 g"

3. Fraction formatting:
   - 0.5 -> "½"
   - 1.75 -> "1¾"
   - 2.333 -> "2⅓"

4. Ingredient-specific (volume to weight):
   - 1 cup flour -> "125g"
   - 1 cup sugar -> "200g"
   - 1 cup butter -> "227g"

5. Language-specific unit parsing (Latin):
   - "2 c. à soupe" (French) -> 2 tablespoons
   - "250ml de lait" (French) -> quantity: 250, unit: ml
   - "1 EL Öl" (German) -> 1 tablespoon

6. Language-specific unit parsing (CJK):
   - "小麦粉 2カップ" (Japanese) -> 2 cups (400ml, NOT 480ml!)
   - "大さじ1" (Japanese) -> 1 tablespoon
   - "설탕 1컵" (Korean) -> 1 cup (200ml)
   - "面粉 2杯" (Chinese) -> 2 cups (480ml, Chinese uses US cup)

7. CRITICAL: Japanese/Korean cup conversion:
   - 1 カップ (ja) -> 200ml -> "0.85 cups" or "6.8 fl oz" (imperial)
   - 1 컵 (ko) -> 200ml -> "0.85 cups" or "6.8 fl oz" (imperial)
   - Do NOT convert as 240ml!

8. Edge cases:
   - Ranges: "1-2 cups" -> both converted
   - No quantity: "salt to taste" -> unchanged
   - Mixed fractions: "1 1/2 cups" -> parsed correctly
   - Unicode fractions: "½ tasse" -> 0.5 cup

9. Round-trip accuracy:
   - 200g -> imperial -> metric should ≈ 200g
   - 1 カップ -> imperial -> metric should = 200ml (not 240ml)
```

---

### Task 15: Testing - Translation Flow

```
Create integration tests for translation flow.

Test file: __tests__/translation.test.ts

Test scenarios:

1. Mock Claude API response and verify:
   - JSON parsing works
   - All fields populated
   - Confidence score extracted

2. Language detection accuracy:
   - French HTML with lang="fr" -> detected as French
   - German text content -> detected as German
   - Mixed content -> reasonable fallback

3. Full import flow (mocked):
   - URL with French recipe
   - Language detected
   - Recipe extracted
   - Translation requested
   - Both versions stored

4. Error handling:
   - API timeout -> graceful fallback message
   - Malformed response -> error logged, user notified
   - Partial translation -> warnings included

5. User feedback storage:
   - Report issue flow stores correctly
   - Positive feedback updates metadata
```

---

## Quick Reference: Supported Languages (Launch)

### Latin Script
| Language | Code | OCR Config | Unit Patterns |
|----------|------|------------|---------------|
| French | fr | fr-FR | g, kg, ml, L, cl, c. à soupe, c. à café |
| Spanish | es | es-ES | g, kg, ml, L, cucharada, cucharadita, taza |
| German | de | de-DE | g, kg, ml, L, EL (Esslöffel), TL (Teelöffel) |

### CJK Script
| Language | Code | OCR Config | Unit Patterns | Cup Size |
|----------|------|------------|---------------|----------|
| Japanese | ja | ja-JP | g, ml, カップ, 大さじ, 小さじ | **200ml** |
| Mandarin | zh | zh-Hans/zh-Hant | 克, 毫升, 杯, 大匙, 小匙 | 240ml |
| Korean | ko | ko-KR | g, ml, 컵, 큰술, 작은술 | **200ml** |

---

## Testing Checklist

### Unit Conversion
- [ ] Metric to imperial converts correctly
- [ ] Imperial to metric converts correctly
- [ ] Fractions display properly (½, ¾, etc.)
- [ ] Ingredient-specific conversions work (flour, sugar, etc.)
- [ ] Japanese cup (200ml) converts correctly (not as 240ml!)
- [ ] Korean cup (200ml) converts correctly
- [ ] Edge cases handled (ranges, no quantity, unknown units)
- [ ] Settings respected (preferred system, show both)

### Language Detection
- [ ] HTML lang attribute detected
- [ ] Meta tags detected
- [ ] URL TLD provides hint
- [ ] Content analysis fallback works
- [ ] CJK script detection works (Japanese vs Chinese vs Korean)
- [ ] User can override detected language

### OCR
- [ ] French text recognized accurately
- [ ] Spanish text recognized accurately
- [ ] German text recognized accurately
- [ ] Japanese text recognized accurately (kanji + hiragana + katakana)
- [ ] Chinese text recognized accurately (Simplified and Traditional)
- [ ] Korean text recognized accurately (Hangul)
- [ ] Special characters handled (é, ñ, ü, ß)
- [ ] Handwritten text reasonable accuracy

### Translation
- [ ] Claude API integration works
- [ ] Culinary terms preserved appropriately
- [ ] Units NOT converted during translation
- [ ] Untranslatable terms flagged
- [ ] Japanese → English works well
- [ ] Chinese → English works well
- [ ] Korean → English works well
- [ ] Fallback to Google works if Claude fails

### User Flow
- [ ] URL import shows language detection
- [ ] OCR import shows language detection
- [ ] Translation option presented clearly
- [ ] Beta warning displayed
- [ ] Feedback mechanism works
- [ ] Settings control behavior correctly

---

## API Setup Requirements

### Claude API (Translation)

```bash
export ANTHROPIC_API_KEY="your-api-key"
```

### Google Cloud (OCR + Translation Fallback)

```bash
# Enable Cloud Vision API and Cloud Translation API in Google Cloud Console
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
```

### Local Development

For local dev without full API access:
1. Mock translation responses for testing
2. Use local OCR if available (Tesseract)
3. Test unit conversion without translation dependency
