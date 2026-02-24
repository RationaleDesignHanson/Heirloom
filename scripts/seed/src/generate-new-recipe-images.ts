/**
 * Generate images for the 6 new theme recipes added for 14-day coverage
 *
 * Recipes:
 * - railroad-dining-013: Empire Builder Wild Rice Soup
 * - railroad-dining-014: California Zephyr Baked Alaska
 * - scandinavian-heritage-013: Finnish Karelian Pies
 * - scandinavian-heritage-014: Swedish Hasselback Potatoes
 * - sunday-suppers-013: Yorkshire Pudding
 * - sunday-suppers-014: Honey-Glazed Carrots
 *
 * Uses Google Secret Manager for Replicate API token
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = path.resolve(__dirname, '../../../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const storage = admin.storage();

// Google Cloud project ID
const PROJECT_ID = 'heirloom-ios-prod';

// Replicate API configuration
const REPLICATE_API_URL = 'https://api.replicate.com/v1';
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';

// Cache the API token
let cachedReplicateToken: string | null = null;

// Allow passing token via environment variable as fallback
const ENV_REPLICATE_TOKEN = process.env.REPLICATE_API_TOKEN;

// The 6 new recipes
interface NewRecipe {
  themeId: string;
  recipeId: string;
  title: string;
}

const NEW_RECIPES: NewRecipe[] = [
  { themeId: 'railroad-dining', recipeId: 'railroad-dining-013', title: 'Empire Builder Wild Rice Soup' },
  { themeId: 'railroad-dining', recipeId: 'railroad-dining-014', title: 'California Zephyr Baked Alaska' },
  { themeId: 'scandinavian-heritage', recipeId: 'scandinavian-heritage-013', title: 'Finnish Karelian Pies (Karjalanpiirakat)' },
  { themeId: 'scandinavian-heritage', recipeId: 'scandinavian-heritage-014', title: 'Swedish Hasselback Potatoes' },
  { themeId: 'sunday-suppers', recipeId: 'sunday-suppers-013', title: 'Yorkshire Pudding' },
  { themeId: 'sunday-suppers', recipeId: 'sunday-suppers-014', title: 'Honey-Glazed Carrots' },
];

/**
 * Get Replicate API token from environment variable or Google Secret Manager
 */
async function getReplicateToken(): Promise<string> {
  if (cachedReplicateToken) {
    return cachedReplicateToken;
  }

  // Check environment variable first
  if (ENV_REPLICATE_TOKEN) {
    console.log('Using REPLICATE_API_TOKEN from environment variable\n');
    cachedReplicateToken = ENV_REPLICATE_TOKEN.trim();
    return cachedReplicateToken;
  }

  // Fall back to Secret Manager
  console.log('Fetching REPLICATE_API_TOKEN from Google Secret Manager...');

  const client = new SecretManagerServiceClient();
  const secretName = `projects/${PROJECT_ID}/secrets/REPLICATE_API_TOKEN/versions/latest`;

  const [version] = await client.accessSecretVersion({ name: secretName });
  const payload = version.payload?.data;

  if (!payload) {
    throw new Error('Secret payload is empty');
  }

  const token = typeof payload === 'string'
    ? payload
    : Buffer.from(payload).toString('utf8');

  cachedReplicateToken = token.trim();
  console.log('Successfully retrieved API token from Secret Manager\n');
  return cachedReplicateToken;
}

interface ReplicatePrediction {
  id: string;
  status: 'starting' | 'processing' | 'succeeded' | 'failed' | 'canceled';
  output?: string | string[];
  error?: string;
}

/**
 * Generate image using Replicate Flux API
 */
