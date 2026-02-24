/**
 * Seed a Firebase account from an exported JSON file
 * - Uploads all recipes from export to Firebase
 * - Generates AI images for recipes without images
 * - Creates proper collections
 * - Sets up theme progress
 */

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
import * as dotenv from 'dotenv';
import fetch from 'node-fetch';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-7b945.firebasestorage.app',
  });
}

const db = admin.firestore();
const auth = admin.auth();
const bucket = admin.storage().bucket();

// Configuration
const TARGET_EMAIL = process.argv[2] || 'tester01@heirloomrecipebox.app';
const EXPORT_FILE = process.argv[3] || '/Users/matthanson/Downloads/heirloom-export-v2-2026-02-20-175903.json';
const GENERATE_IMAGES = process.argv.includes('--generate-images');
const CLEAN_FIRST = process.argv.includes('--clean');

// Parse --unlock-day=N parameter (default to all 14 days)
const unlockDayArg = process.argv.find(arg => arg.startsWith('--unlock-day='));
const TARGET_UNLOCK_DAY = unlockDayArg ? parseInt(unlockDayArg.split('=')[1], 10) : 14;

interface ExportedRecipe {
  id: string;
  title: string;
  ingredients: string[];
  instructions: string[];
  servings?: string;
  prepTime?: string;
  cookTime?: string;
  notes?: string;
  sourceType?: string;
  sourceURL?: string;
  sourcePerson?: string;
  sourceBookTitle?: string;
  sourceDate?: string;
  dateAdded: string;
  lastModified: string;
  isFavorite: boolean;
  timesCooked: number;
  lastCooked?: string;
  isThemeRecipe: boolean;
  sourceThemeId?: string;
  historicalText?: string;
  historicalContext?: string;
  collections?: string[];
  firebaseImageURL?: string;
  tags?: string[];
}

interface ExportData {
  version: number;
  recipes: ExportedRecipe[];
  themeProgress?: {
    selectedThemeIds: string[];
    trialStartDate: string;
    lastUnlockDay: number;
    currentTrialDay: number;
  };
}

interface ThemeRecipe {
  title: string;
  unlockDay: number;
}

interface ThemeData {
  id: string;
  recipes: ThemeRecipe[];
}

// Map theme IDs to their JSON file names
const THEME_FILE_MAP: Record<string, string> = {
  'scandinavian-heritage': 'theme-07-scandinavian.json',
  'german-american': 'theme-08-german-american.json',
  // Add other themes as needed
};

/**
 * Load theme data to get unlock day for each recipe
 */
function loadThemeUnlockDays(): Map<string, number> {
  const recipeUnlockDays = new Map<string, number>();
  const themesDir = path.resolve(__dirname, '../../../themerecipes');

  for (const [themeId, fileName] of Object.entries(THEME_FILE_MAP)) {
    const filePath = path.join(themesDir, fileName);
    if (fs.existsSync(filePath)) {
      const themeData: ThemeData = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
      for (const recipe of themeData.recipes) {
        // Key by title since that's what we have in the export
        recipeUnlockDays.set(recipe.title, recipe.unlockDay);
      }
    }
  }

  return recipeUnlockDays;
}

/**
 * Filter recipes based on unlock day
 */
function filterRecipesByUnlockDay(
  recipes: ExportedRecipe[],
  targetDay: number,
  unlockDays: Map<string, number>
): ExportedRecipe[] {
  return recipes.filter(recipe => {
    // Keep all non-theme recipes
    if (!recipe.isThemeRecipe) return true;

    // For theme recipes, check if unlocked by target day
    const unlockDay = unlockDays.get(recipe.title);
    if (unlockDay === undefined) {
      console.log(`  Warning: No unlock day found for "${recipe.title}", excluding`);
      return false;
    }

    return unlockDay <= targetDay;
  });
}

async function cleanUserData(userId: string): Promise<void> {
  console.log('Cleaning existing user data...');

  // Delete all recipes
  const recipes = await db.collection(`users/${userId}/recipes`).get();
  const recipeBatch = db.batch();
  recipes.docs.forEach(doc => recipeBatch.delete(doc.ref));
  if (recipes.size > 0) {
    await recipeBatch.commit();
    console.log(`  Deleted ${recipes.size} recipes`);
  }

  // Delete all collections
  const collections = await db.collection(`users/${userId}/collections`).get();
  const collectionBatch = db.batch();
  collections.docs.forEach(doc => collectionBatch.delete(doc.ref));
  if (collections.size > 0) {
    await collectionBatch.commit();
    console.log(`  Deleted ${collections.size} collections`);
  }

  console.log('User data cleaned');
}

