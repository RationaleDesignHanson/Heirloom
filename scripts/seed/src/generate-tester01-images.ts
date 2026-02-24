/**
 * Generate images for tester01 account - 15 recipes + profile photo
 *
 * Usage: npx ts-node src/generate-tester01-images.ts [--force]
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { callReplicateAPI, delay } from './utils/replicate';
import { getStorage } from 'firebase-admin/storage';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

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

const TESTER_USER_ID = 'uBaIzSsCTnWXPoYSLHwpkU54G3U2';
const STORAGE_PREFIX = 'seed/tester01';
const DISPLAY_NAME = 'OOBEApple';

const RECIPE_IMAGE_PROMPTS: Record<string, string> = {
  'Easy Vegetable Fried Rice': 'Professional food photography of vegetable fried rice in wok, colorful vegetables mixed with rice, scrambled egg pieces visible, sesame seeds on top, served in white bowl with chopsticks, overhead shot on rustic wooden table, natural window lighting, 8k resolution, editorial food magazine style',
  'Norwegian Fish Pudding (Fiskepudding)': 'Professional food photography of Norwegian fiskepudding, creamy light fish mousse soufflé, delicate beige color, served with shrimp sauce and peas, plated elegantly, overhead shot on rustic wooden table, natural window lighting, refined Scandinavian cuisine, 8k resolution',
  'Homemade Blueberry Muffins': 'Professional food photography of blueberry muffins with sugar-crusted tops, fresh blueberries scattered around, one muffin broken open showing moist interior with berries, overhead shot on rustic wooden table, natural window lighting, bakery style, 8k resolution',
  'Garlic Shrimp Scampi': 'Professional food photography of shrimp scampi over linguine pasta, plump garlic butter shrimp, fresh parsley and red pepper flakes, lemon wedge, served in white pasta bowl, overhead shot on rustic wooden table, natural window lighting, 8k resolution',
  'Spätzle (German Egg Noodles)': 'Professional food photography of Spätzle German egg noodles with brown butter and crispy onions, golden brown color, rich and savory, served in ceramic bowl, overhead shot on rustic wooden table, natural window lighting, traditional German cuisine, 8k resolution',
  'Homemade Cinnamon Rolls': 'Professional food photography of cinnamon rolls with cream cheese frosting drizzled on top, golden brown swirls visible, one roll pulled apart showing soft interior, overhead shot on rustic wooden table, natural window lighting, fresh from oven, 8k resolution',
  "Classic Shepherd's Pie": 'Professional food photography of shepherds pie in cast iron skillet, golden mashed potato top with fork marks, rich lamb and vegetable filling visible at edge, fresh thyme garnish, overhead shot on rustic wooden table, natural window lighting, comfort food, 8k resolution',
  'Danish Aebleskiver': 'Professional food photography of Danish aebleskiver pancake balls, golden brown spheres with powdered sugar dusted on top, jam filling visible at center, served on white plate with jam and whipped cream, overhead shot on rustic wooden table, natural window lighting, 8k resolution',
  'Swedish Meatballs (Köttbullar)': 'Professional food photography of Swedish meatballs köttbullar, brown glazed meatballs with creamy sauce, fresh dill garnish, served over egg noodles, overhead shot on rustic wooden table, natural window lighting, traditional Scandinavian cuisine, 8k resolution',
  'Sauerbraten (German Pot Roast)': 'Professional food photography of German sauerbraten pot roast, dark braised meat with rich gravy, tender and succulent, served with red cabbage and egg noodles, overhead shot on rustic wooden table, natural window lighting, traditional German cuisine, 8k resolution',
  'French Onion Soup': 'Professional food photography of French onion soup in white ceramic crock, melted gruyere cheese stretching, caramelized onions visible through broth, crusty baguette slice, overhead shot on rustic wooden table, natural window lighting, steaming hot, 8k resolution',
  'Classic Banana Bread': 'Professional food photography of sliced banana bread loaf on wooden cutting board, golden brown crust, moist interior visible, fresh banana slices as garnish, overhead shot on rustic wooden table, natural window lighting, homemade comfort food, 8k resolution',
  'Wiener Schnitzel': 'Professional food photography of Wiener schnitzel, golden crispy breaded thin pork cutlet, lemon wedge and parsley garnish, served on white plate, overhead shot on rustic wooden table, natural window lighting, traditional Viennese cuisine, 8k resolution',
  'Classic Caesar Salad': 'Professional food photography of caesar salad, crisp romaine lettuce leaves, shaved parmesan cheese, golden croutons, creamy dressing, served in white bowl, overhead shot on rustic wooden table, natural window lighting, fresh and appetizing, 8k resolution',
  'Honey Garlic Salmon': 'Professional food photography of honey garlic glazed salmon fillet, caramelized golden crust, sesame seeds and green onion garnish, served on white plate, overhead shot on rustic wooden table, natural window lighting, appetizing and delicious, 8k resolution',
};

const AVATAR_PROMPT = 'Portrait photography of a friendly approachable woman in her early 40s with a warm genuine smile and kind eyes, casually styled shoulder-length blonde hair with natural highlights, wearing a comfortable sweater in warm earth tones, relaxed pose leaning against a cozy home kitchen counter, country farmhouse kitchen background with copper pots and fresh herbs, soft natural window lighting, warm and inviting personality, approachable and trustworthy, high quality portrait, 8k resolution, professional headshot style';

function toSlug(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

async function generateTester01Images(force: boolean): Promise<void> {
  console.log('\n' + '='.repeat(70));
  console.log('GENERATING TESTER01 IMAGES - 15 RECIPES + PROFILE PHOTO');
  console.log('='.repeat(70));
  console.log('User ID: ' + TESTER_USER_ID);
  console.log('Display name: ' + DISPLAY_NAME);
  console.log('Force regenerate: ' + force);
  console.log('='.repeat(70) + '\n');

  const recipesSnapshot = await db.collection('users').doc(TESTER_USER_ID).collection('recipes').get();
  console.log('Found ' + recipesSnapshot.size + ' recipes\n');

  let generated = 0, skipped = 0, failed = 0;

  // Generate Recipe Images
  console.log('-'.repeat(70));
  console.log('GENERATING RECIPE IMAGES');
  console.log('-'.repeat(70) + '\n');

  for (const recipeDoc of recipesSnapshot.docs) {
    const recipe = recipeDoc.data();
    const recipeTitle = recipe.title as string;
    const imagePrompt = RECIPE_IMAGE_PROMPTS[recipeTitle];

    if (!imagePrompt) {
      console.log('Skip (no prompt): ' + recipeTitle);
      skipped++;
      continue;
    }

    const slug = toSlug(recipeTitle);
    const storagePath = STORAGE_PREFIX + '/' + slug + '-image.webp';
    const file = storage.file(storagePath);

    if (!force) {
      const [exists] = await file.exists();
      if (exists) {
        const publicUrl = 'https://storage.googleapis.com/' + storage.name + '/' + storagePath;
        await recipeDoc.ref.update({ firebaseImageURL: publicUrl });
        console.log('Skip (exists): ' + recipeTitle);
        skipped++;
        continue;
      }
    }

    console.log('Generating: ' + recipeTitle);

    try {
      const imageUrl = await callReplicateAPI({
        prompt: imagePrompt,
        aspect_ratio: '4:3',
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      });

      console.log('  Downloading...');
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();

      console.log('  Uploading...');
      await file.save(Buffer.from(buffer), {
        metadata: { contentType: 'image/webp', cacheControl: 'public, max-age=31536000' },
      });

      const publicUrl = 'https://storage.googleapis.com/' + storage.name + '/' + storagePath;
      await recipeDoc.ref.update({ firebaseImageURL: publicUrl });

      console.log('  Done: ' + publicUrl);
      generated++;
    } catch (error) {
      console.error('  FAILED: ' + error);
      failed++;
    }

    await delay(1000);
  }

  // Generate Avatar
  console.log('\n' + '-'.repeat(70));
  console.log('GENERATING PROFILE AVATAR');
  console.log('-'.repeat(70) + '\n');

  const avatarPath = STORAGE_PREFIX + '/oobe-apple-avatar.webp';
  const avatarFile = storage.file(avatarPath);
  const [avatarExists] = await avatarFile.exists();

  if (!force && avatarExists) {
    const avatarUrl = 'https://storage.googleapis.com/' + storage.name + '/' + avatarPath;
    await db.collection('users').doc(TESTER_USER_ID).update({ 
      displayName: DISPLAY_NAME,
      photoURL: avatarUrl 
    });
    console.log('Avatar exists, updated profile with existing URL');
  } else {
    console.log('Generating avatar for: ' + DISPLAY_NAME);

    try {
      const avatarUrl = await callReplicateAPI({
        prompt: AVATAR_PROMPT,
        aspect_ratio: '1:1',
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      });

      console.log('  Downloading...');
      const response = await fetch(avatarUrl);
      const buffer = await response.arrayBuffer();

      console.log('  Uploading...');
      await avatarFile.save(Buffer.from(buffer), {
        metadata: { contentType: 'image/webp', cacheControl: 'public, max-age=31536000' },
      });

      const publicUrl = 'https://storage.googleapis.com/' + storage.name + '/' + avatarPath;
      await db.collection('users').doc(TESTER_USER_ID).update({
        displayName: DISPLAY_NAME,
        photoURL: publicUrl,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log('  Avatar done: ' + publicUrl);
    } catch (error) {
      console.error('  Avatar FAILED: ' + error);
    }
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('COMPLETE');
  console.log('='.repeat(70));
  console.log('Generated: ' + generated);
  console.log('Skipped: ' + skipped);
  console.log('Failed: ' + failed);
  console.log('='.repeat(70) + '\n');

  if (failed > 0) process.exit(1);
}

const force = process.argv.includes('--force');
generateTester01Images(force)
  .then(() => process.exit(0))
  .catch((err) => { console.error('Fatal:', err); process.exit(1); });
