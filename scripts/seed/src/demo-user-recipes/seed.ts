/**
 * Demo User Recipe Seeding
 *
 * Creates recipes for demo users that are referenced in welcome shares.
 * These recipes must exist for share acceptance to work.
 */

import { initializeFirebase, getDb, toTimestamp, daysAgo } from '../utils/firebase';
import { v4 as uuidv4 } from 'uuid';

// Demo user recipe data
// IMPORTANT: recipeIds must match the UUIDs in seed_data.ts DEMO_USER_WELCOME_RECIPES
// These UUIDs are referenced in the share documents
const DEMO_USER_RECIPES = {
  demo_phillipfry: {
    recipeId: '7ee0a981-0dd2-4105-aa26-ab941c23d688', // Must match seed_data.ts UUID
    title: 'Creamy One-Pot Pasta',
    description: 'My go-to weeknight dinner. Everything cooks in one pot - pasta, sauce, and all. Super easy cleanup and it\'s ready in 25 minutes.',
    category: 'Dinner',
    tags: ['Pasta', 'Quick', 'One-Pot', 'Weeknight'],
    servings: '4 servings',
    prepTime: '5',
    cookTime: '20',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_phillipfry_one_pot_pasta-image.webp',
    ingredients: [
      { text: '12 oz penne pasta', name: 'penne pasta', amount: 12, unit: 'oz', order: 0 },
      { text: '2 cups chicken broth', name: 'chicken broth', amount: 2, unit: 'cups', order: 1 },
      { text: '1 cup heavy cream', name: 'heavy cream', amount: 1, unit: 'cup', order: 2 },
      { text: '2 cups fresh spinach', name: 'fresh spinach', amount: 2, unit: 'cups', order: 3 },
      { text: '1/2 cup sun-dried tomatoes', name: 'sun-dried tomatoes', amount: 0.5, unit: 'cup', order: 4 },
      { text: '3 cloves garlic, minced', name: 'garlic, minced', amount: 3, unit: 'cloves', order: 5 },
      { text: '1/2 cup parmesan cheese', name: 'parmesan cheese', amount: 0.5, unit: 'cup', order: 6 },
      { text: 'Salt and pepper to taste', name: 'salt and pepper', amount: null, unit: '', order: 7 },
    ],
    instructions: [
      { text: 'In a large pot, combine pasta, broth, cream, and garlic. Bring to a boil.', order: 0 },
      { text: 'Reduce heat to medium and simmer, stirring occasionally, for 15-18 minutes until pasta is tender.', order: 1 },
      { text: 'Stir in sun-dried tomatoes and spinach. Cook until spinach wilts.', order: 2 },
      { text: 'Remove from heat, stir in parmesan. Season with salt and pepper.', order: 3 },
      { text: 'Serve immediately with extra parmesan on top.', order: 4 },
    ],
  },
  demo_grillmaster: {
    recipeId: '1de8ec4c-7629-466d-b39b-87d97b48ec9f', // Must match seed_data.ts UUID
    title: 'Ultimate Smash Burgers',
    description: 'The secret is smashing the patties thin on a screaming hot griddle. Those crispy edges are everything. Trust me on this one.',
    category: 'Dinner',
    tags: ['Burgers', 'Grilling', 'Quick', 'American'],
    servings: '4 burgers',
    prepTime: '10',
    cookTime: '8',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grillmaster_smash_burgers-image.webp',
    ingredients: [
      { text: '1 lb ground beef (80/20)', name: 'ground beef', amount: 1, unit: 'lb', order: 0 },
      { text: '4 brioche buns', name: 'brioche buns', amount: 4, unit: '', order: 1 },
      { text: '8 slices American cheese', name: 'American cheese', amount: 8, unit: 'slices', order: 2 },
      { text: '1 white onion, thinly sliced', name: 'white onion', amount: 1, unit: '', order: 3 },
      { text: 'Pickles', name: 'pickles', amount: null, unit: '', order: 4 },
      { text: 'Special sauce (mayo, ketchup, relish)', name: 'special sauce', amount: null, unit: '', order: 5 },
      { text: 'Salt and pepper', name: 'salt and pepper', amount: null, unit: '', order: 6 },
    ],
    instructions: [
      { text: 'Divide beef into 8 equal balls (2 oz each). Keep loosely packed.', order: 0 },
      { text: 'Heat a cast iron griddle or pan over high heat until smoking.', order: 1 },
      { text: 'Place ball on griddle, immediately smash flat with spatula. Season with salt and pepper.', order: 2 },
      { text: 'Cook 2 minutes until edges are crispy and brown. Flip, add cheese.', order: 3 },
      { text: 'Cook 1 more minute. Stack two patties per bun.', order: 4 },
      { text: 'Add sauce, onions, and pickles. Serve immediately.', order: 5 },
    ],
  },
  demo_grandmazing: {
    recipeId: '5e13b837-1a80-4d22-af8a-c474a6ea5c35', // Must match seed_data.ts UUID
    title: 'Brown Butter Chocolate Chip Cookies',
    description: 'The brown butter is my secret - it adds this nutty, caramel flavor that makes everyone ask for the recipe. Been making these for 40 years.',
    category: 'Dessert',
    tags: ['Cookies', 'Baking', 'Chocolate', 'Classic'],
    servings: '24 cookies',
    prepTime: '20',
    cookTime: '12',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing_chocolate_chip_cookies-image.webp',
    ingredients: [
      { text: '1 cup butter', name: 'butter', amount: 1, unit: 'cup', order: 0 },
      { text: '2 1/4 cups all-purpose flour', name: 'all-purpose flour', amount: 2.25, unit: 'cups', order: 1 },
      { text: '1 cup brown sugar', name: 'brown sugar', amount: 1, unit: 'cup', order: 2 },
      { text: '1/2 cup white sugar', name: 'white sugar', amount: 0.5, unit: 'cup', order: 3 },
      { text: '2 eggs', name: 'eggs', amount: 2, unit: '', order: 4 },
      { text: '1 tsp vanilla extract', name: 'vanilla extract', amount: 1, unit: 'tsp', order: 5 },
      { text: '1 tsp baking soda', name: 'baking soda', amount: 1, unit: 'tsp', order: 6 },
      { text: '1/2 tsp salt', name: 'salt', amount: 0.5, unit: 'tsp', order: 7 },
      { text: '2 cups chocolate chips', name: 'chocolate chips', amount: 2, unit: 'cups', order: 8 },
    ],
    instructions: [
      { text: 'Brown the butter in a saucepan over medium heat until nutty and golden. Cool slightly.', order: 0 },
      { text: 'Whisk together flour, baking soda, and salt.', order: 1 },
      { text: 'Beat brown butter with sugars until fluffy. Add eggs and vanilla.', order: 2 },
      { text: 'Gradually mix in flour mixture. Fold in chocolate chips.', order: 3 },
      { text: 'Chill dough 30 minutes (or overnight for best flavor).', order: 4 },
      { text: 'Bake at 375°F for 10-12 minutes until edges are golden but centers look soft.', order: 5 },
      { text: 'Cool on pan 5 minutes before transferring.', order: 6 },
    ],
  },
  demo_chef_maria: {
    recipeId: '5d5a16d4-4fc2-483b-9737-7d0451f3c236', // Must match seed_data.ts UUID
    title: 'Camarones al Ajillo (Garlic Shrimp)',
    description: 'This is how my abuela made it in Havana. The secret is letting the garlic infuse the oil slowly, then cooking the shrimp fast over high heat.',
    category: 'Dinner',
    tags: ['Shrimp', 'Latin', 'Quick', 'Seafood'],
    servings: '4 servings',
    prepTime: '10',
    cookTime: '10',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_chef_maria_garlic_shrimp-image.webp',
    ingredients: [
      { text: '1.5 lbs large shrimp, peeled', name: 'large shrimp', amount: 1.5, unit: 'lbs', order: 0 },
      { text: '10 cloves garlic, thinly sliced', name: 'garlic', amount: 10, unit: 'cloves', order: 1 },
      { text: '1/2 cup olive oil', name: 'olive oil', amount: 0.5, unit: 'cup', order: 2 },
      { text: '1 dried guajillo chile', name: 'guajillo chile', amount: 1, unit: '', order: 3 },
      { text: '1/4 cup dry sherry', name: 'dry sherry', amount: 0.25, unit: 'cup', order: 4 },
      { text: '2 tbsp fresh parsley', name: 'fresh parsley', amount: 2, unit: 'tbsp', order: 5 },
      { text: 'Crusty bread for serving', name: 'crusty bread', amount: null, unit: '', order: 6 },
    ],
    instructions: [
      { text: 'Heat oil in a large skillet over medium-low. Add garlic and chile, cook slowly until garlic is golden (5 min).', order: 0 },
      { text: 'Remove chile. Increase heat to high.', order: 1 },
      { text: 'Add shrimp in single layer. Cook 1 minute per side until pink.', order: 2 },
      { text: 'Add sherry, cook 30 seconds to reduce slightly.', order: 3 },
      { text: 'Remove from heat, sprinkle with parsley. Serve with crusty bread to soak up the oil.', order: 4 },
    ],
  },
  demo_fitfoodie: {
    recipeId: 'f3890dc5-f51a-455a-8bf2-eb4bb089c5a9', // Must match seed_data.ts UUID
    title: 'Ultimate Protein Power Bowl',
    description: '45g of protein and it actually tastes amazing. This is my post-workout go-to. The tahini dressing makes it.',
    category: 'Lunch',
    tags: ['Healthy', 'High-Protein', 'Bowl', 'Meal-Prep'],
    servings: '2 bowls',
    prepTime: '15',
    cookTime: '20',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_fitfoodie_protein_bowl-image.webp',
    ingredients: [
      { text: '2 chicken breasts', name: 'chicken breasts', amount: 2, unit: '', order: 0 },
      { text: '1 can chickpeas, drained', name: 'chickpeas', amount: 1, unit: 'can', order: 1 },
      { text: '2 cups quinoa, cooked', name: 'quinoa', amount: 2, unit: 'cups', order: 2 },
      { text: '2 cups mixed greens', name: 'mixed greens', amount: 2, unit: 'cups', order: 3 },
      { text: '1 cucumber, diced', name: 'cucumber', amount: 1, unit: '', order: 4 },
      { text: '1/4 cup tahini', name: 'tahini', amount: 0.25, unit: 'cup', order: 5 },
      { text: '2 tbsp lemon juice', name: 'lemon juice', amount: 2, unit: 'tbsp', order: 6 },
      { text: '1 tbsp olive oil', name: 'olive oil', amount: 1, unit: 'tbsp', order: 7 },
    ],
    instructions: [
      { text: 'Season chicken with salt, pepper, and olive oil. Grill or bake at 400°F for 20 min.', order: 0 },
      { text: 'Roast chickpeas at 400°F for 15 min until crispy.', order: 1 },
      { text: 'Make dressing: whisk tahini, lemon juice, 2 tbsp water, salt.', order: 2 },
      { text: 'Slice chicken. Arrange bowls: quinoa, greens, chicken, chickpeas, cucumber.', order: 3 },
      { text: 'Drizzle with tahini dressing. Add hot sauce if desired.', order: 4 },
    ],
  },
  demo_bakingbelle: {
    recipeId: 'fceb840f-6acb-49f3-a7f0-e1da3de286ff', // Must match seed_data.ts UUID
    title: 'Molten Chocolate Lava Cakes',
    description: 'These look so fancy but they\'re actually super easy. The trick is not overbaking - you want that molten center!',
    category: 'Dessert',
    tags: ['Chocolate', 'Dessert', 'Elegant', 'Quick'],
    servings: '4 cakes',
    prepTime: '15',
    cookTime: '14',
    imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bakingbelle_chocolate_lava_cakes-image.webp',
    ingredients: [
      { text: '4 oz dark chocolate', name: 'dark chocolate', amount: 4, unit: 'oz', order: 0 },
      { text: '1/2 cup butter', name: 'butter', amount: 0.5, unit: 'cup', order: 1 },
      { text: '1 cup powdered sugar', name: 'powdered sugar', amount: 1, unit: 'cup', order: 2 },
      { text: '2 eggs', name: 'eggs', amount: 2, unit: '', order: 3 },
      { text: '2 egg yolks', name: 'egg yolks', amount: 2, unit: '', order: 4 },
      { text: '6 tbsp flour', name: 'flour', amount: 6, unit: 'tbsp', order: 5 },
      { text: 'Vanilla ice cream for serving', name: 'vanilla ice cream', amount: null, unit: '', order: 6 },
    ],
    instructions: [
      { text: 'Preheat oven to 425°F. Grease 4 ramekins with butter and dust with cocoa powder.', order: 0 },
      { text: 'Melt chocolate and butter together in microwave, stirring every 30 seconds.', order: 1 },
      { text: 'Stir in powdered sugar until smooth. Whisk in eggs and egg yolks.', order: 2 },
      { text: 'Fold in flour until just combined. Divide among ramekins.', order: 3 },
      { text: 'Bake 12-14 minutes until edges are firm but center jiggles slightly.', order: 4 },
      { text: 'Let cool 1 minute, then invert onto plates. Serve immediately with ice cream.', order: 5 },
    ],
  },
};

