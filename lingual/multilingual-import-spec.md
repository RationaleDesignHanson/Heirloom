# Multilingual Recipe Import: Design Specification

> **Purpose:** Enable users to import recipes from non-English sources (websites and scanned documents) while preserving the original language and offering optional English translation.

---

## Overview

### Philosophy
Family recipes cross borders. A user's grandmother's handwritten recipe card might be in German, or they might find their great-aunt's dish on a French cooking blog. Heirloom should accept these recipes in their native language—preserving authenticity—while making them accessible through optional translation.

### Scope
- **In scope:** Importing and storing recipes in foreign languages, optional translation to English, metric/imperial conversion
- **Out of scope:** Localizing the app UI (future roadmap item)

### Language Tiers

| Tier | Languages | Script | OCR Complexity | Priority |
|------|-----------|--------|----------------|----------|
| 1A | French, Spanish, German | Latin | Low | Launch |
| 1B | Japanese, Mandarin, Korean | CJK | Medium | Launch |
| 2 | Italian, Portuguese, Dutch | Latin | Low | Fast-follow |
| 3 | Hindi, Arabic, Hebrew | Brahmic/RTL | Medium-High | Phase 2 |

**Note on CJK:** Modern OCR (Google Vision, Apple Vision iOS 16+) handles CJK scripts well. The additional complexity is:
- Japanese cup = 200ml (not US 240ml) — handled in unit conversion
- No word boundaries in Chinese/Japanese — OCR handles segmentation
- Character set mixing in Japanese (kanji + hiragana + katakana) — Vision handles this

The translation lift is identical across all tiers—Claude handles all these languages well.

---

## Data Model Extensions

### Recipe Model Additions

```typescript
interface Recipe {
  // ... existing fields ...
  
  // Language & Translation
  sourceLanguage: LanguageCode;           // ISO 639-1: "fr", "es", "de", "ja", etc.
  sourceLanguageConfidence: number;       // 0-1, from auto-detection
  originalText: LocalizedRecipeText;      // Full recipe in original language
  translatedText?: LocalizedRecipeText;   // English translation if requested
  translationMetadata?: TranslationMetadata;
  
  // Units
  sourceUnitSystem: "metric" | "imperial" | "mixed" | "unknown";
  ingredients: LocalizedIngredient[];     // Extended ingredient model
}

interface LocalizedRecipeText {
  title: string;
  description?: string;
  instructions: string[];
  notes?: string;
  languageCode: LanguageCode;
}

interface LocalizedIngredient {
  original: string;                       // "200g de farine"
  parsed: ParsedIngredient;               // Structured: { quantity: 200, unit: "g", item: "farine" }
  translated?: string;                    // "200g flour" or "1¾ cups flour"
  convertedQuantity?: ConvertedQuantity;  // For unit switching
}

interface ParsedIngredient {
  quantity: number | null;                // 200
  quantityMax?: number;                   // For ranges: "1-2 cups"
  unit: string | null;                    // "g"
  unitNormalized: NormalizedUnit;         // "gram"
  item: string;                           // "farine"
  preparation?: string;                   // "sifted", "chopped"
  optional: boolean;
}

interface ConvertedQuantity {
  metric: { quantity: number; unit: string; display: string };    // "200g"
  imperial: { quantity: number; unit: string; display: string };  // "1¾ cups"
}

interface TranslationMetadata {
  translatedAt: Date;
  translationService: "claude" | "google" | "deepl";
  modelVersion?: string;
  confidence: number;                     // 0-1
  userVerified: boolean;                  // User confirmed translation is good
  userReportedIssues?: TranslationIssue[];
}

interface TranslationIssue {
  reportedAt: Date;
  field: "title" | "ingredient" | "instruction" | "other";
  originalText: string;
  translatedText: string;
  userComment?: string;
  resolved: boolean;
}

type LanguageCode = "en" | "fr" | "es" | "de" | "it" | "pt" | "nl" | 
                    "ja" | "zh" | "ko" | "hi" | "ar" | "he";

type NormalizedUnit = 
  // Metric
  | "gram" | "kilogram" | "milliliter" | "liter" | "centimeter"
  // Imperial  
  | "ounce" | "pound" | "cup" | "tablespoon" | "teaspoon" | "fluid_ounce" | "pint" | "quart" | "gallon" | "inch"
  // Universal
  | "piece" | "pinch" | "bunch" | "clove" | "slice" | "whole"
  // Unknown
  | "unknown";
```

