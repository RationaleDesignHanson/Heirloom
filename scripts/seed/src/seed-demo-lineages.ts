/**
 * Seed lineage records for demo user recipes
 *
 * This creates the initial (generation 1) lineage records that enable
 * version tracking when recipes are shared and modified.
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

// Demo user welcome recipes that need lineage records
// NOTE: Use lowercase UUIDs to match Swift's UUID.firebaseString convention
const DEMO_RECIPES = [
  {
    userId: 'demo_grandmazing',
    recipeId: '5e13b837-1a80-4d22-af8a-c474a6ea5c35',
    title: 'Brown Butter Chocolate Chip Cookies',
    displayName: 'Grandmazing',
  },
  {
    userId: 'demo_phillipfry',
    recipeId: '7ee0a981-0dd2-4105-aa26-ab941c23d688',
    title: 'Creamy One-Pot Pasta',
    displayName: 'Phillip Fry',
  },
  {
    userId: 'demo_chef_maria',
    recipeId: '5d5a16d4-4fc2-483b-9737-7d0451f3c236',
    title: 'Camarones al Ajillo (Garlic Shrimp)',
    displayName: 'Maria Santos',
  },
  {
    userId: 'demo_fitfoodie',
    recipeId: 'f3890dc5-f51a-455a-8bf2-eb4bb089c5a9',
    title: 'Ultimate Protein Power Bowl',
    displayName: 'Alex Chen',
  },
  {
    userId: 'demo_bakingbelle',
    recipeId: 'fceb840f-6acb-49f3-a7f0-e1da3de286ff',
    title: 'Molten Chocolate Lava Cakes',
    displayName: 'Belle Thompson',
  },
  {
    userId: 'demo_grillmaster',
    recipeId: '1de8ec4c-7629-466d-b39b-87d97b48ec9f',
    title: 'Ultimate Smash Burgers',
    displayName: 'Marcus Johnson',
  },
];

async function seedDemoLineages(): Promise<void> {
  console.log('Seeding lineage records for demo user recipes...\n');

  const now = new Date();

  for (const recipe of DEMO_RECIPES) {
    // Create lineage record in global lineages collection
    // This is the "generation 0" record - the original recipe (root)
    const lineageData = {
      id: recipe.recipeId, // Use recipe ID as lineage ID for determinism
      recipeId: recipe.recipeId,
      currentRecipeId: recipe.recipeId, // CRITICAL: App queries by currentRecipeId
      ownerId: recipe.userId,
      ownerDisplayName: recipe.displayName,
      generation: 0, // Root recipes are generation 0
      rootRecipeId: recipe.recipeId,
      rootOwnerId: recipe.userId,
      parentRecipeId: null,
      parentOwnerId: null,
      title: recipe.title,
      isHeirloom: true,
      hasLocalModifications: false,
      modifications: [],
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
      lastModified: admin.firestore.Timestamp.fromDate(now),
    };

    // Write to global lineages collection (used for cross-user queries)
    // Use deterministic ID to prevent duplicates on re-runs
    const globalLineageRef = db.collection('lineages').doc(`demo-lineage-${recipe.recipeId}`);
    await globalLineageRef.set(lineageData);

    // Also write to user's lineages subcollection (used for their own recipes)
    const userLineageRef = db.doc(`users/${recipe.userId}/lineages/${recipe.recipeId}`);
    await userLineageRef.set(lineageData);

    console.log(`✓ Created lineage for: ${recipe.title} (${recipe.displayName})`);
    console.log(`  Global: ${globalLineageRef.path}`);
    console.log(`  User: ${userLineageRef.path}\n`);
  }

  console.log('Done! Lineage records created for all demo recipes.');
}

seedDemoLineages()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
