/**
 * Firebase Cloud Functions - API Gateway
 * Secure proxy for all external API requests
 *
 * Setup:
 * 1. cd functions
 * 2. npm install
 * 3. firebase functions:config:set \
 *      anthropic.key="sk-ant-..." \
 *      openai.key="sk-proj-..." \
 *      google.vision_key="..." \
 *      brave.search_key="..."
 * 4. firebase deploy --only functions
 */

import * as admin from 'firebase-admin';

admin.initializeApp();

// Export AI gateway functions
export { aiComplete, aiCompleteStructured, aiCompleteWithVision } from './ai-gateway';

// Export Google Vision functions
export { googleVisionOCR } from './google-vision';

// Export Brave Search functions
export { braveSearch } from './brave-search';

// Export image generation functions
export { dalleGenerateImage, replicateGenerateImage } from './image-generation';

// Export restyle functions
export { createRestyleJob, processRestyleQueue, applyRestyleResults, refundRestyleCredits } from './restyle';

// Export OG profile function (hosting rewrite: /u/** -> ogProfile)
export { ogProfile } from './ogProfile';

// Export discovery & public recipe functions
export {
  syncUserToAlgolia,
  syncPublicRecipeToAlgolia,
  monitorPublicRecipeReports,
  calculateTrendingScores,
  incrementPublicRecipeView,
  incrementPublicRecipeSave,
} from './discovery';

// Export utility functions
export { checkUserRateLimit, getUserUsageStats } from './rate-limiter';
