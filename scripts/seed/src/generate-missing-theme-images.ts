/**
 * Generate missing theme recipe images
 *
 * This script generates images for the 48 expanded theme recipes that
 * were added but don't have images yet:
 * - presidential-pantry: 015-025 (11 recipes)
 * - literary-kitchen: 015-025 (11 recipes)
 * - ancient-table: 013-025 (13 recipes)
 * - american-foundation: 013-025 (13 recipes)
 *
 * Uses Google Secret Manager for API keys (same pattern as Cloud Functions)
 */

import * as admin from 'firebase-admin';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    path.resolve(__dirname, '../../../service-account-key.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
    storageBucket: 'heirloom-ios-prod.firebasestorage.app',
  });
}

const storage = admin.storage();

// Google Cloud project ID (same as Firebase project)
const PROJECT_ID = 'heirloom-ios-prod';

// Replicate API configuration
const REPLICATE_API_URL = 'https://api.replicate.com/v1';
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';

// Cache the API token after first fetch
let cachedReplicateToken: string | null = null;

/**
 * Get Replicate API token from Google Secret Manager
 * Uses the same secret that Cloud Functions use
 */
async function getReplicateToken(): Promise<string> {
  if (cachedReplicateToken) {
    return cachedReplicateToken;
  }

  console.log('  Fetching REPLICATE_API_TOKEN from Google Secret Manager...');

  const client = new SecretManagerServiceClient();
  const secretName = `projects/${PROJECT_ID}/secrets/REPLICATE_API_TOKEN/versions/latest`;

  try {
    const [version] = await client.accessSecretVersion({ name: secretName });
    const payload = version.payload?.data;

    if (!payload) {
      throw new Error('Secret payload is empty');
    }

    // Handle both string and Uint8Array
    const token = typeof payload === 'string'
      ? payload
      : Buffer.from(payload).toString('utf8');

    cachedReplicateToken = token.trim();
    console.log('  Successfully retrieved API token from Secret Manager');
    return cachedReplicateToken;
  } catch (error: any) {
    if (error.code === 5) { // NOT_FOUND
      throw new Error(
        `Secret REPLICATE_API_TOKEN not found in project ${PROJECT_ID}. ` +
        `Set it with: firebase functions:secrets:set REPLICATE_API_TOKEN`
      );
    }
    throw new Error(`Failed to access Secret Manager: ${error.message}`);
  }
}

// Missing recipes by theme
interface MissingRecipe {
  themeId: string;
  recipeId: string;
  title: string;
}

const MISSING_RECIPES: MissingRecipe[] = [
  // Presidential Pantry (015-025)
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-015', title: "Herbert Hoover's Waldorf Salad" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-016', title: "Ulysses S. Grant's Rice Pudding" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-017', title: "William Howard Taft's Steak" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-018', title: "Benjamin Harrison's Corn Relish" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-019', title: "Rutherford B. Hayes' Mashed Potatoes" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-020', title: "James Buchanan's Sauerkraut" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-021', title: "Grover Cleveland's Corned Beef Hash" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-022', title: "Chester Arthur's Lobster Newburg" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-023', title: "Millard Fillmore's Apple Dumplings" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-024', title: "Franklin Pierce's Rum Punch" },
  { themeId: 'presidential-pantry', recipeId: 'presidential-pantry-025', title: "William McKinley's Gingerbread Cookies" },

  // Literary Kitchen (015-025)
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-015', title: "Oliver Twist's Gruel" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-016', title: "The Hobbit's Seed-cakes" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-017', title: "Proust's Madeleines" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-018', title: "James Bond's Vesper Martini" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-019', title: "The Bell Jar's Avocado Pear" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-020', title: "Don Quixote's Olla Podrida" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-021', title: "The Old Man and the Sea's Fried Dolphinfish" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-022', title: "Emma's Wedding Cake" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-023', title: "The Grapes of Wrath's Biscuits" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-024', title: "Babette's Feast Blinis" },
  { themeId: 'literary-kitchen', recipeId: 'literary-kitchen-025', title: "Catch-22's Chocolate Covered Cotton Candy" },

  // Ancient Table (013-025)
  { themeId: 'ancient-table', recipeId: 'ancient-table-013', title: 'Phoenician Fish Stew' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-014', title: 'Carthaginian Couscous' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-015', title: 'Etruscan Polenta' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-016', title: 'Sumerian Date Cake' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-017', title: 'Chinese Jiaozi Dumplings' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-018', title: 'Viking Smoked Fish' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-019', title: 'Celtic Oat Porridge' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-020', title: 'Aztec Chocolate Drink' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-021', title: 'Inca Quinoa Soup' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-022', title: 'Medieval Pottage' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-023', title: 'Roman Puls' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-024', title: 'Greek Symposium Wine' },
  { themeId: 'ancient-table', recipeId: 'ancient-table-025', title: 'Babylonian Beer' },

  // American Foundation (013-025)
  { themeId: 'american-foundation', recipeId: 'american-foundation-013', title: 'Samp and Beans' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-014', title: 'Rye and Injun Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-015', title: 'Pone' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-016', title: 'Flummery' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-017', title: 'Persimmon Pudding' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-018', title: 'Hominy Grits' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-019', title: 'Shrub (Colonial Fruit Drink)' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-020', title: 'Indian Pudding' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-021', title: 'Corn Oysters' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-022', title: 'Anadama Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-023', title: 'Sally Lunn Bread' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-024', title: 'Ash Cakes' },
  { themeId: 'american-foundation', recipeId: 'american-foundation-025', title: 'Spider Corn Cake' },
];

interface ReplicatePrediction {
  id: string;
  status: 'starting' | 'processing' | 'succeeded' | 'failed' | 'canceled';
  output?: string | string[];
  error?: string;
}

/**
 * Generate image using Replicate Flux API
 * Uses the same API pattern as the Cloud Function
 */
async function generateImage(title: string): Promise<string> {
  const apiToken = await getReplicateToken();

  // Clean title for better prompts
  const cleanTitle = title
    .replace(/'s/g, '')
    .replace(/The |'s /g, '')
    .trim();

  const prompt = `Professional food photography of ${cleanTitle}, overhead shot on rustic wooden table, natural window lighting, garnished beautifully, shallow depth of field, appetizing and delicious looking, high quality, 8k resolution, editorial food magazine style, vintage americana aesthetic`;

  console.log(`  Generating image for: ${title}`);

  // Create prediction (same as Cloud Function)
  const createResponse = await fetch(`${REPLICATE_API_URL}/models/${FLUX_MODEL}/predictions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
      'Prefer': 'wait', // Wait for result instead of polling
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

  // Poll if needed (same as Cloud Function)
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

  // Extract image URL
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

  // Bucket uses uniform bucket-level access, so no need for makePublic()
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
  console.log('🎨 Generating Missing Theme Recipe Images\n');
  console.log('Using Google Secret Manager for API credentials\n');
  console.log(`Total recipes to process: ${MISSING_RECIPES.length}\n`);

  const newMappings: Array<{ themeId: string; recipeId: string; title: string; slug: string }> = [];
  let successCount = 0;
  let errorCount = 0;

  for (const recipe of MISSING_RECIPES) {
    try {
      console.log(`\n[${successCount + errorCount + 1}/${MISSING_RECIPES.length}] ${recipe.title}`);

      // Generate image with Replicate (using Secret Manager for token)
      const replicateUrl = await generateImage(recipe.title);

      // Extract slug from recipe ID (e.g., "015" from "presidential-pantry-015")
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
