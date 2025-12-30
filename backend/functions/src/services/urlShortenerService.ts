/**
 * URL Shortening Service
 * Creates and manages short URLs for recipe sharing
 */

import {Firestore} from 'firebase-admin/firestore';
import * as crypto from 'crypto';
import {ShortURL, URLClickEvent} from '../types';

export class URLShortenerService {
  private readonly collection = 'short_urls';
  private readonly clicksCollection = 'url_clicks';
  private readonly baseDomain = 'heirloom.app';
  private readonly codeLength = 6;
  private readonly codeCharacters =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  constructor(private db: Firestore) {}

  /**
   * Generate a short URL for a long CloudKit share URL
   * @param longUrl The full CloudKit share URL
   * @param customCode Optional custom short code
   * @param recipeId Optional recipe ID for analytics
   * @param userId Optional user ID for ownership
   * @returns Short URL data
   */
  async shortenURL(
      longUrl: string,
      customCode?: string,
      recipeId?: string,
      userId?: string
  ): Promise<{code: string; shortUrl: string}> {
    console.log(`🔗 Shortening URL: ${longUrl.substring(0, 50)}...`);

    // 1. Validate the long URL
    if (!this.isValidURL(longUrl)) {
      throw new Error('Invalid URL format');
    }

    // 2. Check if URL already has a short code
    const existing = await this.findExistingCode(longUrl);
    if (existing) {
      console.log(`✅ Found existing short code: ${existing}`);
      return {
        code: existing,
        shortUrl: `https://${this.baseDomain}/r/${existing}`,
      };
    }

    // 3. Generate or validate custom code
    const code = customCode ?
      await this.validateCustomCode(customCode) :
      await this.generateUniqueCode();

    // 4. Create short URL document in Firestore
    const shortURLData: ShortURL = {
      code,
      longUrl,
      recipeId,
      userId,
      createdAt: new Date(),
      clicks: 0,
      clicksByDay: {},
      referrers: {},
    };

    await this.db.collection(this.collection).doc(code).set(shortURLData);

    console.log(`✅ Created short URL: ${code}`);

    return {
      code,
      shortUrl: `https://${this.baseDomain}/r/${code}`,
    };
  }

  /**
   * Expand a short code back to the original URL
   * @param code The short code
   * @returns Original long URL, or null if not found
   */
  async expandURL(code: string): Promise<string | null> {
    console.log(`🔍 Expanding code: ${code}`);

    const doc = await this.db.collection(this.collection).doc(code).get();

    if (!doc.exists) {
      console.log(`❌ Code not found: ${code}`);
      return null;
    }

    const data = doc.data() as ShortURL;

    // Check if expired
    if (data.expiresAt && data.expiresAt < new Date()) {
      console.log(`⏰ Code expired: ${code}`);
      return null;
    }

    console.log(`✅ Expanded to: ${data.longUrl.substring(0, 50)}...`);

    return data.longUrl;
  }

  /**
   * Track a click on a short URL
   * @param code The short code that was clicked
   * @param referrer Optional referrer URL
   * @param userAgent Optional user agent string
   */
  async trackClick(
      code: string,
      referrer?: string,
      userAgent?: string
  ): Promise<void> {
    console.log(`📊 Tracking click for code: ${code}`);

    const docRef = this.db.collection(this.collection).doc(code);

    // Increment total clicks
    await docRef.update({
      clicks: Firestore.FieldValue.increment(1),
      lastAccessed: new Date(),
    });

    // Track clicks by day
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    await docRef.update({
      [`clicksByDay.${today}`]: Firestore.FieldValue.increment(1),
    });

    // Track referrer if provided
    if (referrer) {
      try {
        const referrerDomain = new URL(referrer).hostname;
        await docRef.update({
          [`referrers.${referrerDomain}`]: Firestore.FieldValue.increment(1),
        });
      } catch (e) {
        // Invalid referrer URL, skip
      }
    }

    // Store individual click event for detailed analytics
    const clickEvent: URLClickEvent = {
      code,
      timestamp: new Date(),
      userAgent,
      referrer,
    };

    await this.db.collection(this.clicksCollection).add(clickEvent);

    console.log(`✅ Click tracked`);
  }