### User Settings Additions

```typescript
interface UserSettings {
  // ... existing fields ...
  
  // Unit preferences
  preferredUnitSystem: "metric" | "imperial";
  autoConvertUnits: boolean;              // Show converted units inline
  showOriginalUnits: boolean;             // Show source units alongside converted
  
  // Language preferences
  autoTranslateRecipes: boolean;          // Auto-translate on import or ask first
  preferredLanguages: LanguageCode[];     // For recipe browsing/search
  
  // Import preferences
  defaultImportLanguage?: LanguageCode;   // Hint for OCR if detection fails
}
```

---

## Import Flows

### Flow 1: URL Import (Foreign Website)

```
User pastes URL
     ↓
Fetch page content
     ↓
Detect language (from HTML lang attr, meta tags, or content analysis)
     ↓
Extract recipe using existing scraping logic
     ↓
Parse ingredients (language-aware)
     ↓
Detect unit system
     ↓
Store with sourceLanguage set
     ↓
Show preview: "This recipe is in French. [Import as-is] [Translate to English (Beta)]"
     ↓
If translate: Call translation service → Store both versions
     ↓
Apply unit conversion based on user settings
```

### Flow 2: OCR Import (Scanned Document)

```
User captures/uploads image
     ↓
Detect script type (Latin, CJK, Devanagari, Arabic, etc.)
     ↓
Select appropriate OCR model/configuration
     ↓
Run OCR → Raw text
     ↓
Detect language from text content
     ↓
Parse recipe structure (title, ingredients, instructions)
     ↓
Parse ingredients (language-aware)
     ↓
[Same flow as URL import from here]
```

### Flow 3: Manual Entry (Foreign Language)

```
User creates new recipe
     ↓
User selects "Recipe language: [dropdown]"
     ↓
User enters content in selected language
     ↓
On save: Parse ingredients, detect units
     ↓
Offer translation option
```

---

## Language Detection

### Strategy
1. **URL Import:** Check HTML `lang` attribute, `Content-Language` header, meta tags first
2. **Fallback:** Use text-based detection (Claude API or library like `franc`)
3. **OCR:** Detect script first (narrows options), then language within script
4. **User Override:** Always allow user to correct detected language

### Implementation

```typescript
interface LanguageDetectionResult {
  detected: LanguageCode;
  confidence: number;           // 0-1
  method: "html_attr" | "meta_tag" | "content_analysis" | "ocr_script" | "user_override";
  alternativeCandidates?: Array<{ language: LanguageCode; confidence: number }>;
}

// Detection priority for URL import
async function detectLanguageFromUrl(url: string, htmlContent: string): Promise<LanguageDetectionResult> {
  // 1. Check <html lang="fr">
  // 2. Check <meta http-equiv="Content-Language">
  // 3. Check URL TLD (.fr, .de, .es)
  // 4. Fall back to content analysis
}

// Detection for OCR
async function detectLanguageFromImage(image: ImageData): Promise<LanguageDetectionResult> {
  // 1. Detect script type (Latin, CJK, Devanagari, Arabic)
  // 2. If Latin, analyze character frequency for language
  // 3. If CJK, distinguish Japanese/Chinese/Korean by character sets
  // 4. Run language detection on OCR'd text to confirm
}
```

---

## OCR Pipeline

### Tier 1: Latin Script (French, Spanish, German)

**Recommended Approach:**
- **iOS:** Vision framework (`VNRecognizeTextRequest`) with `recognitionLanguages` set
- **Cross-platform:** Google Cloud Vision API or Tesseract 5