async function seedDemoUserRecipes(): Promise<void> {
  const db = getDb();
  const now = new Date();

  console.log('Seeding demo user recipes...');
  console.log('='.repeat(60));

  for (const [userId, recipeData] of Object.entries(DEMO_USER_RECIPES)) {
    // IMPORTANT: Use lowercase UUID for document ID to match app's firebaseString convention
    const recipeIdLower = recipeData.recipeId.toLowerCase();
    const recipeRef = db.doc(`users/${userId}/recipes/${recipeIdLower}`);

    // IMPORTANT: Store instructions as array on document (not subcollection)
    // The app expects instructions as data["instructions"] which is [String]
    const instructionStrings = recipeData.instructions.map(inst => inst.text);

    const recipe = {
      id: recipeData.recipeId,
      title: recipeData.title,
      description: recipeData.description,
      category: recipeData.category,
      tags: recipeData.tags,
      servings: recipeData.servings,
      prepTime: recipeData.prepTime,
      cookTime: recipeData.cookTime,
      firebaseImageURL: recipeData.imageURL,
      instructions: instructionStrings, // Store as array on document for diff view
      createdAt: toTimestamp(daysAgo(30)),
      updatedAt: toTimestamp(now),
      modifiedAt: toTimestamp(now),
      source: 'manual',
      sourceType: 'userEntered',
      visibility: 'public', // Demo recipes are public for sharing
      isArchived: false,
    };

    await recipeRef.set(recipe);

    // Delete existing ingredients before re-seeding (prevents duplicates)
    // Check both uppercase (old) and lowercase (new) paths
    const existingIngredientsOld = await db.collection(`users/${userId}/recipes/${recipeData.recipeId}/ingredients`).get();
    for (const doc of existingIngredientsOld.docs) {
      await doc.ref.delete();
    }
    const existingIngredients = await db.collection(`users/${userId}/recipes/${recipeIdLower}/ingredients`).get();
    for (const doc of existingIngredients.docs) {
      await doc.ref.delete();
    }

    // Seed ingredients as subcollection (using lowercase recipe ID)
    const ingredientBatch = db.batch();
    for (const ing of recipeData.ingredients) {
      const ingredientId = uuidv4().toLowerCase(); // Also lowercase ingredient IDs
      const ingredientRef = db.doc(`users/${userId}/recipes/${recipeIdLower}/ingredients/${ingredientId}`);
      ingredientBatch.set(ingredientRef, {
        id: ingredientId,
        originalText: ing.text,  // App expects 'originalText', not 'text'
        name: ing.name,
        quantity: ing.amount,    // App expects 'quantity', not 'amount'
        unit: ing.unit,
        order: ing.order,
        orderIndex: ing.order,
      });
    }
    await ingredientBatch.commit();

    // Delete existing instructions before re-seeding (prevents duplicates)
    const existingInstructionsOld = await db.collection(`users/${userId}/recipes/${recipeData.recipeId}/instructions`).get();
    for (const doc of existingInstructionsOld.docs) {
      await doc.ref.delete();
    }
    const existingInstructions = await db.collection(`users/${userId}/recipes/${recipeIdLower}/instructions`).get();
    for (const doc of existingInstructions.docs) {
      await doc.ref.delete();
    }

    // Seed instructions as subcollection (using lowercase recipe ID)
    const instructionBatch = db.batch();
    for (const inst of recipeData.instructions) {
      const instructionId = uuidv4().toLowerCase(); // Also lowercase instruction IDs
      const instructionRef = db.doc(`users/${userId}/recipes/${recipeIdLower}/instructions/${instructionId}`);
      instructionBatch.set(instructionRef, {
        id: instructionId,
        text: inst.text,
        order: inst.order,
        orderIndex: inst.order,
      });
    }
    await instructionBatch.commit();

    console.log(`  Created: ${recipeData.title} for ${userId}`);
  }

  console.log('\nDone! Demo user recipes seeded.');
}

async function main() {
  console.log('Initializing Firebase...');
  initializeFirebase();
  await seedDemoUserRecipes();
}

main().catch(console.error);
