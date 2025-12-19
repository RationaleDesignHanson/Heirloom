/**
 * Author extraction utility
 * Fallback methods to extract author when schema.org doesn't provide it
 */

import * as cheerio from 'cheerio';

export class AuthorExtractor {
  /**
   * Extract author from HTML using multiple fallback strategies
   *
   * Priority order:
   * 1. Meta tags (og:article:author, author, etc.)
   * 2. JSON-LD Person data
   * 3. Common HTML patterns (bylines, author classes)
   * 4. Domain fallback (e.g., "Recipe from AllRecipes.com")
   */
  static extract(html: string, domain: string): string | undefined {
    try {
      const $ = cheerio.load(html);

      // Strategy 1: Meta tags
      const authorFromMeta = this.extractFromMetaTags($);
      if (authorFromMeta) return authorFromMeta;

      // Strategy 2: JSON-LD Person
      const authorFromJsonLd = this.extractFromJsonLd($);
      if (authorFromJsonLd) return authorFromJsonLd;

      // Strategy 3: Common HTML patterns
      const authorFromHtml = this.extractFromHtmlPatterns($);
      if (authorFromHtml) return authorFromHtml;

      // Strategy 4: Domain fallback for attribution
      return this.domainFallback(domain);
    } catch (error) {
      console.error('Error extracting author:', error);
      return this.domainFallback(domain);
    }
  }

  /**
   * Extract from meta tags
   */
  private static extractFromMetaTags($: cheerio.CheerioAPI): string | undefined {
    // Check various meta tag author attributes
    const metaSelectors = [
      'meta[property="article:author"]',
      'meta[property="og:article:author"]',
      'meta[name="author"]',
      'meta[name="article:author"]',
      'meta[name="sailthru.author"]',
      'meta[property="author"]',
    ];

    for (const selector of metaSelectors) {
      const content = $(selector).attr('content');
      if (content && content.trim().length > 0) {
        const cleaned = this.cleanAuthorName(content);
        if (cleaned) return cleaned;
      }
    }

    return undefined;
  }

  /**
   * Extract from JSON-LD Person data
   */
  private static extractFromJsonLd($: cheerio.CheerioAPI): string | undefined {
    const scripts = $('script[type="application/ld+json"]');

    for (let i = 0; i < scripts.length; i++) {
      try {
        const content = $(scripts[i]).html();
        if (!content) continue;

        const json = JSON.parse(content);
        const items = Array.isArray(json) ? json : [json];

        for (const item of items) {
          // Check for Person type
          if (item['@type'] === 'Person' && item.name) {
            const cleaned = this.cleanAuthorName(item.name);
            if (cleaned) return cleaned;
          }

          // Check author field in Recipe (backup if schema.org parser missed it)
          if (item['@type'] === 'Recipe' && item.author) {
            if (typeof item.author === 'string') {
              const cleaned = this.cleanAuthorName(item.author);
              if (cleaned) return cleaned;
            }
            if (item.author.name) {
              const cleaned = this.cleanAuthorName(item.author.name);
              if (cleaned) return cleaned;
            }
          }

          // Check @graph for Person
          if (item['@graph']) {
            const graph = Array.isArray(item['@graph']) ? item['@graph'] : [item['@graph']];
            for (const graphItem of graph) {
              if (graphItem['@type'] === 'Person' && graphItem.name) {
                const cleaned = this.cleanAuthorName(graphItem.name);
                if (cleaned) return cleaned;
              }
            }
          }
        }
      } catch (e) {
        // Invalid JSON, continue
      }
    }

    return undefined;
  }

  /**
   * Extract from common HTML patterns
   */
  private static extractFromHtmlPatterns($: cheerio.CheerioAPI): string | undefined {
    // Common author selectors (bylines, author classes, etc.)
    const authorSelectors = [
      '.author-name',
      '.author',
      '.byline',
      '.recipe-author',
      '[itemprop="author"]',
      '[rel="author"]',
      '.contributor',
      '.recipe-by',
      '.submitted-by',
    ];

    for (const selector of authorSelectors) {
      const element = $(selector).first();
      if (element.length > 0) {
        const text = element.text().trim();
        if (text.length > 0 && text.length < 100) {
          // Clean common prefixes
          const cleaned = text
              .replace(/^by\s+/i, '')
              .replace(/^recipe by\s+/i, '')
              .replace(/^submitted by\s+/i, '')
              .replace(/^author:\s+/i, '')
              .trim();

          if (cleaned.length > 0) {
            const finalCleaned = this.cleanAuthorName(cleaned);
            if (finalCleaned) return finalCleaned;
          }
        }
      }
    }

    return undefined;
  }

  /**
   * Clean author name (remove extra whitespace, truncate if too long)
   * Returns undefined if the "author" is actually a URL or invalid
   */
  private static cleanAuthorName(name: string): string | undefined {
    const cleaned = name
        .trim()
        .replace(/\s+/g, ' '); // Normalize whitespace

    // Filter out URLs (Facebook, Twitter, etc.)
    if (cleaned.match(/^https?:\/\//i) ||
        cleaned.match(/facebook\.com|twitter\.com|instagram\.com/i)) {
      return undefined;
    }

    // Filter out email addresses
    if (cleaned.match(/^[^\s]+@[^\s]+\.[^\s]+$/)) {
      return undefined;
    }

    // Must be reasonable length (2-100 chars)
    if (cleaned.length < 2 || cleaned.length > 100) {
      return undefined;
    }

    return cleaned;
  }

  /**
   * Fallback to domain-based attribution
   */
  private static domainFallback(domain: string): string {
    // Capitalize first letter of domain name
    const siteName = domain
        .replace(/\.com$|\.org$|\.net$/i, '')
        .split('.')
        .map(part => part.charAt(0).toUpperCase() + part.slice(1))
        .join('');

    return `${siteName}`;
  }
}
