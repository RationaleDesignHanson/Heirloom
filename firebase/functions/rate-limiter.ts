/**
 * Rate Limiter - Prevent abuse and control costs
 * Uses Firestore for distributed rate limiting
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// Rate limits per operation type
const RATE_LIMITS = {
  ai_complete: { limit: 500, windowMs: 24 * 60 * 60 * 1000 }, // 500 per day (increased for development)
  ai_vision: { limit: 200, windowMs: 24 * 60 * 60 * 1000 }, // 200 per day (increased for cookbook testing)
  google_vision: { limit: 500, windowMs: 24 * 60 * 60 * 1000 }, // 500 OCR per day (increased for development)
  brave_search: { limit: 500, windowMs: 24 * 60 * 60 * 1000 }, // 500 searches per day (increased for development)
};

/**
 * Check if user has exceeded rate limit for an operation
 * @throws HttpsError if rate limit exceeded
 */
export async function checkRateLimit(userId: string, operation: keyof typeof RATE_LIMITS): Promise<void> {
  const config = RATE_LIMITS[operation];
  if (!config) {
    logger.warn('Unknown operation for rate limiting', { operation });
    return;
  }

  const key = `${userId}:${operation}`;
  const now = Date.now();

  const docRef = db.collection('rateLimits').doc(key);
  const doc = await docRef.get();
  const data = doc.data();

  // Check if limit exceeded
  if (data && data.count >= config.limit && data.resetAt) {
    const resetAt = data.resetAt.toMillis();
    if (now < resetAt) {
      const hoursUntilReset = Math.ceil((resetAt - now) / (60 * 60 * 1000));

      logger.warn('Rate limit exceeded', { userId, operation, count: data.count, limit: config.limit });

      throw new HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. You can make ${config.limit} ${operation} requests per day. Try again in ${hoursUntilReset} hours.`
      );
    }
  }

  // Increment or reset counter
  if (!data || !data.resetAt || now >= data.resetAt.toMillis()) {
    // Start new window
    await docRef.set({
      count: 1,
      resetAt: new Date(now + config.windowMs),
      lastRequest: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    // Increment existing window
    await docRef.update({
      count: admin.firestore.FieldValue.increment(1),
      lastRequest: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Log AI usage for billing/analytics
 */
export async function logAIUsage(
  userId: string,
  operation: string,
  data: {
    provider: string;
    model: string;
    inputTokens: number;
    outputTokens: number;
    totalTokens: number;
  }
): Promise<void> {
  // Calculate cost
  const cost = calculateCost(data.provider, data.model, data.inputTokens, data.outputTokens);

  // Log to aiUsage collection
  await db.collection('aiUsage').add({
    userId,
    operation,
    provider: data.provider,
    model: data.model,
    inputTokens: data.inputTokens,
    outputTokens: data.outputTokens,
    totalTokens: data.totalTokens,
    cost,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Update user's total cost
  const userCostRef = db.collection('userCosts').doc(userId);
  await userCostRef.set(
    {
      totalCost: admin.firestore.FieldValue.increment(cost),
      totalTokens: admin.firestore.FieldValue.increment(data.totalTokens),
      operations: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  logger.info('AI usage logged', { userId, operation, cost, tokens: data.totalTokens });
}

/**
 * Calculate cost based on provider and model
 */
function calculateCost(provider: string, model: string, inputTokens: number, outputTokens: number): number {
  // Pricing as of Jan 2025 (per 1M tokens)
  let inputCostPer1M = 0;
  let outputCostPer1M = 0;

  if (provider === 'anthropic') {
    if (model.includes('haiku')) {
      inputCostPer1M = 0.25;
      outputCostPer1M = 1.25;
    } else if (model.includes('sonnet')) {
      inputCostPer1M = 3.0;
      outputCostPer1M = 15.0;
    } else if (model.includes('opus')) {
      inputCostPer1M = 15.0;
      outputCostPer1M = 75.0;
    } else {
      // Default to Haiku pricing
      inputCostPer1M = 0.25;
      outputCostPer1M = 1.25;
    }
  } else if (provider === 'openai') {
    if (model.includes('gpt-4o-mini')) {
      inputCostPer1M = 0.15;
      outputCostPer1M = 0.6;
    } else if (model.includes('gpt-4o')) {
      inputCostPer1M = 2.5;
      outputCostPer1M = 10.0;
    } else if (model.includes('gpt-4')) {
      inputCostPer1M = 30.0;
      outputCostPer1M = 60.0;
    } else {
      // Default to GPT-4o-mini pricing
      inputCostPer1M = 0.15;
      outputCostPer1M = 0.6;
    }
  }

  const inputCost = (inputTokens / 1_000_000) * inputCostPer1M;
  const outputCost = (outputTokens / 1_000_000) * outputCostPer1M;

  return inputCost + outputCost;
}

/**
 * Get user's rate limit status (for debugging/monitoring)
 */
export const checkUserRateLimit = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;
  const { operation } = request.data;

  if (!operation || !RATE_LIMITS[operation as keyof typeof RATE_LIMITS]) {
    throw new HttpsError('invalid-argument', 'Invalid operation');
  }

  const key = `${userId}:${operation}`;
  const docRef = db.collection('rateLimits').doc(key);
  const doc = await docRef.get();

  if (!doc.exists) {
    const config = RATE_LIMITS[operation as keyof typeof RATE_LIMITS];
    return {
      count: 0,
      limit: config.limit,
      remaining: config.limit,
      resetAt: null,
    };
  }

  const data = doc.data();
  const config = RATE_LIMITS[operation as keyof typeof RATE_LIMITS];

  return {
    count: data?.count || 0,
    limit: config.limit,
    remaining: Math.max(0, config.limit - (data?.count || 0)),
    resetAt: data?.resetAt?.toDate?.() || null,
  };
});

/**
 * Get user's AI usage statistics
 */
export const getUserUsageStats = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = request.auth.uid;

  const userCostRef = db.collection('userCosts').doc(userId);
  const doc = await userCostRef.get();

  if (!doc.exists) {
    return {
      totalCost: 0,
      totalTokens: 0,
      operations: 0,
      lastUpdated: null,
    };
  }

  const data = doc.data();

  return {
    totalCost: data?.totalCost || 0,
    totalTokens: data?.totalTokens || 0,
    operations: data?.operations || 0,
    lastUpdated: data?.lastUpdated?.toDate?.() || null,
  };
});
