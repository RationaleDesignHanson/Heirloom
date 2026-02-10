/**
 * Bigshare Lineage Seed
 *
 * Creates a 5-node, 3-generation lineage tree for the demo "Traveling Bolognese".
 * When a real user friends demo_bigshare and accepts his shared recipe,
 * they become Gen 3 and see the full history above them.
 *
 * Tree structure:
 *   Gen 0: demo_grandmazing    - "Grandma's Sunday Bolognese"  (ROOT)
 *   Gen 1: demo_chef_maria     - "Bolognese con Sofrito"       (from ROOT)
 *   Gen 1: demo_phillipfry     - "Quick Weeknight Bolognese"   (from ROOT)
 *   Gen 2: demo_grillmaster    - "Smoky Grilled Bolognese"     (from Maria)
 *   Gen 2: demo_bigshare       - "The Traveling Bolognese"     (from Phillip)
 */

import { initializeFirebase, getDb, toTimestamp, daysAgo } from '../utils/firebase';
import { v4 as uuidv4 } from 'uuid';

// Stable UUIDs for the lineage tree (must match DemoSocialBehaviorService.swift)
const ROOT_UUID = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';
const UUID_B = 'B2C3D4E5-F6A7-8901-BCDE-F12345678901';
const UUID_C = 'C3D4E5F6-A7B8-9012-CDEF-123456789012';
const UUID_D = 'D4E5F6A7-B8C9-0123-DEFA-234567890123';
const UUID_E = 'E5F6A7B8-C9D0-1234-EFAB-345678901234';

const ROOT_OWNER = 'demo_grandmazing';

// Bolognese image URL (shared across all variants for v1)
const BOLOGNESE_IMAGE = 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare_bolognese-image.webp';

interface RecipeNode {
  recipeId: string;
  ownerId: string;
  ownerName: string;
  title: string;
  description: string;
  generation: number;
  parentRecipeId: string | null;
  parentOwnerId: string | null;
  servings: string;
  prepTime: string;
  cookTime: string;
  createdDaysAgo: number;
  ingredients: Array<{ text: string; name: string; amount: number | null; unit: string; order: number }>;
  instructions: Array<{ text: string; order: number }>;
}

