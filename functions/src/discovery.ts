/**
 * Discovery & Public Recipe Functions
 * Algolia search sync, trending scores, view/save counters, moderation
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import algoliasearch from 'algoliasearch';

const db = admin.firestore();

// Algolia clients (lazy-initialized to avoid crash during code analysis)
let usersIndex: ReturnType<ReturnType<typeof algoliasearch>['initIndex']>;
let publicRecipesIndex: ReturnType<ReturnType<typeof algoliasearch>['initIndex']>;

function getAlgoliaIndices() {
  if (!usersIndex || !publicRecipesIndex) {
    const appId = process.env.ALGOLIA_APP_ID || '';
    const adminKey = process.env.ALGOLIA_ADMIN_KEY || '';
    const client = algoliasearch(appId, adminKey);
    usersIndex = client.initIndex('users');
    publicRecipesIndex = client.initIndex('public_recipes');
  }
  return { usersIndex, publicRecipesIndex };
}

// ========================================
// ALGOLIA SYNC: User Profiles
// ========================================

/**
 * Sync user profile to Algolia when profile/data document changes
 * Trigger: users/{userId}/profile/data
 */
export const syncUserToAlgolia = onDocumentWritten(
  'users/{userId}/profile/data',
  async (event) => {
    const userId = event.params.userId;
    const change = event.data;
    if (!change) return null;

    const { usersIndex: idx } = getAlgoliaIndices();

    // Delete from Algolia if document was removed
    if (!change.after.exists) {
      logger.info(`Deleting user ${userId} from Algolia`);
      await idx.deleteObject(userId);
      return null;
    }

    const data = change.after.data();
    if (!data) return null;

    // Don't index if user has hidden their profile from search
    if (data.privacySettings?.hideFromSearch === true) {
      logger.info(`User ${userId} has hideFromSearch=true, removing from Algolia`);
      await idx.deleteObject(userId);
      return null;
    }

    // Prepare Algolia object
    const algoliaObject = {
      objectID: userId,
      displayName: data.displayName || '',
      email: data.email || null,
      photoURL: data.photoURL || null,
      bio: data.bio || null,
      location: data.location || null,
      specialties: data.specialties || [],
      connectionCount: data.connectionCount || 0,
      isVerified: data.isVerified || false,
      updatedAt: admin.firestore.Timestamp.now().seconds,
    };

    logger.info(`Syncing user ${userId} (${data.displayName}) to Algolia`);
    await idx.saveObject(algoliaObject);

    return null;
  }
);

// ========================================
// ALGOLIA SYNC: Public Recipes
// ========================================

/**
 * Sync public recipe to Algolia when document changes
 * Trigger: publicRecipes/{recipeId}
 */
export const syncPublicRecipeToAlgolia = onDocumentWritten(
  'publicRecipes/{recipeId}',
  async (event) => {
    const recipeId = event.params.recipeId;
    const change = event.data;
    if (!change) return null;

    const { publicRecipesIndex: idx } = getAlgoliaIndices();

    // Delete from Algolia if document was removed
    if (!change.after.exists) {
      logger.info(`Deleting public recipe ${recipeId} from Algolia`);
      await idx.deleteObject(recipeId);
      return null;
    }

    const data = change.after.data();
    if (!data) return null;

    // Don't index if recipe is hidden
    if (data.isHidden === true) {
      logger.info(`Recipe ${recipeId} is hidden, removing from Algolia`);
      await idx.deleteObject(recipeId);
      return null;
    }

    // Prepare Algolia object
    const algoliaObject = {
      objectID: recipeId,
      title: data.title || '',
      description: data.description || '',
      ingredients: data.ingredients || [],
      instructions: data.instructions || [],
      tags: data.tags || [],
      category: data.category || null,
      creatorName: data.creatorName || '',
      creatorId: data.ownerId || '',
      creatorPhotoURL: data.creatorPhotoURL || null,
      imageURL: data.imageURL || null,
      viewCount: data.viewCount || 0,
      saveCount: data.saveCount || 0,
      trendingScore: data.trendingScore || 0,
      servings: data.servings || null,
      prepTime: data.prepTime || null,
      cookTime: data.cookTime || null,
      totalTime: data.totalTime || null,
      _searchText: [
        data.title || '',
        data.description || '',
        data.creatorName || '',
        ...(data.ingredients || []),
        ...(data.tags || []),
      ].join(' ').toLowerCase(),
      publishedAt: data.publishedAt ? data.publishedAt.seconds : Date.now() / 1000,
      updatedAt: data.updatedAt ? data.updatedAt.seconds : Date.now() / 1000,
      isDemoSeed: data.isDemoSeed || false,
    };

    logger.info(`Syncing public recipe ${recipeId} (${data.title}) to Algolia`);
    await idx.saveObject(algoliaObject);

    return null;
  }
);

