/**
 * Replicate API utilities
 * Uses Flux model for generating recipe and avatar images
 */

import Replicate from 'replicate';

// Flux model for high-quality food photography
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';

let replicate: Replicate | null = null;

/**
 * Initialize Replicate client
 */
function getReplicateClient(): Replicate {
  if (replicate) {
    return replicate;
  }

  const token = process.env.REPLICATE_API_TOKEN;
  if (!token) {
    throw new Error('REPLICATE_API_TOKEN environment variable not set');
  }

  replicate = new Replicate({
    auth: token,
  });

  return replicate;
}

/**
 * Generate a food photography image using Flux
 */
export async function generateFoodImage(recipeTitle: string): Promise<string> {
  const client = getReplicateClient();

  const prompt = `Professional food photography of ${recipeTitle}, overhead shot on rustic wooden table, natural window lighting, garnished beautifully, shallow depth of field, appetizing and delicious looking, high quality, 8k resolution, editorial food magazine style`;

  console.log(`Generating image for: ${recipeTitle}`);

  const output = await client.run(FLUX_MODEL, {
    input: {
      prompt,
      aspect_ratio: '4:3',
      output_format: 'webp',
      output_quality: 90,
      safety_tolerance: 2,
      prompt_upsampling: true,
    },
  });

  // Flux returns a single URL string or array with URL
  const imageUrl = Array.isArray(output) ? output[0] : output;

  if (typeof imageUrl !== 'string') {
    throw new Error(`Unexpected output from Replicate: ${JSON.stringify(output)}`);
  }

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
  const client = getReplicateClient();

  const prompt = `Portrait photography of ${description}, warm friendly expression, soft natural lighting, home kitchen background slightly blurred, approachable and welcoming, high quality portrait, professional headshot style, 8k resolution`;

  console.log(`Generating avatar for: ${creatorName}`);

  const output = await client.run(FLUX_MODEL, {
    input: {
      prompt,
      aspect_ratio: '1:1',
      output_format: 'webp',
      output_quality: 90,
      safety_tolerance: 2,
      prompt_upsampling: true,
    },
  });

  const imageUrl = Array.isArray(output) ? output[0] : output;

  if (typeof imageUrl !== 'string') {
    throw new Error(`Unexpected output from Replicate: ${JSON.stringify(output)}`);
  }

  console.log(`Generated avatar URL: ${imageUrl}`);
  return imageUrl;
}

/**
 * Delay helper for rate limiting
 */
export function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
