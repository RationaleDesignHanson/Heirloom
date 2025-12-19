/**
 * URL utilities for recipe import
 */

export class UrlUtils {
  /**
   * Validate URL format
   */
  static isValidUrl(urlString: string): boolean {
    try {
      const url = new URL(urlString);
      return url.protocol === 'http:' || url.protocol === 'https:';
    } catch {
      return false;
    }
  }

  /**
   * Extract domain from URL
   */
  static extractDomain(urlString: string): string {
    try {
      const url = new URL(urlString);
      return url.hostname.replace(/^www\./, '');
    } catch {
      return 'unknown';
    }
  }

  /**
   * Generate hash from URL for caching
   */
  static urlToHash(urlString: string): string {
    // Simple hash function (for cache keys)
    let hash = 0;
    for (let i = 0; i < urlString.length; i++) {
      const char = urlString.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash).toString(36);
  }

  /**
   * Normalize URL (remove tracking params, etc.)
   */
  static normalizeUrl(urlString: string): string {
    try {
      const url = new URL(urlString);

      // Remove common tracking parameters
      const trackingParams = [
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
        'fbclid', 'gclid', 'ref', 'source'
      ];

      trackingParams.forEach(param => url.searchParams.delete(param));

      // Remove hash
      url.hash = '';

      return url.toString();
    } catch {
      return urlString;
    }
  }

  /**
   * Check if domain is likely a recipe site
   */
  static isLikelyRecipeSite(domain: string): boolean {
    const recipeKeywords = [
      'recipe', 'cooking', 'food', 'kitchen', 'baking', 'chef',
      'allrecipes', 'foodnetwork', 'epicurious', 'seriouseats',
      'bonappetit', 'kingarthur', 'simplyrecipes', 'budgetbytes'
    ];

    const lowerDomain = domain.toLowerCase();
    return recipeKeywords.some(keyword => lowerDomain.includes(keyword));
  }

  /**
   * Get user agent string for scraping
   */
  static getUserAgent(): string {
    return 'Mozilla/5.0 (compatible; HeirloomApp/1.0; +https://heirloom.app/bot)';
  }
}
