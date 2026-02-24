/**
 * Fix unlockDay values in the last 4 theme JSON files
 *
 * This script ONLY modifies local JSON files.
 * It does NOT touch Firebase.
 *
 * After running, you can review the changes with:
 *   git diff themerecipes/
 *
 * Then manually run the Firebase seed when ready:
 *   node scripts/cleanup-and-reseed-recipes.js
 */

import * as fs from 'fs';
import * as path from 'path';

// Themes that need fixing (all 25 recipes currently set to unlockDay: 1)
const THEMES_TO_FIX = [
  'theme-11-presidential-pantry.json',
  'theme-12-literary-kitchen.json',
  'theme-13-ancient-table.json',
  'theme-14-american-foundation.json',
];

// Distribution for 25 recipes across 14 days
// Days without recipes: 4, 6, 8, 10, 12, 13
const UNLOCK_SCHEDULE_25_RECIPES = [
  1, 1, 1, 1,   // Day 1: 4 recipes (indices 0-3)
  2, 2, 2,       // Day 2: 3 recipes (indices 4-6)
  3, 3, 3,       // Day 3: 3 recipes (indices 7-9)
  5, 5, 5,       // Day 5: 3 recipes (indices 10-12)
  7, 7, 7,       // Day 7: 3 recipes (indices 13-15)
  9, 9, 9,       // Day 9: 3 recipes (indices 16-18)
  11, 11, 11,    // Day 11: 3 recipes (indices 19-21)
  14, 14, 14,    // Day 14: 3 recipes (indices 22-24)
];

const THEME_RECIPES_DIR = path.resolve(__dirname, '../../../themerecipes');

interface Recipe {
  id: string;
  title: string;
  unlockDay: number;
  sortOrder: number;
  [key: string]: any;
}

interface ThemeData {
  themeId: string;
  themeName: string;
  recipes: Recipe[];
}

function fixThemeFile(fileName: string, dryRun: boolean = false): void {
  const filePath = path.join(THEME_RECIPES_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.log(`  ⚠️ File not found: ${fileName}`);
    return;
  }

  const data: ThemeData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const recipes = data.recipes;

  console.log(`\n📚 ${data.themeName} (${data.themeId})`);
  console.log(`   Total recipes: ${recipes.length}`);

  if (recipes.length !== 25) {
    console.log(`   ⚠️ Expected 25 recipes, found ${recipes.length}. Skipping.`);
    return;
  }

  // Sort by sortOrder to ensure consistent assignment
  recipes.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));

  // Show current distribution
  const currentByDay = new Map<number, string[]>();
  recipes.forEach(r => {
    const day = r.unlockDay || 1;
    if (!currentByDay.has(day)) currentByDay.set(day, []);
    currentByDay.get(day)!.push(r.title.substring(0, 30));
  });

  console.log(`   Current distribution:`);
  Array.from(currentByDay.entries())
    .sort((a, b) => a[0] - b[0])
    .forEach(([day, titles]) => {
      console.log(`     Day ${day}: ${titles.length} recipes`);
    });

  // Apply new distribution
  console.log(`\n   Proposed distribution:`);
  const newByDay = new Map<number, string[]>();

  recipes.forEach((recipe, index) => {
    const newUnlockDay = UNLOCK_SCHEDULE_25_RECIPES[index];
    recipe.unlockDay = newUnlockDay;

    if (!newByDay.has(newUnlockDay)) newByDay.set(newUnlockDay, []);
    newByDay.get(newUnlockDay)!.push(recipe.title.substring(0, 40));
  });

  Array.from(newByDay.entries())
    .sort((a, b) => a[0] - b[0])
    .forEach(([day, titles]) => {
      console.log(`     Day ${day.toString().padStart(2)}: ${titles.length} recipes`);
      titles.forEach(t => console.log(`           - ${t}`));
    });

  if (!dryRun) {
    // Write updated JSON
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
    console.log(`\n   ✅ Updated ${fileName}`);
  } else {
    console.log(`\n   [DRY RUN] Would update ${fileName}`);
  }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  console.log('═'.repeat(60));
  console.log('FIX UNLOCK DAYS - JSON FILES ONLY');
  console.log('═'.repeat(60));

  if (dryRun) {
    console.log('\n🔍 DRY RUN MODE - No files will be modified\n');
  } else {
    console.log('\n⚠️  LIVE MODE - JSON files will be updated\n');
  }

  console.log('Distribution plan for 25 recipes:');
  console.log('  Day 1:  4 recipes');
  console.log('  Day 2:  3 recipes');
  console.log('  Day 3:  3 recipes');
  console.log('  Day 5:  3 recipes');
  console.log('  Day 7:  3 recipes');
  console.log('  Day 9:  3 recipes');
  console.log('  Day 11: 3 recipes');
  console.log('  Day 14: 3 recipes');

  for (const fileName of THEMES_TO_FIX) {
    fixThemeFile(fileName, dryRun);
  }

  console.log('\n' + '═'.repeat(60));

  if (!dryRun) {
    console.log('✅ JSON files updated!');
    console.log('\nNext steps:');
    console.log('  1. Review changes: git diff themerecipes/');
    console.log('  2. If changes look good, run Firebase seed:');
    console.log('     node scripts/cleanup-and-reseed-recipes.js');
    console.log('\n⚠️  DO NOT run Firebase seed until you\'ve reviewed the changes!');
  } else {
    console.log('Dry run complete. Run without --dry-run to apply changes.');
  }
  console.log('═'.repeat(60));
}

main().catch(console.error);
