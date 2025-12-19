/**
 * Schema.org recipe parser
 * Extracts recipe data from JSON-LD structured data
 */

import * as cheerio from 'cheerio';
import {ExtractedRecipe, ParserResult, SchemaOrgRecipe} from '../types';

export class SchemaOrgParser {
  /**
   * Parse recipe from HTML with schema.org structured data
   */
  static parse(html: string): ParserResult {
    try {
      const $ = cheerio.load(html);
      const jsonLdScripts = $('script[type="application/ld+json"]');

      // Find Recipe schema
      let recipeSchema: SchemaOrgRecipe | null = null;

      jsonLdScripts.each((_, el) => {
        try {
          const content = $(el).html();
          if (!content) return undefined;

          const json = JSON.parse(content);

          // Handle arrays of structured data
          const items = Array.isArray(json) ? json : [json];

          for (const item of items) {
            if (this.isRecipeSchema(item)) {
              recipeSchema = item;
              return false; // Break loop
            }

            // Check nested @graph
            if (item['@graph']) {
              const graphItems = Array.isArray(item['@graph']) ? item['@graph'] : [item['@graph']];
              for (const graphItem of graphItems) {
                if (this.isRecipeSchema(graphItem)) {
                  recipeSchema = graphItem;
                  return false; // Break loop
                }
              }
            }
          }
        } catch (e) {
          // Invalid JSON, skip
        }
        return undefined;
      });

      if (!recipeSchema) {
        return {
          success: false,
          confidence: 0,
          parserUsed: 'schemaOrg',
          errors: [{
            type: 'parsing',
            message: 'No schema.org Recipe found in page',
          }],
        };
      }

      // Extract recipe data
      const recipe = this.extractRecipe(recipeSchema);

      // Calculate confidence
      const confidence = this.calculateConfidence(recipe);

      return {
        success: true,
        recipe,
        confidence,
        parserUsed: 'schemaOrg',
      };
    } catch (error: any) {
      return {
        success: false,
        confidence: 0,
        parserUsed: 'schemaOrg',
        errors: [{
          type: 'parsing',
          message: `Schema.org parsing failed: ${error.message}`,
        }],
      };
    }
  }

  /**
   * Check if object is a Recipe schema
   */
  private static isRecipeSchema(obj: any): boolean {
    if (!obj || typeof obj !== 'object') return false;

    const type = obj['@type'];
    if (!type) return false;

    // Handle arrays
    const types = Array.isArray(type) ? type : [type];

    return types.some((t: string) =>
      t === 'Recipe' ||
      t === 'http://schema.org/Recipe' ||
      t.endsWith('#Recipe')
    );
  }

  /**
   * Extract recipe from schema.org data
   */
  private static extractRecipe(schema: SchemaOrgRecipe): ExtractedRecipe {
    return {
      title: schema.name || 'Untitled Recipe',
      ingredients: this.extractIngredients(schema),
      instructions: this.extractInstructions(schema),
      servings: this.extractServings(schema),
      prepTime: schema.prepTime,
      cookTime: schema.cookTime,
      totalTime: schema.totalTime,
      imageUrl: this.extractImageUrl(schema),
      rating: schema.aggregateRating?.ratingValue,
      ratingCount: schema.aggregateRating?.ratingCount,
      description: schema.description,
      author: this.extractAuthor(schema),
      category: this.extractCategory(schema),
      cuisine: this.extractCuisine(schema),
      keywords: this.extractKeywords(schema),
      nutrition: schema.nutrition ? {
        calories: schema.nutrition.calories,
        protein: schema.nutrition.proteinContent,
        carbohydrates: schema.nutrition.carbohydrateContent,
        fat: schema.nutrition.fatContent,
        fiber: schema.nutrition.fiberContent,
        sugar: schema.nutrition.sugarContent,
        sodium: schema.nutrition.sodiumContent,
      } : undefined,
    };
  }

  /**
   * Extract ingredients array
   */
  private static extractIngredients(schema: SchemaOrgRecipe): string[] {
    if (!schema.recipeIngredient) return [];

    const ingredients = Array.isArray(schema.recipeIngredient) ?
      schema.recipeIngredient :
      [schema.recipeIngredient];

    return ingredients
        .map(ing => String(ing).trim())
        .filter(ing => ing.length > 0);
  }

  /**
   * Extract instructions array
   */
  private static extractInstructions(schema: SchemaOrgRecipe): string[] {
    if (!schema.recipeInstructions) return [];

    const instructions = Array.isArray(schema.recipeInstructions) ?
      schema.recipeInstructions :
      [schema.recipeInstructions];

    const steps: string[] = [];

    for (const instruction of instructions) {
      if (typeof instruction === 'string') {
        steps.push(instruction.trim());
      } else if (typeof instruction === 'object' && instruction['@type'] === 'HowToStep') {
        const text = instruction.text || instruction.name || '';
        if (text) steps.push(text.trim());
      }
    }

    return steps.filter(step => step.length > 0);
  }

