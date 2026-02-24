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

async function deleteUppercaseDocs() {
  const demoUsers = ['demo_grandmazing', 'demo_phillipfry', 'demo_chef_maria', 'demo_fitfoodie', 'demo_bakingbelle', 'demo_grillmaster'];

  console.log('Deleting uppercase recipe documents...\n');

  for (const userId of demoUsers) {
    const recipes = await db.collection(`users/${userId}/recipes`).get();
    for (const doc of recipes.docs) {
      if (doc.id !== doc.id.toLowerCase()) {
        console.log(`  Deleting ${userId}/recipes/${doc.id}`);
        // Delete subcollections first
        const ingredients = await doc.ref.collection('ingredients').get();
        for (const ing of ingredients.docs) {
          await ing.ref.delete();
        }
        const instructions = await doc.ref.collection('instructions').get();
        for (const inst of instructions.docs) {
          await inst.ref.delete();
        }
        await doc.ref.delete();
      }
    }
  }
  console.log('\nDone!');
}

deleteUppercaseDocs()
  .then(() => process.exit(0))
  .catch(e => { console.error(e); process.exit(1); });
