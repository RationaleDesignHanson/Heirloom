/**
 * Seed Account Deletion Test Account
 *
 * Creates a test account for Apple reviewers to test the account deletion feature.
 * Same structure as demo (3 collections, 9 recipes) but different content.
 *
 * Email: deletetest@heirloomrecipebox.app
 * Password: HeirloomDemo2026!
 *
 * Run: npx ts-node src/seed-deletion-test-account.ts
 * Cleanup: npx ts-node src/seed-deletion-test-account.ts cleanup
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { v4 as uuidv4 } from 'uuid';

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

// Deletion test account credentials
const TEST_EMAIL = 'deletetest@heirloomrecipebox.app';
const TEST_PASSWORD = 'HeirloomDemo2026!';
const TEST_DISPLAY_NAME = 'Delete Test User';

// Generate UUIDs for recipes (consistent for relinking)
const RECIPE_IDS = {
  honeyGarlicSalmon: uuidv4(),
  shepherdsPie: uuidv4(),
  friedRice: uuidv4(),
  shrimpScampi: uuidv4(),
  caesarSalad: uuidv4(),
  frenchOnionSoup: uuidv4(),
  bananaBread: uuidv4(),
  blueberryMuffins: uuidv4(),
  cinnamonRolls: uuidv4(),
};

// Collection UUIDs
const COLLECTION_IDS = {
  quickEasy: uuidv4(),
  favorites: uuidv4(),
  bakedGoods: uuidv4(),
};

interface TestRecipe {
  id: string;
  title: string;
  sourceType: string;
  instructions: string[];
  servings: string;
  prepTime: string;
  cookTime: string;
  isFavorite: boolean;
  collectionId: string;
  firebaseImageURL?: string;
  ingredients: Array<{
    originalText: string;
    name: string;
    quantity: number | null;
    unit: string | null;
    orderIndex: number;
  }>;
}

// Test recipes - different from demo account
const TEST_RECIPES: TestRecipe[] = [
  {
    id: RECIPE_IDS.honeyGarlicSalmon,
    title: 'Honey Garlic Salmon',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&q=80',
    instructions: [
      'Pat salmon fillets dry and season with salt and pepper.',
      'Heat olive oil in a large oven-safe skillet over medium-high heat.',
      'Add salmon skin-side up and sear 3 minutes until golden.',
      'Flip salmon and transfer skillet to oven at 400°F for 5 minutes.',
      'Meanwhile, mix honey, soy sauce, garlic, and ginger.',
      'Remove salmon from oven and pour sauce over fillets.',
      'Return to stovetop and simmer 2 minutes, basting salmon.',
      'Garnish with sesame seeds and green onions. Serve immediately.',
    ],
    servings: '4',
    prepTime: '10 mins',
    cookTime: '15 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.quickEasy,
    ingredients: [
      { originalText: '4 salmon fillets (6 oz each)', name: 'salmon fillets', quantity: 4, unit: null, orderIndex: 0 },
      { originalText: '3 tablespoons honey', name: 'honey', quantity: 3, unit: 'tablespoon', orderIndex: 1 },
      { originalText: '2 tablespoons soy sauce', name: 'soy sauce', quantity: 2, unit: 'tablespoon', orderIndex: 2 },
      { originalText: '4 cloves garlic, minced', name: 'garlic', quantity: 4, unit: 'clove', orderIndex: 3 },
      { originalText: '1 teaspoon fresh ginger', name: 'fresh ginger', quantity: 1, unit: 'teaspoon', orderIndex: 4 },
      { originalText: '2 tablespoons olive oil', name: 'olive oil', quantity: 2, unit: 'tablespoon', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.shepherdsPie,
    title: "Classic Shepherd's Pie",
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800&q=80',
    instructions: [
      'Boil potatoes until tender, about 15-20 minutes. Drain and mash with butter and cream.',
      'Brown ground lamb in a large skillet over medium-high heat.',
      'Add onion, carrots, and celery. Cook 5 minutes until softened.',
      'Stir in tomato paste, beef broth, and Worcestershire sauce.',
      'Add frozen peas and simmer 10 minutes until thickened.',
      'Transfer meat mixture to a baking dish.',
      'Spread mashed potatoes evenly over the top.',
      'Bake at 400°F for 25 minutes until golden and bubbling.',
    ],
    servings: '6',
    prepTime: '25 mins',
    cookTime: '45 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.quickEasy,
    ingredients: [
      { originalText: '1.5 lbs ground lamb', name: 'ground lamb', quantity: 1.5, unit: 'lb', orderIndex: 0 },
      { originalText: '2 lbs russet potatoes, peeled', name: 'russet potatoes', quantity: 2, unit: 'lb', orderIndex: 1 },
      { originalText: '1 onion, diced', name: 'onion', quantity: 1, unit: null, orderIndex: 2 },
      { originalText: '2 carrots, diced', name: 'carrots', quantity: 2, unit: null, orderIndex: 3 },
      { originalText: '1 cup frozen peas', name: 'frozen peas', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '1 cup beef broth', name: 'beef broth', quantity: 1, unit: 'cup', orderIndex: 5 },
      { originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.friedRice,
    title: 'Easy Vegetable Fried Rice',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80',
    instructions: [
      'Use day-old cold rice for best results.',
      'Heat vegetable oil in a wok or large skillet over high heat.',
      'Scramble eggs and set aside.',
      'Add vegetables and stir-fry 3-4 minutes.',
      'Add cold rice, breaking up any clumps.',
      'Push rice to the side and add soy sauce to the pan.',
      'Toss everything together with scrambled eggs.',
      'Season with sesame oil and white pepper. Serve hot.',
    ],
    servings: '4',
    prepTime: '10 mins',
    cookTime: '10 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.favorites,
    ingredients: [
      { originalText: '4 cups cold cooked rice', name: 'cooked rice', quantity: 4, unit: 'cup', orderIndex: 0 },
      { originalText: '3 eggs, beaten', name: 'eggs', quantity: 3, unit: null, orderIndex: 1 },
      { originalText: '1 cup mixed vegetables', name: 'mixed vegetables', quantity: 1, unit: 'cup', orderIndex: 2 },
      { originalText: '3 tablespoons soy sauce', name: 'soy sauce', quantity: 3, unit: 'tablespoon', orderIndex: 3 },
      { originalText: '2 tablespoons vegetable oil', name: 'vegetable oil', quantity: 2, unit: 'tablespoon', orderIndex: 4 },
      { originalText: '1 teaspoon sesame oil', name: 'sesame oil', quantity: 1, unit: 'teaspoon', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.shrimpScampi,
    title: 'Garlic Shrimp Scampi',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&q=80',
    instructions: [
      'Cook linguine according to package directions. Reserve 1 cup pasta water.',
      'Pat shrimp dry and season with salt and pepper.',
      'Heat olive oil and butter in a large skillet over medium-high heat.',
      'Add shrimp and cook 2 minutes per side. Remove and set aside.',
      'Add garlic to the pan and sauté 30 seconds until fragrant.',
      'Add white wine and lemon juice. Simmer 2 minutes.',
      'Toss in cooked pasta and shrimp.',
      'Add pasta water as needed. Top with parsley and red pepper flakes.',
    ],
    servings: '4',
    prepTime: '15 mins',
    cookTime: '15 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.quickEasy,
    ingredients: [
      { originalText: '1 lb large shrimp, peeled', name: 'large shrimp', quantity: 1, unit: 'lb', orderIndex: 0 },
      { originalText: '12 oz linguine pasta', name: 'linguine pasta', quantity: 12, unit: 'oz', orderIndex: 1 },
      { originalText: '6 cloves garlic, minced', name: 'garlic', quantity: 6, unit: 'clove', orderIndex: 2 },
      { originalText: '1/2 cup white wine', name: 'white wine', quantity: 0.5, unit: 'cup', orderIndex: 3 },
      { originalText: '1/4 cup lemon juice', name: 'lemon juice', quantity: 0.25, unit: 'cup', orderIndex: 4 },
      { originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 5 },
      { originalText: '3 tablespoons olive oil', name: 'olive oil', quantity: 3, unit: 'tablespoon', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.caesarSalad,
    title: 'Classic Caesar Salad',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=800&q=80',
    instructions: [
      'Chop romaine lettuce into bite-sized pieces.',
      'For dressing: whisk together anchovy paste, garlic, lemon juice, and Dijon mustard.',
      'Slowly stream in olive oil while whisking to emulsify.',
      'Stir in grated parmesan and black pepper.',
      'Toss lettuce with dressing until evenly coated.',
      'Add croutons and more parmesan.',
      'Top with grilled chicken if desired.',
      'Serve immediately while croutons are crisp.',
    ],
    servings: '4',
    prepTime: '15 mins',
    cookTime: '0 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.favorites,
    ingredients: [
      { originalText: '2 heads romaine lettuce', name: 'romaine lettuce', quantity: 2, unit: 'head', orderIndex: 0 },
      { originalText: '1/2 cup olive oil', name: 'olive oil', quantity: 0.5, unit: 'cup', orderIndex: 1 },
      { originalText: '2 cloves garlic, minced', name: 'garlic', quantity: 2, unit: 'clove', orderIndex: 2 },
      { originalText: '2 tablespoons lemon juice', name: 'lemon juice', quantity: 2, unit: 'tablespoon', orderIndex: 3 },
      { originalText: '1 teaspoon anchovy paste', name: 'anchovy paste', quantity: 1, unit: 'teaspoon', orderIndex: 4 },
      { originalText: '1/2 cup parmesan cheese', name: 'parmesan cheese', quantity: 0.5, unit: 'cup', orderIndex: 5 },
      { originalText: '1 cup croutons', name: 'croutons', quantity: 1, unit: 'cup', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.frenchOnionSoup,
    title: 'French Onion Soup',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=800&q=80',
    instructions: [
      'Slice onions into thin half-moons.',
      'Melt butter in a large pot over medium heat.',
      'Add onions and cook 45 minutes, stirring occasionally, until deeply caramelized.',
      'Add thyme, bay leaf, and a pinch of sugar to help caramelization.',
      'Deglaze with white wine, scraping up brown bits.',
      'Add beef broth and simmer 20 minutes.',
      'Ladle soup into oven-safe bowls. Top with baguette slices and gruyere.',
      'Broil until cheese is bubbly and golden.',
    ],
    servings: '4',
    prepTime: '15 mins',
    cookTime: '75 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.quickEasy,
    ingredients: [
      { originalText: '4 large yellow onions', name: 'yellow onions', quantity: 4, unit: null, orderIndex: 0 },
      { originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 1 },
      { originalText: '4 cups beef broth', name: 'beef broth', quantity: 4, unit: 'cup', orderIndex: 2 },
      { originalText: '1/2 cup white wine', name: 'white wine', quantity: 0.5, unit: 'cup', orderIndex: 3 },
      { originalText: '1 baguette, sliced', name: 'baguette', quantity: 1, unit: null, orderIndex: 4 },
      { originalText: '2 cups gruyere cheese, shredded', name: 'gruyere cheese', quantity: 2, unit: 'cup', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.bananaBread,
    title: 'Classic Banana Bread',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1605286978633-2dec93ff88a2?w=800&q=80',
    instructions: [
      'Preheat oven to 350°F. Grease a 9x5 loaf pan.',
      'Mash ripe bananas in a large bowl until smooth.',
      'Stir in melted butter, sugar, egg, and vanilla.',
      'Mix in baking soda and salt.',
      'Gently fold in flour until just combined.',
      'Add walnuts if using.',
      'Pour batter into prepared pan.',
      'Bake 55-60 minutes until a toothpick comes out clean.',
      'Cool in pan 10 minutes before removing.',
    ],
    servings: '10',
    prepTime: '15 mins',
    cookTime: '60 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.bakedGoods,
    ingredients: [
      { originalText: '3 ripe bananas', name: 'bananas', quantity: 3, unit: null, orderIndex: 0 },
      { originalText: '1/3 cup melted butter', name: 'melted butter', quantity: 0.33, unit: 'cup', orderIndex: 1 },
      { originalText: '3/4 cup sugar', name: 'sugar', quantity: 0.75, unit: 'cup', orderIndex: 2 },
      { originalText: '1 egg, beaten', name: 'egg', quantity: 1, unit: null, orderIndex: 3 },
      { originalText: '1 teaspoon vanilla extract', name: 'vanilla extract', quantity: 1, unit: 'teaspoon', orderIndex: 4 },
      { originalText: '1 teaspoon baking soda', name: 'baking soda', quantity: 1, unit: 'teaspoon', orderIndex: 5 },
      { originalText: '1.5 cups all-purpose flour', name: 'all-purpose flour', quantity: 1.5, unit: 'cup', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.blueberryMuffins,
    title: 'Homemade Blueberry Muffins',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1558303095-a3c36dc50878?w=800&q=80',
    instructions: [
      'Preheat oven to 375°F. Line muffin tin with paper liners.',
      'Whisk together flour, sugar, baking powder, and salt.',
      'In another bowl, mix melted butter, milk, eggs, and vanilla.',
      'Pour wet ingredients into dry and stir until just combined.',
      'Gently fold in blueberries.',
      'Divide batter among muffin cups.',
      'Sprinkle tops with coarse sugar if desired.',
      'Bake 20-25 minutes until golden and a toothpick comes out clean.',
    ],
    servings: '12',
    prepTime: '15 mins',
    cookTime: '25 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.bakedGoods,
    ingredients: [
      { originalText: '2 cups all-purpose flour', name: 'all-purpose flour', quantity: 2, unit: 'cup', orderIndex: 0 },
      { originalText: '3/4 cup sugar', name: 'sugar', quantity: 0.75, unit: 'cup', orderIndex: 1 },
      { originalText: '2.5 teaspoons baking powder', name: 'baking powder', quantity: 2.5, unit: 'teaspoon', orderIndex: 2 },
      { originalText: '1/3 cup vegetable oil', name: 'vegetable oil', quantity: 0.33, unit: 'cup', orderIndex: 3 },
      { originalText: '1 cup milk', name: 'milk', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '1 egg', name: 'egg', quantity: 1, unit: null, orderIndex: 5 },
      { originalText: '1.5 cups fresh blueberries', name: 'blueberries', quantity: 1.5, unit: 'cup', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.cinnamonRolls,
    title: 'Homemade Cinnamon Rolls',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1509365465985-25d11c17e812?w=800&q=80',
    instructions: [
      'Warm milk to 110°F. Add yeast and 1 tablespoon sugar. Let sit 5 minutes.',
      'Mix in remaining sugar, butter, eggs, and salt. Add flour gradually.',
      'Knead dough 5 minutes until smooth. Let rise 1 hour.',
      'Roll dough into a 16x12 rectangle.',
      'Spread softened butter over dough. Sprinkle with cinnamon-sugar mixture.',
      'Roll up tightly from the long side. Cut into 12 pieces.',
      'Place in greased 9x13 pan. Let rise 30 minutes.',
      'Bake at 350°F for 25 minutes.',
      'Drizzle with cream cheese frosting while warm.',
    ],
    servings: '12',
    prepTime: '30 mins',
    cookTime: '25 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.bakedGoods,
    ingredients: [
      { originalText: '1 cup warm milk', name: 'warm milk', quantity: 1, unit: 'cup', orderIndex: 0 },
      { originalText: '2.25 teaspoons active dry yeast', name: 'active dry yeast', quantity: 2.25, unit: 'teaspoon', orderIndex: 1 },
      { originalText: '1/2 cup sugar', name: 'sugar', quantity: 0.5, unit: 'cup', orderIndex: 2 },
      { originalText: '1/3 cup butter, softened', name: 'butter', quantity: 0.33, unit: 'cup', orderIndex: 3 },
      { originalText: '4 cups all-purpose flour', name: 'all-purpose flour', quantity: 4, unit: 'cup', orderIndex: 4 },
      { originalText: '2 tablespoons cinnamon', name: 'cinnamon', quantity: 2, unit: 'tablespoon', orderIndex: 5 },
      { originalText: '1 cup brown sugar', name: 'brown sugar', quantity: 1, unit: 'cup', orderIndex: 6 },
      { originalText: '4 oz cream cheese', name: 'cream cheese', quantity: 4, unit: 'oz', orderIndex: 7 },
    ],
  },
];

// Collection definitions - different from demo (except Favorites)
const COLLECTIONS = [
  {
    id: COLLECTION_IDS.quickEasy,
    name: 'Quick & Easy',
    icon: 'bolt',
    color: '#FF9500',
    isSystemCollection: false,
  },
  {
    id: COLLECTION_IDS.favorites,
    name: 'Favorites',
    icon: 'heart.fill',
    color: '#E05A3A',
    isSystemCollection: true,
  },
  {
    id: COLLECTION_IDS.bakedGoods,
    name: 'Baked Goods',
    icon: 'flame',
    color: '#8B4513',
    isSystemCollection: false,
  },
];

/**
 * Create the test user in Firebase Auth
 */
