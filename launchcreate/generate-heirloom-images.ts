/**
 * Generate Heirloom marketing images using Replicate API
 *
 * Run with: npx ts-node src/generate-heirloom-images.ts
 */

import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import * as fs from 'fs';
import * as path from 'path';

// Flux model for high-quality images
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';
const REPLICATE_API_URL = 'https://api.replicate.com/v1';
const PROJECT_ID = 'heirloom-ios-prod';

// Output directory
const OUTPUT_DIR = '/Users/matthanson/Desktop/HeirloomCaptures/GenAI';

// Cache the API token
let cachedReplicateToken: string | null = null;

interface ReplicatePrediction {
  id: string;
  status: 'starting' | 'processing' | 'succeeded' | 'failed' | 'canceled';
  output?: string | string[];
  error?: string;
}

interface ImageSpec {
  filename: string;
  width: number;
  height: number;
  prompt: string;
  negativePrompt: string;
}

// Image specifications — photographic style matching the app's visual language
// App uses: "professional food photography", "warm golden hour lighting",
// "rustic wooden table", "overhead shot", "shallow depth of field"
const IMAGES: ImageSpec[] = [
  {
    filename: 'AI_01_onboarding_hero.png',
    width: 1200,
    height: 800,
    prompt: `Professional food photography, warm golden hour lighting, rustic wooden table with a neat stack of handwritten recipe cards next to scattered loose papers and a phone showing a recipe, cozy home kitchen background slightly blurred, cream and amber color palette, soft natural shadows, overhead angle, inviting and organized, high quality, detailed, 8k resolution, no text no labels no words`,
    negativePrompt: `illustration, vector, cartoon, 3D render, dark colors, cold colors, blue, purple, cluttered, busy, text, words, logos, faces, people, hands, neon, harsh lighting, restaurant styling, modern plating`,
  },
  {
    filename: 'AI_02_collection_weeknight.png',
    width: 800,
    height: 400,
    prompt: `Professional food photography of simple weeknight dinner ingredients, pasta and fresh vegetables on a rustic wooden cutting board, warm golden hour lighting, overhead flat lay, cream and terracotta tones, shallow depth of field, home-cooked aesthetic, high quality, 8k resolution, no text no labels no words, horizontal composition`,
    negativePrompt: `illustration, vector, cartoon, busy, cluttered, cold colors, text, people, hands, faces, restaurant styling, modern plating, harsh lighting`,
  },
  {
    filename: 'AI_03_collection_holiday.png',
    width: 800,
    height: 400,
    prompt: `Professional food photography of holiday baking scene, fresh cookies on a cooling rack, cinnamon sticks, star anise, flour-dusted wooden surface, warm spice colors, cream and rich brown tones, golden hour lighting, overhead angle, nostalgic cozy atmosphere, high quality, 8k resolution, no text no labels no words, horizontal composition`,
    negativePrompt: `illustration, vector, cartoon, Christmas specific, snow, neon red and green, text, people, hands, faces, harsh lighting`,
  },
  {
    filename: 'AI_04_collection_lunches.png',
    width: 800,
    height: 400,
    prompt: `Professional food photography of a fresh lunch spread, colorful salad bowls and sandwiches on a clean white marble surface, bright natural daylight, overhead flat lay, light and fresh feeling, cream and sage green accents, modern minimalist food photography, high quality, 8k resolution, no text no labels no words, horizontal composition`,
    negativePrompt: `illustration, vector, cartoon, heavy, dark colors, text, people, hands, faces, cluttered, harsh lighting`,
  },
  {
    filename: 'AI_05_collection_family.png',
    width: 800,
    height: 400,
    prompt: `Professional food photography evoking family cooking, vintage ceramic serving dishes on a worn wooden farmhouse table, warm golden hour lighting, nostalgic cozy atmosphere, cream and soft orange tones, slightly overhead angle, shallow depth of field, home-cooked heritage aesthetic, high quality, 8k resolution, no text no labels no words, horizontal composition`,
    negativePrompt: `illustration, vector, cartoon, modern, cold, text, specific faces, people, hands, restaurant styling, harsh lighting`,
  },
  {
    filename: 'AI_06_og_image.png',
    width: 1200,
    height: 630,
    prompt: `Professional food photography, warm overhead flat lay of beautifully arranged recipe cards and fresh ingredients on a rustic wooden table, soft natural lighting, cream and terracotta color palette, shallow depth of field with left third slightly out of focus for text overlay space, inviting home kitchen feel, high quality, 8k resolution, no text no labels no words`,
    negativePrompt: `illustration, vector, cartoon, cluttered, dark, cold colors, text, screenshots, faces, people, harsh lighting, modern plating`,
  },
  {
    filename: 'AI_07_screenshot_bg.png',
    width: 1290,
    height: 2796,
    prompt: `Subtle warm gradient background for app store screenshot, cream to soft terracotta gradient, subtle ceramic texture, professional and clean, no distinct objects, suitable as background for device mockup, vertical orientation`,
    negativePrompt: `busy, patterns, objects, text, illustrations, food, faces, people`,
  },
  {
    filename: 'AI_08_landing_hero_bg.png',
    width: 1920,
    height: 1080,
    prompt: `Soft-focus food photography background, warm kitchen scene heavily blurred, golden hour light through a window, cream and pale terracotta tones, bokeh light circles, very minimal and professional, suitable as background for text and device mockups overlaid on top, horizontal composition, high quality, 8k resolution`,
    negativePrompt: `illustration, vector, cartoon, sharp focus on food, busy, text, dark, cold colors, faces, people, harsh lighting`,
  },
  {
    filename: 'AI_09_presskit_header.png',
    width: 1200,
    height: 400,
    prompt: `Professional food photography, warm overhead view of a curated recipe card collection on a clean wooden surface, vintage cookbook and fresh herbs visible, warm brand colors (cream, terracotta, sage), golden hour lighting, clean and press-worthy, shallow depth of field, horizontal banner composition with space for text overlay, high quality, 8k resolution, no text no labels no words`,
    negativePrompt: `illustration, vector, cartoon, casual, playful, busy, cold colors, faces, people, hands, harsh lighting, modern plating`,
  },
];

