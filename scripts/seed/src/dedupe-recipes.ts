/**
 * Remove duplicate recipes (same title, keep one)
 *
 * Run: npx ts-node src/dedupe-recipes.ts [--fix]
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

async function dedupeRecipes(email: string, dryRun: boolean): Promise<void> {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`${dryRun ? 'DRY RUN -' : 'FIXING'} ${email}`);
  console.log('='.repeat(60));

  try {
    const user = await auth.getUserByEmail(email);
    const userId = user.uid;

    // Get all recipes
    const recipesSnap = await db.collection('users').doc(userId).collection('recipes').get();

    // Group by title
    const byTitle: Map<string, admin.firestore.QueryDocumentSnapshot[]> = new Map();
    recipesSnap.docs.forEach(doc => {
      const title = doc.data().title || 'Untitled';
      if (!byTitle.has(title)) {
        byTitle.set(title, []);
      }
      byTitle.get(title)!.push(doc);
    });

    // Find duplicates
    const toDelete: admin.firestore.QueryDocumentSnapshot[] = [];

    for (const [title, docs] of byTitle) {
      if (docs.length > 1) {
        // Sort by createdAt (keep oldest) or by most data
        docs.sort((a, b) => {
          const aTime = a.data().createdAt?.toMillis?.() || a.data().createdAt || 0;
          const bTime = b.data().createdAt?.toMillis?.() || b.data().createdAt || 0;
          return aTime - bTime; // Oldest first
        });

        const keep = docs[0];
        const duplicates = docs.slice(1);

        console.log(`\n"${title}" - ${docs.length} copies`);
        console.log(`  KEEP: ${keep.id}`);
        duplicates.forEach(d => {
          console.log(`  DELETE: ${d.id}`);
          toDelete.push(d);
        });
      }
    }

    if (toDelete.length === 0) {
      console.log('\n✅ No duplicate recipes found');
      return;
    }

    console.log(`\nTotal to delete: ${toDelete.length}`);

    if (!dryRun) {
      // Also need to remove recipe IDs from collections
      const collectionsSnap = await db.collection('users').doc(userId).collection('collections').get();
      const deleteIds = new Set(toDelete.map(d => d.id));

      console.log('\nRemoving from collections...');
      for (const collDoc of collectionsSnap.docs) {
        const recipeIds: string[] = collDoc.data().recipeIds || [];
        const filtered = recipeIds.filter(id => !deleteIds.has(id));
        if (filtered.length !== recipeIds.length) {
          console.log(`  ${collDoc.data().name}: ${recipeIds.length} → ${filtered.length} recipes`);
          await collDoc.ref.update({ recipeIds: filtered });
        }
      }

      console.log('\nDeleting recipes...');
      for (const doc of toDelete) {
        await doc.ref.delete();
      }
      console.log('Done!');
    }

    // Show final count
    const finalRecipes = await db.collection('users').doc(userId).collection('recipes').get();
    console.log(`\nFinal recipe count: ${finalRecipes.size}`);

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

  await dedupeRecipes('demo@heirloomrecipebox.app', dryRun);
  await dedupeRecipes('deletetest@heirloomrecipebox.app', dryRun);

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
