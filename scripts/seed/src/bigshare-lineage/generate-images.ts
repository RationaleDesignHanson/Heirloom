/**
 * Generate images for Bigshare demo user
 *
 * Creates:
 * 1. Bolognese recipe image (shared across all 5 lineage recipes)
 * 2. Big Share avatar image
 *
 * Uploads to Firebase Storage at seed/demo/
 *
 * Usage: npx ts-node src/bigshare-lineage/generate-images.ts
 */

import { initializeFirebase } from '../utils/firebase';
import { callReplicateAPI, delay } from '../utils/replicate';
import { getStorage } from 'firebase-admin/storage';

initializeFirebase();
const storage = getStorage().bucket();

const STORAGE_PREFIX = 'seed/demo';

const IMAGES_TO_GENERATE = [
  {
    name: 'Bolognese recipe image',
    storagePath: `${STORAGE_PREFIX}/demo_bigshare_bolognese-image.webp`,
    prompt: 'Professional food photography of a rich, slow-simmered Italian bolognese sauce served over fresh pappardelle pasta in a rustic ceramic bowl, overhead shot on aged wooden table, natural window lighting, garnished with fresh basil and grated Parmigiano-Reggiano, shallow depth of field, appetizing and comforting, high quality, 8k resolution, editorial food magazine style',
    aspectRatio: '4:3',
  },
  {
    name: 'Big Share avatar',
    storagePath: `${STORAGE_PREFIX}/demo_bigshare-avatar.webp`,
    prompt: 'Portrait photography of a friendly approachable man in his late 30s with a warm genuine smile and kind eyes, casually tousled brown hair, wearing a comfortable henley shirt, relaxed pose leaning against a kitchen counter, cozy New York apartment kitchen background with cookbooks and a cast iron pan, soft natural window lighting, warm and inviting personality, looks like a likeable 90s sitcom neighbor, high quality portrait, 8k resolution',
    aspectRatio: '1:1',
  },
];

async function generateBigshareImages(): Promise<void> {
  console.log('\nGenerating Bigshare demo images...\n');

  for (const image of IMAGES_TO_GENERATE) {
    const file = storage.file(image.storagePath);

    // Check if already exists
    const [exists] = await file.exists();
    if (exists) {
      console.log(`Already exists, skipping: ${image.name}`);
      console.log(`  Path: ${image.storagePath}\n`);
      continue;
    }

    console.log(`Generating: ${image.name}`);
    console.log(`  Prompt: ${image.prompt.substring(0, 80)}...`);

    try {
      const imageUrl = await callReplicateAPI({
        prompt: image.prompt,
        aspect_ratio: image.aspectRatio,
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      });

      // Download the generated image
      const response = await fetch(imageUrl);
      const buffer = await response.arrayBuffer();

      // Upload to Firebase Storage
      await file.save(Buffer.from(buffer), {
        metadata: {
          contentType: 'image/webp',
        },
      });

      const publicUrl = `https://storage.googleapis.com/${storage.name}/${image.storagePath}`;
      console.log(`  Uploaded: ${publicUrl}\n`);
    } catch (error) {
      console.error(`  Failed: ${image.name} - ${error}\n`);
    }

    await delay(1000);
  }

  console.log('Done! Bigshare images generated.');
}

generateBigshareImages()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
