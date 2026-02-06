/**
 * Replicate API utilities
 * Uses Flux model for generating recipe and avatar images
 *
 * API token is fetched from Google Secret Manager (same as Cloud Functions)
 */

import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

// Flux model for high-quality food photography
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';
const REPLICATE_API_URL = 'https://api.replicate.com/v1';

// Google Cloud project ID (same as Firebase project)
const PROJECT_ID = 'heirloom-ios-prod';

// Cache the API token after first fetch
let cachedReplicateToken: string | null = null;

interface ReplicatePrediction {
  id: string;
  status: 'starting' | 'processing' | 'succeeded' | 'failed' | 'canceled';
  output?: string | string[];
  error?: string;
}

/**
 * Get Replicate API token from Google Secret Manager
 * Uses the same secret that Cloud Functions use
 */
async function getReplicateToken(): Promise<string> {
  if (cachedReplicateToken) {
    return cachedReplicateToken;
  }

  console.log('Fetching REPLICATE_API_TOKEN from Google Secret Manager...');

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
    console.log('Successfully retrieved API token from Secret Manager');
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

/**
 * Call Replicate API with the given inputs
 */
async function callReplicateAPI(input: Record<string, any>): Promise<string> {
  const apiToken = await getReplicateToken();

  // Create prediction
  const createResponse = await fetch(`${REPLICATE_API_URL}/models/${FLUX_MODEL}/predictions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
      'Prefer': 'wait', // Wait for result instead of polling
    },
    body: JSON.stringify({ input }),
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
 * Generate a food photography image using Flux
 */
export async function generateFoodImage(recipeTitle: string): Promise<string> {
  const prompt = `Professional food photography of ${recipeTitle}, overhead shot on rustic wooden table, natural window lighting, garnished beautifully, shallow depth of field, appetizing and delicious looking, high quality, 8k resolution, editorial food magazine style`;

  console.log(`Generating image for: ${recipeTitle}`);

  const imageUrl = await callReplicateAPI({
    prompt,
    aspect_ratio: '4:3',
    output_format: 'webp',
    output_quality: 90,
    safety_tolerance: 2,
    prompt_upsampling: true,
  });

  console.log(`Generated image URL: ${imageUrl}`);
  return imageUrl;
}

/**
 * Generate an avatar image for a demo creator
 */
export async function generateAvatarImage(
  creatorName: string,
  description: string
): Promise<string> {
  const prompt = `Portrait photography of ${description}, warm friendly expression, soft natural lighting, home kitchen background slightly blurred, approachable and welcoming, high quality portrait, professional headshot style, 8k resolution`;

  console.log(`Generating avatar for: ${creatorName}`);

  const imageUrl = await callReplicateAPI({
    prompt,
    aspect_ratio: '1:1',
    output_format: 'webp',
    output_quality: 90,
    safety_tolerance: 2,
    prompt_upsampling: true,
  });

  console.log(`Generated avatar URL: ${imageUrl}`);
  return imageUrl;
}

/**
 * Delay helper for rate limiting
 */
export function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
