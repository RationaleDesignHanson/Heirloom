/**
 * Image Generation Gateway
 * Secure proxy for DALL-E 3 and Replicate image generation
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import OpenAI from 'openai';
import { checkRateLimit, logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

const getOpenAIClient = () => new OpenAI({ apiKey: process.env.OPENAI_KEY });

const getReplicateToken = (): string => {
  return process.env.REPLICATE_API_TOKEN || '';
};

/**
 * Generate an image using OpenAI DALL-E 3
 * Maps to: FirebaseImageGenerationService.generateWithDALLE() in iOS app
 */
export const dalleGenerateImage = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    await checkRateLimit(userId, 'image_generation');

    const { prompt, size, quality } = request.data;

    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid prompt');
    }

    const imageSize = size || '1792x1024';
    const imageQuality = quality || 'standard';

    const response = await getOpenAIClient().images.generate({
      model: 'dall-e-3',
      prompt,
      size: imageSize as '1024x1024' | '1792x1024' | '1024x1792',
      quality: imageQuality as 'standard' | 'hd',
      n: 1,
    });

    const imageUrl = response.data?.[0]?.url;
    const revisedPrompt = response.data?.[0]?.revised_prompt;

    if (!imageUrl) {
      throw new HttpsError('internal', 'No image returned from DALL-E');
    }

    try {
      await logAIUsage(userId, 'dalle_generate_image', {
        provider: 'openai',
        model: 'dall-e-3',
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
      });
    } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

    return {
      imageUrl,
      revisedPrompt: revisedPrompt || prompt,
    };
  } catch (error: any) {
    logger.error('DALL-E Generate Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    if (error.status === 429) {
      throw new HttpsError('resource-exhausted', 'OpenAI rate limit exceeded');
    }
    if (error.status === 400) {
      throw new HttpsError('invalid-argument', error.message || 'Invalid request to DALL-E');
    }

    throw new HttpsError('internal', 'Failed to generate image');
  }
});

/**
 * Generate an image using Replicate (Flux model)
 * Maps to: FirebaseImageGenerationService.generateWithReplicate() in iOS app
 */
export const replicateGenerateImage = onCall(
  { timeoutSeconds: 120 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in');
    }
    if (ENFORCE_APP_CHECK && !request.app) {
      throw new HttpsError('failed-precondition', 'App Check verification failed.');
    }

    const userId = request.auth.uid;

    try {
      await checkRateLimit(userId, 'image_generation');

      const { prompt, aspectRatio, outputFormat, outputQuality } = request.data;

      if (!prompt || typeof prompt !== 'string') {
        throw new HttpsError('invalid-argument', 'Invalid prompt');
      }

      const token = getReplicateToken();
      if (!token) {
        throw new HttpsError('failed-precondition', 'Replicate API not configured');
      }

      // Create prediction using Replicate API
      const createResponse = await fetch(
        'https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions',
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
            'Prefer': 'wait',
          },
          body: JSON.stringify({
            input: {
              prompt,
              aspect_ratio: aspectRatio || '16:9',
              output_format: outputFormat || 'jpg',
              output_quality: outputQuality || 90,
            },
          }),
        }
      );

      if (!createResponse.ok) {
        const errorText = await createResponse.text();
        logger.error('Replicate API Error', { status: createResponse.status, error: errorText });

        if (createResponse.status === 429) {
          throw new HttpsError('resource-exhausted', 'Replicate rate limit exceeded');
        }
        throw new HttpsError('internal', 'Replicate API request failed');
      }

      let prediction = await createResponse.json();

      // Poll for completion if not using Prefer: wait or if still processing
      const maxAttempts = 30;
      let attempts = 0;
      while (prediction.status !== 'succeeded' && prediction.status !== 'failed' && attempts < maxAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 1000));

        const pollResponse = await fetch(
          `https://api.replicate.com/v1/predictions/${prediction.id}`,
          {
            headers: { 'Authorization': `Bearer ${token}` },
          }
        );
        prediction = await pollResponse.json();
        attempts++;
      }

      if (prediction.status === 'failed') {
        logger.error('Replicate prediction failed', { error: prediction.error });
        throw new HttpsError('internal', 'Image generation failed');
      }

      if (prediction.status !== 'succeeded') {
        throw new HttpsError('deadline-exceeded', 'Image generation timed out');
      }

      // Flux returns output as an array of URLs or a single URL
      const output = prediction.output;
      const imageUrl = Array.isArray(output) ? output[0] : output;

      if (!imageUrl) {
        throw new HttpsError('internal', 'No image returned from Replicate');
      }

      try {
        await logAIUsage(userId, 'replicate_generate_image', {
          provider: 'replicate',
          model: 'flux-schnell',
          inputTokens: 0,
          outputTokens: 0,
          totalTokens: 0,
        });
      } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

      return { imageUrl };
    } catch (error: any) {
      logger.error('Replicate Generate Error', { userId, error: error.message });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError('internal', 'Failed to generate image');
    }
  }
);
