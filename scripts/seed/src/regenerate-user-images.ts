/**
 * Regenerate images for a user's seeded recipes using Replicate
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { generateFoodImage } from './utils/replicate';

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
const storage = admin.storage().bucket();

async function regenerateUserImages(userId: string): Promise<void> {
  console.log(`\n🖼️  REGENERATING IMAGES for user: ${userId}`);
  console.log('='.repeat(60));

  // Get all recipes for the user
  const recipesSnapshot = await db.collection(`users/${userId}/recipes`).get();
  
  console.log(`Found ${recipesSnapshot.size} recipes\n`);

  let updated = 0;
  let skipped = 0;
  let failed = 0;

  for (const doc of recipesSnapshot.docs) {
    const recipe = doc.data();
    const recipeId = doc.id;
    const title = recipe.title || 'Unknown';

    // Generate image using Replicate
    console.log(`Generating image for: ${title}`);
    
    try {
      const imageUrl = await generateFoodImage(title);
      
      if (imageUrl) {
        // Download and upload to Firebase Storage
        const response = await fetch(imageUrl);
        const buffer = await response.arrayBuffer();
        
        const storagePath = `users/${userId}/recipes/${recipeId}/image.webp`;
        const file = storage.file(storagePath);
        
        await file.save(Buffer.from(buffer), {
          metadata: {
            contentType: 'image/webp',
          },
        });
        
        // Get the public URL
        const [metadata] = await file.getMetadata();
        const firebaseImageURL = `https://storage.googleapis.com/${storage.name}/${storagePath}`;
        
        // Update the recipe document
        await doc.ref.update({
          firebaseImageURL: firebaseImageURL,
          modifiedAt: admin.firestore.Timestamp.now(),
        });
        
        console.log(`  ✓ Updated: ${title}`);
        updated++;
      } else {
        console.log(`  ⏭ No image generated: ${title}`);
        skipped++;
      }
    } catch (error) {
      console.error(`  ✗ Failed: ${title} - ${error}`);
      failed++;
    }
    
    // Small delay to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ IMAGE REGENERATION COMPLETE');
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped: ${skipped}`);
  console.log(`  Failed: ${failed}`);
}

const userId = process.argv[2];
if (!userId) {
  console.error('Usage: npx ts-node src/regenerate-user-images.ts <userId>');
  process.exit(1);
}

regenerateUserImages(userId)
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
