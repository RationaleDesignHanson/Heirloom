/**
 * Restyle Backend Infrastructure
 * Cloud Functions for batch recipe image restyling with credit transactions
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import { logAIUsage } from './rate-limiter';

const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

const db = admin.firestore();

const MAX_RESTYLE_RECIPES = 500;

/**
 * Create a restyle job — validates credits and atomically deducts them
 * Maps to: RestyleService.createJob() in iOS app
 */
export const createRestyleJob = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    const { recipeIds, stylePreset } = request.data;

    if (!recipeIds || !Array.isArray(recipeIds) || recipeIds.length === 0) {
      throw new HttpsError('invalid-argument', 'recipeIds must be a non-empty array');
    }

    if (recipeIds.length > MAX_RESTYLE_RECIPES) {
      throw new HttpsError(
        'invalid-argument',
        `Cannot restyle more than ${MAX_RESTYLE_RECIPES} recipes at once`
      );
    }

    if (!stylePreset || typeof stylePreset !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid stylePreset');
    }

    const creditsRequired = recipeIds.length;
    const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');
    const jobId = db.collection('users').doc(userId).collection('restyleJobs').doc().id;
    const jobRef = db.collection('users').doc(userId).collection('restyleJobs').doc(jobId);

    const creditsRemaining = await db.runTransaction(async (transaction) => {
      const creditsDoc = await transaction.get(creditsRef);
      const currentCredits = creditsDoc.data()?.balance ?? 0;

      if (currentCredits < creditsRequired) {
        throw new HttpsError(
          'failed-precondition',
          `Not enough credits. Required: ${creditsRequired}, available: ${currentCredits}`
        );
      }

      const newBalance = currentCredits - creditsRequired;

      transaction.set(creditsRef, {
        balance: newBalance,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.set(jobRef, {
        status: 'pending',
        recipeIds,
        stylePreset,
        creditsCharged: creditsRequired,
        totalRecipes: recipeIds.length,
        processedRecipes: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return newBalance;
    });

    try {
      await logAIUsage(userId, 'restyle_create_job', {
        provider: 'internal',
        model: stylePreset,
        inputTokens: 0,
        outputTokens: 0,
        totalTokens: 0,
      });
    } catch (e) { logger.warn('logAIUsage failed', { error: e }); }

    return { jobId, creditsRemaining };
  } catch (error: any) {
    logger.error('Create Restyle Job Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Failed to create restyle job');
  }
});

/**
 * Process restyle queue — triggered when a new restyle job is created
 * TODO: Full implementation in Stage 12 — will call image generation APIs
 */
export const processRestyleQueue = onDocumentCreated(
  'users/{userId}/restyleJobs/{jobId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const { userId, jobId } = event.params;
    const jobRef = snapshot.ref;

    try {
      // Set status to processing
      await jobRef.update({
        status: 'processing',
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const jobData = snapshot.data();
      const totalRecipes = jobData.recipeIds?.length ?? 0;

      // TODO: Full implementation in Stage 12 — will call image generation APIs
      // For each recipe:
      //   1. Generate styled image via dalleGenerateImage or replicateGenerateImage
      //   2. Upload to users/{userId}/restyle-staging/{jobId}/{recipeId}.jpg
      //   3. Update processedRecipes count on job doc

      // Stub: mark as completed
      await jobRef.update({
        status: 'completed',
        processedRecipes: totalRecipes,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info('Restyle job completed (stub)', { userId, jobId, totalRecipes });
    } catch (error: any) {
      logger.error('Process Restyle Queue Error', { userId, jobId, error: error.message });

      // Auto-refund credits on failure via atomic transaction
      try {
        const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');
        await db.runTransaction(async (transaction) => {
          const jobDoc = await transaction.get(jobRef);
          const jobData = jobDoc.data();
          const creditsCharged = jobData?.creditsCharged ?? 0;

          if (creditsCharged > 0) {
            const creditsDoc = await transaction.get(creditsRef);
            const currentBalance = creditsDoc.data()?.balance ?? 0;

            transaction.set(creditsRef, {
              balance: currentBalance + creditsCharged,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
          }

          transaction.update(jobRef, {
            status: 'refunded',
            error: error.message || 'Processing failed',
            refundedCredits: creditsCharged > 0 ? creditsCharged : 0,
            refundedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        logger.info('Auto-refunded credits for failed restyle job', { userId, jobId });
      } catch (refundError: any) {
        logger.error('Failed to auto-refund credits — manual refund needed', { userId, jobId, error: refundError.message });
        // Still mark the job as failed even if refund fails
        await jobRef.update({
          status: 'failed',
          error: error.message || 'Processing failed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }
  }
);

/**
 * Apply restyle results — swaps staged images into recipes
 * TODO: Full implementation will atomic-swap staged images into recipes
 */
export const applyRestyleResults = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    const { jobId } = request.data;

    if (!jobId || typeof jobId !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid jobId');
    }

    const jobRef = db.collection('users').doc(userId).collection('restyleJobs').doc(jobId);
    const jobDoc = await jobRef.get();

    if (!jobDoc.exists) {
      throw new HttpsError('not-found', 'Restyle job not found');
    }

    const jobData = jobDoc.data();

    if (jobData?.status !== 'completed') {
      throw new HttpsError(
        'failed-precondition',
        `Cannot apply results for job with status: ${jobData?.status}`
      );
    }

    // TODO: Full implementation will atomic-swap staged images into recipes
    // For each recipe in job:
    //   1. Copy from restyle-staging/{jobId}/{recipeId}.jpg to recipe image path
    //   2. Update recipe doc with new image URL
    //   3. Clean up staging files

    await jobRef.update({
      status: 'applied',
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info('Restyle results applied (stub)', { userId, jobId });

    return { success: true };
  } catch (error: any) {
    logger.error('Apply Restyle Results Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Failed to apply restyle results');
  }
});

/**
 * Refund credits for a failed restyle job
 */
export const refundRestyleCredits = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Must be logged in');
  }
  if (ENFORCE_APP_CHECK && !request.app) {
    throw new HttpsError('failed-precondition', 'App Check verification failed.');
  }

  const userId = request.auth.uid;

  try {
    const { jobId } = request.data;

    if (!jobId || typeof jobId !== 'string') {
      throw new HttpsError('invalid-argument', 'Invalid jobId');
    }

    const jobRef = db.collection('users').doc(userId).collection('restyleJobs').doc(jobId);
    const creditsRef = db.collection('users').doc(userId).collection('credits').doc('balance');

    await db.runTransaction(async (transaction) => {
      const jobDoc = await transaction.get(jobRef);

      if (!jobDoc.exists) {
        throw new HttpsError('not-found', 'Restyle job not found');
      }

      const jobData = jobDoc.data();

      if (jobData?.status === 'refunded') {
        throw new HttpsError(
          'failed-precondition',
          'Credits have already been refunded for this job'
        );
      }

      if (jobData?.status !== 'failed') {
        throw new HttpsError(
          'failed-precondition',
          `Can only refund failed jobs. Current status: ${jobData?.status}`
        );
      }

      const creditsToRefund = jobData.creditsCharged ?? 0;

      if (creditsToRefund <= 0) {
        throw new HttpsError('failed-precondition', 'No credits to refund');
      }

      const creditsDoc = await transaction.get(creditsRef);
      const currentBalance = creditsDoc.data()?.balance ?? 0;

      transaction.set(creditsRef, {
        balance: currentBalance + creditsToRefund,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      transaction.update(jobRef, {
        status: 'refunded',
        refundedCredits: creditsToRefund,
        refundedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    logger.info('Restyle credits refunded', { userId, jobId });

    return { success: true };
  } catch (error: any) {
    logger.error('Refund Restyle Credits Error', { userId, error: error.message });

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError('internal', 'Failed to refund credits');
  }
});
