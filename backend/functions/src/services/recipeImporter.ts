/**
 * Main recipe importer service
 * Orchestrates the entire import workflow
 */

import {HttpFetcher} from '../utils/httpFetcher';
import {UrlUtils} from '../utils/urlUtils';
import {AuthorExtractor} from '../utils/authorExtractor';
import {SchemaOrgParser} from '../parsers/schemaOrgParser';
import {HeuristicParser} from '../parsers/heuristicParser';
import {AnalyticsService} from './analyticsService';
import {
  ImportResponse,
  ImportStatus,
  HtmlStructure,
  ImportError,
} from '../types';
import * as cheerio from 'cheerio';

export class RecipeImporter {
  constructor(private analyticsService: AnalyticsService) {}

  /**
   * Import recipe from URL
   */
  async import(url: string, userId?: string): Promise<ImportResponse> {
    const startTime = Date.now();

    try {
      // 1. Validate URL
      if (!UrlUtils.isValidUrl(url)) {
        return this.errorResponse('Invalid URL format', 'validation', startTime);
      }

      // 2. Normalize URL
      const normalizedUrl = UrlUtils.normalizeUrl(url);

      // 3. Fetch HTML
      const fetchResult = await HttpFetcher.fetch(normalizedUrl);
      if (!fetchResult.success || !fetchResult.html) {
        return this.errorResponse(
            fetchResult.error?.message || 'Failed to fetch URL',
            fetchResult.error?.type || 'network',
            startTime,
            normalizedUrl,
            userId
        );
      }

      const html = fetchResult.html;

      // 4. Analyze HTML structure
      const htmlStructure = this.analyzeHtmlStructure(html);

      // 5. Try parsers in order
      let parserResult = SchemaOrgParser.parse(html);

      // If schema.org failed or low confidence, try heuristic
      if (!parserResult.success || parserResult.confidence < 0.7) {
        console.log('Schema.org parser failed or low confidence, trying heuristic...');
        const heuristicResult = HeuristicParser.parse(html);

        // Use heuristic if it has higher confidence
        if (heuristicResult.confidence > parserResult.confidence) {
          parserResult = heuristicResult;
        }
      }

      // 6. Fallback author extraction if missing
      if (parserResult.recipe && !parserResult.recipe.author) {
        const domain = UrlUtils.extractDomain(normalizedUrl);
        const extractedAuthor = AuthorExtractor.extract(html, domain);
        if (extractedAuthor) {
          parserResult.recipe.author = extractedAuthor;
          console.log(`✨ Extracted author via fallback: ${extractedAuthor}`);
        }
      }

      // 7. Determine overall status
      const status: ImportStatus =
        parserResult.success && parserResult.confidence > 0.7 ? 'success' :
        parserResult.success && parserResult.confidence > 0.4 ? 'partial' :
        'failed';

      // 8. Store analytics (including raw HTML for failed/low confidence)
      const storeRawHTML = status === 'failed' || parserResult.confidence < 0.7;
      const importId = await this.analyticsService.storeImportAttempt(
          normalizedUrl,
          userId,
          status,
          parserResult.recipe || {},
          parserResult.parserUsed,
          parserResult.confidence,
          parserResult.errors,
          htmlStructure,
          Date.now() - startTime,
          storeRawHTML,
          storeRawHTML ? html : undefined
      );

      // 9. Generate response
      const parseTimeMs = Date.now() - startTime;

      return {
        status,
        importId,
        confidence: parserResult.confidence,
        recipe: parserResult.recipe,
        warnings: this.generateWarnings(parserResult, htmlStructure),
        errors: parserResult.errors,
        metadata: {
          parserUsed: parserResult.parserUsed,
          parseTimeMs,
          hasSchemaOrg: htmlStructure.hasSchemaOrg,
          needsFeedback: status !== 'success' || parserResult.confidence < 0.8,
          domain: UrlUtils.extractDomain(normalizedUrl),
          sourceUrl: normalizedUrl,
          timestamp: new Date(),
        },
      };
    } catch (error: any) {
      console.error('Unexpected error during import:', error);
      return this.errorResponse(
          `Unexpected error: ${error.message}`,
          'parsing',
          startTime,
          url,
          userId
      );
    }
  }