async function generateImageForRecipe(recipe: ExportedRecipe): Promise<string | null> {
  // Call Firebase Cloud Function to generate image
  const prompt = `a beautifully plated finished dish of ${recipe.title}, ready to serve, professional food photography, soft natural lighting, shallow depth of field`;

  console.log(`  Generating image for: ${recipe.title}`);

  try {
    // Use the generateImage cloud function
    const response = await fetch('https://us-central1-heirloom-7b945.cloudfunctions.net/generateImage', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt }),
    });

    if (!response.ok) {
      console.log(`    Failed to generate image: ${response.status}`);
      return null;
    }

    const data = await response.json() as { imageUrl?: string };
    if (data.imageUrl) {
      console.log(`    Image generated successfully`);
      return data.imageUrl;
    }
    return null;
  } catch (error) {
    console.log(`    Error generating image: ${error}`);
    return null;
  }
}

async function uploadImageToStorage(
  imageUrl: string,
  userId: string,
  recipeId: string
): Promise<string | null> {
  try {
    // Download the image
    const response = await fetch(imageUrl);
    if (!response.ok) return null;

    const buffer = await response.buffer();

    // Upload to Firebase Storage
    const storagePath = `users/${userId}/recipes/${recipeId.toLowerCase()}/image.jpg`;
    const file = bucket.file(storagePath);

    await file.save(buffer, {
      metadata: { contentType: 'image/jpeg' },
    });

    // Get download URL
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '03-01-2500', // Far future expiry
    });

    // Actually use the public URL format
    const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(storagePath)}?alt=media`;

    return publicUrl;
  } catch (error) {
    console.log(`    Error uploading image: ${error}`);
    return null;
  }
}

async function seedRecipes(userId: string, recipes: ExportedRecipe[]): Promise<void> {
  console.log(`\nSeeding ${recipes.length} recipes...`);

  const collectionMap: Record<string, string[]> = {}; // collectionName -> recipeIds

  for (const recipe of recipes) {
    const recipeId = recipe.id.toLowerCase(); // Normalize to lowercase

    // Convert to Firestore format
    const firestoreData: Record<string, any> = {
      id: recipeId,
      title: recipe.title,
      ingredients: recipe.ingredients.map((ing, idx) => ({
        id: `ing-${idx}`,
        originalText: ing,
        name: ing,
        quantity: null,
        unit: null,
      })),
      instructions: recipe.instructions,
      servings: recipe.servings || null,
      prepTime: recipe.prepTime || null,
      cookTime: recipe.cookTime || null,
      notes: recipe.notes || null,
      sourceType: recipe.sourceType || 'manual',
      sourceURL: recipe.sourceURL || null,
      sourcePerson: recipe.sourcePerson || null,
      sourceBookTitle: recipe.sourceBookTitle || null,
      sourceDate: recipe.sourceDate || null,
      dateAdded: admin.firestore.Timestamp.fromDate(new Date(recipe.dateAdded)),
      lastModified: admin.firestore.Timestamp.fromDate(new Date(recipe.lastModified)),
      createdAt: admin.firestore.Timestamp.fromDate(new Date(recipe.dateAdded)),
      modifiedAt: admin.firestore.Timestamp.fromDate(new Date(recipe.lastModified)),
      isFavorite: recipe.isFavorite,
      timesCooked: recipe.timesCooked,
      lastCooked: recipe.lastCooked ? admin.firestore.Timestamp.fromDate(new Date(recipe.lastCooked)) : null,
      isThemeRecipe: recipe.isThemeRecipe,
      sourceThemeId: recipe.sourceThemeId || null,
      historicalText: recipe.historicalText || null,
      historicalContext: recipe.historicalContext || null,
      firebaseImageURL: recipe.firebaseImageURL || null,
      tags: recipe.tags || [],
      isDeleted: false,
    };

    // Track collections
    if (recipe.collections) {
      for (const collName of recipe.collections) {
        if (!collectionMap[collName]) collectionMap[collName] = [];
        collectionMap[collName].push(recipeId);
      }
    }

    // Generate image if needed and flag is set
    if (GENERATE_IMAGES && !firestoreData.firebaseImageURL) {
      const generatedUrl = await generateImageForRecipe(recipe);
      if (generatedUrl) {
        // Upload to user's storage path
        const uploadedUrl = await uploadImageToStorage(generatedUrl, userId, recipeId);
        if (uploadedUrl) {
          firestoreData.firebaseImageURL = uploadedUrl;
        }
      }
      // Add delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Write to Firestore
    await db.collection(`users/${userId}/recipes`).doc(recipeId).set(firestoreData);
    console.log(`  ✓ ${recipe.title}${firestoreData.firebaseImageURL ? ' (with image)' : ''}`);
  }

  // Create collections
  console.log(`\nCreating ${Object.keys(collectionMap).length} collections...`);

  for (const [name, recipeIds] of Object.entries(collectionMap)) {
    const collectionId = `coll-${name.toLowerCase().replace(/[^a-z0-9]/g, '-')}`;

    await db.collection(`users/${userId}/collections`).doc(collectionId).set({
      id: collectionId,
      name: name,
      recipeIds: recipeIds,
      isSystemCollection: name === 'Favorites',
      createdAt: admin.firestore.Timestamp.now(),
      modifiedAt: admin.firestore.Timestamp.now(),
    });

    console.log(`  ✓ ${name} (${recipeIds.length} recipes)`);
  }

  // Always create Favorites if not exists
  if (!collectionMap['Favorites']) {
    const favoritesId = 'favorites';
    await db.collection(`users/${userId}/collections`).doc(favoritesId).set({
      id: favoritesId,
      name: 'Favorites',
      recipeIds: [],
      isSystemCollection: true,
      createdAt: admin.firestore.Timestamp.now(),
      modifiedAt: admin.firestore.Timestamp.now(),
    });
    console.log(`  ✓ Favorites (created empty)`);
  }
}

async function main() {
  console.log('='.repeat(70));
  console.log('SEED FIREBASE FROM EXPORT');
  console.log('='.repeat(70));
  console.log(`Target: ${TARGET_EMAIL}`);
  console.log(`Export: ${EXPORT_FILE}`);
  console.log(`Generate images: ${GENERATE_IMAGES}`);
  console.log(`Clean first: ${CLEAN_FIRST}`);
  console.log(`Target unlock day: ${TARGET_UNLOCK_DAY}`);
  console.log('');

  // Get user ID
  let userId: string;
  try {
    const user = await auth.getUserByEmail(TARGET_EMAIL);
    userId = user.uid;
    console.log(`User ID: ${userId}`);
  } catch (error) {
    console.error(`User not found: ${TARGET_EMAIL}`);
    process.exit(1);
  }

  // Read export file
  if (!fs.existsSync(EXPORT_FILE)) {
    console.error(`Export file not found: ${EXPORT_FILE}`);
    process.exit(1);
  }

  const exportData: ExportData = JSON.parse(fs.readFileSync(EXPORT_FILE, 'utf-8'));
  console.log(`Export version: ${exportData.version}`);
  console.log(`Recipes in export: ${exportData.recipes.length}`);

  // Load unlock day mappings from theme files
  console.log('\nLoading theme unlock day mappings...');
  const unlockDays = loadThemeUnlockDays();
  console.log(`  Loaded unlock days for ${unlockDays.size} recipes`);

  // Filter recipes by unlock day
  const filteredRecipes = filterRecipesByUnlockDay(exportData.recipes, TARGET_UNLOCK_DAY, unlockDays);
  const themeRecipesIncluded = filteredRecipes.filter(r => r.isThemeRecipe).length;
  const userRecipesIncluded = filteredRecipes.filter(r => !r.isThemeRecipe).length;
  console.log(`\nFiltered to ${filteredRecipes.length} recipes:`);
  console.log(`  Theme recipes (day 1-${TARGET_UNLOCK_DAY}): ${themeRecipesIncluded}`);
  console.log(`  User recipes: ${userRecipesIncluded}`);

  // Clean existing data if requested
  if (CLEAN_FIRST) {
    await cleanUserData(userId);
  }

  // Seed filtered recipes
  await seedRecipes(userId, filteredRecipes);

  // Set up theme progress in user's profile document
  const selectedThemeIds = [...new Set(filteredRecipes
    .filter(r => r.isThemeRecipe && r.sourceThemeId)
    .map(r => r.sourceThemeId!)
  )];

  if (selectedThemeIds.length > 0) {
    // Calculate trial start date to be TARGET_UNLOCK_DAY days ago (so current day = TARGET_UNLOCK_DAY)
    const now = new Date();
    const trialStartDate = new Date(now);
    trialStartDate.setDate(trialStartDate.getDate() - (TARGET_UNLOCK_DAY - 1));

    const themeProgress = {
      selectedThemeIds,
      trialStartDate: trialStartDate.toISOString(),
      lastUnlockDay: TARGET_UNLOCK_DAY,
      currentTrialDay: TARGET_UNLOCK_DAY,
    };

    // Save theme progress to user profile
    await db.doc(`users/${userId}`).set(
      { themeProgress },
      { merge: true }
    );
    console.log(`\nSet theme progress: Day ${TARGET_UNLOCK_DAY}, ${selectedThemeIds.length} themes`);
    console.log(`  Trial start: ${trialStartDate.toISOString().split('T')[0]}`);
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('COMPLETE');
  console.log('='.repeat(70));

  // Re-analyze
  const recipesSnap = await db.collection(`users/${userId}/recipes`).get();
  const collectionsSnap = await db.collection(`users/${userId}/collections`).get();

  const withImages = recipesSnap.docs.filter(d => d.data().firebaseImageURL).length;
  const themeRecipes = recipesSnap.docs.filter(d => d.data().isThemeRecipe).length;

  console.log(`Recipes: ${recipesSnap.size} (${themeRecipes} theme, ${recipesSnap.size - themeRecipes} user)`);
  console.log(`With images: ${withImages}`);
  console.log(`Collections: ${collectionsSnap.size}`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
