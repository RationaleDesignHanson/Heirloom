/**
 * Orchestrator for all Heirloom seed scripts
 *
 * Calls existing scripts in sequence while keeping them in their original locations.
 * This provides a unified entry point without regression risk.
 *
 * Usage:
 *   npm run seed:all           # Run all seeds
 *   npm run seed:themes        # Just theme recipes
 *   npm run seed:public        # Just public recipes (demo creators)
 *   npm run seed:algolia       # Sync to Algolia
 *   npm run cleanup:all        # Clean all seeded data
 */

import { execSync, spawn } from 'child_process';
import * as path from 'path';

// Script locations (relative to scripts/seed/)
const SCRIPTS = {
  themeRecipes: '../../scripts/cleanup-and-reseed-recipes.js',
  publicRecipes: './src/seed.ts',
  publicRecipesCleanup: './src/cleanup.ts',
  publicRecipesVerify: './src/verify.ts',
  algoliaBackfill: '../../firebase/functions/backfill-public-recipes-algolia.js',
};

// Resolve paths relative to scripts/seed directory
const SEED_DIR = path.resolve(__dirname, '..');

function resolvePath(scriptPath: string): string {
  return path.resolve(SEED_DIR, scriptPath);
}

/**
 * Execute a Node.js script and stream output
 */
async function execScript(scriptPath: string, args: string[] = []): Promise<void> {
  const resolved = resolvePath(scriptPath);
  const ext = path.extname(resolved);

  return new Promise((resolve, reject) => {
    let cmd: string;
    let cmdArgs: string[];

    if (ext === '.ts') {
      cmd = 'npx';
      cmdArgs = ['ts-node', resolved, ...args];
    } else {
      cmd = 'node';
      cmdArgs = [resolved, ...args];
    }

    console.log(`\n${'='.repeat(60)}`);
    console.log(`Running: ${path.basename(resolved)}`);
    console.log('='.repeat(60) + '\n');

    const child = spawn(cmd, cmdArgs, {
      cwd: SEED_DIR,
      stdio: 'inherit',
      env: { ...process.env },
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Script ${scriptPath} exited with code ${code}`));
      }
    });

    child.on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Seed all data in the correct order
 */
async function seedAll(): Promise<void> {
  console.log('\n🌱 HEIRLOOM SEED ORCHESTRATOR');
  console.log('============================\n');
  console.log('This will seed all demo/test data:\n');
  console.log('  1. Theme recipes (14 themes)');
  console.log('  2. Public recipes (demo creators)');
  console.log('  3. Algolia sync\n');

  const startTime = Date.now();

  try {
    // 1. Theme recipes
    console.log('\n📚 Step 1/3: Seeding theme recipes...');
    await execScript(SCRIPTS.themeRecipes);

    // 2. Public recipes (demo creators)
    console.log('\n👨‍🍳 Step 2/3: Seeding public recipes (demo creators)...');
    await execScript(SCRIPTS.publicRecipes);

    // 3. Algolia sync
    console.log('\n🔍 Step 3/3: Syncing to Algolia...');
    await execScript(SCRIPTS.algoliaBackfill);

    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log('\n' + '='.repeat(60));
    console.log(`✅ ALL SEEDS COMPLETE (${elapsed}s)`);
    console.log('='.repeat(60) + '\n');

  } catch (error) {
    console.error('\n❌ Seed failed:', error);
    process.exit(1);
  }
}

/**
 * Seed only theme recipes
 */
async function seedThemes(): Promise<void> {
  console.log('\n📚 Seeding theme recipes...\n');
  await execScript(SCRIPTS.themeRecipes);
  console.log('\n✅ Theme recipes seeded.');
}

/**
 * Seed only public recipes (demo creators)
 */
async function seedPublic(skipImages: boolean = false): Promise<void> {
  console.log('\n👨‍🍳 Seeding public recipes (demo creators)...\n');
  const args = skipImages ? ['--skip-images'] : [];
  await execScript(SCRIPTS.publicRecipes, args);
  console.log('\n✅ Public recipes seeded.');
}

/**
 * Sync to Algolia
 */
async function syncAlgolia(): Promise<void> {
  console.log('\n🔍 Syncing to Algolia...\n');
  await execScript(SCRIPTS.algoliaBackfill);
  console.log('\n✅ Algolia sync complete.');
}

/**
 * Verify all seeded data
 */
async function verifyAll(): Promise<void> {
  console.log('\n🔎 Verifying seeded data...\n');
  await execScript(SCRIPTS.publicRecipesVerify);
}

/**
 * Clean up all seeded data
 */
async function cleanupAll(): Promise<void> {
  console.log('\n🧹 CLEANUP ALL SEEDED DATA');
  console.log('==========================\n');
  console.log('This will remove:\n');
  console.log('  1. Public recipes (demo creators)');
  console.log('  2. Theme recipes are NOT cleaned (they are app content)\n');

  // Only clean demo/test data, not theme recipes (those are real app content)
  await execScript(SCRIPTS.publicRecipesCleanup);

  console.log('\n✅ Cleanup complete.');
}

// CLI handling
const command = process.argv[2];

switch (command) {
  case 'all':
    seedAll();
    break;
  case 'themes':
    seedThemes();
    break;
  case 'public':
    seedPublic(process.argv.includes('--skip-images'));
    break;
  case 'algolia':
    syncAlgolia();
    break;
  case 'verify':
    verifyAll();
    break;
  case 'cleanup':
    cleanupAll();
    break;
  default:
    console.log(`
Heirloom Seed Orchestrator

Usage: npx ts-node src/orchestrate.ts <command>

Commands:
  all       Seed everything (themes + public recipes + Algolia)
  themes    Seed theme recipes only
  public    Seed public recipes (demo creators) only
  algolia   Sync public recipes to Algolia
  verify    Verify seeded data
  cleanup   Remove all demo/test data

Options:
  --skip-images   Skip AI image generation (for 'public' command)

Examples:
  npx ts-node src/orchestrate.ts all
  npx ts-node src/orchestrate.ts public --skip-images
  npx ts-node src/orchestrate.ts cleanup
`);
    process.exit(1);
}
