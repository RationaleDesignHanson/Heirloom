/**
 * Seed App Store Review Demo Account (v2)
 *
 * Creates the demo account for Apple's review team with CORRECT Firestore structure
 * that matches what the app expects via FirebaseRecordConverter.
 *
 * Email: demo@heirloomrecipebox.app
 * Password: HeirloomDemo2026!
 *
 * Run: npx ts-node src/seed-appstore-demo.ts
 * Cleanup: npx ts-node src/seed-appstore-demo.ts cleanup
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

// Demo account credentials
const DEMO_EMAIL = 'demo@heirloomrecipebox.app';
const DEMO_PASSWORD = 'HeirloomDemo2026!';
const DEMO_DISPLAY_NAME = 'Demo User';

// Generate UUIDs for recipes (consistent for relinking)
const RECIPE_IDS = {
  lemonChicken: uuidv4(),
  pastaPrimavera: uuidv4(),
  tacos: uuidv4(),
  stirFry: uuidv4(),
  grilledCheese: uuidv4(),
  tomatoSoup: uuidv4(),
  chocolateCake: uuidv4(),
  applePie: uuidv4(),
  cheesecake: uuidv4(),
};

// Collection UUIDs
const COLLECTION_IDS = {
  weeknight: uuidv4(),
  favorites: uuidv4(),
  desserts: uuidv4(),
};

interface DemoRecipe {
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

// Demo recipes with correct format
const DEMO_RECIPES: DemoRecipe[] = [
  {
    id: RECIPE_IDS.lemonChicken,
    title: 'Lemon Garlic Chicken',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800&q=80',
    instructions: [
      'Season chicken breasts with salt and pepper on both sides.',
      'Heat olive oil in a large skillet over medium-high heat.',
      'Add chicken and cook 6-7 minutes per side until golden and cooked through.',
      'Remove chicken and set aside.',
      'Add garlic and sauté for 30 seconds until fragrant.',
      'Add lemon juice, zest, and chicken broth. Bring to a simmer.',
      'Stir in butter until melted and sauce is slightly thickened.',
      'Return chicken to the pan and spoon sauce over it.',
      'Garnish with fresh parsley and serve immediately.',
    ],
    servings: '4',
    prepTime: '10 mins',
    cookTime: '20 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.weeknight,
    ingredients: [
      { originalText: '4 boneless chicken breasts', name: 'chicken breasts', quantity: 4, unit: null, orderIndex: 0 },
      { originalText: '3 tablespoons olive oil', name: 'olive oil', quantity: 3, unit: 'tablespoon', orderIndex: 1 },
      { originalText: '4 cloves garlic, minced', name: 'garlic', quantity: 4, unit: 'clove', orderIndex: 2 },
      { originalText: '1/4 cup fresh lemon juice', name: 'lemon juice', quantity: 0.25, unit: 'cup', orderIndex: 3 },
      { originalText: '1 teaspoon lemon zest', name: 'lemon zest', quantity: 1, unit: 'teaspoon', orderIndex: 4 },
      { originalText: '1/2 cup chicken broth', name: 'chicken broth', quantity: 0.5, unit: 'cup', orderIndex: 5 },
      { originalText: '2 tablespoons butter', name: 'butter', quantity: 2, unit: 'tablespoon', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.pastaPrimavera,
    title: 'Pasta Primavera',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800&q=80',
    instructions: [
      'Cook pasta according to package directions. Reserve 1 cup pasta water.',
      'Heat olive oil in a large skillet over medium heat.',
      'Add broccoli and bell pepper, sauté 5 minutes until crisp-tender.',
      'Add squash and garlic, cook another 3 minutes.',
      'Add cherry tomatoes and cook 2 minutes more.',
      'Toss drained pasta with vegetables.',
      'Add pasta water as needed for sauce.',
      'Stir in parmesan cheese and season with salt and pepper.',
      'Top with fresh basil and serve.',
    ],
    servings: '6',
    prepTime: '15 mins',
    cookTime: '20 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.weeknight,
    ingredients: [
      { originalText: '1 lb penne pasta', name: 'penne pasta', quantity: 1, unit: 'lb', orderIndex: 0 },
      { originalText: '2 cups broccoli florets', name: 'broccoli florets', quantity: 2, unit: 'cup', orderIndex: 1 },
      { originalText: '1 red bell pepper, sliced', name: 'red bell pepper', quantity: 1, unit: null, orderIndex: 2 },
      { originalText: '1 yellow squash, sliced', name: 'yellow squash', quantity: 1, unit: null, orderIndex: 3 },
      { originalText: '1 cup cherry tomatoes', name: 'cherry tomatoes', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '4 cloves garlic, minced', name: 'garlic', quantity: 4, unit: 'clove', orderIndex: 5 },
      { originalText: '1/4 cup olive oil', name: 'olive oil', quantity: 0.25, unit: 'cup', orderIndex: 6 },
      { originalText: '1/2 cup parmesan cheese', name: 'parmesan cheese', quantity: 0.5, unit: 'cup', orderIndex: 7 },
    ],
  },
  {
    id: RECIPE_IDS.tacos,
    title: 'Easy Ground Beef Tacos',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800&q=80',
    instructions: [
      'Brown ground beef in a skillet over medium-high heat.',
      'Drain excess fat from the pan.',
      'Add taco seasoning and 1/4 cup water.',
      'Simmer 5 minutes until sauce thickens.',
      'Warm taco shells according to package directions.',
      'Fill each shell with seasoned beef.',
      'Top with lettuce, tomatoes, cheese, sour cream, and salsa.',
      'Garnish with fresh cilantro and serve.',
    ],
    servings: '4',
    prepTime: '10 mins',
    cookTime: '15 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.favorites,
    ingredients: [
      { originalText: '1 lb ground beef', name: 'ground beef', quantity: 1, unit: 'lb', orderIndex: 0 },
      { originalText: '1 packet taco seasoning', name: 'taco seasoning', quantity: 1, unit: 'packet', orderIndex: 1 },
      { originalText: '8 taco shells', name: 'taco shells', quantity: 8, unit: null, orderIndex: 2 },
      { originalText: '1 cup shredded lettuce', name: 'shredded lettuce', quantity: 1, unit: 'cup', orderIndex: 3 },
      { originalText: '1 cup diced tomatoes', name: 'diced tomatoes', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '1 cup shredded cheddar cheese', name: 'cheddar cheese', quantity: 1, unit: 'cup', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.stirFry,
    title: 'Chicken Stir Fry',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80',
    instructions: [
      'Heat vegetable oil in a wok over high heat.',
      'Add chicken and stir-fry 4-5 minutes until cooked through.',
      'Remove chicken and set aside.',
      'Add more oil if needed, then add vegetables.',
      'Stir-fry 3-4 minutes until crisp-tender.',
      'Add garlic and ginger, cook 30 seconds until fragrant.',
      'Return chicken to the wok.',
      'Add soy sauce and sesame oil, toss everything together.',
      'Serve immediately over steamed rice.',
    ],
    servings: '4',
    prepTime: '15 mins',
    cookTime: '10 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.weeknight,
    ingredients: [
      { originalText: '1 lb chicken breast, sliced thin', name: 'chicken breast', quantity: 1, unit: 'lb', orderIndex: 0 },
      { originalText: '2 cups mixed vegetables', name: 'mixed vegetables', quantity: 2, unit: 'cup', orderIndex: 1 },
      { originalText: '3 tablespoons soy sauce', name: 'soy sauce', quantity: 3, unit: 'tablespoon', orderIndex: 2 },
      { originalText: '1 tablespoon sesame oil', name: 'sesame oil', quantity: 1, unit: 'tablespoon', orderIndex: 3 },
      { originalText: '2 cloves garlic, minced', name: 'garlic', quantity: 2, unit: 'clove', orderIndex: 4 },
      { originalText: '1 tablespoon fresh ginger', name: 'fresh ginger', quantity: 1, unit: 'tablespoon', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.grilledCheese,
    title: 'Perfect Grilled Cheese',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=800&q=80',
    instructions: [
      'Butter one side of each bread slice.',
      'Place one slice butter-side down in a cold skillet.',
      'Layer both cheeses on the bread.',
      'Top with second slice, butter-side up.',
      'Turn heat to medium-low.',
      'Cook 3-4 minutes until bottom is golden brown.',
      'Flip carefully and cook 2-3 minutes more.',
      'Let cool 1 minute before cutting.',
    ],
    servings: '1',
    prepTime: '2 mins',
    cookTime: '8 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.favorites,
    ingredients: [
      { originalText: '2 slices bread', name: 'bread', quantity: 2, unit: 'slice', orderIndex: 0 },
      { originalText: '2 tablespoons butter', name: 'butter', quantity: 2, unit: 'tablespoon', orderIndex: 1 },
      { originalText: '2 slices American cheese', name: 'American cheese', quantity: 2, unit: 'slice', orderIndex: 2 },
      { originalText: '2 slices cheddar cheese', name: 'cheddar cheese', quantity: 2, unit: 'slice', orderIndex: 3 },
    ],
  },
  {
    id: RECIPE_IDS.tomatoSoup,
    title: 'Homemade Tomato Soup',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80',
    instructions: [
      'In a large pot, heat butter over medium heat.',
      'Add diced onion and cook until softened (5 minutes).',
      'Add minced garlic and cook for 1 minute.',
      'Add crushed tomatoes, vegetable broth, and dried basil.',
      'Bring to a boil, then reduce heat and simmer 15 minutes.',
      'Use an immersion blender to puree until smooth.',
      'Stir in heavy cream and season with salt and pepper.',
      'Serve hot with grilled cheese.',
    ],
    servings: '4',
    prepTime: '10 mins',
    cookTime: '25 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.favorites,
    ingredients: [
      { originalText: '2 tablespoons butter', name: 'butter', quantity: 2, unit: 'tablespoon', orderIndex: 0 },
      { originalText: '1 onion, diced', name: 'onion', quantity: 1, unit: null, orderIndex: 1 },
      { originalText: '3 cloves garlic, minced', name: 'garlic', quantity: 3, unit: 'clove', orderIndex: 2 },
      { originalText: '2 cans crushed tomatoes', name: 'crushed tomatoes', quantity: 2, unit: 'can', orderIndex: 3 },
      { originalText: '2 cups vegetable broth', name: 'vegetable broth', quantity: 2, unit: 'cup', orderIndex: 4 },
      { originalText: '1/2 cup heavy cream', name: 'heavy cream', quantity: 0.5, unit: 'cup', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.chocolateCake,
    title: "Grandma's Chocolate Cake",
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800&q=80',
    instructions: [
      'Preheat oven to 350°F. Grease two 9-inch round cake pans.',
      'Whisk together flour, sugar, cocoa, baking soda, and salt.',
      'Add eggs, buttermilk, oil, and vanilla. Beat 2 minutes.',
      'Stir in hot coffee (batter will be thin).',
      'Divide batter evenly between prepared pans.',
      'Bake 30-35 minutes until a toothpick comes out clean.',
      'Cool in pans 10 minutes, then turn out onto wire racks.',
      'Cool completely before frosting.',
    ],
    servings: '12',
    prepTime: '20 mins',
    cookTime: '35 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.desserts,
    ingredients: [
      { originalText: '2 cups all-purpose flour', name: 'all-purpose flour', quantity: 2, unit: 'cup', orderIndex: 0 },
      { originalText: '2 cups sugar', name: 'sugar', quantity: 2, unit: 'cup', orderIndex: 1 },
      { originalText: '3/4 cup cocoa powder', name: 'cocoa powder', quantity: 0.75, unit: 'cup', orderIndex: 2 },
      { originalText: '2 eggs', name: 'eggs', quantity: 2, unit: null, orderIndex: 3 },
      { originalText: '1 cup buttermilk', name: 'buttermilk', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '1 cup hot coffee', name: 'hot coffee', quantity: 1, unit: 'cup', orderIndex: 5 },
      { originalText: '1/2 cup vegetable oil', name: 'vegetable oil', quantity: 0.5, unit: 'cup', orderIndex: 6 },
    ],
  },
  {
    id: RECIPE_IDS.applePie,
    title: "Grandma's Apple Pie",
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1568571780765-9276ac8b75a2?w=800&q=80',
    instructions: [
      'Preheat oven to 425°F.',
      'Place one pie crust in a 9-inch pie plate.',
      'Toss apple slices with sugar, flour, cinnamon, and lemon juice.',
      'Pour apple mixture into crust. Dot with butter.',
      'Cover with second crust. Crimp edges to seal.',
      'Cut slits in top crust for steam to escape.',
      'Brush with egg wash and sprinkle with sugar.',
      'Bake at 425°F for 15 minutes, then reduce to 350°F for 35-40 minutes.',
      'Cool at least 2 hours before serving.',
    ],
    servings: '8',
    prepTime: '30 mins',
    cookTime: '55 mins',
    isFavorite: true,
    collectionId: COLLECTION_IDS.desserts,
    ingredients: [
      { originalText: '2 pie crusts', name: 'pie crusts', quantity: 2, unit: null, orderIndex: 0 },
      { originalText: '6 cups sliced apples', name: 'sliced apples', quantity: 6, unit: 'cup', orderIndex: 1 },
      { originalText: '3/4 cup sugar', name: 'sugar', quantity: 0.75, unit: 'cup', orderIndex: 2 },
      { originalText: '2 tablespoons flour', name: 'flour', quantity: 2, unit: 'tablespoon', orderIndex: 3 },
      { originalText: '1 teaspoon cinnamon', name: 'cinnamon', quantity: 1, unit: 'teaspoon', orderIndex: 4 },
      { originalText: '2 tablespoons butter', name: 'butter', quantity: 2, unit: 'tablespoon', orderIndex: 5 },
    ],
  },
  {
    id: RECIPE_IDS.cheesecake,
    title: 'Classic New York Cheesecake',
    sourceType: 'manual',
    firebaseImageURL: 'https://images.unsplash.com/photo-1533134242443-d4fd215305ad?w=800&q=80',
    instructions: [
      'Preheat oven to 325°F. Wrap outside of springform pan with foil.',
      'Mix graham cracker crumbs, sugar, and melted butter. Press into pan bottom.',
      'Bake crust 10 minutes. Let cool.',
      'Beat cream cheese until smooth. Add sugar and beat until fluffy.',
      'Add eggs one at a time, beating after each. Mix in vanilla and sour cream.',
      'Pour filling over crust. Place pan in larger roasting pan with 1 inch hot water.',
      'Bake 55-60 minutes until edges are set but center jiggles slightly.',
      'Turn off oven, crack door, and let cool 1 hour in oven.',
      'Refrigerate at least 4 hours or overnight before serving.',
    ],
    servings: '12',
    prepTime: '25 mins',
    cookTime: '60 mins',
    isFavorite: false,
    collectionId: COLLECTION_IDS.desserts,
    ingredients: [
      { originalText: '2 cups graham cracker crumbs', name: 'graham cracker crumbs', quantity: 2, unit: 'cup', orderIndex: 0 },
      { originalText: '3 tablespoons sugar', name: 'sugar', quantity: 3, unit: 'tablespoon', orderIndex: 1 },
      { originalText: '6 tablespoons melted butter', name: 'melted butter', quantity: 6, unit: 'tablespoon', orderIndex: 2 },
      { originalText: '4 packages (8 oz each) cream cheese', name: 'cream cheese', quantity: 32, unit: 'oz', orderIndex: 3 },
      { originalText: '1 cup sugar', name: 'sugar', quantity: 1, unit: 'cup', orderIndex: 4 },
      { originalText: '4 eggs', name: 'eggs', quantity: 4, unit: null, orderIndex: 5 },
      { originalText: '1 cup sour cream', name: 'sour cream', quantity: 1, unit: 'cup', orderIndex: 6 },
      { originalText: '2 teaspoons vanilla extract', name: 'vanilla extract', quantity: 2, unit: 'teaspoon', orderIndex: 7 },
    ],
  },
];

// Collection definitions
const COLLECTIONS = [
  {
    id: COLLECTION_IDS.weeknight,
    name: 'Weeknight Dinners',
    icon: 'clock',
    color: '#4A90A4',
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
    id: COLLECTION_IDS.desserts,
    name: 'Desserts',
    icon: 'birthday.cake',
    color: '#9C27B0',
    isSystemCollection: false,
  },
];

/**
 * Create the demo user in Firebase Auth
 */
