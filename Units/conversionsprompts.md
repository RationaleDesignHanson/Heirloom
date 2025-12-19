# Heirloom Shopping List System: Claude Code Implementation Prompts

## Overview

These prompts guide Claude Code through building a bulletproof ingredient parsing and shopping list consolidation system. The architecture:

1. **Web Demo (React/TypeScript)** — Testing harness at heirloom.app/lab (hidden page)
2. **Core Logic** — Pure TypeScript functions that translate 1:1 to Swift
3. **Feedback System** — Captures user corrections for continuous improvement
4. **Swift Port** — Final implementation in the Heirloom iOS app

Each prompt is self-contained but references prior work. Run them sequentially.

---

# PHASE 1: Core Parser

## Prompt 1.1: Project Scaffolding

```
I'm building a bulletproof ingredient parsing and shopping list consolidation system for Heirloom, a recipe app. We need a React web demo that will serve as a testing harness before porting the logic to Swift/iOS.

Create a new project in ~/heirloom-shopping-lab with:

1. **Stack**: Vite + React 18 + TypeScript + Tailwind CSS
2. **Structure**:
   ```
   heirloom-shopping-lab/
   ├── src/
   │   ├── core/                    # Platform-agnostic parsing logic
   │   │   ├── parser/              # Ingredient parsing
   │   │   ├── units/               # Unit conversion
   │   │   ├── normalizer/          # Ingredient normalization
   │   │   ├── consolidator/        # Shopping list consolidation
   │   │   └── types/               # Shared TypeScript types
   │   ├── data/                    # Static data files
   │   │   ├── ingredients.json     # Canonical ingredients
   │   │   ├── synonyms.json        # Synonym mappings
   │   │   ├── units.json           # Unit definitions
   │   │   └── densities.json       # Ingredient densities
   │   ├── components/              # React UI components
   │   ├── hooks/                   # React hooks
   │   ├── pages/                   # Page components
   │   └── tests/                   # Test files
   ├── golden-tests/                # Golden test dataset
   └── swift-export/                # Generated Swift code
   ```

3. **Core Types** (src/core/types/index.ts):
   ```typescript
   // Parsed ingredient result
   interface ParsedIngredient {
     original: string;
     quantity: QuantityValue | null;
     unit: UnitInfo | null;
     ingredient: IngredientInfo;
     preparation: string[];
     modifiers: string[];
     confidence: number;
     flags: IngredientFlags;
   }

   // Quantity can be single, range, or fraction
   interface QuantityValue {
     type: 'single' | 'range' | 'approximate';
     value: number;
     valueLow?: number;
     valueHigh?: number;
     display: string;
   }

   // Unit information
   interface UnitInfo {
     canonical: string;        // e.g., "tablespoon"
     original: string;         // e.g., "Tbsp"
     type: 'volume' | 'weight' | 'count' | 'informal' | 'other';
     system: 'metric' | 'imperial' | 'universal';
     mlEquivalent?: number;    // For volume units
     gramEquivalent?: number;  // For weight units
   }

   // Ingredient information
   interface IngredientInfo {
     canonical: string;        // Normalized name
     original: string;         // As written
     category: IngredientCategory;
     subcategory?: string;
     aisleHint?: string;
   }

   // Special flags for handling
   interface IngredientFlags {
     optional: boolean;
     toTaste: boolean;
     forGarnish: boolean;
     divided: boolean;         // "2 eggs, divided"
     separated: boolean;       // "2 eggs, separated"
     partialUse: 'whites' | 'yolks' | 'juice' | 'zest' | null;
   }

   // Categories for grocery organization
   type IngredientCategory = 
     | 'produce' | 'dairy' | 'meat' | 'seafood' | 'bakery'
     | 'pantry' | 'spices' | 'condiments' | 'frozen' | 'beverages'
     | 'oils' | 'grains' | 'canned' | 'baking' | 'other';
   ```

4. **Initial Data Files**:
   - Create starter `units.json` with comprehensive unit mappings (T/Tbsp/tablespoon → tablespoon, t/tsp/teaspoon → teaspoon, etc.)
   - Include metric (ml, L, g, kg) and imperial (cup, oz, lb, fl oz)
   - Handle Australian tablespoon (20ml vs 15ml US)

5. **Dev Setup**:
   - ESLint + Prettier configured
   - Vitest for testing
   - Path aliases (@core, @data, @components)

Initialize the project and create all scaffolding. Make the types comprehensive—they're the foundation everything builds on.
```

## Prompt 1.2: Unit System Foundation

```
In ~/heirloom-shopping-lab, build the comprehensive unit conversion system.

Create src/core/units/index.ts with:

1. **Unit Registry** (src/data/units.json):
   Cover ALL common recipe unit variations:

   VOLUME (with ml equivalents):
   - teaspoon: t, tsp, tspn, teaspn → 4.93ml (US), 5ml (metric)
   - tablespoon: T, Tbsp, tbsp, TB, tbs, tbl → 14.79ml (US), 15ml (metric), 20ml (AU)
   - cup: c, C, cup, cups → 236.59ml (US), 250ml (metric/AU)
   - fluid ounce: fl oz, fl. oz., fluid ounce → 29.57ml
   - pint: pt, pint → 473.18ml (US), 568.26ml (UK)
   - quart: qt, quart → 946.35ml (US)
   - gallon: gal, gallon → 3785.41ml (US)
   - milliliter: ml, mL, milliliter, millilitre
   - liter: l, L, liter, litre → 1000ml

   WEIGHT (with gram equivalents):
   - ounce: oz, ounce → 28.35g
   - pound: lb, lbs, pound → 453.59g
   - gram: g, gram, grams, gm
   - kilogram: kg, kilogram, kilo → 1000g

   COUNT (no conversion, preserve as-is):
   - each, piece, whole, slice, clove, head, bunch, sprig, stalk, leaf, can, jar, package, bag, box, bottle, stick

   INFORMAL (with approximate equivalents):
   - pinch → ~0.31ml (1/16 tsp)
   - dash → ~0.62ml (1/8 tsp)
   - smidgen → ~0.15ml (1/32 tsp)
   - splash → ~2.5ml (1/2 tsp, liquids)
   - handful → ~30g (varies)
   - glug → ~15ml (1 tbsp, liquids)

2. **UnitConverter class**:
   ```typescript
   class UnitConverter {
     // Parse unit string to canonical form
     parseUnit(input: string): UnitInfo | null;
     
     // Convert between compatible units
     convert(value: number, from: UnitInfo, to: UnitInfo, ingredientDensity?: number): number | null;
     
     // Check if two units can be combined
     areCompatible(unit1: UnitInfo, unit2: UnitInfo): boolean;
     
     // Get best display unit for a quantity (e.g., 48 tsp → 1 cup)
     getBestDisplayUnit(quantity: number, unit: UnitInfo): { quantity: number; unit: UnitInfo };
     
     // Handle regional variants
     setRegion(region: 'US' | 'UK' | 'AU' | 'metric'): void;
   }
   ```

3. **Conversion Logic**:
   - Volume ↔ Volume: Direct conversion via ml
   - Weight ↔ Weight: Direct conversion via grams
   - Volume ↔ Weight: REQUIRES ingredient density (fail gracefully if unknown)
   - Count units: Never convert, only combine same units
   - Informal units: Convert to nearest standard with `isApproximate: true` flag

4. **Edge Cases to Handle**:
   - "1/2 cup" vs "0.5 cup" vs "½ cup" (unicode fractions)
   - "2 T" vs "2 t" (case sensitivity matters!)
   - "2 tbsp." with trailing period
   - "2tbsp" without space
   - "2 tablespoons (30ml)" with parenthetical metric
   - Regional detection from recipe source if available

5. **Comprehensive Tests** (src/core/units/units.test.ts):
   ```typescript
   describe('UnitConverter', () => {
     // Parsing tests
     test('parses all tablespoon variants to canonical form');
     test('distinguishes T (tablespoon) from t (teaspoon)');
     test('handles units with/without trailing periods');
     test('handles units attached to numbers (2tbsp)');
     
     // Conversion tests
     test('converts 3 tsp to 1 tbsp');
     test('converts 16 tbsp to 1 cup');
     test('converts 2 cups to 473ml (US region)');
     test('converts 2 cups to 500ml (metric region)');
     test('converts 1 lb to 453.59g');
     
     // Compatibility tests
     test('volume units are compatible with each other');
     test('weight units are compatible with each other');
     test('volume and weight are NOT compatible without density');
     test('count units only compatible with same unit');
     
     // Display optimization
     test('48 teaspoons displays as 1 cup');
     test('0.25 cup displays as 4 tablespoons');
     test('1000g displays as 1 kg');
   });
   ```

Write thorough, production-quality code. This is the foundation—unit conversion errors break user trust.
```

## Prompt 1.3: Quantity Parser

```
In ~/heirloom-shopping-lab, build the quantity parsing system.

Create src/core/parser/quantity-parser.ts:

1. **QuantityParser class** that handles ALL real-world quantity formats:

   FRACTIONS:
   - Unicode: ½, ⅓, ⅔, ¼, ¾, ⅛, ⅜, ⅝, ⅞, ⅕, ⅖, ⅗, ⅘, ⅙, ⅚
   - Text: 1/2, 1/3, 2/3, 1/4, 3/4, 1/8
   - Mixed: 1 1/2, 2 1/4, 1½, 2¼
   - Spelled out: "one half", "one and a half", "quarter"

   RANGES:
   - Hyphen: "2-3", "1-2"
   - To: "2 to 3", "1 to 2"
   - Or: "2 or 3"
   - Approximately: "about 2", "approximately 3", "~2", "roughly 2"

   DECIMALS:
   - Standard: "1.5", "0.25", "2.75"
   - Leading zero optional: ".5", ".25"

   SPELLED NUMBERS:
   - "one", "two", "three" through "twelve"
   - "a" and "an" = 1 (e.g., "a cup", "an egg")
   - "a couple" = 2
   - "a few" = 3 (approximate)
   - "several" = 4-6 (approximate)
   - "dozen" = 12, "half dozen" = 6

   COMPOUND:
   - "1 1/2" = 1.5
   - "2 and 1/4" = 2.25
   - "one and a half" = 1.5

2. **Parser Output**:
   ```typescript
   interface ParsedQuantity {
     type: 'exact' | 'range' | 'approximate';
     value: number;           // Primary value (or midpoint for ranges)
     valueLow?: number;       // For ranges
     valueHigh?: number;      // For ranges
     display: string;         // Human-readable: "1½", "2-3", "about 2"
     confidence: number;      // 0-1, lower for spelled/approximate
   }

   class QuantityParser {
     parse(input: string): { quantity: ParsedQuantity | null; remainder: string };
     
     // Utility methods
     fractionToDecimal(fraction: string): number;
     unicodeFractionToDecimal(char: string): number;
     spelledNumberToValue(word: string): number | null;
     
     // Format for display
     toDisplayString(value: number, preferFraction: boolean): string;
   }
   ```

3. **Key Implementation Details**:
   - Return BOTH the parsed quantity AND the remainder string (for further parsing)
   - Handle quantity appearing at start, middle, or implied ("eggs" = count)
   - Preserve original formatting for display where sensible
   - Flag approximate quantities for consolidation logic

4. **Comprehensive Tests**:
   ```typescript
   describe('QuantityParser', () => {
     // Exact quantities
     test('parses "2" as exact 2');
     test('parses "1/2" as exact 0.5');
     test('parses "½" as exact 0.5');
     test('parses "1 1/2" as exact 1.5');
     test('parses "1½" as exact 1.5');
     test('parses "one" as exact 1');
     test('parses "a" as exact 1');
     test('parses "dozen" as exact 12');
     
     // Ranges
     test('parses "2-3" as range 2-3');
     test('parses "2 to 3" as range 2-3');
     test('parses "2 or 3" as range 2-3');
     
     // Approximate
     test('parses "about 2" as approximate 2');
     test('parses "~3" as approximate 3');
     test('parses "a few" as approximate 3');
     
     // Compound
     test('parses "2 and 1/4" as 2.25');
     test('parses "one and a half" as 1.5');
     
     // Edge cases
     test('handles no quantity (returns null)');
     test('returns correct remainder after quantity');
     test('handles quantity in middle of string');
   });
   ```

5. **Display Formatting**:
   - 0.5 → "½" (prefer unicode fractions for common values)
   - 1.5 → "1½"
   - 0.33 → "⅓" (within tolerance)
   - 0.3 → "0.3" (not a common fraction)
   - 2.5 → "2½"

Build this as a standalone module with no dependencies on other parser components. It should be fully testable in isolation.
```

## Prompt 1.4: Ingredient Name Parser & Normalizer