  /**
   * Analyze HTML structure for metadata
   */
  private analyzeHtmlStructure(html: string): HtmlStructure {
    try {
      const $ = cheerio.load(html);

      // Check for schema.org
      const hasSchemaOrg = $('script[type="application/ld+json"]').length > 0;

      // Check for recipe card patterns
      const hasRecipeCard = $(
          '.recipe, .recipe-card, [class*="recipe"], [id*="recipe"]'
      ).length > 0;

      // Count dominant tags
      const dominantTags: string[] = [];
      if ($('ul').length > 3) dominantTags.push('ul');
      if ($('ol').length > 2) dominantTags.push('ol');
      if ($('p').length > 5) dominantTags.push('p');
      if ($('article').length > 0) dominantTags.push('article');

      return {
        hasSchemaOrg,
        hasRecipeCard,
        dominantTags,
        headingCount: $('h1, h2, h3').length,
        listCount: $('ul, ol').length,
        imageCount: $('img').length,
      };
    } catch {
      return {
        hasSchemaOrg: false,
        hasRecipeCard: false,
        dominantTags: [],
        headingCount: 0,
        listCount: 0,
        imageCount: 0,
      };
    }
  }

  /**
   * Generate warnings based on parse result
   */
  private generateWarnings(
      parserResult: any,
      htmlStructure: HtmlStructure
  ): string[] {
    const warnings: string[] = [];

    if (!parserResult.recipe) return warnings;

    const recipe = parserResult.recipe;

    // Check for missing critical fields
    if (!recipe.ingredients || recipe.ingredients.length === 0) {
      warnings.push('No ingredients found');
    } else if (recipe.ingredients.length < 3) {
      warnings.push('Very few ingredients found - recipe may be incomplete');
    }

    if (!recipe.instructions || recipe.instructions.length === 0) {
      warnings.push('No instructions found');
    } else if (recipe.instructions.length < 2) {
      warnings.push('Very few instructions found - recipe may be incomplete');
    }

    if (!recipe.imageUrl) {
      warnings.push('No recipe image found');
    }

    if (!recipe.servings) {
      warnings.push('Servings information not found');
    }

    // Parser-specific warnings
    if (parserResult.parserUsed === 'heuristic' && parserResult.confidence < 0.6) {
      warnings.push('Low confidence parse - please review carefully');
    }

    if (!htmlStructure.hasSchemaOrg && parserResult.parserUsed === 'schemaOrg') {
      warnings.push('Schema.org data may be incomplete');
    }

    return warnings;
  }

  /**
   * Generate error response
   */
  private errorResponse(
      message: string,
      type: ImportError['type'],
      startTime: number,
      url?: string,
      userId?: string
  ): ImportResponse {
    const importId = 'error'; // Will be replaced by analytics if URL available

    // Store failed attempt if we have URL
    if (url && userId) {
      this.analyticsService.storeImportAttempt(
          url,
          userId,
          'failed',
          {},
          'none',
          0,
          [{type, message}],
          {
            hasSchemaOrg: false,
            hasRecipeCard: false,
            dominantTags: [],
            headingCount: 0,
            listCount: 0,
            imageCount: 0,
          },
          Date.now() - startTime,
          false
      ).catch(err => console.error('Failed to store error attempt:', err));
    }

    return {
      status: 'failed',
      importId,
      confidence: 0,
      errors: [{type, message}],
      metadata: {
        parserUsed: 'none',
        parseTimeMs: Date.now() - startTime,
        hasSchemaOrg: false,
        needsFeedback: true,
        domain: url ? UrlUtils.extractDomain(url) : 'unknown',
        sourceUrl: url || '',
        timestamp: new Date(),
      },
    };
  }
}
