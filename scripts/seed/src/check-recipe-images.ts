import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();
const userId = 'TuQgh4k7HSY8p5eDk90ja53u9ki2';

async function checkImages() {
  const recipes = await db.collection(`users/${userId}/recipes`).get();
  console.log(`Checking ${recipes.size} recipe images:\n`);

  let regenerated = 0;
  let placeholder = 0;

  for (const doc of recipes.docs) {
    const data = doc.data();
    const url = data.firebaseImageURL || '(none)';
    // Regenerated images are stored in users/{userId}/recipes/ path
    // Placeholder images are in /seed/demo/ path
    const isRegenerated = url.includes(`users/${userId}/recipes/`);
    const isPlaceholder = url.includes('/seed/demo/') && !url.includes(`users/${userId}`);

    if (isRegenerated) {
      regenerated++;
      console.log(`✓ ${data.title}`);
    } else if (isPlaceholder) {
      placeholder++;
      console.log(`⚠️ ${data.title} - PLACEHOLDER IMAGE`);
    } else {
      console.log(`? ${data.title} - ${url.substring(0, 60)}...`);
    }
  }

  console.log(`\nSummary: ${regenerated} regenerated, ${placeholder} placeholder`);
}

checkImages().then(() => process.exit(0));
