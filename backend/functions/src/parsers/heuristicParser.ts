/**
 * Heuristic recipe parser
 * Fallback parser for sites without schema.org structured data
 * Uses HTML structure heuristics to find recipe components
 */

import * as cheerio from 'cheerio';
import {ExtractedRecipe, ParserResult} from '../types';

export class HeuristicParser {
  /**
   * Parse recipe from HTML using heuristics
   */
  static parse(html: string): ParserResult {
    try {
      const $ = cheerio.load(html);

      // Remove comment sections FIRST to prevent extracting user comments
      this.removeCommentSections($);

      // Extract components
      const title = this.extractTitle($);
      const ingredients = this.extractIngredients($);
      const instructions = this.extractInstructions($);
      const image = this.extractImage($);
      const servings = this.extractServings($);
      const times = this.extractTimes($);

      // Build recipe
      const recipe: ExtractedRecipe = {
        title: title || 'Untitled Recipe',
        ingredients,
        instructions,
        imageUrl: image,
        servings,
        prepTime: times.prep,
        cookTime: times.cook,
      };

      // Calculate confidence
      const confidence = this.calculateConfidence(recipe);

      return {
        success: ingredients.length > 0 && instructions.length > 0,
        recipe,
        confidence,
        parserUsed: 'heuristic',
      };
    } catch (error: any) {
      return {
        success: false,
        confidence: 0,
        parserUsed: 'heuristic',
        errors: [{
          type: 'parsing',
          message: `Heuristic parsing failed: ${error.message}`,
        }],
      };
    }
  }

  /**
   * Remove comment sections from DOM to prevent extracting user comments as instructions
   */
  private static removeCommentSections($: cheerio.CheerioAPI): void {
    // Remove common comment containers
    const commentSelectors = [
      '.comments',
      '#comments',
      '.comment-section',
      '.comment-list',
      '.comment-content',
      '.discussion',
      '.reviews',
      '.review-section',
      '.disqus',
      '.facebook-comments',
      '.utterances',
      '.commento',
      '[class*="comment-"]',
      '[id*="comment-"]',
      '[class*="disqus"]',
      '[class*="discussion"]',
      '[id*="reviews"]',
      '[id*="respond"]',
    ];

    commentSelectors.forEach(selector => {
      try {
        $(selector).remove();
      } catch (e) {
        // Ignore errors from invalid selectors
      }
    });

    // Also remove anything after a "Comments" heading
    $('h1, h2, h3, h4, h5').each((_, el) => {
      const text = $(el).text().toLowerCase().trim();
      if (text.includes('comment') ||
          text.includes('review') ||
          text.includes('discussion') ||
          text === 'leave a reply' ||
          text === 'leave a comment') {
        // Remove this heading and all siblings after it
        $(el).nextAll().remove();
        $(el).remove();
      }
    });
  }

  /**
   * Extract recipe title
   */
  private static extractTitle($: cheerio.CheerioAPI): string | null {
    // Try h1 first
    const h1 = $('h1').first().text().trim();
    if (h1 && h1.length < 100) return h1;

    // Try title tag
    const titleTag = $('title').text().trim();
    if (titleTag) {
      // Remove site name (usually after | or -)
      const cleaned = titleTag.split(/[\|\-]/)[0].trim();
      if (cleaned.length > 0 && cleaned.length < 100) return cleaned;
    }

    // Try meta og:title
    const ogTitle = $('meta[property="og:title"]').attr('content');
    if (ogTitle && ogTitle.length < 100) return ogTitle.trim();

    return null;
  }

  /**
   * Extract ingredients list
   */
  private static extractIngredients($: cheerio.CheerioAPI): string[] {
    const ingredients: string[] = [];

    // Look for common selectors
    const selectors = [
      '.ingredient',
      '.ingredients li',
      '[itemprop="recipeIngredient"]',
      '[class*="ingredient"] li',
      '[id*="ingredient"] li',
      'ul li',  // Generic fallback
    ];

    for (const selector of selectors) {
      const items = $(selector);
      if (items.length > 2) { // Need at least 3 items
        items.each((_, el) => {
          const text = $(el).text().trim();
          if (text && text.length < 200 && this.looksLikeIngredient(text)) {
            ingredients.push(text);
          }
        });

        if (ingredients.length > 0) break;
      }
    }

    return ingredients;
  }

  /**
   * Check if text looks like an ingredient
   */
  private static looksLikeIngredient(text: string): boolean {
    // Too short or too long
    if (text.length < 3 || text.length > 200) return false;

    // Common ingredient patterns
    const ingredientPatterns = [
      /\d+/, // Contains number (measurement)
      /cup|tbsp|tsp|oz|lb|kg|g|ml|l/i, // Contains unit
      /chopped|diced|sliced|minced/i, // Contains prep instruction
    ];

    // Should match at least one pattern
    return ingredientPatterns.some(pattern => pattern.test(text));
  }

