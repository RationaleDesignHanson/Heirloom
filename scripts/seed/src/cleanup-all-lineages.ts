import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

async function cleanup() {
  console.log('=== Cleaning Up Lineage Collection ===\n');

  const allLineages = await db.collection('lineages').get();
  console.log('Total lineages before cleanup:', allLineages.size);

  let deleted = 0;
  const toDelete: string[] = [];

  for (const doc of allLineages.docs) {
    const d = doc.data();
    const id = doc.id;

    // Delete if missing required fields
    if (!d.title && !d.recipeTitle) {
      toDelete.push(id);
      console.log(`Will delete (no title): ${id}`);
      continue;
    }

    // Delete duplicate bigshare-lineage-* entries (keep lineage-*-bolognese)
    if (id.startsWith('bigshare-lineage-')) {
      toDelete.push(id);
      console.log(`Will delete (duplicate bigshare-lineage): ${id}`);
      continue;
    }
  }

  console.log(`\nDeleting ${toDelete.length} records...`);

  for (const id of toDelete) {
    await db.collection('lineages').doc(id).delete();
    deleted++;
  }

  console.log(`Deleted ${deleted} records`);

  // Verify remaining
  console.log('\n=== Remaining Bolognese Lineages ===\n');
  const remaining = await db.collection('lineages').get();
  const bolognese = remaining.docs.filter(doc => {
    const d = doc.data();
    return d.rootRecipeId === 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
  });

  bolognese.sort((a, b) => (a.data().generation || 0) - (b.data().generation || 0));

  console.log('Tree:');
  for (const doc of bolognese) {
    const d = doc.data();
    const indent = '  '.repeat(d.generation || 0);
    console.log(`${indent}Gen ${d.generation}: ${d.ownerDisplayName} - ${d.title}`);
  }

  console.log(`\nTotal remaining lineages: ${remaining.size}`);
}

cleanup().catch(console.error);
