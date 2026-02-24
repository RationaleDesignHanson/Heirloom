import * as admin from 'firebase-admin';
import * as path from 'path';

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(path.resolve(__dirname, '../../../service-account-key.json')),
  });
}

const db = admin.firestore();

async function check() {
  // Bolognese rootRecipeId from seed
  const boloRootId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  
  console.log('=== Lineages for Bolognese (rootRecipeId: ' + boloRootId + ') ===\n');
  
  const lineages = await db.collection('lineages')
    .where('rootRecipeId', '==', boloRootId)
    .get();
  
  console.log('Total: ' + lineages.docs.length + '\n');
  
  for (const doc of lineages.docs) {
    const d = doc.data();
    console.log('Gen ' + d.generation + ' | ownerId: ' + d.ownerId + ' | sharedByName: ' + (d.sharedByName || 'null'));
  }

  // Also list the heritageChain from the test user's Bolognese to see who SHOULD be allowed
  console.log('\n=== Test user Bolognese heritageChain ===');
  const allowedOwners = ['demo_grandmazing', 'demo_phillipfry', 'demo_chef_maria', 'demo_bigshare', 'demo_grillmaster', 'nVkKpcbBtdNxXqRErSYQdeIUiHh1'];
  console.log('Allowed owners: ' + allowedOwners.join(', '));
}

check().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
