/**
 * One-time migration: Add recipeVersion to all theme documents
 *
 * Usage:
 *   node scripts/migrate-theme-versions.js
 *
 * Prerequisites:
 *   - Firebase Admin SDK credentials (GOOGLE_APPLICATION_CREDENTIALS env var or default project)
 *   - Run from project root: cd /path/to/Heirloom && node scripts/migrate-theme-versions.js
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin with service account credentials
const serviceAccount = require(path.join(__dirname, 'firebase', 'serviceAccountKey.json'));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function migrateThemeVersions() {
  console.log('Starting theme version migration...');

  const themes = await db.collection('themes').get();

  if (themes.empty) {
    console.log('No themes found. Nothing to migrate.');
    return;
  }

  console.log(`Found ${themes.size} themes. Adding recipeVersion: 1...`);

  let updated = 0;
  let skipped = 0;

  for (const doc of themes.docs) {
    const data = doc.data();

    // Skip if already has recipeVersion
    if (data.recipeVersion !== undefined) {
      console.log(`  Skipped: ${doc.id} (${data.name || 'unnamed'}) — already has recipeVersion: ${data.recipeVersion}`);
      skipped++;
      continue;
    }

    await doc.ref.update({
      recipeVersion: 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`  Updated: ${doc.id} (${data.name || 'unnamed'}) — set recipeVersion: 1`);
    updated++;
  }

  console.log(`\nMigration complete. Updated: ${updated}, Skipped: ${skipped}, Total: ${themes.size}`);
}

migrateThemeVersions()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Migration failed:', error);
    process.exit(1);
  });
