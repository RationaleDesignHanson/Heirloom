#!/usr/bin/env node

/**
 * Verify that recipe images match the recipe data
 *
 * This script checks:
 * 1. Theme cover images exist for all themes
 * 2. Recipe images exist and match recipe titles
 * 3. No orphaned images (images without matching recipes)
 *
 * Usage: node scripts/verify-image-mapping.js
 */

const fs = require('fs');
const path = require('path');

// Paths
const THEME_COVERS_DIR = path.join(__dirname, 'theme-image-gen', 'theme-covers');
const RECIPE_IMAGES_DIR = path.join(__dirname, 'theme-image-gen', 'images');
const THEME_RECIPES_DIR = path.join(__dirname, '..', 'themerecipes');

// Theme files
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
 * Convert recipe title to slug for image filename
 */
function titleToSlug(title) {
  return title
    .toLowerCase()
    .replace(/[()]/g, '') // Remove parentheses
    .replace(/[\s/]+/g, '-') // Replace spaces and slashes with hyphens
    .replace(/[^a-z0-9-]/g, '') // Remove special characters
    .replace(/-+/g, '-') // Collapse multiple hyphens
    .replace(/^-|-$/g, ''); // Trim hyphens from edges
}

/**
 * Verify theme cover images
 */
function verifyThemeCovers() {
  console.log('📸 Verifying theme cover images...\n');

  const coverFiles = fs.readdirSync(THEME_COVERS_DIR)
    .filter(f => f.endsWith('.webp') && f.startsWith('theme-'));

  let allGood = true;

  THEME_FILES.forEach((fileName, index) => {
    const themeNum = String(index + 1).padStart(2, '0');
    const expectedCover = `theme-${themeNum}-`;

    const matchingCovers = coverFiles.filter(f => f.startsWith(expectedCover));

    if (matchingCovers.length === 0) {
      console.log(`❌ Missing cover for: ${fileName}`);
      allGood = false;
    } else if (matchingCovers.length > 1) {
      console.log(`⚠️  Multiple covers for: ${fileName}`);
      matchingCovers.forEach(f => console.log(`   - ${f}`));
      allGood = false;
    } else {
      console.log(`✅ ${matchingCovers[0]}`);
    }
  });

  console.log(allGood ? '\n✅ All theme covers verified!\n' : '\n❌ Theme cover issues found\n');
  return allGood;
}

/**
 * Verify recipe images for a single theme
 */
function verifyThemeRecipes(fileName) {
  const filePath = path.join(THEME_RECIPES_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.log(`⚠️  Theme file not found: ${fileName}\n`);
    return { missing: [], extra: [] };
  }

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const themeId = data.themeId;
  const recipes = data.recipes || [];

  console.log(`\n🍽️  Verifying ${themeId} (${recipes.length} recipes)...\n`);

  const allImageFiles = fs.readdirSync(RECIPE_IMAGES_DIR)
    .filter(f => f.endsWith('.webp'));

  const themeImageFiles = allImageFiles.filter(f => f.startsWith(`${themeId}-`));

  const missing = [];
  const found = [];

  // Check each recipe has a matching image
  recipes.forEach(recipe => {
    const titleSlug = titleToSlug(recipe.title);
    const expectedFilename = `${themeId}-${titleSlug}.webp`;

    const exists = themeImageFiles.includes(expectedFilename);

    if (exists) {
      found.push(expectedFilename);
      console.log(`  ✅ ${recipe.title}`);
      console.log(`     → ${expectedFilename}`);
    } else {
      missing.push({ recipe: recipe.title, expected: expectedFilename });
      console.log(`  ❌ MISSING: ${recipe.title}`);
      console.log(`     Expected: ${expectedFilename}`);
      console.log(`     Available images starting with "${themeId}-":`);

      // Show similar filenames to help debug
      const similar = themeImageFiles.filter(f =>
        f.toLowerCase().includes(titleSlug.substring(0, 10).toLowerCase())
      );

      if (similar.length > 0) {
        similar.forEach(f => console.log(`       → ${f}`));
      } else {
        console.log(`       (no similar filenames found)`);
      }
    }
  });

  // Check for extra images (images without matching recipes)
  const extra = themeImageFiles.filter(img => !found.includes(img));

  if (extra.length > 0) {
    console.log(`\n  ⚠️  Extra images (no matching recipe):`);
    extra.forEach(f => console.log(`     - ${f}`));
  }

  const summary = {
    theme: themeId,
    total: recipes.length,
    found: found.length,
    missing: missing,
    extra: extra
  };

  console.log(`\n  📊 Summary: ${found.length}/${recipes.length} recipes have images`);

  return summary;
}

/**
 * Main execution
 */
function main() {
  console.log('🔍 Verifying image-recipe mapping...\n');
  console.log('='.repeat(60) + '\n');

  // Step 1: Verify theme covers
  const coversOk = verifyThemeCovers();

  console.log('='.repeat(60));

  // Step 2: Verify recipe images
  const results = [];
  THEME_FILES.forEach(fileName => {
    const result = verifyThemeRecipes(fileName);
    results.push(result);
  });

  console.log('\n' + '='.repeat(60));
  console.log('\n📊 OVERALL SUMMARY\n');

  const totalMissing = results.reduce((sum, r) => sum + r.missing.length, 0);
  const totalExtra = results.reduce((sum, r) => sum + r.extra.length, 0);
  const totalRecipes = results.reduce((sum, r) => sum + r.total, 0);
  const totalFound = results.reduce((sum, r) => sum + r.found, 0);

  console.log(`Total recipes: ${totalRecipes}`);
  console.log(`Images found:  ${totalFound} ✅`);
  console.log(`Images missing: ${totalMissing} ❌`);
  console.log(`Extra images:   ${totalExtra} ⚠️`);

  if (totalMissing === 0 && totalExtra === 0 && coversOk) {
    console.log('\n✅ All images verified successfully!');
    console.log('\n💡 Ready to run:');
    console.log('   1. node scripts/cleanup-and-reseed-recipes.js');
    console.log('   2. node scripts/upload-images-to-storage.js');
  } else {
    console.log('\n⚠️  Issues found. Please fix image filenames or recipe data before uploading.');
  }
}

// Run main function
main();
