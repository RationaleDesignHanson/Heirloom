/**
 * Generate proper images for seed recipes using Replicate API (ONE-TIME)
 *
 * Generates images using each recipe's imagePrompt field and uploads them to a
 * global shared location (seed/demo/) in Firebase Storage. These images are
 * shared across ALL users and never regenerated — run this script once.
 *
 * The seed script (seed.ts) references these images via seedImageUrl() which
 * computes the deterministic URL from the recipe title.
 *
 * Usage: npx ts-node src/generate-seed-images.ts
 *   --force    Regenerate even if image already exists in storage
 */

import { initializeFirebase } from './utils/firebase';
import { callReplicateAPI, delay } from './utils/replicate';
import { getStorage } from 'firebase-admin/storage';
import { COLLECTION_RECIPES, SCREENSHOT_COLLECTIONS, toSlug } from './screenshot-demo/seed';

// Initialize Firebase
initializeFirebase();
const storage = getStorage().bucket();

const STORAGE_PREFIX = 'seed/demo';

async function generateSeedImages(force: boolean): Promise<void> {
  console.log(`\n🖼️  GENERATING GLOBAL SEED RECIPE IMAGES`);
  console.log(`   Storage path: ${STORAGE_PREFIX}/seed_*-image.webp`);
  console.log(`   Force regenerate: ${force}`);
  console.log('='.repeat(60));

  let generated = 0;
  let skipped = 0;
  let failed = 0;

  for (const collection of SCREENSHOT_COLLECTIONS) {
    const recipes = COLLECTION_RECIPES[collection.name];
    if (!recipes) {
      console.log(`⏭ No recipes found for collection: ${collection.name}`);
      continue;
    }

    console.log(`\n📁 ${collection.name} (${recipes.length} recipes)`);

    for (const recipe of recipes) {
      const slug = toSlug(recipe.title);
      const storagePath = `${STORAGE_PREFIX}/seed_${slug}-image.webp`;
      const file = storage.file(storagePath);

      // Skip if image already exists (unless --force)
      if (!force) {
        const [exists] = await file.exists();
        if (exists) {
          console.log(`  ⏭ Already exists: ${recipe.title}`);
          skipped++;
          continue;
        }
      }

      console.log(`  Generating: ${recipe.title}`);
      console.log(`    Prompt: ${recipe.imagePrompt.substring(0, 80)}...`);
      console.log(`    Path: ${storagePath}`);

      try {
        // Call Replicate with the recipe's specific imagePrompt
        const imageUrl = await callReplicateAPI({
          prompt: recipe.imagePrompt,
          aspect_ratio: '4:3',
          output_format: 'webp',
          output_quality: 90,
          safety_tolerance: 2,
          prompt_upsampling: true,
        });

        // Download the generated image
        const response = await fetch(imageUrl);
        const buffer = await response.arrayBuffer();

        // Upload to the global seed/demo/ path in Firebase Storage
        await file.save(Buffer.from(buffer), {
          metadata: {
            contentType: 'image/webp',
          },
        });

        const publicUrl = `https://storage.googleapis.com/${storage.name}/${storagePath}`;
        console.log(`  ✓ Uploaded: ${publicUrl}`);
        generated++;
      } catch (error) {
        console.error(`  ✗ Failed: ${recipe.title} - ${error}`);
        failed++;
      }

      // Rate limit to avoid Replicate throttling
      await delay(500);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ SEED IMAGE GENERATION COMPLETE');
  console.log(`  Generated: ${generated}`);
  console.log(`  Skipped (already exist): ${skipped}`);
  console.log(`  Failed: ${failed}`);
  console.log('\nThese images are now available globally for all seeded users.');
  console.log('The seed script will automatically reference them via seedImageUrl().');
}

// CLI entry point
const force = process.argv.includes('--force');

generateSeedImages(force)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