const LINEAGE_NODES: RecipeNode[] = [
  // Gen 0: Grandmazing - the original
  {
    recipeId: ROOT_UUID,
    ownerId: 'demo_grandmazing',
    ownerName: 'Grandmazing',
    title: "Grandma's Sunday Bolognese",
    description: 'The recipe that started it all. Slow-simmered for hours, the way my grandmother made it every Sunday in Vermont.',
    generation: 0,
    parentRecipeId: null,
    parentOwnerId: null,
    servings: '8 servings',
    prepTime: '20',
    cookTime: '240',
    createdDaysAgo: 180,
    ingredients: [
      { text: '1 lb ground beef', name: 'ground beef', amount: 1, unit: 'lb', order: 0 },
      { text: '1 can (28 oz) crushed tomatoes', name: 'crushed tomatoes', amount: 28, unit: 'oz', order: 1 },
      { text: '1 can (6 oz) tomato paste', name: 'tomato paste', amount: 6, unit: 'oz', order: 2 },
      { text: '1 large onion, diced', name: 'onion', amount: 1, unit: '', order: 3 },
      { text: '4 cloves garlic, minced', name: 'garlic', amount: 4, unit: 'cloves', order: 4 },
      { text: '1/2 cup whole milk', name: 'whole milk', amount: 0.5, unit: 'cup', order: 5 },
      { text: '2 bay leaves', name: 'bay leaves', amount: 2, unit: '', order: 6 },
      { text: '1 tsp dried oregano', name: 'dried oregano', amount: 1, unit: 'tsp', order: 7 },
      { text: '2 tbsp olive oil', name: 'olive oil', amount: 2, unit: 'tbsp', order: 8 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 9 },
    ],
    instructions: [
      { text: 'Heat olive oil in a large Dutch oven over medium heat. Add diced onion and cook until translucent, about 5 minutes.', order: 0 },
      { text: 'Add garlic and cook for 1 minute until fragrant.', order: 1 },
      { text: 'Add ground beef, breaking it up with a wooden spoon. Cook until browned, about 8 minutes.', order: 2 },
      { text: 'Stir in tomato paste and cook for 2 minutes to deepen the flavor.', order: 3 },
      { text: 'Add crushed tomatoes, milk, bay leaves, and oregano. Stir to combine.', order: 4 },
      { text: 'Bring to a gentle simmer, then reduce heat to low. Cover and cook for 3-4 hours, stirring occasionally.', order: 5 },
      { text: 'Remove bay leaves. Season with salt and pepper to taste.', order: 6 },
      { text: 'Serve over fresh pasta with grated Parmigiano-Reggiano.', order: 7 },
    ],
  },

  // Gen 1: Maria Santos - added Latin flair
  {
    recipeId: UUID_B,
    ownerId: 'demo_chef_maria',
    ownerName: 'Maria Santos',
    title: 'Bolognese con Sofrito',
    description: "I took Grandmazing's classic and added my Latin touch - a proper sofrito base and a splash of red wine. The smoked paprika makes all the difference.",
    generation: 1,
    parentRecipeId: ROOT_UUID,
    parentOwnerId: ROOT_OWNER,
    servings: '8 servings',
    prepTime: '25',
    cookTime: '240',
    createdDaysAgo: 120,
    ingredients: [
      { text: '1 lb ground beef', name: 'ground beef', amount: 1, unit: 'lb', order: 0 },
      { text: '1 can (28 oz) crushed tomatoes', name: 'crushed tomatoes', amount: 28, unit: 'oz', order: 1 },
      { text: '1 can (6 oz) tomato paste', name: 'tomato paste', amount: 6, unit: 'oz', order: 2 },
      { text: '1 large onion, diced', name: 'onion', amount: 1, unit: '', order: 3 },
      { text: '8 cloves garlic, minced', name: 'garlic', amount: 8, unit: 'cloves', order: 4 },
      { text: '1/2 cup whole milk', name: 'whole milk', amount: 0.5, unit: 'cup', order: 5 },
      { text: '2 bay leaves', name: 'bay leaves', amount: 2, unit: '', order: 6 },
      { text: '1 tsp dried oregano', name: 'dried oregano', amount: 1, unit: 'tsp', order: 7 },
      { text: '2 tbsp olive oil', name: 'olive oil', amount: 2, unit: 'tbsp', order: 8 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 9 },
      // Maria's additions
      { text: '1 cup dry red wine', name: 'dry red wine', amount: 1, unit: 'cup', order: 10 },
      { text: '1 red bell pepper, diced (sofrito base)', name: 'red bell pepper', amount: 1, unit: '', order: 11 },
      { text: '1 tsp smoked paprika', name: 'smoked paprika', amount: 1, unit: 'tsp', order: 12 },
    ],
    instructions: [
      { text: 'Heat olive oil in a large Dutch oven over medium heat. Add diced onion and red bell pepper (sofrito base) and cook until soft, about 7 minutes.', order: 0 },
      { text: 'Add garlic (doubled!) and smoked paprika. Cook for 1 minute until fragrant.', order: 1 },
      { text: 'Add ground beef, breaking it up with a wooden spoon. Cook until browned, about 8 minutes.', order: 2 },
      { text: 'Pour in red wine and let it reduce by half, scraping up the fond from the bottom.', order: 3 },
      { text: 'Stir in tomato paste and cook for 2 minutes to deepen the flavor.', order: 4 },
      { text: 'Add crushed tomatoes, milk, bay leaves, and oregano. Stir to combine.', order: 5 },
      { text: 'Bring to a gentle simmer, then reduce heat to low. Cover and cook for 3-4 hours, stirring occasionally.', order: 6 },
      { text: 'Remove bay leaves. Season with salt and pepper. Serve over pasta with grated manchego.', order: 7 },
    ],
  },

  // Gen 1: Phillip Fry - made it quick
  {
    recipeId: UUID_C,
    ownerId: 'demo_phillipfry',
    ownerName: 'Phillip Fry',
    title: 'Quick Weeknight Bolognese',
    description: "Love Grandmazing's recipe but who has 4 hours on a Tuesday? I swapped in turkey, cut the cook time to 30 minutes, and added red pepper flakes for kick.",
    generation: 1,
    parentRecipeId: ROOT_UUID,
    parentOwnerId: ROOT_OWNER,
    servings: '4 servings',
    prepTime: '10',
    cookTime: '30',
    createdDaysAgo: 90,
    ingredients: [
      { text: '1 lb ground turkey', name: 'ground turkey', amount: 1, unit: 'lb', order: 0 },
      { text: '1 can (28 oz) crushed tomatoes', name: 'crushed tomatoes', amount: 28, unit: 'oz', order: 1 },
      { text: '2 tbsp tomato paste', name: 'tomato paste', amount: 2, unit: 'tbsp', order: 2 },
      { text: '1 medium onion, diced', name: 'onion', amount: 1, unit: '', order: 3 },
      { text: '3 cloves garlic, minced', name: 'garlic', amount: 3, unit: 'cloves', order: 4 },
      { text: '1 tsp dried oregano', name: 'dried oregano', amount: 1, unit: 'tsp', order: 5 },
      { text: '1/2 tsp red pepper flakes', name: 'red pepper flakes', amount: 0.5, unit: 'tsp', order: 6 },
      { text: '2 tbsp olive oil', name: 'olive oil', amount: 2, unit: 'tbsp', order: 7 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 8 },
    ],
    instructions: [
      { text: 'Heat olive oil in a large skillet over medium-high heat. Add onion, cook 3 minutes.', order: 0 },
      { text: 'Add garlic and red pepper flakes. Cook 30 seconds.', order: 1 },
      { text: 'Add ground turkey, break apart and cook until no longer pink, about 5 minutes.', order: 2 },
      { text: 'Stir in tomato paste, then add crushed tomatoes and oregano.', order: 3 },
      { text: 'Simmer uncovered for 20 minutes, stirring occasionally. The sauce will thicken nicely.', order: 4 },
      { text: 'Season with salt and pepper. Serve over your favorite pasta.', order: 5 },
    ],
  },

  // Gen 2: Marcus Johnson (Grillmaster) - smoky grilled version from Maria's
  {
    recipeId: UUID_D,
    ownerId: 'demo_grillmaster',
    ownerName: 'Marcus Johnson',
    title: 'Smoky Grilled Bolognese',
    description: "Maria's sofrito version inspired me to go full smoky. I grill the peppers and zucchini first, then fold them in. The charred flavor is unreal.",
    generation: 2,
    parentRecipeId: UUID_B,
    parentOwnerId: 'demo_chef_maria',
    servings: '8 servings',
    prepTime: '30',
    cookTime: '240',
    createdDaysAgo: 60,
    ingredients: [
      { text: '1 lb ground beef', name: 'ground beef', amount: 1, unit: 'lb', order: 0 },
      { text: '1 can (28 oz) crushed tomatoes', name: 'crushed tomatoes', amount: 28, unit: 'oz', order: 1 },
      { text: '1 can (6 oz) tomato paste', name: 'tomato paste', amount: 6, unit: 'oz', order: 2 },
      { text: '1 large onion, diced', name: 'onion', amount: 1, unit: '', order: 3 },
      { text: '6 cloves garlic, minced', name: 'garlic', amount: 6, unit: 'cloves', order: 4 },
      { text: '1/2 cup whole milk', name: 'whole milk', amount: 0.5, unit: 'cup', order: 5 },
      { text: '2 bay leaves', name: 'bay leaves', amount: 2, unit: '', order: 6 },
      { text: '1 tsp dried oregano', name: 'dried oregano', amount: 1, unit: 'tsp', order: 7 },
      { text: '2 tbsp olive oil', name: 'olive oil', amount: 2, unit: 'tbsp', order: 8 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 9 },
      { text: '1 cup dry red wine', name: 'dry red wine', amount: 1, unit: 'cup', order: 10 },
      { text: '2 tsp smoked paprika', name: 'smoked paprika', amount: 2, unit: 'tsp', order: 11 },
      // Marcus's additions
      { text: '2 bell peppers, grilled and chopped', name: 'grilled bell peppers', amount: 2, unit: '', order: 12 },
      { text: '1 large zucchini, grilled and diced', name: 'grilled zucchini', amount: 1, unit: '', order: 13 },
    ],
    instructions: [
      { text: 'Fire up the grill to high heat. Halve the bell peppers and slice zucchini lengthwise. Brush with oil and grill 4-5 minutes per side until charred.', order: 0 },
      { text: 'Chop the grilled vegetables and set aside.', order: 1 },
      { text: 'Heat olive oil in a large Dutch oven over medium heat. Add onion, cook until translucent.', order: 2 },
      { text: 'Add garlic and smoked paprika (doubled from Maria\'s version). Cook 1 minute.', order: 3 },
      { text: 'Add ground beef, brown well. Pour in red wine, reduce by half.', order: 4 },
      { text: 'Add tomato paste, crushed tomatoes, milk, bay leaves, oregano. Simmer low for 3-4 hours.', order: 5 },
      { text: 'Fold in the grilled peppers and zucchini in the last 30 minutes.', order: 6 },
      { text: 'Remove bay leaves. Season and serve. The smoky char from the grilled veg makes this version special.', order: 7 },
    ],
  },

  // Gen 2: Big Share - the traveling version from Phillip's
  {
    recipeId: UUID_E,
    ownerId: 'demo_bigshare',
    ownerName: 'Big Share',
    title: 'The Traveling Bolognese',
    description: "I took Phillip's quick version and brought it back to slow-cooking territory. Added brown sugar for depth and simplified the instructions so anyone can nail it.",
    generation: 2,
    parentRecipeId: UUID_C,
    parentOwnerId: 'demo_phillipfry',
    servings: '6 servings',
    prepTime: '15',
    cookTime: '180',
    createdDaysAgo: 30,
    ingredients: [
      { text: '1.5 lbs ground beef', name: 'ground beef', amount: 1.5, unit: 'lbs', order: 0 },
      { text: '1 can (28 oz) crushed tomatoes', name: 'crushed tomatoes', amount: 28, unit: 'oz', order: 1 },
      { text: '3 tbsp tomato paste', name: 'tomato paste', amount: 3, unit: 'tbsp', order: 2 },
      { text: '1 large onion, diced', name: 'onion', amount: 1, unit: '', order: 3 },
      { text: '4 cloves garlic, minced', name: 'garlic', amount: 4, unit: 'cloves', order: 4 },
      { text: '1 tsp dried oregano', name: 'dried oregano', amount: 1, unit: 'tsp', order: 5 },
      { text: '1/2 tsp red pepper flakes', name: 'red pepper flakes', amount: 0.5, unit: 'tsp', order: 6 },
      { text: '2 tbsp olive oil', name: 'olive oil', amount: 2, unit: 'tbsp', order: 7 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 8 },
      // Big Share's additions
      { text: '1 tbsp brown sugar', name: 'brown sugar', amount: 1, unit: 'tbsp', order: 9 },
      { text: '1 tsp Worcestershire sauce', name: 'Worcestershire sauce', amount: 1, unit: 'tsp', order: 10 },
      { text: '1/2 cup beef broth', name: 'beef broth', amount: 0.5, unit: 'cup', order: 11 },
      { text: '1 carrot, finely grated', name: 'carrot', amount: 1, unit: '', order: 12 },
      { text: '1 stalk celery, finely diced', name: 'celery', amount: 1, unit: 'stalk', order: 13 },
    ],
    instructions: [
      { text: 'Heat olive oil over medium heat. Add onion, carrot, and celery. Cook until soft, about 8 minutes.', order: 0 },
      { text: 'Add garlic and red pepper flakes. Cook 1 minute.', order: 1 },
      { text: 'Add ground beef and brown well, about 8 minutes. Drain excess fat.', order: 2 },
      { text: 'Stir in tomato paste, brown sugar, and Worcestershire sauce. Cook 2 minutes.', order: 3 },
      { text: 'Add crushed tomatoes, beef broth, and oregano. Bring to a simmer.', order: 4 },
      { text: 'Reduce heat to low, cover, and simmer for 2-3 hours. The longer the better.', order: 5 },
      { text: 'Season with salt and pepper. The brown sugar balances the acidity perfectly.', order: 6 },
      { text: "Serve over rigatoni or pappardelle. This recipe has traveled through 5 kitchens — now it's yours.", order: 7 },
    ],
  },
];

