#!/usr/bin/env node

/**
 * Download heritage recipes from Firebase heritage_recipes collection
 * and convert to theme JSON format for themes 11-14
 * Heritage recipes store ingredients/instructions as arrays in the document
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Map heritage collection IDs to theme IDs
const HERITAGE_TO_THEME_MAP = {
  'presidential-pantry': { themeId: 'presidential-pantry', fileName: 'theme-11-presidential-pantry.json', themeName: 'Presidential Pantry' },
  'literary-kitchen': { themeId: 'literary-kitchen', fileName: 'theme-12-literary-kitchen.json', themeName: 'Literary Kitchen' },
  'ancient-table': { themeId: 'ancient-table', fileName: 'theme-13-ancient-table.json', themeName: 'Ancient Table' },
  'american-foundation': { themeId: 'american-foundation', fileName: 'theme-14-american-foundation.json', themeName: 'American Foundation' }
};

/**
 * Parse ingredient string or object to structured format
 */
function parseIngredient(ing) {
  if (typeof ing === 'string') {
    // Simple string like "1 cup flour"
    return { name: ing };
  }

  return {
    name: ing.name || ing.ingredient || '',
    amount: ing.amount || ing.quantity,
    unit: ing.unit,
    group: ing.group,
    isOptional: ing.isOptional || false
  };
}

async function downloadHeritageRecipes() {
  console.log('📥 Downloading heritage recipes from Firebase...\n');

  try {
    // Download all heritage recipes
    const heritageSnapshot = await db.collection('heritage_recipes').get();

    console.log(`Found ${heritageSnapshot.size} heritage recipes\n`);

    // Group recipes by collection
    const recipesByCollection = {};

    for (const doc of heritageSnapshot.docs) {
      const recipe = doc.data();
      const collectionId = recipe.collectionId || recipe.heritageCollectionId;

      if (!collectionId || !HERITAGE_TO_THEME_MAP[collectionId]) {
        console.log(`⚠️  Skipping recipe ${doc.id} - unknown collection: ${collectionId}`);
        continue;
      }

      if (!recipesByCollection[collectionId]) {
        recipesByCollection[collectionId] = [];
      }

      // Get ingredients from document array
      const ingredients = (recipe.ingredients || []).map(parseIngredient);

      // Get instructions from document array
      const instructions = recipe.instructions || [];

      // Convert to theme recipe format
      const themeRecipe = {
        id: `${HERITAGE_TO_THEME_MAP[collectionId].themeId}-${String(recipesByCollection[collectionId].length + 1).padStart(3, '0')}`,
        title: recipe.title,
        description: recipe.description || recipe.notes || recipe.historicalText || '',
        prepTime: recipe.prepTime || 0,
        cookTime: recipe.cookTime || 0,
        servings: recipe.servings || 4,
        difficulty: recipe.difficulty || 'medium',
        unlockDay: recipe.unlockDay || 1,
        sortOrder: recipesByCollection[collectionId].length + 1,
        tags: recipe.tags || [],
        source: recipe.sourceAttribution || recipe.sourceStory || recipe.source || '',
        story: recipe.historicalContext || recipe.historicalText || recipe.story || '',
        ingredients: ingredients,
        instructions: instructions
      };

      recipesByCollection[collectionId].push(themeRecipe);
      console.log(`  ✓ Downloaded: ${recipe.title} (${collectionId}) - ${ingredients.length} ingredients, ${instructions.length} instructions`);
    }

    // Write each collection to JSON file
    const outputDir = path.join(__dirname, '../themerecipes');

    for (const [collectionId, recipes] of Object.entries(recipesByCollection)) {
      const themeInfo = HERITAGE_TO_THEME_MAP[collectionId];

      const themeData = {
        themeId: themeInfo.themeId,
        themeName: themeInfo.themeName,
        recipes: recipes.sort((a, b) => a.sortOrder - b.sortOrder)
      };

      const outputPath = path.join(outputDir, themeInfo.fileName);
      fs.writeFileSync(outputPath, JSON.stringify(themeData, null, 2));

      console.log(`\n✅ Saved ${recipes.length} recipes to: ${themeInfo.fileName}`);
    }

    console.log('\n🎉 Heritage recipe download complete!');

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

downloadHeritageRecipes();
