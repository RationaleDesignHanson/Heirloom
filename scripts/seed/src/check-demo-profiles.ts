import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function check() {
  const demoUsers = ['demo_grandmazing', 'demo_phillipfry', 'demo_bigshare', 'demo_chef_maria', 'demo_grillmaster'];
  
  for (const userId of demoUsers) {
    const profile = await db.doc(`users/${userId}/profile/data`).get();
    const recipes = await db.collection(`users/${userId}/recipes`).get();
    const lineages = await db.collection(`users/${userId}/lineages`).get();
    
    console.log(userId + ':');
    console.log('  Profile:', profile.exists ? profile.data()?.displayName : 'MISSING');
    console.log('  Recipes:', recipes.size);
    console.log('  Lineages:', lineages.size);
  }
  
  // Check globalLineages
  const globalLineages = await db.collection('globalLineages').get();
  console.log('\nglobalLineages collection:', globalLineages.size);
  
  // Check lineages collection 
  const lineagesCol = await db.collection('lineages').get();
  console.log('lineages collection:', lineagesCol.size);
}

check();