async function seedBigshareLineage(): Promise<void> {
  console.log('Seeding Bigshare lineage tree (5 recipes, 5 lineage records)...\n');

  const db = getDb();

  // Phase 1: Create recipe documents
  console.log('--- Phase 1: Creating recipe documents ---\n');

  for (const node of LINEAGE_NODES) {
    const recipeRef = db.doc(`users/${node.ownerId}/recipes/${node.recipeId}`);

    const recipe: Record<string, any> = {
      title: node.title,
      description: node.description,
      category: 'Dinner',
      tags: ['Italian', 'Bolognese', 'Pasta', 'Comfort Food'],
      servings: node.servings,
      prepTime: node.prepTime,
      cookTime: node.cookTime,
      firebaseImageURL: BOLOGNESE_IMAGE,
      createdAt: toTimestamp(daysAgo(node.createdDaysAgo)),
      updatedAt: toTimestamp(daysAgo(Math.max(0, node.createdDaysAgo - 5))),
      modifiedAt: toTimestamp(daysAgo(Math.max(0, node.createdDaysAgo - 5))),
      source: 'shared',
      sourceType: 'family',
      visibility: 'public',
      isArchived: false,
      isDemoSeed: true,
      demoSeedLabel: 'bigshare-lineage',
    };

    await recipeRef.set(recipe, { merge: true });

    // Delete existing ingredients before re-seeding
    const existingIngredients = await db.collection(`users/${node.ownerId}/recipes/${node.recipeId}/ingredients`).get();
    for (const doc of existingIngredients.docs) {
      await doc.ref.delete();
    }

    // Seed ingredients
    const ingredientBatch = db.batch();
    for (const ing of node.ingredients) {
      const ingredientId = uuidv4();
      const ingredientRef = db.doc(`users/${node.ownerId}/recipes/${node.recipeId}/ingredients/${ingredientId}`);
      ingredientBatch.set(ingredientRef, {
        id: ingredientId,
        originalText: ing.text,
        name: ing.name,
        quantity: ing.amount,
        unit: ing.unit,
        order: ing.order,
        orderIndex: ing.order,
      });
    }
    await ingredientBatch.commit();

    // Delete existing instructions before re-seeding
    const existingInstructions = await db.collection(`users/${node.ownerId}/recipes/${node.recipeId}/instructions`).get();
    for (const doc of existingInstructions.docs) {
      await doc.ref.delete();
    }

    // Seed instructions
    const instructionBatch = db.batch();
    for (const inst of node.instructions) {
      const instructionId = uuidv4();
      const instructionRef = db.doc(`users/${node.ownerId}/recipes/${node.recipeId}/instructions/${instructionId}`);
      instructionBatch.set(instructionRef, {
        id: instructionId,
        text: inst.text,
        order: inst.order,
        orderIndex: inst.order,
      });
    }
    await instructionBatch.commit();

    console.log(`  Created recipe: "${node.title}" for ${node.ownerName} (${node.ownerId})`);
    console.log(`    Path: users/${node.ownerId}/recipes/${node.recipeId}`);
    console.log(`    Gen ${node.generation}, ${node.ingredients.length} ingredients, ${node.instructions.length} instructions\n`);
  }

  // Phase 2: Create lineage records
  console.log('--- Phase 2: Creating lineage records ---\n');

  for (const node of LINEAGE_NODES) {
    const lineageData: Record<string, any> = {
      id: node.recipeId,
      recipeId: node.recipeId,
      currentRecipeId: node.recipeId,
      ownerId: node.ownerId,
      ownerDisplayName: node.ownerName,
      generation: node.generation,
      rootRecipeId: ROOT_UUID,
      rootOwnerId: ROOT_OWNER,
      parentRecipeId: node.parentRecipeId,
      parentOwnerId: node.parentOwnerId,
      title: node.title,
      isHeirloom: true,
      hasLocalModifications: node.generation > 0,
      modifications: [],
      createdAt: toTimestamp(daysAgo(node.createdDaysAgo)),
      updatedAt: toTimestamp(daysAgo(Math.max(0, node.createdDaysAgo - 5))),
      lastModified: toTimestamp(daysAgo(Math.max(0, node.createdDaysAgo - 5))),
      isDemoSeed: true,
      demoSeedLabel: 'bigshare-lineage',
    };

    // Write to global lineages collection (for cross-user queries)
    // Use deterministic ID (recipeId) so re-runs are idempotent
    const globalLineageRef = db.collection('lineages').doc(`bigshare-lineage-${node.recipeId}`);
    await globalLineageRef.set(lineageData);

    // Write to user's lineages subcollection
    const userLineageRef = db.doc(`users/${node.ownerId}/lineages/${node.recipeId}`);
    await userLineageRef.set(lineageData);

    console.log(`  Created lineage: "${node.title}" (Gen ${node.generation})`);
    console.log(`    Global: ${globalLineageRef.path}`);
    console.log(`    User: ${userLineageRef.path}`);
    if (node.parentRecipeId) {
      console.log(`    Parent: ${node.parentRecipeId}`);
    }
    console.log('');
  }

  console.log('Done! Bigshare lineage tree seeded.');
  console.log(`\nTree structure:`);
  console.log(`  Gen 0: Grandmazing     - "Grandma's Sunday Bolognese"  (ROOT)`);
  console.log(`  Gen 1: Maria Santos    - "Bolognese con Sofrito"       (from ROOT)`);
  console.log(`  Gen 1: Phillip Fry     - "Quick Weeknight Bolognese"   (from ROOT)`);
  console.log(`  Gen 2: Marcus Johnson  - "Smoky Grilled Bolognese"     (from Maria)`);
  console.log(`  Gen 2: Big Share       - "The Traveling Bolognese"     (from Phillip)`);
  console.log(`\nAll nodes share rootRecipeId: ${ROOT_UUID}`);
}

