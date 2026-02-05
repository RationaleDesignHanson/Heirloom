/**
 * Schema validation utilities
 * Validates seed data against PublicRecipe schema requirements
 */

import { SeedRecipe } from '../seed_data.js';

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

/**
 * Validate a single recipe against schema requirements
 */
export function validateRecipe(recipe: SeedRecipe): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Required string fields
  if (!recipe.id || typeof recipe.id !== 'string') {
    errors.push('id is required and must be a string');
  }
  if (!recipe.title || typeof recipe.title !== 'string') {
    errors.push('title is required and must be a string');
  }
  if (!recipe.creatorId || typeof recipe.creatorId !== 'string') {
    errors.push('creatorId is required and must be a string');
  }
  if (!recipe.creatorName || typeof recipe.creatorName !== 'string') {
    errors.push('creatorName is required and must be a string');
  }

  // Title length check (should fit 2 lines in UI)
  if (recipe.title && recipe.title.length > 60) {
    warnings.push(`title is long (${recipe.title.length} chars), may not fit 2 lines`);
  }

  // Description validation
  if (!recipe.description) {
    warnings.push('description is missing (recommended for rich display)');
  } else if (recipe.description.length < 50) {
    warnings.push('description is short (< 50 chars), consider adding more context');
  }

  // Ingredients validation
  if (!recipe.ingredients || !Array.isArray(recipe.ingredients)) {
    errors.push('ingredients is required and must be an array');
  } else {
    if (recipe.ingredients.length < 3) {
      warnings.push(`only ${recipe.ingredients.length} ingredients (recommended: 8-14)`);
    }
    if (recipe.ingredients.length > 20) {
      warnings.push(`${recipe.ingredients.length} ingredients is excessive`);
    }
    // Check ingredient format
    recipe.ingredients.forEach((ing, idx) => {
      if (typeof ing !== 'string') {
        errors.push(`ingredient[${idx}] must be a string`);
      } else if (ing.length < 3) {
        warnings.push(`ingredient[${idx}] "${ing}" is very short`);
      }
    });
  }

  // Instructions validation
  if (!recipe.instructions || !Array.isArray(recipe.instructions)) {
    errors.push('instructions is required and must be an array');
  } else {
    if (recipe.instructions.length < 3) {
      warnings.push(`only ${recipe.instructions.length} instructions (recommended: 6-10)`);
    }
    if (recipe.instructions.length > 15) {
      warnings.push(`${recipe.instructions.length} instructions may be excessive`);
    }
    recipe.instructions.forEach((inst, idx) => {
      if (typeof inst !== 'string') {
        errors.push(`instruction[${idx}] must be a string`);
      } else if (inst.length < 10) {
        warnings.push(`instruction[${idx}] is very short`);
      }
    });
  }

  // Tags validation
  if (!recipe.tags || !Array.isArray(recipe.tags)) {
    errors.push('tags is required and must be an array');
  } else {
    if (recipe.tags.length < 2) {
      warnings.push(`only ${recipe.tags.length} tags (recommended: 3-6)`);
    }
    if (recipe.tags.length > 8) {
      warnings.push(`${recipe.tags.length} tags may be excessive`);
    }
  }

  // Stats validation
  if (typeof recipe.viewCount !== 'number' || recipe.viewCount < 0) {
    errors.push('viewCount must be a non-negative number');
  }
  if (typeof recipe.saveCount !== 'number' || recipe.saveCount < 0) {
    errors.push('saveCount must be a non-negative number');
  }
  if (recipe.saveCount > recipe.viewCount) {
    warnings.push('saveCount > viewCount is unrealistic');
  }

  // Days ago validation
  if (typeof recipe.publishedDaysAgo !== 'number' || recipe.publishedDaysAgo < 0) {
    errors.push('publishedDaysAgo must be a non-negative number');
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Validate all recipes in the seed data
 */
export function validateAllRecipes(recipes: SeedRecipe[]): {
  allValid: boolean;
  results: Map<string, ValidationResult>;
  summary: {
    total: number;
    valid: number;
    invalid: number;
    totalErrors: number;
    totalWarnings: number;
  };
} {
  const results = new Map<string, ValidationResult>();
  let totalErrors = 0;
  let totalWarnings = 0;

  recipes.forEach((recipe) => {
    const result = validateRecipe(recipe);
    results.set(recipe.id, result);
    totalErrors += result.errors.length;
    totalWarnings += result.warnings.length;
  });

  const validCount = Array.from(results.values()).filter((r) => r.isValid).length;

  return {
    allValid: totalErrors === 0,
    results,
    summary: {
      total: recipes.length,
      valid: validCount,
      invalid: recipes.length - validCount,
      totalErrors,
      totalWarnings,
    },
  };
}

/**
 * Print validation results to console
 */
export function printValidationResults(
  results: Map<string, ValidationResult>,
  verbose: boolean = false
): void {
  let hasIssues = false;

  results.forEach((result, recipeId) => {
    if (!result.isValid || (verbose && result.warnings.length > 0)) {
      hasIssues = true;
      console.log(`\n${recipeId}:`);

      if (result.errors.length > 0) {
        console.log('  Errors:');
        result.errors.forEach((err) => console.log(`    - ${err}`));
      }

      if (verbose && result.warnings.length > 0) {
        console.log('  Warnings:');
        result.warnings.forEach((warn) => console.log(`    - ${warn}`));
      }
    }
  });

  if (!hasIssues) {
    console.log('All recipes passed validation!');
  }
}
