/**
 * Screenshot Demo Data Seeding
 *
 * Creates collections and recipes optimized for App Store screenshot capture (CAP_07B).
 * Images should be generated in-app for consistent styling.
 *
 * Collections created:
 * - Weeknight Dinners (6 recipes)
 * - Holiday Baking (4 recipes)
 * - Quick Lunches (3 recipes)
 * - Family Favorites (4 recipes)
 * - Desserts (5 recipes)
 *
 * Workflow:
 * 1. Run this script to seed data: npx ts-node src/screenshot-demo/seed.ts seed <userId>
 * 2. Open app and sync
 * 3. Generate recipe images via app's image generation
 * 4. Generate collection backgrounds via app's image generation
 * 5. Capture screenshots
 *
 * Run with: npx ts-node src/screenshot-demo/seed.ts seed <userId>
 */

import { initializeFirebase, getDb, toTimestamp, daysAgo } from '../utils/firebase';
import { v4 as uuidv4, v5 as uuidv5 } from 'uuid';
import * as crypto from 'crypto';

// Namespace UUID for generating deterministic recipe IDs
// This ensures the same recipe title always gets the same UUID
const RECIPE_NAMESPACE = '6ba7b810-9dad-11d1-80b4-00c04fd430c8'; // Standard DNS namespace

/**
 * Generate a deterministic UUID from a string (recipe title + collection name)
 * This prevents duplicates when re-running the seed script
 */
export function generateDeterministicId(title: string, collectionName: string): string {
  const input = `${collectionName}:${title}`.toLowerCase();
  return uuidv5(input, RECIPE_NAMESPACE);
}

/**
 * Convert a recipe title to a URL-safe slug
 * e.g. "One-Pan Lemon Herb Chicken" → "one_pan_lemon_herb_chicken"
 */