async function createDemoUser(): Promise<string> {
  console.log('Creating demo user in Firebase Auth...');

  try {
    const existingUser = await auth.getUserByEmail(DEMO_EMAIL).catch(() => null);

    if (existingUser) {
      console.log(`  User already exists: ${existingUser.uid}`);
      return existingUser.uid;
    }

    const user = await auth.createUser({
      email: DEMO_EMAIL,
      password: DEMO_PASSWORD,
      displayName: DEMO_DISPLAY_NAME,
      emailVerified: true,
    });

    console.log(`  ✓ Created user: ${user.uid}`);
    return user.uid;
  } catch (error) {
    console.error('  ✗ Failed to create user:', error);
    throw error;
  }
}

/**
 * Create user profile
 */
async function createUserProfile(userId: string): Promise<void> {
  console.log('Creating user profile...');

  await db.collection('users').doc(userId).collection('profile').doc('data').set({
    displayName: DEMO_DISPLAY_NAME,
    email: DEMO_EMAIL,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('  ✓ Profile created');
}

/**
 * Set expired subscription for App Store Review
 * Apple needs to see the paywall, so demo account has expired subscription
 */
async function grantPremiumSubscription(userId: string): Promise<void> {
  console.log('Setting expired subscription for App Store Review...');

  await db.collection('users').doc(userId).collection('subscription').doc('status').set({
    isActive: false,  // Expired for App Store Review
    productId: 'com.rationaledesign.heirloom.premium.annual.v2',
    planType: 'annual',
    expiresAt: admin.firestore.Timestamp.fromDate(new Date('2024-01-01')),  // Past date = expired
    startedAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'demo_seed',
  }, { merge: true });

  console.log('  ✓ Expired subscription set (for App Store Review paywall testing)');
}

/**
 * Create collections
 */
async function createCollections(userId: string): Promise<void> {
  console.log('Creating collections...');

  for (const collection of COLLECTIONS) {
    // Get recipe IDs for this collection
    const recipeIds = DEMO_RECIPES
      .filter(r => r.collectionId === collection.id)
      .map(r => r.id);

    await db.collection('users').doc(userId).collection('collections').doc(collection.id).set({
      id: collection.id,
      name: collection.name,
      icon: collection.icon,
      color: collection.color,
      isSystemCollection: collection.isSystemCollection,
      isAllRecipes: false,
      isDemoSeed: false,  // Apple demo account - NOT demo seed (Apple needs to see collections)
      recipeIds: recipeIds,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      modifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`  ✓ ${collection.name} (${recipeIds.length} recipes)`);
  }
}

/**
 * Create recipes with correct Firestore format
 */
async function createRecipes(userId: string): Promise<void> {
  console.log('Creating recipes...');

  const now = new Date();

  for (const recipe of DEMO_RECIPES) {
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

    console.log(`  ✓ ${recipe.title} (${recipe.ingredients.length} ingredients)`);
  }

  console.log(`\n  Created ${DEMO_RECIPES.length} recipes`);
}

/**
 * Main seed function
 */
async function seedAppStoreDemo(): Promise<void> {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('  Seeding App Store Review Demo Account (v2)');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`  Email: ${DEMO_EMAIL}`);
  console.log(`  Password: ${DEMO_PASSWORD}`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  const userId = await createDemoUser();
  await createUserProfile(userId);
  await grantPremiumSubscription(userId);
  await createCollections(userId);
  await createRecipes(userId);

  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log('  ✅ Demo account ready!');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log(`  Email: ${DEMO_EMAIL}`);
  console.log(`  Password: ${DEMO_PASSWORD}`);
  console.log(`  User ID: ${userId}`);
  console.log(`  Collections: ${COLLECTIONS.length}`);
  console.log(`  Recipes: ${DEMO_RECIPES.length}`);
  console.log('');
  console.log('  The demo user should now log in, and recipes will sync down.');
  console.log('═══════════════════════════════════════════════════════════════\n');
}

/**
 * Cleanup function
 */
async function cleanupAppStoreDemo(): Promise<void> {
  console.log('Cleaning up App Store demo account...\n');

  try {
    const user = await auth.getUserByEmail(DEMO_EMAIL).catch(() => null);

    if (!user) {
      console.log('  Demo user not found. Nothing to clean up.');
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
    console.log(`  ✓ Deleted ${recipesSnapshot.size} recipes`);

    // Delete collections
    const collectionsSnapshot = await db.collection('users').doc(userId).collection('collections').get();
    for (const doc of collectionsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  ✓ Deleted ${collectionsSnapshot.size} collections`);

    // Delete subscription
    await db.collection('users').doc(userId).collection('subscription').doc('status').delete();
    console.log('  ✓ Deleted subscription');

    // Delete profile
    await db.collection('users').doc(userId).collection('profile').doc('data').delete();
    console.log('  ✓ Deleted profile');

    // Delete Firebase Auth user
    await auth.deleteUser(userId);
    console.log('  ✓ Deleted Firebase Auth user');

    console.log('\n✅ Demo account cleaned up successfully');
  } catch (error) {
    console.error('Error during cleanup:', error);
    throw error;
  }
}

// CLI handling
if (require.main === module) {
  const command = process.argv[2];

  if (command === 'cleanup') {
    cleanupAppStoreDemo()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  } else {
    seedAppStoreDemo()
      .then(() => process.exit(0))
      .catch((err) => {
        console.error('Error:', err);
        process.exit(1);
      });
  }
}

export { seedAppStoreDemo, cleanupAppStoreDemo };
