/**
 * Generate images for deletion test account recipes using Replicate API
 *
 * Generates high-quality food photography images for the 9 deletion test recipes
 * and uploads them to Firebase Storage, then updates Firestore with the URLs.
 *
 * Usage: npx ts-node src/generate-deletion-test-images.ts
 *   --force    Regenerate even if image already exists in storage
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { callReplicateAPI, delay } from './utils/replicate';
import { getStorage } from 'firebase-admin/storage';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const db = admin.firestore();
const storage = getStorage().bucket();

const DELETION_TEST_EMAIL = 'deletetest@heirloomrecipebox.app';
const STORAGE_PREFIX = 'seed/deletion-test';

// Recipe titles and their image prompts
const RECIPE_IMAGE_PROMPTS: Record<string, string> = {
  'Honey Garlic Salmon': 'Professional food photography of honey garlic glazed salmon fillet, caramelized golden crust, sesame seeds and green onion garnish, served on white plate, overhead shot on rustic wooden table, natural window lighting, appetizing and delicious, 8k resolution, editorial food magazine style',

  "Classic Shepherd's Pie": 'Professional food photography of shepherd\'s pie in cast iron skillet, golden mashed potato top with fork marks, rich lamb and vegetable filling visible at edge, fresh thyme garnish, overhead shot on rustic wooden table, natural window lighting, comfort food, 8k resolution, editorial food magazine style',

  'Easy Vegetable Fried Rice': 'Professional food photography of vegetable fried rice in wok, colorful vegetables mixed with rice, scrambled egg pieces visible, sesame seeds on top, served in white bowl with chopsticks, overhead shot on rustic wooden table, natural window lighting, 8k resolution, editorial food magazine style',

  'Garlic Shrimp Scampi': 'Professional food photography of shrimp scampi over linguine pasta, plump garlic butter shrimp, fresh parsley and red pepper flakes, lemon wedge, served in white pasta bowl, overhead shot on rustic wooden table, natural window lighting, 8k resolution, editorial food magazine style',

  'Classic Caesar Salad': 'Professional food photography of caesar salad, crisp romaine lettuce leaves, shaved parmesan cheese, golden croutons, creamy dressing, served in white bowl, overhead shot on rustic wooden table, natural window lighting, fresh and appetizing, 8k resolution, editorial food magazine style',

  'French Onion Soup': 'Professional food photography of French onion soup in white ceramic crock, melted gruyere cheese stretching, caramelized onions visible through broth, crusty baguette slice, overhead shot on rustic wooden table, natural window lighting, steaming hot, 8k resolution, editorial food magazine style',

  'Classic Banana Bread': 'Professional food photography of sliced banana bread loaf on wooden cutting board, golden brown crust, moist interior visible, fresh banana slices as garnish, overhead shot on rustic wooden table, natural window lighting, homemade comfort food, 8k resolution, editorial food magazine style',

  'Homemade Blueberry Muffins': 'Professional food photography of blueberry muffins with sugar-crusted tops, fresh blueberries scattered around, one muffin broken open showing moist interior with berries, overhead shot on rustic wooden table, natural window lighting, bakery style, 8k resolution, editorial food magazine style',

  'Homemade Cinnamon Rolls': 'Professional food photography of cinnamon rolls with cream cheese frosting drizzled on top, golden brown swirls visible, one roll pulled apart showing soft interior, overhead shot on rustic wooden table, natural window lighting, fresh from oven, 8k resolution, editorial food magazine style',
};

function toSlug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

async function findDeletionTestUser(): Promise<string | null> {
  try {
    const user = await admin.auth().getUserByEmail(DELETION_TEST_EMAIL);
    return user.uid;
  } catch {
    return null;
  }
}

async function generateDeletionTestImages(force: boolean): Promise<void> {
  console.log(`\n🖼️  GENERATING DELETION TEST ACCOUNT IMAGES`);
  console.log(`   Account: ${DELETION_TEST_EMAIL}`);
  console.log(`   Storage path: ${STORAGE_PREFIX}/`);
  console.log(`   Force regenerate: ${force}`);
  console.log('='.repeat(60));

  // Find the deletion test user
  const userId = await findDeletionTestUser();
  if (!userId) {
    console.error(`❌ Deletion test user not found: ${DELETION_TEST_EMAIL}`);
    console.log('   Run seed-deletion-test-account.ts first to create the account.');
    process.exit(1);
  }
  console.log(`\n✓ Found user: ${userId}`);

  // Get all recipes for this user
  const recipesSnapshot = await db
    .collection('users')
    .doc(userId)
    .collection('recipes')
    .get();

  console.log(`\n📋 Found ${recipesSnapshot.size} recipes to process\n`);

  let generated = 0;
  let skipped = 0;
  let failed = 0;

  for (const recipeDoc of recipesSnapshot.docs) {
    const recipe = recipeDoc.data();
    const recipeTitle = recipe.title as string;
    const recipeId = recipeDoc.id;

    const imagePrompt = RECIPE_IMAGE_PROMPTS[recipeTitle];
    if (!imagePrompt) {
      console.log(`⏭ No image prompt defined for: ${recipeTitle}`);
      skipped++;
      continue;
    }

    const slug = toSlug(recipeTitle);
    const storagePath = `${STORAGE_PREFIX}/${slug}-image.webp`;
    const file = storage.file(storagePath);

    // Skip if image already exists (unless --force)
    if (!force) {
      const [exists] = await file.exists();
      if (exists) {
        // Still update Firestore with the existing URL
        const publicUrl = `https://storage.googleapis.com/${storage.name}/${storagePath}`;
        await recipeDoc.ref.update({ firebaseImageURL: publicUrl });
        console.log(`⏭ Already exists: ${recipeTitle}`);
        console.log(`   Updated Firestore with existing URL`);
        skipped++;
        continue;
      }
    }

    console.log(`🎨 Generating: ${recipeTitle}`);
    console.log(`   Prompt: ${imagePrompt.substring(0, 70)}...`);

    try {
      // Call Replicate with the recipe's image prompt
      const imageUrl = await callReplicateAPI({
        prompt: imagePrompt,
        aspect_ratio: '4:3',
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      });

      console.log(`   ⬇️  Downloading from Replicate...`);

      // Download the generated image
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();

      console.log(`   ⬆️  Uploading to Firebase Storage...`);

      // Upload to Firebase Storage
      await file.save(Buffer.from(buffer), {
        metadata: {
          contentType: 'image/webp',
          cacheControl: 'public, max-age=31536000',
        },
      });

      // Bucket has uniform access, so files are already publicly readable
      const publicUrl = `https://storage.googleapis.com/${storage.name}/${storagePath}`;

      // Update Firestore with the new image URL
      await recipeDoc.ref.update({ firebaseImageURL: publicUrl });

      console.log(`   ✓ Success: ${publicUrl}`);
      generated++;
    } catch (error) {
      console.error(`   ✗ Failed: ${error}`);
      failed++;
    }

    // Rate limit to avoid Replicate throttling
    await delay(1000);
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ DELETION TEST IMAGE GENERATION COMPLETE');
  console.log(`   Generated: ${generated}`);
  console.log(`   Skipped (already exist): ${skipped}`);
  console.log(`   Failed: ${failed}`);
  console.log(`\nImages are now available for the deletion test account.`);
}

// CLI entry point
const force = process.argv.includes('--force');

generateDeletionTestImages(force)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
