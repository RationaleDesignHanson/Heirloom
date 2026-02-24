/**
 * Seed Account Deletion Test Account
 *
 * Creates a test account for Apple reviewers to test the account deletion feature.
 * Structure: 3 collections (Favorites + 2 custom) + recipes with REAL Firebase Storage images
 *
 * Email: deletetest@heirloomrecipebox.app
 * Password: HeirloomDemo2026!
 *
 * Run: npx ts-node src/seed-deletion-test-account.ts
 * Cleanup: npx ts-node src/seed-deletion-test-account.ts cleanup
 *
 * IMPORTANT: Favorites collection MUST be created in Firebase for recipe linking to work.
 * The app may create its own Favorites, but the sync service will merge them by name.
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { v4 as uuidv4 } from 'uuid';
import fetch from 'node-fetch';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin with Storage
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const db = admin.firestore();
const auth = admin.auth();
const storage = admin.storage().bucket();

// Deletion test account credentials
const TEST_EMAIL = 'deletetest@heirloomrecipebox.app';
const TEST_PASSWORD = 'HeirloomDemo2026!';
const TEST_DISPLAY_NAME = 'Delete Test User';

// DETERMINISTIC UUIDs for recipes (idempotent seeding - re-runs update instead of duplicate)
const RECIPE_IDS = {
  honeyGarlicSalmon: 'a1111111-1111-1111-1111-111111111111',
  shepherdsPie: 'a2222222-2222-2222-2222-222222222222',
  friedRice: 'a3333333-3333-3333-3333-333333333333',
  shrimpScampi: 'a4444444-4444-4444-4444-444444444444',
  caesarSalad: 'a5555555-5555-5555-5555-555555555555',
  frenchOnionSoup: 'a6666666-6666-6666-6666-666666666666',
  bananaBread: 'a7777777-7777-7777-7777-777777777777',
  blueberryMuffins: 'a8888888-8888-8888-8888-888888888888',
  cinnamonRolls: 'a9999999-9999-9999-9999-999999999999',
};

// DETERMINISTIC Collection UUIDs (idempotent seeding)
const COLLECTION_IDS = {
  favorites: 'c1111111-1111-1111-1111-111111111111',
  quickEasy: 'c2222222-2222-2222-2222-222222222222',
  bakedGoods: 'c3333333-3333-3333-3333-333333333333',
  webImports: 'c4444444-4444-4444-4444-444444444444',
};

// ============================================================================
// DEMO FRIENDS DATA (from DemoSocialBehaviorService - DO NOT MODIFY)
// ============================================================================

const DEMO_USERS = {
  grandmazing: {
    id: 'demo_grandmazing',
    displayName: 'Grandmazing',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing-avatar.webp',
    recipe: {
      id: '5e13b837-1a80-4d22-af8a-c474a6ea5c35',
      title: 'Brown Butter Chocolate Chip Cookies',
      message: "Welcome to Heirloom! Here's my most popular recipe to get you started. These cookies are a family favorite!",
      servings: '24 cookies',
      prepTime: '20 min',
      cookTime: '12 min',
      ingredientCount: 11,
      instructionCount: 8,
      imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_grandmazing_chocolate_chip_cookies-image.webp',
    },
  },
  phillipfry: {
    id: 'demo_phillipfry',
    displayName: 'Phillip Fry',
    generation: 1,
  },
  chefmaria: {
    id: 'demo_chef_maria',
    displayName: 'Maria Santos',
    generation: 1,
  },
  bigshare: {
    id: 'demo_bigshare',
    displayName: 'Big Share',
    photoURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare-avatar.webp',
    generation: 2,
    recipe: {
      id: 'e5f6a7b8-c9d0-1234-efab-345678901234',
      title: 'The Traveling Bolognese',
      message: "This recipe started with Grandmazing in Vermont and has traveled through 5 kitchens — each person added their own twist. Accept it and check the Family Tree to see how it evolved!",
      servings: '6 servings',
      prepTime: '20 min',
      cookTime: '4 hours',
      ingredientCount: 14,
      instructionCount: 8,
      imageURL: 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo/demo_bigshare_bolognese-image.webp',
      // Lineage data for The Traveling Bolognese
      rootRecipeId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      rootOwnerId: 'demo_grandmazing',
      shareGeneration: 2,  // Recipient becomes Gen 3
      heritageChainIds: ['demo_grandmazing', 'demo_phillipfry', 'demo_chef_maria', 'demo_bigshare', 'demo_grillmaster'],
      heritageChainNames: ['Grandmazing', 'Phillip Fry', 'Maria Santos', 'Big Share', 'Marcus Johnson'],
    },
  },
  grillmaster: {
    id: 'demo_grillmaster',
    displayName: 'Marcus Johnson',
    generation: 2,
  },
};

// Web Import recipe data (from heirloomrecipebox.app/demo/recipe)
const WEB_IMPORT_RECIPE = {
  id: 'b0111111-1111-1111-1111-111111111111',  // Deterministic ID (valid hex)
  title: 'The Best Soft & Chewy Chocolate Chip Cookies',
  sourceType: 'urlImport',
  sourceURL: 'https://heirloomrecipebox.app/demo/recipe',
  // Image for the web import (chocolate chip cookies)
  imageURL: 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800&q=80',
  // Attribution to the website author
  authorName: 'Cheryl Buttersworth',
  servings: '36 cookies',
  prepTime: '20 min',
  cookTime: '12 min',
  instructions: [
    'Preheat oven to 375°F. Line baking sheets with parchment paper.',
    'Whisk together flour, baking soda, and salt in a medium bowl.',
    'Cream butter and both sugars until fluffy (3-4 minutes). Add eggs one at a time, then vanilla.',
    'Gradually incorporate flour mixture on low speed. Fold in chocolate chips and walnuts.',
    'Drop rounded tablespoons of dough onto sheets, spacing 2 inches apart.',
    'Bake 9-12 minutes until edges are golden but centers appear slightly underdone. Cool on sheet for 5 minutes before transferring to wire rack.',
  ],
  ingredients: [
    { originalText: '2 ¼ cups all-purpose flour', name: 'all-purpose flour', quantity: 2.25, unit: 'cup', orderIndex: 0 },
    { originalText: '1 tsp baking soda', name: 'baking soda', quantity: 1, unit: 'tsp', orderIndex: 1 },
    { originalText: '1 tsp fine sea salt', name: 'fine sea salt', quantity: 1, unit: 'tsp', orderIndex: 2 },
    { originalText: '1 cup (2 sticks) unsalted butter, softened', name: 'unsalted butter', quantity: 1, unit: 'cup', orderIndex: 3 },
    { originalText: '¾ cup granulated sugar', name: 'granulated sugar', quantity: 0.75, unit: 'cup', orderIndex: 4 },
    { originalText: '¾ cup packed light brown sugar', name: 'light brown sugar', quantity: 0.75, unit: 'cup', orderIndex: 5 },
    { originalText: '2 large eggs, room temperature', name: 'eggs', quantity: 2, unit: null, orderIndex: 6 },
    { originalText: '2 tsp pure vanilla extract', name: 'vanilla extract', quantity: 2, unit: 'tsp', orderIndex: 7 },
    { originalText: '2 cups semi-sweet chocolate chips', name: 'chocolate chips', quantity: 2, unit: 'cup', orderIndex: 8 },
    { originalText: '1 cup chopped walnuts (optional)', name: 'walnuts', quantity: 1, unit: 'cup', orderIndex: 9 },
  ],
};

// Share IDs for pending demo shares (deterministic for idempotent seeding)
const PENDING_SHARE_IDS = {
  grandmazingCookies: 'share-grandmazing-cookies-pending',
  bigshareBolognese: 'share-bigshare-bolognese-pending',
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
  collectionIds: string[];  // Recipe can belong to multiple collections
  unsplashImageURL: string; // Source URL to download from
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // In both collections
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // Not favorite - only in Quick & Easy
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // In both collections
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // Not favorite
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // In both collections
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1534939561126-855b8675edd7?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.quickEasy],  // Not favorite
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1605286978633-2dec93ff88a2?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.bakedGoods],  // In both collections
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1607958996333-41aef7caefaa?w=800&q=80', // Working blueberry muffin image
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
    isFavorite: true, // Added as favorite (6 total now)
    collectionIds: [COLLECTION_IDS.bakedGoods],  // In both collections
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
    unsplashImageURL: 'https://images.unsplash.com/photo-1509365465985-25d11c17e812?w=800&q=80',
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
    collectionIds: [COLLECTION_IDS.bakedGoods],  // In both collections
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

// Collection definitions
// NOTE: Do NOT seed Favorites - the app handles favorites via isFavorite flag on recipes
// Seeding a separate Favorites collection conflicts with the app's built-in favorites handling
const COLLECTIONS = [
  {
    id: COLLECTION_IDS.quickEasy,
    name: 'Quick & Easy',
    iconName: 'bolt.fill', // Must match SF Symbol names used by app
    color: '#FF9500',
    isSystemCollection: false,
    collectionType: 'userCreated',
    // No preset - uses recipe collage
  },
  {
    id: COLLECTION_IDS.bakedGoods,
    name: 'Baked Goods',
    iconName: 'flame.fill',
    color: '#8B4513',
    isSystemCollection: false,
    collectionType: 'userCreated',
    // Preset background from app bundle
    customBackgroundImagePath: 'preset-holiday-baking-bg',
    useCustomBackground: true,
  },
];

/**
 * Download image from URL and upload to Firebase Storage
 * Returns the Firebase Storage download URL (using token-based URL)
 */
