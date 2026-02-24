import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS || '../service-account-key.json'),
  });
}

const db = admin.firestore();

async function check() {
  const recipeId = '5e13b837-1a80-4d22-af8a-c474a6ea5c35';
  console.log('Checking recipe:', recipeId);

  // Check demo_grandmazing's recipe
  const demoDoc = await db.doc(`users/demo_grandmazing/recipes/${recipeId}`).get();
  if (demoDoc.exists) {
    const data = demoDoc.data()!;
    console.log('\n=== demo_grandmazing recipe ===');
    console.log('Title:', data.title);
    console.log('Has instructions field:', 'instructions' in data);
    if ('instructions' in data) {
      console.log('Instructions type:', typeof data.instructions);
      console.log('Is array:', Array.isArray(data.instructions));
      if (Array.isArray(data.instructions)) {
        console.log('Instructions count:', data.instructions.length);
        if (data.instructions.length > 0) {
          console.log('First instruction preview:', String(data.instructions[0]).substring(0, 80));
        }
      }
    }
    console.log('All top-level keys:', Object.keys(data).join(', '));
  } else {
    console.log('demo_grandmazing recipe not found');
  }

  // Check user's copy
  const userId = 'jkxDVuA91wTOSLKWk3GZWqdOigQ2';
  const userDoc = await db.doc(`users/${userId}/recipes/${recipeId}`).get();
  if (userDoc.exists) {
    const data = userDoc.data()!;
    console.log('\n=== User recipe ===');
    console.log('Title:', data.title);
    console.log('Has instructions field:', 'instructions' in data);
    if ('instructions' in data) {
      console.log('Instructions count:', Array.isArray(data.instructions) ? data.instructions.length : 'N/A');
    }
    console.log('All top-level keys:', Object.keys(data).join(', '));
  } else {
    console.log('User recipe not found');
  }
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