**Configuration:**
```typescript
const latinOcrConfig = {
  recognitionLanguages: ["fr-FR", "es-ES", "de-DE", "en-US"],
  recognitionLevel: "accurate",  // vs "fast"
  usesLanguageCorrection: true,
  minimumTextHeight: 0.02,       // Filter noise
};
```

### Tier 3: CJK Scripts (Japanese, Mandarin, Korean)

**Considerations:**
- Japanese mixes kanji, hiragana, katakana—all must be recognized
- Chinese has Traditional and Simplified variants
- Korean Hangul is phonetic but may include Hanja

**Recommended Approach:**
- **iOS:** Vision framework handles CJK well as of iOS 16+
- **Cross-platform:** Google Cloud Vision API (best CJK support)

**Configuration:**
```typescript
const cjkOcrConfig = {
  recognitionLanguages: ["ja-JP", "zh-Hans", "zh-Hant", "ko-KR"],
  // CJK has no word boundaries—segment by character
  customWords: [],  // Can add recipe-specific terms
};
```

### Tier 4: Brahmic/RTL Scripts (Hindi, Arabic, Hebrew)

**Considerations:**
- Hindi (Devanagari) connects characters—ligature handling critical
- Arabic/Hebrew are right-to-left—text direction must be preserved
- Arabic has multiple forms per letter based on position

**Recommended Approach:**
- **Google Cloud Vision API** has best support for these scripts
- Tesseract 5 with specific language packs

---

## Translation Service

### Architecture

```typescript
interface TranslationService {
  translate(request: TranslationRequest): Promise<TranslationResult>;
  translateIngredient(ingredient: string, from: LanguageCode): Promise<string>;
  translateInstructions(instructions: string[], from: LanguageCode): Promise<string[]>;
}

interface TranslationRequest {
  sourceLanguage: LanguageCode;
  targetLanguage: LanguageCode;  // Always "en" for now
  recipe: {
    title: string;
    description?: string;
    ingredients: string[];
    instructions: string[];
    notes?: string;
  };
}

interface TranslationResult {
  translated: {
    title: string;
    description?: string;
    ingredients: string[];
    instructions: string[];
    notes?: string;
  };
  confidence: number;
  warnings?: string[];  // E.g., "Some cooking terms may be approximate"
}
```

### Claude API Implementation

**System Prompt:**
```
You are a culinary translator specializing in recipe translation. Translate the following recipe from {sourceLanguage} to English.

Guidelines:
- Preserve cooking terminology accurately (sauté, braise, julienne, etc.)
- Keep ingredient names recognizable (don't translate "fromage blanc" to "white cheese"—use "fromage blanc" or "quark")
- Maintain original measurements (do not convert units)
- Preserve cultural context in descriptions
- Flag any terms that have no direct English equivalent with [original term]
- Keep proper nouns (dish names, regional specialties) in original language with English explanation if needed

Output format: Return a JSON object with translated fields.
```

**Example call:**
```typescript
async function translateRecipeWithClaude(recipe: LocalizedRecipeText, sourceLanguage: LanguageCode): Promise<TranslationResult> {
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 2000,
    system: TRANSLATION_SYSTEM_PROMPT.replace("{sourceLanguage}", getLanguageName(sourceLanguage)),
    messages: [{
      role: "user",
      content: JSON.stringify(recipe)
    }]
  });
  
  return parseTranslationResponse(response);
}
```

### Fallback: Google Translate API

For high-volume or cost-sensitive scenarios:
```typescript
async function translateWithGoogle(text: string, from: LanguageCode, to: LanguageCode): Promise<string> {
  // Use Google Cloud Translation API
  // Less accurate for culinary terms but faster/cheaper
}
```

---

## Unit Conversion System

### Philosophy
- **Source of truth:** Always store original values
- **Display flexibility:** Convert on-the-fly based on user settings
- **Precision:** Use fractions for imperial (½, ¾) not decimals
- **Transparency:** Show original alongside converted when helpful

### Unit Mapping Table

