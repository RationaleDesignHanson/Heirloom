/**
 * Mark existing collections as isDemoSeed for a given user
 *
 * Run: npx ts-node src/mark-demo-seed.ts <email>
 * Example: npx ts-node src/mark-demo-seed.ts hanson@rationale.work
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function markCollectionsAsDemoSeed(email: string): Promise<void> {
  console.log(`\nMarking collections as isDemoSeed for: ${email}\n`);

  try {
    const user = await auth.getUserByEmail(email);
    console.log(`Found user: ${user.uid}`);

    const collectionsRef = db.collection('users').doc(user.uid).collection('collections');
    const snapshot = await collectionsRef.get();

    console.log(`Found ${snapshot.size} collections\n`);

    let updated = 0;
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const name = data.name || 'Unnamed';
      const currentValue = data.isDemoSeed || false;

      if (!currentValue) {
        await doc.ref.update({ isDemoSeed: true });
        console.log(`  ✓ ${name} - marked as isDemoSeed`);
        updated++;
      } else {
        console.log(`  - ${name} - already isDemoSeed`);
      }
    }

    console.log(`\n✅ Updated ${updated} collections`);

  } catch (error: any) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

// CLI handling
if (require.main === module) {
  const email = process.argv[2];

  if (!email) {
    console.log('Usage: npx ts-node src/mark-demo-seed.ts <email>');
    console.log('Example: npx ts-node src/mark-demo-seed.ts hanson@rationale.work');
    process.exit(1);
  }

  markCollectionsAsDemoSeed(email)
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Error:', err);
      process.exit(1);
    });
}

export { markCollectionsAsDemoSeed };
