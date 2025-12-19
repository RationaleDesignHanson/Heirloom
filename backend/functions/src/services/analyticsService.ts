/**
 * Analytics service for tracking import attempts
 * Stores all attempts (success and failure) for learning
 */

import * as admin from 'firebase-admin';
import {
  ImportAttempt,
  ImportStatus,
  ParserType,
  HtmlStructure,
  ExtractedRecipe,
  ImportError,
  SitePattern,
  TrainingQueueItem,
} from '../types';
import {UrlUtils} from '../utils/urlUtils';
import {removeUndefined} from '../utils/firestoreUtils';

export class AnalyticsService {
  private db: admin.firestore.Firestore;

  constructor(db: admin.firestore.Firestore) {
    this.db = db;
  }

  /**
   * Store import attempt in Firestore
   */
  async storeImportAttempt(
      url: string,
      userId: string | undefined,
      status: ImportStatus,
      extracted: Partial<ExtractedRecipe>,
      parserUsed: ParserType,
      confidence: number,
      errors: ImportError[] | undefined,
      htmlStructure: HtmlStructure,
      parseTimeMs: number,
      storeRawHTML: boolean = false,
      rawHTML?: string
  ): Promise<string> {
    const domain = UrlUtils.extractDomain(url);

    const attempt: Omit<ImportAttempt, 'id'> = {
      url,
      domain,
      timestamp: new Date(),
      ...(userId && { userId }), // Only include userId if defined
      status,
      extracted,
      parserUsed,
      confidence,
      htmlStructure,
      errors,
      parseTimeMs,
    };

    // Only store raw HTML for failed or low confidence imports (for retraining)
    if (storeRawHTML && rawHTML && (status === 'failed' || confidence < 0.7)) {
      attempt.rawHTML = rawHTML;
    }

    // Store in Firestore (clean undefined values first)
    const cleanedAttempt = removeUndefined(attempt);
    const docRef = await this.db.collection('import_attempts').add(cleanedAttempt);

    // Update site patterns in background
    this.updateSitePattern(domain, status, parserUsed, confidence).catch(err => {
      console.error('Error updating site pattern:', err);
    });

    // Add to training queue if needed
    if (status === 'failed' || confidence < 0.6) {
      this.addToTrainingQueue(url, domain, extracted).catch(err => {
        console.error('Error adding to training queue:', err);
      });
    }

    return docRef.id;
  }

  /**
   * Update site pattern statistics
   */
  private async updateSitePattern(
      domain: string,
      status: ImportStatus,
      parserUsed: ParserType,
      confidence: number
  ): Promise<void> {
    const patternRef = this.db.collection('site_patterns').doc(domain);

    await this.db.runTransaction(async (transaction) => {
      const doc = await transaction.get(patternRef);

      if (!doc.exists) {
        // Create new pattern
        const pattern: SitePattern = {
          domain,
          successRate: status === 'success' ? 1.0 : 0.0,
          totalAttempts: 1,
          successfulAttempts: status === 'success' ? 1 : 0,
          lastSuccessful: status === 'success' ? new Date() : undefined,
          lastFailed: status === 'failed' ? new Date() : undefined,
          bestParser: parserUsed,
          commonIssues: [],
          updatedAt: new Date(),
        };
        transaction.set(patternRef, removeUndefined(pattern));
      } else {
        // Update existing pattern
        const data = doc.data() as SitePattern;
        const newTotalAttempts = data.totalAttempts + 1;
        const newSuccessfulAttempts = data.successfulAttempts + (status === 'success' ? 1 : 0);
        const newSuccessRate = newSuccessfulAttempts / newTotalAttempts;

        const updates: Partial<SitePattern> = {
          successRate: newSuccessRate,
          totalAttempts: newTotalAttempts,
          successfulAttempts: newSuccessfulAttempts,
          updatedAt: new Date(),
        };

        if (status === 'success') {
          updates.lastSuccessful = new Date();
          // Update best parser if this one has better success rate
          if (confidence > 0.8) {
            updates.bestParser = parserUsed;
          }
        } else {
          updates.lastFailed = new Date();
        }

        transaction.update(patternRef, removeUndefined(updates));
      }
    });
  }