```
In ~/heirloom-shopping-lab, build the ingredient name parsing and normalization system.

Create src/core/normalizer/index.ts and supporting data files:

1. **Ingredient Database** (src/data/ingredients.json):
   Structure with ~500 common ingredients to start:
   ```json
   {
     "ingredients": [
       {
         "id": "butter",
         "canonical": "butter",
         "category": "dairy",
         "subcategory": "fats",
         "aisleHint": "Dairy",
         "defaultUnit": "tablespoon",
         "densityGramsPerCup": 227,
         "variants": ["unsalted butter", "salted butter", "European butter"],
         "variantHandling": "combine"  // or "separate"
       },
       {
         "id": "egg",
         "canonical": "eggs",
         "category": "dairy",
         "subcategory": "eggs",
         "aisleHint": "Dairy",
         "defaultUnit": "count",
         "averageWeightGrams": 50,
         "parts": {
           "white": { "averageWeightGrams": 33, "countPer": 1 },
           "yolk": { "averageWeightGrams": 17, "countPer": 1 }
         }
       },
       {
         "id": "flour_ap",
         "canonical": "all-purpose flour",
         "category": "baking",
         "aisleHint": "Baking",
         "defaultUnit": "cup",
         "densityGramsPerCup": 120
       }
       // ... continue for all common ingredients
     ]
   }
   ```

2. **Synonym Database** (src/data/synonyms.json):
   Comprehensive mapping including regional variants:
   ```json
   {
     "synonyms": {
       "all-purpose flour": ["ap flour", "plain flour", "all purpose flour", "white flour"],
       "cilantro": ["coriander", "fresh coriander", "coriander leaves", "chinese parsley"],
       "eggplant": ["aubergine"],
       "zucchini": ["courgette", "summer squash"],
       "bell pepper": ["capsicum", "sweet pepper"],
       "green onion": ["scallion", "spring onion", "salad onion"],
       "arugula": ["rocket", "roquette"],
       "shrimp": ["prawns"],
       "ground beef": ["beef mince", "minced beef"],
       "heavy cream": ["double cream", "heavy whipping cream"],
       "confectioners sugar": ["icing sugar", "powdered sugar"],
       "baking soda": ["bicarbonate of soda", "bicarb"],
       "corn starch": ["cornflour", "corn flour"],
       "molasses": ["treacle", "black treacle"]
     }
   }
   ```

3. **IngredientNormalizer class**:
   ```typescript
   class IngredientNormalizer {
     // Find canonical ingredient from raw text
     normalize(input: string): NormalizationResult;
     
     // Fuzzy search for close matches
     findSimilar(input: string, threshold?: number): IngredientMatch[];
     
     // Check if two ingredients should be combined
     areCombineable(ing1: string, ing2: string): boolean;
     
     // Get ingredient metadata
     getMetadata(canonical: string): IngredientMetadata | null;
     
     // Handle variant detection
     detectVariant(input: string): VariantInfo | null;
   }

   interface NormalizationResult {
     canonical: string;
     original: string;
     confidence: number;
     matchType: 'exact' | 'synonym' | 'fuzzy' | 'unknown';
     category: IngredientCategory;
     metadata: IngredientMetadata | null;
   }

   interface VariantInfo {
     base: string;           // "butter"
     variant: string;        // "unsalted"
     handling: 'combine' | 'separate' | 'annotate';
   }
   ```

4. **Preparation & Modifier Extraction**:
   Parse and separate preparation instructions:
   ```typescript
   const PREPARATION_TERMS = [
     // Cutting
     'chopped', 'diced', 'minced', 'sliced', 'julienned', 'cubed',
     'quartered', 'halved', 'crushed', 'grated', 'shredded', 'torn',
     
     // Processing
     'sifted', 'melted', 'softened', 'room temperature', 'cold',
     'frozen', 'thawed', 'drained', 'rinsed', 'peeled', 'seeded',
     'cored', 'trimmed', 'stemmed', 'deveined', 'deboned',
     
     // Size/State
     'large', 'medium', 'small', 'thin', 'thick', 'fine', 'coarse',
     'fresh', 'dried', 'ground', 'whole', 'packed', 'loosely packed',
     'firmly packed', 'lightly beaten', 'beaten', 'whisked'
   ];
   
   function extractPreparation(input: string): {
     ingredient: string;
     preparation: string[];
     modifiers: string[];
   };
   ```

5. **Fuzzy Matching Strategy**:
   - Levenshtein distance with 0.85 threshold
   - Trigram similarity for multi-word ingredients
   - Phonetic matching (Soundex/Metaphone) as fallback
   - Block matching within categories to prevent "cream cheese" → "heavy cream"

6. **Tests**:
   ```typescript
   describe('IngredientNormalizer', () => {
     // Exact matches
     test('normalizes "butter" to "butter"');
     test('normalizes "Butter" (case insensitive)');
     
     // Synonyms
     test('normalizes "aubergine" to "eggplant"');
     test('normalizes "coriander" to "cilantro"');
     test('normalizes "prawns" to "shrimp"');
     
     // Variants
     test('detects "unsalted butter" as butter variant');
     test('detects "Greek yogurt" as yogurt variant');
     
     // Fuzzy
     test('matches "buter" (typo) to "butter"');
     test('matches "parsely" (typo) to "parsley"');
     
     // No false positives
     test('does NOT match "cream cheese" to "cream"');
     test('does NOT match "flour" to "flower"');
     
     // Preparation extraction
     test('extracts "finely chopped" from "onion, finely chopped"');
     test('extracts "at room temperature" from "butter, at room temperature"');
   });
   ```

Populate the ingredients.json with at least 300 common ingredients covering all categories. This is critical—the quality of normalization depends on comprehensive data.
```

## Prompt 1.5: Full Ingredient Parser Integration

```
In ~/heirloom-shopping-lab, integrate all parsing components into a unified IngredientParser.

Create src/core/parser/ingredient-parser.ts:

1. **IngredientParser class** that orchestrates all parsing:
   ```typescript
   class IngredientParser {
     private quantityParser: QuantityParser;
     private unitConverter: UnitConverter;
     private normalizer: IngredientNormalizer;

     parse(input: string): ParsedIngredient {
       // 1. Clean and normalize whitespace
       // 2. Extract quantity (handles start, middle, or none)
       // 3. Extract unit
       // 4. Extract ingredient name
       // 5. Extract preparation terms
       // 6. Detect special flags (optional, to taste, divided, etc.)
       // 7. Normalize ingredient name
       // 8. Calculate confidence score
       // 9. Return structured result
     }

     parseMultiple(inputs: string[]): ParsedIngredient[];
     
     // For debugging/testing
     parseWithExplanation(input: string): ParsedIngredientWithSteps;
   }
   ```

2. **Pattern Recognition for Complex Formats**:
   Handle these real-world ingredient line formats:
   ```
   // Standard
   "2 cups all-purpose flour"
   "1/2 teaspoon salt"
   
   // Parenthetical info
   "1 (14-oz) can diced tomatoes"
   "2 cups (250g) bread flour"
   "1 lb (450g) ground beef"
   
   // Preparation variations
   "1 onion, diced"
   "2 cloves garlic, minced"
   "1 cup parsley, finely chopped"
   "butter, softened, for greasing"
   
   // Optional/to taste
   "salt to taste"
   "pepper (optional)"
   "fresh herbs, for garnish (optional)"
   
   // Divided
   "2 cups sugar, divided"
   "3 eggs, separated"
   "1/2 cup butter, divided (1/4 cup for sauce, 1/4 cup for topping)"
   
   // Alternatives
   "1 cup milk or cream"
   "2 tablespoons olive oil or butter"
   
   // Ranges
   "2-3 tablespoons water"
   "1 to 2 teaspoons vanilla"
   
   // No quantity
   "salt and pepper"
   "cooking spray"
   
   // Complex
   "juice of 2 lemons"
   "zest of 1 orange"
   "1 bunch fresh cilantro, leaves only"
   "2 large eggs, whites only"
   ```

3. **Special Flag Detection**:
   ```typescript
   function detectFlags(input: string): IngredientFlags {
     return {
       optional: /\(optional\)|optional|if desired/i.test(input),
       toTaste: /to taste|as needed|as desired/i.test(input),
       forGarnish: /for garnish|garnish|to garnish/i.test(input),
       divided: /divided/i.test(input),
       separated: /separated/i.test(input),
       partialUse: detectPartialUse(input) // 'whites', 'yolks', 'juice', 'zest'
     };
   }
   
   function detectPartialUse(input: string): string | null {
     if (/egg whites?|whites? only/i.test(input)) return 'whites';
     if (/egg yolks?|yolks? only/i.test(input)) return 'yolks';
     if (/juice of|juiced/i.test(input)) return 'juice';
     if (/zest of|zested/i.test(input)) return 'zest';
     return null;
   }
   ```

4. **Confidence Scoring**:
   ```typescript
   function calculateConfidence(parsed: Partial<ParsedIngredient>): number {
     let score = 1.0;
     
     // Reduce for uncertain elements
     if (parsed.quantity?.type === 'approximate') score *= 0.9;
     if (parsed.unit?.type === 'informal') score *= 0.85;
     if (parsed.ingredient?.matchType === 'fuzzy') score *= 0.8;
     if (parsed.ingredient?.matchType === 'unknown') score *= 0.5;
     if (parsed.flags?.toTaste) score *= 0.7;
     
     return score;
   }
   ```

5. **Comprehensive Test Suite** (golden-tests/parser.test.ts):
   Create 200+ test cases covering all patterns:
   ```typescript
   const GOLDEN_TESTS: Array<{input: string; expected: Partial<ParsedIngredient>}> = [
     // Basic
     { input: "2 cups flour", expected: { quantity: { value: 2 }, unit: { canonical: "cup" }, ingredient: { canonical: "all-purpose flour" } } },
     
     // Fractions
     { input: "½ tsp salt", expected: { quantity: { value: 0.5 }, unit: { canonical: "teaspoon" } } },
     { input: "1 1/2 cups sugar", expected: { quantity: { value: 1.5 } } },
     
     // Complex
     { input: "1 (14-oz) can diced tomatoes", expected: { quantity: { value: 1 }, unit: { canonical: "can" } } },
     { input: "juice of 2 lemons", expected: { quantity: { value: 2 }, flags: { partialUse: "juice" } } },
     
     // Add 195+ more covering all edge cases
   ];
   
   describe('IngredientParser Golden Tests', () => {
     GOLDEN_TESTS.forEach(({ input, expected }) => {
       test(`parses "${input}"`, () => {
         const result = parser.parse(input);
         expect(result).toMatchObject(expected);
       });
     });
   });
   ```

6. **Error Handling**:
   - Never throw on malformed input
   - Return best-effort parse with low confidence
   - Log unparseable patterns for future improvement
   - Preserve original text in all cases

Build this as the integration layer that brings together quantity, unit, and ingredient parsing into a single clean API. The parser should be rock-solid—handle any input without crashing, always return structured data.
```

---

# PHASE 2: Data Layer & Ingredient Database

## Prompt 2.1: Comprehensive Ingredient Database

```
In ~/heirloom-shopping-lab, create a comprehensive ingredient database seeded from authoritative sources.

1. **Fetch and Process USDA FoodData Central**:
   - Use the FDC API (https://api.nal.usda.gov/fdc/v1/)
   - Get a free API key from data.gov
   - Download Foundation Foods dataset (most useful for cooking)
   - Extract: food name, category, serving sizes, density info

2. **Create Database Schema** (src/data/schema.ts):
   ```typescript
   interface IngredientDatabase {
     version: string;
     lastUpdated: string;
     ingredients: CanonicalIngredient[];
     synonyms: SynonymMapping[];
     densities: DensityTable[];
     conversions: SpecialConversion[];
   }

   interface CanonicalIngredient {
     id: string;                    // UUID
     canonical: string;             // "all-purpose flour"
     displayName: string;           // "All-Purpose Flour"
     category: IngredientCategory;
     subcategory: string;
     aisleHint: string;
     shelfLife: ShelfLife;
     
     // Measurement defaults
     defaultUnit: string;
     preferredUnits: string[];
     
     // Density for volume/weight conversion
     density?: {
       gramsPerCup?: number;
       gramsPerTablespoon?: number;
       gramsPerTeaspoon?: number;
       source: 'usda' | 'king_arthur' | 'measured' | 'estimated';
     };
     
     // For count-based items
     countInfo?: {
       averageWeightGrams: number;
       typicalCount?: string;       // "1 medium" 
     };
     
     // Variant handling
     variants: IngredientVariant[];
     variantHandling: 'combine' | 'separate' | 'annotate';
     
     // Parts (for eggs, citrus, etc.)
     parts?: Record<string, IngredientPart>;
     
     // Substitutions (future feature)
     substitutes?: string[];
   }

   interface IngredientVariant {
     name: string;                  // "unsalted"
     modifiesDensity?: number;      // Multiplier if different
     notes?: string;
   }

   interface IngredientPart {
     name: string;                  // "white", "yolk", "juice", "zest"
     averageWeightGrams?: number;
     averageYieldMl?: number;       // For juice
     countPer: number;              // How many per whole ingredient
   }
   ```

3. **Seed Data Sources**:
   - King Arthur Baking ingredient weight chart (200+ baking ingredients)
   - USDA FDC Foundation Foods
   - Manually curated common cooking ingredients
   
   Create scripts in src/scripts/:
   ```typescript
   // src/scripts/fetch-usda.ts
   // Fetches and processes USDA data

   // src/scripts/parse-king-arthur.ts  
   // Parses King Arthur weight chart

   // src/scripts/merge-sources.ts
   // Combines all sources, resolves conflicts
   ```

4. **Minimum Coverage Requirements**:
   Create entries for at least:
   
   PRODUCE (100+):
   - All common vegetables (onion, garlic, tomato, potato, carrot, celery, bell pepper, etc.)
   - All common fruits (apple, banana, lemon, lime, orange, berries, etc.)
   - Fresh herbs (parsley, cilantro, basil, mint, rosemary, thyme, etc.)
   - Greens (lettuce, spinach, kale, arugula, cabbage, etc.)
   
   PROTEINS (50+):
   - Meats (beef, pork, chicken, turkey, lamb)
   - Cuts (breast, thigh, ground, steak, chop, roast)
   - Seafood (salmon, shrimp, cod, tuna, etc.)
   - Eggs and egg parts
   
   DAIRY (40+):
   - Milks (whole, 2%, skim, buttermilk)
   - Creams (heavy, light, half-and-half, sour cream)
   - Cheeses (cheddar, parmesan, mozzarella, cream cheese, etc.)
   - Yogurts (regular, Greek)
   - Butter (salted, unsalted)
   
   PANTRY (100+):
   - Flours (AP, bread, cake, whole wheat, etc.)
   - Sugars (white, brown, powdered, etc.)
   - Oils (olive, vegetable, coconut, sesame)
   - Vinegars (white, apple cider, balsamic, rice)
   - Canned goods (tomatoes, beans, broth, coconut milk)
   - Grains (rice, pasta, oats, quinoa)
   - Nuts and seeds
   
   SPICES & SEASONINGS (80+):
   - All common spices with dried/ground variants
   - Salt types (table, kosher, sea, flaky)
   - Pepper types (black, white, cayenne, red pepper flakes)
   - Spice blends (Italian seasoning, curry powder, etc.)

5. **Density Data**:
   Include accurate density data for ALL baking ingredients at minimum.
   Source from King Arthur chart:
   ```json
   {
     "all-purpose flour": { "gramsPerCup": 120, "source": "king_arthur" },
     "bread flour": { "gramsPerCup": 120, "source": "king_arthur" },
     "cake flour": { "gramsPerCup": 113, "source": "king_arthur" },
     "granulated sugar": { "gramsPerCup": 198, "source": "king_arthur" },
     "brown sugar (packed)": { "gramsPerCup": 213, "source": "king_arthur" },
     "powdered sugar": { "gramsPerCup": 113, "source": "king_arthur" },
     "butter": { "gramsPerCup": 227, "source": "king_arthur" },
     "honey": { "gramsPerCup": 340, "source": "king_arthur" },
     "cocoa powder": { "gramsPerCup": 85, "source": "king_arthur" }
     // ... etc
   }
   ```

6. **Validation**:
   Write validation script that checks:
   - All ingredients have required fields
   - All categories are valid
   - All densities are within reasonable ranges
   - No duplicate canonical names
   - All synonyms point to valid ingredients
   - No circular synonym references

Generate the complete database. This is foundational—shopping list accuracy depends on comprehensive, accurate ingredient data.
```

