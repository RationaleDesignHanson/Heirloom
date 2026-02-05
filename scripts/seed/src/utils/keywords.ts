/**
 * Search keyword generation utilities
 * Generates searchable keywords from recipe content
 */

// Common words to exclude from search keywords
const STOP_WORDS = new Set([
  'the', 'and', 'for', 'with', 'this', 'that', 'are', 'was', 'were',
  'been', 'being', 'have', 'has', 'had', 'does', 'did', 'will', 'would',
  'could', 'should', 'may', 'might', 'must', 'can', 'into', 'from',
  'about', 'over', 'under', 'again', 'then', 'once', 'here', 'there',
  'when', 'where', 'why', 'how', 'all', 'each', 'few', 'more', 'most',
  'other', 'some', 'such', 'only', 'same', 'than', 'too', 'very',
  'just', 'but', 'also', 'your', 'our', 'their', 'its', 'his', 'her',
  'cup', 'cups', 'tablespoon', 'tablespoons', 'tbsp', 'teaspoon', 'teaspoons',
  'tsp', 'pound', 'pounds', 'ounce', 'ounces', 'inch', 'inches',
]);

/**
 * Generate search keywords from recipe content
 * Matches the Swift PublicRecipe.generateSearchKeywords logic
 */
export function generateSearchKeywords(
  title: string,
  ingredients: string[],
  creatorName: string
): string[] {
  const keywords = new Set<string>();

  // Add title words
  const titleWords = extractWords(title);
  titleWords.forEach((word) => keywords.add(word));

  // Add ingredient words
  ingredients.forEach((ingredient) => {
    const ingredientWords = extractWords(ingredient);
    ingredientWords.forEach((word) => keywords.add(word));
  });

  // Add creator name words
  const creatorWords = extractWords(creatorName);
  creatorWords.forEach((word) => keywords.add(word));

  // Convert to sorted array
  return Array.from(keywords).sort();
}

/**
 * Extract searchable words from a string
 * - Converts to lowercase
 * - Splits on non-alphanumeric characters
 * - Filters words >= 3 characters
 * - Removes stop words and numbers
 */
function extractWords(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((word) => {
      // Must be at least 3 characters
      if (word.length < 3) return false;

      // Skip pure numbers
      if (/^\d+$/.test(word)) return false;

      // Skip stop words
      if (STOP_WORDS.has(word)) return false;

      return true;
    });
}

/**
 * Generate keywords specifically for a recipe
 * Includes tags and category as well
 */
export function generateRecipeKeywords(recipe: {
  title: string;
  ingredients: string[];
  creatorName: string;
  tags?: string[];
  category?: string;
}): string[] {
  const keywords = new Set<string>();

  // Base keywords from title, ingredients, creator
  const baseKeywords = generateSearchKeywords(
    recipe.title,
    recipe.ingredients,
    recipe.creatorName
  );
  baseKeywords.forEach((word) => keywords.add(word));

  // Add tag words
  if (recipe.tags) {
    recipe.tags.forEach((tag) => {
      const tagWords = extractWords(tag);
      tagWords.forEach((word) => keywords.add(word));
    });
  }

  // Add category words
  if (recipe.category) {
    const categoryWords = extractWords(recipe.category);
    categoryWords.forEach((word) => keywords.add(word));
  }

  return Array.from(keywords).sort();
}
