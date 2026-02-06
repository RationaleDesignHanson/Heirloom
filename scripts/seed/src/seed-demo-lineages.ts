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
const DEMO_RECIPES = [
  {
    userId: 'demo_grandmazing',
    recipeId: '5E13B837-1A80-4D22-AF8A-C474A6EA5C35',
    title: 'Brown Butter Chocolate Chip Cookies',
    displayName: 'Grandmazing',
  },
  {
    userId: 'demo_phillipfry',
    recipeId: '7EE0A981-0DD2-4105-AA26-AB941C23D688',
    title: 'Creamy One-Pot Pasta',
    displayName: 'Phillip Fry',
  },
  {
    userId: 'demo_chef_maria',
    recipeId: '5D5A16D4-4FC2-483B-9737-7D0451F3C236',
    title: 'Camarones al Ajillo (Garlic Shrimp)',
    displayName: 'Maria Santos',
  },
  {
    userId: 'demo_fitfoodie',
    recipeId: 'F3890DC5-F51A-455A-8BF2-EB4BB089C5A9',
    title: 'Ultimate Protein Power Bowl',
    displayName: 'Alex Chen',
  },
  {
    userId: 'demo_bakingbelle',
    recipeId: 'FCEB840F-6ACB-49F3-A7F0-E1DA3DE286FF',
    title: 'Molten Chocolate Lava Cakes',
    displayName: 'Belle Thompson',
  },
  {
    userId: 'demo_grillmaster',
    recipeId: '1DE8EC4C-7629-466D-B39B-87D97B48EC9F',
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
    const globalLineageRef = db.collection('lineages').doc();
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