## Prompt 2.2: Synonym & Regional Mapping System

```
In ~/heirloom-shopping-lab, create a comprehensive synonym and regional terminology mapping system.

1. **Synonym Database Structure** (src/data/synonyms.json):
   ```json
   {
     "version": "1.0.0",
     "mappings": [
       {
         "canonical": "all-purpose flour",
         "synonyms": [
           { "term": "ap flour", "confidence": 1.0 },
           { "term": "plain flour", "confidence": 1.0, "region": "UK" },
           { "term": "all purpose flour", "confidence": 1.0 },
           { "term": "white flour", "confidence": 0.9 },
           { "term": "flour", "confidence": 0.8 }
         ]
       },
       // ... hundreds more
     ],
     "regional": {
       "UK": {
         "aubergine": "eggplant",
         "courgette": "zucchini",
         "rocket": "arugula",
         "coriander": "cilantro",
         "prawns": "shrimp",
         "mince": "ground meat",
         "double cream": "heavy cream",
         "single cream": "light cream",
         "caster sugar": "superfine sugar",
         "icing sugar": "powdered sugar",
         "bicarbonate of soda": "baking soda",
         "cornflour": "cornstarch",
         "plain flour": "all-purpose flour",
         "strong flour": "bread flour",
         "self-raising flour": "self-rising flour",
         "treacle": "molasses",
         "golden syrup": "light corn syrup"
       },
       "AU": {
         // Australian terms (largely overlap with UK)
         "capsicum": "bell pepper",
         "pawpaw": "papaya"
       }
     }
   }
   ```

2. **Comprehensive Regional Mappings**:
   Research and include ALL common US/UK/AU ingredient differences:
   
   Vegetables:
   - eggplant ↔ aubergine
   - zucchini ↔ courgette  
   - arugula ↔ rocket
   - cilantro ↔ coriander (fresh)
   - green onion ↔ spring onion ↔ scallion
   - bell pepper ↔ capsicum
   - snow peas ↔ mange tout
   - rutabaga ↔ swede
   - beet ↔ beetroot
   
   Proteins:
   - shrimp ↔ prawns
   - ground beef ↔ beef mince
   - bacon (US) ↔ streaky bacon (UK)
   - Canadian bacon ↔ back bacon
   
   Dairy:
   - heavy cream ↔ double cream
   - light cream ↔ single cream
   - half-and-half ↔ half cream
   - whole milk ↔ full-fat milk
   - 2% milk ↔ semi-skimmed milk
   - skim milk ↔ skimmed milk
   
   Baking:
   - all-purpose flour ↔ plain flour
   - bread flour ↔ strong flour
   - cake flour ↔ soft flour
   - powdered sugar ↔ icing sugar
   - superfine sugar ↔ caster sugar
   - light brown sugar ↔ soft light brown sugar
   - baking soda ↔ bicarbonate of soda
   - cornstarch ↔ cornflour
   - molasses ↔ treacle
   - corn syrup ↔ golden syrup (approximate)
   - vegetable shortening ↔ vegetable fat
   
   Other:
   - jello ↔ jelly (dessert)
   - jelly (US) ↔ jam (UK)
   - chips (US) ↔ crisps (UK)
   - fries ↔ chips (UK)
   - cookie ↔ biscuit
   - graham cracker ↔ digestive biscuit

3. **Synonym Matching Service**:
   ```typescript
   class SynonymService {
     private synonyms: Map<string, SynonymEntry>;
     private regionalMaps: Map<string, Map<string, string>>;
     
     constructor(data: SynonymDatabase) {
       // Build efficient lookup structures
     }
     
     // Find canonical name for any term
     findCanonical(term: string, region?: 'US' | 'UK' | 'AU'): string | null;
     
     // Get all synonyms for a canonical name
     getSynonyms(canonical: string): string[];
     
     // Check if two terms are synonymous
     areSynonymous(term1: string, term2: string): boolean;
     
     // Convert term between regions
     convertRegion(term: string, from: Region, to: Region): string;
     
     // Suggest corrections for unknown terms
     suggestCorrections(unknown: string): SuggestionResult[];
   }
   ```

4. **Fuzzy Matching Integration**:
   When exact/synonym match fails:
   ```typescript
   class FuzzyMatcher {
     // Levenshtein with threshold
     findSimilar(input: string, candidates: string[], threshold: number): Match[];
     
     // Trigram similarity for multi-word
     trigramSimilarity(a: string, b: string): number;
     
     // Phonetic matching
     soundexMatch(input: string, candidates: string[]): Match[];
     
     // Combined scoring
     findBestMatch(input: string): MatchResult | null;
   }
   ```

5. **Blocklist for False Positives**:
   Prevent common false matches:
   ```typescript
   const NEVER_MATCH = [
     ['cream', 'cream cheese'],
     ['cream', 'ice cream'],
     ['flour', 'flower'],
     ['cheese', 'cream cheese'],
     ['chocolate', 'chocolate chips'],
     ['onion', 'onion powder'],
     ['garlic', 'garlic powder'],
     ['oil', 'olive oil'],
     ['sugar', 'brown sugar'],
     ['milk', 'coconut milk'],
     ['butter', 'peanut butter'],
   ];
   ```

6. **Tests**:
   ```typescript
   describe('SynonymService', () => {
     test('finds canonical for "aubergine" → "eggplant"');
     test('finds canonical for "coriander" → "cilantro"');
     test('converts "courgette" from UK to US → "zucchini"');
     test('treats "scallion" and "green onion" as synonymous');
     
     // Regional awareness
     test('in UK mode, "coriander" stays as "coriander"');
     test('in US mode, "coriander" suggests "cilantro"');
     
     // Fuzzy matching
     test('matches "parsely" (typo) to "parsley"');
     test('matches "tomatoe" to "tomato"');
     
     // No false positives
     test('does NOT match "cream" to "cream cheese"');
     test('does NOT match "flour" to "flower"');
   });
   ```

Build a robust, comprehensive synonym system. This is critical for consolidation accuracy.
```

## Prompt 2.3: Database Service Layer

```
In ~/heirloom-shopping-lab, create the database service layer that provides a clean API for all ingredient data operations.

1. **IngredientDatabase Service**:
   ```typescript
   // src/core/database/ingredient-database.ts
   
   class IngredientDatabase {
     private ingredients: Map<string, CanonicalIngredient>;
     private synonymService: SynonymService;
     private fuzzyMatcher: FuzzyMatcher;
     
     // Initialize with data files
     static async load(): Promise<IngredientDatabase>;
     
     // Primary lookup - always returns a result
     lookup(term: string): LookupResult {
       // 1. Exact match on canonical
       // 2. Synonym lookup
       // 3. Fuzzy match
       // 4. Return unknown with suggestions
     }
     
     // Get full ingredient info
     getIngredient(canonical: string): CanonicalIngredient | null;
     
     // Search ingredients
     search(query: string, options?: SearchOptions): SearchResult[];
     
     // Category operations
     getByCategory(category: IngredientCategory): CanonicalIngredient[];
     getCategories(): IngredientCategory[];
     
     // Density/conversion data
     getDensity(canonical: string): DensityInfo | null;
     canConvertVolumeToWeight(canonical: string): boolean;
     
     // Variant operations
     getVariants(canonical: string): IngredientVariant[];
     shouldCombineVariants(canonical: string): boolean;
     
     // Parts (eggs, citrus)
     getParts(canonical: string): IngredientPart[] | null;
     getPartInfo(canonical: string, part: string): IngredientPart | null;
   }

   interface LookupResult {
     found: boolean;
     canonical: string | null;
     matchType: 'exact' | 'synonym' | 'fuzzy' | 'unknown';
     confidence: number;
     ingredient: CanonicalIngredient | null;
     suggestions?: string[];  // For unknown items
   }
   ```

2. **Caching Layer**:
   ```typescript
   class IngredientCache {
     private lookupCache: LRUCache<string, LookupResult>;
     private parseCache: LRUCache<string, ParsedIngredient>;
     
     constructor(options: CacheOptions) {
       this.lookupCache = new LRUCache({ max: 1000, ttl: 24 * 60 * 60 * 1000 });
       this.parseCache = new LRUCache({ max: 500, ttl: 60 * 60 * 1000 });
     }
     
     getCachedLookup(term: string): LookupResult | undefined;
     setCachedLookup(term: string, result: LookupResult): void;
     
     getCachedParse(input: string): ParsedIngredient | undefined;
     setCachedParse(input: string, result: ParsedIngredient): void;
     
     clear(): void;
     getStats(): CacheStats;
   }
   ```

3. **Persistence Layer** (for web demo):
   ```typescript
   // src/core/database/persistence.ts
   
   class DatabasePersistence {
     // IndexedDB for web
     private db: IDBDatabase;
     
     // User corrections and additions
     async saveUserCorrection(correction: UserCorrection): Promise<void>;
     async getUserCorrections(): Promise<UserCorrection[]>;
     
     // Custom ingredients added by user
     async saveCustomIngredient(ingredient: CanonicalIngredient): Promise<void>;
     async getCustomIngredients(): Promise<CanonicalIngredient[]>;
     
     // Analytics/feedback
     async logParseResult(input: string, result: ParsedIngredient, userEdited: boolean): Promise<void>;
     async getParseAnalytics(): Promise<ParseAnalytics>;
   }

   interface UserCorrection {
     id: string;
     original: string;
     correctedParsed: ParsedIngredient;
     timestamp: Date;
     applied: boolean;  // Whether it's been incorporated into training
   }
   ```

4. **Export for Swift**:
   Create utilities to export data in Swift-compatible formats:
   ```typescript
   // src/scripts/export-swift.ts
   
   async function exportForSwift() {
     // Generate Swift struct definitions
     generateSwiftTypes();
     
     // Export JSON data files
     exportIngredients('swift-export/ingredients.json');
     exportSynonyms('swift-export/synonyms.json');
     exportDensities('swift-export/densities.json');
     
     // Generate Swift loading code
     generateSwiftLoader();
   }
   ```

5. **Validation & Health Checks**:
   ```typescript
   class DatabaseValidator {
     // Validate data integrity
     validateIngredients(): ValidationResult;
     validateSynonyms(): ValidationResult;
     validateDensities(): ValidationResult;
     
     // Check coverage
     getCoverage(): CoverageReport;
     findMissingDensities(): string[];
     findOrphanedSynonyms(): string[];
     
     // Performance checks
     measureLookupPerformance(): PerformanceReport;
   }
   ```

6. **Tests**:
   ```typescript
   describe('IngredientDatabase', () => {
     let db: IngredientDatabase;
     
     beforeAll(async () => {
       db = await IngredientDatabase.load();
     });
     
     test('loads all ingredients');
     test('lookup finds exact match');
     test('lookup finds synonym');
     test('lookup finds fuzzy match for typo');
     test('lookup returns suggestions for unknown');
     test('getDensity returns data for flour');
     test('getVariants returns butter variants');
     test('getParts returns egg parts');
     
     // Performance
     test('lookup completes in <10ms');
     test('search returns results in <50ms');
   });
   ```

Build a clean, well-tested database layer. This abstracts all data access and makes the parsing logic simple.
```

---

# PHASE 3: Shopping List Consolidation

## Prompt 3.1: Consolidation Algorithm