// ========================================
// MODERATION: Auto-hide reported recipes
// ========================================

/**
 * Monitor public recipe reports and auto-hide if threshold reached
 * Trigger: publicRecipeReports/{reportId}
 */
export const monitorPublicRecipeReports = onDocumentWritten(
  'publicRecipeReports/{reportId}',
  async (event) => {
    const reportId = event.params.reportId;
    const change = event.data;
    if (!change) return null;

    // Only process new reports (not updates or deletes)
    if (!change.after.exists || change.before.exists) {
      return null;
    }

    const reportData = change.after.data();
    if (!reportData) return null;

    const publicRecipeId = reportData.publicRecipeId;
    const reporterId = reportData.reporterId;
    const reason = reportData.reason;

    logger.info(`New report received: ${reportId}`, { publicRecipeId, reporterId, reason });

    // Fetch the public recipe to check report count
    const recipeRef = db.collection('publicRecipes').doc(publicRecipeId);
    const recipeDoc = await recipeRef.get();

    if (!recipeDoc.exists) {
      logger.warn(`Public recipe not found: ${publicRecipeId}`);
      return null;
    }

    const recipeData = recipeDoc.data();
    const reportCount = recipeData?.reportCount || 0;

    // Auto-moderation threshold: 3 reports
    const AUTO_HIDE_THRESHOLD = 3;

    if (reportCount >= AUTO_HIDE_THRESHOLD) {
      logger.warn(`Auto-moderation triggered for recipe: ${publicRecipeId} (${reportCount} reports)`);

      // Mark recipe as hidden (soft delete - preserves data for admin review)
      await recipeRef.update({
        isHidden: true,
        hiddenReason: 'auto_moderation',
        hiddenAt: admin.firestore.Timestamp.now(),
        hiddenByReportCount: reportCount,
      });

      logger.info(`Recipe ${publicRecipeId} auto-hidden due to ${reportCount} reports`);
    }

    return null;
  }
);

// ========================================
// TRENDING: Daily score calculation
// ========================================

/**
 * Calculate trending scores for all public recipes
 * Schedule: Daily at 2:00 AM UTC
 */
export const calculateTrendingScores = onSchedule('0 2 * * *', async () => {
  try {
    logger.info('Starting trending score calculation...');

    const recipesSnapshot = await db.collection('publicRecipes').get();

    if (recipesSnapshot.empty) {
      logger.info('No public recipes found');
      return;
    }

    const batch = db.batch();
    let updateCount = 0;
    const now = new Date();

    for (const doc of recipesSnapshot.docs) {
      const data = doc.data();
      const publishedAt = data.publishedAt ? data.publishedAt.toDate() : now;

      // Calculate recency boost (exponential decay)
      const daysSincePublish = (now.getTime() - publishedAt.getTime()) / (1000 * 60 * 60 * 24);
      let recencyBoost = 0;

      if (daysSincePublish <= 2) {
        recencyBoost = 20.0;
      } else if (daysSincePublish <= 7) {
        recencyBoost = 20.0 * Math.exp(-daysSincePublish / 7.0);
      } else if (daysSincePublish <= 30) {
        recencyBoost = 20.0 * Math.exp(-daysSincePublish / 15.0);
      } else {
        recencyBoost = 0.0;
      }

      // Calculate trending score
      const viewCount = data.viewCount || 0;
      const saveCount = data.saveCount || 0;
      const cookCount = data.cookCount || 0;
      const trendingScore = Math.min(
        (viewCount * 0.3) + (saveCount * 5.0) + (cookCount * 2.0) + recencyBoost,
        100.0
      );

      batch.update(doc.ref, {
        trendingScore,
        lastTrendingCalculation: admin.firestore.Timestamp.now(),
      });

      updateCount++;

      // Commit batch every 500 operations (Firestore limit)
      if (updateCount % 500 === 0) {
        await batch.commit();
        logger.info(`Committed batch of 500 updates (total: ${updateCount})`);
      }
    }

    // Commit remaining updates
    if (updateCount % 500 !== 0) {
      await batch.commit();
    }

    logger.info(`Trending score calculation complete. Updated ${updateCount} recipes.`);
  } catch (error) {
    logger.error('Error calculating trending scores:', error);
    throw error;
  }
});

