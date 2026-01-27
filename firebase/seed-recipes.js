#!/usr/bin/env node

/**
 * Recipe Seeding Script
 * Seeds recipes from JSON files to Firestore under /themes/{themeId}/recipes/
 *
 * Usage: node seed-recipes.js [theme-id]
 * Example: node seed-recipes.js automat-classics
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

// Path to recipe JSON files
const RECIPES_DIR = path.join(__dirname, '../themerecipes');

/**
 * Map theme file names to Firebase theme IDs
 */
const THEME_FILE_MAP = {
  'theme-01-automat-classics.json': 'automat-classics',
  'theme-02-railroad-dining.json': 'railroad-dining',
  'theme-03-victory-kitchen.json': 'victory-kitchen',
  'theme-04-navy-mess.json': 'navy-mess',
  'theme-05-boston-cooking.json': 'boston-cooking-school',
  'theme-06-southern-roots.json': 'southern-roots',
  'theme-07-scandinavian.json': 'scandinavian-heritage',
  'theme-08-german-american.json': 'german-american',
  'theme-09-quick-weeknight.json': 'quick-weeknight',
  'theme-10-sunday-suppers.json': 'sunday-suppers',
  'theme-11-presidential-pantry.json': 'presidential-pantry',
  'theme-12-literary-kitchen.json': 'literary-kitchen',
  'theme-13-ancient-table.json': 'ancient-table',
  'theme-14-american-foundation.json': 'american-foundation'
};

/**
 * Format ingredient text from structured data
 */
function formatIngredient(ing) {
  let text = '';

  if (ing.amount) {
    // Format amount (handle decimals nicely)
    const amount = ing.amount % 1 === 0 ? ing.amount : ing.amount.toString();
    text += amount;
  }

  if (ing.unit) {
    text += ` ${ing.unit}`;
  }

  text += ` ${ing.name}`;

  if (ing.preparation) {
    text += `, ${ing.preparation}`;
  }

  if (ing.notes) {
    text += ` (${ing.notes})`;
  }

  return text.trim();
}

/**
 * Load recipes from JSON files
 */
function loadRecipes(targetThemeId = null) {
  const recipes = {};

  const files = fs.readdirSync(RECIPES_DIR)
    .filter(f => f.endsWith('.json'));

  for (const file of files) {
    const firebaseId = THEME_FILE_MAP[file];

    if (!firebaseId) {
      console.warn(`⚠️  No mapping for file: ${file}`);
      continue;
    }

    // Skip if targeting specific theme
    if (targetThemeId && firebaseId !== targetThemeId) {
      continue;
    }

    const filePath = path.join(RECIPES_DIR, file);
    const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

    recipes[firebaseId] = {
      themeName: data.themeName,
      recipes: data.recipes
    };
  }

  return recipes;
}

/**
 * Seed recipes for a specific theme or all themes
 */