```
In ~/heirloom-shopping-lab, build the core shopping list consolidation algorithm.

The consolidation pipeline:
1. Parse each ingredient string → ParsedIngredient
2. Normalize ingredient names → CanonicalIngredient
3. Group by (canonical_name, compatible_unit_type)
4. Sum quantities within groups
5. Handle special cases (egg parts, variants, etc.)
6. Generate consolidated shopping list

Create src/core/consolidator/index.ts:

1. **ShoppingListConsolidator class**:
   ```typescript
   class ShoppingListConsolidator {
     private parser: IngredientParser;
     private database: IngredientDatabase;
     private unitConverter: UnitConverter;

     // Main entry point
     consolidate(inputs: RecipeIngredientInput[]): ShoppingList {
       const parsed = this.parseAll(inputs);
       const normalized = this.normalizeAll(parsed);
       const grouped = this.groupIngredients(normalized);
       const consolidated = this.consolidateGroups(grouped);
       const organized = this.organizeByAisle(consolidated);
       return this.buildShoppingList(organized);
     }

     // Process a single recipe
     addRecipe(recipe: Recipe): ConsolidationResult;
     
     // Process multiple recipes
     addRecipes(recipes: Recipe[]): ConsolidationResult;
     
     // Remove a recipe from the list
     removeRecipe(recipeId: string): void;
     
     // Clear and rebuild
     rebuild(): ShoppingList;
   }

   interface RecipeIngredientInput {
     recipeId: string;
     recipeName: string;
     servingsMultiplier?: number;  // For scaling
     ingredients: string[];        // Raw ingredient lines
   }

   interface ShoppingList {
     id: string;
     createdAt: Date;
     updatedAt: Date;
     items: ShoppingListItem[];
     byAisle: Map<string, ShoppingListItem[]>;
     sourceRecipes: RecipeSummary[];
     warnings: ConsolidationWarning[];
   }

   interface ShoppingListItem {
     id: string;
     displayText: string;          // "2 cups all-purpose flour"
     canonical: string;            // "all-purpose flour"
     category: IngredientCategory;
     aisle: string;
     
     quantity: {
       value: number;
       unit: string;
       display: string;            // "2 cups" or "3 large"
     };
     
     // Track sources
     sources: IngredientSource[];
     
     // Metadata
     isChecked: boolean;
     notes: string[];              // Prep notes, variant info
     confidence: number;
     flags: {
       hasVariants: boolean;       // "includes both salted and unsalted"
       isApproximate: boolean;     // "to taste" items
       needsReview: boolean;       // Low confidence
     };
   }

   interface IngredientSource {
     recipeId: string;
     recipeName: string;
     originalText: string;
     quantity: number;
     unit: string;
   }
   ```

2. **Grouping Logic**:
   ```typescript
   class IngredientGrouper {
     // Group by canonical + unit type
     group(items: NormalizedIngredient[]): IngredientGroup[] {
       const groups = new Map<string, IngredientGroup>();
       
       for (const item of items) {
         const key = this.getGroupKey(item);
         
         if (groups.has(key)) {
           groups.get(key)!.items.push(item);
         } else {
           groups.set(key, {
             key,
             canonical: item.canonical,
             unitType: item.unit.type,
             items: [item]
           });
         }
       }
       
       return Array.from(groups.values());
     }
     
     private getGroupKey(item: NormalizedIngredient): string {
       // Key format: "canonical|unitType"
       // Examples: "flour|volume", "eggs|count", "salt|informal"
       return `${item.canonical}|${item.unit.type}`;
     }
   }
   ```

3. **Quantity Consolidation**:
   ```typescript
   class QuantityConsolidator {
     // Consolidate quantities within a group
     consolidate(group: IngredientGroup): ConsolidatedQuantity {
       if (group.unitType === 'count') {
         return this.consolidateCounts(group);
       } else if (group.unitType === 'volume') {
         return this.consolidateVolumes(group);
       } else if (group.unitType === 'weight') {
         return this.consolidateWeights(group);
       } else {
         return this.consolidateInformal(group);
       }
     }
     
     private consolidateVolumes(group: IngredientGroup): ConsolidatedQuantity {
       // Convert all to ml, sum, convert to best display unit
       let totalMl = 0;
       
       for (const item of group.items) {
         const ml = this.unitConverter.toMl(item.quantity, item.unit);
         totalMl += ml * (item.servingsMultiplier || 1);
       }
       
       const displayUnit = this.findBestVolumeUnit(totalMl);
       const displayQuantity = this.unitConverter.fromMl(totalMl, displayUnit);
       
       return {
         value: displayQuantity,
         unit: displayUnit,
         display: this.formatDisplay(displayQuantity, displayUnit),
         totalMl
       };
     }
     
     private consolidateCounts(group: IngredientGroup): ConsolidatedQuantity {
       // For count items, just sum the counts
       // Round up for fractional items (can't buy half an onion)
       let total = 0;
       
       for (const item of group.items) {
         total += item.quantity * (item.servingsMultiplier || 1);
       }
       
       // Round up for whole items
       if (this.isWholeItem(group.canonical)) {
         total = Math.ceil(total);
       }
       
       return {
         value: total,
         unit: group.items[0].unit.canonical,
         display: this.formatCountDisplay(total, group.canonical)
       };
     }
   }
   ```

4. **Special Case Handlers**:
   ```typescript
   class SpecialCaseHandler {
     // Handle egg parts
     handleEggParts(items: NormalizedIngredient[]): SpecialCaseResult {
       const whites = items.filter(i => i.flags.partialUse === 'whites');
       const yolks = items.filter(i => i.flags.partialUse === 'yolks');
       const whole = items.filter(i => !i.flags.partialUse);
       
       const whiteCount = sum(whites, i => i.quantity);
       const yolkCount = sum(yolks, i => i.quantity);
       const wholeCount = sum(whole, i => i.quantity);
       
       // Calculate total eggs needed
       // If we need 3 whites and 2 yolks, we need max(3, 2) = 3 eggs
       // Plus any whole eggs
       const partialEggs = Math.max(whiteCount, yolkCount);
       const totalEggs = Math.ceil(wholeCount + partialEggs);
       
       return {
         displayItem: {
           text: `${totalEggs} eggs`,
           notes: this.buildEggNotes(whiteCount, yolkCount, wholeCount)
         },
         handledItems: items
       };
     }
     
     // Handle citrus parts (juice, zest)
     handleCitrusParts(canonical: string, items: NormalizedIngredient[]): SpecialCaseResult {
       const juice = items.filter(i => i.flags.partialUse === 'juice');
       const zest = items.filter(i => i.flags.partialUse === 'zest');
       const whole = items.filter(i => !i.flags.partialUse);
       
       // Calculate total fruit needed
       // Assume 1 lemon = ~3 tbsp juice, 1 lemon = ~1 tbsp zest
       const juiceCount = sum(juice, i => i.quantity);
       const zestCount = sum(zest, i => i.quantity);
       const wholeCount = sum(whole, i => i.quantity);
       
       // If we need juice of 2 AND zest of 1, we need max(2, 1) = 2
       const totalFruit = Math.ceil(Math.max(juiceCount, zestCount) + wholeCount);
       
       return {
         displayItem: {
           text: `${totalFruit} ${canonical}`,
           notes: this.buildCitrusNotes(juiceCount, zestCount, wholeCount)
         }
       };
     }
     
     // Handle variants (salted/unsalted butter, etc.)
     handleVariants(canonical: string, items: NormalizedIngredient[]): VariantResult {
       const variants = groupBy(items, i => i.variant || 'unspecified');
       const ingredient = this.database.getIngredient(canonical);
       
       if (ingredient?.variantHandling === 'separate') {
         // Keep variants as separate line items
         return { action: 'separate', groups: variants };
       } else if (ingredient?.variantHandling === 'annotate') {
         // Combine but add note
         return {
           action: 'combine',
           note: `Includes: ${Object.keys(variants).join(', ')}`
         };
       } else {
         // Just combine
         return { action: 'combine' };
       }
     }
   }
   ```

5. **Aisle Organization**:
   ```typescript
   class AisleOrganizer {
     private aisleOrder = [
       'Produce',
       'Meat & Seafood',
       'Dairy & Eggs',
       'Bakery',
       'Frozen',
       'Canned & Jarred',
       'Pasta & Grains',
       'Baking',
       'Oils & Vinegars',
       'Condiments',
       'Spices & Seasonings',
       'International',
       'Beverages',
       'Other'
     ];
     
     organize(items: ShoppingListItem[]): Map<string, ShoppingListItem[]> {
       const byAisle = new Map<string, ShoppingListItem[]>();
       
       // Initialize all aisles
       for (const aisle of this.aisleOrder) {
         byAisle.set(aisle, []);
       }
       
       // Sort items into aisles
       for (const item of items) {
         const aisle = item.aisle || 'Other';
         byAisle.get(aisle)?.push(item);
       }
       
       // Sort items within each aisle alphabetically
       for (const [aisle, aisleItems] of byAisle) {
         aisleItems.sort((a, b) => a.canonical.localeCompare(b.canonical));
       }
       
       // Remove empty aisles
       for (const [aisle, items] of byAisle) {
         if (items.length === 0) {
           byAisle.delete(aisle);
         }
       }
       
       return byAisle;
     }
   }
   ```

6. **Comprehensive Tests**:
   ```typescript
   describe('ShoppingListConsolidator', () => {
     // Basic consolidation
     test('combines 2 cups flour + 1 cup flour = 3 cups flour');
     test('combines 3 tsp salt + 1 tbsp salt = 2 tbsp salt');
     test('combines 100g butter + 1/2 cup butter correctly');
     
     // Count items
     test('2 eggs + 3 eggs = 5 eggs');
     test('1/2 onion + 1/2 onion = 1 onion (rounds up)');
     test('1.5 onions = 2 onions (rounds up for whole items)');
     
     // Egg parts
     test('3 egg whites + 2 egg yolks = 3 eggs total');
     test('2 whole eggs + 1 egg white = 3 eggs total');
     
     // Citrus parts
     test('juice of 2 lemons + zest of 1 lemon = 2 lemons');
     test('juice of 1 lemon + 2 whole lemons = 3 lemons');
     
     // Variants
     test('1/2 cup salted butter + 1/2 cup unsalted butter combines with note');
     test('Greek yogurt and regular yogurt stay separate');
     
     // Unit optimization
     test('48 teaspoons displays as 1 cup');
     test('4 tablespoons displays as 1/4 cup');
     
     // Multiple recipes
     test('combines ingredients across 3 recipes correctly');
     test('tracks source recipes for each item');
     
     // Edge cases
     test('handles "to taste" items without combining');
     test('handles optional items with flag');
     test('handles divided ingredients correctly');
   });
   ```

Build a robust, well-tested consolidation system. This is where all the parsing work pays off.
```

## Prompt 3.2: Conflict Detection & Resolution

