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
 * Creates the full branching lineage tree for The Traveling Bolognese:
 *
 * Gen 0: Grandmazing (root) - a1b2c3d4-e5f6-7890-abcd-ef1234567890
 *        ├── Gen 1: Phillip Fry - c3d4e5f6-a7b8-9012-cdef-123456789012
 *        │          └── Gen 2: Big Share - e5f6a7b8-c9d0-1234-efab-345678901234
 *        │
 *        └── Gen 1: Maria Santos - d4e5f6a7-b8c9-0123-defa-234567890123
 *                   └── Gen 2: Marcus Johnson - f6a7b8c9-d0e1-2345-fabc-456789012345
 *
 * When tester01 accepts from Big Share, they become Gen 3.
 */

// Recipe IDs (using consistent lowercase UUIDs)
const RECIPE_IDS = {
  grandmazing: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
  phillipfry: 'c3d4e5f6-a7b8-9012-cdef-123456789012',
  maria: 'd4e5f6a7-b8c9-0123-defa-234567890123',
  bigshare: 'e5f6a7b8-c9d0-1234-efab-345678901234',
  marcus: 'f6a7b8c9-d0e1-2345-fabc-456789012345',
};

// Lineage IDs
const LINEAGE_IDS = {
  grandmazing: 'lineage-grandmazing-bolognese',
  phillipfry: 'lineage-phillipfry-bolognese',
  maria: 'lineage-maria-bolognese',
  bigshare: 'lineage-bigshare-bolognese',
  marcus: 'lineage-marcus-bolognese',
};