  /**
   * Extract instructions
   */
  private static extractInstructions($: cheerio.CheerioAPI): string[] {
    const instructions: string[] = [];

    // Look for common selectors
    const selectors = [
      '.instruction',
      '.instructions li',
      '.directions li',
      '.steps li',
      '[itemprop="recipeInstructions"]',
      '[class*="instruction"] li',
      '[class*="direction"] li',
      '[class*="step"] li',
      'ol li', // Generic fallback
    ];

    for (const selector of selectors) {
      const items = $(selector);
      if (items.length > 0) {
        items.each((_, el) => {
          const text = $(el).text().trim();
          if (text && text.length > 10 && text.length < 1000 && this.looksLikeInstruction(text)) {
            instructions.push(text);
          }
        });

        if (instructions.length > 0) break;
      }
    }

    // If still no instructions, look for paragraphs in common containers
    if (instructions.length === 0) {
      const containerSelectors = [
        '.instructions',
        '.directions',
        '.steps',
        '[class*="instruction"]',
        '[class*="direction"]',
      ];

      for (const selector of containerSelectors) {
        const container = $(selector).first();
        if (container.length > 0) {
          container.find('p').each((_, el) => {
            const text = $(el).text().trim();
            if (text && text.length > 20 && text.length < 1000 && this.looksLikeInstruction(text)) {
              instructions.push(text);
            }
          });

          if (instructions.length > 0) break;
        }
      }
    }

    return instructions;
  }

  /**
   * Check if text looks like a recipe instruction (not a user comment)
   */
  private static looksLikeInstruction(text: string): boolean {
    // Exclude comment patterns (first-person narratives, reviews)
    const commentPatterns = [
      /^(I|We|My|This) .*(love|loved|tried|made|recommend|favorite)/i,
      /^These (are|were) (amazing|delicious|perfect|great|wonderful)/i,
      /thank you (for|so much)/i,
      /can'?t wait to (try|make)/i,
      /just made this/i,
      /turned out (great|perfect|amazing)/i,
      /^(So|Very) (good|delicious|tasty|yummy)/i,
      /will (definitely |certainly )?make (this |these )?again/i,
      /my (family|kids|husband|wife) loved/i,
    ];

    if (commentPatterns.some(pattern => pattern.test(text))) {
      return false;
    }

    // Prefer imperative mood (typical recipe instructions)
    const instructionPatterns = [
      /^(Preheat|Heat|Warm|Cool)/i,
      /^(Mix|Combine|Blend|Stir|Whisk|Beat|Fold)/i,
      /^(Add|Pour|Place|Put|Set|Arrange)/i,
      /^(Bake|Cook|Roast|Grill|Fry|Sauté|Boil|Simmer)/i,
      /^(Chill|Refrigerate|Freeze|Rest|Let sit)/i,
      /^(Remove|Transfer|Drain|Strain)/i,
      /^(Cut|Chop|Slice|Dice|Mince)/i,
      /^(Season|Sprinkle|Garnish|Top)/i,
      /^(In a (bowl|pan|pot|skillet))/i,
      /\d+\s*(minutes?|hours?|degrees?|°F|°C)/i, // Contains time/temp measurements
    ];

    return instructionPatterns.some(pattern => pattern.test(text));
  }

  /**
   * Extract image URL
   */
  private static extractImage($: cheerio.CheerioAPI): string | undefined {
    // Try meta og:image first
    const ogImage = $('meta[property="og:image"]').attr('content');
    if (ogImage) return ogImage;

    // Try itemprop image
    const itempropImage = $('[itemprop="image"]').attr('src') ||
                          $('[itemprop="image"]').attr('content');
    if (itempropImage) return itempropImage;

    // Look for large images in common containers
    const containers = $('.recipe, .post, article, main');
    if (containers.length > 0) {
      const img = containers.find('img').first();
      const src = img.attr('src') || img.attr('data-src');
      if (src && !src.includes('icon') && !src.includes('logo')) {
        return src;
      }
    }

    return undefined;
  }

  /**
   * Extract servings
   */
  private static extractServings($: cheerio.CheerioAPI): string | undefined {
    // Look for yield/servings patterns
    const patterns = [
      '[itemprop="recipeYield"]',
      '.yield',
      '.servings',
      '[class*="yield"]',
      '[class*="serving"]',
    ];

    for (const pattern of patterns) {
      const el = $(pattern).first();
      if (el.length > 0) {
        const text = el.text().trim();
        if (text && text.length < 50) return text;
      }
    }

    return undefined;
  }

  /**
   * Extract prep and cook times
   */
  private static extractTimes($: cheerio.CheerioAPI): {
    prep?: string;
    cook?: string;
  } {
    const times: { prep?: string; cook?: string } = {};

    // Look for time elements
    const timeElements = $('[itemprop*="Time"], .time, [class*="time"]');

    timeElements.each((_, el) => {
      const text = $(el).text().trim().toLowerCase();
      const itemprop = $(el).attr('itemprop');

      if (itemprop === 'prepTime' || text.includes('prep')) {
        times.prep = $(el).text().trim();
      } else if (itemprop === 'cookTime' || text.includes('cook')) {
        times.cook = $(el).text().trim();
      }
    });

    return times;
  }

  /**
   * Calculate confidence score
   */
  private static calculateConfidence(recipe: ExtractedRecipe): number {
    let score = 0;

    // Title (lower weight for heuristic)
    if (recipe.title && recipe.title !== 'Untitled Recipe') score += 0.1;

    // Ingredients (critical)
    if (recipe.ingredients.length >= 5) {
      score += 0.4;
    } else if (recipe.ingredients.length > 0) {
      score += 0.2;
    }

    // Instructions (critical)
    if (recipe.instructions.length >= 3) {
      score += 0.3;
    } else if (recipe.instructions.length > 0) {
      score += 0.15;
    }

    // Image
    if (recipe.imageUrl) score += 0.05;

    // Metadata
    if (recipe.servings) score += 0.05;
    if (recipe.prepTime) score += 0.05;
    if (recipe.cookTime) score += 0.05;

    return Math.min(1.0, score);
  }
}
