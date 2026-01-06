# Heirloom Platform Strategy
## Cross-Platform Architecture, Testing Infrastructure, and Watch Integration

**Document Version:** 1.0  
**Date:** January 2026  
**Author:** Rationale Studio

---

## Executive Summary

This document provides a comprehensive technical roadmap for evolving Heirloom from an iOS-first recipe app into a cross-platform system with Apple Watch support. The strategy is built around four interdependent workstreams:

1. **Shared Core Extraction** — Extract parsing, scaling, and aggregation logic into platform-agnostic TypeScript
2. **Test Harness Architecture** — Validate ingredient parsing, unit conversion, and shopping list aggregation
3. **Telemetry Schema** — Instrument production for import success, sharing metrics, and error tracking
4. **WatchOS Architecture** — Simple timer list for hands-free cooking

**Key Difference from Zero:** Heirloom's backend is already cross-platform (Firebase). The extraction focus is on *client-side intelligence* (parsing, scaling, aggregation) rather than core business logic.

---

## Table of Contents

1. [Shared Core Extraction Plan](#1-shared-core-extraction-plan)
2. [Test Harness Architecture](#2-test-harness-architecture)
3. [Telemetry Schema](#3-telemetry-schema)
4. [WatchOS App Architecture](#4-watchos-app-architecture)
5. [Ship Readiness Criteria](#5-ship-readiness-criteria)
6. [Attribution & Legal Compliance](#6-attribution--legal-compliance)
7. [Appendix: Agent Workflow Specifications](#appendix-agent-workflow-specifications)

---

# 1. Shared Core Extraction Plan

## 1.1 Why Extraction Matters for Heirloom

Unlike Zero (where intent classification is the core IP), Heirloom's intelligence is distributed across several subsystems:

```
┌─────────────────────────────────────────────────────────────────┐
│                 HEIRLOOM INTELLIGENCE MAP                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 AI-POWERED (GPT-4)                       │   │
│  │  • Recipe extraction from URLs                          │   │
│  │  • Photo OCR post-processing                            │   │
│  │  • Complex ingredient parsing                           │   │
│  │  └─► Stays server-side, cross-platform by nature        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              CLIENT-SIDE INTELLIGENCE                    │   │
│  │  • Ingredient parsing (structured extraction)           │   │
│  │  • Unit conversion (cups → ml, oz → grams)              │   │
│  │  • Scaling math (fractions, multipliers)                │   │
│  │  • Timer detection (regex patterns)                     │   │
│  │  • Shopping list aggregation (combine like items)       │   │
│  │  • Lineage operations (graph traversal, merging)        │   │
│  │  └─► EXTRACTION CANDIDATES                              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              FIREBASE (Already Cross-Platform)           │   │
│  │  • Auth, Firestore, Storage, Cloud Messaging            │   │
│  │  └─► No extraction needed                               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 1.2 Modules to Extract

### Module Inventory

| Module | Current Location | Extraction Priority | Complexity | Lines (Est.) |
|--------|------------------|---------------------|------------|--------------|
| Ingredient Parser | AIIngredientParser.swift | P0 - Critical | High | ~400 |
| Unit Converter | Embedded in services | P0 - Critical | Medium | ~300 |
| Scaling Engine | Recipe scaling logic | P0 - Critical | Medium | ~250 |
| Timer Detector | TimerDetectionService.swift | P1 - High | Low | ~150 |
| Shopping Aggregator | ShoppingCartRecipe.swift | P1 - High | High | ~350 |
| Lineage Operations | FirebaseLineageService.swift | P2 - Medium | High | ~400 |
| Provenance Tracker | ProvenanceMetadata.swift | P2 - Medium | Low | ~100 |

### 1.2.1 Ingredient Parser

**Purpose:** Parse ingredient strings into structured data

**Input Interface:**
```typescript
interface IngredientParseInput {
  text: string;                    // "2 1/2 cups all-purpose flour, sifted"
  locale?: Locale;                 // For regional unit preferences
  context?: ParsingContext;        // Recipe type hints
}

interface ParsingContext {
  recipeType?: RecipeType;         // 'baking' | 'cooking' | 'beverage'
  servingSize?: number;
  cuisine?: string;
}
```

**Output Interface:**
```typescript
interface ParsedIngredient {
  // Quantity
  quantity: QuantityResult;
  
  // Unit
  unit: UnitResult | null;
  
  // Ingredient
  ingredient: string;              // "all-purpose flour"
  ingredientNormalized: string;    // "flour_all_purpose" (for matching)
  
  // Modifiers
  preparation: string | null;      // "sifted"
  notes: string | null;            // "optional", "to taste"
  
  // Metadata
  isOptional: boolean;
  isRange: boolean;
  confidence: number;              // 0-1 parsing confidence
  originalText: string;
}

interface QuantityResult {
  value: number;                   // 2.5
  display: string;                 // "2 1/2" or "2½"
  isRange: boolean;
  rangeMin?: number;
  rangeMax?: number;
  isApproximate: boolean;          // "about", "~"
}

interface UnitResult {
  unit: StandardUnit;              // Canonical unit
  originalUnit: string;            // As written ("cups")
  category: UnitCategory;          // 'volume' | 'weight' | 'count' | 'length'
}

type StandardUnit = 
  // Volume
  | 'tsp' | 'tbsp' | 'cup' | 'fl_oz' | 'pint' | 'quart' | 'gallon'
  | 'ml' | 'l'
  // Weight
  | 'oz' | 'lb' | 'g' | 'kg'
  // Count
  | 'piece' | 'slice' | 'clove' | 'sprig' | 'bunch'
  // Length
  | 'inch' | 'cm'
  // Special
  | 'pinch' | 'dash' | 'to_taste';

type UnitCategory = 'volume' | 'weight' | 'count' | 'length' | 'special';
```

**Core Logic:**
```typescript
// packages/@heirloom/ingredient-parser/src/parser.ts

export class IngredientParser {
  private patterns: ParsingPatterns;
  private unitMap: UnitMapping;
  private ingredientNormalizer: IngredientNormalizer;

  parse(input: IngredientParseInput): ParsedIngredient {
    const { text, locale = 'en-US', context } = input;
    
    // Step 1: Normalize whitespace and characters
    const normalized = this.normalizeText(text);
    
    // Step 2: Extract quantity
    const quantityMatch = this.extractQuantity(normalized);
    
    // Step 3: Extract unit
    const unitMatch = this.extractUnit(normalized, quantityMatch.remainder);
    
    // Step 4: Extract preparation notes
    const prepMatch = this.extractPreparation(unitMatch.remainder);
    
    // Step 5: Extract ingredient name
    const ingredient = this.extractIngredient(prepMatch.remainder);
    
    // Step 6: Detect optional/notes
    const { isOptional, notes } = this.extractNotes(text);
    
    // Step 7: Calculate confidence
    const confidence = this.calculateConfidence(quantityMatch, unitMatch, ingredient);
    
    return {
      quantity: quantityMatch.result,
      unit: unitMatch.result,
      ingredient: ingredient.name,
      ingredientNormalized: this.ingredientNormalizer.normalize(ingredient.name),
      preparation: prepMatch.preparation,
      notes,
      isOptional,
      isRange: quantityMatch.result.isRange,
      confidence,
      originalText: text
    };
  }

  private extractQuantity(text: string): ExtractionResult<QuantityResult> {
    // Pattern priority:
    // 1. Unicode fractions: "2½", "¾"
    // 2. Written fractions: "2 1/2", "1/4"
    // 3. Decimals: "2.5", "0.25"
    // 4. Ranges: "1-2", "1 to 2"
    // 5. Approximations: "~2", "about 2"
    // 6. Whole numbers: "2"
    
    const patterns = [
      // "2½" or "2 ½"
      /^(\d+)\s*([½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])/,
      // "2 1/2"
      /^(\d+)\s+(\d+)\/(\d+)/,
      // "1/2"
      /^(\d+)\/(\d+)/,
      // "1-2" or "1 to 2" (range)
      /^(\d+(?:\.\d+)?)\s*(?:-|to)\s*(\d+(?:\.\d+)?)/i,
      // "~2" or "about 2"
      /^(?:~|about|approximately)\s*(\d+(?:\.\d+)?)/i,
      // "2.5"
      /^(\d+\.\d+)/,
      // "2"
      /^(\d+)/
    ];
    
    // ... implementation
  }

  private extractUnit(text: string, afterQuantity: string): ExtractionResult<UnitResult | null> {
    // Unit aliases (case-insensitive)
    const unitAliases: Record<string, StandardUnit> = {
      // Volume
      'teaspoon': 'tsp', 'teaspoons': 'tsp', 'tsp': 'tsp', 't': 'tsp',
      'tablespoon': 'tbsp', 'tablespoons': 'tbsp', 'tbsp': 'tbsp', 'tbs': 'tbsp', 'T': 'tbsp',
      'cup': 'cup', 'cups': 'cup', 'c': 'cup',
      'fluid ounce': 'fl_oz', 'fluid ounces': 'fl_oz', 'fl oz': 'fl_oz',
      'pint': 'pint', 'pints': 'pint', 'pt': 'pint',
      'quart': 'quart', 'quarts': 'quart', 'qt': 'quart',
      'gallon': 'gallon', 'gallons': 'gallon', 'gal': 'gallon',
      'milliliter': 'ml', 'milliliters': 'ml', 'ml': 'ml',
      'liter': 'l', 'liters': 'l', 'litre': 'l', 'litres': 'l', 'l': 'l',
      
      // Weight
      'ounce': 'oz', 'ounces': 'oz', 'oz': 'oz',
      'pound': 'lb', 'pounds': 'lb', 'lb': 'lb', 'lbs': 'lb',
      'gram': 'g', 'grams': 'g', 'g': 'g',
      'kilogram': 'kg', 'kilograms': 'kg', 'kg': 'kg',
      
      // Count
      'piece': 'piece', 'pieces': 'piece', 'pc': 'piece',
      'slice': 'slice', 'slices': 'slice',
      'clove': 'clove', 'cloves': 'clove',
      'sprig': 'sprig', 'sprigs': 'sprig',
      'bunch': 'bunch', 'bunches': 'bunch',
      
      // Special
      'pinch': 'pinch', 'pinches': 'pinch',
      'dash': 'dash', 'dashes': 'dash',
      'to taste': 'to_taste'
    };
    
    // ... implementation
  }
}
```

### 1.2.2 Unit Converter

**Purpose:** Convert between units while preserving readability

**Interface:**
```typescript
interface ConversionInput {
  value: number;
  fromUnit: StandardUnit;
  toUnit: StandardUnit;
  context?: ConversionContext;
}

interface ConversionContext {
  ingredient?: string;             // Some conversions are ingredient-specific
  preferFriendly: boolean;         // "1.5 cups" vs "355ml"
  locale?: Locale;
}

interface ConversionResult {
  value: number;                   // Precise value
  display: string;                 // Human-friendly display
  unit: StandardUnit;
  isExact: boolean;                // Some conversions are approximate
  conversionPath: string[];        // How we got there: ['cup', 'ml', 'l']
}

export class UnitConverter {
  private conversionTable: ConversionTable;
  private ingredientDensities: IngredientDensityMap;

  convert(input: ConversionInput): ConversionResult {
    const { value, fromUnit, toUnit, context } = input;
    
    // Same unit - no conversion needed
    if (fromUnit === toUnit) {
      return { value, display: this.format(value, toUnit), unit: toUnit, isExact: true, conversionPath: [] };
    }
    
    // Check if units are compatible
    const fromCategory = this.getCategory(fromUnit);
    const toCategory = this.getCategory(toUnit);
    
    if (fromCategory !== toCategory) {
      // Volume ↔ Weight requires ingredient density
      if (this.canConvertWithDensity(fromCategory, toCategory) && context?.ingredient) {
        return this.convertWithDensity(value, fromUnit, toUnit, context.ingredient);
      }
      throw new ConversionError(`Cannot convert ${fromUnit} to ${toUnit}`);
    }
    
    // Standard conversion
    return this.standardConvert(value, fromUnit, toUnit, context);
  }

  private standardConvert(value: number, from: StandardUnit, to: StandardUnit, context?: ConversionContext): ConversionResult {
    // Convert to base unit, then to target
    const baseUnit = this.getBaseUnit(from);
    const toBase = value * this.conversionTable[from][baseUnit];
    const result = toBase * this.conversionTable[baseUnit][to];
    
    return {
      value: result,
      display: this.format(result, to, context?.preferFriendly ?? true),
      unit: to,
      isExact: this.isExactConversion(from, to),
      conversionPath: [from, baseUnit, to].filter((u, i, arr) => arr.indexOf(u) === i)
    };
  }

  // Format for human readability
  private format(value: number, unit: StandardUnit, friendly: boolean = true): string {
    if (!friendly) {
      return `${value.toFixed(2)} ${unit}`;
    }
    
    // Convert to friendly fractions for cooking
    if (this.shouldUseFraction(unit)) {
      return `${this.toFraction(value)} ${this.pluralize(unit, value)}`;
    }
    
    // Round nicely
    const rounded = this.roundNicely(value);
    return `${rounded} ${this.pluralize(unit, rounded)}`;
  }

  private toFraction(value: number): string {
    // Common cooking fractions
    const fractions: [number, string][] = [
      [0.125, '⅛'], [0.25, '¼'], [0.333, '⅓'], [0.375, '⅜'],
      [0.5, '½'], [0.625, '⅝'], [0.666, '⅔'], [0.75, '¾'], [0.875, '⅞']
    ];
    
    const whole = Math.floor(value);
    const decimal = value - whole;
    
    if (decimal < 0.0625) {
      return whole.toString();
    }
    
    // Find closest fraction
    const closest = fractions.reduce((prev, curr) => 
      Math.abs(curr[0] - decimal) < Math.abs(prev[0] - decimal) ? curr : prev
    );
    
    if (whole === 0) {
      return closest[1];
    }
    return `${whole} ${closest[1]}`;
  }
}

// Conversion table (to base unit)
const VOLUME_TO_ML: Record<string, number> = {
  'tsp': 4.929,
  'tbsp': 14.787,
  'cup': 236.588,
  'fl_oz': 29.574,
  'pint': 473.176,
  'quart': 946.353,
  'gallon': 3785.41,
  'ml': 1,
  'l': 1000
};

const WEIGHT_TO_G: Record<string, number> = {
  'oz': 28.3495,
  'lb': 453.592,
  'g': 1,
  'kg': 1000
};

// Ingredient densities (g per cup) for volume ↔ weight
const INGREDIENT_DENSITIES: Record<string, number> = {
  'flour_all_purpose': 125,
  'flour_bread': 127,
  'flour_cake': 114,
  'sugar_granulated': 200,
  'sugar_brown': 220,
  'sugar_powdered': 120,
  'butter': 227,
  'milk': 245,
  'water': 237,
  'honey': 340,
  'oil_vegetable': 218,
  'rice_uncooked': 185,
  'oats': 80,
  'cocoa_powder': 85,
  'salt_table': 292,
  'salt_kosher': 138
};
```

### 1.2.3 Scaling Engine

**Purpose:** Scale recipe quantities while maintaining readability

**Interface:**
```typescript
interface ScalingInput {
  ingredients: ParsedIngredient[];
  originalServings: number;
  targetServings: number;
  scalingMode: ScalingMode;
}

type ScalingMode = 
  | 'linear'           // Simple multiplication
  | 'smart'            // Adjusts for cooking physics
  | 'baking';          // Special rules for baking

interface ScaledIngredient extends ParsedIngredient {
  scaledQuantity: QuantityResult;
  scaleFactor: number;
  wasAdjusted: boolean;           // True if smart scaling modified
  adjustmentReason?: string;
}

interface ScalingResult {
  ingredients: ScaledIngredient[];
  scaleFactor: number;
  warnings: ScalingWarning[];
  servings: number;
}

interface ScalingWarning {
  type: 'timing' | 'technique' | 'equipment' | 'ingredient';
  message: string;
  severity: 'info' | 'warning' | 'critical';
}

export class ScalingEngine {
  private parser: IngredientParser;
  private converter: UnitConverter;

  scale(input: ScalingInput): ScalingResult {
    const { ingredients, originalServings, targetServings, scalingMode } = input;
    const scaleFactor = targetServings / originalServings;
    
    const warnings: ScalingWarning[] = [];
    
    // Check for scaling issues
    if (scaleFactor > 4) {
      warnings.push({
        type: 'technique',
        message: 'Scaling up 4x+ may require technique adjustments. Consider batch cooking.',
        severity: 'warning'
      });
    }
    
    if (scaleFactor < 0.25 && scalingMode === 'baking') {
      warnings.push({
        type: 'technique',
        message: 'Scaling down below ¼ is unreliable for baking. Minimum batch recommended.',
        severity: 'critical'
      });
    }
    
    const scaledIngredients = ingredients.map(ing => 
      this.scaleIngredient(ing, scaleFactor, scalingMode, warnings)
    );
    
    return {
      ingredients: scaledIngredients,
      scaleFactor,
      warnings,
      servings: targetServings
    };
  }

  private scaleIngredient(
    ingredient: ParsedIngredient,
    scaleFactor: number,
    mode: ScalingMode,
    warnings: ScalingWarning[]
  ): ScaledIngredient {
    const { quantity, unit, ingredientNormalized } = ingredient;
    
    // Non-scalable ingredients
    if (this.isNonScalable(ingredientNormalized)) {
      return {
        ...ingredient,
        scaledQuantity: quantity,
        scaleFactor: 1,
        wasAdjusted: true,
        adjustmentReason: 'This ingredient does not scale linearly'
      };
    }
    
    // Apply smart scaling rules
    let adjustedFactor = scaleFactor;
    let adjustmentReason: string | undefined;
    
    if (mode === 'smart' || mode === 'baking') {
      const adjustment = this.getSmartAdjustment(ingredientNormalized, scaleFactor);
      if (adjustment) {
        adjustedFactor = scaleFactor * adjustment.multiplier;
        adjustmentReason = adjustment.reason;
      }
    }
    
    // Calculate new quantity
    const newValue = quantity.value * adjustedFactor;
    
    // Convert to friendly unit if needed
    const friendlyResult = this.convertToFriendlyUnit(newValue, unit);
    
    return {
      ...ingredient,
      scaledQuantity: {
        value: friendlyResult.value,
        display: friendlyResult.display,
        isRange: quantity.isRange,
        isApproximate: quantity.isApproximate
      },
      scaleFactor: adjustedFactor,
      wasAdjusted: adjustedFactor !== scaleFactor,
      adjustmentReason
    };
  }

  private isNonScalable(ingredient: string): boolean {
    // These ingredients don't scale linearly
    const nonScalable = [
      'yeast', 'baking_soda', 'baking_powder',  // Leaveners
      'vanilla_extract', 'almond_extract',       // Extracts (diminishing returns)
      'salt',                                    // Needs taste adjustment
    ];
    return nonScalable.includes(ingredient);
  }

  private getSmartAdjustment(ingredient: string, scaleFactor: number): { multiplier: number; reason: string } | null {
    // Leaveners don't scale linearly
    if (['yeast', 'baking_soda', 'baking_powder'].includes(ingredient)) {
      if (scaleFactor > 2) {
        // Use square root scaling for large batches
        return {
          multiplier: Math.sqrt(scaleFactor) / scaleFactor,
          reason: 'Leaveners adjusted - they don\'t scale linearly for large batches'
        };
      }
    }
    
    // Salt scales at ~75% for large batches
    if (ingredient === 'salt' && scaleFactor > 2) {
      return {
        multiplier: 0.75,
        reason: 'Salt reduced - larger batches need proportionally less salt'
      };
    }
    
    return null;
  }

  private convertToFriendlyUnit(value: number, unit: UnitResult | null): { value: number; display: string } {
    if (!unit) {
      return { value, display: this.formatQuantity(value) };
    }
    
    // Convert to more appropriate unit for readability
    // e.g., 48 tsp → 1 cup, 0.25 cup → 4 tbsp
    const conversions: Record<string, { threshold: number; toUnit: StandardUnit; factor: number }[]> = {
      'tsp': [
        { threshold: 3, toUnit: 'tbsp', factor: 1/3 },
        { threshold: 48, toUnit: 'cup', factor: 1/48 }
      ],
      'tbsp': [
        { threshold: 0.33, toUnit: 'tsp', factor: 3 },
        { threshold: 16, toUnit: 'cup', factor: 1/16 }
      ],
      'cup': [
        { threshold: 0.25, toUnit: 'tbsp', factor: 16 },
        { threshold: 4, toUnit: 'quart', factor: 1/4 }
      ],
      'ml': [
        { threshold: 1000, toUnit: 'l', factor: 1/1000 }
      ],
      'g': [
        { threshold: 1000, toUnit: 'kg', factor: 1/1000 }
      ]
    };
    
    const unitConversions = conversions[unit.unit];
    if (unitConversions) {
      for (const conv of unitConversions) {
        if (value >= conv.threshold) {
          const converted = value * conv.factor;
          return {
            value: converted,
            display: `${this.formatQuantity(converted)} ${conv.toUnit}`
          };
        }
      }
    }
    
    return {
      value,
      display: `${this.formatQuantity(value)} ${unit.unit}`
    };
  }
}
```

### 1.2.4 Shopping List Aggregator

**Purpose:** Combine ingredients across recipes, merging like items

**Interface:**
```typescript
interface AggregationInput {
  recipes: RecipeShoppingItem[];
  userPreferences: AggregationPreferences;
}

interface RecipeShoppingItem {
  recipeId: string;
  recipeName: string;
  servings: number;
  ingredients: ParsedIngredient[];
}

interface AggregationPreferences {
  preferredUnits: 'imperial' | 'metric' | 'original';
  groupByCategory: boolean;
  separateByRecipe: boolean;
  excludeStaples: boolean;
  staplesList?: string[];
}

interface AggregatedShoppingList {
  items: ShoppingListItem[];
  byCategory: Map<GroceryCategory, ShoppingListItem[]>;
  byRecipe: Map<string, ShoppingListItem[]>;
  totals: {
    itemCount: number;
    recipeCount: number;
    estimatedCost?: number;
  };
}

interface ShoppingListItem {
  id: string;
  ingredient: string;
  ingredientNormalized: string;
  
  // Aggregated quantity
  totalQuantity: AggregatedQuantity;
  
  // Source tracking
  sources: IngredientSource[];
  
  // Shopping metadata
  category: GroceryCategory;
  isChecked: boolean;
  notes: string[];
}

interface AggregatedQuantity {
  value: number;
  unit: StandardUnit | null;
  display: string;
  
  // When units couldn't be combined
  hasMultipleUnits: boolean;
  breakdown?: { value: number; unit: StandardUnit; display: string }[];
}

interface IngredientSource {
  recipeId: string;
  recipeName: string;
  originalQuantity: QuantityResult;
  originalUnit: UnitResult | null;
  scaledServings: number;
}

type GroceryCategory = 
  | 'produce'
  | 'dairy'
  | 'meat_seafood'
  | 'bakery'
  | 'frozen'
  | 'pantry'
  | 'spices'
  | 'beverages'
  | 'other';

export class ShoppingListAggregator {
  private parser: IngredientParser;
  private converter: UnitConverter;
  private categorizer: IngredientCategorizer;

  aggregate(input: AggregationInput): AggregatedShoppingList {
    const { recipes, userPreferences } = input;
    
    // Step 1: Flatten all ingredients with source tracking
    const allIngredients = this.flattenWithSources(recipes);
    
    // Step 2: Group by normalized ingredient name
    const grouped = this.groupByIngredient(allIngredients);
    
    // Step 3: Aggregate quantities within each group
    const items = Array.from(grouped.entries()).map(([ingredient, sources]) =>
      this.aggregateGroup(ingredient, sources, userPreferences)
    );
    
    // Step 4: Filter staples if requested
    const filteredItems = userPreferences.excludeStaples
      ? items.filter(item => !this.isStaple(item.ingredientNormalized, userPreferences.staplesList))
      : items;
    
    // Step 5: Categorize
    const byCategory = this.categorizeItems(filteredItems);
    
    // Step 6: Group by recipe (for reference)
    const byRecipe = this.groupByRecipe(filteredItems);
    
    return {
      items: filteredItems,
      byCategory,
      byRecipe,
      totals: {
        itemCount: filteredItems.length,
        recipeCount: recipes.length
      }
    };
  }

  private aggregateGroup(
    ingredient: string,
    sources: IngredientWithSource[],
    prefs: AggregationPreferences
  ): ShoppingListItem {
    // Try to combine all quantities
    const { canCombine, combined, breakdown } = this.combineQuantities(sources, prefs);
    
    return {
      id: this.generateId(ingredient),
      ingredient: sources[0].ingredient.ingredient,
      ingredientNormalized: ingredient,
      totalQuantity: {
        value: combined.value,
        unit: combined.unit,
        display: combined.display,
        hasMultipleUnits: !canCombine,
        breakdown: canCombine ? undefined : breakdown
      },
      sources: sources.map(s => ({
        recipeId: s.recipeId,
        recipeName: s.recipeName,
        originalQuantity: s.ingredient.quantity,
        originalUnit: s.ingredient.unit,
        scaledServings: s.servings
      })),
      category: this.categorizer.categorize(ingredient),
      isChecked: false,
      notes: this.collectNotes(sources)
    };
  }

  private combineQuantities(
    sources: IngredientWithSource[],
    prefs: AggregationPreferences
  ): CombineResult {
    // Group by unit category (volume, weight, count)
    const byCategory = new Map<UnitCategory | 'none', IngredientWithSource[]>();
    
    for (const source of sources) {
      const category = source.ingredient.unit?.category ?? 'none';
      if (!byCategory.has(category)) {
        byCategory.set(category, []);
      }
      byCategory.get(category)!.push(source);
    }
    
    // If all same category, combine
    if (byCategory.size === 1) {
      const [category, items] = Array.from(byCategory.entries())[0];
      return this.combineWithinCategory(items, category, prefs);
    }
    
    // Multiple categories - provide breakdown
    const breakdown: { value: number; unit: StandardUnit; display: string }[] = [];
    
    for (const [category, items] of byCategory) {
      const combined = this.combineWithinCategory(items, category, prefs);
      if (combined.combined.unit) {
        breakdown.push({
          value: combined.combined.value,
          unit: combined.combined.unit,
          display: combined.combined.display
        });
      }
    }
    
    // Return the largest quantity as primary
    const primary = breakdown.sort((a, b) => b.value - a.value)[0];
    
    return {
      canCombine: false,
      combined: {
        value: primary.value,
        unit: primary.unit,
        display: breakdown.map(b => b.display).join(' + ')
      },
      breakdown
    };
  }

  private combineWithinCategory(
    items: IngredientWithSource[],
    category: UnitCategory | 'none',
    prefs: AggregationPreferences
  ): CombineResult {
    if (category === 'none') {
      // Count-based (no units) - just sum
      const total = items.reduce((sum, item) => sum + item.ingredient.quantity.value, 0);
      return {
        canCombine: true,
        combined: {
          value: total,
          unit: null,
          display: total.toString()
        }
      };
    }
    
    // Convert all to preferred unit
    const targetUnit = this.getTargetUnit(category, prefs);
    
    let total = 0;
    for (const item of items) {
      if (item.ingredient.unit) {
        const converted = this.converter.convert({
          value: item.ingredient.quantity.value,
          fromUnit: item.ingredient.unit.unit,
          toUnit: targetUnit
        });
        total += converted.value;
      } else {
        total += item.ingredient.quantity.value;
      }
    }
    
    // Format nicely
    const display = this.formatCombined(total, targetUnit);
    
    return {
      canCombine: true,
      combined: {
        value: total,
        unit: targetUnit,
        display
      }
    };
  }
}

// Ingredient categorization for grocery sections
const INGREDIENT_CATEGORIES: Record<string, GroceryCategory> = {
  // Produce
  'apple': 'produce', 'banana': 'produce', 'lettuce': 'produce', 'tomato': 'produce',
  'onion': 'produce', 'garlic': 'produce', 'potato': 'produce', 'carrot': 'produce',
  'celery': 'produce', 'lemon': 'produce', 'lime': 'produce', 'avocado': 'produce',
  
  // Dairy
  'milk': 'dairy', 'butter': 'dairy', 'cheese': 'dairy', 'cream': 'dairy',
  'yogurt': 'dairy', 'egg': 'dairy', 'sour_cream': 'dairy',
  
  // Meat & Seafood
  'chicken': 'meat_seafood', 'beef': 'meat_seafood', 'pork': 'meat_seafood',
  'salmon': 'meat_seafood', 'shrimp': 'meat_seafood', 'bacon': 'meat_seafood',
  
  // Pantry
  'flour': 'pantry', 'sugar': 'pantry', 'rice': 'pantry', 'pasta': 'pantry',
  'oil': 'pantry', 'vinegar': 'pantry', 'soy_sauce': 'pantry',
  
  // Spices
  'salt': 'spices', 'pepper': 'spices', 'cinnamon': 'spices', 'cumin': 'spices',
  'oregano': 'spices', 'basil': 'spices', 'thyme': 'spices',
  
  // Bakery
  'bread': 'bakery', 'tortilla': 'bakery', 'pita': 'bakery',
  
  // Frozen
  'ice_cream': 'frozen', 'frozen_vegetables': 'frozen'
};
```

### 1.2.5 Timer Detector

**Purpose:** Extract cooking timers from instruction text

**Interface:**
```typescript
interface TimerDetectionInput {
  instructions: string[];
  stepNumbers?: number[];       // Optional step numbering
}

interface DetectedTimer {
  id: string;
  label: string;                // "Bake until golden"
  duration: TimerDuration;
  stepNumber: number;
  instructionSnippet: string;   // Context from instruction
  timerType: TimerType;
  isRange: boolean;
  confidence: number;
}

interface TimerDuration {
  seconds: number;
  display: string;              // "30 minutes"
  rangeMin?: number;
  rangeMax?: number;
}

type TimerType = 
  | 'cooking'      // Active cooking (bake, boil, fry)
  | 'resting'      // Passive waiting (let rise, cool)
  | 'marinating'   // Extended passive (marinate overnight)
  | 'prep';        // Preparation time

export class TimerDetector {
  private patterns: TimerPattern[];

  detect(input: TimerDetectionInput): DetectedTimer[] {
    const { instructions, stepNumbers } = input;
    const timers: DetectedTimer[] = [];
    
    for (let i = 0; i < instructions.length; i++) {
      const instruction = instructions[i];
      const stepNum = stepNumbers?.[i] ?? i + 1;
      
      const detected = this.detectInInstruction(instruction, stepNum);
      timers.push(...detected);
    }
    
    return timers;
  }

  private detectInInstruction(instruction: string, stepNumber: number): DetectedTimer[] {
    const timers: DetectedTimer[] = [];
    
    for (const pattern of this.patterns) {
      const matches = instruction.matchAll(pattern.regex);
      
      for (const match of matches) {
        const duration = this.parseDuration(match, pattern);
        if (duration) {
          timers.push({
            id: this.generateId(),
            label: this.extractLabel(instruction, match),
            duration,
            stepNumber,
            instructionSnippet: this.extractSnippet(instruction, match.index ?? 0),
            timerType: pattern.type,
            isRange: duration.rangeMin !== undefined,
            confidence: pattern.confidence
          });
        }
      }
    }
    
    return timers;
  }

  private patterns: TimerPattern[] = [
    // "bake for 30 minutes"
    {
      regex: /(?:bake|roast|cook|simmer|boil|fry|sauté|grill|broil)\s+(?:for\s+)?(\d+)\s*(minutes?|mins?|hours?|hrs?|seconds?|secs?)/gi,
      type: 'cooking',
      confidence: 0.95
    },
    // "let rest for 10 minutes"
    {
      regex: /(?:let\s+)?(?:rest|cool|stand|sit)\s+(?:for\s+)?(\d+)\s*(minutes?|mins?|hours?)/gi,
      type: 'resting',
      confidence: 0.90
    },
    // "marinate for 2 hours" or "marinate overnight"
    {
      regex: /marinate\s+(?:for\s+)?(?:(\d+)\s*(minutes?|hours?)|overnight)/gi,
      type: 'marinating',
      confidence: 0.85
    },
    // "until golden, about 20 minutes"
    {
      regex: /(?:about|approximately|around)\s+(\d+)\s*(minutes?|mins?|hours?)/gi,
      type: 'cooking',
      confidence: 0.75
    },
    // "10-15 minutes" (range)
    {
      regex: /(\d+)\s*[-–to]\s*(\d+)\s*(minutes?|mins?|hours?)/gi,
      type: 'cooking',
      confidence: 0.85,
      isRange: true
    },
    // "20 minutes per side"
    {
      regex: /(\d+)\s*(minutes?|mins?)\s+(?:per|each)\s+side/gi,
      type: 'cooking',
      confidence: 0.90,
      multiplier: 2  // Assumes 2 sides
    }
  ];

  private parseDuration(match: RegExpMatchArray, pattern: TimerPattern): TimerDuration | null {
    if (pattern.isRange && match[2]) {
      const min = parseInt(match[1]);
      const max = parseInt(match[2]);
      const unit = match[3];
      
      const minSeconds = this.toSeconds(min, unit);
      const maxSeconds = this.toSeconds(max, unit);
      
      return {
        seconds: minSeconds,  // Default to minimum
        display: `${min}-${max} ${unit}`,
        rangeMin: minSeconds,
        rangeMax: maxSeconds
      };
    }
    
    const value = parseInt(match[1]);
    const unit = match[2] || 'minutes';
    let seconds = this.toSeconds(value, unit);
    
    if (pattern.multiplier) {
      seconds *= pattern.multiplier;
    }
    
    return {
      seconds,
      display: `${value} ${unit}`
    };
  }

  private toSeconds(value: number, unit: string): number {
    const normalized = unit.toLowerCase().replace(/s$/, '');
    switch (normalized) {
      case 'second':
      case 'sec':
        return value;
      case 'minute':
      case 'min':
        return value * 60;
      case 'hour':
      case 'hr':
        return value * 3600;
      default:
        return value * 60; // Default to minutes
    }
  }
}
```

## 1.3 Package Structure

```
packages/
├── @heirloom/core-types/           # Shared type definitions
│   ├── src/
│   │   ├── ingredient.ts           # Ingredient types
│   │   ├── unit.ts                 # Unit types
│   │   ├── recipe.ts               # Recipe types
│   │   ├── shopping.ts             # Shopping list types
│   │   ├── timer.ts                # Timer types
│   │   ├── lineage.ts              # Lineage types
│   │   └── index.ts
│   └── package.json
│
├── @heirloom/ingredient-parser/    # Ingredient parsing
│   ├── src/
│   │   ├── parser.ts               # Main parser class
│   │   ├── patterns.ts             # Regex patterns
│   │   ├── normalizer.ts           # Ingredient name normalization
│   │   └── index.ts
│   ├── __tests__/
│   │   ├── parser.test.ts
│   │   ├── fixtures/
│   │   │   ├── basic.json
│   │   │   ├── fractions.json
│   │   │   ├── ranges.json
│   │   │   └── edge-cases.json
│   └── package.json
│
├── @heirloom/unit-converter/       # Unit conversion
│   ├── src/
│   │   ├── converter.ts
│   │   ├── tables.ts               # Conversion tables
│   │   ├── densities.ts            # Ingredient densities
│   │   └── formatter.ts            # Friendly formatting
│   ├── __tests__/
│   └── package.json
│
├── @heirloom/scaling-engine/       # Recipe scaling
│   ├── src/
│   │   ├── engine.ts
│   │   ├── rules.ts                # Smart scaling rules
│   │   └── warnings.ts
│   ├── __tests__/
│   └── package.json
│
├── @heirloom/timer-detector/       # Timer extraction
│   ├── src/
│   │   ├── detector.ts
│   │   └── patterns.ts
│   ├── __tests__/
│   └── package.json
│
├── @heirloom/shopping-aggregator/  # Shopping list
│   ├── src/
│   │   ├── aggregator.ts
│   │   ├── categorizer.ts
│   │   └── staples.ts
│   ├── __tests__/
│   └── package.json
│
└── @heirloom/core/                 # Unified export
    ├── src/
    │   └── index.ts
    └── package.json
```

## 1.4 iOS Integration

Since Heirloom is SwiftUI-native, the TypeScript core needs to be bridged:

**Option A: JavaScriptCore (Recommended for Heirloom)**
```swift
// Heirloom/Core/Bridge/HeirloomCoreBridge.swift

import JavaScriptCore

@MainActor
class HeirloomCoreBridge: ObservableObject {
    static let shared = HeirloomCoreBridge()
    
    private var jsContext: JSContext
    private var ingredientParser: JSValue
    private var unitConverter: JSValue
    private var scalingEngine: JSValue
    private var shoppingAggregator: JSValue
    private var timerDetector: JSValue
    
    init() {
        jsContext = JSContext()
        
        // Load bundled core
        guard let corePath = Bundle.main.path(forResource: "heirloom-core", ofType: "js"),
              let coreCode = try? String(contentsOfFile: corePath) else {
            fatalError("Heirloom core bundle not found")
        }
        
        jsContext.evaluateScript(coreCode)
        
        // Get module references
        ingredientParser = jsContext.objectForKeyedSubscript("IngredientParser")
        unitConverter = jsContext.objectForKeyedSubscript("UnitConverter")
        scalingEngine = jsContext.objectForKeyedSubscript("ScalingEngine")
        shoppingAggregator = jsContext.objectForKeyedSubscript("ShoppingAggregator")
        timerDetector = jsContext.objectForKeyedSubscript("TimerDetector")
    }
    
    // MARK: - Ingredient Parsing
    
    func parseIngredient(_ text: String) -> ParsedIngredient? {
        let input = ["text": text]
        guard let inputJSON = try? JSONSerialization.data(withJSONObject: input),
              let inputString = String(data: inputJSON, encoding: .utf8) else {
            return nil
        }
        
        let result = ingredientParser.invokeMethod("parse", withArguments: [inputString])
        
        guard let resultString = result?.toString(),
              let resultData = resultString.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(ParsedIngredient.self, from: resultData) else {
            return nil
        }
        
        return parsed
    }
    
    // MARK: - Shopping List Aggregation
    
    func aggregateShoppingList(recipes: [RecipeShoppingItem], preferences: AggregationPreferences) -> AggregatedShoppingList? {
        let input = AggregationInput(recipes: recipes, userPreferences: preferences)
        
        guard let inputData = try? JSONEncoder().encode(input),
              let inputString = String(data: inputData, encoding: .utf8) else {
            return nil
        }
        
        let result = shoppingAggregator.invokeMethod("aggregate", withArguments: [inputString])
        
        guard let resultString = result?.toString(),
              let resultData = resultString.data(using: .utf8),
              let aggregated = try? JSONDecoder().decode(AggregatedShoppingList.self, from: resultData) else {
            return nil
        }
        
        return aggregated
    }
}
```

**Option B: Keep Swift Implementation, Use TS for Web/Future Platforms**

Given that Heirloom is iOS-native and working well, an alternative approach:

1. **Keep Swift implementations for iOS** — They're already built and tested
2. **Use TypeScript shared core for future platforms** — Web, Android
3. **Maintain test fixtures in JSON** — Both Swift and TS implementations must pass

This is more pragmatic for beta timeline.

---

# 2. Test Harness Architecture

## 2.1 Testing Philosophy for Heirloom

Heirloom's core intelligence is deterministic (parsing, conversion, aggregation) unlike Zero's probabilistic intent classification. This means tests can be more precise.

```
┌─────────────────────────────────────────────────────────────────┐
│                    HEIRLOOM TEST PYRAMID                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                        ┌─────┐                                  │
│                       /  E2E  \          5% - Import-to-shop    │
│                      /─────────\                                │
│                     / Integration\       25% - Multi-module     │
│                    /───────────────\                            │
│                   /      Unit       \    70% - Parser/converter │
│                  /───────────────────\                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2.2 Test Categories

### 2.2.1 Ingredient Parser Tests

```typescript
// packages/@heirloom/ingredient-parser/__tests__/fixtures/comprehensive.json

{
  "basic": [
    {
      "id": "basic-001",
      "input": "2 cups flour",
      "expected": {
        "quantity": { "value": 2, "display": "2" },
        "unit": { "unit": "cup", "category": "volume" },
        "ingredient": "flour",
        "ingredientNormalized": "flour"
      }
    },
    {
      "id": "basic-002",
      "input": "1 large egg",
      "expected": {
        "quantity": { "value": 1, "display": "1" },
        "unit": { "unit": "piece", "category": "count" },
        "ingredient": "large egg",
        "ingredientNormalized": "egg"
      }
    }
  ],
  
  "fractions": [
    {
      "id": "frac-001",
      "input": "1/2 cup sugar",
      "expected": {
        "quantity": { "value": 0.5, "display": "½" }
      }
    },
    {
      "id": "frac-002",
      "input": "2 1/2 cups milk",
      "expected": {
        "quantity": { "value": 2.5, "display": "2½" }
      }
    },
    {
      "id": "frac-003",
      "input": "¾ teaspoon salt",
      "expected": {
        "quantity": { "value": 0.75, "display": "¾" }
      }
    }
  ],
  
  "ranges": [
    {
      "id": "range-001",
      "input": "1-2 cups chicken broth",
      "expected": {
        "quantity": {
          "value": 1,
          "isRange": true,
          "rangeMin": 1,
          "rangeMax": 2
        }
      }
    },
    {
      "id": "range-002",
      "input": "3 to 4 tablespoons olive oil",
      "expected": {
        "quantity": {
          "isRange": true,
          "rangeMin": 3,
          "rangeMax": 4
        }
      }
    }
  ],
  
  "complex": [
    {
      "id": "complex-001",
      "input": "2 cups all-purpose flour, sifted",
      "expected": {
        "ingredient": "all-purpose flour",
        "preparation": "sifted"
      }
    },
    {
      "id": "complex-002",
      "input": "1 pound boneless, skinless chicken breast, cut into 1-inch pieces",
      "expected": {
        "quantity": { "value": 1 },
        "unit": { "unit": "lb" },
        "ingredient": "boneless, skinless chicken breast",
        "preparation": "cut into 1-inch pieces"
      }
    },
    {
      "id": "complex-003",
      "input": "2 cloves garlic, minced (about 1 tablespoon)",
      "expected": {
        "quantity": { "value": 2 },
        "unit": { "unit": "clove" },
        "ingredient": "garlic",
        "preparation": "minced",
        "notes": "about 1 tablespoon"
      }
    }
  ],
  
  "edge_cases": [
    {
      "id": "edge-001",
      "input": "salt to taste",
      "expected": {
        "unit": { "unit": "to_taste" },
        "ingredient": "salt"
      }
    },
    {
      "id": "edge-002",
      "input": "pinch of cayenne pepper",
      "expected": {
        "unit": { "unit": "pinch" },
        "ingredient": "cayenne pepper"
      }
    },
    {
      "id": "edge-003",
      "input": "freshly ground black pepper",
      "expected": {
        "ingredient": "black pepper",
        "preparation": "freshly ground",
        "quantity": null  // No quantity specified
      }
    },
    {
      "id": "edge-004",
      "input": "1 (14.5 oz) can diced tomatoes",
      "expected": {
        "quantity": { "value": 1 },
        "unit": { "unit": "piece" },
        "ingredient": "can diced tomatoes",
        "notes": "14.5 oz"
      }
    },
    {
      "id": "edge-005",
      "input": "~2 cups water",
      "expected": {
        "quantity": { "value": 2, "isApproximate": true }
      }
    }
  ],
  
  "international": [
    {
      "id": "intl-001",
      "input": "500ml milk",
      "expected": {
        "quantity": { "value": 500 },
        "unit": { "unit": "ml" }
      }
    },
    {
      "id": "intl-002",
      "input": "250g butter",
      "expected": {
        "quantity": { "value": 250 },
        "unit": { "unit": "g" }
      }
    }
  ]
}
```

### 2.2.2 Unit Conversion Tests

```typescript
// packages/@heirloom/unit-converter/__tests__/fixtures/conversions.json

{
  "volume_imperial": [
    {
      "id": "vol-imp-001",
      "from": { "value": 1, "unit": "cup" },
      "to": "tbsp",
      "expected": { "value": 16, "isExact": true }
    },
    {
      "id": "vol-imp-002",
      "from": { "value": 3, "unit": "tsp" },
      "to": "tbsp",
      "expected": { "value": 1, "isExact": true }
    },
    {
      "id": "vol-imp-003",
      "from": { "value": 4, "unit": "cup" },
      "to": "quart",
      "expected": { "value": 1, "isExact": true }
    }
  ],
  
  "volume_metric": [
    {
      "id": "vol-met-001",
      "from": { "value": 1000, "unit": "ml" },
      "to": "l",
      "expected": { "value": 1, "isExact": true }
    },
    {
      "id": "vol-met-002",
      "from": { "value": 1, "unit": "cup" },
      "to": "ml",
      "expected": { "value": 236.588, "tolerance": 0.5 }
    }
  ],
  
  "weight": [
    {
      "id": "weight-001",
      "from": { "value": 1, "unit": "lb" },
      "to": "oz",
      "expected": { "value": 16, "isExact": true }
    },
    {
      "id": "weight-002",
      "from": { "value": 1, "unit": "kg" },
      "to": "g",
      "expected": { "value": 1000, "isExact": true }
    },
    {
      "id": "weight-003",
      "from": { "value": 1, "unit": "oz" },
      "to": "g",
      "expected": { "value": 28.35, "tolerance": 0.01 }
    }
  ],
  
  "volume_to_weight": [
    {
      "id": "v2w-001",
      "from": { "value": 1, "unit": "cup" },
      "to": "g",
      "ingredient": "flour_all_purpose",
      "expected": { "value": 125, "tolerance": 5 }
    },
    {
      "id": "v2w-002",
      "from": { "value": 1, "unit": "cup" },
      "to": "g",
      "ingredient": "sugar_granulated",
      "expected": { "value": 200, "tolerance": 5 }
    },
    {
      "id": "v2w-003",
      "from": { "value": 1, "unit": "cup" },
      "to": "g",
      "ingredient": "butter",
      "expected": { "value": 227, "tolerance": 5 }
    }
  ],
  
  "friendly_formatting": [
    {
      "id": "friendly-001",
      "input": { "value": 0.5, "unit": "cup" },
      "expected_display": "½ cup"
    },
    {
      "id": "friendly-002",
      "input": { "value": 1.5, "unit": "cup" },
      "expected_display": "1½ cups"
    },
    {
      "id": "friendly-003",
      "input": { "value": 0.333, "unit": "cup" },
      "expected_display": "⅓ cup"
    },
    {
      "id": "friendly-004",
      "input": { "value": 48, "unit": "tsp" },
      "expected_display": "1 cup",
      "note": "Auto-converts to larger unit"
    }
  ]
}
```

### 2.2.3 Shopping List Aggregation Tests

```typescript
// packages/@heirloom/shopping-aggregator/__tests__/fixtures/aggregation.json

{
  "basic_combination": [
    {
      "id": "agg-001",
      "name": "Same ingredient, same unit",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "2 cups flour" },
        { "recipe": "Recipe B", "ingredient": "1 cup flour" }
      ],
      "expected": {
        "ingredient": "flour",
        "totalQuantity": { "value": 3, "unit": "cup", "display": "3 cups" }
      }
    },
    {
      "id": "agg-002",
      "name": "Same ingredient, different units (same category)",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "2 cups milk" },
        { "recipe": "Recipe B", "ingredient": "500 ml milk" }
      ],
      "expected": {
        "ingredient": "milk",
        "totalQuantity": {
          "display": "4 cups",
          "note": "2 cups + 500ml ≈ 2 cups + 2.1 cups"
        }
      }
    },
    {
      "id": "agg-003",
      "name": "Same ingredient, incompatible units",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "2 cups flour" },
        { "recipe": "Recipe B", "ingredient": "500g flour" }
      ],
      "expected": {
        "ingredient": "flour",
        "totalQuantity": {
          "hasMultipleUnits": true,
          "display": "2 cups + 500g",
          "note": "Volume and weight can't be combined without density"
        }
      }
    }
  ],
  
  "normalization": [
    {
      "id": "norm-001",
      "name": "Ingredient name variations",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "2 cups all-purpose flour" },
        { "recipe": "Recipe B", "ingredient": "1 cup AP flour" },
        { "recipe": "Recipe C", "ingredient": "1 cup plain flour" }
      ],
      "expected": {
        "ingredientNormalized": "flour_all_purpose",
        "totalQuantity": { "value": 4, "unit": "cup" }
      }
    },
    {
      "id": "norm-002",
      "name": "Size variations ignored",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "2 large eggs" },
        { "recipe": "Recipe B", "ingredient": "1 egg" }
      ],
      "expected": {
        "ingredientNormalized": "egg",
        "totalQuantity": { "value": 3 }
      }
    }
  ],
  
  "categorization": [
    {
      "id": "cat-001",
      "name": "Grocery category assignment",
      "inputs": [
        { "ingredient": "2 cups milk" },
        { "ingredient": "1 lb chicken breast" },
        { "ingredient": "3 tomatoes" },
        { "ingredient": "2 cups flour" },
        { "ingredient": "1 tsp salt" }
      ],
      "expected_categories": {
        "milk": "dairy",
        "chicken breast": "meat_seafood",
        "tomatoes": "produce",
        "flour": "pantry",
        "salt": "spices"
      }
    }
  ],
  
  "edge_cases": [
    {
      "id": "edge-001",
      "name": "No quantity ingredients",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "salt to taste" },
        { "recipe": "Recipe B", "ingredient": "salt to taste" }
      ],
      "expected": {
        "ingredient": "salt",
        "totalQuantity": { "display": "to taste" },
        "note": "Non-quantified ingredients don't aggregate"
      }
    },
    {
      "id": "edge-002",
      "name": "Range quantities",
      "inputs": [
        { "recipe": "Recipe A", "ingredient": "1-2 cups broth" },
        { "recipe": "Recipe B", "ingredient": "1 cup broth" }
      ],
      "expected": {
        "totalQuantity": {
          "isRange": true,
          "display": "2-3 cups"
        }
      }
    }
  ]
}
```

### 2.2.4 Timer Detection Tests

```typescript
// packages/@heirloom/timer-detector/__tests__/fixtures/timers.json

{
  "explicit_durations": [
    {
      "id": "timer-001",
      "instruction": "Bake for 30 minutes at 350°F.",
      "expected": [{
        "duration": { "seconds": 1800, "display": "30 minutes" },
        "timerType": "cooking",
        "confidence": 0.95
      }]
    },
    {
      "id": "timer-002",
      "instruction": "Simmer for 2 hours, stirring occasionally.",
      "expected": [{
        "duration": { "seconds": 7200, "display": "2 hours" },
        "timerType": "cooking"
      }]
    },
    {
      "id": "timer-003",
      "instruction": "Cook each side for 3 minutes.",
      "expected": [{
        "duration": { "seconds": 360, "display": "6 minutes" },
        "note": "3 min × 2 sides = 6 min total"
      }]
    }
  ],
  
  "ranges": [
    {
      "id": "range-001",
      "instruction": "Bake for 25-30 minutes until golden.",
      "expected": [{
        "duration": {
          "seconds": 1500,
          "rangeMin": 1500,
          "rangeMax": 1800,
          "display": "25-30 minutes"
        },
        "isRange": true
      }]
    }
  ],
  
  "resting": [
    {
      "id": "rest-001",
      "instruction": "Let rest for 10 minutes before slicing.",
      "expected": [{
        "timerType": "resting",
        "duration": { "seconds": 600 }
      }]
    },
    {
      "id": "rest-002",
      "instruction": "Allow to cool completely, about 1 hour.",
      "expected": [{
        "timerType": "resting",
        "duration": { "seconds": 3600 },
        "confidence": 0.75
      }]
    }
  ],
  
  "multiple_timers": [
    {
      "id": "multi-001",
      "instruction": "Sauté onions for 5 minutes, then add garlic and cook for 1 minute more.",
      "expected": [
        { "duration": { "seconds": 300 }, "label": "Sauté onions" },
        { "duration": { "seconds": 60 }, "label": "Cook garlic" }
      ]
    }
  ],
  
  "edge_cases": [
    {
      "id": "edge-001",
      "instruction": "Marinate overnight.",
      "expected": [{
        "timerType": "marinating",
        "duration": { "seconds": 28800, "display": "8 hours" },
        "note": "Overnight = ~8 hours"
      }]
    },
    {
      "id": "edge-002",
      "instruction": "Cook until internal temperature reaches 165°F.",
      "expected": [],
      "note": "No time specified - temperature-based"
    }
  ]
}
```

## 2.3 Test Runner

```typescript
// packages/@heirloom/test-harness/src/runner.ts

import { IngredientParser } from '@heirloom/ingredient-parser';
import { UnitConverter } from '@heirloom/unit-converter';
import { ScalingEngine } from '@heirloom/scaling-engine';
import { ShoppingListAggregator } from '@heirloom/shopping-aggregator';
import { TimerDetector } from '@heirloom/timer-detector';

interface TestConfig {
  modules: ('parser' | 'converter' | 'scaling' | 'shopping' | 'timers')[];
  fixtureDir: string;
  outputFormat: 'json' | 'junit' | 'pretty';
  verbose: boolean;
}

interface TestResult {
  module: string;
  fixture: string;
  testId: string;
  passed: boolean;
  expected: unknown;
  actual: unknown;
  diff?: string;
  latencyMs: number;
}

interface TestSummary {
  totalTests: number;
  passed: number;
  failed: number;
  passRate: number;
  byModule: Map<string, { passed: number; failed: number }>;
  failures: TestResult[];
  avgLatencyMs: number;
}

export class HeirloomTestRunner {
  private parser: IngredientParser;
  private converter: UnitConverter;
  private scaling: ScalingEngine;
  private shopping: ShoppingListAggregator;
  private timers: TimerDetector;

  constructor() {
    this.parser = new IngredientParser();
    this.converter = new UnitConverter();
    this.scaling = new ScalingEngine();
    this.shopping = new ShoppingListAggregator();
    this.timers = new TimerDetector();
  }

  async runSuite(config: TestConfig): Promise<TestSummary> {
    const results: TestResult[] = [];
    
    for (const module of config.modules) {
      const fixtures = await this.loadFixtures(config.fixtureDir, module);
      
      for (const fixture of fixtures) {
        const result = await this.runTest(module, fixture);
        results.push(result);
      }
    }
    
    return this.summarize(results);
  }

  private async runTest(module: string, fixture: TestFixture): Promise<TestResult> {
    const startTime = performance.now();
    
    try {
      let actual: unknown;
      
      switch (module) {
        case 'parser':
          actual = this.parser.parse({ text: fixture.input });
          break;
        case 'converter':
          actual = this.converter.convert(fixture.input);
          break;
        case 'scaling':
          actual = this.scaling.scale(fixture.input);
          break;
        case 'shopping':
          actual = this.shopping.aggregate(fixture.input);
          break;
        case 'timers':
          actual = this.timers.detect({ instructions: [fixture.input] });
          break;
      }
      
      const passed = this.compare(actual, fixture.expected, fixture.tolerance);
      
      return {
        module,
        fixture: fixture.name,
        testId: fixture.id,
        passed,
        expected: fixture.expected,
        actual,
        diff: passed ? undefined : this.generateDiff(fixture.expected, actual),
        latencyMs: performance.now() - startTime
      };
    } catch (error) {
      return {
        module,
        fixture: fixture.name,
        testId: fixture.id,
        passed: false,
        expected: fixture.expected,
        actual: { error: error.message },
        latencyMs: performance.now() - startTime
      };
    }
  }

  private compare(actual: unknown, expected: unknown, tolerance?: number): boolean {
    // Deep comparison with tolerance for numbers
    // ... implementation
  }
}
```

## 2.4 CI/CD Integration

```yaml
# .github/workflows/heirloom-tests.yml

name: Heirloom Core Tests

on:
  push:
    branches: [main, develop]
    paths:
      - 'packages/@heirloom/**'
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      matrix:
        module: [parser, converter, scaling, shopping, timers]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run ${{ matrix.module }} tests
        run: |
          npx heirloom-test run --module ${{ matrix.module }} --format junit > results-${{ matrix.module }}.xml
      
      - name: Upload test results
        uses: actions/upload-artifact@v4
        with:
          name: test-results-${{ matrix.module }}
          path: results-${{ matrix.module }}.xml

  accuracy-report:
    runs-on: ubuntu-latest
    needs: test
    
    steps:
      - name: Download all test results
        uses: actions/download-artifact@v4
      
      - name: Generate accuracy report
        run: |
          node scripts/generate-accuracy-report.js
      
      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const report = require('./accuracy-report.json');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Heirloom Core Test Results\n\n${report.summary}`
            });
```

---

# 3. Telemetry Schema

## 3.1 Key Metrics for Heirloom

Unlike Zero (where intent accuracy is critical), Heirloom's key metrics are:

| Category | Metric | Why It Matters |
|----------|--------|----------------|
| **Import** | URL import success rate | Core feature reliability |
| **Import** | Photo OCR success rate | Core feature reliability |
| **Parsing** | Ingredient parse accuracy | User trust |
| **Scaling** | Scaling usage rate | Feature adoption |
| **Shopping** | List generation rate | Feature adoption |
| **Sharing** | Share creation rate | Social feature health |
| **Sharing** | Share acceptance rate | Network growth |
| **Lineage** | Fork rate | Engagement signal |

## 3.2 Event Schema

### 3.2.1 Import Events

```typescript
// Recipe import tracking

interface RecipeImportStartedEvent {
  eventType: 'recipe_import_started';
  timestamp: Date;
  sessionId: string;
  userId: string;          // Anonymized
  
  importMethod: 'url' | 'photo' | 'manual';
  
  // For URL imports
  urlMetadata?: {
    domain: string;        // Recipe website domain
    hasStructuredData: boolean;  // Schema.org markup
  };
  
  // For photo imports
  photoMetadata?: {
    source: 'camera' | 'library';
    imageSize: { width: number; height: number };
  };
}

interface RecipeImportCompletedEvent {
  eventType: 'recipe_import_completed';
  timestamp: Date;
  importEventId: string;   // Links to started event
  
  success: boolean;
  
  // On success
  result?: {
    ingredientCount: number;
    instructionCount: number;
    hasImage: boolean;
    parsedFields: string[];  // ['title', 'servings', 'prepTime', etc.]
  };
  
  // On failure
  error?: {
    stage: 'fetch' | 'parse' | 'extract' | 'save';
    errorCode: string;
    errorMessage: string;
  };
  
  // Performance
  durationMs: number;
  aiCallCount: number;      // Number of GPT-4 calls
}

interface RecipeImportEditedEvent {
  eventType: 'recipe_import_edited';
  timestamp: Date;
  recipeId: string;
  
  // What the user corrected
  edits: {
    field: string;          // 'title', 'ingredients', 'instructions'
    editType: 'add' | 'remove' | 'modify';
  }[];
  
  // Time from import to first edit
  timeToEditMs: number;
}
```

### 3.2.2 Parsing & Scaling Events

```typescript
interface IngredientParseEvent {
  eventType: 'ingredient_parsed';
  timestamp: Date;
  
  // Input characteristics
  inputLength: number;
  hasQuantity: boolean;
  hasUnit: boolean;
  hasFraction: boolean;
  
  // Parse result
  success: boolean;
  confidence: number;
  
  // For improving parser
  parseResult?: {
    quantityType: 'whole' | 'fraction' | 'decimal' | 'range';
    unitCategory: 'volume' | 'weight' | 'count' | 'none';
    hasPreparation: boolean;
    hasNotes: boolean;
  };
}

interface RecipeScaledEvent {
  eventType: 'recipe_scaled';
  timestamp: Date;
  recipeId: string;
  
  originalServings: number;
  targetServings: number;
  scaleFactor: number;
  scalingMode: 'linear' | 'smart' | 'baking';
  
  ingredientCount: number;
  warningCount: number;
}

interface ShoppingListGeneratedEvent {
  eventType: 'shopping_list_generated';
  timestamp: Date;
  
  recipeCount: number;
  totalIngredients: number;
  aggregatedItems: number;    // After combining
  
  // Aggregation stats
  combinedCount: number;      // Items that were combined
  multiUnitCount: number;     // Items with incompatible units
  
  // User preferences
  preferredUnits: 'imperial' | 'metric';
  groupedByCategory: boolean;
}
```

### 3.2.3 Sharing & Lineage Events

```typescript
interface ShareCreatedEvent {
  eventType: 'share_created';
  timestamp: Date;
  userId: string;
  shareId: string;
  
  shareType: 'generic' | 'heirloom' | 'collaborative';
  
  options: {
    includesCardBack: boolean;
    includesRating: boolean;
    includesNotes: boolean;
    includesHistory: boolean;
    hasExpiration: boolean;
    allowsResharing: boolean;
  };
  
  recipeMeta: {
    ingredientCount: number;
    hasImage: boolean;
    generation: number;       // 0 = original, 1+ = fork
  };
}

interface ShareAcceptedEvent {
  eventType: 'share_accepted';
  timestamp: Date;
  shareId: string;
  recipientId: string;
  
  // Conversion tracking
  timeSinceShareCreatedMs: number;
  sourceChannel: 'link' | 'qr' | 'message';
  
  // Lineage impact
  newGeneration: number;
}

interface RecipeForkedEvent {
  eventType: 'recipe_forked';
  timestamp: Date;
  
  parentRecipeId: string;
  childRecipeId: string;
  generation: number;
  
  // What changed
  modifications: {
    type: 'ingredient_added' | 'ingredient_removed' | 'ingredient_modified' |
          'instruction_added' | 'instruction_removed' | 'instruction_modified' |
          'serving_changed' | 'note_added';
    count: number;
  }[];
}

interface LineageViewedEvent {
  eventType: 'lineage_viewed';
  timestamp: Date;
  
  rootRecipeId: string;
  currentRecipeGeneration: number;
  totalGenerations: number;
  totalDescendants: number;
}
```

## 3.3 Dashboard Queries

```sql
-- Key Heirloom dashboard queries

-- 1. Import success rate by method (daily)
SELECT 
  DATE_TRUNC('day', timestamp) as day,
  import_method,
  COUNT(CASE WHEN success THEN 1 END)::float / COUNT(*) as success_rate,
  COUNT(*) as total_imports
FROM recipe_import_completed_events
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1, 2;

-- 2. Import failure reasons
SELECT 
  error_stage,
  error_code,
  COUNT(*) as count
FROM recipe_import_completed_events
WHERE success = false
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;

-- 3. User edit rate after import (quality signal)
SELECT 
  import_method,
  COUNT(CASE WHEN had_edit THEN 1 END)::float / COUNT(*) as edit_rate,
  AVG(time_to_edit_ms) / 1000 / 60 as avg_minutes_to_edit
FROM (
  SELECT 
    i.import_method,
    e.recipe_id IS NOT NULL as had_edit,
    e.time_to_edit_ms
  FROM recipe_import_completed_events i
  LEFT JOIN recipe_import_edited_events e ON i.recipe_id = e.recipe_id
  WHERE i.timestamp > NOW() - INTERVAL '30 days'
    AND i.success = true
) sub
GROUP BY 1;

-- 4. Sharing funnel
SELECT 
  'shares_created' as stage, COUNT(*) as count
FROM share_created_events
WHERE timestamp > NOW() - INTERVAL '30 days'
UNION ALL
SELECT 
  'shares_accepted', COUNT(*)
FROM share_accepted_events
WHERE timestamp > NOW() - INTERVAL '30 days';

-- 5. Lineage depth distribution
SELECT 
  generation,
  COUNT(*) as recipe_count
FROM recipes
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1;

-- 6. Scaling usage patterns
SELECT 
  CASE 
    WHEN scale_factor < 0.5 THEN 'scale_down_half'
    WHEN scale_factor < 1 THEN 'scale_down_slight'
    WHEN scale_factor = 1 THEN 'no_scale'
    WHEN scale_factor <= 2 THEN 'scale_up_double'
    ELSE 'scale_up_large'
  END as scale_category,
  COUNT(*) as count
FROM recipe_scaled_events
WHERE timestamp > NOW() - INTERVAL '30 days'
GROUP BY 1
ORDER BY 2 DESC;

-- 7. Shopping list ingredient aggregation effectiveness
SELECT 
  AVG(total_ingredients::float / aggregated_items) as avg_compression_ratio,
  AVG(combined_count::float / total_ingredients) as avg_combine_rate,
  AVG(recipe_count) as avg_recipes_per_list
FROM shopping_list_generated_events
WHERE timestamp > NOW() - INTERVAL '30 days';
```

## 3.4 Alerts

```typescript
// packages/@heirloom/telemetry/src/alerts.ts

const HEIRLOOM_ALERTS = [
  {
    name: 'url_import_success_drop',
    query: 'avg(success_rate) where import_method=url over 1h',
    condition: '< 0.80',
    severity: 'critical',
    action: 'page_on_call',
    message: 'URL import success rate dropped below 80%'
  },
  {
    name: 'photo_import_success_drop',
    query: 'avg(success_rate) where import_method=photo over 1h',
    condition: '< 0.70',
    severity: 'warning',
    action: 'slack_alert',
    message: 'Photo import success rate dropped below 70%'
  },
  {
    name: 'high_edit_rate_after_import',
    query: 'avg(edit_rate) over 24h',
    condition: '> 0.50',
    severity: 'warning',
    action: 'create_ticket',
    message: '>50% of imports being edited - parsing quality issue?'
  },
  {
    name: 'share_acceptance_drop',
    query: 'count(share_accepted) / count(share_created) over 7d',
    condition: '< 0.10',
    severity: 'info',
    action: 'log',
    message: 'Share acceptance rate very low - UX issue?'
  },
  {
    name: 'ai_cost_spike',
    query: 'sum(ai_call_count) over 1h',
    condition: '> 1000',
    severity: 'warning',
    action: 'slack_alert',
    message: 'High AI API usage - cost spike warning'
  }
];
```

---

# 4. WatchOS App Architecture

## 4.1 Design Philosophy

The Apple Watch for Heirloom is **simple and focused**: a timer list for hands-free cooking.

```
┌─────────────────────────────────────────────────────────────────┐
│              HEIRLOOM WATCH: TIMER LIST                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────────────────────────────────────────┐       │
│   │  TIMER LIST                                          │       │
│   │                                                       │       │
│   │  ┌─────────────────────────────────────────────┐     │       │
│   │  │ 🍞 Bake bread               25:00 remaining │     │       │
│   │  │    ████████░░░░░░░░░░░░░░░░░░░             │     │       │
│   │  └─────────────────────────────────────────────┘     │       │
│   │                                                       │       │
│   │  ┌─────────────────────────────────────────────┐     │       │
│   │  │ 🥩 Rest steak                5:00 remaining │     │       │
│   │  │    ██████████████████░░░░░░░░░             │     │       │
│   │  └─────────────────────────────────────────────┘     │       │
│   │                                                       │       │
│   │  ┌─────────────────────────────────────────────┐     │       │
│   │  │ + Add timer                                  │     │       │
│   │  └─────────────────────────────────────────────┘     │       │
│   │                                                       │       │
│   └─────────────────────────────────────────────────────┘       │
│                                                                 │
│   Interaction:                                                  │
│   • Tap timer → Pause/Resume                                   │
│   • Swipe left → Delete                                        │
│   • Digital Crown → Adjust time                                │
│   • Notification when complete                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 4.2 App Structure

```
HeirloomWatch/
├── HeirloomWatchApp.swift       # App entry point
├── Models/
│   └── CookingTimer.swift       # Timer model
├── Views/
│   ├── TimerListView.swift      # Main view - list of timers
│   ├── TimerRowView.swift       # Single timer row
│   ├── AddTimerView.swift       # Quick add timer
│   └── TimerDetailView.swift    # Timer controls
├── Services/
│   ├── TimerManager.swift       # Timer state management
│   └── WatchConnectivity.swift  # Sync with iPhone
├── Complications/
│   ├── ComplicationController.swift
│   └── ComplicationViews.swift
└── Notifications/
    └── NotificationManager.swift
```

## 4.3 Data Model

```swift
// HeirloomWatch/Models/CookingTimer.swift

import Foundation
import SwiftData

@Model
class CookingTimer: Identifiable {
    var id: UUID
    var label: String                    // "Bake bread"
    var recipeId: UUID?                  // Link to recipe (optional)
    var recipeName: String?              // For display
    
    // Duration
    var totalSeconds: Int
    var remainingSeconds: Int
    
    // State
    var state: TimerState
    var startedAt: Date?
    var pausedAt: Date?
    
    // For notifications
    var notificationId: String?
    
    // Display
    var emoji: String                    // 🍞, 🥩, ⏰
    var color: TimerColor
    
    // Computed
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var displayTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isComplete: Bool {
        remainingSeconds <= 0
    }
}

enum TimerState: String, Codable {
    case idle
    case running
    case paused
    case completed
}

enum TimerColor: String, Codable {
    case red, orange, yellow, green, blue, purple
}
```

## 4.4 Timer List View

```swift
// HeirloomWatch/Views/TimerListView.swift

import SwiftUI
import SwiftData

struct TimerListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CookingTimer.startedAt) private var timers: [CookingTimer]
    @StateObject private var timerManager = TimerManager.shared
    
    @State private var showingAddTimer = false
    
    var body: some View {
        NavigationStack {
            List {
                // Active timers
                ForEach(activeTimers) { timer in
                    TimerRowView(timer: timer)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteTimer(timer)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                
                // Completed timers (collapsible)
                if !completedTimers.isEmpty {
                    Section("Completed") {
                        ForEach(completedTimers) { timer in
                            CompletedTimerRow(timer: timer)
                        }
                        .onDelete(perform: deleteCompletedTimers)
                    }
                }
                
                // Add timer button
                Button {
                    showingAddTimer = true
                } label: {
                    Label("Add Timer", systemImage: "plus.circle.fill")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Timers")
            .sheet(isPresented: $showingAddTimer) {
                AddTimerView()
            }
        }
    }
    
    private var activeTimers: [CookingTimer] {
        timers.filter { $0.state != .completed }
    }
    
    private var completedTimers: [CookingTimer] {
        timers.filter { $0.state == .completed }
    }
    
    private func deleteTimer(_ timer: CookingTimer) {
        timerManager.cancelTimer(timer)
        modelContext.delete(timer)
    }
}

struct TimerRowView: View {
    @ObservedObject var timer: CookingTimer
    @StateObject private var timerManager = TimerManager.shared
    
    var body: some View {
        Button {
            toggleTimer()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(timer.emoji)
                    Text(timer.label)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(timer.displayTime)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(timerColor)
                }
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(timerColor)
                            .frame(width: geometry.size.width * timer.progress, height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
                
                // State indicator
                HStack {
                    Image(systemName: stateIcon)
                        .font(.caption)
                    Text(stateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var timerColor: Color {
        if timer.remainingSeconds < 60 {
            return .red
        } else if timer.remainingSeconds < 300 {
            return .orange
        }
        return .green
    }
    
    private var stateIcon: String {
        switch timer.state {
        case .running: return "play.fill"
        case .paused: return "pause.fill"
        case .idle: return "clock"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    private var stateText: String {
        switch timer.state {
        case .running: return "Running"
        case .paused: return "Paused - tap to resume"
        case .idle: return "Tap to start"
        case .completed: return "Done!"
        }
    }
    
    private func toggleTimer() {
        switch timer.state {
        case .idle, .paused:
            timerManager.startTimer(timer)
        case .running:
            timerManager.pauseTimer(timer)
        case .completed:
            break
        }
        
        WKInterfaceDevice.current().play(.click)
    }
}
```

## 4.5 Add Timer View

```swift
// HeirloomWatch/Views/AddTimerView.swift

import SwiftUI

struct AddTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var minutes: Int = 10
    @State private var label: String = ""
    @State private var selectedEmoji: String = "⏰"
    
    private let emojis = ["⏰", "🍞", "🥩", "🍳", "🥘", "🍝", "🍰", "☕️"]
    private let presets = [
        ("1 min", 1), ("5 min", 5), ("10 min", 10),
        ("15 min", 15), ("30 min", 30), ("1 hour", 60)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Quick presets
                Section("Quick Add") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(presets, id: \.0) { preset in
                            Button(preset.0) {
                                createTimer(minutes: preset.1, label: preset.0)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                // Custom timer
                Section("Custom Timer") {
                    // Minutes picker with Digital Crown
                    Picker("Minutes", selection: $minutes) {
                        ForEach(1...120, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .focusable()
                    
                    // Label
                    TextField("Label", text: $label)
                    
                    // Emoji picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(emojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.title2)
                                        .padding(8)
                                        .background(selectedEmoji == emoji ? Color.blue.opacity(0.3) : Color.clear)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // Create button
                Button("Create Timer") {
                    createTimer(minutes: minutes, label: label.isEmpty ? "\(minutes) min timer" : label)
                }
                .disabled(minutes < 1)
            }
            .navigationTitle("Add Timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func createTimer(minutes: Int, label: String) {
        let timer = CookingTimer(
            id: UUID(),
            label: label,
            totalSeconds: minutes * 60,
            remainingSeconds: minutes * 60,
            state: .idle,
            emoji: selectedEmoji,
            color: .blue
        )
        
        modelContext.insert(timer)
        dismiss()
    }
}
```

## 4.6 Timer Manager

```swift
// HeirloomWatch/Services/TimerManager.swift

import Foundation
import UserNotifications
import WatchKit

@MainActor
class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    private var activeTimers: [UUID: Timer] = [:]
    
    func startTimer(_ timer: CookingTimer) {
        timer.state = .running
        timer.startedAt = Date()
        
        // Create system timer
        let systemTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick(timer)
            }
        }
        activeTimers[timer.id] = systemTimer
        
        // Schedule notification
        scheduleNotification(for: timer)
    }
    
    func pauseTimer(_ timer: CookingTimer) {
        timer.state = .paused
        timer.pausedAt = Date()
        
        // Cancel system timer
        activeTimers[timer.id]?.invalidate()
        activeTimers.removeValue(forKey: timer.id)
        
        // Cancel notification
        cancelNotification(for: timer)
    }
    
    func cancelTimer(_ timer: CookingTimer) {
        activeTimers[timer.id]?.invalidate()
        activeTimers.removeValue(forKey: timer.id)
        cancelNotification(for: timer)
    }
    
    private func tick(_ timer: CookingTimer) {
        guard timer.state == .running else { return }
        
        timer.remainingSeconds -= 1
        
        if timer.remainingSeconds <= 0 {
            complete(timer)
        }
    }
    
    private func complete(_ timer: CookingTimer) {
        timer.state = .completed
        timer.remainingSeconds = 0
        
        activeTimers[timer.id]?.invalidate()
        activeTimers.removeValue(forKey: timer.id)
        
        // Haptic feedback
        WKInterfaceDevice.current().play(.notification)
    }
    
    // MARK: - Notifications
    
    private func scheduleNotification(for timer: CookingTimer) {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(timer.emoji) \(timer.label) is done!"
        content.sound = .default
        content.categoryIdentifier = "TIMER_COMPLETE"
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(timer.remainingSeconds),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: timer.id.uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
        timer.notificationId = timer.id.uuidString
    }
    
    private func cancelNotification(for timer: CookingTimer) {
        guard let notificationId = timer.notificationId else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationId]
        )
    }
}
```

## 4.7 WatchConnectivity

```swift
// HeirloomWatch/Services/WatchConnectivity.swift

import WatchConnectivity

class HeirloomWatchConnectivity: NSObject, WCSessionDelegate {
    static let shared = HeirloomWatchConnectivity()
    
    private let session: WCSession
    
    override init() {
        session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - Receive Timers from iPhone
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        
        switch type {
        case "timers_from_recipe":
            handleTimersFromRecipe(message)
        case "timer_update":
            handleTimerUpdate(message)
        default:
            break
        }
    }
    
    private func handleTimersFromRecipe(_ message: [String: Any]) {
        guard let timersData = message["timers"] as? [[String: Any]],
              let recipeName = message["recipeName"] as? String,
              let recipeId = message["recipeId"] as? String else { return }
        
        Task { @MainActor in
            for timerData in timersData {
                guard let label = timerData["label"] as? String,
                      let seconds = timerData["seconds"] as? Int else { continue }
                
                let timer = CookingTimer(
                    id: UUID(),
                    label: label,
                    recipeId: UUID(uuidString: recipeId),
                    recipeName: recipeName,
                    totalSeconds: seconds,
                    remainingSeconds: seconds,
                    state: .idle,
                    emoji: "🍳",
                    color: .blue
                )
                
                // Save to SwiftData
                // modelContext.insert(timer)
            }
        }
    }
    
    // MARK: - Send Updates to iPhone
    
    func sendTimerUpdate(_ timer: CookingTimer) {
        guard session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "timer_update",
            "timerId": timer.id.uuidString,
            "state": timer.state.rawValue,
            "remainingSeconds": timer.remainingSeconds
        ]
        
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // Handle activation
    }
}
```

## 4.8 Complication

```swift
// HeirloomWatch/Complications/ComplicationViews.swift

import SwiftUI
import WidgetKit

struct HeirloomComplication: Widget {
    let kind: String = "HeirloomTimers"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerProvider()) { entry in
            TimerComplicationView(entry: entry)
        }
        .configurationDisplayName("Cooking Timers")
        .description("Shows your active cooking timers")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct TimerComplicationView: View {
    var entry: TimerEntry
    
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularTimerView(entry: entry)
        case .accessoryRectangular:
            RectangularTimerView(entry: entry)
        case .accessoryInline:
            InlineTimerView(entry: entry)
        case .accessoryCorner:
            CornerTimerView(entry: entry)
        default:
            EmptyView()
        }
    }
}

struct CircularTimerView: View {
    let entry: TimerEntry
    
    var body: some View {
        if let timer = entry.nextTimer {
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(timerColor(timer), lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                
                // Time remaining
                VStack(spacing: 0) {
                    Text(timer.emoji)
                        .font(.caption)
                    Text(timer.displayTime)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                }
            }
        } else {
            // No active timers
            VStack {
                Image(systemName: "timer")
                Text("No timers")
                    .font(.caption2)
            }
        }
    }
    
    private func timerColor(_ timer: CookingTimer) -> Color {
        if timer.remainingSeconds < 60 { return .red }
        if timer.remainingSeconds < 300 { return .orange }
        return .green
    }
}

struct RectangularTimerView: View {
    let entry: TimerEntry
    
    var body: some View {
        if let timer = entry.nextTimer {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(timer.emoji)
                    Text(timer.label)
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(timer.displayTime)
                        .font(.system(.title3, design: .monospaced))
                    
                    Spacer()
                    
                    if entry.activeTimerCount > 1 {
                        Text("+\(entry.activeTimerCount - 1) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            HStack {
                Image(systemName: "timer")
                Text("No active timers")
            }
        }
    }
}

// Timeline provider
struct TimerProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(date: Date(), nextTimer: nil, activeTimerCount: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        var entries: [TimerEntry] = []
        let currentDate = Date()
        
        // Create entries for the next hour, updating every minute
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!
            let entry = createEntry(at: entryDate)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
    
    private func createEntry(at date: Date = Date()) -> TimerEntry {
        // Get active timers from SwiftData
        // This is simplified - real implementation needs data access
        return TimerEntry(date: date, nextTimer: nil, activeTimerCount: 0)
    }
}

struct TimerEntry: TimelineEntry {
    let date: Date
    let nextTimer: CookingTimer?
    let activeTimerCount: Int
}
```

## 4.9 Watch App Acceptance Criteria

| Criterion | Target |
|-----------|--------|
| Timer accuracy | ±1 second over 1 hour |
| Background timer reliability | 100% notification delivery |
| Battery impact | <3% per active timer per hour |
| Sync latency (iPhone → Watch) | <2 seconds |
| Complication update frequency | Every minute when active |
| Cold launch to timer list | <1 second |

---

# 5. Ship Readiness Criteria

## 5.1 Beta Launch Checklist

### Core Functionality

| Feature | Criterion | Target | Status |
|---------|-----------|--------|--------|
| URL Import | Success rate | ≥85% | 🔲 |
| Photo Import | Success rate | ≥75% | 🔲 |
| Manual Entry | Works reliably | 100% | 🔲 |
| Recipe Viewing | No crashes | 0 crashes | 🔲 |
| Scaling | Accuracy | ≥95% | 🔲 |
| Timer Detection | Accuracy | ≥90% | 🔲 |
| Shopping List | Aggregation correct | ≥95% | 🔲 |

### Sharing & Lineage

| Feature | Criterion | Target | Status |
|---------|-----------|--------|--------|
| Share Link Generation | Works reliably | 100% | 🔲 |
| Deep Link Handling | Cold + warm launch | 100% | 🔲 |
| Share Acceptance | Flow completes | 100% | 🔲 |
| Lineage Tracking | Generation accurate | 100% | 🔲 |
| Modification Recording | Changes tracked | 100% | 🔲 |
| Ancestor Notifications | Delivered | ≥95% | 🔲 |

### Infrastructure

| Feature | Criterion | Target | Status |
|---------|-----------|--------|--------|
| Firebase Sync | Offline → Online | No data loss | 🔲 |
| DI Migration | Services converted | 100% (52/52) | 🔲 |
| Error Handling | No TODO messages | 0 TODOs | 🔲 |
| Performance | 1000 recipes | <2s load | 🔲 |
| Crash Rate | Production crashes | <0.1% | 🔲 |

### Legal & Compliance

| Feature | Criterion | Target | Status |
|---------|-----------|--------|--------|
| Attribution Display | Source shown | 100% of imports | 🔲 |
| Terms of Service | Document exists | ✓ | 🔲 |
| Privacy Policy | Document exists | ✓ | 🔲 |
| DMCA Process | Documented | ✓ | 🔲 |

## 5.2 Staged Rollout Plan

```
┌─────────────────────────────────────────────────────────────────┐
│                    HEIRLOOM BETA ROLLOUT                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Week 1: Internal Testing                                       │
│  ├─ Team + family members only                                 │
│  ├─ Focus: Import reliability, sync stability                  │
│  ├─ Full telemetry enabled                                     │
│  └─ Goal: Catch critical bugs                                  │
│                                                                 │
│  Week 2: Friends & Family (20 users)                           │
│  ├─ Trusted external testers                                   │
│  ├─ Focus: Sharing flow, lineage accuracy                      │
│  ├─ Feedback form + direct Slack channel                       │
│  └─ Goal: Validate social features                             │
│                                                                 │
│  Week 3-4: Closed Beta (100 users)                             │
│  ├─ TestFlight invite system                                   │
│  ├─ Focus: Scale testing, edge cases                           │
│  ├─ Weekly update cadence                                      │
│  └─ Goal: Find long-tail bugs                                  │
│                                                                 │
│  Week 5-6: Open Beta (500+ users)                              │
│  ├─ TestFlight public link                                     │
│  ├─ Focus: Performance, UX polish                              │
│  ├─ Feature requests collection                                │
│  └─ Goal: Validate market fit                                  │
│                                                                 │
│  Week 7+: Public Launch                                        │
│  ├─ App Store submission                                       │
│  ├─ Marketing push                                             │
│  └─ Continuous monitoring                                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 5.3 Kill Switch Criteria

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Crash rate | >1% sessions | Pause rollout, investigate |
| Import failure rate | >30% | Disable AI import, fallback to manual |
| Data sync failures | >5% | Disable background sync, manual only |
| Share acceptance failures | >20% | Disable sharing, investigate |
| Negative reviews | >3 in 24h mentioning data loss | Pause rollout |

## 5.4 Phase 1 Sprint Plan: Road to Beta

### Overview

**Goal:** Beta-ready build in 6 weeks  
**Start:** Week of January 6, 2026  
**Beta Launch Target:** Week of February 17, 2026

```
┌─────────────────────────────────────────────────────────────────┐
│                    6-WEEK SPRINT TIMELINE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Week 1-2: Infrastructure & DI                                  │
│  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                                                 │
│  Week 3-4: Features & Testing                                   │
│  ░░░░░░░░░░░░░░░░████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                                                                 │
│  Week 5: Legal & Polish                                         │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░░░░░░░░░░░░░░░░░░░  │
│                                                                 │
│  Week 6: Internal Beta                                          │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████░░░░░░░░░░░░  │
│                                                                 │
│  Week 7+: External Beta Rollout                                 │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████████  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

### Week 1: DI Migration — Core Services
**Jan 6-12, 2026**

| Day | Task | Services | Owner |
|-----|------|----------|-------|
| Mon | Core services batch 1 | `RecipeService`, `IngredientService` | — |
| Tue | Core services batch 2 | `CollectionService`, `TagService` | — |
| Wed | Core services batch 3 | `SearchService`, `CacheService` | — |
| Thu | Core services batch 4 | `SettingsService` | — |
| Fri | Integration testing | Verify all Core services work together | — |

**Deliverables:**
- [ ] 7 Core services converted to DI (7/7)
- [ ] All Core service protocols defined
- [ ] Mock implementations for testing
- [ ] No regressions in existing functionality

**Progress checkpoint:** 16/52 services complete (31%)

---

### Week 2: DI Migration — AI Services
**Jan 13-19, 2026**

| Day | Task | Services | Owner |
|-----|------|----------|-------|
| Mon | AI services batch 1 | `AIRecipeExtractor`, `AIIngredientParser` | — |
| Tue | AI services batch 2 | `AIRecipeDetector`, `AITimerDetector` | — |
| Wed | AI services batch 3 | `EnhancedOCRService`, `AIImageService` | — |
| Thu | AI services batch 4 | `AIRecommendationService`, `AISummaryService` | — |
| Fri | AI services batch 5 | `AISearchService`, `AITagSuggester`, `AIErrorHandler` | — |

**Deliverables:**
- [ ] 11 AI services converted to DI (11/11)
- [ ] AI service protocols with clear boundaries
- [ ] Stub implementations for offline/testing
- [ ] API key handling via DI (not hardcoded)

**Progress checkpoint:** 27/52 services complete (52%)

---

### Week 3: DI Migration — Remaining Services + Deep Links
**Jan 20-26, 2026**

| Day | Task | Services/Features | Owner |
|-----|------|-------------------|-------|
| Mon | Other services batch 1 | `DeepLinkHandler`, `URLService`, `NotificationService` | — |
| Tue | Other services batch 2 | `ImageCacheService`, `ThumbnailService`, `StorageService` | — |
| Wed | Other services batch 3 | `SyncCoordinator`, `ConflictResolver`, `MergeEngine` | — |
| Thu | Other services batch 4 | `ShoppingListService`, `MealPlanService`, `TimerService` | — |
| Fri | Other services batch 5 | `AnalyticsService`, `CrashReporter`, `LoggingService` | — |

**Deep Link Testing (parallel track):**
| Scenario | Test Case | Status |
|----------|-----------|--------|
| Cold launch | App not running → tap share link → accept flow | 🔲 |
| Warm launch | App in background → tap share link → accept flow | 🔲 |
| Foreground | App active → tap share link → accept flow | 🔲 |
| Expired link | Tap expired share → graceful error | 🔲 |
| Invalid link | Malformed URL → graceful error | 🔲 |
| Already accepted | Re-tap same link → appropriate message | 🔲 |

**Deliverables:**
- [ ] 15 additional services converted (15/25)
- [ ] Deep link test suite passing
- [ ] `DeepLinkHandler` queueing for cold launch verified

**Progress checkpoint:** 42/52 services complete (81%)

---

### Week 4: DI Completion + Sharing & Lineage Testing
**Jan 27 - Feb 2, 2026**

| Day | Task | Services/Features | Owner |
|-----|------|-------------------|-------|
| Mon | Other services batch 6 | `ExportService`, `ImportService`, `BackupService` | — |
| Tue | Other services batch 7 | `SubscriptionService`, `PurchaseService` | — |
| Wed | Other services batch 8 | `UserPreferencesService`, `OnboardingService` | — |
| Thu | Final services | `FeatureFlagService`, `ABTestService`, `RemoteConfigService` | — |
| Fri | DI verification | Full app walkthrough with all DI services | — |

**Sharing & Lineage Test Matrix:**

| Test Case | Steps | Expected | Status |
|-----------|-------|----------|--------|
| Basic share | Create share → Copy link → Accept on other device | Recipe appears, G1 | 🔲 |
| Heirloom share | Share as Heirloom → Accept → Modify → Check lineage | Modification tracked | 🔲 |
| Multi-generation | A shares to B → B shares to C | C is G2, lineage shows A→B→C | 🔲 |
| Ancestor notification | B modifies → A receives notification | Notification delivered | 🔲 |
| Concurrent edits | A and B edit simultaneously → Sync | CRDT merges correctly | 🔲 |
| Offline share accept | Accept while offline → Go online | Syncs correctly | 🔲 |
| Re-share permission | Share with re-share disabled → B tries to share | Blocked appropriately | 🔲 |
| Share expiration | Create 24h share → Wait → Try to accept | Expired error shown | 🔲 |

**Deliverables:**
- [ ] All 52 services converted to DI ✓
- [ ] Full sharing test matrix passing
- [ ] Lineage accuracy verified across 3+ generations
- [ ] CRDT conflict resolution tested

**Progress checkpoint:** 52/52 services complete (100%) 🎉

---

### Week 5: Legal, Attribution & Error Handling
**Feb 3-9, 2026**

| Day | Task | Deliverable | Owner |
|-----|------|-------------|-------|
| Mon | Terms of Service | Draft TOS document | — |
| Mon | Privacy Policy | Draft privacy policy | — |
| Tue | Legal review | Send to lawyer (if budget allows) | — |
| Tue | Attribution UI | `RecipeAttributionView` implementation | — |
| Wed | Photo import attribution | `CookbookAttributionInput` (required field) | — |
| Wed | Lineage attribution | `LineageAttributionView` implementation | — |
| Thu | Error handling audit | Find all `// TODO` error messages | — |
| Thu | Error messages | Replace TODOs with user-friendly messages | — |
| Fri | In-app TOS flow | First-launch TOS acceptance screen | — |
| Fri | Attribution verification | Every imported recipe shows source | — |

**Error Handling Audit Checklist:**

| Location | Current State | Fix Required |
|----------|---------------|--------------|
| URL import failure | `// TODO: show error` | User-friendly message + retry option |
| Photo OCR failure | `// TODO: handle` | "Couldn't read text, try clearer photo" |
| Firebase sync failure | Generic error | Specific offline/auth/network messages |
| Share creation failure | Silent fail | Toast with retry |
| Deep link invalid | Crash (?) | Graceful "link not found" screen |
| AI parsing failure | Falls back silently | Inform user, offer manual entry |

**Deliverables:**
- [ ] Terms of Service document finalized
- [ ] Privacy Policy document finalized
- [ ] In-app TOS acceptance flow working
- [ ] Attribution displayed on all imported recipes
- [ ] Photo imports require cookbook attribution
- [ ] 0 TODO error messages remaining
- [ ] All error states have user-friendly messages

---

### Week 6: Polish, Performance & Internal Beta
**Feb 10-16, 2026**

| Day | Task | Focus | Owner |
|-----|------|-------|-------|
| Mon | Performance testing | Test with 500+ recipes | — |
| Mon | Memory profiling | Check for leaks, reduce footprint | — |
| Tue | Performance fixes | Address any slowdowns found | — |
| Tue | Image optimization | Lazy loading, cache tuning | — |
| Wed | UI polish | Animation smoothness, loading states | — |
| Wed | Empty states | First-time user experience | — |
| Thu | TestFlight build | Create beta build, upload | — |
| Thu | Internal distribution | Team + family install | — |
| Fri | Bug bash | Whole team tests all features | — |
| Fri | Triage | Prioritize bugs found | — |

**Performance Targets:**

| Metric | Target | Test Method |
|--------|--------|-------------|
| App launch (cold) | <2s to usable | Stopwatch from tap to list visible |
| Recipe list scroll | 60fps | Instruments profiling |
| Recipe detail load | <500ms | With images |
| Search results | <300ms | 500 recipe corpus |
| Share link generation | <1s | End to end |
| Import (URL) | <10s | Average website |
| Import (photo) | <15s | Including OCR + AI |
| Memory (500 recipes) | <150MB | Instruments |

**Internal Beta Checklist:**

- [ ] TestFlight build uploaded
- [ ] Internal testers invited (team + family)
- [ ] Crash reporting enabled (Crashlytics/Sentry)
- [ ] Telemetry pipeline verified
- [ ] Feedback collection method ready (form/Slack)
- [ ] Known issues documented
- [ ] Bug reporting instructions sent

---

### Week 7+: External Beta Rollout
**Feb 17+, 2026**

**Week 7: Friends & Family (20 users)**
- Send TestFlight invites to trusted external testers
- Daily check-in on crash reports
- Collect feedback via dedicated Slack channel
- Fix P0 bugs same-day, P1 within 48h

**Week 8: Closed Beta (100 users)**
- Expand TestFlight to waitlist
- Establish weekly release cadence
- Monitor telemetry dashboards
- Prioritize based on user feedback

**Week 9-10: Open Beta (500+ users)**
- TestFlight public link
- Social media soft launch
- Scale monitoring
- Feature freeze for stability

**Post-Beta: App Store Submission**
- Final QA pass
- App Store assets (screenshots, description)
- Submit for review
- Plan launch marketing

---

### Sprint Tracking Summary

| Week | Focus | DI Progress | Key Milestone |
|------|-------|-------------|---------------|
| 1 | Core Services | 16/52 (31%) | Core services DI complete |
| 2 | AI Services | 27/52 (52%) | AI services DI complete |
| 3 | Other Services + Deep Links | 42/52 (81%) | Deep links tested |
| 4 | Final Services + Sharing | **52/52 (100%)** | DI migration complete ✓ |
| 5 | Legal + Attribution | — | TOS/Attribution complete |
| 6 | Polish + Internal Beta | — | Internal beta live |
| 7+ | External Rollout | — | Beta launch |

---

### Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| DI migration breaks existing features | Medium | High | Run full regression after each batch |
| Legal review takes longer than expected | Medium | Medium | Start Week 5 Day 1, have fallback TOS |
| Deep link edge cases cause crashes | Medium | High | Extensive QA matrix, staged rollout |
| Performance issues at 500+ recipes | Low | High | Profile early in Week 6 |
| AI costs spike during beta | Medium | Medium | Add rate limiting, cache aggressively |
| Lineage sync bugs in multi-user scenarios | Medium | High | Test with 3+ devices simultaneously |

---

### Daily Standup Template

```
HEIRLOOM BETA SPRINT - DAY [X]
==============================

Yesterday:
- [What was completed]

Today:
- [What's planned]

Blockers:
- [Any blockers]

DI Progress: [X]/52 services
Beta Readiness: [X]% (checklist items complete)
Days to Beta: [X]
```

---

# 6. Attribution & Legal Compliance

## 6.1 Current State

Heirloom has `ProvenanceMetadata` tracking:
- Source URL (for web imports)
- Source attribution (website name or cookbook)
- Shared by name (for received recipes)

**This is good foundation but needs strengthening.**

## 6.2 Attribution Requirements

### For URL Imports

```swift
// Required attribution display
struct RecipeAttributionView: View {
    let provenance: ProvenanceMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recipe Source")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let url = provenance.sourceURL {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link")
                        Text(provenance.sourceAttribution ?? url.host ?? "Original Recipe")
                    }
                }
            } else if let attribution = provenance.sourceAttribution {
                Text(attribution)
            }
            
            if let importDate = provenance.createdAt {
                Text("Imported \(importDate.formatted())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
```

### For Photo Imports (Cookbooks)

```swift
struct CookbookAttributionInput: View {
    @Binding var bookTitle: String
    @Binding var author: String
    @Binding var pageNumber: String
    
    var body: some View {
        Form {
            Section("Cookbook Information") {
                TextField("Book Title", text: $bookTitle)
                TextField("Author", text: $author)
                TextField("Page Number (optional)", text: $pageNumber)
            }
            
            Section {
                Text("Please provide attribution for recipes from physical cookbooks to respect the author's work.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

### Lineage Attribution

```swift
// Show full provenance chain
struct LineageAttributionView: View {
    let lineage: RecipeLineage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Original source
            if let rootProvenance = lineage.rootProvenance {
                AttributionRow(
                    label: "Original Recipe",
                    attribution: rootProvenance.sourceAttribution,
                    url: rootProvenance.sourceURL
                )
            }
            
            // Sharing chain
            if lineage.generation > 0 {
                ForEach(lineage.sharingHistory, id: \.id) { share in
                    AttributionRow(
                        label: "Generation \(share.generation)",
                        attribution: "Shared by \(share.sharedByName)",
                        date: share.sharedDate
                    )
                }
            }
        }
    }
}
```

## 6.3 Terms of Service Requirements

```markdown
# Heirloom Terms of Service

## Recipe Content

1. **User Responsibility**: You are responsible for ensuring you have the right 
   to import, store, and share any recipe content.

2. **Attribution**: When importing recipes from websites or cookbooks, you must 
   provide accurate attribution. Heirloom displays this attribution to maintain 
   proper credit to original creators.

3. **No Commercial Redistribution**: Recipes stored in Heirloom are for personal 
   use. You may share with friends and family through Heirloom's sharing features, 
   but may not commercially redistribute recipe content.

4. **Original Content**: For recipes you create yourself, you retain all rights. 
   By sharing through Heirloom, you grant recipients the right to view, cook, and 
   modify the recipe for personal use.

## Shared Recipes & Lineage

1. **Lineage Tracking**: When you share a recipe as an "Heirloom," modifications 
   made by recipients are tracked to preserve recipe history.

2. **Ancestor Access**: Original recipe creators may see when their recipes have 
   been modified by recipients (but not the specific modifications without permission).

3. **Modification Rights**: Recipients of shared recipes may modify them for 
   personal use. These modifications create a new "generation" in the lineage.

## Copyright Claims

If you believe content in Heirloom infringes your copyright:

1. Contact us at [email]
2. Provide identification of the copyrighted work
3. Provide identification of the allegedly infringing content
4. Provide your contact information

We will review and respond within 10 business days.
```

## 6.4 Implementation Checklist

| Item | Priority | Status |
|------|----------|--------|
| Attribution display on recipe card | P0 | 🔲 |
| Require attribution for photo imports | P0 | 🔲 |
| Lineage attribution view | P1 | 🔲 |
| Terms of Service document | P0 | 🔲 |
| Privacy Policy document | P0 | 🔲 |
| In-app TOS acceptance flow | P0 | 🔲 |
| DMCA contact process | P1 | 🔲 |
| Report content feature | P2 | 🔲 |

---

# Appendix: Agent Workflow Specifications

## A.1 Agent System for Heirloom

```
┌─────────────────────────────────────────────────────────────────┐
│                HEIRLOOM AGENT ECOSYSTEM                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌───────────────────────────────────────────────────────┐      │
│  │                 ORCHESTRATOR AGENT                    │      │
│  │  • Route tasks to specialists                         │      │
│  │  • Track DI migration progress (52 services)          │      │
│  │  • Manage beta readiness checklist                    │      │
│  └───────────────────────────────────────────────────────┘      │
│                            │                                    │
│        ┌───────────────────┼───────────────────┐                │
│        ▼                   ▼                   ▼                │
│  ┌───────────┐       ┌───────────┐       ┌───────────┐         │
│  │  PARSER   │       │  IMPORT   │       │   TEST    │         │
│  │  AGENT    │       │  AGENT    │       │   AGENT   │         │
│  │           │       │           │       │           │         │
│  │• Ingredient│      │• URL parse│       │• Generate │         │
│  │  patterns │       │• OCR flow │       │  fixtures │         │
│  │• Unit conv│       │• Error    │       │• Run suite│         │
│  │• Scaling  │       │  handling │       │• Coverage │         │
│  └───────────┘       └───────────┘       └───────────┘         │
│        │                   │                   │                │
│        ▼                   ▼                   ▼                │
│  ┌───────────┐       ┌───────────┐       ┌───────────┐         │
│  │ LINEAGE   │       │   DI      │       │    QA     │         │
│  │  AGENT    │       │  AGENT    │       │   AGENT   │         │
│  │           │       │           │       │           │         │
│  │• Share    │       │• Convert  │       │• Beta     │         │
│  │  flows    │       │  singletons│      │  readiness│         │
│  │• Deep link│       │• Protocol │       │• Ship/no  │         │
│  │• CRDT ops │       │  abstract │       │  ship     │         │
│  └───────────┘       └───────────┘       └───────────┘         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## A.2 Agent Specifications

### Parser Agent

```yaml
name: ParserAgent
purpose: Maintain and improve ingredient parsing

capabilities:
  - Analyze parsing failures
  - Add new unit aliases
  - Improve fraction handling
  - Handle regional variations

inputs:
  - Failed parse logs
  - User edit corrections
  - New fixture requests

outputs:
  - Pattern updates
  - Unit mapping additions
  - Test fixtures

workflow_example:
  trigger: "User corrected parsed ingredient"
  steps:
    1: Analyze correction (what was wrong?)
    2: Check if pattern exists
    3: If not, propose new pattern
    4: Generate test fixture
    5: Run regression
    6: Submit PR
```

### Import Agent

```yaml
name: ImportAgent
purpose: Improve recipe import reliability

capabilities:
  - Debug URL extraction failures
  - Improve OCR post-processing
  - Handle new website formats
  - Optimize AI prompts

inputs:
  - Import failure logs
  - Website format changes
  - OCR accuracy reports

outputs:
  - SwiftSoup selector updates
  - GPT-4 prompt improvements
  - Error handling improvements
```

### DI Agent

```yaml
name: DIAgent
purpose: Complete dependency injection migration

capabilities:
  - Convert singleton to protocol + implementation
  - Update call sites
  - Verify no circular dependencies
  - Generate mock implementations

progress:
  - Firebase services: 9/9 (100%)
  - Core services: 0/7 (0%)
  - AI services: 0/11 (0%)
  - Other services: 0/25 (0%)
  - Total: 9/52 (18%)

workflow_per_service:
  1: Create protocol abstraction
  2: Refactor class to implement protocol
  3: Update registration in DIContainer
  4: Update all call sites
  5: Create mock for testing
  6: Write unit tests
  7: Verify no regressions
```

### Lineage Agent

```yaml
name: LineageAgent
purpose: Ensure sharing and lineage features work correctly

capabilities:
  - Test share flows end-to-end
  - Verify lineage graph integrity
  - Debug deep link handling
  - Test CRDT conflict resolution

test_scenarios:
  - Single share, single accept
  - Single share, multiple accepts
  - Chain of shares (A→B→C)
  - Concurrent modifications
  - Offline modifications + sync
  - Share expiration
  - Re-sharing permissions
```

---

## Document Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2026 | Initial document |

---

*This document is a living specification. Update as implementation progresses.*