/**
 * Get Replicate API token from Google Secret Manager
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

    const token = typeof payload === 'string'
      ? payload
      : Buffer.from(payload).toString('utf8');

    cachedReplicateToken = token.trim();
    console.log('Successfully retrieved API token from Secret Manager');
    return cachedReplicateToken;
  } catch (error: any) {
    if (error.code === 5) {
      throw new Error(
        `Secret REPLICATE_API_TOKEN not found in project ${PROJECT_ID}. ` +
        `Set it with: firebase functions:secrets:set REPLICATE_API_TOKEN`
      );
    }
    throw new Error(`Failed to access Secret Manager: ${error.message}`);
  }
}

/**
 * Convert dimensions to aspect ratio string
 */
function getAspectRatio(width: number, height: number): string {
  // Flux supports specific aspect ratios, pick the closest one
  const ratio = width / height;

  if (ratio >= 1.7) return '16:9';      // ~1.78
  if (ratio >= 1.4) return '3:2';       // ~1.5
  if (ratio >= 1.15) return '4:3';      // ~1.33
  if (ratio >= 0.85) return '1:1';      // 1.0
  if (ratio >= 0.65) return '3:4';      // ~0.75
  if (ratio >= 0.55) return '2:3';      // ~0.67
  return '9:16';                         // ~0.56
}

/**
 * Generate an image using Replicate API
 */
async function generateImage(spec: ImageSpec): Promise<string> {
  const apiToken = await getReplicateToken();

  // Combine prompt with negative prompt
  const fullPrompt = spec.negativePrompt
    ? `${spec.prompt}. Avoid: ${spec.negativePrompt}`
    : spec.prompt;

  const aspectRatio = getAspectRatio(spec.width, spec.height);
  console.log(`  Aspect ratio: ${aspectRatio} (${spec.width}x${spec.height})`);

  // Create prediction
  const createResponse = await fetch(`${REPLICATE_API_URL}/models/${FLUX_MODEL}/predictions`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
      'Prefer': 'wait',
    },
    body: JSON.stringify({
      input: {
        prompt: fullPrompt,
        aspect_ratio: aspectRatio,
        output_format: 'png',
        output_quality: 95,
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
  const maxPollAttempts = 120; // 2 minutes

  while (prediction.status !== 'succeeded' && prediction.status !== 'failed' && prediction.status !== 'canceled') {
    if (pollAttempts >= maxPollAttempts) {
      throw new Error('Image generation timed out');
    }

    await new Promise(resolve => setTimeout(resolve, 1000));
    pollAttempts++;

    if (pollAttempts % 10 === 0) {
      console.log(`  Still processing... (${pollAttempts}s)`);
    }

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
 * Download image from URL and save to file
 */
async function downloadImage(url: string, outputPath: string): Promise<void> {
  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.status}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  fs.writeFileSync(outputPath, buffer);
}

/**
 * Main function to generate all images
 */
async function main() {
  console.log('='.repeat(60));
  console.log('Heirloom Marketing Image Generator');
  console.log('='.repeat(60));
  console.log(`Output directory: ${OUTPUT_DIR}`);
  console.log(`Images to generate: ${IMAGES.length}`);
  console.log('');

  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const results: { filename: string; success: boolean; error?: string }[] = [];

  for (let i = 0; i < IMAGES.length; i++) {
    const spec = IMAGES[i];
    console.log(`[${i + 1}/${IMAGES.length}] Generating: ${spec.filename}`);
    console.log(`  Dimensions: ${spec.width}x${spec.height}`);

    try {
      // Generate image
      const imageUrl = await generateImage(spec);
      console.log(`  Generated URL: ${imageUrl.substring(0, 50)}...`);

      // Download and save
      const outputPath = path.join(OUTPUT_DIR, spec.filename);
      await downloadImage(imageUrl, outputPath);
      console.log(`  Saved to: ${outputPath}`);

      results.push({ filename: spec.filename, success: true });

      // Rate limiting delay between images
      if (i < IMAGES.length - 1) {
        console.log('  Waiting 2s before next image...');
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    } catch (error: any) {
      console.error(`  ERROR: ${error.message}`);
      results.push({ filename: spec.filename, success: false, error: error.message });
    }

    console.log('');
  }

  // Summary
  console.log('='.repeat(60));
  console.log('SUMMARY');
  console.log('='.repeat(60));

  const successful = results.filter(r => r.success).length;
  const failed = results.filter(r => !r.success).length;

  console.log(`Successful: ${successful}/${IMAGES.length}`);
  console.log(`Failed: ${failed}/${IMAGES.length}`);

  if (failed > 0) {
    console.log('\nFailed images:');
    results.filter(r => !r.success).forEach(r => {
      console.log(`  - ${r.filename}: ${r.error}`);
    });
  }

  console.log(`\nOutput directory: ${OUTPUT_DIR}`);
}

// Run
main().catch(console.error);
