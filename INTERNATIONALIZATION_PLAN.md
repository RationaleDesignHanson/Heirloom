# Internationalization Plan: French, German, Spanish

## Overview
Add full multi-language support for French (FR), German (DE), and Spanish (ES) across all app features.

## Current State ✅
- **OCR**: Vision framework with `automaticallyDetectsLanguage = true`
- **Basic Infrastructure**: iOS provides strong i18n support
- **No Existing Localization**: Starting from scratch

---

## Implementation Plan

### Phase 1: Core UI Localization (2-3 days)

#### 1.1 Setup Xcode String Catalog
- [ ] Create `Localizable.xcstrings` in Xcode
- [ ] Add languages: French (fr), German (de), Spanish (es)
- [ ] Configure base language: English (en)

#### 1.2 Extract & Localize UI Strings
**Current**: Hardcoded strings throughout SwiftUI views
```swift
Text("Recipe")  // Current
Text(String(localized: "recipe.title"))  // Target
```

**Files to Update** (~100-150 strings):
- Navigation titles
- Button labels
- Form labels
- Error messages
- Empty states
- Settings screens
- Onboarding screens

**Effort**: 1-2 days (extraction + translation)

---

### Phase 2: OCR Multi-Language Support (1 day)

#### 2.1 Update OCR Language Detection
**File**: `EnhancedOCRService.swift:83`

**Current**:
```swift
request.recognitionLanguages = ["en-US"]
```

**Target**:
```swift
// Get user's preferred language or auto-detect
let preferredLanguages = ["en-US", "fr-FR", "de-DE", "es-ES"]
request.recognitionLanguages = preferredLanguages
request.automaticallyDetectsLanguage = true  // Already set ✅
```

**Vision Framework Support**: ✅ Already supports FR, DE, ES out-of-box

---

### Phase 3: AI Recipe Extraction (2-3 days)

#### 3.1 Multi-Language AI Prompts
**Files**:
- `AIRecipeExtractor.swift`
- `AIIngredientParser.swift`

**Strategy**: Detect language + use language-specific prompts

**Example**:
```swift
private func extractionPrompt(for language: RecipeLanguage) -> String {
    switch language {
    case .english:
        return "Extract the recipe from this image..."
    case .french:
        return "Extraire la recette de cette image..."
    case .german:
        return "Extrahieren Sie das Rezept aus diesem Bild..."
    case .spanish:
        return "Extraer la receta de esta imagen..."
    }
}
```

**AI Capability**: Claude (Anthropic) fully supports FR/DE/ES ✅

#### 3.2 Language Detection
**New Service**: `LanguageDetectionService.swift`

```swift
enum RecipeLanguage: String {
    case english = "en"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

class LanguageDetectionService {
    static func detect(from text: String) -> RecipeLanguage {
        // Use NaturalLanguage framework
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let languageCode = recognizer.dominantLanguage?.rawValue {
            return RecipeLanguage(rawValue: languageCode) ?? .english
        }
        return .english
    }
}
```

---

### Phase 4: Ingredient Parsing (3-4 days)

#### 4.1 Multi-Language Ingredient Parser
**File**: `IngredientParser.swift`

**Challenges**:
- Different measurement systems (metric vs imperial)
- Different units names:
  - English: "cup", "tablespoon", "teaspoon"
  - French: "tasse", "cuillère à soupe", "cuillère à café"
  - German: "Tasse", "Esslöffel", "Teelöffel"
  - Spanish: "taza", "cucharada", "cucharadita"

**Solution**: Language-specific unit dictionaries

```swift
private static let unitMappings: [RecipeLanguage: [String: String]] = [
    .english: ["cup": "cup", "tbsp": "tablespoon", "tsp": "teaspoon"],
    .french: ["tasse": "cup", "cs": "tablespoon", "cc": "teaspoon"],
    .german: ["Tasse": "cup", "EL": "tablespoon", "TL": "teaspoon"],
    .spanish: ["taza": "cup", "cdta": "tablespoon", "cdita": "teaspoon"]
]
```

**AI Alternative**: Let Claude handle parsing in native language, then normalize

#### 4.2 Measurement Conversion
**New**: `MeasurementConverter.swift`
- Metric ↔ Imperial conversion
- User preference: show original or converted

---

### Phase 5: Recipe Content Localization (1-2 days)

#### 5.1 Recipe Metadata
**Fields to Localize**:
- Categories (Breakfast, Lunch, Dinner, Dessert)
- Tags (Vegetarian, Vegan, Gluten-Free)
- Source types (Family, Website, Cookbook)

