/**
 * Fix test accounts - remove duplicate collections
 *
 * Run: npx ts-node src/fix-test-accounts.ts [--fix]
 *
 * Without --fix: Dry run
 * With --fix: Actually deletes duplicates
 */

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
const auth = admin.auth();

async function fixAccount(email: string, dryRun: boolean): Promise<void> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`${dryRun ? 'DRY RUN -' : 'FIXING'} ${email}`);
  console.log('='.repeat(60));

  try {
    const user = await auth.getUserByEmail(email);
    console.log(`User ID: ${user.uid}`);

    const collectionsRef = db.collection('users').doc(user.uid).collection('collections');
    const collections = await collectionsRef.get();

    // Group by name
    const byName: Record<string, admin.firestore.QueryDocumentSnapshot[]> = {};
    collections.docs.forEach(doc => {
      const name = doc.data().name || 'Unnamed';
      if (!byName[name]) byName[name] = [];
      byName[name].push(doc);
    });

    let toDelete: admin.firestore.QueryDocumentSnapshot[] = [];

    for (const [name, docs] of Object.entries(byName)) {
      if (docs.length > 1) {
        // Keep the one with most recipes, or the oldest one
        docs.sort((a, b) => {
          const aRecipes = a.data().recipeIds?.length || 0;
          const bRecipes = b.data().recipeIds?.length || 0;
          if (aRecipes !== bRecipes) return bRecipes - aRecipes; // More recipes first
          // Otherwise keep oldest (by createdAt)
          const aTime = a.data().createdAt?.toMillis?.() || 0;
          const bTime = b.data().createdAt?.toMillis?.() || 0;
          return aTime - bTime;
        });

        // Keep first, delete rest
        const keep = docs[0];
        const duplicates = docs.slice(1);

        console.log(`\n"${name}" - ${docs.length} copies`);
        console.log(`  KEEP: ${keep.id} (${keep.data().recipeIds?.length || 0} recipes)`);
        duplicates.forEach(d => {
          console.log(`  DELETE: ${d.id} (${d.data().recipeIds?.length || 0} recipes)`);
        });

        toDelete.push(...duplicates);
      }
    }

    console.log(`\nTotal to delete: ${toDelete.length}`);

    if (!dryRun && toDelete.length > 0) {
      console.log('\nDeleting...');
      for (const doc of toDelete) {
        await doc.ref.delete();
      }
      console.log('Done!');
    }

    // Show final state
    const finalCollections = await collectionsRef.get();
    console.log(`\nFinal collection count: ${finalCollections.size}`);

  } catch (error: any) {
    if (error.code === 'auth/user-not-found') {
      console.log('User not found');
    } else {
      throw error;
    }
  }
}

async function main() {
  const dryRun = !process.argv.includes('--fix');

  console.log('\n' + '='.repeat(60));
  console.log(dryRun ? 'DRY RUN MODE - No changes will be made' : 'LIVE MODE - Will delete duplicates');
  console.log('='.repeat(60));

  await fixAccount('demo@heirloomrecipebox.app', dryRun);
  // Don't touch deletetest@ - it looks clean

  if (dryRun) {
    console.log('\n\nRun with --fix to actually delete duplicates');
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