```
In ~/heirloom-shopping-lab, build the conflict detection and resolution system.

Conflicts arise when:
- Same ingredient in incompatible units (can't add 1 cup + 1 lb without density)
- Variant conflicts (some recipes say salted, some say unsalted)
- Ambiguous ingredients (different things with similar names)

Create src/core/consolidator/conflict-resolver.ts:

1. **ConflictDetector class**:
   ```typescript
   class ConflictDetector {
     // Detect all conflicts in a set of ingredients
     detectConflicts(items: NormalizedIngredient[]): Conflict[] {
       const conflicts: Conflict[] = [];
       
       // Group by canonical name
       const groups = groupBy(items, i => i.canonical);
       
       for (const [canonical, groupItems] of groups) {
         // Check for unit conflicts
         const unitConflict = this.checkUnitConflict(canonical, groupItems);
         if (unitConflict) conflicts.push(unitConflict);
         
         // Check for variant conflicts
         const variantConflict = this.checkVariantConflict(canonical, groupItems);
         if (variantConflict) conflicts.push(variantConflict);
         
         // Check for preparation conflicts
         const prepConflict = this.checkPreparationConflict(canonical, groupItems);
         if (prepConflict) conflicts.push(prepConflict);
       }
       
       // Check for ambiguous matches across groups
       conflicts.push(...this.checkAmbiguousMatches(groups));
       
       return conflicts;
     }
     
     private checkUnitConflict(canonical: string, items: NormalizedIngredient[]): UnitConflict | null {
       const unitTypes = new Set(items.map(i => i.unit.type));
       
       // Volume and weight mixed?
       if (unitTypes.has('volume') && unitTypes.has('weight')) {
         const ingredient = this.database.getIngredient(canonical);
         
         if (!ingredient?.density) {
           return {
             type: 'unit',
             canonical,
             description: `Cannot combine volume and weight measurements for ${canonical} (no density data)`,
             items: items.filter(i => ['volume', 'weight'].includes(i.unit.type)),
             resolution: 'manual'
           };
         }
       }
       
       return null;
     }
     
     private checkVariantConflict(canonical: string, items: NormalizedIngredient[]): VariantConflict | null {
       const variants = new Set(items.map(i => i.variant).filter(Boolean));
       
       if (variants.size > 1) {
         const ingredient = this.database.getIngredient(canonical);
         
         if (ingredient?.variantHandling === 'separate') {
           return {
             type: 'variant',
             canonical,
             variants: Array.from(variants),
             description: `Multiple variants of ${canonical}: ${Array.from(variants).join(', ')}`,
             items,
             resolution: 'separate'
           };
         }
       }
       
       return null;
     }
   }

   interface Conflict {
     type: 'unit' | 'variant' | 'preparation' | 'ambiguous';
     canonical: string;
     description: string;
     items: NormalizedIngredient[];
     resolution: 'manual' | 'separate' | 'combine' | 'choose';
     resolutionOptions?: ResolutionOption[];
   }
   ```

2. **ConflictResolver class**:
   ```typescript
   class ConflictResolver {
     // Apply automatic resolutions where possible
     autoResolve(conflicts: Conflict[]): ResolutionResult {
       const resolved: ResolvedConflict[] = [];
       const needsReview: Conflict[] = [];
       
       for (const conflict of conflicts) {
         const autoResolution = this.tryAutoResolve(conflict);
         
         if (autoResolution) {
           resolved.push({
             conflict,
             resolution: autoResolution,
             automatic: true
           });
         } else {
           needsReview.push(conflict);
         }
       }
       
       return { resolved, needsReview };
     }
     
     private tryAutoResolve(conflict: Conflict): Resolution | null {
       switch (conflict.type) {
         case 'unit':
           return this.resolveUnitConflict(conflict);
         case 'variant':
           return this.resolveVariantConflict(conflict);
         case 'ambiguous':
           return null; // Always needs manual review
         default:
           return null;
       }
     }
     
     private resolveUnitConflict(conflict: UnitConflict): Resolution | null {
       const ingredient = this.database.getIngredient(conflict.canonical);
       
       // If we have density data, convert to common unit
       if (ingredient?.density) {
         return {
           action: 'convert',
           targetUnit: 'weight', // Prefer weight for accuracy
           density: ingredient.density.gramsPerCup
         };
       }
       
       // If standard conversion is possible
       // (e.g., 1 stick butter = 1/2 cup = 113g)
       const standardConversion = this.getStandardConversion(conflict.canonical);
       if (standardConversion) {
         return {
           action: 'standardConvert',
           conversion: standardConversion
         };
       }
       
       return null;
     }
   }
   ```

3. **Manual Resolution Interface**:
   ```typescript
   interface ResolutionPrompt {
     conflictId: string;
     type: Conflict['type'];
     description: string;
     options: ResolutionOption[];
     defaultOption?: string;
   }

   interface ResolutionOption {
     id: string;
     label: string;
     description: string;
     preview: string;  // What the result would look like
   }

   class ManualResolver {
     // Generate prompts for user review
     generatePrompts(conflicts: Conflict[]): ResolutionPrompt[] {
       return conflicts.map(c => this.generatePrompt(c));
     }
     
     // Apply user's resolution
     applyResolution(conflictId: string, optionId: string): void;
     
     // Remember resolution for future (same ingredients)
     saveResolutionPreference(canonical: string, resolution: Resolution): void;
   }
   ```

4. **Resolution History**:
   Track user resolutions to improve future consolidation:
   ```typescript
   interface ResolutionHistory {
     canonical: string;
     conflictType: Conflict['type'];
     resolution: Resolution;
     count: number;
     lastUsed: Date;
   }

   class ResolutionLearner {
     // Learn from user resolutions
     recordResolution(conflict: Conflict, resolution: Resolution): void;
     
     // Suggest resolution based on history
     suggestResolution(conflict: Conflict): Resolution | null;
     
     // Get most common resolutions
     getCommonResolutions(): ResolutionHistory[];
   }
   ```

5. **Tests**:
   ```typescript
   describe('ConflictDetector', () => {
     test('detects volume/weight conflict without density');
     test('no conflict when density is available');
     test('detects variant conflict for butter');
     test('no variant conflict when handling is "combine"');
     test('detects ambiguous match between similar ingredients');
   });

   describe('ConflictResolver', () => {
     test('auto-resolves unit conflict with density data');
     test('auto-resolves variant conflict with "combine" handling');
     test('requires manual resolution for ambiguous matches');
     test('applies saved preferences');
   });
   ```

Build conflict detection that catches real issues and resolution that learns from user behavior.
```

## Prompt 3.3: Recipe Integration

```
In ~/heirloom-shopping-lab, build the recipe-level integration that connects meal planning to shopping list generation.

This bridges the gap between "I want to make these recipes" and "here's my shopping list."

Create src/core/consolidator/recipe-integrator.ts:

1. **RecipeIntegrator class**:
   ```typescript
   class RecipeIntegrator {
     private consolidator: ShoppingListConsolidator;
     private shoppingList: ShoppingList;
     
     constructor() {
       this.shoppingList = this.createEmptyList();
     }
     
     // Add a recipe to the shopping list
     addRecipe(recipe: Recipe, options?: RecipeOptions): IntegrationResult {
       const scaledIngredients = this.scaleIngredients(recipe, options?.servings);
       const parsed = this.parseIngredients(scaledIngredients);
       const result = this.consolidator.addIngredients(parsed, recipe);
       
       this.shoppingList = result.shoppingList;
       
       return {
         added: result.addedItems,
         merged: result.mergedItems,
         conflicts: result.conflicts,
         warnings: result.warnings
       };
     }
     
     // Remove a recipe
     removeRecipe(recipeId: string): ShoppingList {
       // Filter out items that only came from this recipe
       // Recalculate quantities for items from multiple recipes
       const itemsToRemove = this.shoppingList.items.filter(
         item => item.sources.length === 1 && item.sources[0].recipeId === recipeId
       );
       
       const itemsToRecalculate = this.shoppingList.items.filter(
         item => item.sources.length > 1 && item.sources.some(s => s.recipeId === recipeId)
       );
       
       // Rebuild affected items
       for (const item of itemsToRecalculate) {
         const remainingSources = item.sources.filter(s => s.recipeId !== recipeId);
         const newQuantity = this.recalculateQuantity(item.canonical, remainingSources);
         item.quantity = newQuantity;
         item.sources = remainingSources;
       }
       
       // Remove items with no sources
       this.shoppingList.items = this.shoppingList.items.filter(
         item => item.sources.length > 0
       );
       
       // Update recipe list
       this.shoppingList.sourceRecipes = this.shoppingList.sourceRecipes.filter(
         r => r.id !== recipeId
       );
       
       return this.shoppingList;
     }
     
     // Update serving size for a recipe
     updateServings(recipeId: string, newServings: number): ShoppingList {
       const recipe = this.shoppingList.sourceRecipes.find(r => r.id === recipeId);
       if (!recipe) return this.shoppingList;
       
       const multiplier = newServings / recipe.originalServings;
       
       // Update all items from this recipe
       for (const item of this.shoppingList.items) {
         const source = item.sources.find(s => s.recipeId === recipeId);
         if (source) {
           const oldContribution = source.quantity;
           const newContribution = oldContribution * multiplier;
           source.quantity = newContribution;
           
           // Recalculate total
           item.quantity.value = this.recalculateTotalQuantity(item);
         }
       }
       
       recipe.servings = newServings;
       
       return this.shoppingList;
     }
     
     // Get current shopping list
     getShoppingList(): ShoppingList;
     
     // Export in various formats
     exportAsText(): string;
     exportAsMarkdown(): string;
     exportAsJSON(): object;
   }

   interface Recipe {
     id: string;
     name: string;
     servings: number;
     ingredients: string[];
     // Optional metadata
     source?: string;
     url?: string;
     cuisine?: string;
     categories?: string[];
   }

   interface RecipeOptions {
     servings?: number;     // Override recipe servings
     exclude?: string[];    // Ingredients to skip
     substitute?: Map<string, string>; // Substitutions
   }
   ```

2. **Ingredient Scaling**:
   ```typescript
   class IngredientScaler {
     // Scale quantities based on serving multiplier
     scale(ingredient: ParsedIngredient, multiplier: number): ParsedIngredient {
       if (!ingredient.quantity) return ingredient;
       
       // Don't scale "to taste" or optional items
       if (ingredient.flags.toTaste || ingredient.flags.forGarnish) {
         return ingredient;
       }
       
       const scaledQuantity = {
         ...ingredient.quantity,
         value: ingredient.quantity.value * multiplier,
         display: this.formatScaledQuantity(
           ingredient.quantity.value * multiplier,
           ingredient.unit
         )
       };
       
       return {
         ...ingredient,
         quantity: scaledQuantity
       };
     }
     
     // Format scaled quantity nicely
     private formatScaledQuantity(value: number, unit: UnitInfo | null): string {
       // Round to sensible values
       const rounded = this.roundToMeasurable(value, unit);
       
       // Format with appropriate fractions
       return this.quantityFormatter.format(rounded, unit);
     }
     
     // Round to values that can actually be measured
     private roundToMeasurable(value: number, unit: UnitInfo | null): number {
       if (!unit) return Math.round(value);
       
       if (unit.type === 'volume') {
         // Round to nearest 1/8 for small amounts, 1/4 for larger
         if (value < 0.25) {
           return Math.round(value * 8) / 8;
         } else {
           return Math.round(value * 4) / 4;
         }
       }
       
       if (unit.type === 'count') {
         return Math.ceil(value); // Can't buy half an onion
       }
       
       return Math.round(value * 10) / 10;
     }
   }
   ```

3. **Pantry Integration** (optional items user already has):
   ```typescript
   interface PantryItem {
     ingredient: string;
     quantity?: number;
     unit?: string;
     expires?: Date;
   }

   class PantryIntegrator {
     private pantry: Map<string, PantryItem>;
     
     // Check pantry against shopping list
     checkAgainstPantry(shoppingList: ShoppingList): PantryCheckResult {
       const haveEnough: ShoppingListItem[] = [];
       const needMore: ShoppingListItemWithPantry[] = [];
       const notInPantry: ShoppingListItem[] = [];
       
       for (const item of shoppingList.items) {
         const pantryItem = this.findInPantry(item.canonical);
         
         if (!pantryItem) {
           notInPantry.push(item);
         } else if (this.hasEnough(pantryItem, item)) {
           haveEnough.push(item);
         } else {
           needMore.push({
             ...item,
             inPantry: pantryItem.quantity,
             stillNeed: this.calculateDifference(item, pantryItem)
           });
         }
       }
       
       return { haveEnough, needMore, notInPantry };
     }
     
     // Update pantry after shopping
     markAsPurchased(items: ShoppingListItem[]): void;
     
     // Deduct from pantry after cooking
     markAsUsed(recipe: Recipe): void;
   }
   ```

4. **Meal Planning Bridge**:
   ```typescript
   interface MealPlan {
     id: string;
     startDate: Date;
     endDate: Date;
     meals: PlannedMeal[];
   }

   interface PlannedMeal {
     date: Date;
     mealType: 'breakfast' | 'lunch' | 'dinner' | 'snack';
     recipe: Recipe;
     servings: number;
   }

   class MealPlanIntegrator {
     // Generate shopping list for a meal plan
     generateShoppingList(mealPlan: MealPlan): ShoppingList {
       const integrator = new RecipeIntegrator();
       
       for (const meal of mealPlan.meals) {
         integrator.addRecipe(meal.recipe, { servings: meal.servings });
       }
       
       return integrator.getShoppingList();
     }
     
     // Update shopping list when meal plan changes
     handleMealPlanChange(
       change: MealPlanChange,
       currentList: ShoppingList
     ): ShoppingList;
   }
   ```

5. **Tests**:
   ```typescript
   describe('RecipeIntegrator', () => {
     test('adds single recipe to empty list');
     test('merges ingredients when adding second recipe');
     test('removes recipe and updates quantities');
     test('scales ingredients for different servings');
     test('handles serving change after adding');
     test('excludes specified ingredients');
     
     // Edge cases
     test('handles recipe with no parseable ingredients');
     test('handles duplicate recipes (same ID)');
     test('preserves notes when merging');
   });

   describe('IngredientScaler', () => {
     test('scales 2 cups to 3 cups for 1.5x');
     test('rounds to measurable quantities');
     test('does not scale "to taste" items');
     test('scales count items and rounds up');
   });

   describe('MealPlanIntegrator', () => {
     test('generates list for week of meals');
     test('combines same ingredient across days');
     test('tracks which meal each item is for');
   });
   ```

Build the integration that makes shopping list generation feel seamless and accurate.
```

---

# PHASE 4: Web Demo & Feedback System

## Prompt 4.1: React Web Demo UI

