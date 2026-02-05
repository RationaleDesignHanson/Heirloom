#!/usr/bin/env npx ts-node --esm
/**
 * Seed Demo Creators + Public Recipes
 * Idempotent seeding script for Discovery feature
 *
 * Usage:
 *   npm run seed           # Full seed with image generation
 *   npm run seed:no-images # Seed data only, skip image generation
 */

import { initializeFirebase, toTimestamp, daysAgo, getDb } from './utils/firebase.js';
import { uploadImageFromUrl, fileExistsInStorage, getSeedFileUrl } from './utils/storage.js';
import { generateFoodImage, generateAvatarImage, delay } from './utils/replicate.js';
import { generateRecipeKeywords } from './utils/keywords.js';
import { validateAllRecipes, printValidationResults } from './utils/validator.js';
import { ALL_RECIPES, DEMO_CREATORS, SeedRecipe, DemoCreator } from './seed_data.js';

// ============================================================================
// Configuration
// ============================================================================

const SKIP_IMAGES = process.argv.includes('--skip-images');
const IMAGE_DELAY_MS = 2000; // Delay between image generations to avoid rate limits
const SEED_VERSION = 'v1';
const SEED_LABEL = 'discover-capture';

// ============================================================================
// Main Seeding Logic
// ============================================================================

async function seedCreatorAvatars(): Promise<Map<string, string>> {
  console.log('\n📷 Seeding creator avatars...\n');
  const avatarUrls = new Map<string, string>();
  const { storage } = initializeFirebase();
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET!;

  for (const creator of DEMO_CREATORS) {
    const filename = `${creator.id}-avatar.webp`;

    // Check if avatar already exists
    const exists = await fileExistsInStorage(filename);
    if (exists) {
      const url = getSeedFileUrl(filename, bucketName);
      console.log(`✓ Avatar exists: ${creator.creatorName} -> ${url}`);
      avatarUrls.set(creator.id, url);
      continue;
    }

    if (SKIP_IMAGES) {
      console.log(`⏭ Skipping avatar generation: ${creator.creatorName}`);
      avatarUrls.set(creator.id, ''); // Empty URL for skip mode
      continue;
    }

    try {
      // Generate avatar with Replicate
      const tempUrl = await generateAvatarImage(creator.creatorName, creator.avatarDescription);

      // Upload to Firebase Storage
      const permanentUrl = await uploadImageFromUrl(tempUrl, filename);
      console.log(`✓ Created avatar: ${creator.creatorName} -> ${permanentUrl}`);
      avatarUrls.set(creator.id, permanentUrl);

      await delay(IMAGE_DELAY_MS);
    } catch (error) {
      console.error(`✗ Failed to create avatar for ${creator.creatorName}:`, error);
      avatarUrls.set(creator.id, '');
    }
  }

  return avatarUrls;
}

async function seedRecipeImages(): Promise<Map<string, string>> {
  console.log('\n📷 Seeding recipe images...\n');
  const imageUrls = new Map<string, string>();
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET!;

  for (const recipe of ALL_RECIPES) {
    const filename = `${recipe.id}-image.webp`;

    // Check if image already exists
    const exists = await fileExistsInStorage(filename);
    if (exists) {
      const url = getSeedFileUrl(filename, bucketName);
      console.log(`✓ Image exists: ${recipe.title}`);
      imageUrls.set(recipe.id, url);
      continue;
    }

    if (SKIP_IMAGES) {
      console.log(`⏭ Skipping image: ${recipe.title}`);
      imageUrls.set(recipe.id, '');
      continue;
    }

    try {
      // Generate image with Replicate
      const tempUrl = await generateFoodImage(recipe.title);

      // Upload to Firebase Storage
      const permanentUrl = await uploadImageFromUrl(tempUrl, filename);
      console.log(`✓ Created image: ${recipe.title}`);
      imageUrls.set(recipe.id, permanentUrl);

      await delay(IMAGE_DELAY_MS);
    } catch (error) {
      console.error(`✗ Failed to create image for ${recipe.title}:`, error);
      imageUrls.set(recipe.id, '');
    }
  }

  return imageUrls;
}

