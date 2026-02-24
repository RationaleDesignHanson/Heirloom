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
  console.log('=== Cleaning Up UUID Case Duplicates ===\n');

  // demo_bigshare has two "Traveling Bolognese" recipes:
  // - E5F6A7B8-C9D0-1234-EFAB-345678901234 (uppercase - delete)
  // - e5f6a7b8-c9d0-1234-efab-345678901234 (lowercase - keep, has lineage)

  const uppercaseId = 'E5F6A7B8-C9D0-1234-EFAB-345678901234';
  const lowercaseId = 'e5f6a7b8-c9d0-1234-efab-345678901234';

  // Delete the uppercase duplicate
  const uppercaseRef = db.doc(`users/demo_bigshare/recipes/${uppercaseId}`);
  const uppercaseDoc = await uppercaseRef.get();

  if (uppercaseDoc.exists) {
    await uppercaseRef.delete();
    console.log(`Deleted duplicate recipe: ${uppercaseId}`);
  } else {
    console.log(`Uppercase recipe not found (already deleted?): ${uppercaseId}`);
  }

  // Verify lowercase version exists with correct data
  const lowercaseRef = db.doc(`users/demo_bigshare/recipes/${lowercaseId}`);
  const lowercaseDoc = await lowercaseRef.get();

  if (lowercaseDoc.exists) {
    const data = lowercaseDoc.data()!;
    console.log(`\nVerified lowercase recipe exists: ${lowercaseId}`);
    console.log(`  Title: ${data.title}`);
    console.log(`  Source Type: ${data.sourceType}`);
  } else {
    console.log(`WARNING: Lowercase recipe not found: ${lowercaseId}`);
  }

  // Verify lineage exists
  const lineage = await db.doc('lineages/bigshare-lineage-e5f6a7b8-c9d0-1234-efab-345678901234').get();
  if (lineage.exists) {
    const data = lineage.data()!;
    console.log('\nLineage verified:');
    console.log(`  Generation: ${data.generation}`);
    console.log(`  Root Owner: ${data.rootOwnerId}`);
    console.log(`  Parent Owner: ${data.parentOwnerId}`);
    console.log(`  Title: ${data.title}`);
  } else {
    console.log('\nWARNING: Lineage document not found!');
  }

  // Delete the old lineage that doesn't have recipe title
  const oldLineageRef = db.doc('lineages/72B33B4E-831C-419A-85FE-74F60B7EB6E6');
  const oldLineage = await oldLineageRef.get();
  if (oldLineage.exists) {
    await oldLineageRef.delete();
    console.log('\nDeleted old lineage without recipe title');
  }

  console.log('\n=== Cleanup Complete ===');
}

cleanup().catch(console.error);