```
In ~/heirloom-shopping-lab, build the React web demo UI for testing the shopping list system.

This will be a hidden page at heirloom.app/lab for internal and beta tester use.

Create the full React application:

1. **Pages**:
   ```
   src/pages/
   ├── LabHome.tsx           # Main testing interface
   ├── ParserPlayground.tsx  # Test individual ingredient parsing
   ├── ConsolidatorTest.tsx  # Test full consolidation
   ├── GoldenTests.tsx       # Run and view golden test results
   └── FeedbackReview.tsx    # Review user corrections
   ```

2. **LabHome.tsx** - Main Interface:
   ```tsx
   const LabHome: React.FC = () => {
     return (
       <div className="min-h-screen bg-cream-50">
         <header className="bg-tomato-600 text-white p-4">
           <h1 className="text-2xl font-serif">Heirloom Shopping Lab</h1>
           <p className="text-cream-100">Internal testing environment</p>
         </header>
         
         <nav className="bg-white border-b p-4">
           <Link to="/lab/parser">Parser Playground</Link>
           <Link to="/lab/consolidator">Consolidation Test</Link>
           <Link to="/lab/golden">Golden Tests</Link>
           <Link to="/lab/feedback">Feedback Review</Link>
         </nav>
         
         <main className="p-6">
           <QuickStats />
           <RecentIssues />
           <TestCoverage />
         </main>
       </div>
     );
   };
   ```

3. **ParserPlayground.tsx** - Interactive Parser Testing:
   ```tsx
   const ParserPlayground: React.FC = () => {
     const [input, setInput] = useState('');
     const [result, setResult] = useState<ParsedIngredient | null>(null);
     const [parseSteps, setParseSteps] = useState<ParseStep[]>([]);
     
     const handleParse = async () => {
       const { result, steps } = await parser.parseWithExplanation(input);
       setResult(result);
       setParseSteps(steps);
     };
     
     return (
       <div className="grid grid-cols-2 gap-6 p-6">
         {/* Input Panel */}
         <div className="space-y-4">
           <h2>Input</h2>
           <textarea
             value={input}
             onChange={e => setInput(e.target.value)}
             className="w-full h-32 p-3 border rounded"
             placeholder="Enter ingredient text..."
           />
           <button onClick={handleParse} className="btn-primary">
             Parse Ingredient
           </button>
           
           {/* Quick test examples */}
           <div className="space-y-2">
             <h3>Quick Tests:</h3>
             {EXAMPLE_INGREDIENTS.map(ex => (
               <button
                 key={ex}
                 onClick={() => setInput(ex)}
                 className="text-sm text-left hover:bg-gray-100 p-2 rounded block"
               >
                 {ex}
               </button>
             ))}
           </div>
         </div>
         
         {/* Result Panel */}
         <div className="space-y-4">
           <h2>Parsed Result</h2>
           
           {result && (
             <div className="space-y-4">
               {/* Visual result */}
               <div className="bg-white p-4 rounded shadow">
                 <ParsedIngredientDisplay ingredient={result} />
               </div>
               
               {/* Confidence meter */}
               <ConfidenceMeter value={result.confidence} />
               
               {/* Parse steps (debug view) */}
               <details className="bg-gray-50 p-4 rounded">
                 <summary>Parse Steps</summary>
                 <ParseStepsTimeline steps={parseSteps} />
               </details>
               
               {/* JSON view */}
               <details className="bg-gray-50 p-4 rounded">
                 <summary>JSON Output</summary>
                 <pre className="text-xs overflow-auto">
                   {JSON.stringify(result, null, 2)}
                 </pre>
               </details>
               
               {/* Correction interface */}
               <CorrectionForm
                 original={input}
                 parsed={result}
                 onSubmit={handleCorrection}
               />
             </div>
           )}
         </div>
       </div>
     );
   };
   ```

4. **ConsolidatorTest.tsx** - Full Recipe Test:
   ```tsx
   const ConsolidatorTest: React.FC = () => {
     const [recipes, setRecipes] = useState<TestRecipe[]>([]);
     const [shoppingList, setShoppingList] = useState<ShoppingList | null>(null);
     const [conflicts, setConflicts] = useState<Conflict[]>([]);
     
     return (
       <div className="p-6 space-y-6">
         <h2>Shopping List Consolidation Test</h2>
         
         {/* Recipe Input */}
         <div className="grid grid-cols-3 gap-4">
           {recipes.map((recipe, i) => (
             <RecipeCard
               key={i}
               recipe={recipe}
               onUpdate={r => updateRecipe(i, r)}
               onRemove={() => removeRecipe(i)}
             />
           ))}
           <AddRecipeCard onAdd={addRecipe} />
         </div>
         
         {/* Generate Button */}
         <button
           onClick={generateShoppingList}
           className="btn-primary w-full py-3 text-lg"
         >
           Generate Shopping List
         </button>
         
         {/* Results */}
         {shoppingList && (
           <div className="grid grid-cols-2 gap-6">
             {/* Shopping List */}
             <div className="bg-white rounded-lg shadow p-4">
               <h3 className="font-bold mb-4">Shopping List</h3>
               <ShoppingListDisplay list={shoppingList} />
             </div>
             
             {/* Analysis */}
             <div className="space-y-4">
               {/* Conflicts */}
               {conflicts.length > 0 && (
                 <ConflictPanel conflicts={conflicts} onResolve={resolveConflict} />
               )}
               
               {/* Merge visualization */}
               <MergeVisualization list={shoppingList} />
               
               {/* Per-recipe breakdown */}
               <RecipeBreakdown list={shoppingList} />
             </div>
           </div>
         )}
       </div>
     );
   };
   ```

5. **GoldenTests.tsx** - Automated Test Runner:
   ```tsx
   const GoldenTests: React.FC = () => {
     const [results, setResults] = useState<TestResult[]>([]);
     const [running, setRunning] = useState(false);
     const [filter, setFilter] = useState<'all' | 'failed' | 'passed'>('all');
     
     const runTests = async () => {
       setRunning(true);
       const results = await runGoldenTests();
       setResults(results);
       setRunning(false);
     };
     
     const passCount = results.filter(r => r.passed).length;
     const failCount = results.filter(r => !r.passed).length;
     
     return (
       <div className="p-6">
         <div className="flex justify-between items-center mb-6">
           <h2>Golden Test Suite</h2>
           <button onClick={runTests} disabled={running} className="btn-primary">
             {running ? 'Running...' : 'Run All Tests'}
           </button>
         </div>
         
         {/* Summary */}
         <div className="grid grid-cols-3 gap-4 mb-6">
           <StatCard label="Total" value={results.length} />
           <StatCard label="Passed" value={passCount} color="green" />
           <StatCard label="Failed" value={failCount} color="red" />
         </div>
         
         {/* Filter */}
         <div className="flex gap-2 mb-4">
           <FilterButton active={filter === 'all'} onClick={() => setFilter('all')}>All</FilterButton>
           <FilterButton active={filter === 'passed'} onClick={() => setFilter('passed')}>Passed</FilterButton>
           <FilterButton active={filter === 'failed'} onClick={() => setFilter('failed')}>Failed</FilterButton>
         </div>
         
         {/* Results */}
         <div className="space-y-2">
           {filteredResults.map(result => (
             <TestResultRow key={result.id} result={result} />
           ))}
         </div>
       </div>
     );
   };
   ```

6. **Components**:
   ```
   src/components/
   ├── ParsedIngredientDisplay.tsx   # Visual breakdown of parsed result
   ├── ConfidenceMeter.tsx           # Confidence score visualization
   ├── CorrectionForm.tsx            # User correction submission
   ├── ShoppingListDisplay.tsx       # Formatted shopping list
   ├── ConflictPanel.tsx             # Conflict resolution UI
   ├── MergeVisualization.tsx        # Show how items merged
   ├── RecipeCard.tsx                # Recipe input card
   └── TestResultRow.tsx             # Single test result
   ```

7. **Styling** (Tailwind config extending Heirloom design system):
   ```js
   // tailwind.config.js
   module.exports = {
     theme: {
       extend: {
         colors: {
           cream: { 50: '#FDF6E3', 100: '#FCF0D4', /* ... */ },
           tomato: { 500: '#E54B4B', 600: '#D43D3D', /* ... */ },
           amber: { 400: '#D4A574', 500: '#C49464', /* ... */ },
           charcoal: { 500: '#3D3D3D', 600: '#2D2D2D', /* ... */ },
           'family-green': { 500: '#2D5A27', 600: '#1D4A17', /* ... */ },
         },
         fontFamily: {
           serif: ['Georgia', 'serif'],
           sans: ['system-ui', 'sans-serif'],
         }
       }
     }
   };
   ```

8. **Routing**:
   ```tsx
   // src/App.tsx
   const App: React.FC = () => {
     return (
       <BrowserRouter>
         <Routes>
           <Route path="/lab" element={<LabHome />} />
           <Route path="/lab/parser" element={<ParserPlayground />} />
           <Route path="/lab/consolidator" element={<ConsolidatorTest />} />
           <Route path="/lab/golden" element={<GoldenTests />} />
           <Route path="/lab/feedback" element={<FeedbackReview />} />
         </Routes>
       </BrowserRouter>
     );
   };
   ```

Build a polished, functional testing interface. This is where you and beta testers will stress-test the system before it goes into the production app.
```

## Prompt 4.2: Feedback Collection System

```
In ~/heirloom-shopping-lab, build the feedback collection system that captures user corrections and learns from them.

This is the foundation for continuous improvement—every correction makes the system smarter.

Create src/feedback/:

1. **FeedbackCollector**:
   ```typescript
   // src/feedback/collector.ts
   
   interface ParseFeedback {
     id: string;
     timestamp: Date;
     
     // What was parsed
     originalInput: string;
     systemParsed: ParsedIngredient;
     
     // User correction
     userCorrected: ParsedIngredient;
     
     // What specifically was wrong
     corrections: CorrectionDetail[];
     
     // Metadata
     sessionId: string;
     source: 'lab' | 'app' | 'api';
     confidence: number;        // System's original confidence
   }

   interface CorrectionDetail {
     field: 'quantity' | 'unit' | 'ingredient' | 'preparation' | 'flags';
     original: any;
     corrected: any;
     impact: 'high' | 'medium' | 'low';  // How much this affects shopping list
   }

   class FeedbackCollector {
     private storage: FeedbackStorage;
     private analytics: AnalyticsTracker;
     
     // Submit correction
     async submitCorrection(feedback: ParseFeedback): Promise<void> {
       // Validate correction
       this.validateFeedback(feedback);
       
       // Store locally
       await this.storage.saveFeedback(feedback);
       
       // Track analytics
       this.analytics.trackCorrection(feedback);
       
       // If high-impact, flag for immediate review
       if (this.isHighImpact(feedback)) {
         await this.flagForReview(feedback);
       }
     }
     
     // Get corrections for analysis
     async getCorrections(options?: QueryOptions): Promise<ParseFeedback[]>;
     
     // Get correction statistics
     async getStats(): Promise<CorrectionStats>;
     
     // Export for training
     async exportForTraining(): Promise<TrainingData>;
   }
   ```

2. **Feedback Analysis**:
   ```typescript
   // src/feedback/analyzer.ts
   
   class FeedbackAnalyzer {
     // Find patterns in corrections
     async analyzePatterns(): Promise<PatternAnalysis> {
       const feedback = await this.collector.getCorrections();
       
       return {
         // Most commonly corrected ingredients
         frequentMisparses: this.findFrequentMisparses(feedback),
         
         // Unit confusion patterns
         unitConfusions: this.findUnitConfusions(feedback),
         
         // Missing synonyms
         missingSynonyms: this.findMissingSynonyms(feedback),
         
         // Quantity parsing issues
         quantityIssues: this.findQuantityIssues(feedback),
         
         // Suggestions for improvement
         suggestions: this.generateSuggestions(feedback)
       };
     }
     
     private findFrequentMisparses(feedback: ParseFeedback[]): MisparsePattern[] {
       const byIngredient = groupBy(feedback, f => f.userCorrected.ingredient.canonical);
       
       return Object.entries(byIngredient)
         .filter(([_, items]) => items.length >= 3) // At least 3 corrections
         .map(([canonical, items]) => ({
           canonical,
           count: items.length,
           commonInputs: this.findCommonInputs(items),
           suggestedFix: this.suggestFix(canonical, items)
         }))
         .sort((a, b) => b.count - a.count);
     }
     
     private findMissingSynonyms(feedback: ParseFeedback[]): SynonymSuggestion[] {
       // Find cases where ingredient was corrected but could be a synonym
       return feedback
         .filter(f => f.corrections.some(c => c.field === 'ingredient'))
         .map(f => ({
           input: f.systemParsed.ingredient.original,
           correctedTo: f.userCorrected.ingredient.canonical,
           count: 1  // Will be aggregated
         }))
         .reduce((acc, item) => {
           const key = `${item.input}→${item.correctedTo}`;
           if (!acc.has(key)) acc.set(key, { ...item, count: 0 });
           acc.get(key)!.count++;
           return acc;
         }, new Map())
         .values()
         .filter(s => s.count >= 2); // Suggested at least twice
     }
   }
   ```

3. **Training Data Generator**:
   ```typescript
   // src/feedback/training.ts
   
   class TrainingDataGenerator {
     // Generate training data from corrections
     async generateTrainingData(): Promise<TrainingDataset> {
       const feedback = await this.collector.getCorrections();
       const validated = await this.validateFeedback(feedback);
       
       return {
         // For retraining the parser
         parserExamples: this.generateParserExamples(validated),
         
         // For improving the normalizer
         synonymAdditions: this.generateSynonymAdditions(validated),
         
         // For the unit converter
         unitMappings: this.generateUnitMappings(validated),
         
         // Statistics
         stats: {
           totalExamples: validated.length,
           byField: this.countByField(validated),
           confidence: this.calculateConfidence(validated)
         }
       };
     }
     
     private generateParserExamples(feedback: ParseFeedback[]): ParserExample[] {
       return feedback.map(f => ({
         input: f.originalInput,
         expected: {
           quantity: f.userCorrected.quantity,
           unit: f.userCorrected.unit,
           ingredient: f.userCorrected.ingredient,
           preparation: f.userCorrected.preparation
         },
         weight: this.calculateWeight(f)
       }));
     }
     
     // Auto-apply confident corrections
     async autoApplyCorrections(): Promise<AutoApplyResult> {
       const analysis = await this.analyzer.analyzePatterns();
       const applied: AppliedCorrection[] = [];
       
       // Add obvious synonyms (>= 5 corrections, same pattern)
       for (const synonym of analysis.missingSynonyms) {
         if (synonym.count >= 5) {
           await this.synonymService.addSynonym(synonym.input, synonym.correctedTo);
           applied.push({ type: 'synonym', details: synonym });
         }
       }
       
       // Add missing ingredients
       for (const misparse of analysis.frequentMisparses) {
         if (misparse.count >= 10 && misparse.suggestedFix) {
           await this.database.addIngredient(misparse.suggestedFix);
           applied.push({ type: 'ingredient', details: misparse });
         }
       }
       
       return { applied, skipped: analysis.suggestions.length - applied.length };
     }
   }
   ```

4. **Feedback UI Components**:
   ```tsx
   // src/components/CorrectionForm.tsx
   
   const CorrectionForm: React.FC<{
     original: string;
     parsed: ParsedIngredient;
     onSubmit: (feedback: ParseFeedback) => void;
   }> = ({ original, parsed, onSubmit }) => {
     const [corrections, setCorrections] = useState<Partial<ParsedIngredient>>({});
     
     const handleFieldCorrection = (field: keyof ParsedIngredient, value: any) => {
       setCorrections(prev => ({ ...prev, [field]: value }));
     };
     
     return (
       <div className="bg-amber-50 p-4 rounded-lg border border-amber-200">
         <h4 className="font-bold mb-3">Was this parsed correctly?</h4>
         
         <div className="space-y-3">
           {/* Quantity correction */}
           <CorrectionField
             label="Quantity"
             original={parsed.quantity?.display || 'none'}
             value={corrections.quantity}
             onChange={v => handleFieldCorrection('quantity', v)}
           />
           
           {/* Unit correction */}
           <CorrectionField
             label="Unit"
             original={parsed.unit?.canonical || 'none'}
             value={corrections.unit}
             onChange={v => handleFieldCorrection('unit', v)}
             suggestions={COMMON_UNITS}
           />
           
           {/* Ingredient correction */}
           <CorrectionField
             label="Ingredient"
             original={parsed.ingredient.canonical}
             value={corrections.ingredient}
             onChange={v => handleFieldCorrection('ingredient', v)}
             searchable
           />
           
           {/* Preparation correction */}
           <CorrectionField
             label="Preparation"
             original={parsed.preparation.join(', ') || 'none'}
             value={corrections.preparation}
             onChange={v => handleFieldCorrection('preparation', v)}
           />
         </div>
         
         <div className="flex gap-2 mt-4">
           <button
             onClick={() => onSubmit(null)}
             className="btn-secondary flex-1"
           >
             Looks Correct ✓
           </button>
           <button
             onClick={() => submitCorrection(corrections)}
             className="btn-primary flex-1"
             disabled={Object.keys(corrections).length === 0}
           >
             Submit Correction
           </button>
         </div>
       </div>
     );
   };
   ```

5. **Feedback Review Dashboard**:
   ```tsx
   // src/pages/FeedbackReview.tsx
   
   const FeedbackReview: React.FC = () => {
     const [analysis, setAnalysis] = useState<PatternAnalysis | null>(null);
     const [pending, setPending] = useState<ParseFeedback[]>([]);
     
     useEffect(() => {
       loadAnalysis();
       loadPending();
     }, []);
     
     return (
       <div className="p-6 space-y-6">
         <h2>Feedback Review</h2>
         
         {/* Summary Stats */}
         <div className="grid grid-cols-4 gap-4">
           <StatCard label="Total Corrections" value={stats.total} />
           <StatCard label="Pending Review" value={pending.length} />
           <StatCard label="Auto-Applied" value={stats.autoApplied} />
           <StatCard label="Accuracy Impact" value={`+${stats.accuracyGain}%`} />
         </div>
         
         {/* Pattern Analysis */}
         {analysis && (
           <div className="grid grid-cols-2 gap-6">
             <PatternCard
               title="Frequent Misparses"
               items={analysis.frequentMisparses}
               onApplyFix={applyFix}
             />
             <PatternCard
               title="Missing Synonyms"
               items={analysis.missingSynonyms}
               onAddSynonym={addSynonym}
             />
           </div>
         )}
         
         {/* Pending Corrections */}
         <div className="bg-white rounded-lg shadow">
           <h3 className="p-4 border-b font-bold">Pending Review</h3>
           <div className="divide-y">
             {pending.map(feedback => (
               <FeedbackReviewRow
                 key={feedback.id}
                 feedback={feedback}
                 onApprove={() => approveFeedback(feedback.id)}
                 onReject={() => rejectFeedback(feedback.id)}
                 onEdit={() => editFeedback(feedback)}
               />
             ))}
           </div>
         </div>
         
         {/* Auto-Apply Button */}
         <button
           onClick={runAutoApply}
           className="btn-primary"
         >
           Auto-Apply Confident Corrections
         </button>
       </div>
     );
   };
   ```

6. **Persistence**:
   ```typescript
   // src/feedback/storage.ts
   
   class FeedbackStorage {
     private db: IDBDatabase;
     
     async saveFeedback(feedback: ParseFeedback): Promise<void>;
     async getFeedback(id: string): Promise<ParseFeedback | null>;
     async queryFeedback(options: QueryOptions): Promise<ParseFeedback[]>;
     async deleteFeedback(id: string): Promise<void>;
     
     // Sync to server
     async syncToServer(): Promise<SyncResult>;
     async pullFromServer(): Promise<ParseFeedback[]>;
   }
   ```

Build a comprehensive feedback system. Every user interaction is an opportunity to improve accuracy.
```