export function toSlug(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

/**
 * Get the global seed image URL for a recipe
 * Images live at seed/demo/ in Firebase Storage and are shared across all users
 */
export function seedImageUrl(title: string): string {
  return `${SEED_IMAGE_BASE}/seed_${toSlug(title)}-image.webp`;
}

// Firebase Storage base URL for seed recipe images (global, not user-specific)
const SEED_IMAGE_BASE = 'https://storage.googleapis.com/heirloom-ios-prod.firebasestorage.app/seed/demo';

// ============================================================================
// Ingredient Parsing
// ============================================================================

interface ParsedIngredient {
  originalText: string;
  quantity: number | null;
  quantityMax: number | null;
  unit: string | null;
  name: string;
}

/**
 * Parse an ingredient string like "2 cups flour" into structured data
 */
function parseIngredient(text: string): ParsedIngredient {
  const trimmed = text.trim();

  // Regex to match: optional quantity (including fractions), optional unit, then name
  // Examples: "2 cups flour", "1/2 tsp salt", "3-4 large eggs", "Salt to taste"
  const quantityPattern = /^(\d+(?:\/\d+)?(?:\s*-\s*\d+(?:\/\d+)?)?|\d+\.?\d*)\s*/;
  const unitPattern = /^(cups?|tbsps?|tablespoons?|tsps?|teaspoons?|oz|ounces?|lbs?|pounds?|grams?|g|kg|ml|liters?|l|pinch(?:es)?|cloves?|pieces?|slices?|sprigs?|bunche?s?|cans?|packages?|sticks?)\s+/i;

  let remaining = trimmed;
  let quantity: number | null = null;
  let quantityMax: number | null = null;
  let unit: string | null = null;

  // Extract quantity
  const qtyMatch = remaining.match(quantityPattern);
  if (qtyMatch) {
    const qtyStr = qtyMatch[1];
    remaining = remaining.slice(qtyMatch[0].length);

    // Handle range like "3-4"
    if (qtyStr.includes('-')) {
      const parts = qtyStr.split('-').map(p => p.trim());
      quantity = parseFraction(parts[0]);
      quantityMax = parseFraction(parts[1]);
    } else {
      quantity = parseFraction(qtyStr);
    }
  }

  // Extract unit
  const unitMatch = remaining.match(unitPattern);
  if (unitMatch) {
    unit = normalizeUnit(unitMatch[1]);
    remaining = remaining.slice(unitMatch[0].length);
  }

  // The rest is the name
  const name = remaining.trim() || trimmed;

  return {
    originalText: trimmed,
    quantity,
    quantityMax,
    unit,
    name,
  };
}

function parseFraction(str: string): number {
  str = str.trim();
  if (str.includes('/')) {
    const [num, denom] = str.split('/').map(Number);
    return num / denom;
  }
  return parseFloat(str);
}

function normalizeUnit(unit: string): string {
  const lower = unit.toLowerCase();
  const unitMap: { [key: string]: string } = {
    'cup': 'cup', 'cups': 'cup',
    'tbsp': 'tbsp', 'tbsps': 'tbsp', 'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
    'tsp': 'tsp', 'tsps': 'tsp', 'teaspoon': 'tsp', 'teaspoons': 'tsp',
    'oz': 'oz', 'ounce': 'oz', 'ounces': 'oz',
    'lb': 'lb', 'lbs': 'lb', 'pound': 'lb', 'pounds': 'lb',
    'gram': 'g', 'grams': 'g', 'g': 'g',
    'kg': 'kg',
    'ml': 'ml',
    'liter': 'l', 'liters': 'l', 'l': 'l',
    'pinch': 'pinch', 'pinches': 'pinch',
    'clove': 'clove', 'cloves': 'clove',
    'piece': 'piece', 'pieces': 'piece',
    'slice': 'slice', 'slices': 'slice',
    'sprig': 'sprig', 'sprigs': 'sprig',
    'bunch': 'bunch', 'bunches': 'bunch',
    'can': 'can', 'cans': 'can',
    'package': 'package', 'packages': 'package',
    'stick': 'stick', 'sticks': 'stick',
  };
  return unitMap[lower] || lower;
}

// ============================================================================
// Types
// ============================================================================

interface ScreenshotCollection {
  id: string;
  name: string;
  desc: string;
  iconName: string;
  color: string;
  collectionType: string;
  customBackgroundImagePath: string | null; // "preset-xxx-bg" for asset catalog
  useCustomBackground: boolean;
  recipeCount: number;
}

export interface ScreenshotRecipe {
  id: string;
  title: string;
  description: string;
  category: string;
  tags: string[];
  servings: string;
  prepTime: string;
  cookTime: string;
  ingredients: string[];
  instructions: string[];
  imagePrompt: string; // For generating the image
  imageUrl?: string; // Firebase Storage URL for recipe thumbnail
}

// ============================================================================
// Screenshot Collections
// ============================================================================

export const SCREENSHOT_COLLECTIONS: ScreenshotCollection[] = [
  {
    id: uuidv4(),
    name: 'Weeknight Dinners',
    desc: 'Quick and easy dinners for busy weeknights',
    iconName: 'fork.knife',
    color: '#FF6B6B',
    collectionType: 'userCreated',
    customBackgroundImagePath: null, // Generate via app for consistent style
    useCustomBackground: false,
    recipeCount: 6,
  },
  {
    id: uuidv4(),
    name: 'Holiday Baking',
    desc: 'Festive treats for special occasions',
    iconName: 'gift.fill',
    color: '#8B4513',
    collectionType: 'userCreated',
    customBackgroundImagePath: null,
    useCustomBackground: false,
    recipeCount: 4,
  },
  {
    id: uuidv4(),
    name: 'Quick Lunches',
    desc: 'Ready in 30 minutes or less',
    iconName: 'clock.fill',
    color: '#4ECDC4',
    collectionType: 'userCreated',
    customBackgroundImagePath: null,
    useCustomBackground: false,
    recipeCount: 3,
  },
  {
    id: uuidv4(),
    name: 'Family Favorites',
    desc: 'Recipes passed down through generations',
    iconName: 'heart.fill',
    color: '#E74C3C',
    collectionType: 'userCreated',
    customBackgroundImagePath: null,
    useCustomBackground: false,
    recipeCount: 4,
  },
  {
    id: uuidv4(),
    name: 'Desserts',
    desc: 'Sweet treats and indulgences',
    iconName: 'birthday.cake.fill',
    color: '#9B59B6',
    collectionType: 'userCreated',
    customBackgroundImagePath: null,
    useCustomBackground: false,
    recipeCount: 5,
  },
];

// ============================================================================
// Screenshot Recipes by Collection
// ============================================================================

const WEEKNIGHT_DINNER_RECIPES: ScreenshotRecipe[] = [
  {
    id: uuidv4(),
    title: 'One-Pan Lemon Herb Chicken',
    description: 'Juicy chicken thighs with roasted vegetables, all in one pan. Perfect for busy weeknights with minimal cleanup.',
    category: 'Dinner',
    tags: ['Chicken', 'One-Pan', 'Quick', 'Healthy'],
    servings: '4 servings',
    prepTime: '10',
    cookTime: '35',
    ingredients: [
      '4 bone-in chicken thighs',
      '1 lb baby potatoes, halved',
      '2 cups green beans',
      '3 tbsp olive oil',
      '2 lemons',
      '4 cloves garlic, minced',
      '1 tbsp fresh rosemary',
      'Salt and pepper to taste',
    ],
    instructions: [
      'Preheat oven to 425°F (220°C).',
      'Toss potatoes with 1 tbsp olive oil, salt, and pepper. Spread on a baking sheet.',
      'Season chicken thighs with remaining oil, garlic, rosemary, lemon zest, salt, and pepper.',
      'Nestle chicken among potatoes. Roast for 20 minutes.',
      'Add green beans to the pan. Roast another 15 minutes until chicken is cooked through.',
      'Squeeze lemon juice over everything and serve.',
    ],
    imagePrompt: 'overhead shot of one-pan roasted chicken thighs with baby potatoes and green beans, lemon wedges, rustic ceramic plate, warm lighting, food photography',
  },
  {
    id: uuidv4(),
    title: '15-Minute Shrimp Stir Fry',
    description: 'Quick and flavorful shrimp with crisp vegetables in a savory garlic ginger sauce.',
    category: 'Dinner',
    tags: ['Shrimp', 'Quick', 'Asian', 'Healthy'],
    servings: '4 servings',
    prepTime: '5',
    cookTime: '10',
    ingredients: [
      '1 lb large shrimp, peeled and deveined',
      '2 cups broccoli florets',
      '1 red bell pepper, sliced',
      '3 tbsp soy sauce',
      '1 tbsp sesame oil',
      '2 cloves garlic, minced',
      '1 inch fresh ginger, grated',
      'Rice for serving',
    ],
    instructions: [
      'Heat sesame oil in a large wok over high heat.',
      'Add shrimp and cook 2 minutes per side. Remove and set aside.',
      'Add broccoli and bell pepper. Stir fry 3-4 minutes.',
      'Add garlic and ginger. Cook 30 seconds until fragrant.',
      'Return shrimp to wok. Add soy sauce and toss to combine.',
      'Serve immediately over rice.',
    ],
    imagePrompt: 'colorful shrimp stir fry in a black wok, broccoli, red bell peppers, garlic, steam rising, asian cooking style, food photography',
  },
  {
    id: uuidv4(),
    title: 'Creamy Tuscan Pasta',
    description: 'Rich and creamy pasta with sun-dried tomatoes, spinach, and parmesan. Restaurant-quality in 25 minutes.',
    category: 'Dinner',
    tags: ['Pasta', 'Italian', 'Creamy', 'Vegetarian'],
    servings: '4 servings',
    prepTime: '5',
    cookTime: '20',
    ingredients: [
      '12 oz penne pasta',
      '1 cup heavy cream',
      '1/2 cup sun-dried tomatoes',
      '3 cups fresh spinach',
      '1/2 cup parmesan, grated',
      '3 cloves garlic, minced',
      '2 tbsp olive oil',
      'Italian seasoning',
    ],
    instructions: [
      'Cook pasta according to package directions. Reserve 1 cup pasta water.',
      'In a large skillet, heat olive oil. Sauté garlic 30 seconds.',
      'Add sun-dried tomatoes and cook 2 minutes.',
      'Pour in heavy cream. Simmer 5 minutes.',
      'Add spinach and stir until wilted.',
      'Toss in pasta and parmesan. Add pasta water if needed.',
    ],
    imagePrompt: 'creamy tuscan pasta in a white bowl, sun-dried tomatoes, spinach, parmesan cheese, rustic wooden table, warm lighting, food photography',
  },
  {
    id: uuidv4(),
    title: 'Honey Garlic Salmon',
    description: 'Perfectly glazed salmon fillets with a sweet and savory honey garlic sauce. Ready in 20 minutes.',
    category: 'Dinner',
    tags: ['Salmon', 'Quick', 'Healthy', 'Glazed'],
    servings: '4 servings',
    prepTime: '5',
    cookTime: '15',
    ingredients: [
      '4 salmon fillets',
      '3 tbsp honey',
      '2 tbsp soy sauce',
      '4 cloves garlic, minced',
      '1 tbsp olive oil',
      '1 lemon, juiced',
      'Fresh parsley for garnish',
    ],
    instructions: [
      'Mix honey, soy sauce, garlic, and lemon juice in a bowl.',
      'Heat olive oil in an oven-safe skillet over medium-high heat.',
      'Sear salmon skin-side up for 3 minutes.',
      'Flip salmon and pour glaze over fillets.',
      'Transfer to 400°F oven for 8-10 minutes.',
      'Garnish with parsley and serve.',
    ],
    imagePrompt: 'honey garlic glazed salmon fillet on a plate with glaze dripping, lemon wedge, fresh parsley, elegant plating, food photography',
  },
  {
    id: uuidv4(),
    title: 'Sheet Pan Fajitas',
    description: 'Sizzling chicken fajitas with colorful peppers and onions. Minimal prep, maximum flavor.',
    category: 'Dinner',
    tags: ['Mexican', 'Chicken', 'Sheet Pan', 'Easy'],
    servings: '6 servings',
    prepTime: '10',
    cookTime: '25',
    ingredients: [
      '1.5 lbs chicken breast, sliced',
      '3 bell peppers, sliced',
      '1 large onion, sliced',
      '2 tbsp fajita seasoning',
      '3 tbsp olive oil',
      'Lime wedges',
      'Tortillas for serving',
      'Sour cream, salsa, guacamole',
    ],
    instructions: [
      'Preheat oven to 400°F (200°C).',
      'Toss chicken and vegetables with oil and seasoning.',
      'Spread in a single layer on a large baking sheet.',
      'Roast for 25 minutes, stirring halfway through.',
      'Squeeze lime juice over everything.',
      'Serve with warm tortillas and toppings.',
    ],
    imagePrompt: 'sizzling sheet pan chicken fajitas with colorful bell peppers, onions, lime wedges, tortillas on the side, mexican style, food photography',
  },
  {
    id: uuidv4(),
    title: 'Beef and Broccoli',
    description: 'Better than takeout! Tender beef strips with crisp broccoli in a savory brown sauce.',
    category: 'Dinner',
    tags: ['Beef', 'Asian', 'Quick', 'Stir Fry'],
    servings: '4 servings',
    prepTime: '10',
    cookTime: '15',
    ingredients: [
      '1 lb flank steak, thinly sliced',
      '4 cups broccoli florets',
      '3 tbsp soy sauce',
      '2 tbsp oyster sauce',
      '1 tbsp cornstarch',
      '3 cloves garlic',
      '1 tbsp sesame oil',
      'Rice for serving',
    ],
    instructions: [
      'Mix soy sauce, oyster sauce, and cornstarch in a bowl.',
      'Blanch broccoli in boiling water 2 minutes. Drain.',
      'Heat sesame oil in a wok over high heat.',
      'Stir fry beef 2-3 minutes until browned. Remove.',
      'Add garlic, then broccoli. Stir fry 2 minutes.',
      'Return beef, add sauce, and toss until thickened.',
    ],
    imagePrompt: 'beef and broccoli stir fry in a dark ceramic bowl, glossy brown sauce, sesame seeds, steam rising, asian cuisine, food photography',
  },
];

const HOLIDAY_BAKING_RECIPES: ScreenshotRecipe[] = [
  {
    id: uuidv4(),
    title: 'Classic Sugar Cookies',
    description: 'Buttery, soft sugar cookies perfect for decorating. A holiday tradition in our family for generations.',
    category: 'Dessert',
    tags: ['Cookies', 'Holiday', 'Baking', 'Christmas'],
    servings: '36 cookies',
    prepTime: '30',
    cookTime: '10',
    ingredients: [
      '3 cups all-purpose flour',
      '1 cup butter, softened',
      '1 cup sugar',
      '1 egg',
      '1 tsp vanilla extract',
      '1/2 tsp almond extract',
      '1/2 tsp baking powder',
      'Royal icing for decorating',
    ],
    instructions: [
      'Cream butter and sugar until fluffy.',
      'Beat in egg, vanilla, and almond extract.',
      'Mix flour and baking powder. Gradually add to wet ingredients.',
      'Chill dough 1 hour.',
      'Roll out and cut into shapes. Bake at 350°F for 8-10 minutes.',
      'Cool completely before decorating with royal icing.',
    ],
    imagePrompt: 'beautifully decorated holiday sugar cookies with royal icing, christmas shapes, stars, trees, snowflakes, festive colors, baking photography',
  },
  {
    id: uuidv4(),
    title: 'Gingerbread Loaf',
    description: 'Warm spices and rich molasses make this loaf the taste of the holidays. Perfect with coffee.',
    category: 'Dessert',
    tags: ['Bread', 'Holiday', 'Gingerbread', 'Christmas'],
    servings: '10 slices',
    prepTime: '15',
    cookTime: '55',
    ingredients: [
      '2 cups flour',
      '1/2 cup molasses',
      '1/2 cup butter, melted',
      '1/2 cup brown sugar',
      '2 eggs',
      '2 tsp ground ginger',
      '1 tsp cinnamon',
      '1/2 tsp cloves',
    ],
    instructions: [
      'Preheat oven to 350°F. Grease a 9x5 loaf pan.',
      'Whisk together flour and spices.',
      'In another bowl, mix molasses, butter, sugar, and eggs.',
      'Combine wet and dry ingredients until just mixed.',
      'Pour into prepared pan. Bake 50-55 minutes.',
      'Cool before slicing. Dust with powdered sugar.',
    ],
    imagePrompt: 'sliced gingerbread loaf on a wooden cutting board, powdered sugar dusted on top, warm holiday lighting, cozy atmosphere, baking photography',
  },
  {
    id: uuidv4(),
    title: 'Peppermint Bark',
    description: 'Layers of dark and white chocolate with crushed candy canes. The perfect homemade gift.',
    category: 'Dessert',
    tags: ['Candy', 'Christmas', 'No-Bake', 'Gift'],
    servings: '20 pieces',
    prepTime: '20',
    cookTime: '0',
    ingredients: [
      '12 oz dark chocolate',
      '12 oz white chocolate',
      '1 tsp peppermint extract',
      '6 candy canes, crushed',
      '1 tbsp coconut oil',
    ],
    instructions: [
      'Line a baking sheet with parchment paper.',
      'Melt dark chocolate with half the coconut oil. Spread evenly on sheet.',
      'Refrigerate 15 minutes until set.',
      'Melt white chocolate with remaining oil and peppermint extract.',
      'Spread over dark chocolate layer. Sprinkle with crushed candy canes.',
      'Refrigerate until firm. Break into pieces.',
    ],
    imagePrompt: 'layered peppermint bark pieces with dark and white chocolate, crushed candy canes on top, festive red and white colors, holiday candy, food photography',
  },
  {
    id: uuidv4(),
    title: 'Apple Pie with Lattice Crust',
    description: 'The quintessential holiday pie with a beautiful lattice top. Grandma\'s recipe perfected over 50 years.',
    category: 'Dessert',
    tags: ['Pie', 'Apple', 'Holiday', 'Thanksgiving'],
    servings: '8 slices',
    prepTime: '45',
    cookTime: '60',
    ingredients: [
      '6 cups sliced apples',
      '3/4 cup sugar',
      '2 tbsp flour',
      '1 tsp cinnamon',
      '1/4 tsp nutmeg',
      'Double pie crust',
      '2 tbsp butter',
      '1 egg for wash',
    ],
    instructions: [
      'Toss apples with sugar, flour, cinnamon, and nutmeg.',
      'Line pie dish with bottom crust. Add apple filling. Dot with butter.',
      'Create lattice top with remaining dough.',
      'Brush with egg wash.',
      'Bake at 425°F for 15 minutes, then 350°F for 45 minutes.',
      'Cool at least 2 hours before serving.',
    ],
    imagePrompt: 'golden brown apple pie with beautiful lattice crust, baked in ceramic dish, cinnamon stick garnish, warm rustic setting, thanksgiving dessert, food photography',
  },
];

const QUICK_LUNCH_RECIPES: ScreenshotRecipe[] = [
  {
    id: uuidv4(),
    title: 'Mediterranean Wrap',
    description: 'Fresh and flavorful wrap with hummus, feta, and crisp vegetables. Ready in 10 minutes.',
    category: 'Lunch',
    tags: ['Wrap', 'Mediterranean', 'Quick', 'Healthy'],
    servings: '2 wraps',
    prepTime: '10',
    cookTime: '0',
    ingredients: [
      '2 large flour tortillas',
      '1/2 cup hummus',
      '1 cup mixed greens',
      '1/2 cucumber, sliced',
      '1/4 cup feta cheese',
      '1/4 cup kalamata olives',
      'Cherry tomatoes',
      'Red onion slices',
    ],
    instructions: [
      'Spread hummus evenly over each tortilla.',
      'Layer mixed greens down the center.',
      'Add cucumber, tomatoes, olives, and onion.',
      'Sprinkle feta cheese on top.',
      'Fold in sides and roll tightly.',
      'Cut in half diagonally and serve.',
    ],
    imagePrompt: 'mediterranean wrap cut in half showing colorful layers, hummus, feta, vegetables, olives, on a white plate, fresh and healthy, food photography',
  },
  {
    id: uuidv4(),
    title: 'Asian Chicken Salad',
    description: 'Crunchy, colorful salad with sesame ginger dressing. Perfect for meal prep.',
    category: 'Lunch',
    tags: ['Salad', 'Asian', 'Chicken', 'Healthy'],
    servings: '2 servings',
    prepTime: '15',
    cookTime: '0',
    ingredients: [
      '2 cups shredded rotisserie chicken',
      '4 cups napa cabbage, shredded',
      '1 cup edamame',
      '1 carrot, julienned',
      '1/4 cup crispy wonton strips',
      'Sesame ginger dressing',
      'Toasted sesame seeds',
    ],
    instructions: [
      'Combine cabbage, carrot, and edamame in a large bowl.',
      'Top with shredded chicken.',
      'Add wonton strips for crunch.',
      'Drizzle with sesame ginger dressing.',
      'Toss to combine and sprinkle with sesame seeds.',
      'Serve immediately.',
    ],
    imagePrompt: 'colorful asian chicken salad in a white bowl, shredded cabbage, carrots, edamame, crispy wontons, sesame seeds, fresh and crunchy, food photography',
  },
  {
    id: uuidv4(),
    title: 'Caprese Panini',
    description: 'Warm, melty mozzarella with fresh tomatoes and basil on crispy bread.',
    category: 'Lunch',
    tags: ['Sandwich', 'Italian', 'Quick', 'Vegetarian'],
    servings: '2 sandwiches',
    prepTime: '5',
    cookTime: '8',
    ingredients: [
      '4 slices ciabatta bread',
      '8 oz fresh mozzarella, sliced',
      '2 tomatoes, sliced',
      'Fresh basil leaves',
      'Balsamic glaze',
      '2 tbsp olive oil',
      'Salt and pepper',
    ],
    instructions: [
      'Brush bread slices with olive oil.',
      'Layer mozzarella, tomato, and basil on bottom slices.',
      'Season with salt and pepper. Top with remaining bread.',
      'Grill in panini press or skillet 3-4 minutes per side.',
      'Drizzle with balsamic glaze.',
      'Cut in half and serve warm.',
    ],
    imagePrompt: 'grilled caprese panini with melted mozzarella oozing out, fresh tomatoes, basil, balsamic glaze drizzle, on wooden cutting board, food photography',
  },
];

const FAMILY_FAVORITES_RECIPES: ScreenshotRecipe[] = [
  {
    id: uuidv4(),
    title: 'Mom\'s Meatloaf',
    description: 'The recipe my mother made every Sunday. Comfort food at its finest with a tangy glaze.',
    category: 'Dinner',
    tags: ['Meatloaf', 'Comfort Food', 'Family', 'Classic'],
    servings: '8 servings',
    prepTime: '15',
    cookTime: '60',
    ingredients: [
      '2 lbs ground beef',
      '1 cup breadcrumbs',
      '1 onion, diced',
      '2 eggs',
      '1/2 cup ketchup',
      '2 tbsp Worcestershire',
      '1/2 cup milk',
      'Salt and pepper',
    ],
    instructions: [
      'Preheat oven to 350°F.',
      'Mix beef, breadcrumbs, onion, eggs, 1/4 cup ketchup, Worcestershire, milk, salt, and pepper.',
      'Form into a loaf on a baking sheet.',
      'Top with remaining ketchup.',
      'Bake 1 hour until internal temp reaches 160°F.',
      'Rest 10 minutes before slicing.',
    ],
    imagePrompt: 'classic glazed meatloaf sliced on a platter, rich ketchup glaze, comfort food, homestyle cooking, warm family dinner setting, food photography',
  },
  {
    id: uuidv4(),
    title: 'Grandma\'s Chicken Soup',
    description: 'The healing soup that\'s been in our family for four generations. Made with love.',
    category: 'Soup',
    tags: ['Soup', 'Chicken', 'Comfort Food', 'Heritage'],
    servings: '8 servings',
    prepTime: '20',
    cookTime: '90',
    ingredients: [
      '1 whole chicken',
      '4 carrots, chopped',
      '4 celery stalks, chopped',
      '1 onion, quartered',
      '8 cups water',
      'Fresh dill',
      'Egg noodles',
      'Salt and pepper',
    ],
    instructions: [
      'Place chicken, onion, and half the carrots and celery in a large pot.',
      'Cover with water. Bring to a boil, then simmer 1 hour.',
      'Remove chicken. Strain broth and return to pot.',
      'Shred chicken, discarding skin and bones.',
      'Add remaining vegetables and cook 20 minutes.',
      'Add noodles, chicken, and dill. Simmer 10 more minutes.',
    ],
    imagePrompt: 'homemade chicken noodle soup in a ceramic bowl, egg noodles, carrots, celery, fresh dill garnish, steam rising, comfort food, food photography',
  },
  {
    id: uuidv4(),
    title: 'Nana\'s Pot Roast',
    description: 'Fall-apart tender beef with root vegetables. Sunday dinner tradition since 1952.',
    category: 'Dinner',
    tags: ['Beef', 'Pot Roast', 'Sunday Dinner', 'Heritage'],
    servings: '6 servings',
    prepTime: '20',
    cookTime: '180',
    ingredients: [
      '3 lb chuck roast',
      '1 lb baby potatoes',
      '4 carrots, chunked',
      '2 cups beef broth',
      '1 onion, quartered',
      '4 cloves garlic',
      'Fresh thyme',
      'Salt and pepper',
    ],
    instructions: [
      'Preheat oven to 325°F.',
      'Season roast generously with salt and pepper.',
      'Sear on all sides in a hot Dutch oven.',
      'Add broth, onion, garlic, and thyme.',
      'Cover and braise 2 hours.',
      'Add potatoes and carrots. Cook 1 more hour until tender.',
    ],
    imagePrompt: 'tender pot roast with carrots and potatoes in cast iron dutch oven, rich gravy, fresh thyme sprigs, rustic comfort food, food photography',
  },
  {
    id: uuidv4(),
    title: 'Dad\'s Pancakes',
    description: 'Fluffy, golden pancakes that Dad made every Saturday morning. Now I make them for my kids.',
    category: 'Breakfast',
    tags: ['Pancakes', 'Breakfast', 'Family', 'Classic'],
    servings: '12 pancakes',
    prepTime: '10',
    cookTime: '15',
    ingredients: [
      '2 cups flour',
      '2 cups buttermilk',
      '2 eggs',
      '2 tbsp sugar',
      '2 tbsp melted butter',
      '1 tsp baking powder',
      '1/2 tsp baking soda',
      'Maple syrup for serving',
    ],
    instructions: [
      'Whisk dry ingredients together in a large bowl.',
      'In another bowl, mix buttermilk, eggs, and melted butter.',
      'Combine wet and dry ingredients. Don\'t overmix.',
      'Heat a griddle over medium heat. Lightly butter.',
      'Pour 1/4 cup batter per pancake. Cook until bubbles form.',
      'Flip and cook until golden. Serve with maple syrup.',
    ],
    imagePrompt: 'stack of fluffy golden pancakes with butter pat on top, maple syrup drizzling down, breakfast table setting, warm morning light, food photography',
  },
];

const DESSERT_RECIPES: ScreenshotRecipe[] = [
  {
    id: uuidv4(),
    title: 'New York Cheesecake',
    description: 'Dense, creamy, and absolutely indulgent. The only cheesecake recipe you\'ll ever need.',
    category: 'Dessert',
    tags: ['Cheesecake', 'Classic', 'Baking', 'Party'],
    servings: '12 slices',
    prepTime: '30',
    cookTime: '90',
    ingredients: [
      '32 oz cream cheese, softened',
      '1 cup sugar',
      '5 eggs',
      '1 cup sour cream',
      '2 tsp vanilla extract',
      '2 cups graham cracker crumbs',
      '1/2 cup butter, melted',
    ],
    instructions: [
      'Mix graham cracker crumbs with butter. Press into springform pan.',
      'Beat cream cheese and sugar until smooth.',
      'Add eggs one at a time, then sour cream and vanilla.',
      'Pour over crust. Bake at 325°F for 75 minutes.',
      'Turn off oven, crack door, and let cool 1 hour inside.',
      'Refrigerate overnight before serving.',
    ],
    imagePrompt: 'slice of creamy new york cheesecake on a plate with berry compote, graham cracker crust visible, elegant dessert presentation, food photography',
  },
  {
    id: uuidv4(),
    title: 'Chocolate Lava Cakes',
    description: 'Warm chocolate cakes with a molten center. Easier than they look, absolutely impressive.',
    category: 'Dessert',
    tags: ['Chocolate', 'Elegant', 'Quick', 'Romantic'],
    servings: '4 cakes',
    prepTime: '15',
    cookTime: '14',
    ingredients: [
      '4 oz dark chocolate',
      '1/2 cup butter',
      '1 cup powdered sugar',
      '2 eggs',
      '2 egg yolks',
      '6 tbsp flour',
      'Vanilla ice cream for serving',
    ],
    instructions: [
      'Preheat oven to 425°F. Grease 4 ramekins.',
      'Melt chocolate and butter together. Stir in sugar.',
      'Whisk in eggs and egg yolks.',
      'Fold in flour until just combined.',
      'Divide among ramekins. Bake 12-14 minutes.',
      'Invert onto plates and serve immediately with ice cream.',
    ],
    imagePrompt: 'chocolate lava cake with molten center flowing out, dusted with powdered sugar, vanilla ice cream on side, elegant dessert plating, food photography',
  },
  {
    id: uuidv4(),
    title: 'Classic Tiramisu',
    description: 'Layers of espresso-soaked ladyfingers and mascarpone cream. A showstopping Italian dessert.',
    category: 'Dessert',
    tags: ['Italian', 'Coffee', 'No-Bake', 'Elegant'],
    servings: '9 servings',
    prepTime: '30',
    cookTime: '0',
    ingredients: [
      '6 egg yolks',
      '3/4 cup sugar',
      '16 oz mascarpone cheese',
      '2 cups heavy cream',
      '2 cups espresso, cooled',
      '3 tbsp coffee liqueur',
      '30 ladyfinger cookies',
      'Cocoa powder',
    ],
    instructions: [
      'Whisk egg yolks and sugar over simmering water until thick.',
      'Remove from heat and whisk in mascarpone.',
      'Whip heavy cream to stiff peaks. Fold into mascarpone mixture.',
      'Mix espresso and liqueur. Dip ladyfingers briefly.',
      'Layer in dish: ladyfingers, cream, ladyfingers, cream.',
      'Refrigerate 4 hours. Dust with cocoa before serving.',
    ],
    imagePrompt: 'tiramisu in a glass dish showing layers, cocoa powder dusted on top, coffee beans as decoration, elegant italian dessert, food photography',
  },
  {
    id: uuidv4(),
    title: 'Homemade Brownies',
    description: 'Fudgy, rich, and perfectly chocolatey. The gold standard of brownies.',
    category: 'Dessert',
    tags: ['Brownies', 'Chocolate', 'Baking', 'Classic'],
    servings: '16 brownies',
    prepTime: '15',
    cookTime: '30',
    ingredients: [
      '1 cup butter',
      '2 cups sugar',
      '4 eggs',
      '1 cup cocoa powder',
      '1 cup flour',
      '1/2 tsp salt',
      '1 tsp vanilla',
      '1 cup chocolate chips',
    ],
    instructions: [
      'Preheat oven to 350°F. Line 9x13 pan with parchment.',
      'Melt butter. Stir in sugar and let cool slightly.',
      'Beat in eggs and vanilla.',
      'Mix in cocoa, flour, and salt.',
      'Fold in chocolate chips. Spread in pan.',
      'Bake 28-32 minutes. Cool completely before cutting.',
    ],
    imagePrompt: 'stack of fudgy chocolate brownies with crackly top, chocolate chips visible, on parchment paper, warm comfort dessert, food photography',
  },
  {
    id: uuidv4(),
    title: 'Crème Brûlée',
    description: 'Silky vanilla custard with a satisfying crackle of caramelized sugar on top.',
    category: 'Dessert',
    tags: ['French', 'Custard', 'Elegant', 'Classic'],
    servings: '6 servings',
    prepTime: '20',
    cookTime: '50',
    ingredients: [
      '2 cups heavy cream',
      '5 egg yolks',
      '1/2 cup sugar plus more for topping',
      '1 vanilla bean',
      'Pinch of salt',
    ],
    instructions: [
      'Preheat oven to 325°F.',
      'Heat cream with vanilla bean until simmering.',
      'Whisk yolks and sugar until pale.',
      'Slowly temper hot cream into yolks.',
      'Pour into ramekins. Bake in water bath 45-50 minutes.',
      'Chill overnight. Sprinkle sugar and torch before serving.',
    ],
    imagePrompt: 'creme brulee in white ramekin with perfectly caramelized sugar top, vanilla bean pod beside, elegant french dessert, food photography',
  },
];

// Map collections to their recipes
export const COLLECTION_RECIPES: { [key: string]: ScreenshotRecipe[] } = {
  'Weeknight Dinners': WEEKNIGHT_DINNER_RECIPES,
  'Holiday Baking': HOLIDAY_BAKING_RECIPES,
  'Quick Lunches': QUICK_LUNCH_RECIPES,
  'Family Favorites': FAMILY_FAVORITES_RECIPES,
  'Desserts': DESSERT_RECIPES,
};

// Note: DEMO_IMAGE_BASE and COLLECTION_IMAGE_POOLS removed.
// Seed recipe images now use deterministic URLs via seedImageUrl().
// Run `npx ts-node src/generate-seed-images.ts` once to populate them.

// ============================================================================
// Main Seeding Functions
// ============================================================================

async function seedScreenshotDemoForUser(userId: string): Promise<void> {
  const db = getDb();

  console.log(`\nSeeding screenshot demo data for user: ${userId}`);
  console.log('='.repeat(60));

  // Track recipe IDs for each collection
  const collectionRecipeIds: { [collectionId: string]: string[] } = {};

  // First, seed all recipes and store their IDs
  for (const collection of SCREENSHOT_COLLECTIONS) {
    const recipes = COLLECTION_RECIPES[collection.name];
    if (!recipes) continue;

    // Generate deterministic collection ID based on name
    const collectionId = generateDeterministicId(collection.name, 'collection');

    console.log(`\nPreparing ${recipes.length} recipes for "${collection.name}"...`);
    collectionRecipeIds[collectionId] = [];

    for (let recipeIndex = 0; recipeIndex < recipes.length; recipeIndex++) {
      const recipe = recipes[recipeIndex];
      // Generate deterministic recipe ID based on title + collection
      const recipeId = generateDeterministicId(recipe.title, collection.name);
      const recipeRef = db.doc(`users/${userId}/recipes/${recipeId}`);

      const now = new Date();

      // Use the deterministic global seed image URL for this recipe
      // These images are generated once via generate-seed-images.ts and stored at seed/demo/
      const imageUrl: string = seedImageUrl(recipe.title);

      const recipeData = {
        id: recipeId,
        title: recipe.title,
        description: recipe.description,
        category: recipe.category,
        tags: recipe.tags,
        servings: recipe.servings,
        prepTime: recipe.prepTime,
        cookTime: recipe.cookTime,
        instructions: recipe.instructions, // Required: array of instruction strings
        createdAt: toTimestamp(daysAgo(Math.floor(Math.random() * 30) + 1)),
        updatedAt: toTimestamp(now),
        modifiedAt: toTimestamp(now), // Required for sync service to pick up changes
        firebaseImageURL: imageUrl, // Use demo images for thumbnails
        source: 'manual',
        sourceType: 'userEntered',
        visibility: 'private',
        isArchived: false,
        isDemoSeed: true, // Mark for preservation during reset
        collectionIds: [collectionId], // Link recipe to its collection for sync relink
      };

      await recipeRef.set(recipeData);

      // Delete existing ingredients before re-seeding (prevents duplicates)
      const existingIngredients = await db.collection(`users/${userId}/recipes/${recipeId}/ingredients`).get();
      const deleteIngBatch = db.batch();
      for (const doc of existingIngredients.docs) {
        deleteIngBatch.delete(doc.ref);
      }
      if (existingIngredients.size > 0) {
        await deleteIngBatch.commit();
      }

      // Seed ingredients as subcollection (batch write for efficiency)
      const ingredientBatch = db.batch();
      for (let i = 0; i < recipe.ingredients.length; i++) {
        const ingredientId = uuidv4();
        const ingredientRef = db.doc(`users/${userId}/recipes/${recipeId}/ingredients/${ingredientId}`);
        const parsed = parseIngredient(recipe.ingredients[i]);
        ingredientBatch.set(ingredientRef, {
          id: ingredientId,
          originalText: parsed.originalText,
          text: parsed.originalText, // Backward compatibility
          name: parsed.name,
          quantity: parsed.quantity,
          quantityMax: parsed.quantityMax,
          unit: parsed.unit,
          orderIndex: i,
          order: i,
          isChecked: false,
          isSelected: false,
          isCheckedOff: false,
          isOptional: false,
          category: 'other', // Default category
        });
      }
      await ingredientBatch.commit();

      // Delete existing instructions before re-seeding (prevents duplicates)
      const existingInstructions = await db.collection(`users/${userId}/recipes/${recipeId}/instructions`).get();
      const deleteInstBatch = db.batch();
      for (const doc of existingInstructions.docs) {
        deleteInstBatch.delete(doc.ref);
      }
      if (existingInstructions.size > 0) {
        await deleteInstBatch.commit();
      }

      // Seed instructions as subcollection
      const instructionBatch = db.batch();
      for (let i = 0; i < recipe.instructions.length; i++) {
        const instructionId = uuidv4();
        const instructionRef = db.doc(`users/${userId}/recipes/${recipeId}/instructions/${instructionId}`);
        instructionBatch.set(instructionRef, {
          id: instructionId,
          text: recipe.instructions[i],
          orderIndex: i,
        });
      }
      await instructionBatch.commit();

      collectionRecipeIds[collectionId].push(recipeId);
      console.log(`  Created recipe: ${recipe.title}`);
    }
  }

  // Now seed collections with recipe IDs
  console.log('\nCreating collections...');
  for (const collection of SCREENSHOT_COLLECTIONS) {
    // Use same deterministic ID generation as in recipe loop
    const collectionId = generateDeterministicId(collection.name, 'collection');
    const collectionRef = db.doc(`users/${userId}/collections/${collectionId}`);

    const now = new Date();
    const collectionData = {
      id: collectionId,
      name: collection.name,
      desc: collection.desc,
      iconName: collection.iconName,
      color: collection.color,
      collectionType: collection.collectionType,
      customBackgroundImagePath: collection.customBackgroundImagePath,
      useCustomBackground: collection.useCustomBackground,
      createdDate: toTimestamp(daysAgo(60)), // Created 2 months ago
      modifiedAt: toTimestamp(now), // Required for sync service to pick up changes
      recipeIds: collectionRecipeIds[collectionId] || [],
      isDemoSeed: true, // Mark as demo seed so it can be hidden via toggle
    };

    await collectionRef.set(collectionData);
    console.log(`  Created: ${collection.name} (${collectionData.recipeIds.length} recipes)`);
  }

  console.log('\nDone!');

  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('SCREENSHOT DEMO DATA SUMMARY');
  console.log('='.repeat(60));
  console.log(`Collections created: ${SCREENSHOT_COLLECTIONS.length}`);

  let totalRecipes = 0;
  for (const collection of SCREENSHOT_COLLECTIONS) {
    const collectionId = generateDeterministicId(collection.name, 'collection');
    const count = collectionRecipeIds[collectionId]?.length || 0;
    totalRecipes += count;
    const bgStatus = collection.customBackgroundImagePath ? `preset: ${collection.customBackgroundImagePath}` : 'recipe images';
    console.log(`  ${collection.name}: ${count} recipes (${bgStatus})`);
  }

  console.log(`Total recipes: ${totalRecipes}`);
  console.log('\nSync the app to see the demo data.');
}

async function cleanupScreenshotDemo(userId: string): Promise<void> {
  const db = getDb();

  console.log(`\nCleaning up screenshot demo data for user: ${userId}`);

  // Only delete screenshot demo collections (not themes or other collections)
  const screenshotCollectionNames = SCREENSHOT_COLLECTIONS.map(c => c.name);
  const collectionsRef = db.collection(`users/${userId}/collections`);
  const collections = await collectionsRef.get();

  const recipeIdsToDelete: string[] = [];

  for (const doc of collections.docs) {
    const data = doc.data();
    if (screenshotCollectionNames.includes(data.name)) {
      // Collect recipe IDs from this collection before deleting
      if (data.recipeIds && Array.isArray(data.recipeIds)) {
        recipeIdsToDelete.push(...data.recipeIds);
      }
      await doc.ref.delete();
      console.log(`  Deleted collection: ${data.name}`);
    } else {
      console.log(`  Skipping collection: ${data.name} (not a screenshot demo collection)`);
    }
  }

  // Only delete recipes that were in the screenshot demo collections
  if (recipeIdsToDelete.length > 0) {
    console.log(`\nDeleting ${recipeIdsToDelete.length} recipes from screenshot demo collections...`);

    for (const recipeId of recipeIdsToDelete) {
      const recipeRef = db.doc(`users/${userId}/recipes/${recipeId}`);
      const recipeDoc = await recipeRef.get();

      if (recipeDoc.exists) {
        // Delete subcollections first
        const ingredientsRef = recipeRef.collection('ingredients');
        const ingredients = await ingredientsRef.get();
        for (const ing of ingredients.docs) {
          await ing.ref.delete();
        }

        const instructionsRef = recipeRef.collection('instructions');
        const instructions = await instructionsRef.get();
        for (const inst of instructions.docs) {
          await inst.ref.delete();
        }

        await recipeRef.delete();
        console.log(`  Deleted recipe: ${recipeDoc.data()?.title || recipeId}`);
      }
    }
  }

  console.log('\nCleanup complete! Theme collections and recipes were preserved.');
}

// ============================================================================
// Main Entry Point
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const userId = args[1];

  if (!command || !userId) {
    console.error('Usage: npx ts-node src/screenshot-demo/seed.ts <seed|cleanup> <userId>');
    console.error('\nCommands:');
    console.error('  seed <userId>    - Create demo collections and recipes');
    console.error('  cleanup <userId> - Remove all demo data');
    console.error('\nAfter seeding:');
    console.error('  1. Open app and sync data');
    console.error('  2. Generate recipe images in-app for consistent styling');
    console.error('  3. Generate collection backgrounds in-app');
    console.error('  4. Capture screenshots');
    process.exit(1);
  }

  console.log('Initializing Firebase...');
  initializeFirebase();

  switch (command) {
    case 'seed':
      await seedScreenshotDemoForUser(userId);
      break;
    case 'cleanup':
      await cleanupScreenshotDemo(userId);
      break;
    default:
      console.error(`Unknown command: ${command}`);
      console.error('Use "seed" or "cleanup"');
      process.exit(1);
  }
}

// Only run CLI when this file is the entry point (not when imported as a module)
if (require.main === module) {
  main().catch(console.error);
}
