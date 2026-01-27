#!/usr/bin/env node

/**
 * Fix recipe IDs in themes 11-14 to match convention
 *
 * Changes:
 * - presidential-001 → presidential-pantry-001
 * - literary-001 → literary-kitchen-001
 * - ancient-001 → ancient-table-001
 * - american-001 → american-foundation-001
 */

const fs = require('fs');
const path = require('path');

const THEME_RECIPES_DIR = path.join(__dirname, '..', 'themerecipes');

const fixes = [
  {
    file: 'theme-11-presidential-pantry.json',
    themeId: 'presidential-pantry',
    oldPrefix: 'presidential-',
    newPrefix: 'presidential-pantry-'
  },
  {
    file: 'theme-12-literary-kitchen.json',
    themeId: 'literary-kitchen',
    oldPrefix: 'literary-',
    newPrefix: 'literary-kitchen-'
  },
  {
    file: 'theme-13-ancient-table.json',
    themeId: 'ancient-table',
    oldPrefix: 'ancient-',
    newPrefix: 'ancient-table-'
  },
  {
    file: 'theme-14-american-foundation.json',
    themeId: 'american-foundation',
    oldPrefix: 'american-',
    newPrefix: 'american-foundation-'
  }
];

console.log('🔧 Fixing recipe IDs in heritage themes...\n');

fixes.forEach(({ file, themeId, oldPrefix, newPrefix }) => {
  const filePath = path.join(THEME_RECIPES_DIR, file);

  if (!fs.existsSync(filePath)) {
    console.log(`⚠️  File not found: ${file}`);
    return;
  }

  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  console.log(`📝 Processing ${file}...`);
  console.log(`   Theme ID: ${themeId}`);
  console.log(`   Recipes: ${data.recipes.length}`);

  let changedCount = 0;

  data.recipes.forEach(recipe => {
    if (recipe.id.startsWith(oldPrefix) && !recipe.id.startsWith(newPrefix)) {
      const oldId = recipe.id;
      recipe.id = recipe.id.replace(oldPrefix, newPrefix);
      console.log(`   ✓ ${oldId} → ${recipe.id}`);
      changedCount++;
    }
  });

  // Write back to file
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');

  console.log(`   ✅ Updated ${changedCount} recipe IDs\n`);
});

console.log('✅ All heritage theme recipe IDs fixed!');
console.log('\n💡 Now run: node cleanup-and-reseed-recipes.js');
