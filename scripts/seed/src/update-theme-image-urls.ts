/**
 * Update Firestore with existing theme recipe image URLs
 *
 * This script assumes images are already uploaded to Firebase Storage
 * and just updates Firestore documents with the correct URLs.
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();

// Missing recipes by theme
interface MissingRecipe {
  themeId: string;
  recipeId: string;
  title: string;
}

const MISSING_RECIPES: MissingRecipe[] = [
  // Presidential Pantry (015-025)
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-015', title: "Herbert Hoover's Waldorf Salad" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-016', title: "Ulysses S. Grant's Rice Pudding" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-017', title: "William Howard Taft's Steak" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-018', title: "Benjamin Harrison's Corn Relish" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-019', title: "Rutherford B. Hayes' Mashed Potatoes" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-020', title: "James Buchanan's Sauerkraut" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-021', title: "Grover Cleveland's Corned Beef Hash" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-022', title: "Chester Arthur's Lobster Newburg" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-023', title: "Millard Fillmore's Apple Dumplings" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-024', title: "Franklin Pierce's Rum Punch" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-025', title: "William McKinley's Gingerbread Cookies" },

  // Literary Kitchen (015-025)
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-015', title: "Oliver Twist's Gruel" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-016', title: "The Hobbit's Seed-cakes" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-017', title: "Proust's Madeleines" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-018', title: "James Bond's Vesper Martini" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-019', title: "The Bell Jar's Avocado Pear" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-020', title: "Don Quixote's Olla Podrida" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-021', title: "The Old Man and the Sea's Fried Dolphinfish" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-022', title: "Emma's Wedding Cake" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-023', title: "The Grapes of Wrath's Biscuits" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-024', title: "Babette's Feast Blinis" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-025', title: "Catch-22's Chocolate Covered Cotton Candy" },

  // Ancient Table (013-025)
  { themeId: 'ancient-table', recipeId: 'ancient-table-013', title: 'Phoenician Fish Stew' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-014', title: 'Carthaginian Couscous' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-015', title: 'Etruscan Polenta' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-016', title: 'Sumerian Date Cake' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-017', title: 'Chinese Jiaozi Dumplings' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-018', title: 'Viking Smoked Fish' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-019', title: 'Celtic Oat Porridge' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-020', title: 'Aztec Chocolate Drink' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-021', title: 'Inca Quinoa Soup' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-022', title: 'Medieval Pottage' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-023', title: 'Roman Puls' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-024', title: 'Greek Symposium Wine' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-025', title: 'Babylonian Beer' },

  // American Foundation (013-025)
  { themeId: 'american-foundation', recipeId: 'american-foundation-013', title: 'Samp and Beans' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-014', title: 'Rye and Injun Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-015', title: 'Pone' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-016', title: 'Flummery' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-017', title: 'Persimmon Pudding' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-018', title: 'Hominy Grits' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-019', title: 'Shrub (Colonial Fruit Drink)' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-020', title: 'Indian Pudding' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-021', title: 'Corn Oysters' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-022', title: 'Anadama Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-023', title: 'Sally Lunn Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-024', title: 'Ash Cakes' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-025', title: 'Spider Corn Cake' },
];

/**
 * Update Firestore recipe document with image URL
 */
async function updateFirestoreRecipe(
  themeId: string,
  recipeId: string,
  imageUrl: string
): Promise<void> {
  const recipeRef = db.collection('themes').doc(themeId).collection('recipes').doc(recipeId);

  await recipeRef.update({
    imageURL: imageUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`  Updated Firestore: ${recipeId}`);
}

/**
 * Update ID mapping file
 */
function updateIdMapping(newMappings: Array<{ themeId: string; recipeId: string; title: string; slug: string }>): void {
  const mappingPath = path.resolve(__dirname, '../../theme-image-gen/id_conversion_mapping.json');

  const existingData = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));

  // Get existing recipe IDs to avoid duplicates
  const existingIds = new Set(existingData.conversions.map((c: any) => c.new_id));

  let addedCount = 0;
  for (const mapping of newMappings) {
    if (!existingIds.has(mapping.recipeId)) {
      existingData.conversions.push({
        theme_id: mapping.themeId,
        theme_name: mapping.themeId.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
        old_id: mapping.slug,
        new_id: mapping.recipeId,
        title: mapping.title,
        sort_order: parseInt(mapping.recipeId.split('-').pop() || '0'),
      });
      addedCount++;
    }
  }

  existingData.total_recipes = existingData.conversions.length;

  fs.writeFileSync(mappingPath, JSON.stringify(existingData, null, 2));
  console.log(`\nUpdated ${mappingPath} with ${addedCount} new entries`);
}

/**
 * Main execution
 */
async function main(): Promise<void> {
  console.log('📝 Updating Firestore with Theme Recipe Image URLs\n');
  console.log(`Total recipes to update: ${MISSING_RECIPES.length}\n`);

  const newMappings: Array<{ themeId: string; recipeId: string; title: string; slug: string }> = [];
  let successCount = 0;
  let errorCount = 0;

  for (const recipe of MISSING_RECIPES) {
    try {
      console.log(`[${successCount + errorCount + 1}/${MISSING_RECIPES.length}] ${recipe.title}`);

      // Extract slug from recipe ID (e.g., "015" from "presidential-pantry-015")
      const slug = recipe.recipeId.split('-').pop() || recipe.recipeId;

      // Construct the storage URL (images already exist)
      const storageUrl = `https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/recipes/${recipe.themeId}/${recipe.themeId}-${slug}.webp`;

      // Update Firestore recipe document
      await updateFirestoreRecipe(recipe.themeId, recipe.recipeId, storageUrl);

      // Record for mapping update
      newMappings.push({
        themeId: recipe.themeId,
        recipeId: recipe.recipeId,
        title: recipe.title,
        slug: slug,
      });

      console.log(`  ✅ URL: ${storageUrl}`);
      successCount++;

    } catch (error) {
      console.error(`  ❌ Error updating ${recipe.recipeId}:`, error);
      errorCount++;
    }
  }

  // Update ID mapping file
  if (newMappings.length > 0) {
    updateIdMapping(newMappings);
  }

  console.log('\n========================================');
  console.log(`✅ Success: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log('========================================\n');
}

// Run
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
