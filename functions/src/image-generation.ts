/**
 * Image Generation Gateway
 * Secure proxy for DALL-E 3 and Replicate image generation
 */

import * as functions from 'firebase-functions';
import OpenAI from 'openai';
import { checkRateLimit, logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_KEY,
});

const getReplicateToken = (): string => {
  return functions.config().replicate?.api_token || process.env.REPLICATE_API_TOKEN || '';
};

/**
 * Generate an image using OpenAI DALL-E 3
 * Maps to: FirebaseImageGenerationService.generateWithDALLE() in iOS app
 */
export const dalleGenerateImage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = context.auth.uid;

  try {
    await checkRateLimit(userId, 'image_generation');

    const { prompt, size, quality } = data;

    if (!prompt || typeof prompt !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid prompt');
    }

    const imageSize = size || '1792x1024';
    const imageQuality = quality || 'standard';

    const response = await openai.images.generate({
      model: 'dall-e-3',
      prompt,
      size: imageSize as '1024x1024' | '1792x1024' | '1024x1792',
      quality: imageQuality as 'standard' | 'hd',
      n: 1,
    });

    const imageUrl = response.data?.[0]?.url;
    const revisedPrompt = response.data?.[0]?.revised_prompt;

    if (!imageUrl) {
      throw new functions.https.HttpsError('internal', 'No image returned from DALL-E');
    }

    try {
      await logAIUsage(userId, 'dalle_generate_image', {
        provider: 'openai',
        model: 'dall-e-3',
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
      });
    } catch (e) { functions.logger.warn('logAIUsage failed', { error: e }); }

    return {
      imageUrl,
      revisedPrompt: revisedPrompt || prompt,
    };
  } catch (error: any) {
    functions.logger.error('DALL-E Generate Error', { userId, error: error.message });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    if (error.status === 429) {
      throw new functions.https.HttpsError('resource-exhausted', 'OpenAI rate limit exceeded');
    }
    if (error.status === 400) {
      throw new functions.https.HttpsError('invalid-argument', error.message || 'Invalid request to DALL-E');
    }

    throw new functions.https.HttpsError('internal', 'Failed to generate image');
  }
});

/**
 * Generate an image using Replicate (Flux model)
 * Maps to: FirebaseImageGenerationService.generateWithReplicate() in iOS app
 */
export const replicateGenerateImage = functions
  .runWith({ timeoutSeconds: 120 })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }
    if (ENFORCE_APP_CHECK && !context.app) {
      throw new functions.https.HttpsError('failed-precondition', 'App Check verification failed.');
    }

    const userId = context.auth.uid;

    try {
      await checkRateLimit(userId, 'image_generation');

      const { prompt, aspectRatio, outputFormat, outputQuality } = data;

      if (!prompt || typeof prompt !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid prompt');
      }

      const token = getReplicateToken();
      if (!token) {
        throw new functions.https.HttpsError('failed-precondition', 'Replicate API not configured');
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
        functions.logger.error('Replicate API Error', { status: createResponse.status, error: errorText });

        if (createResponse.status === 429) {
          throw new functions.https.HttpsError('resource-exhausted', 'Replicate rate limit exceeded');
        }
        throw new functions.https.HttpsError('internal', 'Replicate API request failed');
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
        functions.logger.error('Replicate prediction failed', { error: prediction.error });
        throw new functions.https.HttpsError('internal', 'Image generation failed');
      }

      if (prediction.status !== 'succeeded') {
        throw new functions.https.HttpsError('deadline-exceeded', 'Image generation timed out');
      }

      // Flux returns output as an array of URLs or a single URL
      const output = prediction.output;
      const imageUrl = Array.isArray(output) ? output[0] : output;

      if (!imageUrl) {
        throw new functions.https.HttpsError('internal', 'No image returned from Replicate');
      }

      try {
        await logAIUsage(userId, 'replicate_generate_image', {
          provider: 'replicate',
          model: 'flux-schnell',
          inputTokens: 0,
          outputTokens: 0,
          totalTokens: 0,
        });
      } catch (e) { functions.logger.warn('logAIUsage failed', { error: e }); }

      return { imageUrl };
    } catch (error: any) {
      functions.logger.error('Replicate Generate Error', { userId, error: error.message });

      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      throw new functions.https.HttpsError('internal', 'Failed to generate image');
    }
  });