## Prompt 4.3: Swift Export & Integration Prep

```
In ~/heirloom-shopping-lab, create the Swift export system that generates iOS-ready code from the TypeScript implementation.

This is the bridge from web testing to production iOS app.

Create src/scripts/swift-export/:

1. **Type Generator**:
   ```typescript
   // src/scripts/swift-export/type-generator.ts
   
   class SwiftTypeGenerator {
     // Generate Swift structs from TypeScript interfaces
     generateTypes(): string {
       return `
   // GENERATED - DO NOT EDIT
   // Generated from TypeScript types on ${new Date().toISOString()}
   
   import Foundation
   
   // MARK: - Core Types
   
   struct ParsedIngredient: Codable, Equatable {
       let original: String
       let quantity: QuantityValue?
       let unit: UnitInfo?
       let ingredient: IngredientInfo
       let preparation: [String]
       let modifiers: [String]
       let confidence: Double
       let flags: IngredientFlags
   }
   
   struct QuantityValue: Codable, Equatable {
       enum QuantityType: String, Codable {
           case single, range, approximate
       }
       
       let type: QuantityType
       let value: Double
       let valueLow: Double?
       let valueHigh: Double?
       let display: String
   }
   
   struct UnitInfo: Codable, Equatable {
       enum UnitType: String, Codable {
           case volume, weight, count, informal, other
       }
       
       enum UnitSystem: String, Codable {
           case metric, imperial, universal
       }
       
       let canonical: String
       let original: String
       let type: UnitType
       let system: UnitSystem
       let mlEquivalent: Double?
       let gramEquivalent: Double?
   }
   
   struct IngredientInfo: Codable, Equatable {
       let canonical: String
       let original: String
       let category: IngredientCategory
       let subcategory: String?
       let aisleHint: String?
   }
   
   struct IngredientFlags: Codable, Equatable {
       let optional: Bool
       let toTaste: Bool
       let forGarnish: Bool
       let divided: Bool
       let separated: Bool
       let partialUse: PartialUse?
       
       enum PartialUse: String, Codable {
           case whites, yolks, juice, zest
       }
   }
   
   enum IngredientCategory: String, Codable, CaseIterable {
       case produce, dairy, meat, seafood, bakery
       case pantry, spices, condiments, frozen, beverages
       case oils, grains, canned, baking, other
   }
   
   // MARK: - Shopping List Types
   
   struct ShoppingList: Codable {
       let id: String
       let createdAt: Date
       let updatedAt: Date
       let items: [ShoppingListItem]
       let sourceRecipes: [RecipeSummary]
       let warnings: [ConsolidationWarning]
   }
   
   struct ShoppingListItem: Codable, Identifiable {
       let id: String
       let displayText: String
       let canonical: String
       let category: IngredientCategory
       let aisle: String
       let quantity: ItemQuantity
       let sources: [IngredientSource]
       var isChecked: Bool
       let notes: [String]
       let confidence: Double
       let flags: ItemFlags
       
       struct ItemQuantity: Codable {
           let value: Double
           let unit: String
           let display: String
       }
       
       struct ItemFlags: Codable {
           let hasVariants: Bool
           let isApproximate: Bool
           let needsReview: Bool
       }
   }
   
   struct IngredientSource: Codable {
       let recipeId: String
       let recipeName: String
       let originalText: String
       let quantity: Double
       let unit: String
   }
   `;
     }
   }
   ```

2. **Data Exporter**:
   ```typescript
   // src/scripts/swift-export/data-exporter.ts
   
   class DataExporter {
     async exportAllData(): Promise<void> {
       const outputDir = 'swift-export/data';
       
       // Export ingredients database
       await this.exportIngredients(`${outputDir}/ingredients.json`);
       
       // Export synonyms
       await this.exportSynonyms(`${outputDir}/synonyms.json`);
       
       // Export unit definitions
       await this.exportUnits(`${outputDir}/units.json`);
       
       // Export densities
       await this.exportDensities(`${outputDir}/densities.json`);
       
       // Generate Swift data loader
       await this.generateDataLoader(`${outputDir}/DataLoader.swift`);
     }
     
     private async generateDataLoader(path: string): Promise<void> {
       const swift = `
   // GENERATED - DO NOT EDIT
   
   import Foundation
   
   class IngredientDataLoader {
       static let shared = IngredientDataLoader()
       
       private(set) var ingredients: [String: CanonicalIngredient] = [:]
       private(set) var synonyms: [String: String] = [:]
       private(set) var units: [String: UnitDefinition] = [:]
       private(set) var densities: [String: DensityInfo] = [:]
       
       private init() {
           loadData()
       }
       
       private func loadData() {
           // Load from bundled JSON files
           ingredients = loadJSON("ingredients")
           synonyms = loadJSON("synonyms")
           units = loadJSON("units")
           densities = loadJSON("densities")
       }
       
       private func loadJSON<T: Decodable>(_ name: String) -> T {
           guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
                 let data = try? Data(contentsOf: url),
                 let decoded = try? JSONDecoder().decode(T.self, from: data)
           else {
               fatalError("Failed to load \\(name).json")
           }
           return decoded
       }
   }
   `;
       await fs.writeFile(path, swift);
     }
   }
   ```

3. **Algorithm Translator**:
   ```typescript
   // src/scripts/swift-export/algorithm-docs.ts
   
   class AlgorithmDocGenerator {
     // Generate documentation for translating algorithms to Swift
     generateTranslationGuide(): string {
       return `
   # Heirloom Shopping List - Swift Implementation Guide
   
   This document provides guidance for implementing the ingredient parsing
   and shopping list consolidation algorithms in Swift.
   
   ## Architecture Overview
   
   The TypeScript implementation uses these core classes:
   - QuantityParser: Parses quantity values from strings
   - UnitConverter: Handles unit recognition and conversion
   - IngredientNormalizer: Normalizes ingredient names via synonyms
   - IngredientParser: Orchestrates full ingredient parsing
   - ShoppingListConsolidator: Combines parsed ingredients into shopping list
   
   ## Translation Notes
   
   ### Regex Patterns
   TypeScript:
   \`const FRACTION_PATTERN = /^(\\d+)?\\s*(\\d+)\\/(\\d+)/;\`
   
   Swift:
   \`let fractionPattern = try! NSRegularExpression(pattern: "^(\\\\d+)?\\\\s*(\\\\d+)/(\\\\d+)")\`
   
   ### Optional Handling
   TypeScript uses null/undefined; Swift uses Optional<T>
   
   ### Enums
   TypeScript string enums map to Swift String-backed enums
   
   ### Collections
   - TypeScript Map<K,V> → Swift Dictionary<K,V>
   - TypeScript Set<T> → Swift Set<T>
   - TypeScript Array<T>.filter/map → Swift .filter/.map (same names)
   
   ## Core Algorithm: Ingredient Parsing
   
   The parsing pipeline:
   1. Clean input (normalize whitespace, handle special chars)
   2. Extract quantity (start of string typically)
   3. Extract unit (after quantity)
   4. Extract ingredient name (remaining text)
   5. Separate preparation notes
   6. Normalize ingredient name
   7. Detect special flags
   8. Calculate confidence
   
   See \`src/core/parser/ingredient-parser.ts\` for reference implementation.
   
   ## Core Algorithm: Consolidation
   
   The consolidation pipeline:
   1. Parse all ingredient strings
   2. Normalize all ingredient names
   3. Group by (canonical_name, unit_type)
   4. For each group:
      a. Convert all quantities to base unit
      b. Sum quantities
      c. Convert to best display unit
   5. Handle special cases (eggs, citrus)
   6. Organize by aisle
   7. Generate shopping list
   
   See \`src/core/consolidator/index.ts\` for reference implementation.
   `;
     }
   }
   ```

4. **Test Suite Exporter**:
   ```typescript
   // src/scripts/swift-export/test-exporter.ts
   
   class TestExporter {
     // Export golden tests as Swift XCTest
     async exportGoldenTests(): Promise<void> {
       const tests = await this.loadGoldenTests();
       
       const swift = `
   // GENERATED - DO NOT EDIT
   
   import XCTest
   @testable import Heirloom
   
   final class IngredientParserGoldenTests: XCTestCase {
       let parser = IngredientParser()
       
       ${tests.map(t => this.generateTestCase(t)).join('\n\n    ')}
   }
   
   // MARK: - Test Helpers
   
   extension IngredientParserGoldenTests {
       func assertParsedIngredient(
           _ input: String,
           quantity: Double?,
           unit: String?,
           ingredient: String,
           file: StaticString = #file,
           line: UInt = #line
       ) {
           let result = parser.parse(input)
           
           if let expectedQty = quantity {
               XCTAssertEqual(result.quantity?.value, expectedQty, "Quantity mismatch", file: file, line: line)
           }
           
           if let expectedUnit = unit {
               XCTAssertEqual(result.unit?.canonical, expectedUnit, "Unit mismatch", file: file, line: line)
           }
           
           XCTAssertEqual(result.ingredient.canonical, ingredient, "Ingredient mismatch", file: file, line: line)
       }
   }
   `;
       
       await fs.writeFile('swift-export/IngredientParserGoldenTests.swift', swift);
     }
     
     private generateTestCase(test: GoldenTest): string {
       return `
       func test_${this.sanitizeTestName(test.input)}() {
           assertParsedIngredient(
               "${test.input}",
               quantity: ${test.expected.quantity?.value ?? 'nil'},
               unit: ${test.expected.unit ? `"${test.expected.unit.canonical}"` : 'nil'},
               ingredient: "${test.expected.ingredient.canonical}"
           )
       }`;
     }
   }
   ```

5. **Integration Documentation**:
   ```typescript
   // src/scripts/swift-export/integration-guide.ts
   
   class IntegrationGuideGenerator {
     generate(): string {
       return `
   # Heirloom iOS Integration Guide
   
   ## Files to Add to Xcode Project
   
   1. **Types** (Heirloom/Core/ShoppingList/Types/):
      - GeneratedTypes.swift
      
   2. **Data** (Heirloom/Resources/ShoppingListData/):
      - ingredients.json
      - synonyms.json
      - units.json
      - densities.json
      
   3. **Services** (Heirloom/Core/ShoppingList/Services/):
      - IngredientParser.swift (implement from TypeScript reference)
      - UnitConverter.swift
      - IngredientNormalizer.swift
      - ShoppingListConsolidator.swift
      
   4. **Tests** (HeirloomTests/ShoppingList/):
      - IngredientParserGoldenTests.swift
      
   ## SwiftData Integration
   
   The shopping list integrates with existing SwiftData models:
   
   \`\`\`swift
   // In Recipe model, add:
   @Relationship(deleteRule: .cascade)
   var shoppingListContributions: [ShoppingListContribution]?
   
   // New model:
   @Model
   class ShoppingListContribution {
       var ingredientCanonical: String
       var quantity: Double
       var unit: String
       var originalText: String
       
       @Relationship(inverse: \\Recipe.shoppingListContributions)
       var recipe: Recipe?
   }
   \`\`\`
   
   ## View Integration
   
   Add shopping list views:
   - ShoppingListView.swift (main list)
   - ShoppingListItemRow.swift (single item)
   - AddToShoppingListSheet.swift (from recipe detail)
   
   ## Testing Strategy
   
   1. Run golden tests first - these validate core parsing
   2. Integration tests with real recipes
   3. UI tests for shopping list interactions
   `;
     }
   }
   ```

6. **Export Script**:
   ```typescript
   // src/scripts/swift-export/export.ts
   
   async function exportForSwift() {
     console.log('Exporting for Swift...\n');
     
     const outputDir = 'swift-export';
     await fs.mkdir(outputDir, { recursive: true });
     
     // Generate types
     console.log('Generating Swift types...');
     const typeGen = new SwiftTypeGenerator();
     await fs.writeFile(`${outputDir}/GeneratedTypes.swift`, typeGen.generateTypes());
     
     // Export data
     console.log('Exporting data files...');
     const dataExporter = new DataExporter();
     await dataExporter.exportAllData();
     
     // Generate tests
     console.log('Generating test suite...');
     const testExporter = new TestExporter();
     await testExporter.exportGoldenTests();
     
     // Generate documentation
     console.log('Generating documentation...');
     const algoDoc = new AlgorithmDocGenerator();
     await fs.writeFile(`${outputDir}/ALGORITHM_GUIDE.md`, algoDoc.generateTranslationGuide());
     
     const integrationGuide = new IntegrationGuideGenerator();
     await fs.writeFile(`${outputDir}/INTEGRATION_GUIDE.md`, integrationGuide.generate());
     
     console.log('\n✅ Swift export complete!');
     console.log(`   Output: ${outputDir}/`);
   }
   
   // Run
   exportForSwift().catch(console.error);
   ```

7. **Package.json Script**:
   ```json
   {
     "scripts": {
       "export:swift": "ts-node src/scripts/swift-export/export.ts",
       "test:golden": "vitest run golden-tests/",
       "dev": "vite",
       "build": "vite build"
     }
   }
   ```

Build a comprehensive export system. When the web demo is validated, you should be able to run one command and get everything needed for iOS implementation.
```