async function cleanupBigshareLineage(): Promise<void> {
  console.log('Cleaning up Bigshare lineage data...\n');

  const db = getDb();

  // Delete recipes
  for (const node of LINEAGE_NODES) {
    // Delete ingredients subcollection
    const ingredients = await db.collection(`users/${node.ownerId}/recipes/${node.recipeId}/ingredients`).get();
    for (const doc of ingredients.docs) {
      await doc.ref.delete();
    }

    // Delete instructions subcollection
    const instructions = await db.collection(`users/${node.ownerId}/recipes/${node.recipeId}/instructions`).get();
    for (const doc of instructions.docs) {
      await doc.ref.delete();
    }

    // Delete recipe document
    await db.doc(`users/${node.ownerId}/recipes/${node.recipeId}`).delete();

    // Delete user lineage record
    await db.doc(`users/${node.ownerId}/lineages/${node.recipeId}`).delete();

    console.log(`  Deleted: ${node.title} (${node.ownerId})`);
  }

  // Delete global lineage records for this tree
  const globalLineages = await db.collection('lineages')
    .where('rootRecipeId', '==', ROOT_UUID)
    .get();

  for (const doc of globalLineages.docs) {
    await doc.ref.delete();
    console.log(`  Deleted global lineage: ${doc.id}`);
  }

  console.log('\nDone! Bigshare lineage data cleaned up.');
}

async function main() {
  console.log('Initializing Firebase...');
  initializeFirebase();

  const command = process.argv[2];

  if (command === 'cleanup') {
    await cleanupBigshareLineage();
  } else {
    await seedBigshareLineage();
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
