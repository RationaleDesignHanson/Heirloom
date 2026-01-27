#!/usr/bin/env node

/**
 * Clean up duplicate recipes and re-seed from JSON files
 *
 * This script:
 * 1. Deletes ALL recipe subcollections from Firestore themes
 * 2. Re-seeds from local JSON files with correct IDs
 * 3. Uses imageURL paths that match the generated images
 *
 * Usage: node scripts/cleanup-and-reseed-recipes.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('./firebase/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Theme JSON files directory
const THEME_RECIPES_DIR = path.join(__dirname, '..', 'themerecipes');

// Load ID conversion mapping
const idMappingPath = path.join(__dirname, 'theme-image-gen', 'id_conversion_mapping.json');
const idMappingData = JSON.parse(fs.readFileSync(idMappingPath, 'utf8'));

// Create lookup map: new_id -> old_id (image filename slug)
const recipeIdToImageSlug = {};
idMappingData.conversions.forEach(conv => {
  recipeIdToImageSlug[conv.new_id] = conv.old_id;
});

console.log(`Loaded ${Object.keys(recipeIdToImageSlug).length} recipe ID mappings\n`);

// Theme ID mapping from JSON file names
const THEME_FILES = [
  'theme-01-automat-classics.json',
  'theme-02-railroad-dining.json',
  'theme-03-victory-kitchen.json',
  'theme-04-navy-mess.json',
  'theme-05-boston-cooking.json',
  'theme-06-southern-roots.json',
  'theme-07-scandinavian.json',
  'theme-08-german-american.json',
  'theme-09-quick-weeknight.json',
  'theme-10-sunday-suppers.json',
  'theme-11-presidential-pantry.json',
  'theme-12-literary-kitchen.json',
  'theme-13-ancient-table.json',
  'theme-14-american-foundation.json'
];

/**
 * Delete all recipe subcollections for a theme
 */
async function deleteRecipes(themeId) {
  console.log(`  🗑️  Deleting existing recipes for ${themeId}...`);

  const recipesRef = db.collection('themes').doc(themeId).collection('recipes');
  const snapshot = await recipesRef.get();

  if (snapshot.empty) {
    console.log(`  ✓ No recipes to delete for ${themeId}`);
    return;
  }

  const batch = db.batch();
  let count = 0;

  for (const doc of snapshot.docs) {
    // Delete subcollections (ingredients, instructions)
    const ingredientsSnap = await doc.ref.collection('ingredients').get();
    ingredientsSnap.docs.forEach(ingDoc => batch.delete(ingDoc.ref));

    const instructionsSnap = await doc.ref.collection('instructions').get();
    instructionsSnap.docs.forEach(instDoc => batch.delete(instDoc.ref));

    // Delete recipe document
    batch.delete(doc.ref);
    count++;

    // Commit batch every 500 operations (Firestore limit)
    if (count % 100 === 0) {
      await batch.commit();
      console.log(`    Deleted ${count}/${snapshot.size} recipes...`);
    }
  }

  if (count % 100 !== 0) {
    await batch.commit();
  }

  console.log(`  ✓ Deleted ${count} recipes from ${themeId}`);
}

/**
 * Upload a single recipe with subcollections
 */
async function uploadRecipe(themeId, recipe, index) {
  const recipeId = recipe.id;
  const recipeRef = db.collection('themes').doc(themeId).collection('recipes').doc(recipeId);

  // Get image filename slug from mapping
  const imageSlug = recipeIdToImageSlug[recipeId];

  let imageURL = null;
  if (imageSlug) {
    imageURL = `https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/recipes/${themeId}/${themeId}-${imageSlug}.webp`;
  } else {
    console.warn(`    ⚠️  No image mapping found for ${recipeId}`);
  }

  // Create recipe document
  await recipeRef.set({
    title: recipe.title,
    description: recipe.description || recipe.story || '',
    prepTime: recipe.prepTime || null,
    cookTime: recipe.cookTime || null,
    servings: recipe.servings || null,
    source: recipe.source || null,
    story: recipe.story || null,
    difficulty: recipe.difficulty || 'medium',
    tags: recipe.tags || [],
    imageURL: imageURL,
    sortOrder: recipe.sortOrder || index + 1,
    unlockDay: recipe.unlockDay || 1,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // Upload ingredients subcollection
  if (recipe.ingredients && recipe.ingredients.length > 0) {
    const batch = db.batch();
    recipe.ingredients.forEach((ing, idx) => {
      const ingRef = recipeRef.collection('ingredients').doc();
      batch.set(ingRef, {
        name: ing.name || '',
        amount: ing.amount || null,
        unit: ing.unit || null,
        preparation: ing.preparation || null,
        group: ing.group || null,
        text: ing.text || `${ing.amount || ''} ${ing.unit || ''} ${ing.name || ''}`.trim(),
        order: idx
      });
    });
    await batch.commit();
  }

  // Upload instructions subcollection
  if (recipe.instructions && recipe.instructions.length > 0) {
    const batch = db.batch();
    recipe.instructions.forEach((instruction, idx) => {
      const instRef = recipeRef.collection('instructions').doc();
      batch.set(instRef, {
        text: instruction,
        order: idx
      });
    });
    await batch.commit();
  }
}

/**
 * Seed recipes for a single theme
 */
async function seedTheme(fileName) {
  const filePath = path.join(THEME_RECIPES_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.log(`⚠️  File not found: ${fileName}`);
    return;
  }

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const themeId = data.themeId;
  const recipes = data.recipes || [];

  console.log(`\n📚 Processing ${themeId} (${recipes.length} recipes)...`);

  // Step 1: Delete existing recipes
  await deleteRecipes(themeId);

  // Step 2: Upload new recipes
  console.log(`  📤 Uploading ${recipes.length} recipes...`);

  let uploadCount = 0;
  for (let i = 0; i < recipes.length; i++) {
    const recipe = recipes[i];
    try {
      await uploadRecipe(themeId, recipe, i);
      uploadCount++;

      if (uploadCount % 5 === 0) {
        console.log(`    Uploaded ${uploadCount}/${recipes.length} recipes...`);
      }
    } catch (error) {
      console.error(`  ✗ Failed to upload ${recipe.id}:`, error.message);
    }
  }

  console.log(`  ✅ Completed ${themeId}: ${uploadCount}/${recipes.length} recipes uploaded`);
}

/**
 * Main execution
 */
async function main() {
  console.log('🧹 Starting Firestore cleanup and re-seed...\n');

  try {
    for (const fileName of THEME_FILES) {
      await seedTheme(fileName);
    }

    console.log('\n✅ All themes processed successfully!');
    console.log('\n💡 Next steps:');
    console.log('   1. Run: node scripts/upload-images-to-storage.js');
    console.log('   2. Restart the app to download fresh recipe data');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Operation failed:', error);
    process.exit(1);
  }
}

// Run main function
main();