  /**
   * Add failed/low confidence URL to training queue
   */
  private async addToTrainingQueue(
      url: string,
      domain: string,
      extracted: Partial<ExtractedRecipe>
  ): Promise<void> {
    // Check if URL already in queue
    const existing = await this.db.collection('training_queue')
        .where('url', '==', url)
        .limit(1)
        .get();

    if (!existing.empty) {
      // Update attempt count
      const doc = existing.docs[0];
      await doc.ref.update({
        attemptCount: admin.firestore.FieldValue.increment(1),
        lastAttempted: new Date(),
      });
      return;
    }

    // Calculate priority based on domain popularity
    const sitePattern = await this.db.collection('site_patterns').doc(domain).get();
    const priority = sitePattern.exists ?
      (sitePattern.data() as SitePattern).totalAttempts :
      1;

    const queueItem: Omit<TrainingQueueItem, 'url'> & { url: string } = {
      url,
      domain,
      priority,
      attemptCount: 1,
      lastAttempted: new Date(),
      status: 'pending',
      extractedData: extracted,
      createdAt: new Date(),
    };

    await this.db.collection('training_queue').add(removeUndefined(queueItem));
  }

  /**
   * Get site pattern for domain
   */
  async getSitePattern(domain: string): Promise<SitePattern | null> {
    const doc = await this.db.collection('site_patterns').doc(domain).get();
    return doc.exists ? doc.data() as SitePattern : null;
  }

  /**
   * Get user's recent imports
   */
  async getUserImports(userId: string, limit: number = 20): Promise<ImportAttempt[]> {
    const snapshot = await this.db.collection('import_attempts')
        .where('userId', '==', userId)
        .orderBy('timestamp', 'desc')
        .limit(limit)
        .get();

    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    } as ImportAttempt));
  }

  /**
   * Store user feedback
   */
  async storeFeedback(
      importId: string,
      _userId: string | undefined,
      wasAccurate: boolean,
      corrections: { field: string; correctValue: string }[] | undefined,
      rating: number | undefined,
      comment: string | undefined
  ): Promise<void> {
    // Update the import attempt with feedback
    const feedback = removeUndefined({
      wasAccurate,
      corrections,
      rating,
      comment,
      timestamp: new Date(),
    });
    await this.db.collection('import_attempts').doc(importId).update({
      'userFeedback': feedback,
    });

    // If user provided corrections, mark for review in training queue
    if (corrections && corrections.length > 0) {
      const attempt = await this.db.collection('import_attempts').doc(importId).get();
      if (attempt.exists) {
        const data = attempt.data() as ImportAttempt;
        await this.addToTrainingQueue(data.url, data.domain, data.extracted);
      }
    }
  }

  /**
   * Get analytics stats (for debugging)
   */
  async getStats(): Promise<{
    totalImports: number;
    successRate: number;
    topDomains: { domain: string; count: number }[];
  }> {
    const attempts = await this.db.collection('import_attempts')
        .orderBy('timestamp', 'desc')
        .limit(1000)
        .get();

    const total = attempts.size;
    const successful = attempts.docs.filter(doc =>
      (doc.data() as ImportAttempt).status === 'success'
    ).length;

    // Count by domain
    const domainCounts = new Map<string, number>();
    attempts.docs.forEach(doc => {
      const domain = (doc.data() as ImportAttempt).domain;
      domainCounts.set(domain, (domainCounts.get(domain) || 0) + 1);
    });

    const topDomains = Array.from(domainCounts.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([domain, count]) => ({domain, count}));

    return {
      totalImports: total,
      successRate: total > 0 ? successful / total : 0,
      topDomains,
    };
  }
}
