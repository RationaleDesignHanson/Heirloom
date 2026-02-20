/**
 * Heirloom Cloud Functions
 * Recipe import and analytics endpoints
 */

import {onRequest, Request} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import * as functionsV1 from 'firebase-functions/v1';
import {Response} from 'express';
import * as admin from 'firebase-admin';
import {UserRecord} from 'firebase-admin/auth';
import {RecipeImporter} from './services/recipeImporter';
import {AnalyticsService} from './services/analyticsService';
import {URLShortenerService} from './services/urlShortenerService';
import {LanguageService} from './services/languageService';
import {DeletionTestSeeder} from './services/deletionTestSeeder';
import {
  ImportRequest,
  FeedbackRequest,
  ShortenURLRequest,
  DetectLanguageRequest,
  TranslateTextRequest,
} from './types';

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const analyticsService = new AnalyticsService(db);
const recipeImporter = new RecipeImporter(analyticsService);
const urlShortener = new URLShortenerService(db);

// Initialize language service (API key from environment variable)
const claudeApiKey = process.env.CLAUDE_API_KEY || '';
const languageService = new LanguageService(claudeApiKey);

// Initialize deletion test seeder
const deletionTestSeeder = new DeletionTestSeeder(db);

/**
 * Main recipe import endpoint
 * POST /importRecipe
 * Body: { url: string, userId?: string }
 */
export const importRecipe = onRequest(
    {
      timeoutSeconds: 60,
      memory: '512MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      try {
        const requestBody = req.body as ImportRequest;

        if (!requestBody || !requestBody.url) {
          res.status(400).json({
            error: 'Missing required field: url',
          });
          return;
        }

        console.log(`📥 Import request for: ${requestBody.url}`);

        // Import the recipe
        const result = await recipeImporter.import(
            requestBody.url,
            requestBody.userId
        );

        console.log(`✅ Import ${result.status}: ${result.importId}`);

        res.status(200).json(result);
      } catch (error: any) {
        console.error('❌ Import error:', error);
        res.status(500).json({
          error: 'Internal server error',
          message: error.message,
        });
      }
    }
);

/**
 * Submit user feedback endpoint
 * POST /submitFeedback
 * Body: FeedbackRequest
 */
export const submitFeedback = onRequest(
    {
      timeoutSeconds: 30,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      try {
        const feedback = req.body as FeedbackRequest;

        if (!feedback || !feedback.importId) {
          res.status(400).json({
            error: 'Missing required field: importId',
          });
          return;
        }

        console.log(`📝 Feedback for import: ${feedback.importId}`);

        await analyticsService.storeFeedback(
            feedback.importId,
            feedback.userId,
            feedback.wasAccurate,
            feedback.corrections,
            feedback.rating,
            feedback.comment
        );

        res.status(200).json({
          success: true,
          message: 'Feedback received',
        });
      } catch (error: any) {
        console.error('❌ Feedback error:', error);
        res.status(500).json({
          error: 'Internal server error',
          message: error.message,
        });
      }
    }
);

/**
 * Get import statistics
 * GET /getStats
 */
export const getStats = onRequest(
    {
      timeoutSeconds: 30,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      try {
        const stats = await analyticsService.getStats();
        res.status(200).json(stats);
      } catch (error: any) {
        console.error('❌ Stats error:', error);
        res.status(500).json({
          error: 'Internal server error',
          message: error.message,
        });
      }
    }
);

/**
 * Scheduled function: Update site patterns
 * Runs every 6 hours
 */
export const updateSitePatterns = onSchedule(
    {
      schedule: 'every 6 hours',
      timeoutSeconds: 300,
      memory: '512MiB',
    },
    async () => {
      console.log('🔄 Updating site patterns...');

      try {
        // Get all site patterns
        const patterns = await db.collection('site_patterns').get();

        console.log(`📊 Analyzed ${patterns.size} site patterns`);

        // TODO: Implement pattern learning algorithm
        // For now, just log stats
        patterns.docs.forEach((doc) => {
          const data = doc.data();
          console.log(
              `  ${doc.id}: ${(data.successRate * 100).toFixed(1)}% success (${data.totalAttempts} attempts)`
          );
        });
      } catch (error) {
        console.error('❌ Error updating site patterns:', error);
        throw error;
      }
    }
);

/**
 * Shorten URL endpoint
 * POST /shortenURL
 * Body: { url: string, customCode?: string, recipeId?: string, userId?: string }
 */
export const shortenURL = onRequest(
    {
      timeoutSeconds: 30,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      try {
        const requestBody = req.body as ShortenURLRequest;

        if (!requestBody || !requestBody.url) {
          res.status(400).json({
            success: false,
            error: 'Missing required field: url',
          });
          return;
        }

        console.log(`🔗 Shortening URL for user: ${requestBody.userId || 'anonymous'}`);

        const result = await urlShortener.shortenURL(
            requestBody.url,
            requestBody.customCode,
            requestBody.recipeId,
            requestBody.userId
        );

        res.status(200).json({
          success: true,
          shortUrl: result.shortUrl,
          code: result.code,
          longUrl: requestBody.url,
        });
      } catch (error: any) {
        console.error('❌ Shortening error:', error);
        res.status(500).json({
          success: false,
          error: error.message || 'Failed to shorten URL',
        });
      }
    }
);

/**
 * Expand/redirect endpoint
 * GET /r/:code
 * Redirects to the original CloudKit URL
 */
