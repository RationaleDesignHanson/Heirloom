#!/usr/bin/env node

/**
 * Heritage to Theme Conversion Script
 * Converts heritage collections to theme format (12-14 recipes each)
 *
 * Usage: node convert-heritage-to-themes.js
 */

const fs = require('fs');
const path = require('path');

// Input/Output directories
const HERITAGE_DIR = path.join(__dirname, '../heritage-recipes-export');
const OUTPUT_DIR = path.join(__dirname, '../themerecipes');

// Heritage collection mapping to new theme IDs
const HERITAGE_TO_THEME_MAP = {
  'presidential-pantry': {
    themeId: 'presidential-pantry',
    themeName: 'Presidential Pantry',
    category: 'historical',
    description: 'Recipes from the White House kitchens spanning American presidents from Washington to Reagan',
    sortOrder: 11,
    recipeCount: 14
  },
  'literary-kitchen': {
    themeId: 'literary-kitchen',
    themeName: 'Literary Kitchen',
    category: 'historical',
    description: 'Dishes inspired by classic literature, from Moby-Dick to The Great Gatsby',
    sortOrder: 12,
    recipeCount: 14
  },
  'ancient-table': {
    themeId: 'ancient-table',
    themeName: 'Ancient Table',
    category: 'historical',
    description: 'Culinary treasures from Rome, Greece, Egypt, and ancient civilizations',
    sortOrder: 13,
    recipeCount: 12
  },
  'american-foundation': {
    themeId: 'american-foundation',
    themeName: 'American Foundation',
    category: 'historical',
    description: 'Colonial and early American recipes that shaped a nation\'s culinary identity',
    sortOrder: 14,
    recipeCount: 12
  }
};

/**
 * Convert heritage collection to theme format
 */
function convertToTheme(heritageData, themeConfig) {
  const recipes = heritageData.recipes
    .sort((a, b) => a.sortOrder - b.sortOrder)
    .slice(0, themeConfig.recipeCount) // Take top N recipes
    .map((recipe, index) => ({
      id: recipe.id,
      title: recipe.title,
      description: recipe.description,
      ingredients: recipe.ingredients.map(ing => ({
        name: ing.name,
        amount: ing.amount || null,
        unit: ing.unit || null,
        preparation: null,
        notes: ing.group || null,
        isOptional: ing.isOptional
      })),
      instructions: recipe.instructions,
      prepTime: recipe.prepTime,
      cookTime: recipe.cookTime,
      servings: recipe.servings,
      difficulty: recipe.difficulty,
      tags: recipe.tags,
      source: recipe.source,
      story: recipe.story,
      unlockDay: index + 1, // Sequential unlock
      sortOrder: index + 1
    }));

  return {
    themeId: themeConfig.themeId,
    themeName: themeConfig.themeName,
    category: themeConfig.category,
    description: themeConfig.description,
    sortOrder: themeConfig.sortOrder,
    recipes: recipes
  };
}

/**
 * Main conversion function
 */
function main() {
  console.log('🔄 Converting heritage collections to themes...\n');

  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  let totalRecipes = 0;

  for (const [heritageId, themeConfig] of Object.entries(HERITAGE_TO_THEME_MAP)) {
    const heritageFile = path.join(HERITAGE_DIR, `heritage-${heritageId}.json`);

    if (!fs.existsSync(heritageFile)) {
      console.log(`⚠️  Heritage file not found: ${heritageFile}`);
      continue;
    }

    console.log(`\n📚 Converting ${themeConfig.themeName}...`);

    // Read heritage collection
    const heritageData = JSON.parse(fs.readFileSync(heritageFile, 'utf8'));
    console.log(`   Source: ${heritageData.recipeCount} recipes`);

    // Convert to theme format
    const themeData = convertToTheme(heritageData, themeConfig);
    console.log(`   Selected: ${themeData.recipes.length} recipes`);

    // Write theme file
    const themeNumber = String(themeConfig.sortOrder).padStart(2, '0');
    const outputFile = path.join(OUTPUT_DIR, `theme-${themeNumber}-${heritageId}.json`);
    fs.writeFileSync(outputFile, JSON.stringify(themeData, null, 2));

    console.log(`   ✓ Wrote: theme-${themeNumber}-${heritageId}.json`);

    // List recipe titles
    console.log(`\n   Selected recipes:`);
    themeData.recipes.forEach((recipe, i) => {
      console.log(`     ${i + 1}. ${recipe.title}`);
    });

    totalRecipes += themeData.recipes.length;
  }

  console.log('\n📊 Conversion Summary:');
  console.log(`   Themes created: ${Object.keys(HERITAGE_TO_THEME_MAP).length}`);
  console.log(`   Total recipes: ${totalRecipes}`);

  console.log('\n✅ Conversion complete!');
  console.log(`\n📍 Theme files created in: ${OUTPUT_DIR}`);
  console.log('\n🎯 Next Steps:');
  console.log('   1. Review the converted theme files');
  console.log('   2. Update seed-recipes.js to include the new theme mappings');
  console.log('   3. Generate theme cover images (14 total)');
  console.log('   4. Generate recipe images for heritage recipes (52 total)');
  console.log('   5. Run: npm run seed-recipes to upload to Firebase');
  console.log('   6. Run: npm run upload-images to upload images');
}

// Run conversion
try {
  main();
} catch (error) {
  console.error('❌ Conversion failed:', error);
  console.error(error.stack);
  process.exit(1);
}
