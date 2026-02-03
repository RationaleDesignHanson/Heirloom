/**
 * Brave Search API Gateway
 * Secure proxy for web recipe search requests
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { checkRateLimit, logAIUsage } from './rate-limiter';

// Define secret for Brave Search API key (stored in Google Secret Manager)
const braveSearchKey = defineSecret('BRAVE_SEARCH_API_KEY');

/**
 * Search web for recipes using Brave Search
 * Maps to: WebRecipeSearchService in iOS app
 */
export const braveSearch = onCall({ secrets: [braveSearchKey] }, async (request) => {
  // 1. Verify authentication
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;
  const { query, count } = request.data;

  try {
    // 2. Rate limiting check
    await checkRateLimit(userId, 'brave_search');

    // 3. Validate input
    if (!query || typeof query !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid search query');
    }

    const searchCount = count || 10;
    if (searchCount > 20) {
      throw new HttpsError('invalid-argument', 'Maximum 20 results per request');
    }

    // 4. Get API key from Secret Manager
    const apiKey = braveSearchKey.value();
    if (!apiKey) {
      throw new HttpsError('failed-precondition', 'Brave Search API not configured');
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
      logger.error('Brave Search API Error', { status: response.status, error: errorText });
      throw new HttpsError('internal', 'Brave Search API request failed');
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
    await logAIUsage(userId, 'brave_search', {
      provider: 'brave',
      model: 'search-api-v1',
      inputTokens: 0,
      outputTokens: 0,
      totalTokens: 0,
    });

    return {
      results: searchResults,
      query: result.query?.original || query,
    };
  } catch (error: any) {
    logger.error('Brave Search Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Failed to perform search');
  }
});