export const expandURL = onRequest(
    {
      timeoutSeconds: 10,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      // Extract code from path: /r/abc123 -> abc123
      const pathParts = req.path.split('/');
      const code = pathParts[pathParts.length - 1];

      if (!code) {
        res.status(400).send('Missing short code');
        return;
      }

      try {
        console.log(`🔍 Expanding code: ${code}`);

        const longUrl = await urlShortener.expandURL(code);

        if (!longUrl) {
          res.status(404).send('Short URL not found or expired');
          return;
        }

        // Track the click
        const referrer = req.get('referer') || req.get('referrer');
        const userAgent = req.get('user-agent');
        await urlShortener.trackClick(code, referrer, userAgent);

        // Redirect to the original URL
        res.redirect(302, longUrl);
      } catch (error: any) {
        console.error('❌ Expansion error:', error);
        res.status(500).send('Error expanding URL');
      }
    }
);

/**
 * Get URL analytics endpoint
 * GET /urlAnalytics/:code
 * Returns analytics data for a short URL
 */
export const urlAnalytics = onRequest(
    {
      timeoutSeconds: 10,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      const pathParts = req.path.split('/');
      const code = pathParts[pathParts.length - 1];

      if (!code) {
        res.status(400).json({error: 'Missing short code'});
        return;
      }

      try {
        const analytics = await urlShortener.getAnalytics(code);

        if (!analytics) {
          res.status(404).json({error: 'Short URL not found'});
          return;
        }

        res.status(200).json(analytics);
      } catch (error: any) {
        console.error('❌ Analytics error:', error);
        res.status(500).json({error: 'Failed to retrieve analytics'});
      }
    }
);

/**
 * Scheduled function: Clean old cache
 * Runs daily at 3 AM
 */
export const cleanCache = onSchedule(
    {
      schedule: 'every day 03:00',
      timeoutSeconds: 300,
      memory: '256MiB',
    },
    async () => {
      console.log('🧹 Cleaning old cache...');

      try {
        const thirtyDaysAgo = new Date();
        thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

        // Delete old import attempts (keep failures for 1 year)
        const oldSuccessfulImports = await db
            .collection('import_attempts')
            .where('status', '==', 'success')
            .where('timestamp', '<', thirtyDaysAgo)
            .get();

        console.log(
            `🗑️  Deleting ${oldSuccessfulImports.size} old successful imports...`
        );

        const batch = db.batch();
        oldSuccessfulImports.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();

        console.log('✅ Cache cleaned successfully');

        // Also clean up expired short URLs
        const expiredCount = await urlShortener.cleanupExpired();
        console.log(`🔗 Cleaned up ${expiredCount} expired short URLs`);
      } catch (error) {
        console.error('❌ Error cleaning cache:', error);
        throw error;
      }
    }
);

/**
 * Detect language of recipe text
 * POST /detectLanguage
 * Body: { text: string, hints?: { url?: string, domain?: string } }
 */
export const detectLanguage = onRequest(
    {
      timeoutSeconds: 30,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      try {
        const requestBody = req.body as DetectLanguageRequest;

        if (!requestBody || !requestBody.text) {
          res.status(400).json({
            error: 'Missing required field: text',
          });
          return;
        }

        console.log('🌐 Language detection request');

        // Detect language using Claude
        const result = await languageService.detectLanguage(
            requestBody.text,
            requestBody.hints
        );

        console.log(`✅ Detected language: ${result.language} (${result.confidence})`);

        res.status(200).json(result);
      } catch (error: any) {
        console.error('❌ Language detection error:', error);
        res.status(500).json({
          error: 'Language detection failed',
          message: error.message,
        });
      }
    }
);

/**
 * Translate recipe text
 * POST /translateText
 * Body: { text: string, sourceLanguage: string, targetLanguage?: string, context?: string }
 */
export const translateText = onRequest(
    {
      timeoutSeconds: 30,
      memory: '256MiB',
      cors: true,
    },
    async (req: Request, res: Response) => {
      if (req.method === 'OPTIONS') {
        res.status(204).send('');
        return;
      }

      if (req.method !== 'POST') {
        res.status(405).json({error: 'Method not allowed'});
        return;
      }

      try {
        const requestBody = req.body as TranslateTextRequest;

        if (!requestBody || !requestBody.text || !requestBody.sourceLanguage) {
          res.status(400).json({
            error: 'Missing required fields: text, sourceLanguage',
          });
          return;
        }

        console.log(
            `🌐 Translation request: ${requestBody.sourceLanguage} → ${requestBody.targetLanguage || 'en'}`
        );

        // Translate using Claude
        const result = await languageService.translateText(
            requestBody.text,
            requestBody.sourceLanguage,
            requestBody.targetLanguage,
            requestBody.context
        );

        console.log(`✅ Translation completed (confidence: ${result.confidence})`);

        res.status(200).json(result);
      } catch (error: any) {
        console.error('❌ Translation error:', error);
        res.status(500).json({
          error: 'Translation failed',
          message: error.message,
        });
      }
    }
);

/**
 * Auth trigger: Auto-seed deletion test account on creation
 * Fires when a new user is created in Firebase Auth
 * If the email is deletetest@heirloomrecipebox.app, auto-populates with test data
 */
export const onUserCreated = functionsV1.auth.user().onCreate(async (user: UserRecord) => {
  const DELETION_TEST_EMAIL = 'deletetest@heirloomrecipebox.app';

  if (user.email !== DELETION_TEST_EMAIL) {
    return; // Not the deletion test account, skip
  }

  console.log('🧪 Deletion test account created, auto-seeding data...');
  console.log(`   User ID: ${user.uid}`);
  console.log(`   Email: ${user.email}`);

  try {
    await deletionTestSeeder.seedAccount(user.uid, user.email);
    console.log('✅ Deletion test account seeded successfully');
  } catch (error) {
    console.error('❌ Failed to seed deletion test account:', error);
    // Don't throw - let the user creation succeed even if seeding fails
    // They can re-seed manually via the seed script
  }
});