async function uploadImageToStorage(
  userId: string,
  recipeId: string,
  imageUrl: string
): Promise<string | null> {
  try {
    console.log(`    Downloading image for recipe ${recipeId}...`);

    // Download image from Unsplash
    const response = await fetch(imageUrl);
    if (!response.ok) {
      console.error(`    Failed to download image: ${response.status}`);
      return null;
    }

    const imageBuffer = await response.buffer();
    const contentType = response.headers.get('content-type') || 'image/jpeg';

    // Generate unique filename with download token
    const timestamp = Date.now();
    const downloadToken = uuidv4(); // Token for public access
    const fileName = `recipe-${recipeId}-${timestamp}.jpg`;
    const storagePath = `users/${userId}/recipe-images/${fileName}`;

    console.log(`    Uploading to Firebase Storage: ${storagePath}`);

    // Upload to Firebase Storage with download token in metadata
    const file = storage.file(storagePath);
    await file.save(imageBuffer, {
      metadata: {
        contentType: contentType,
        metadata: {
          firebaseStorageDownloadTokens: downloadToken, // This enables public download URL
          recipeId: recipeId,
          uploadedAt: new Date().toISOString(),
          source: 'deletion-test-seed',
        },
      },
    });

    // Construct Firebase Storage download URL with token
    const encodedPath = encodeURIComponent(storagePath);
    const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${storage.name}/o/${encodedPath}?alt=media&token=${downloadToken}`;

    console.log(`    Image uploaded successfully`);
    return downloadUrl;
  } catch (error) {
    console.error(`    Failed to upload image:`, error);
    return null;
  }
}

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
 * Create user profile with hasCompletedOnboarding: true
 */
async function createUserProfile(userId: string): Promise<void> {
  console.log('Creating user profile...');

  await db.collection('users').doc(userId).collection('profile').doc('data').set({
    displayName: TEST_DISPLAY_NAME,
    email: TEST_EMAIL,
    hasCompletedOnboarding: true, // Skip onboarding for test account
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('  Profile created (onboarding marked complete)');
}

/**
 * Set NO subscription for App Store Review
 * Apple needs to see the paywall, so test account has no active subscription
 * We delete any existing subscription document to ensure clean state
 */
async function setExpiredSubscription(userId: string): Promise<void> {
  console.log('Removing any existing subscription (for App Store Review paywall)...');

  // Delete any existing subscription status to ensure clean state
  await db.collection('users').doc(userId).collection('subscription').doc('status').delete().catch(() => {});

  // Set explicitly expired/inactive subscription
  await db.collection('users').doc(userId).collection('subscription').doc('status').set({
    isActive: false,  // NOT active
    productId: null,  // No product
    planType: null,   // No plan
    expiresAt: null,  // No expiration (never had one)
    startedAt: null,  // Never started
    source: 'deletion_test_seed_no_subscription',
  });

  console.log('  Subscription removed (user will see paywall)');
}

/**
 * Create user collections (NOT Favorites - app handles favorites via isFavorite flag)
 */
async function createCollections(userId: string): Promise<void> {
  console.log('Creating collections...');

  for (const collection of COLLECTIONS) {
    // Get recipe IDs for this collection
    const recipeIds = TEST_RECIPES
      .filter(r => r.collectionIds.includes(collection.id))
      .map(r => r.id);

    const collectionData: Record<string, any> = {
      id: collection.id,
      name: collection.name,
      iconName: collection.iconName, // App expects 'iconName' not 'icon'
      color: collection.color,
      isSystemCollection: collection.isSystemCollection,
      isAllRecipes: false,
      isDemoSeed: false, // Not demo content
      collectionType: collection.collectionType,  // 'system' for Favorites, 'userCreated' for others
      recipeIds: recipeIds,
      // Use a date 1 day ago to ensure Firebase collections are preferred during sync deduplication
      // (app-created local collections have later createdDate)
      createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)),
      modifiedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)),
    };

    // Add preset background if specified (for distinct collection appearances)
    if ((collection as any).customBackgroundImagePath) {
      collectionData.customBackgroundImagePath = (collection as any).customBackgroundImagePath;
      collectionData.useCustomBackground = (collection as any).useCustomBackground ?? true;
    }

    await db.collection('users').doc(userId).collection('collections').doc(collection.id).set(collectionData);

    console.log(`  ${collection.name} (${recipeIds.length} recipes)`);
  }
}

/**
 * Create recipes with REAL Firebase Storage images
 */
async function createRecipes(userId: string): Promise<void> {
  console.log('Creating recipes with real images...');

  const now = new Date();

  for (const recipe of TEST_RECIPES) {
    console.log(`  Creating: ${recipe.title}`);

    // Upload image to Firebase Storage
    const firebaseImageURL = await uploadImageToStorage(
      userId,
      recipe.id,
      recipe.unsplashImageURL
    );

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
      isFavorite: recipe.isFavorite, // Flag for analytics/display
      firebaseImageURL: firebaseImageURL, // Real Firebase Storage URL
      timesCooked: 0,
      generationCount: 0,
      collectionIds: recipe.collectionIds,  // All collections this recipe belongs to
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

    console.log(`    ${recipe.isFavorite ? '⭐ ' : ''}${recipe.ingredients.length} ingredients`);
  }

  console.log(`\n  Created ${TEST_RECIPES.length} recipes with images`);
  console.log(`  Favorites: ${TEST_RECIPES.filter(r => r.isFavorite).length} recipes marked`);
}

/**
 * Create demo friend connections (Grandmazing and Big Share)
 * These are already connected so shares can be pending
 */
async function createDemoConnections(userId: string): Promise<void> {
  console.log('Creating demo friend connections...');

  const now = new Date();
  const demoUsers = [DEMO_USERS.grandmazing, DEMO_USERS.bigshare];

  for (const demoUser of demoUsers) {
    const connectionId = uuidv4();

    await db.collection('users').doc(userId).collection('connections').doc(connectionId).set({
      id: connectionId,
      userId: userId,
      connectedUserId: demoUser.id,
      connectedUserDisplayName: demoUser.displayName,
      connectedUserPhotoURL: demoUser.photoURL,
      status: 'connected',  // Already connected
      initiatedBy: userId,  // User sent request
      requestedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 86400000)), // 1 day ago
      acceptedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 86300000)),  // Accepted shortly after
      recipesSharedCount: 0,
      recipesReceivedCount: 0,
      isFavorite: false,
      isKitchenTableConnection: false,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
      isDemoConnection: true,
    });

    console.log(`  Connected with ${demoUser.displayName}`);
  }
}

/**
 * Seed Grandmazing's Cookies recipe (for the cookies pending share)
 * The Bolognese lineage tree is handled by bigshare-lineage/seed.ts
 */
async function seedGrandmazingCookies(): Promise<void> {
  console.log('Seeding Grandmazing cookies recipe...');

  const now = new Date();
  const grandmazing = DEMO_USERS.grandmazing;

  // Check if cookies recipe already exists
  const existingRecipe = await db.doc(`users/${grandmazing.id}/recipes/${grandmazing.recipe.id}`).get();
  if (existingRecipe.exists) {
    console.log(`  Grandmazing cookies already exists, skipping`);
    return;
  }

  // Create Grandmazing's Cookies (Gen 0)
  const grandmazingRecipeRef = db.collection('users').doc(grandmazing.id).collection('recipes').doc(grandmazing.recipe.id);
  await grandmazingRecipeRef.set({
    id: grandmazing.recipe.id,
    title: grandmazing.recipe.title,
    sourceType: 'manual',
    firebaseImageURL: grandmazing.recipe.imageURL,
    instructions: [
      'Brown the butter in a saucepan over medium heat until golden and nutty, about 5 minutes. Let cool.',
      'Whisk flour, baking soda, and salt in a bowl.',
      'Beat cooled brown butter with both sugars until fluffy.',
      'Add eggs one at a time, then vanilla.',
      'Gradually mix in flour mixture until just combined.',
      'Fold in chocolate chips.',
      'Chill dough for 30 minutes.',
      'Bake at 375°F for 10-12 minutes until edges are golden.',
    ],
    servings: grandmazing.recipe.servings,
    prepTime: grandmazing.recipe.prepTime,
    cookTime: grandmazing.recipe.cookTime,
    isFavorite: false,
    timesCooked: 0,
    generationCount: 0,
    collectionIds: [],
    createdAt: admin.firestore.Timestamp.fromDate(now),
    modifiedAt: admin.firestore.Timestamp.fromDate(now),
    lastSyncedAt: admin.firestore.Timestamp.fromDate(now),
  });

  const cookieIngredients = [
    { originalText: '1 cup unsalted butter', name: 'unsalted butter', quantity: 1, unit: 'cup', orderIndex: 0 },
    { originalText: '2 cups all-purpose flour', name: 'all-purpose flour', quantity: 2, unit: 'cup', orderIndex: 1 },
    { originalText: '1 tsp baking soda', name: 'baking soda', quantity: 1, unit: 'tsp', orderIndex: 2 },
    { originalText: '1 tsp salt', name: 'salt', quantity: 1, unit: 'tsp', orderIndex: 3 },
    { originalText: '¾ cup granulated sugar', name: 'granulated sugar', quantity: 0.75, unit: 'cup', orderIndex: 4 },
    { originalText: '¾ cup brown sugar', name: 'brown sugar', quantity: 0.75, unit: 'cup', orderIndex: 5 },
    { originalText: '2 large eggs', name: 'eggs', quantity: 2, unit: null, orderIndex: 6 },
    { originalText: '2 tsp vanilla extract', name: 'vanilla extract', quantity: 2, unit: 'tsp', orderIndex: 7 },
    { originalText: '2 cups chocolate chips', name: 'chocolate chips', quantity: 2, unit: 'cup', orderIndex: 8 },
  ];
  for (const ingredient of cookieIngredients) {
    const ingredientId = uuidv4();
    await grandmazingRecipeRef.collection('ingredients').doc(ingredientId).set({
      id: ingredientId,
      ...ingredient,
      isChecked: false,
    });
  }

  // Create lineage for cookies
  const lineageData = {
    id: grandmazing.recipe.id,
    recipeId: grandmazing.recipe.id,
    currentRecipeId: grandmazing.recipe.id,
    ownerId: grandmazing.id,
    ownerDisplayName: grandmazing.displayName,
    generation: 0,
    rootRecipeId: grandmazing.recipe.id,
    rootOwnerId: grandmazing.id,
    parentRecipeId: null,
    parentOwnerId: null,
    title: grandmazing.recipe.title,
    isHeirloom: false,
    hasLocalModifications: false,
    modifications: [],
    createdAt: admin.firestore.Timestamp.fromDate(now),
    updatedAt: admin.firestore.Timestamp.fromDate(now),
    lastModified: admin.firestore.Timestamp.fromDate(now),
    isDemoSeed: true,
    demoSeedLabel: 'grandmazing-cookies',
  };
  await db.collection('lineages').doc(`demo-lineage-${grandmazing.recipe.id}`).set(lineageData);
  await db.doc(`users/${grandmazing.id}/lineages/${grandmazing.recipe.id}`).set(lineageData);

  console.log(`  ${grandmazing.displayName}: ${grandmazing.recipe.title} (Gen 0)`);
}

/**
 * Create lineage documents for a recipe (both user-specific and global)
 * Required for Family Tree feature to work
 */
async function createLineageDocuments(
  userId: string,
  recipeId: string,
  rootRecipeId: string,
  parentRecipeId: string | null,
  rootOwnerId: string,
  generation: number,
  sharedByName: string
): Promise<void> {
  const lineageId = uuidv4();
  const now = new Date();

  const lineageData = {
    id: lineageId,
    rootRecipeId: rootRecipeId,
    parentRecipeId: parentRecipeId,
    currentRecipeId: recipeId,
    ownerId: userId,
    rootOwnerId: rootOwnerId,
    generation: generation,
    createdAt: admin.firestore.Timestamp.fromDate(now),
    lastModified: admin.firestore.Timestamp.fromDate(now),
    isHeirloom: generation > 0,  // Heirloom if shared (gen > 0)
    hasLocalModifications: false,
    sharedByName: sharedByName,
    modifications: [],
  };

  // Store in user's lineages collection
  await db.collection('users').doc(userId).collection('lineages').doc(lineageId).set(lineageData);

  // Also store in global lineages index for cross-user queries
  await db.collection('lineages').doc(lineageId).set(lineageData);

  console.log(`    Created lineage: Gen ${generation} (${lineageId.substring(0, 8)}...)`);
}

/**
 * Create pending share documents and notifications
 * These will appear as "X shared a recipe with you" notifications
 * User must accept them to get the recipes (uses real acceptShare flow)
 */
async function createPendingShares(userId: string): Promise<void> {
  console.log('Creating pending share notifications...');

  const now = new Date();
  const grandmazing = DEMO_USERS.grandmazing;
  const bigshare = DEMO_USERS.bigshare;

  // Clean up any existing pending shares from prior runs
  console.log('  Cleaning up old pending shares...');
  for (const shareId of Object.values(PENDING_SHARE_IDS)) {
    await db.collection('shares').doc(shareId).delete().catch(() => {});
  }
  // Clean up old notifications for this user
  const oldNotifications = await db.collection('users').doc(userId).collection('notifications')
    .where('type', '==', 'connectionSharedRecipe')
    .get();
  for (const doc of oldNotifications.docs) {
    await doc.ref.delete();
  }
  console.log('  Old pending shares cleaned up');

  // ============================================
  // 1. Grandmazing's Chocolate Chip Cookies Share
  // ============================================
  const cookiesShareId = PENDING_SHARE_IDS.grandmazingCookies;

  // Heritage chain for the share (Grandmazing only - user gets added on accept)
  const cookiesHeritageChain = [grandmazing.id];
  const cookiesHeritageChainNames = [grandmazing.displayName];

  // Create share document
  await db.collection('shares').doc(cookiesShareId).set({
    shareId: cookiesShareId,
    recipeId: grandmazing.recipe.id,
    ownerId: grandmazing.id,
    ownerName: grandmazing.displayName,
    recipeTitle: grandmazing.recipe.title,
    shareType: 'heirloom',
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: null,  // No expiration for demo shares

    // Share options (full share)
    includeCardBack: true,
    includeRating: true,
    includeNotes: true,
    includePinnedComments: true,
    includeAllComments: false,
    includeCookingHistory: false,
    includeStickers: true,
    personalMessage: grandmazing.recipe.message,
    allowReSharing: true,

    // Metadata
    generation: 0,  // Grandmazing's generation (user becomes Gen 1)
    servings: grandmazing.recipe.servings,
    prepTime: grandmazing.recipe.prepTime,
    cookTime: grandmazing.recipe.cookTime,
    ingredientCount: grandmazing.recipe.ingredientCount,
    instructionCount: grandmazing.recipe.instructionCount,

    // Preview data
    ingredientsPreview: ['1 cup unsalted butter', '2 cups all-purpose flour', '2 cups chocolate chips'],
    instructionsPreview: [
      'Brown the butter in a saucepan over medium heat until golden and nutty.',
      'Whisk flour, baking soda, and salt in a bowl.',
      'Beat cooled brown butter with both sugars until fluffy.',
    ],

    // Image
    firebaseImageURL: grandmazing.recipe.imageURL,

    // Lineage tracking
    rootRecipeId: grandmazing.recipe.id,
    rootOwnerId: grandmazing.id,
    rootProvenanceHash: grandmazing.recipe.id,
    heritageChain: cookiesHeritageChain,
    heritageChainNames: cookiesHeritageChainNames,

    // Direct share to test user
    recipientUserIds: [userId],
    isDirectShare: true,
    sharedWithCount: 1,
    recipientDisplayNames: { [userId]: TEST_DISPLAY_NAME },

    // Acceptance tracking
    acceptedBy: [],
    acceptCount: 0,
    viewCount: 0,

    // Demo flag
    isDemoShare: true,
  });

  // Create notification for cookies share
  const cookiesNotificationId = uuidv4().toLowerCase();
  await db.collection('users').doc(userId).collection('notifications').doc(cookiesNotificationId).set({
    type: 'connectionSharedRecipe',
    shareId: cookiesShareId,
    recipeId: grandmazing.recipe.id,
    recipeTitle: grandmazing.recipe.title,
    recipeImageURL: grandmazing.recipe.imageURL,
    actorUserId: grandmazing.id,
    actorDisplayName: grandmazing.displayName,
    actorPhotoURL: grandmazing.photoURL,
    timestamp: admin.firestore.Timestamp.fromDate(now),
    read: false,
    deepLinkURL: `heirloom://share/${cookiesShareId}`,
  });

  console.log(`  ${grandmazing.displayName}: "${grandmazing.recipe.title}" (pending share)`);

  // ============================================
  // 2. Big Share's Traveling Bolognese Share
  // ============================================
  const boloShareId = PENDING_SHARE_IDS.bigshareBolognese;

  // Heritage chain for the share (full chain without the recipient)
  const boloHeritageChain = bigshare.recipe.heritageChainIds;
  const boloHeritageChainNames = bigshare.recipe.heritageChainNames;

  // Create share document
  await db.collection('shares').doc(boloShareId).set({
    shareId: boloShareId,
    recipeId: bigshare.recipe.id,
    ownerId: bigshare.id,
    ownerName: bigshare.displayName,
    recipeTitle: bigshare.recipe.title,
    shareType: 'heirloom',
    createdAt: admin.firestore.Timestamp.fromDate(now),
    expiresAt: null,

    // Share options
    includeCardBack: true,
    includeRating: true,
    includeNotes: true,
    includePinnedComments: true,
    includeAllComments: false,
    includeCookingHistory: false,
    includeStickers: true,
    personalMessage: bigshare.recipe.message,
    allowReSharing: true,

    // Metadata
    generation: bigshare.recipe.shareGeneration,  // Big Share's generation (3)
    servings: bigshare.recipe.servings,
    prepTime: bigshare.recipe.prepTime,
    cookTime: bigshare.recipe.cookTime,
    ingredientCount: bigshare.recipe.ingredientCount,
    instructionCount: bigshare.recipe.instructionCount,

    // Preview data
    ingredientsPreview: ['1 large onion', '1 lb ground beef', '½ lb ground pork', '1 cup dry white wine'],
    instructionsPreview: [
      'Finely dice onion, carrot, and celery (soffritto). Sauté in olive oil until soft.',
      'Add ground beef and pork, breaking up and browning well.',
      'Pour in white wine and let it evaporate.',
    ],

    // Image
    firebaseImageURL: bigshare.recipe.imageURL,

    // Lineage tracking
    rootRecipeId: bigshare.recipe.rootRecipeId,
    rootOwnerId: bigshare.recipe.rootOwnerId,
    rootProvenanceHash: bigshare.recipe.rootRecipeId,
    heritageChain: boloHeritageChain,
    heritageChainNames: boloHeritageChainNames,

    // Direct share to test user
    recipientUserIds: [userId],
    isDirectShare: true,
    sharedWithCount: 1,
    recipientDisplayNames: { [userId]: TEST_DISPLAY_NAME },

    // Acceptance tracking
    acceptedBy: [],
    acceptCount: 0,
    viewCount: 0,

    // Demo flag
    isDemoShare: true,
  });

  // Create notification for bolognese share
  const boloNotificationId = uuidv4().toLowerCase();
  await db.collection('users').doc(userId).collection('notifications').doc(boloNotificationId).set({
    type: 'connectionSharedRecipe',
    shareId: boloShareId,
    recipeId: bigshare.recipe.id,
    recipeTitle: bigshare.recipe.title,
    recipeImageURL: bigshare.recipe.imageURL,
    actorUserId: bigshare.id,
    actorDisplayName: bigshare.displayName,
    actorPhotoURL: bigshare.photoURL,
    timestamp: admin.firestore.Timestamp.fromDate(now),
    read: false,
    deepLinkURL: `heirloom://share/${boloShareId}`,
  });

  console.log(`  ${bigshare.displayName}: "${bigshare.recipe.title}" (pending share with lineage)`);

  console.log('  2 pending shares created - user will see notifications to accept them');
}

