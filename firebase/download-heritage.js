#!/usr/bin/env node

/**
 * Heritage Recipe Download Script
 * Downloads existing heritage recipes from Firebase for review/conversion
 *
 * Usage: node download-heritage.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Output directory
const OUTPUT_DIR = path.join(__dirname, '../heritage-recipes-export');

/**
 * Download all heritage recipes
 */
async function downloadHeritageRecipes() {
  console.log('📥 Downloading heritage recipes from Firebase...\n');

  // Create output directory
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  try {
    // Get all documents from heritage_recipes collection
    const snapshot = await db.collection('heritage_recipes').get();

    if (snapshot.empty) {
      console.log('⚠️  No heritage recipes found in Firebase');
      return;
    }

    console.log(`Found ${snapshot.size} heritage recipes\n`);

    // Group recipes by collection
    const recipesByCollection = {};

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const recipeId = doc.id;

      // Get collection ID (if available)
      const collectionId = data.heritageCollectionId || data.collectionId || 'uncategorized';

      if (!recipesByCollection[collectionId]) {
        recipesByCollection[collectionId] = {
          collectionId: collectionId,
          collectionName: data.heritageCollectionName || collectionId,
          recipes: []
        };
      }

      // Get ingredients subcollection
      let ingredients = [];
      try {
        const ingredientsSnapshot = await doc.ref.collection('ingredients').orderBy('order').get();
        ingredients = ingredientsSnapshot.docs.map(ingDoc => ({
          text: ingDoc.data().text,
          name: ingDoc.data().name,
          amount: ingDoc.data().amount,
          unit: ingDoc.data().unit,
          group: ingDoc.data().group,
          isOptional: ingDoc.data().isOptional || false,
          order: ingDoc.data().order
        }));
      } catch (error) {
        console.log(`  ⚠️  No ingredients for ${recipeId}`);
      }

      // Get instructions subcollection
      let instructions = [];
      try {
        const instructionsSnapshot = await doc.ref.collection('instructions').orderBy('order').get();
        instructions = instructionsSnapshot.docs.map(instDoc => instDoc.data().text);
      } catch (error) {
        console.log(`  ⚠️  No instructions for ${recipeId}`);
      }

      // Build recipe object
      const recipe = {
        id: recipeId,
        title: data.title,
        description: data.description || '',
        prepTime: data.prepTime || 0,
        cookTime: data.cookTime || 0,
        servings: data.servings || 4,
        difficulty: data.difficulty || 'medium',
        unlockDay: data.unlockDay || 1,
        sortOrder: data.sortOrder || 1,
        tags: data.tags || [],
        source: data.source || '',
        story: data.story || '',
        ingredients: ingredients,
        instructions: instructions
      };

      recipesByCollection[collectionId].recipes.push(recipe);

      console.log(`  ✓ Downloaded: ${data.title} (${collectionId})`);
    }

    // Write each collection to a separate JSON file
    console.log('\n📝 Writing files...\n');

    for (const [collectionId, collectionData] of Object.entries(recipesByCollection)) {
      const filename = `heritage-${collectionId}.json`;
      const filepath = path.join(OUTPUT_DIR, filename);

      // Sort recipes by sortOrder
      collectionData.recipes.sort((a, b) => a.sortOrder - b.sortOrder);

      const output = {
        collectionId: collectionId,
        collectionName: collectionData.collectionName,
        recipeCount: collectionData.recipes.length,
        recipes: collectionData.recipes
      };

      fs.writeFileSync(filepath, JSON.stringify(output, null, 2));

      console.log(`  ✓ Wrote ${collectionData.recipes.length} recipes to ${filename}`);
    }

    // Create a summary file
    const summary = {
      exportDate: new Date().toISOString(),
      totalRecipes: snapshot.size,
      collections: Object.entries(recipesByCollection).map(([id, data]) => ({
        id: id,
        name: data.collectionName,
        recipeCount: data.recipes.length,
        filename: `heritage-${id}.json`
      }))
    };

    fs.writeFileSync(
      path.join(OUTPUT_DIR, '_summary.json'),
      JSON.stringify(summary, null, 2)
    );

    console.log('\n✅ Heritage recipes exported successfully!');
    console.log(`\n📍 Exported to: ${OUTPUT_DIR}`);
    console.log('\n🎯 Next Steps:');
    console.log('   1. Review the exported recipes');
    console.log('   2. Identify which collections could become themes');
    console.log('   3. Use existing images as reference for new theme images');
    console.log('   4. Generate matching image prompts for the new themes');

  } catch (error) {
    console.error('❌ Error downloading heritage recipes:', error);
    console.error(error.stack);
    process.exit(1);
  }

  process.exit(0);
}

// Run the download
downloadHeritageRecipes().catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