// ========================================
// COUNTERS: View & Save increments
// ========================================

/**
 * Increment view count for a public recipe (with per-user rate limiting)
 */
export const incrementPublicRecipeView = onCall(async (request) => {
  try {
    const { recipeId } = request.data;

    if (!recipeId || typeof recipeId !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid recipeId parameter');
    }

    const recipeRef = db.collection('publicRecipes').doc(recipeId);

    // Rate-limited view increment wrapped in a transaction to prevent
    // concurrent requests from bypassing the per-user 24-hour cooldown.
    const result = await db.runTransaction(async (transaction) => {
      const recipeSnap = await transaction.get(recipeRef);
      if (!recipeSnap.exists) {
        throw new HttpsError('not-found', 'Public recipe not found');
      }

      if (request.auth) {
        const userId = request.auth.uid;
        const rateLimitRef = recipeRef.collection('viewRateLimits').doc(userId);
        const rateLimitDoc = await transaction.get(rateLimitRef);

        if (rateLimitDoc.exists) {
          const lastView = rateLimitDoc.data()?.lastView?.toMillis();
          if (lastView) {
            const hoursSinceLastView = (Date.now() - lastView) / (1000 * 60 * 60);

            if (hoursSinceLastView < 24) {
              return {
                success: true as const,
                viewCount: recipeSnap.data()?.viewCount || 0,
                rateLimited: true as const,
              };
            }
          }
        }

        transaction.set(rateLimitRef, { lastView: admin.firestore.Timestamp.now() }, { merge: true });
      }

      transaction.update(recipeRef, {
        viewCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.Timestamp.now(),
      });

      return {
        success: true as const,
        viewCount: (recipeSnap.data()?.viewCount || 0) + 1,
        rateLimited: false as const,
      };
    });

    if (!result.rateLimited) {
      logger.info(`Incremented view count for recipe ${recipeId} to ${result.viewCount}`);
    }

    return result;
  } catch (error: any) {
    logger.error('Error incrementing view count:', error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'Failed to increment view count');
  }
});

/**
 * Increment save count for a public recipe (requires authentication)
 */
export const incrementPublicRecipeSave = onCall(async (request) => {
  try {
    const { recipeId } = request.data;

    if (!recipeId || typeof recipeId !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid recipeId parameter');
    }

    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required to save recipes');
    }

    const recipeRef = db.collection('publicRecipes').doc(recipeId);
    const recipeDoc = await recipeRef.get();

    if (!recipeDoc.exists) {
      throw new HttpsError('not-found', 'Public recipe not found');
    }

    // Atomically increment save count
    await recipeRef.update({
      saveCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.Timestamp.now(),
    });

    const updatedDoc = await recipeRef.get();
    const newSaveCount = updatedDoc.data()?.saveCount || 0;

    logger.info(`Incremented save count for recipe ${recipeId} to ${newSaveCount} by user ${request.auth.uid}`);

    return { success: true, saveCount: newSaveCount };
  } catch (error: any) {
    logger.error('Error incrementing save count:', error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError('internal', 'Failed to increment save count');
  }
});
