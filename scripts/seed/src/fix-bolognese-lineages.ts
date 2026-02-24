import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.resolve(__dirname, '../../../service-account-key.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccountPath) });
}

const db = admin.firestore();

/**
 * Fix lineage records with correct recipe IDs:
 *
 * Gen 0: Grandmazing - a1b2c3d4-e5f6-7890-abcd-ef1234567890 (Grandma's Sunday Bolognese)
 *        ├── Gen 1: Phillip Fry - c3d4e5f6-a7b8-9012-cdef-123456789012 (Quick Weeknight Bolognese)
 *        │          └── Gen 2: Big Share - e5f6a7b8-c9d0-1234-efab-345678901234 (The Traveling Bolognese)
 *        │
 *        └── Gen 1: Maria Santos - b2c3d4e5-f6a7-8901-bcde-f12345678901 (Bolognese con Sofrito)
 *                   └── Gen 2: Marcus Johnson - d4e5f6a7-b8c9-0123-defa-234567890123 (Smoky Grilled Bolognese)
 */

const CORRECT_RECIPE_IDS = {
  grandmazing: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  phillipfry: 'c3d4e5f6-a7b8-9012-cdef-123456789012',
  maria: 'b2c3d4e5-f6a7-8901-bcde-f12345678901',
  bigshare: 'e5f6a7b8-c9d0-1234-efab-345678901234',
  marcus: 'd4e5f6a7-b8c9-0123-defa-234567890123',
};

async function fixLineages() {
  console.log('=== Fixing Bolognese Lineage Records ===\n');

  const now = admin.firestore.Timestamp.now();

  // Delete old incorrect lineages
  const oldLineages = [
    'lineage-maria-bolognese',
    'lineage-marcus-bolognese',
  ];
  for (const id of oldLineages) {
    const doc = await db.doc(`lineages/${id}`).get();
    if (doc.exists) {
      await doc.ref.delete();
      console.log(`Deleted old lineage: ${id}`);
    }
  }

  // 1. Maria Santos's lineage (Gen 1, from Grandmazing)
  const mariaLineage = {
    id: `lineage-maria-bolognese`,
    recipeId: CORRECT_RECIPE_IDS.maria,
    currentRecipeId: CORRECT_RECIPE_IDS.maria,
    ownerId: 'demo_chef_maria',
    ownerDisplayName: 'Maria Santos',
    generation: 1,
    rootRecipeId: CORRECT_RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: CORRECT_RECIPE_IDS.grandmazing,
    parentOwnerId: 'demo_grandmazing',
    title: 'Bolognese con Sofrito',
    isHeirloom: true,
    hasLocalModifications: true,
    modifications: [
      {
        id: 'mod-maria-1',
        timestamp: now,
        modifiedBy: 'demo_chef_maria',
        modifiedByName: 'Maria Santos',
        changeType: 'ingredient_modified',
        changeDescription: 'Added Spanish sofrito base',
        fieldChanged: 'ingredients',
      }
    ],
    createdAt: now,
    updatedAt: now,
    lastModified: now,
    isDemoSeed: true,
  };
  await db.collection('lineages').doc('lineage-maria-bolognese').set(mariaLineage);
  console.log('Created: Maria Santos lineage (Gen 1)');

  // 2. Marcus Johnson's lineage (Gen 2, from Maria)
  const marcusLineage = {
    id: `lineage-marcus-bolognese`,
    recipeId: CORRECT_RECIPE_IDS.marcus,
    currentRecipeId: CORRECT_RECIPE_IDS.marcus,
    ownerId: 'demo_grillmaster',
    ownerDisplayName: 'Marcus Johnson',
    generation: 2,
    rootRecipeId: CORRECT_RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: CORRECT_RECIPE_IDS.maria,
    parentOwnerId: 'demo_chef_maria',
    title: 'Smoky Grilled Bolognese',
    isHeirloom: true,
    hasLocalModifications: true,
    modifications: [
      {
        id: 'mod-marcus-1',
        timestamp: now,
        modifiedBy: 'demo_grillmaster',
        modifiedByName: 'Marcus Johnson',
        changeType: 'technique_modified',
        changeDescription: 'Added smoky char from the grill',
        fieldChanged: 'instructions',
      }
    ],
    createdAt: now,
    updatedAt: now,
    lastModified: now,
    isDemoSeed: true,
  };
  await db.collection('lineages').doc('lineage-marcus-bolognese').set(marcusLineage);
  console.log('Created: Marcus Johnson lineage (Gen 2)');

  console.log('\n=== Verifying All Lineages ===\n');

  const lineages = await db.collection('lineages').get();
  const bolLineages = lineages.docs.filter(doc => {
    const d = doc.data();
    return d.rootRecipeId === CORRECT_RECIPE_IDS.grandmazing ||
           d.recipeId === CORRECT_RECIPE_IDS.grandmazing;
  });

  console.log('Bolognese lineage tree:');
  bolLineages.sort((a, b) => (a.data().generation || 0) - (b.data().generation || 0));
  for (const doc of bolLineages) {
    const d = doc.data();
    const indent = '  '.repeat(d.generation || 0);
    console.log(`${indent}Gen ${d.generation}: ${d.ownerDisplayName} - ${d.title}`);
    console.log(`${indent}  Recipe ID: ${d.recipeId}`);
  }
}

fixLineages().catch(console.error);