  /**
   * Get analytics for a short URL
   * @param code The short code
   * @returns Short URL data with analytics
   */
  async getAnalytics(code: string): Promise<ShortURL | null> {
    const doc = await this.db.collection(this.collection).doc(code).get();

    if (!doc.exists) {
      return null;
    }

    return doc.data() as ShortURL;
  }

  /**
   * Delete a short URL
   * @param code The short code to delete
   */
  async deleteShortURL(code: string): Promise<void> {
    console.log(`🗑️  Deleting short URL: ${code}`);
    await this.db.collection(this.collection).doc(code).delete();
    console.log(`✅ Short URL deleted`);
  }

  // ===== Private Helper Methods =====

  /**
   * Generate a unique random code
   */
  private async generateUniqueCode(): Promise<string> {
    let attempts = 0;
    const maxAttempts = 10;

    while (attempts < maxAttempts) {
      const code = this.generateRandomCode();

      // Check if code is available
      const exists = await this.codeExists(code);
      if (!exists) {
        return code;
      }

      attempts++;
    }

    throw new Error('Failed to generate unique code after 10 attempts');
  }

  /**
   * Generate a random code
   */
  private generateRandomCode(): string {
    let code = '';
    for (let i = 0; i < this.codeLength; i++) {
      const randomIndex = Math.floor(
          Math.random() * this.codeCharacters.length
      );
      code += this.codeCharacters[randomIndex];
    }
    return code;
  }

  /**
   * Validate and normalize a custom code
   */
  private async validateCustomCode(customCode: string): Promise<string> {
    // Normalize the code
    const normalized = customCode
        .toLowerCase()
        .replace(/\s+/g, '-') // Replace spaces with hyphens
        .replace(/[^a-z0-9-]/g, ''); // Remove non-alphanumeric (except hyphens)

    // Validate length
    if (normalized.length < 3 || normalized.length > 20) {
      throw new Error('Custom code must be 3-20 characters');
    }

    // Check if code is available
    const exists = await this.codeExists(normalized);
    if (exists) {
      throw new Error('Custom code is already in use');
    }

    return normalized;
  }

  /**
   * Check if a code already exists
   */
  private async codeExists(code: string): Promise<boolean> {
    const doc = await this.db.collection(this.collection).doc(code).get();
    return doc.exists;
  }

  /**
   * Find existing short code for a long URL
   */
  private async findExistingCode(longUrl: string): Promise<string | null> {
    const snapshot = await this.db
        .collection(this.collection)
        .where('longUrl', '==', longUrl)
        .limit(1)
        .get();

    if (snapshot.empty) {
      return null;
    }

    return snapshot.docs[0].id;
  }

  /**
   * Validate URL format
   */
  private isValidURL(url: string): boolean {
    try {
      const parsed = new URL(url);
      return (
        parsed.protocol === 'https:' &&
        (parsed.hostname.includes('icloud.com') ||
          parsed.hostname.includes(this.baseDomain))
      );
    } catch (e) {
      return false;
    }
  }

  /**
   * Hash IP address for privacy
   */
  private hashIP(ip: string): string {
    return crypto.createHash('sha256').update(ip).digest('hex').substring(0, 16);
  }

  /**
   * Clean up expired short URLs (called by scheduled function)
   */
  async cleanupExpired(): Promise<number> {
    console.log('🧹 Cleaning up expired short URLs...');

    const now = new Date();
    const snapshot = await this.db
        .collection(this.collection)
        .where('expiresAt', '<', now)
        .get();

    if (snapshot.empty) {
      console.log('✅ No expired URLs to clean');
      return 0;
    }

    const batch = this.db.batch();
    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    console.log(`✅ Cleaned up ${snapshot.size} expired URLs`);
    return snapshot.size;
  }
}