async function seedPublicRecipes(
  recipeImageUrls: Map<string, string>,
  creatorAvatarUrls: Map<string, string>
): Promise<void> {
  console.log('\n📝 Seeding public recipes to Firestore...\n');
  const db = getDb();

  for (const recipe of ALL_RECIPES) {
    const docRef = db.collection('publicRecipes').doc(recipe.id);

    // Generate search keywords
    const searchKeywords = generateRecipeKeywords({
      title: recipe.title,
      ingredients: recipe.ingredients,
      creatorName: recipe.creatorName,
      tags: recipe.tags,
      category: recipe.category,
    });

    // Build the document data
    const publishedAt = daysAgo(recipe.publishedDaysAgo);
    const data: Record<string, any> = {
      // Core fields
      sourceRecipeId: recipe.sourceRecipeId,
      ownerId: recipe.creatorId,
      title: recipe.title,
      description: recipe.description,
      ingredients: recipe.ingredients,
      instructions: recipe.instructions,
      category: recipe.category,
      tags: recipe.tags,
      servings: recipe.servings,
      prepTime: recipe.prepTime,
      cookTime: recipe.cookTime,

      // Creator attribution
      creatorName: recipe.creatorName,
      creatorProfileSlug: recipe.creatorProfileSlug,

      // Engagement metrics
      viewCount: recipe.viewCount,
      saveCount: recipe.saveCount,

      // Search
      searchKeywords,

      // Moderation
      isHidden: false,
      reportCount: 0,
      moderationStatus: null,

      // Timestamps
      publishedAt: toTimestamp(publishedAt),
      updatedAt: toTimestamp(publishedAt),

      // Seed tagging (for cleanup)
      isDemoSeed: true,
      demoSeedVersion: SEED_VERSION,
      demoSeedLabel: SEED_LABEL,
    };

    // Add optional fields
    if (recipe.totalTime) {
      data.totalTime = recipe.totalTime;
    }

    // Add image URL if available
    const imageUrl = recipeImageUrls.get(recipe.id);
    if (imageUrl) {
      data.imageURL = imageUrl;
    }

    // Add creator photo URL if available
    const avatarUrl = creatorAvatarUrls.get(recipe.creatorId);
    if (avatarUrl) {
      data.creatorPhotoURL = avatarUrl;
    }

    // Upsert the document
    await docRef.set(data, { merge: true });
    console.log(`✓ Upserted: ${recipe.title} (${recipe.id})`);
  }
}

async function main(): Promise<void> {
  console.log('🌱 Heirloom Demo Seeds\n');
  console.log(`Mode: ${SKIP_IMAGES ? 'Data only (no images)' : 'Full seed with images'}`);

  // Initialize Firebase
  console.log('\n🔥 Initializing Firebase...');
  initializeFirebase();

  // Validate all recipes
  console.log('\n✅ Validating recipe data...');
  const validation = validateAllRecipes(ALL_RECIPES);
  printValidationResults(validation.results, false);

  if (!validation.allValid) {
    console.error('\n❌ Validation failed! Fix errors before seeding.');
    process.exit(1);
  }

  console.log(
    `\n📊 Summary: ${validation.summary.total} recipes, ${validation.summary.totalWarnings} warnings`
  );

  // Seed creator avatars
  const creatorAvatarUrls = await seedCreatorAvatars();

  // Seed recipe images
  const recipeImageUrls = await seedRecipeImages();

  // Seed public recipes to Firestore
  await seedPublicRecipes(recipeImageUrls, creatorAvatarUrls);

  // Final summary
  console.log('\n✅ Seeding complete!\n');
  console.log('Summary:');
  console.log(`  - Creators: ${DEMO_CREATORS.length}`);
  console.log(`  - Recipes: ${ALL_RECIPES.length}`);
  console.log(
    `  - Grandmazing: ${ALL_RECIPES.filter((r) => r.creatorId === 'demo_grandmazing').length}`
  );
  console.log(
    `  - Phillip Fry: ${ALL_RECIPES.filter((r) => r.creatorId === 'demo_phillipfry').length}`
  );
  console.log('\nRun `npm run verify` to check capture readiness.');
}

// Run main
main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