async function seedLineageTree() {
  console.log('=== Seeding Bolognese Lineage Tree ===\n');

  const now = admin.firestore.Timestamp.now();

  // 1. Grandmazing's root lineage (Gen 0)
  const grandmazingLineage = {
    id: LINEAGE_IDS.grandmazing,
    recipeId: RECIPE_IDS.grandmazing,
    currentRecipeId: RECIPE_IDS.grandmazing,
    ownerId: 'demo_grandmazing',
    ownerDisplayName: 'Grandmazing',
    generation: 0,
    rootRecipeId: RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: null,
    parentOwnerId: null,
    title: "Grandma's Sunday Bolognese",
    isHeirloom: true,
    hasLocalModifications: false,
    modifications: [],
    createdAt: now,
    updatedAt: now,
    lastModified: now,
    isDemoSeed: true,
    demoSeedLabel: 'bolognese-root',
  };
  await db.collection('lineages').doc(LINEAGE_IDS.grandmazing).set(grandmazingLineage);
  console.log('Created: Grandmazing lineage (Gen 0)');

  // 2. Phillip Fry's lineage (Gen 1, from Grandmazing)
  const phillipfryLineage = {
    id: LINEAGE_IDS.phillipfry,
    recipeId: RECIPE_IDS.phillipfry,
    currentRecipeId: RECIPE_IDS.phillipfry,
    ownerId: 'demo_phillipfry',
    ownerDisplayName: 'Phillip Fry',
    generation: 1,
    rootRecipeId: RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: RECIPE_IDS.grandmazing,
    parentOwnerId: 'demo_grandmazing',
    title: 'Quick Weeknight Bolognese',
    isHeirloom: true,
    hasLocalModifications: true,
    modifications: [
      {
        id: 'mod-phillipfry-1',
        timestamp: now,
        modifiedBy: 'demo_phillipfry',
        modifiedByName: 'Phillip Fry',
        changeType: 'time_modified',
        changeDescription: 'Simplified for weeknight cooking',
        fieldChanged: 'instructions',
      }
    ],
    createdAt: now,
    updatedAt: now,
    lastModified: now,
    isDemoSeed: true,
    demoSeedLabel: 'bolognese-phillipfry',
  };
  await db.collection('lineages').doc(LINEAGE_IDS.phillipfry).set(phillipfryLineage);
  console.log('Created: Phillip Fry lineage (Gen 1)');

  // 3. Maria Santos's lineage (Gen 1, from Grandmazing - different branch)
  const mariaLineage = {
    id: LINEAGE_IDS.maria,
    recipeId: RECIPE_IDS.maria,
    currentRecipeId: RECIPE_IDS.maria,
    ownerId: 'demo_chef_maria',
    ownerDisplayName: 'Maria Santos',
    generation: 1,
    rootRecipeId: RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: RECIPE_IDS.grandmazing,
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
    demoSeedLabel: 'bolognese-maria',
  };
  await db.collection('lineages').doc(LINEAGE_IDS.maria).set(mariaLineage);
  console.log('Created: Maria Santos lineage (Gen 1)');

  // 4. Big Share's lineage (Gen 2, from Phillip Fry)
  const bigshareLineage = {
    id: LINEAGE_IDS.bigshare,
    recipeId: RECIPE_IDS.bigshare,
    currentRecipeId: RECIPE_IDS.bigshare,
    ownerId: 'demo_bigshare',
    ownerDisplayName: 'Big Share',
    generation: 2,
    rootRecipeId: RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: RECIPE_IDS.phillipfry,
    parentOwnerId: 'demo_phillipfry',
    title: 'The Traveling Bolognese',
    isHeirloom: true,
    hasLocalModifications: true,
    modifications: [
      {
        id: 'mod-bigshare-1',
        timestamp: now,
        modifiedBy: 'demo_bigshare',
        modifiedByName: 'Big Share',
        changeType: 'ingredient_added',
        changeDescription: 'Added red wine for depth',
        fieldChanged: 'ingredients',
      }
    ],
    createdAt: now,
    updatedAt: now,
    lastModified: now,
    isDemoSeed: true,
    demoSeedLabel: 'bolognese-bigshare',
  };
  await db.collection('lineages').doc(LINEAGE_IDS.bigshare).set(bigshareLineage);
  console.log('Created: Big Share lineage (Gen 2)');

  // 5. Marcus Johnson's lineage (Gen 2, from Maria - different branch)
  const marcusLineage = {
    id: LINEAGE_IDS.marcus,
    recipeId: RECIPE_IDS.marcus,
    currentRecipeId: RECIPE_IDS.marcus,
    ownerId: 'demo_grillmaster',
    ownerDisplayName: 'Marcus Johnson',
    generation: 2,
    rootRecipeId: RECIPE_IDS.grandmazing,
    rootOwnerId: 'demo_grandmazing',
    parentRecipeId: RECIPE_IDS.maria,
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
    demoSeedLabel: 'bolognese-marcus',
  };
  await db.collection('lineages').doc(LINEAGE_IDS.marcus).set(marcusLineage);
  console.log('Created: Marcus Johnson lineage (Gen 2)');

  // Also delete the old lineage document that has wrong data
  const oldLineage = await db.doc('lineages/bigshare-lineage-e5f6a7b8-c9d0-1234-efab-345678901234').get();
  if (oldLineage.exists) {
    await oldLineage.ref.delete();
    console.log('\nDeleted old lineage document');
  }

  console.log('\n=== Lineage Tree Complete ===');
  console.log('\nTree structure:');
  console.log('  Grandmazing (Gen 0)');
  console.log('  ├── Phillip Fry (Gen 1)');
  console.log('  │   └── Big Share (Gen 2)');
  console.log('  │       └── [tester01 will be Gen 3]');
  console.log('  └── Maria Santos (Gen 1)');
  console.log('      └── Marcus Johnson (Gen 2)');
}

async function verifyRecipes() {
  console.log('\n=== Verifying Demo Recipes Exist ===');

  const users = [
    { id: 'demo_grandmazing', name: 'Grandmazing', recipeId: RECIPE_IDS.grandmazing },
    { id: 'demo_phillipfry', name: 'Phillip Fry', recipeId: RECIPE_IDS.phillipfry },
    { id: 'demo_chef_maria', name: 'Maria Santos', recipeId: RECIPE_IDS.maria },
    { id: 'demo_bigshare', name: 'Big Share', recipeId: RECIPE_IDS.bigshare },
    { id: 'demo_grillmaster', name: 'Marcus Johnson', recipeId: RECIPE_IDS.marcus },
  ];

  for (const user of users) {
    // Check if recipe exists
    const recipeDoc = await db.doc(`users/${user.id}/recipes/${user.recipeId}`).get();
    if (recipeDoc.exists) {
      console.log(`✓ ${user.name}: ${recipeDoc.data()?.title}`);
    } else {
      console.log(`✗ ${user.name}: Recipe ${user.recipeId} NOT FOUND`);
    }
  }
}

async function main() {
  await seedLineageTree();
  await verifyRecipes();
}

main().catch(console.error);
