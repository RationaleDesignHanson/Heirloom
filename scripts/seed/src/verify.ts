#!/usr/bin/env npx ts-node --esm
/**
 * Verify Demo Seeds for Capture Readiness
 * Prints a report of seeded data in Firestore
 *
 * Usage:
 *   npm run verify
 */

import { initializeFirebase, getDb } from './utils/firebase.js';

// ============================================================================
// Types
// ============================================================================

interface PublicRecipeDoc {
  id: string;
  title: string;
  ownerId: string;
  creatorName: string;
  viewCount: number;
  saveCount: number;
  imageURL?: string;
  creatorPhotoURL?: string;
  ingredients: string[];
  instructions: string[];
  tags: string[];
  searchKeywords: string[];
  publishedAt: FirebaseFirestore.Timestamp;
  isDemoSeed?: boolean;
  demoSeedVersion?: string;
}

// ============================================================================
// Verification Logic
// ============================================================================

async function verifySeeds(): Promise<void> {
  console.log('🔍 Verifying Demo Seeds\n');

  // Initialize Firebase
  initializeFirebase();
  const db = getDb();

  // Query all demo seeds
  const snapshot = await db
    .collection('publicRecipes')
    .where('isDemoSeed', '==', true)
    .get();

  if (snapshot.empty) {
    console.log('❌ No demo seeds found in Firestore.');
    console.log('   Run `npm run seed` to create demo data.');
    return;
  }

  const recipes = snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  })) as PublicRecipeDoc[];

  // Group by creator
  const byCreator = new Map<string, PublicRecipeDoc[]>();
  recipes.forEach((recipe) => {
    const existing = byCreator.get(recipe.creatorName) || [];
    existing.push(recipe);
    byCreator.set(recipe.creatorName, existing);
  });

  // Print summary
  console.log('📊 Summary');
  console.log('─'.repeat(50));
  console.log(`Total seeded recipes: ${recipes.length}`);
  console.log('');

  byCreator.forEach((creatorRecipes, creatorName) => {
    console.log(`${creatorName}: ${creatorRecipes.length} recipes`);
  });

  // Check field completeness
  console.log('\n✅ Field Completeness Check');
  console.log('─'.repeat(50));

  let missingImageCount = 0;
  let missingAvatarCount = 0;
  let missingInstructionsCount = 0;
  let missingKeywordsCount = 0;

  recipes.forEach((recipe) => {
    if (!recipe.imageURL) missingImageCount++;
    if (!recipe.creatorPhotoURL) missingAvatarCount++;
    if (!recipe.instructions || recipe.instructions.length === 0) missingInstructionsCount++;
    if (!recipe.searchKeywords || recipe.searchKeywords.length === 0) missingKeywordsCount++;
  });

  console.log(`Missing recipe images: ${missingImageCount}`);
  console.log(`Missing creator avatars: ${missingAvatarCount}`);
  console.log(`Missing instructions: ${missingInstructionsCount}`);
  console.log(`Missing search keywords: ${missingKeywordsCount}`);

  if (missingImageCount + missingAvatarCount + missingInstructionsCount + missingKeywordsCount === 0) {
    console.log('\n✓ All fields populated!');
  } else {
    console.log('\n⚠ Some fields missing. Run `npm run seed` to generate missing data.');
  }

  // PublishedAt distribution
  console.log('\n📅 PublishedAt Distribution');
  console.log('─'.repeat(50));

  const now = new Date();
  const dayBuckets = new Map<string, number>();

  recipes.forEach((recipe) => {
    const publishedDate = recipe.publishedAt.toDate();
    const daysAgo = Math.floor((now.getTime() - publishedDate.getTime()) / (1000 * 60 * 60 * 24));

    let bucket: string;
    if (daysAgo <= 2) bucket = '0-2 days ago';
    else if (daysAgo <= 7) bucket = '3-7 days ago';
    else if (daysAgo <= 14) bucket = '8-14 days ago';
    else bucket = '15+ days ago';

    dayBuckets.set(bucket, (dayBuckets.get(bucket) || 0) + 1);
  });

  ['0-2 days ago', '3-7 days ago', '8-14 days ago', '15+ days ago'].forEach((bucket) => {
    console.log(`${bucket}: ${dayBuckets.get(bucket) || 0} recipes`);
  });

  // Top recipes by engagement
  console.log('\n🔥 Top Recipes by Views');
  console.log('─'.repeat(50));

  const sortedByViews = [...recipes].sort((a, b) => b.viewCount - a.viewCount);
  sortedByViews.slice(0, 5).forEach((recipe, idx) => {
    console.log(`${idx + 1}. ${recipe.title} (${recipe.viewCount} views, ${recipe.saveCount} saves)`);
  });

  console.log('\n💾 Top Recipes by Saves');
  console.log('─'.repeat(50));

  const sortedBySaves = [...recipes].sort((a, b) => b.saveCount - a.saveCount);
  sortedBySaves.slice(0, 5).forEach((recipe, idx) => {
    console.log(`${idx + 1}. ${recipe.title} (${recipe.saveCount} saves, ${recipe.viewCount} views)`);
  });

  // Recipe details
  console.log('\n📋 All Seeded Recipes');
  console.log('─'.repeat(50));

  byCreator.forEach((creatorRecipes, creatorName) => {
    console.log(`\n${creatorName}:`);
    creatorRecipes.forEach((recipe) => {
      const hasImage = recipe.imageURL ? '🖼' : '❌';
      const hasInstructions = recipe.instructions?.length > 0 ? '📝' : '❌';
      console.log(
        `  ${hasImage}${hasInstructions} ${recipe.title} (${recipe.viewCount}/${recipe.saveCount})`
      );
    });
  });

  // Capture readiness verdict
  console.log('\n📸 Capture Readiness');
  console.log('─'.repeat(50));

  const isReady =
    recipes.length >= 10 &&
    missingImageCount === 0 &&
    missingInstructionsCount === 0;

  if (isReady) {
    console.log('✅ READY FOR CAPTURE');
    console.log('   All demo data is in place. You can proceed with Discovery captures.');
  } else {
    console.log('❌ NOT READY');
    console.log('   Fix the issues above before capturing.');
  }
}

// Run verification
verifySeeds().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
