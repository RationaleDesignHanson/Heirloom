import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';

// Define the Replicate API token secret
const replicateToken = defineSecret('REPLICATE_API_TOKEN');

// Replicate API base URL
const REPLICATE_API_URL = 'https://api.replicate.com/v1';

// Flux Pro model for high-quality, fast image generation
// Using black-forest-labs/flux-1.1-pro for best quality/speed balance
const FLUX_MODEL = 'black-forest-labs/flux-1.1-pro';

interface ReplicatePrediction {
  id: string;
  status: 'starting' | 'processing' | 'succeeded' | 'failed' | 'canceled';
  output?: string | string[];
  error?: string;
  urls?: {
    get: string;
    cancel: string;
  };
}

/**
 * Generate an image using Replicate Flux model
 *
 * Much faster than DALL-E (2-5 sec vs 15-20 sec)
 * Supports higher concurrency for bulk operations
 */
export const replicateGenerateImage = onCall(
  {
    secrets: [replicateToken],
    region: 'us-central1',
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    const {
      prompt,
      aspectRatio = '16:9',
      outputFormat = 'jpg',
      outputQuality = 90,
    } = request.data as {
      prompt: string;
      aspectRatio?: string;
      outputFormat?: string;
      outputQuality?: number;
    };

    // Validate input
    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Prompt is required and must be a string');
    }

    if (prompt.length > 4000) {
      throw new HttpsError('invalid-argument', 'Prompt must be less than 4000 characters');
    }

    const userId = request.auth.uid;

    logger.info('Generating Replicate Flux image', {
      userId,
      promptLength: prompt.length,
      aspectRatio,
      outputFormat,
    });

    try {
      const apiToken = replicateToken.value()?.trim();
      if (!apiToken) {
        throw new HttpsError('internal', 'Replicate API token not configured');
      }

      // Create prediction (start generation)
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
            aspect_ratio: aspectRatio,
            output_format: outputFormat,
            output_quality: outputQuality,
            safety_tolerance: 2, // Moderate safety (1-5, lower = stricter)
            prompt_upsampling: true, // Enhance prompts for better results
          },
        }),
      });

      if (!createResponse.ok) {
        const errorText = await createResponse.text();
        logger.error('Replicate API error', {
          status: createResponse.status,
          error: errorText,
          userId,
        });

        if (createResponse.status === 401) {
          throw new HttpsError('unauthenticated', 'Invalid Replicate API token');
        } else if (createResponse.status === 429) {
          throw new HttpsError('resource-exhausted', 'Rate limit exceeded');
        }
        throw new HttpsError('internal', `Replicate API error: ${errorText}`);
      }

      const prediction = await createResponse.json() as ReplicatePrediction;

      logger.info('Replicate prediction created', {
        userId,
        predictionId: prediction.id,
        status: prediction.status,
      });

      // If using 'Prefer: wait', the response should already have the result
      // But we may need to poll if it's still processing
      let result = prediction;
      let pollAttempts = 0;
      const maxPollAttempts = 60; // Max 60 seconds of polling

      while (result.status !== 'succeeded' && result.status !== 'failed' && result.status !== 'canceled') {
        if (pollAttempts >= maxPollAttempts) {
          throw new HttpsError('deadline-exceeded', 'Image generation timed out');
        }

        // Wait 1 second before polling
        await new Promise(resolve => setTimeout(resolve, 1000));
        pollAttempts++;

        const pollResponse = await fetch(`${REPLICATE_API_URL}/predictions/${prediction.id}`, {
          headers: {
            'Authorization': `Bearer ${apiToken}`,
          },
        });

        if (!pollResponse.ok) {
          throw new HttpsError('internal', 'Failed to poll prediction status');
        }

        result = await pollResponse.json() as ReplicatePrediction;

        logger.debug('Polling prediction', {
          predictionId: prediction.id,
          status: result.status,
          attempt: pollAttempts,
        });
      }

      if (result.status === 'failed') {
        logger.error('Replicate prediction failed', {
          userId,
          predictionId: prediction.id,
          error: result.error,
        });
        throw new HttpsError('internal', result.error || 'Image generation failed');
      }

      if (result.status === 'canceled') {
        throw new HttpsError('cancelled', 'Image generation was canceled');
      }

      // Extract image URL from output
      let imageUrl: string;
      if (typeof result.output === 'string') {
        imageUrl = result.output;
      } else if (Array.isArray(result.output) && result.output.length > 0) {
        imageUrl = result.output[0];
      } else {
        throw new HttpsError('internal', 'No image URL in response');
      }

      logger.info('Replicate image generated successfully', {
        userId,
        predictionId: prediction.id,
        hasUrl: !!imageUrl,
      });

      return {
        imageUrl,
        predictionId: prediction.id,
      };

    } catch (error: any) {
      logger.error('Replicate image generation failed', {
        userId,
        error: error.message,
        errorName: error.name,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError('internal', `Failed to generate image: ${error.message || String(error)}`);
    }
  }
);
