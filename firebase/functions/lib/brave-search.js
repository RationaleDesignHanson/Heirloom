"use strict";
/**
 * Brave Search API Gateway
 * Secure proxy for web recipe search requests
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.braveSearch = void 0;
const https_1 = require("firebase-functions/v2/https");
const firebase_functions_1 = require("firebase-functions");
const params_1 = require("firebase-functions/params");
const rate_limiter_1 = require("./rate-limiter");
// Define secret for Brave Search API key (stored in Google Secret Manager)
const braveSearchKey = (0, params_1.defineSecret)('BRAVE_SEARCH_API_KEY');
/**
 * Search web for recipes using Brave Search
 * Maps to: WebRecipeSearchService in iOS app
 */
exports.braveSearch = (0, https_1.onCall)({ secrets: [braveSearchKey] }, async (request) => {
    var _a, _b;
    // 1. Verify authentication
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Must be logged in');
    }
    const userId = request.auth.uid;
    const { query, count } = request.data;
    try {
        // 2. Rate limiting check
        await (0, rate_limiter_1.checkRateLimit)(userId, 'brave_search');
        // 3. Validate input
        if (!query || typeof query !== 'string') {
            throw new https_1.HttpsError('invalid-argument', 'Invalid search query');
        }
        const searchCount = count || 10;
        if (searchCount > 20) {
            throw new https_1.HttpsError('invalid-argument', 'Maximum 20 results per request');
        }
        // 4. Get API key from Secret Manager
        const apiKey = braveSearchKey.value();
        if (!apiKey) {
            throw new https_1.HttpsError('failed-precondition', 'Brave Search API not configured');
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
            firebase_functions_1.logger.error('Brave Search API Error', { status: response.status, error: errorText });
            throw new https_1.HttpsError('internal', 'Brave Search API request failed');
        }
        const result = await response.json();
        // 6. Extract results
        const webResults = ((_a = result.web) === null || _a === void 0 ? void 0 : _a.results) || [];
        const searchResults = webResults.map((item) => ({
            title: item.title,
            url: item.url,
            description: item.description,
            age: item.age,
            language: item.language,
        }));
        // 7. Log usage
        await (0, rate_limiter_1.logAIUsage)(userId, 'brave_search', {
            provider: 'brave',
            model: 'search-api-v1',
            inputTokens: 0,
            outputTokens: 0,
            totalTokens: 0,
        });
        return {
            results: searchResults,
            query: ((_b = result.query) === null || _b === void 0 ? void 0 : _b.original) || query,
        };
    }
    catch (error) {
        firebase_functions_1.logger.error('Brave Search Error', { userId, error: error.message });
        if (error instanceof https_1.HttpsError) {
            throw error;
        }
        throw new https_1.HttpsError('internal', 'Failed to perform search');
    }
});
//# sourceMappingURL=brave-search.js.map