| Metric | Imperial Equivalent | Notes |
|--------|---------------------|-------|
| 1g | 0.035 oz | Below 28g, use "pinch" or gram |
| 28g | 1 oz | |
| 100g | 3.5 oz | |
| 250g | 8.8 oz / 1 cup* | *Depends on ingredient density |
| 1kg | 2.2 lb | |
| 1ml | 0.034 fl oz | Below 15ml, use tsp |
| 5ml | 1 tsp | |
| 15ml | 1 tbsp | |
| 60ml | ¼ cup | |
| 120ml | ½ cup | |
| 240ml | 1 cup | |
| 1L | 4.2 cups / 1 quart | |
| 1cm | 0.4 in | |

### Volume ↔ Weight Conversion (Ingredient-Specific)

Critical for accuracy—flour measured by volume vs. weight differs significantly:

| Ingredient | 1 cup (US) = grams |
|------------|-------------------|
| All-purpose flour | 125g |
| Bread flour | 130g |
| Sugar (granulated) | 200g |
| Sugar (powdered) | 120g |
| Butter | 227g (2 sticks) |
| Milk/Water | 240g |
| Rice (uncooked) | 185g |
| Honey | 340g |
| Oats | 90g |

### Conversion Implementation

```typescript
interface UnitConverter {
  convert(value: number, fromUnit: NormalizedUnit, toSystem: "metric" | "imperial"): ConvertedQuantity;
  formatQuantity(value: number, unit: string, system: "metric" | "imperial"): string;
  parseQuantity(text: string, language: LanguageCode): ParsedIngredient;
}

// Smart rounding for imperial
function roundToFraction(value: number): string {
  const fractions = [
    { value: 0.125, display: "⅛" },
    { value: 0.25, display: "¼" },
    { value: 0.333, display: "⅓" },
    { value: 0.375, display: "⅜" },
    { value: 0.5, display: "½" },
    { value: 0.625, display: "⅝" },
    { value: 0.666, display: "⅔" },
    { value: 0.75, display: "¾" },
    { value: 0.875, display: "⅞" },
  ];
  
  const whole = Math.floor(value);
  const decimal = value - whole;
  
  // Find closest fraction
  const closest = fractions.reduce((prev, curr) => 
    Math.abs(curr.value - decimal) < Math.abs(prev.value - decimal) ? curr : prev
  );
  
  if (decimal < 0.0625) return whole.toString();
  if (whole === 0) return closest.display;
  return `${whole}${closest.display}`;
}

// Example: 200g flour → "1¾ cups flour" or "7 oz flour"
function convertIngredient(
  quantity: number, 
  unit: NormalizedUnit, 
  ingredientType: string,
  toSystem: "metric" | "imperial"
): ConvertedQuantity {
  // ... implementation
}
```

### Unit Detection by Language

| Language | Common Units | Notes |
|----------|-------------|-------|
| French | g, kg, ml, L, cl, c. à soupe, c. à café | cl = centiliter (10ml) |
| Spanish | g, kg, ml, L, cucharada, cucharadita, taza | taza = cup (varies by country) |
| German | g, kg, ml, L, EL (Esslöffel), TL (Teelöffel) | EL = tbsp, TL = tsp |
| Japanese | g, ml, カップ (kappu), 大さじ (ōsaji), 小さじ (kosaji) | **カップ = 200ml (not 240ml!)** |
| Mandarin | 克 (kè/g), 毫升 (háoshēng/ml), 杯 (bēi/cup), 大匙, 小匙 | 杯 often = 240ml |
| Korean | g, ml, 컵 (keop/cup), 큰술 (keun-sul/tbsp), 작은술 (jageun-sul/tsp) | 컵 = 200ml (follows Japanese) |

**Critical:** Japanese and Korean cups are 200ml, not US 240ml. This must be handled in conversion.

---

## User Feedback System

### Translation Quality Feedback

**UI Flow:**
```
User views translated recipe
     ↓
Sees banner: "Translation (Beta) - How did we do? [Looks good ✓] [Report issue]"
     ↓
If "Report issue":
  - Select field: Title / Ingredient / Instruction step / Other
  - Highlight specific text
  - Optional comment
  - Submit
     ↓
Store in TranslationIssue, flag for review
```