/**
 * Create web import collection and recipe
 */
async function createWebImport(userId: string): Promise<void> {
  console.log('Creating web import recipe...');

  const now = new Date();

  // Upload image for web import
  console.log('  Uploading web import image...');
  const firebaseImageURL = await uploadImageToStorage(
    userId,
    WEB_IMPORT_RECIPE.id,
    WEB_IMPORT_RECIPE.imageURL
  );

  // Create Web Imports collection with preset background
  await db.collection('users').doc(userId).collection('collections').doc(COLLECTION_IDS.webImports).set({
    id: COLLECTION_IDS.webImports,
    name: 'From Web',  // Match the app's expected name for preset background
    iconName: 'globe',
    color: '#007AFF',
    isSystemCollection: false,
    isAllRecipes: false,
    isDemoSeed: false,
    collectionType: 'webImports',
    recipeIds: [WEB_IMPORT_RECIPE.id],
    customBackgroundImagePath: 'preset-from-web-bg',
    useCustomBackground: true,
    // Use a date 1 day ago to ensure Firebase collections are preferred during sync deduplication
    createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)),
    modifiedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 86400000)),
  });

  // Create web import recipe with provenance for attribution
  const recipeRef = db.collection('users').doc(userId).collection('recipes').doc(WEB_IMPORT_RECIPE.id);
  await recipeRef.set({
    id: WEB_IMPORT_RECIPE.id,
    title: WEB_IMPORT_RECIPE.title,
    sourceType: WEB_IMPORT_RECIPE.sourceType,
    sourceURL: WEB_IMPORT_RECIPE.sourceURL,
    firebaseImageURL: firebaseImageURL,
    instructions: WEB_IMPORT_RECIPE.instructions,
    servings: WEB_IMPORT_RECIPE.servings,
    prepTime: WEB_IMPORT_RECIPE.prepTime,
    cookTime: WEB_IMPORT_RECIPE.cookTime,
    isFavorite: false,
    timesCooked: 0,
    generationCount: 0,
    collectionIds: [COLLECTION_IDS.webImports],
    // Provenance for proper attribution to website author
    provenance: {
      sourceType: 'imported',
      sourceURL: WEB_IMPORT_RECIPE.sourceURL,
      sourceAttribution: WEB_IMPORT_RECIPE.authorName,
      generation: 0,
      rootProvenanceHash: uuidv4(),  // Unique hash for this recipe
    },
    createdAt: admin.firestore.Timestamp.fromDate(now),
    modifiedAt: admin.firestore.Timestamp.fromDate(now),
    lastSyncedAt: admin.firestore.Timestamp.fromDate(now),
  });

  // Create ingredients subcollection
  for (const ingredient of WEB_IMPORT_RECIPE.ingredients) {
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

  console.log(`  From Web collection with: ${WEB_IMPORT_RECIPE.title}`);
  console.log(`    Source: ${WEB_IMPORT_RECIPE.sourceURL}`);
  console.log(`    Attribution: ${WEB_IMPORT_RECIPE.authorName}`);
}

