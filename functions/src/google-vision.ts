/**
 * Google Vision API Gateway
 * Secure proxy for handwriting OCR requests
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { checkRateLimit, logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

const getGoogleVisionKey = (): string => {
  return process.env.GOOGLE_VISION_KEY || '';
};

/**
 * Google Vision OCR for handwritten recipes
 * Maps to: GoogleVisionService in iOS app
 */
export const googleVisionOCR = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    // 2. Rate limiting check
    await checkRateLimit(userId, 'google_vision');

    // 3. Validate input
    const { imageBase64 } = request.data;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid image data');
    }

    // 4. Get API key
    const apiKey = getGoogleVisionKey();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'Google Vision API not configured');
    }

    // 5. Call Google Vision API
    const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        requests: [
          {
            image: {
              content: imageBase64,
            },
            features: [
              {
                type: 'DOCUMENT_TEXT_DETECTION',
                maxResults: 1,
              },
            ],
            imageContext: {
              languageHints: ['en'],
            },
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      logger.error('Google Vision API Error', { status: response.status, error: errorText });

      if (response.status === 429) {
        throw new HttpsError('resource-exhausted', 'Google Vision API quota exceeded');
      }
      if (response.status === 400) {
        throw new HttpsError('invalid-argument', 'Invalid image data for OCR');
      }

      throw new HttpsError('internal', 'Google Vision API request failed');
    }

    const result = await response.json();

    // 6. Extract text
    const textAnnotations = result.responses?.[0]?.textAnnotations;
    const fullText = textAnnotations?.[0]?.description || '';

    // 7. Log usage (estimate cost - $1.50 per 1000 images)
    try {
      await logAIUsage(userId, 'google_vision_ocr', {
        provider: 'google',
        model: 'vision-api-v1',
        inputTokens: 0, // Not token-based
        outputTokens: 0,
        totalTokens: 0,
      });
    } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

    return {
      text: fullText,
      confidence: textAnnotations?.[0]?.confidence || 0,
      locale: result.responses?.[0]?.textAnnotations?.[0]?.locale,
    };
  } catch (error: any) {
    logger.error('Google Vision OCR Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Failed to process OCR request');
  }
});