### Feedback Data Model

```typescript
interface TranslationFeedback {
  id: string;
  recipeId: string;
  userId: string;
  feedbackType: "positive" | "issue";
  issueDetails?: {
    field: "title" | "ingredient" | "instruction" | "other";
    stepIndex?: number;        // For instructions
    ingredientIndex?: number;  // For ingredients
    originalText: string;
    translatedText: string;
    userComment?: string;
    suggestedTranslation?: string;
  };
  sourceLanguage: LanguageCode;
  createdAt: Date;
}
```

### Analytics to Track

- Translation acceptance rate by language
- Most common error categories by language
- Ingredients with frequent issues (build correction dictionary)
- Unit conversion complaints

---

## Settings UI

### Measurements Section

```
MEASUREMENTS
─────────────────────────────────
Unit System              [Imperial ▾]
                         • Imperial (cups, oz, °F)
                         • Metric (g, ml, °C)

When importing recipes:
☑ Auto-convert to my preferred units
☑ Show original measurements alongside

Temperature display      [Fahrenheit ▾]
```

### Language Section

```
RECIPE LANGUAGE
─────────────────────────────────
When importing foreign recipes:
  ○ Ask me each time
  ● Import in original language
  ○ Auto-translate to English (Beta)

Translation quality
  Help us improve! Report translation issues
  directly from any translated recipe.
  
  [View my reported issues →]
```

---

## Error Handling

### OCR Failures

| Scenario | User Message | Action |
|----------|-------------|--------|
| Image too blurry | "We couldn't read this image clearly. Try taking a new photo with better lighting." | Offer retake |
| Unsupported script | "We don't support [script] yet. You can enter this recipe manually." | Show manual entry |
| Partial read | "We read most of this recipe but some parts are unclear. Please review and edit." | Show with highlights |

### Translation Failures

| Scenario | User Message | Action |
|----------|-------------|--------|
| Service unavailable | "Translation isn't available right now. Your recipe was saved in [language]—you can translate it later." | Save without translation |
| Low confidence | "We're not confident about this translation. Please review carefully." | Show with warning banner |
| Unknown terms | "Some terms couldn't be translated: [list]. These are kept in the original language." | Show inline |

### Unit Conversion Edge Cases

| Scenario | Handling |
|----------|----------|
| Unknown unit | Keep original, flag for user review |
| Ambiguous unit (e.g., "cup" varies by country) | Use source country's standard, note in UI |
| No quantity given ("salt to taste") | Keep as-is, don't convert |
| Range ("1-2 cups") | Convert both bounds |
| Fractions in source ("½ tasse") | Parse correctly before converting |

---

## Phase Rollout

### Phase 1: Tier 1A + 1B Languages (Latin + CJK)
**Languages:** French, Spanish, German, Japanese, Mandarin, Korean

- Latin script OCR (Vision/Google)
- CJK script OCR (same services, different config)
- Language detection (script-aware)
- Translation via Claude API (works for all)
- Metric/Imperial conversion with regional units (Japanese cup = 200ml)
- Basic feedback mechanism
- **Timeline:** 3-4 weeks

### Phase 2: Expand Latin Languages
- Add Italian, Portuguese, Dutch
- Minimal additional work (same OCR, same translation flow)
- **Timeline:** 1 week

### Phase 3: Brahmic/RTL Scripts
- Hindi (Devanagari)
- Arabic, Hebrew (RTL support in UI)
- **Timeline:** 3-4 weeks

---

## Success Metrics

| Metric | Target |
|--------|--------|
| OCR accuracy (Latin) | >95% character accuracy |
| OCR accuracy (CJK) | >90% character accuracy |
| Language detection accuracy | >98% |
| Translation acceptance rate | >80% "looks good" |
| Unit conversion accuracy | >99% (no incorrect conversions) |
| Time to import (URL) | <5 seconds |
| Time to import (OCR) | <10 seconds |