  /**
   * Extract servings
   */
  private static extractServings(schema: SchemaOrgRecipe): string | undefined {
    if (!schema.recipeYield) return undefined;

    if (typeof schema.recipeYield === 'number') {
      return `${schema.recipeYield} servings`;
    }

    if (typeof schema.recipeYield === 'string') {
      return schema.recipeYield;
    }

    if (Array.isArray(schema.recipeYield) && schema.recipeYield.length > 0) {
      return String(schema.recipeYield[0]);
    }

    return undefined;
  }

  /**
   * Extract image URL
   */
  private static extractImageUrl(schema: SchemaOrgRecipe): string | undefined {
    if (!schema.image) return undefined;

    if (typeof schema.image === 'string') {
      return schema.image;
    }

    if (Array.isArray(schema.image)) {
      const first = schema.image[0];
      if (typeof first === 'string') return first;
      if (typeof first === 'object' && first.url) return first.url;
    }

    if (typeof schema.image === 'object' && 'url' in schema.image) {
      return (schema.image as any).url;
    }

    return undefined;
  }

  /**
   * Extract author name
   */
  private static extractAuthor(schema: SchemaOrgRecipe): string | undefined {
    if (!schema.author) return undefined;

    if (typeof schema.author === 'string') return schema.author;

    if (typeof schema.author === 'object' && 'name' in schema.author) {
      return schema.author.name;
    }

    return undefined;
  }

  /**
   * Extract category
   */
  private static extractCategory(schema: SchemaOrgRecipe): string | undefined {
    if (!schema.recipeCategory) return undefined;

    if (Array.isArray(schema.recipeCategory)) {
      return schema.recipeCategory[0];
    }

    return schema.recipeCategory;
  }

  /**
   * Extract cuisine
   */
  private static extractCuisine(schema: SchemaOrgRecipe): string | undefined {
    if (!schema.recipeCuisine) return undefined;

    if (Array.isArray(schema.recipeCuisine)) {
      return schema.recipeCuisine[0];
    }

    return schema.recipeCuisine;
  }

  /**
   * Extract keywords
   */
  private static extractKeywords(schema: SchemaOrgRecipe): string[] | undefined {
    if (!schema.keywords) return undefined;

    if (typeof schema.keywords === 'string') {
      // Split comma-separated keywords
      return schema.keywords.split(',').map(k => k.trim()).filter(k => k.length > 0);
    }

    if (Array.isArray(schema.keywords)) {
      return schema.keywords.map(k => String(k).trim()).filter(k => k.length > 0);
    }

    return undefined;
  }

  /**
   * Calculate confidence score based on completeness
   *
   * Scoring philosophy:
   * - Core recipe data (title, ingredients, instructions) = 85 points
   * - Enhancement data (image, times, metadata) = 15 points
   * - Quality matters more than quantity for instructions
   */
  private static calculateConfidence(recipe: ExtractedRecipe): number {
    let score = 0;
    let maxScore = 0;

    // Title (critical) - 15 points
    maxScore += 15;
    if (recipe.title && recipe.title !== 'Untitled Recipe') score += 15;

    // Ingredients (critical) - 35 points
    maxScore += 35;
    if (recipe.ingredients.length > 0) {
      // Award based on completeness: full points at 5+ ingredients
      const ingredientScore = Math.min(35, recipe.ingredients.length * 7);
      score += ingredientScore;
    }

    // Instructions (critical) - 35 points
    maxScore += 35;
    if (recipe.instructions.length > 0) {
      // Calculate total instruction length (comprehensive steps matter!)
      const totalInstructionLength = recipe.instructions.reduce(
          (sum, inst) => sum + inst.length,
          0
      );

      // Award based on both count AND quality:
      // - Award up to 25 points for step count (5 pts each, max at 5 steps)
      // - Award up to 10 points for instruction comprehensiveness (>500 chars)
      const countScore = Math.min(25, recipe.instructions.length * 5);
      const qualityScore = totalInstructionLength > 500 ? 10 :
                          totalInstructionLength > 250 ? 7 :
                          totalInstructionLength > 100 ? 4 : 0;
      score += Math.min(35, countScore + qualityScore);
    }

    // Image (important for UX) - 8 points
    maxScore += 8;
    if (recipe.imageUrl) score += 8;

    // Timing info (nice to have) - 4 points
    maxScore += 4;
    // Award points if we have any useful time info
    if (recipe.totalTime) score += 2;
    if (recipe.prepTime || recipe.cookTime) score += 2;

    // Servings (useful) - 2 points
    maxScore += 2;
    if (recipe.servings) score += 2;

    // Description (nice context) - 1 point
    maxScore += 1;
    if (recipe.description) score += 1;

    // Author (important for attribution) - 2 points
    maxScore += 2;
    if (recipe.author) score += 2;

    return Math.min(1.0, score / maxScore);
  }
}