/**
 * Clean existing user data (collections, recipes) before seeding
 * This ensures idempotent seeding without duplicates
 */
async function cleanExistingUserData(userId: string): Promise<void> {
  console.log('Cleaning existing user data (if any)...');

  // Delete all existing collections
  const collectionsSnapshot = await db.collection('users').doc(userId).collection('collections').get();
  for (const doc of collectionsSnapshot.docs) {
    await doc.ref.delete();
  }
  if (collectionsSnapshot.size > 0) {
    console.log(`  Deleted ${collectionsSnapshot.size} existing collections`);
  }

  // Delete all existing recipes (and their ingredients subcollections)
  const recipesSnapshot = await db.collection('users').doc(userId).collection('recipes').get();
  for (const doc of recipesSnapshot.docs) {
    // Delete ingredients subcollection
    const ingredientsSnapshot = await doc.ref.collection('ingredients').get();
    for (const ingredientDoc of ingredientsSnapshot.docs) {
      await ingredientDoc.ref.delete();
    }
    await doc.ref.delete();
  }
  if (recipesSnapshot.size > 0) {
    console.log(`  Deleted ${recipesSnapshot.size} existing recipes`);
  }

  // Delete existing connections
  const connectionsSnapshot = await db.collection('users').doc(userId).collection('connections').get();
  for (const doc of connectionsSnapshot.docs) {
    await doc.ref.delete();
  }
  if (connectionsSnapshot.size > 0) {
    console.log(`  Deleted ${connectionsSnapshot.size} existing connections`);
  }

  // Delete existing notifications
  const notificationsSnapshot = await db.collection('users').doc(userId).collection('notifications').get();
  for (const doc of notificationsSnapshot.docs) {
    await doc.ref.delete();
  }
  if (notificationsSnapshot.size > 0) {
    console.log(`  Deleted ${notificationsSnapshot.size} existing notifications`);
  }

  // Delete existing lineages
  const lineagesSnapshot = await db.collection('users').doc(userId).collection('lineages').get();
  for (const doc of lineagesSnapshot.docs) {
    await doc.ref.delete();
  }
  // Also delete from global lineages
  const globalLineagesSnapshot = await db.collection('lineages').where('ownerId', '==', userId).get();
  for (const doc of globalLineagesSnapshot.docs) {
    await doc.ref.delete();
  }
  if (lineagesSnapshot.size > 0 || globalLineagesSnapshot.size > 0) {
    console.log(`  Deleted ${lineagesSnapshot.size + globalLineagesSnapshot.size} existing lineages`);
  }

  console.log('  User data cleaned');
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
  await cleanExistingUserData(userId);  // Clean before seeding to prevent duplicates
  await createUserProfile(userId);
  await setExpiredSubscription(userId);
  await createCollections(userId);
  await createRecipes(userId);
  await createDemoConnections(userId);
  await seedGrandmazingCookies();  // Create Grandmazing's cookies (for the cookies share)
  // NOTE: Bolognese lineage tree is created by bigshare-lineage/seed.ts
  await createPendingShares(userId);      // Create pending shares (user accepts via real flow)
  await createWebImport(userId);

  console.log('\n===============================================================');
  console.log('  Deletion test account ready!');
  console.log('===============================================================');
  console.log(`  Email: ${TEST_EMAIL}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log(`  User ID: ${userId}`);
  console.log('');
  console.log('  Collections:');
  console.log(`    - Quick & Easy: ${TEST_RECIPES.filter(r => r.collectionIds.includes(COLLECTION_IDS.quickEasy)).length} recipes`);
  console.log(`    - Baked Goods: ${TEST_RECIPES.filter(r => r.collectionIds.includes(COLLECTION_IDS.bakedGoods)).length} recipes`);
  console.log(`    - From Web: 1 recipe (with attribution)`);
  console.log(`    - Favorites: ${TEST_RECIPES.filter(r => r.isFavorite).length} recipes (via isFavorite flag)`);
  console.log('');
  console.log('  Demo Friends:');
  console.log(`    - ${DEMO_USERS.grandmazing.displayName} (connected)`);
  console.log(`    - ${DEMO_USERS.bigshare.displayName} (connected)`);
  console.log('');
  console.log('  Pending Shares (notifications):');
  console.log(`    - "${DEMO_USERS.grandmazing.recipe.title}" from ${DEMO_USERS.grandmazing.displayName}`);
  console.log(`    - "${DEMO_USERS.bigshare.recipe.title}" from ${DEMO_USERS.bigshare.displayName} (with lineage)`);
  console.log('');
  console.log('  User will see notifications to accept these shares.');
  console.log('  Accepting uses the real acceptShare flow for correct heritageChain.');
  console.log('');
  console.log('  Theme collections (German-American, Scandinavian) will be');
  console.log('  created automatically by the app on sign-in.');
  console.log('');
  console.log('  Apple reviewers can use this account to test account deletion.');
  console.log('  After deletion, run this script again to re-seed.');
  console.log('===============================================================\n');
}

/**
 * Cleanup function - deletes all user data and images
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

    // Delete recipe images from Storage
    console.log('  Deleting images from Firebase Storage...');
    try {
      const [files] = await storage.getFiles({ prefix: `users/${userId}/recipe-images/` });
      for (const file of files) {
        await file.delete();
      }
      console.log(`    Deleted ${files.length} images`);
    } catch (error) {
      console.log('    No images to delete or error:', error);
    }

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

    // Delete connections
    const connectionsSnapshot = await db.collection('users').doc(userId).collection('connections').get();
    for (const doc of connectionsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${connectionsSnapshot.size} connections`);

    // Delete user's lineages
    const userLineagesSnapshot = await db.collection('users').doc(userId).collection('lineages').get();
    for (const doc of userLineagesSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${userLineagesSnapshot.size} user lineages`);

    // Delete global lineages where this user is owner
    const globalLineagesSnapshot = await db.collection('lineages')
      .where('ownerId', '==', userId)
      .get();
    for (const doc of globalLineagesSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${globalLineagesSnapshot.size} global lineages`);

    // Delete pending shares (by deterministic IDs)
    for (const shareId of Object.values(PENDING_SHARE_IDS)) {
      await db.collection('shares').doc(shareId).delete().catch(() => {});
    }
    console.log(`  Deleted pending demo shares`);

    // Delete shares where this user is recipient
    const sharesSnapshot = await db.collection('shares')
      .where('recipientUserIds', 'array-contains', userId)
      .get();
    for (const doc of sharesSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${sharesSnapshot.size} additional shares`);

    // Delete notifications
    const notificationsSnapshot = await db.collection('users').doc(userId).collection('notifications').get();
    for (const doc of notificationsSnapshot.docs) {
      await doc.ref.delete();
    }
    console.log(`  Deleted ${notificationsSnapshot.size} notifications`);

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
