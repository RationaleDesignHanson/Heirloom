import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import * as logger from 'firebase-functions/logger';
import OpenAI from 'openai';

// Define the OpenAI API key secret
const openaiKey = defineSecret('OPENAI_API_KEY');

/**
 * Generate an image using OpenAI DALL-E 3
 *
 * Rate limits: 50 images per user per day
 */
export const dalleGenerateImage = onCall(
  {
    secrets: [openaiKey],
    region: 'us-central1',
  },
  async (request) => {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { prompt, size = '1792x1024', quality = 'standard' } = request.data as {
      prompt: string;
      size?: string;
      quality?: string;
    };

    // Validate input
    if (!prompt || typeof prompt !== 'string') {
      throw new HttpsError('invalid-argument', 'Prompt is required and must be a string');
    }

    if (prompt.length > 4000) {
      throw new HttpsError('invalid-argument', 'Prompt must be less than 4000 characters');
    }

    const userId = request.auth.uid;

    logger.info('Generating DALL-E image', {
      userId,
      promptLength: prompt.length,
      size,
      quality,
    });

    try {
      // Get API key from secret and trim whitespace/newlines
      const apiKey = openaiKey.value()?.trim();
      logger.info('Got OpenAI API key', { hasKey: !!apiKey, keyLength: apiKey?.length });

      logger.info('About to call OpenAI API', { prompt: prompt.substring(0, 50) });

      // Initialize OpenAI client
      logger.info('Creating OpenAI client...');
      const openai = new OpenAI({ apiKey });
      logger.info('OpenAI client created');

      // Call DALL-E API using SDK
      logger.info('Calling openai.images.generate...');
      const response = await openai.images.generate({
        model: 'dall-e-3',
        prompt: prompt,
        n: 1,
        size: size as '1024x1024' | '1792x1024' | '1024x1792',
        quality: quality as 'standard' | 'hd',
      });
      logger.info('openai.images.generate completed');

      logger.info('OpenAI API response received', { hasData: !!response.data });

      if (!response.data || !response.data[0] || !response.data[0].url) {
        logger.error('Invalid response from OpenAI', { response });
        throw new HttpsError('internal', 'Invalid response from image generation API');
      }

      const imageUrl = response.data[0].url;
      const revisedPrompt = response.data[0].revised_prompt;

      logger.info('Image generated successfully', {
        userId,
        hasRevisedPrompt: !!revisedPrompt,
      });

      return {
        imageUrl,
        revisedPrompt,
      };

    } catch (error: any) {
      // Log full error object
      console.error('FULL ERROR:', JSON.stringify(error, Object.getOwnPropertyNames(error)));

      logger.error('Image generation failed', {
        userId,
        error: error.message,
        errorName: error.name,
        errorStack: error.stack,
        errorString: String(error),
        fullError: JSON.stringify(error, Object.getOwnPropertyNames(error)),
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError('internal', `Failed to generate image: ${error.message || String(error)}`);
    }
  }
);