async function seedRecipes(targetThemeId = null) {
  console.log('🔥 Starting recipe seeding...\n');

  const recipesByTheme = loadRecipes(targetThemeId);

  if (Object.keys(recipesByTheme).length === 0) {
    console.error('❌ No recipes found to seed');
    process.exit(1);
  }

  let totalRecipes = 0;
  let successCount = 0;
  let errorCount = 0;

  for (const [themeId, themeData] of Object.entries(recipesByTheme)) {
    const recipes = themeData.recipes;

    console.log(`\n📚 Seeding ${recipes.length} recipes for theme: ${themeData.themeName} (${themeId})`);

    // Use batched writes (max 500 operations per batch)
    // Each recipe needs: 1 recipe doc + ingredients + instructions
    // We'll process recipes one at a time to stay under batch limits

    for (const recipe of recipes) {
      try {
        const batch = db.batch();
        const recipeRef = db.collection('themes').doc(themeId).collection('recipes').doc(recipe.id);

        // Build recipe document with ingredients and instructions as arrays
        const recipeDoc = {
          title: recipe.title,
          description: recipe.description || '',
          prepTime: recipe.prepTime || 0,
          cookTime: recipe.cookTime || 0,
          servings: recipe.servings || 4,
          difficulty: recipe.difficulty || 'medium',
          unlockDay: recipe.unlockDay || 1,
          sortOrder: recipe.sortOrder || 1,
          tags: recipe.tags || [],
          source: recipe.source || '',
          story: recipe.story || '',
          // Use Firebase Storage API format (like heritage recipes)
          imageURL: `https://firebasestorage.googleapis.com/v0/b/heirloom-ios-prod.firebasestorage.app/o/recipes%2F${themeId}%2F${recipe.id}.webp?alt=media`,
          // Store ingredients and instructions as arrays in the document
          ingredients: recipe.ingredients || [],
          instructions: recipe.instructions || [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };

        batch.set(recipeRef, recipeDoc);

        await batch.commit();

        console.log(`  ✓ Seeded: ${recipe.title} (Day ${recipe.unlockDay})`);
        successCount++;
        totalRecipes++;

      } catch (error) {
        console.error(`  ✗ Error seeding ${recipe.title}:`, error.message);
        errorCount++;
      }
    }

    console.log(`  ✅ Completed ${themeData.themeName}: ${recipes.length} recipes`);
  }

  console.log('\n📊 Seeding Summary:');
  console.log(`   - Total recipes: ${totalRecipes}`);
  console.log(`   - Successfully seeded: ${successCount}`);
  console.log(`   - Failed: ${errorCount}`);

  if (successCount > 0) {
    console.log('\n✅ Recipe seeding complete!');
    console.log('\n🎯 Next Steps:');
    console.log('   1. Verify recipes in Firebase Console: https://console.firebase.google.com');
    console.log('   2. Test unlock flow in the app');
    console.log('   3. Generate recipe images if needed');
  }

  process.exit(errorCount > 0 ? 1 : 0);
}

// Parse command line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const targetThemeId = args.find(arg => !arg.startsWith('--'));

if (isDryRun) {
  console.log('🧪 DRY RUN MODE - No data will be uploaded\n');
}

if (targetThemeId) {
  console.log(`🎯 Targeting specific theme: ${targetThemeId}\n`);
} else {
  console.log('🌍 Seeding all themes\n');
}

// Dry run validation
if (isDryRun) {
  console.log('=== Validating Schema ===\n');

  try {
    const recipesByTheme = loadRecipes(targetThemeId);

    if (Object.keys(recipesByTheme).length === 0) {
      console.error('❌ No recipes found to validate');
      process.exit(1);
    }

    let totalRecipes = 0;
    let errors = [];

    for (const [themeId, themeData] of Object.entries(recipesByTheme)) {
      const recipes = themeData.recipes;
      console.log(`\n📚 ${themeData.themeName} (${themeId}): ${recipes.length} recipes`);

      for (const recipe of recipes) {
        // Validate required fields
        if (!recipe.id) errors.push(`  ❌ ${themeId}: Recipe missing 'id'`);
        if (!recipe.title) errors.push(`  ❌ ${themeId}/${recipe.id}: Missing 'title'`);
        if (!recipe.description) errors.push(`  ❌ ${themeId}/${recipe.id}: Missing 'description'`);
        if (!recipe.ingredients || !Array.isArray(recipe.ingredients)) {
          errors.push(`  ❌ ${themeId}/${recipe.id}: Missing or invalid 'ingredients'`);
        }
        if (!recipe.instructions || !Array.isArray(recipe.instructions)) {
          errors.push(`  ❌ ${themeId}/${recipe.id}: Missing or invalid 'instructions'`);
        }
        if (typeof recipe.unlockDay !== 'number') {
          errors.push(`  ❌ ${themeId}/${recipe.id}: Missing or invalid 'unlockDay'`);
        }
        if (typeof recipe.sortOrder !== 'number') {
          errors.push(`  ❌ ${themeId}/${recipe.id}: Missing or invalid 'sortOrder'`);
        }

        // Show recipe summary
        console.log(`  ✓ ${recipe.title}`);
        console.log(`    - Ingredients: ${recipe.ingredients?.length || 0}`);
        console.log(`    - Instructions: ${recipe.instructions?.length || 0}`);
        console.log(`    - Unlock Day: ${recipe.unlockDay}`);
        console.log(`    - Difficulty: ${recipe.difficulty}`);

        totalRecipes++;
      }
    }

    console.log('\n=== Validation Summary ===');
    console.log(`✅ Total recipes validated: ${totalRecipes}`);

    if (errors.length > 0) {
      console.log(`\n❌ Found ${errors.length} errors:`);
      errors.forEach(err => console.log(err));
      process.exit(1);
    } else {
      console.log('✅ All recipes valid!');
      console.log('\n🎯 Ready to seed. Run without --dry-run to upload.');
    }

    process.exit(0);

  } catch (error) {
    console.error('❌ Validation failed:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the seeding script
seedRecipes(targetThemeId).catch((error) => {
  console.error('❌ Fatal error:', error);
  console.error(error.stack);
  process.exit(1);
});