## Prompt 4.4: Final Integration & Deployment

```
In ~/heirloom-shopping-lab, complete the project with deployment configuration, documentation, and final polish.

1. **Deployment Configuration** (for heirloom.app/lab):
   ```typescript
   // vite.config.ts
   import { defineConfig } from 'vite';
   import react from '@vitejs/plugin-react';
   import path from 'path';
   
   export default defineConfig({
     plugins: [react()],
     base: '/lab/',
     resolve: {
       alias: {
         '@core': path.resolve(__dirname, 'src/core'),
         '@data': path.resolve(__dirname, 'src/data'),
         '@components': path.resolve(__dirname, 'src/components'),
       }
     },
     build: {
       outDir: 'dist',
       sourcemap: true
     }
   });
   ```

2. **README.md**:
   ```markdown
   # Heirloom Shopping Lab
   
   Internal testing environment for Heirloom's ingredient parsing and shopping list consolidation system.
   
   ## Quick Start
   
   \`\`\`bash
   npm install
   npm run dev
   \`\`\`
   
   Open http://localhost:5173/lab
   
   ## Architecture
   
   \`\`\`
   src/
   ├── core/                 # Platform-agnostic logic
   │   ├── parser/           # Ingredient parsing
   │   ├── units/            # Unit conversion
   │   ├── normalizer/       # Name normalization
   │   ├── consolidator/     # Shopping list consolidation
   │   └── types/            # TypeScript types
   ├── data/                 # Static data files
   ├── components/           # React components
   ├── pages/                # Page components
   ├── feedback/             # Feedback collection
   └── scripts/              # Build/export scripts
   \`\`\`
   
   ## Testing
   
   \`\`\`bash
   # Run all tests
   npm test
   
   # Run golden tests only
   npm run test:golden
   
   # Run with coverage
   npm run test:coverage
   \`\`\`
   
   ## Export for Swift
   
   \`\`\`bash
   npm run export:swift
   \`\`\`
   
   Output in \`swift-export/\`:
   - GeneratedTypes.swift - Type definitions
   - data/*.json - Ingredient database
   - IngredientParserGoldenTests.swift - Test suite
   - ALGORITHM_GUIDE.md - Implementation guide
   - INTEGRATION_GUIDE.md - iOS integration guide
   
   ## Data Sources
   
   - USDA FoodData Central (densities, nutrition)
   - King Arthur Baking (baking ingredient weights)
   - Curated synonyms (regional terminology)
   
   ## Feedback Loop
   
   User corrections are collected and analyzed to improve parsing:
   1. Users submit corrections via the UI
   2. Corrections are stored locally (IndexedDB)
   3. Analysis identifies patterns
   4. High-confidence fixes are auto-applied
   5. Training data is exported for model updates
   ```

3. **TESTING_GUIDE.md**:
   ```markdown
   # Testing Guide
   
   ## Golden Test Categories
   
   ### Basic Parsing (50 tests)
   - Standard format: "2 cups flour"
   - Fractions: "1/2 tsp salt"
   - Unicode fractions: "½ cup milk"
   - Mixed numbers: "1 1/2 cups sugar"
   
   ### Complex Formats (50 tests)
   - Parenthetical: "1 (14-oz) can tomatoes"
   - Metric alternatives: "2 cups (250g) flour"
   - Preparation notes: "1 onion, diced"
   - Optional items: "parsley (optional)"
   
   ### Edge Cases (50 tests)
   - Egg parts: "3 egg whites"
   - Citrus parts: "juice of 2 lemons"
   - No quantity: "salt and pepper"
   - Ranges: "2-3 tablespoons"
   
   ### Consolidation (50 tests)
   - Same unit: "1 cup + 1 cup = 2 cups"
   - Different units: "3 tsp + 1 tbsp = 2 tbsp"
   - Egg math: "2 whites + 1 yolk = 2 eggs"
   - Variants: "salted + unsalted butter"
   
   ## Adding New Tests
   
   Add to \`golden-tests/cases.json\`:
   \`\`\`json
   {
     "input": "2 cups all-purpose flour",
     "expected": {
       "quantity": { "value": 2, "type": "single" },
       "unit": { "canonical": "cup" },
       "ingredient": { "canonical": "all-purpose flour" }
     },
     "category": "basic",
     "notes": "Standard format"
   }
   \`\`\`
   
   ## Stress Testing
   
   Import real recipes and check:
   1. Parse success rate (target: >95%)
   2. Consolidation accuracy (target: >90%)
   3. No crashes on any input
   4. Reasonable performance (<50ms per ingredient)
   ```

4. **CONTRIBUTING.md**:
   ```markdown
   # Contributing to Heirloom Shopping Lab
   
   ## Adding Ingredients
   
   1. Add to \`src/data/ingredients.json\`
   2. Add synonyms to \`src/data/synonyms.json\`
   3. Add density if applicable to \`src/data/densities.json\`
   4. Add test cases to golden tests
   
   ## Improving Parsing
   
   1. Check feedback for common failures
   2. Add failing case to golden tests
   3. Implement fix in relevant parser
   4. Verify all tests pass
   
   ## Code Style
   
   - Pure functions where possible
   - Comprehensive error handling
   - All public APIs documented
   - Tests for all new features
   ```

5. **CI Configuration** (.github/workflows/test.yml):
   ```yaml
   name: Test
   
   on:
     push:
       branches: [main]
     pull_request:
       branches: [main]
   
   jobs:
     test:
       runs-on: ubuntu-latest
       
       steps:
         - uses: actions/checkout@v3
         
         - uses: actions/setup-node@v3
           with:
             node-version: '20'
             cache: 'npm'
         
         - run: npm ci
         
         - run: npm run lint
         
         - run: npm test -- --coverage
         
         - run: npm run build
         
         - name: Upload coverage
           uses: codecov/codecov-action@v3
   ```

6. **Final Checklist Script**:
   ```typescript
   // src/scripts/pre-deploy-check.ts
   
   async function preDeployCheck() {
     console.log('Running pre-deploy checks...\n');
     
     const checks = [
       { name: 'All tests pass', fn: checkTests },
       { name: 'Golden tests pass', fn: checkGoldenTests },
       { name: 'No TypeScript errors', fn: checkTypes },
       { name: 'Build succeeds', fn: checkBuild },
       { name: 'Data files valid', fn: checkDataFiles },
       { name: 'Coverage > 80%', fn: checkCoverage },
     ];
     
     let allPassed = true;
     
     for (const check of checks) {
       process.stdout.write(`${check.name}... `);
       try {
         await check.fn();
         console.log('✅');
       } catch (error) {
         console.log('❌');
         console.error(`  Error: ${error.message}`);
         allPassed = false;
       }
     }
     
     if (allPassed) {
       console.log('\n✅ All checks passed! Ready to deploy.');
     } else {
       console.log('\n❌ Some checks failed. Fix issues before deploying.');
       process.exit(1);
     }
   }
   
   preDeployCheck();
   ```

7. **Package.json Final**:
   ```json
   {
     "name": "heirloom-shopping-lab",
     "version": "1.0.0",
     "private": true,
     "scripts": {
       "dev": "vite",
       "build": "tsc && vite build",
       "preview": "vite preview",
       "test": "vitest",
       "test:golden": "vitest run golden-tests/",
       "test:coverage": "vitest run --coverage",
       "lint": "eslint src --ext .ts,.tsx",
       "typecheck": "tsc --noEmit",
       "export:swift": "ts-node src/scripts/swift-export/export.ts",
       "check": "ts-node src/scripts/pre-deploy-check.ts",
       "deploy": "npm run check && npm run build && echo 'Deploy dist/ to heirloom.app/lab'"
     },
     "dependencies": {
       "react": "^18.2.0",
       "react-dom": "^18.2.0",
       "react-router-dom": "^6.20.0"
     },
     "devDependencies": {
       "@types/react": "^18.2.0",
       "@types/react-dom": "^18.2.0",
       "@vitejs/plugin-react": "^4.2.0",
       "autoprefixer": "^10.4.16",
       "eslint": "^8.55.0",
       "postcss": "^8.4.32",
       "tailwindcss": "^3.3.6",
       "typescript": "^5.3.0",
       "vite": "^5.0.0",
       "vitest": "^1.0.0"
     }
   }
   ```

Complete all configuration and documentation. The project should be fully ready for:
1. Local development
2. CI/CD testing
3. Deployment to heirloom.app/lab
4. Swift export for iOS implementation
```

---

# Summary: Running Order

Execute these prompts in order with Claude Code:

1. **Phase 1**: Core Parser (5 prompts)
   - 1.1: Project scaffolding
   - 1.2: Unit system
   - 1.3: Quantity parser
   - 1.4: Ingredient normalizer
   - 1.5: Full parser integration

2. **Phase 2**: Data Layer (3 prompts)
   - 2.1: Comprehensive ingredient database
   - 2.2: Synonym & regional mapping
   - 2.3: Database service layer

3. **Phase 3**: Consolidation (3 prompts)
   - 3.1: Consolidation algorithm
   - 3.2: Conflict detection & resolution
   - 3.3: Recipe integration

4. **Phase 4**: Web Demo & Export (4 prompts)
   - 4.1: React web demo UI
   - 4.2: Feedback collection system
   - 4.3: Swift export
   - 4.4: Deployment & documentation

Total: 15 Claude Code sessions to complete implementation.

Each prompt is designed to produce working, tested code that builds on previous prompts. The web demo will serve as your testing harness, and when you're confident in the results, the Swift export gives you everything needed for native iOS implementation.
