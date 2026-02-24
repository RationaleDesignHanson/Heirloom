import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

const ROOT_RECIPE_ID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

async function verifyAndCleanup() {
  console.log('=== Checking All Lineages ===\n');

  const allLineages = await db.collection('lineages').get();
  console.log('Total lineages in collection:', allLineages.size);

  // Find all Bolognese-related lineages
  const bolLineages: admin.firestore.QueryDocumentSnapshot[] = [];

  for (const doc of allLineages.docs) {
    const d = doc.data();
    console.log(`\n${doc.id}:`);
    console.log(`  Owner: ${d.ownerDisplayName || d.ownerId}`);
    console.log(`  Gen: ${d.generation}`);
    console.log(`  Title: ${d.title || d.recipeTitle}`);
    console.log(`  Recipe ID: ${d.recipeId || d.currentRecipeId}`);
    console.log(`  Root: ${d.rootRecipeId}`);

    if (d.rootRecipeId === ROOT_RECIPE_ID || d.recipeId === ROOT_RECIPE_ID) {
      bolLineages.push(doc);
    }

    // Check for undefined/null data that indicates a bad record
    if (!d.ownerDisplayName && !d.ownerId) {
      console.log('  ⚠️  Missing owner - should delete');
    }
    if (!d.title && !d.recipeTitle) {
      console.log('  ⚠️  Missing title - should delete');
    }
  }

  console.log('\n=== Bolognese Lineages Found ===');
  console.log(`Count: ${bolLineages.length}`);

  // Map by owner to find duplicates
  const byOwner = new Map<string, admin.firestore.QueryDocumentSnapshot[]>();
  for (const doc of bolLineages) {
    const d = doc.data();
    const owner = d.ownerId;
    if (!byOwner.has(owner)) {
      byOwner.set(owner, []);
    }
    byOwner.get(owner)!.push(doc);
  }

  console.log('\nGrouped by owner:');
  for (const [owner, docs] of byOwner) {
    console.log(`  ${owner}: ${docs.length} lineage(s)`);
    if (docs.length > 1) {
      console.log(`    ⚠️  Duplicate detected - IDs: ${docs.map(d => d.id).join(', ')}`);
    }
  }
}

verifyAndCleanup().catch(console.error);