async function createTestUser(): Promise<string> {
  console.log('Creating test user in Firebase Auth...');

  try {
    const existingUser = await auth.getUserByEmail(TEST_EMAIL).catch(() => null);

    if (existingUser) {
      console.log(`  User already exists: ${existingUser.uid}`);
      return existingUser.uid;
    }

    const user = await auth.createUser({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      displayName: TEST_DISPLAY_NAME,
      emailVerified: true,
    });

    console.log(`  Created user: ${user.uid}`);
    return user.uid;
  } catch (error) {
    console.error('  Failed to create user:', error);
    throw error;
  }
}

/**
 * Create user profile
 */
async function createUserProfile(userId: string): Promise<void> {
  console.log('Creating user profile...');

  await db.collection('users').doc(userId).collection('profile').doc('data').set({
    displayName: TEST_DISPLAY_NAME,
    email: TEST_EMAIL,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('  Profile created');
}

/**
 * Set expired subscription for App Store Review
 * Apple needs to see the paywall, so test account has expired subscription
 */
async function setExpiredSubscription(userId: string): Promise<void> {
  console.log('Setting expired subscription for App Store Review...');

  await db.collection('users').doc(userId).collection('subscription').doc('status').set({
    isActive: false,  // Expired for App Store Review
    productId: 'com.rationaledesign.heirloom.premium.annual.v2',
    planType: 'annual',
    expiresAt: admin.firestore.Timestamp.fromDate(new Date('2024-01-01')),  // Past date = expired
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'deletion_test_seed',
  }, { merge: true });

  console.log('  Expired subscription set (for App Store Review paywall testing)');
}

/**
 * Create collections
 */
async function createCollections(userId: string): Promise<void> {
  console.log('Creating collections...');

  for (const collection of COLLECTIONS) {
    // Get recipe IDs for this collection
    const recipeIds = TEST_RECIPES
      .filter(r => r.collectionId === collection.id)
      .map(r => r.id);

    await db.collection('users').doc(userId).collection('collections').doc(collection.id).set({
      id: collection.id,
      name: collection.name,
      icon: collection.icon,
      color: collection.color,
      isSystemCollection: collection.isSystemCollection,
      isAllRecipes: false,
      isDemoSeed: false,
      recipeIds: recipeIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      modifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`  ${collection.name} (${recipeIds.length} recipes)`);
  }
}

/**
 * Create recipes with correct Firestore format
 */
async function createRecipes(userId: string): Promise<void> {
  console.log('Creating recipes...');

  const now = new Date();

  for (const recipe of TEST_RECIPES) {
    // Create main recipe document
    const recipeRef = db.collection('users').doc(userId).collection('recipes').doc(recipe.id);

    await recipeRef.set({
      id: recipe.id,
      title: recipe.title,
      sourceType: recipe.sourceType,
      instructions: recipe.instructions,
      servings: recipe.servings,
      prepTime: recipe.prepTime,
      cookTime: recipe.cookTime,
      isFavorite: recipe.isFavorite,
      firebaseImageURL: recipe.firebaseImageURL || null,
      timesCooked: 0,
      generationCount: 0,
      collectionIds: [recipe.collectionId],
      createdAt: admin.firestore.Timestamp.fromDate(now),
      modifiedAt: admin.firestore.Timestamp.fromDate(now),
      lastSyncedAt: admin.firestore.Timestamp.fromDate(now),
    });

    // Create ingredients subcollection
    for (const ingredient of recipe.ingredients) {
      const ingredientId = uuidv4();
      await recipeRef.collection('ingredients').doc(ingredientId).set({
        id: ingredientId,
        originalText: ingredient.originalText,
        name: ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        orderIndex: ingredient.orderIndex,
        isChecked: false,
      });
    }

    console.log(`  ${recipe.title} (${recipe.ingredients.length} ingredients)`);
  }

  console.log(`\n  Created ${TEST_RECIPES.length} recipes`);
}

/**
 * Main seed function
 */
async function seedDeletionTestAccount(): Promise<void> {
  console.log('===============================================================');
  console.log('  Seeding Account Deletion Test Account');
  console.log('===============================================================');
  console.log(`  Email: ${TEST_EMAIL}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log('===============================================================\n');

  const userId = await createTestUser();
  await createUserProfile(userId);
  await setExpiredSubscription(userId);
  await createCollections(userId);
  await createRecipes(userId);

  console.log('\n===============================================================');
  console.log('  Deletion test account ready!');
  console.log('===============================================================');
  console.log(`  Email: ${TEST_EMAIL}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log(`  User ID: ${userId}`);
  console.log(`  Collections: ${COLLECTIONS.length}`);
  console.log(`  Recipes: ${TEST_RECIPES.length}`);
  console.log('');
  console.log('  Apple reviewers can use this account to test account deletion.');
  console.log('  After deletion, the account will need to be re-seeded.');
  console.log('===============================================================\n');
}

/**
 * Cleanup function
 */
async function cleanupDeletionTestAccount(): Promise<void> {
  console.log('Cleaning up deletion test account...\n');

  try {
    const user = await auth.getUserByEmail(TEST_EMAIL).catch(() => null);

    if (!user) {
      console.log('  Test user not found. Nothing to clean up.');
      return;
    }

    const userId = user.uid;
    console.log(`  Found user: ${userId}`);

    // Delete recipes (including subcollections)
    const recipesSnapshot = await db.collection('users').doc(userId).collection('recipes').get();
    for (const doc of recipesSnapshot.docs) {
      // Delete ingredients subcollection
      const ingredientsSnapshot = await doc.ref.collection('ingredients').get();
      for (const ingredientDoc of ingredientsSnapshot.docs) {
        await ingredientDoc.ref.delete();
      }
      await doc.ref.delete();
    }
    console.log(`  Deleted ${recipesSnapshot.size} recipes`);

    // Delete collections
    const collectionsSnapshot = await db.collection('users').doc(userId).collection('collections').get();
    for (const doc of collectionsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${collectionsSnapshot.size} collections`);

    // Delete subscription
    await db.collection('users').doc(userId).collection('subscription').doc('status').delete();
    console.log('  Deleted subscription');

    // Delete profile
    await db.collection('users').doc(userId).collection('profile').doc('data').delete();
    console.log('  Deleted profile');

    // Delete Firebase Auth user
    await auth.deleteUser(userId);
    console.log('  Deleted Firebase Auth user');

    console.log('\n Deletion test account cleaned up successfully');
  } catch (error) {
    console.error('Error during cleanup:', error);
    throw error;
  }
}

// CLI handling
if (require.main === module) {
  const command = process.argv[2];

  if (command === 'cleanup') {
    cleanupDeletionTestAccount()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  } else {
    seedDeletionTestAccount()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  }
}

export { seedDeletionTestAccount, cleanupDeletionTestAccount };