**Strategy**:
- Store in original language
- Display using localized lookup table
- Or: Store language code with recipe

#### 5.2 Share/Export Messages
**Files**: `FirebaseShareService.swift`, `RecipeShareSheet.swift`

**Example**:
```swift
// Personal message template
let template = String(
    localized: "share.message.template",
    defaultValue: "I'd love to share this recipe with you!"
)
```

---

### Phase 6: Testing & Quality (2-3 days)

#### 6.1 Test Scenarios
- [ ] Import French recipe from image
- [ ] Import German recipe from PDF
- [ ] Import Spanish recipe from text
- [ ] Share recipe with French UI
- [ ] Edit recipe with German units
- [ ] Search recipes in Spanish
- [ ] OCR mixed-language cookbook

#### 6.2 Translation Quality
- [ ] Professional translation service (recommended)
- [ ] OR: Community translators
- [ ] OR: AI translation with native speaker review

---

## Effort Estimate

| Phase | Days | Notes |
|-------|------|-------|
| 1. UI Localization | 2-3 | String extraction + translation |
| 2. OCR Support | 1 | Config changes only |
| 3. AI Extraction | 2-3 | Multi-language prompts |
| 4. Ingredient Parsing | 3-4 | Complex due to units |
| 5. Content Localization | 1-2 | Metadata + messages |
| 6. Testing | 2-3 | QA + fixes |
| **TOTAL** | **11-16 days** | ~2-3 weeks |

---

## Cost Considerations

### Translation Services
- **Professional**: $0.10-0.20/word
  - ~1000 strings × 10 words avg = 10,000 words
  - Cost: $1,000-2,000 per language
  - **Total**: $3,000-6,000 for 3 languages

- **AI Translation (Claude)**:
  - ~$50-100 for initial translation
  - Requires native speaker review
  - **Total**: $150-300 + review time

- **Community/Crowdsource**:
  - Free but time-intensive
  - Quality varies

### Recommendation
**Hybrid Approach**:
1. AI translate UI strings ($100)
2. Professional translator review ($500/language)
3. **Total**: ~$1,600 for high quality

---

## Technical Architecture

### Locale Management
```swift
enum AppLocale: String, CaseIterable {
    case english = "en"
    case french = "fr"
    case german = "de"
    case spanish = "es"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        }
    }

    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        }
    }
}

class LocaleManager: ObservableObject {
    @Published var currentLocale: AppLocale

    static let shared = LocaleManager()

    init() {
        // Auto-detect from system or use saved preference
        let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
        self.currentLocale = AppLocale(rawValue: systemLang) ?? .english
    }
}
```

### Recipe Language Storage
**Add to Recipe model**:
```swift
@Model
final class Recipe {
    // ...existing fields...

    /// Language of recipe content (for proper display/parsing)
    var contentLanguage: String? // ISO 639-1 code ("en", "fr", "de", "es")

    /// Original language (if translated)
    var originalLanguage: String?
}
```

---

## User Experience

### Settings Screen Addition
```
Settings > Language & Region
├── App Language
│   ├── English 🇺🇸
│   ├── Français 🇫🇷
│   ├── Deutsch 🇩🇪
│   └── Español 🇪🇸
│
├── Measurement System
│   ├── Imperial (cups, oz, °F)
│   └── Metric (ml, g, °C)
│
└── Recipe Language Detection
    ├── Automatic (recommended)
    └── Manual selection
```

---

## Quick Start (Minimal Viable Product)

If you want **basic** multi-language support quickly (3-5 days):

### MVP Scope
1. ✅ OCR language detection (already works!)
2. ✅ AI extraction with language-aware prompts (2 days)
3. ✅ Basic UI localization for critical strings (1 day)
4. ❌ Skip full ingredient parser localization
5. ❌ Skip measurement conversion

**Result**: Users can import FR/DE/ES recipes, but units stay in original language

---

## Next Steps

1. **Decide on scope**: Full implementation vs MVP
2. **Choose translation approach**: Professional vs AI+review vs community
3. **Prioritize languages**: Do you need all 3, or start with 1?
4. **Create Xcode string catalog**: Foundation for everything else

**Want me to start with any specific phase?** I can:
- Set up the Xcode string catalog
- Implement language detection service
- Update OCR for multi-language
- Create multi-language AI prompts

Let me know what you'd like to tackle first! 🌍
