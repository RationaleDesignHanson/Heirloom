/**
 * Fix unlockDay values for ALL theme recipe JSON files
 *
 * Distribution:
 * - 14 recipes: 1 per day (Days 1-14)
 * - 25 recipes: 2 per day for Days 1-11, 1 per day for Days 12-14
 *
 * This ensures users get recipes EVERY day of the 14-day trial.
 *
 * Run with --dry-run to preview changes without modifying files.
 */

import * as fs from 'fs';
import * as path from 'path';

const THEME_RECIPES_DIR = path.resolve(__dirname, '../../../themerecipes');

// All theme files to process
const ALL_THEME_FILES = [
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
  'theme-14-american-foundation.json',
];

// Generate unlock schedule based on recipe count
function generateUnlockSchedule(recipeCount: number): number[] {
  const schedule: number[] = [];

  if (recipeCount === 14) {
    // Perfect fit: 1 recipe per day
    for (let day = 1; day <= 14; day++) {
      schedule.push(day);
    }
  } else if (recipeCount === 25) {
    // 25 recipes: 2 per day for Days 1-11, 1 per day for Days 12-14
    // Days 1-11: 2 recipes each = 22
    // Days 12-14: 1 recipe each = 3
    // Total: 25
    for (let day = 1; day <= 11; day++) {
      schedule.push(day);
      schedule.push(day);
    }
    schedule.push(12);
    schedule.push(13);
    schedule.push(14);
  } else if (recipeCount === 12) {
    // 12 recipes: Skip days 13 and 14 (or we'll add 2 more recipes)
    // After adding recipes, this shouldn't be called
    for (let day = 1; day <= 12; day++) {
      schedule.push(day);
    }
  } else {
    // Fallback: distribute evenly
    const recipesPerDay = Math.ceil(recipeCount / 14);
    let recipeIndex = 0;
    for (let day = 1; day <= 14 && recipeIndex < recipeCount; day++) {
      for (let i = 0; i < recipesPerDay && recipeIndex < recipeCount; i++) {
        schedule.push(day);
        recipeIndex++;
      }
    }
  }

  return schedule;
}

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

function fixThemeFile(fileName: string, dryRun: boolean): void {
  const filePath = path.join(THEME_RECIPES_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.log(`  ⚠️ File not found: ${fileName}`);
    return;
  }

  const data: ThemeData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const recipes = data.recipes;

  console.log(`\n📚 ${data.themeName} (${data.themeId})`);
  console.log(`   Total recipes: ${recipes.length}`);

  // Sort by sortOrder to ensure consistent assignment
  recipes.sort((a, b) => (a.sortOrder || 0) - (b.sortOrder || 0));

  // Show current distribution
  const currentByDay = new Map<number, number>();
  recipes.forEach(r => {
    const day = r.unlockDay || 1;
    currentByDay.set(day, (currentByDay.get(day) || 0) + 1);
  });

  const currentDays = Array.from(currentByDay.entries()).sort((a, b) => a[0] - b[0]);
  console.log(`   Current: ${currentDays.map(([d, c]) => `D${d}:${c}`).join(', ')}`);

  // Generate new schedule
  const newSchedule = generateUnlockSchedule(recipes.length);

  // Apply new distribution
  const newByDay = new Map<number, string[]>();
  recipes.forEach((recipe, index) => {
    const newUnlockDay = newSchedule[index];
    recipe.unlockDay = newUnlockDay;

    if (!newByDay.has(newUnlockDay)) newByDay.set(newUnlockDay, []);
    newByDay.get(newUnlockDay)!.push(recipe.title.substring(0, 25));
  });

  const newDays = Array.from(newByDay.entries()).sort((a, b) => a[0] - b[0]);
  console.log(`   New:     ${newDays.map(([d, titles]) => `D${d}:${titles.length}`).join(', ')}`);

  // Check for missing days
  const daysWithRecipes = new Set(newDays.map(([d]) => d));
  const missingDays = [];
  for (let d = 1; d <= 14; d++) {
    if (!daysWithRecipes.has(d)) missingDays.push(d);
  }

  if (missingDays.length > 0) {
    console.log(`   ⚠️  Missing days: ${missingDays.join(', ')}`);
  } else {
    console.log(`   ✓ All 14 days covered`);
  }

  if (!dryRun) {
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
    console.log(`   ✅ Updated ${fileName}`);
  } else {
    console.log(`   [DRY RUN] Would update ${fileName}`);
  }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  console.log('═'.repeat(60));
  console.log('FIX ALL UNLOCK DAYS - EVERY DAY COVERAGE');
  console.log('═'.repeat(60));

  if (dryRun) {
    console.log('\n🔍 DRY RUN MODE - No files will be modified\n');
  } else {
    console.log('\n⚠️  LIVE MODE - JSON files will be updated\n');
  }

  console.log('Distribution strategy:');
  console.log('  14 recipes → 1 per day (Days 1-14)');
  console.log('  25 recipes → 2 per day (Days 1-11), 1 per day (Days 12-14)');

  for (const fileName of ALL_THEME_FILES) {
    fixThemeFile(fileName, dryRun);
  }

  console.log('\n' + '═'.repeat(60));

  if (!dryRun) {
    console.log('✅ All JSON files updated!');
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
