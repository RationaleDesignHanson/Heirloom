/**
 * Brave Search API Gateway
 * Secure proxy for web recipe search requests
 */

import * as functions from 'firebase-functions';
import { checkRateLimit, logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

const getBraveSearchKey = (): string => {
  return functions.config().brave?.search_key || process.env.BRAVE_SEARCH_KEY || '';
};

/**
 * Search web for recipes using Brave Search
 * Maps to: WebRecipeSearchService in iOS app
 */
export const braveSearch = functions.https.onCall(async (data, context) => {
  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !context.app) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = context.auth.uid;

  try {
    // 2. Rate limiting check
    await checkRateLimit(userId, 'brave_search');

    // 3. Validate input
    const { query, count } = data;

    if (!query || typeof query !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid search query');
    }

    const searchCount = count || 10;
    if (searchCount > 20) {
      throw new functions.https.HttpsError('invalid-argument', 'Maximum 20 results per request');
    }

    // 4. Get API key
    const apiKey = getBraveSearchKey();
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Brave Search API not configured');
    }

    // 5. Call Brave Search API
    const url = new URL('https://api.search.brave.com/res/v1/web/search');
    url.searchParams.set('q', query);
    url.searchParams.set('count', searchCount.toString());
    url.searchParams.set('safesearch', 'moderate');

    const response = await fetch(url.toString(), {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'X-Subscription-Token': apiKey,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      functions.logger.error('Brave Search API Error', { status: response.status, error: errorText });
      throw new functions.https.HttpsError('internal', 'Brave Search API request failed');
    }

    const result = await response.json();

    // 6. Extract results
    const webResults = result.web?.results || [];
    const searchResults = webResults.map((item: any) => ({
      title: item.title,
      url: item.url,
      description: item.description,
      age: item.age,
      language: item.language,
    }));

    // 7. Log usage
    try {
      await logAIUsage(userId, 'brave_search', {
        provider: 'brave',
        model: 'search-api-v1',
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
      });
    } catch (e) { functions.logger.warn('logAIUsage failed', { error: e }); }

    return {
      results: searchResults,
      query: result.query?.original || query,
    };
  } catch (error: any) {
    functions.logger.error('Brave Search Error', { userId, error: error.message });

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError('internal', 'Failed to perform search');
  }
});