async function generateImage(title: string): Promise<string> {
  const apiToken = await getReplicateToken();

  // Clean title for better prompts
  const cleanTitle = title
    .replace(/\s*\([^)]*\)/g, '') // Remove parenthetical text
    .replace(/'s/g, '')
    .trim();

  const prompt = `Professional food photography of ${cleanTitle}, overhead shot on rustic wooden table, natural window lighting, garnished beautifully, shallow depth of field, appetizing and delicious looking, high quality, 8k resolution, editorial food magazine style, vintage americana aesthetic`;

  console.log(`  Generating image for: ${cleanTitle}`);

  const createResponse = await fetch(`${REPLICATE_API_URL}/models/${FLUX_MODEL}/predictions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
      'Prefer': 'wait',
    },
    body: JSON.stringify({
      input: {
        prompt: prompt,
        aspect_ratio: '4:3',
        output_format: 'webp',
        output_quality: 90,
        safety_tolerance: 2,
        prompt_upsampling: true,
      },
    }),
  });

  if (!createResponse.ok) {
    const errorText = await createResponse.text();
    throw new Error(`Replicate API error (${createResponse.status}): ${errorText}`);
  }

  let prediction = await createResponse.json() as ReplicatePrediction;

  // Poll if needed
  let pollAttempts = 0;
  const maxPollAttempts = 60;

  while (prediction.status !== 'succeeded' && prediction.status !== 'failed' && prediction.status !== 'canceled') {
    if (pollAttempts >= maxPollAttempts) {
      throw new Error('Image generation timed out');
    }

    await new Promise(resolve => setTimeout(resolve, 1000));
    pollAttempts++;

    const pollResponse = await fetch(`${REPLICATE_API_URL}/predictions/${prediction.id}`, {
      headers: { 'Authorization': `Bearer ${apiToken}` },
    });

    if (!pollResponse.ok) {
      throw new Error('Failed to poll prediction status');
    }

    prediction = await pollResponse.json() as ReplicatePrediction;
  }

  if (prediction.status === 'failed') {
    throw new Error(prediction.error || 'Image generation failed');
  }

  if (prediction.status === 'canceled') {
    throw new Error('Image generation was canceled');
  }

  const imageUrl = typeof prediction.output === 'string'
    ? prediction.output
    : Array.isArray(prediction.output) && prediction.output.length > 0
      ? prediction.output[0]
      : null;

  if (!imageUrl) {
    throw new Error('No image URL in response');
  }

  return imageUrl;
}

/**
 * Upload image to Firebase Storage
 */
async function uploadToStorage(
  imageUrl: string,
  themeId: string,
  slug: string
): Promise<string> {
  console.log(`  Downloading from Replicate...`);

  const response = await fetch(imageUrl);
  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.statusText}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  const bucket = storage.bucket();
  const filePath = `recipes/${themeId}/${themeId}-${slug}.webp`;
  const file = bucket.file(filePath);

  console.log(`  Uploading to: ${filePath}`);

  await file.save(buffer, {
    metadata: {
      contentType: 'image/webp',
      cacheControl: 'public, max-age=31536000',
    },
  });

  const publicUrl = `https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/${filePath}`;
  return publicUrl;
}

/**
 * Update Firestore recipe document with image URL
 */
async function updateFirestoreRecipe(
  themeId: string,
  recipeId: string,
  imageUrl: string
): Promise<void> {
  const db = admin.firestore();
  const recipeRef = db.collection('themes').doc(themeId).collection('recipes').doc(recipeId);

  await recipeRef.update({
    imageURL: imageUrl,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log(`  Updated Firestore: ${recipeId}`);
}

/**
 * Update ID mapping file
 */
function updateIdMapping(newMappings: Array<{ themeId: string; recipeId: string; title: string; slug: string }>): void {
  const mappingPath = path.resolve(__dirname, '../../theme-image-gen/id_conversion_mapping.json');

  const existingData = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));

  for (const mapping of newMappings) {
    existingData.conversions.push({
      theme_id: mapping.themeId,
      theme_name: mapping.themeId.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' '),
      old_id: mapping.slug,
      new_id: mapping.recipeId,
      title: mapping.title,
      sort_order: parseInt(mapping.recipeId.split('-').pop() || '0'),
    });
  }

  existingData.total_recipes = existingData.conversions.length;

  fs.writeFileSync(mappingPath, JSON.stringify(existingData, null, 2));
  console.log(`\nUpdated ${mappingPath} with ${newMappings.length} new entries`);
}

/**
 * Main execution
 */
async function main(): Promise<void> {
  console.log('========================================');
  console.log('Generate Images for 6 New Theme Recipes');
  console.log('========================================\n');
  console.log(`Total recipes to process: ${NEW_RECIPES.length}\n`);

  const newMappings: Array<{ themeId: string; recipeId: string; title: string; slug: string }> = [];
  let successCount = 0;
  let errorCount = 0;

  for (const recipe of NEW_RECIPES) {
    try {
      console.log(`\n[${successCount + errorCount + 1}/${NEW_RECIPES.length}] ${recipe.title}`);

      // Generate image with Replicate
      const replicateUrl = await generateImage(recipe.title);

      // Extract slug from recipe ID (e.g., "013" from "railroad-dining-013")
      const slug = recipe.recipeId.split('-').pop() || recipe.recipeId;

      // Upload to Firebase Storage
      const storageUrl = await uploadToStorage(replicateUrl, recipe.themeId, slug);

      // Update Firestore recipe document
      await updateFirestoreRecipe(recipe.themeId, recipe.recipeId, storageUrl);

      // Record for mapping update
      newMappings.push({
        themeId: recipe.themeId,
        recipeId: recipe.recipeId,
        title: recipe.title,
        slug: slug,
      });

      console.log(`  ✅ Complete: ${storageUrl}`);
      successCount++;

      // Rate limiting - wait 2 seconds between generations
      await new Promise(resolve => setTimeout(resolve, 2000));

    } catch (error) {
      console.error(`  ❌ Error processing ${recipe.recipeId}:`, error);
      errorCount++;
    }
  }

  // Update ID mapping file
  if (newMappings.length > 0) {
    updateIdMapping(newMappings);
  }

  console.log('\n========================================');
  console.log(`✅ Success: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log('========================================\n');
}

// Run
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Fatal error:', err);
    process.exit(1);
  });
