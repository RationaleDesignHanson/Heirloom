#!/usr/bin/env node

/**
 * Fix ingredient format in theme JSON files
 * Parses "2 1/2 lb beef shin" into { amount: 2.5, unit: "lb", name: "beef shin" }
 */

const fs = require('fs');
const path = require('path');

const THEME_RECIPES_DIR = path.join(__dirname, '..', 'themerecipes');

// Theme files that need fixing (15-24)
const THEME_FILES = [
  'theme-15-classic-literature.json',
  'theme-16-childrens-stories.json',
  'theme-17-fantasy-scifi.json',
  'theme-18-crime-cult-classics.json',
  'theme-19-magical-realism.json',
  'theme-20-romance-indulgence.json',
  'theme-21-dystopian-fiction.json',
  'theme-22-film-tv-favourites.json',
  'theme-23-feasts-banquets.json',
  'theme-24-cocktails-confections.json'
];

// Common units to recognize
const UNITS = [
  'lb', 'lbs', 'pound', 'pounds',
  'oz', 'ounce', 'ounces',
  'cup', 'cups',
  'tablespoon', 'tablespoons', 'tbsp',
  'teaspoon', 'teaspoons', 'tsp',
  'quart', 'quarts', 'qt',
  'pint', 'pints', 'pt',
  'gallon', 'gallons', 'gal',
  'ml', 'milliliter', 'milliliters',
  'l', 'liter', 'liters',
  'g', 'gram', 'grams',
  'kg', 'kilogram', 'kilograms',
  'bunch', 'bunches',
  'clove', 'cloves',
  'slice', 'slices',
  'piece', 'pieces',
  'sprig', 'sprigs',
  'head', 'heads',
  'stalk', 'stalks',
  'can', 'cans',
  'bottle', 'bottles',
  'jar', 'jars',
  'package', 'packages', 'pkg',
  'pinch', 'pinches',
  'dash', 'dashes',
  'drop', 'drops',
  'cube', 'cubes',
  'strip', 'strips',
  'sheet', 'sheets',
  'stick', 'sticks',
  'large', 'medium', 'small'  // Size descriptors that act as units
];

// Fraction mappings
const FRACTIONS = {
  '1/4': 0.25,
  '1/3': 0.333,
  '1/2': 0.5,
  '2/3': 0.667,
  '3/4': 0.75,
  '1/8': 0.125,
  '3/8': 0.375,
  '5/8': 0.625,
  '7/8': 0.875
};

function parseFraction(str) {
  // Handle mixed numbers like "2 1/2"
  const mixedMatch = str.match(/^(\d+)\s+(\d+\/\d+)$/);
  if (mixedMatch) {
    const whole = parseInt(mixedMatch[1]);
    const frac = FRACTIONS[mixedMatch[2]] || 0;
    return whole + frac;
  }

  // Handle simple fractions like "1/2"
  if (FRACTIONS[str]) {
    return FRACTIONS[str];
  }

  // Handle decimals and integers
  const num = parseFloat(str);
  return isNaN(num) ? null : num;
}

function parseIngredient(ingredientText) {
  if (!ingredientText || typeof ingredientText !== 'string') {
    return { name: ingredientText || '' };
  }

  let text = ingredientText.trim();
  let amount = null;
  let unit = null;
  let name = '';
  let preparation = null;
  let group = null;

  // Check for preparation instructions (after comma)
  const commaIndex = text.indexOf(',');
  if (commaIndex > 0) {
    const afterComma = text.substring(commaIndex + 1).trim();
    // Only treat as preparation if it looks like an instruction
    if (afterComma.match(/^(cut|sliced|diced|chopped|minced|grated|shredded|crushed|peeled|melted|softened|warmed|chilled|room temperature|to taste|for garnish|optional)/i)) {
      preparation = afterComma;
      text = text.substring(0, commaIndex).trim();
    }
  }

  // Try to extract amount at the start
  // Pattern: number (possibly with fraction) followed by unit
  const amountPattern = /^((?:\d+\s+)?\d+\/\d+|\d+\.?\d*)\s*/;
  const amountMatch = text.match(amountPattern);

  if (amountMatch) {
    const amountStr = amountMatch[1].trim();
    amount = parseFraction(amountStr);
    text = text.substring(amountMatch[0].length).trim();

    // Now try to find unit
    const words = text.split(/\s+/);
    const firstWord = words[0]?.toLowerCase();

    // Check if first word is a unit
    if (firstWord && UNITS.some(u => firstWord === u || firstWord === u + 's' || firstWord.startsWith(u))) {
      unit = words[0];
      text = words.slice(1).join(' ').trim();
    }
  }

  // Handle parenthetical notes like "(750 ml)"
  const parenMatch = text.match(/\(([^)]+)\)/);
  if (parenMatch && !preparation) {
    // Check if it's a measurement
    const parenContent = parenMatch[1];
    if (parenContent.match(/\d+\s*(ml|l|g|kg|oz|lb)/i)) {
      // It's an alternative measurement, keep it in the name
    } else {
      // It might be a note
      preparation = preparation ? `${preparation}, ${parenContent}` : parenContent;
      text = text.replace(/\([^)]+\)/, '').trim();
    }
  }

  name = text;

  // Clean up name - remove leading "of" if present
  name = name.replace(/^of\s+/i, '').trim();

  const result = { name };
  if (amount !== null) result.amount = amount;
  if (unit) result.unit = unit;
  if (preparation) result.preparation = preparation;
  if (group) result.group = group;

  return result;
}

function processThemeFile(filename) {
  const filePath = path.join(THEME_RECIPES_DIR, filename);

  if (!fs.existsSync(filePath)) {
    console.log(`⚠️  File not found: ${filename}`);
    return;
  }

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  let totalFixed = 0;

  for (const recipe of data.recipes) {
    if (!recipe.ingredients) continue;

    const newIngredients = [];
    for (const ing of recipe.ingredients) {
      // Check if ingredient needs parsing (only has 'name' field with embedded amounts)
      if (ing.name && !ing.amount && !ing.unit) {
        // Check if name contains a number (needs parsing)
        if (ing.name.match(/^\d/)) {
          const parsed = parseIngredient(ing.name);
          newIngredients.push(parsed);
          totalFixed++;
        } else {
          // No number at start, keep as-is
          newIngredients.push(ing);
        }
      } else {
        // Already properly formatted
        newIngredients.push(ing);
      }
    }
    recipe.ingredients = newIngredients;
  }

  // Write back
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
  console.log(`✅ ${filename}: Fixed ${totalFixed} ingredients`);
}

console.log('🔧 Fixing ingredient format in theme files...\n');

for (const file of THEME_FILES) {
  processThemeFile(file);
}

console.log('\n✅ Done! Now run: node scripts/cleanup-and-reseed-recipes.js');
