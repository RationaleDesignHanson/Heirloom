/**
 * Add 2 missing recipes to each 12-recipe theme to reach 14 total
 *
 * This enables 1 recipe per day for the full 14-day trial.
 *
 * Run with --dry-run to preview changes without modifying files.
 */

import * as fs from 'fs';
import * as path from 'path';

const THEME_RECIPES_DIR = path.resolve(__dirname, '../../../themerecipes');

// New recipes to add to railroad-dining (Golden Age of Rail)
const RAILROAD_NEW_RECIPES = [
  {
    id: "railroad-dining-013",
    title: "Empire Builder Wild Rice Soup",
    description: "Creamy wild rice soup with chicken and mushrooms—a warming specialty from the Great Northern Railway.",
    ingredients: [
      { name: "wild rice", amount: 1, unit: "cup" },
      { name: "chicken broth", amount: 6, unit: "cups" },
      { name: "butter", amount: 4, unit: "tablespoons" },
      { name: "onion", amount: 1, unit: "medium", preparation: "diced" },
      { name: "celery", amount: 2, unit: "stalks", preparation: "diced" },
      { name: "carrots", amount: 2, unit: "medium", preparation: "diced" },
      { name: "mushrooms", amount: 8, unit: "ounces", preparation: "sliced" },
      { name: "flour", amount: 0.33, unit: "cup" },
      { name: "heavy cream", amount: 1.5, unit: "cups" },
      { name: "cooked chicken", amount: 2, unit: "cups", preparation: "diced" },
      { name: "fresh thyme", amount: 1, unit: "teaspoon" },
      { name: "salt", amount: 1.5, unit: "teaspoons" },
      { name: "white pepper", amount: 0.25, unit: "teaspoon" },
      { name: "dry sherry", amount: 2, unit: "tablespoons", isOptional: true }
    ],
    instructions: [
      "Rinse wild rice thoroughly. Cook in 3 cups broth until tender, about 45 minutes. Set aside.",
      "Melt butter in a large pot over medium heat. Add onion, celery, and carrots. Cook 8 minutes.",
      "Add mushrooms and cook until softened, about 5 minutes.",
      "Sprinkle flour over vegetables and stir to coat. Cook 2 minutes.",
      "Gradually whisk in remaining 3 cups broth. Bring to a simmer.",
      "Add cooked wild rice with its liquid, cream, chicken, and thyme.",
      "Simmer 15 minutes until slightly thickened. Season with salt, pepper, and sherry if using.",
      "Serve hot in warm bowls."
    ],
    prepTime: 20,
    cookTime: 70,
    servings: 8,
    source: "Great Northern Railway, Empire Builder Route",
    story: "The Empire Builder crossed the northern plains where wild rice grew in Minnesota lakes. This soup celebrated the regional ingredient, warming travelers as they watched snow-covered Rockies pass by the dining car windows.",
    unlockDay: 4,
    sortOrder: 13,
    difficulty: "medium",
    tags: ["soup", "comfort food", "regional"]
  },
  {
    id: "railroad-dining-014",
    title: "California Zephyr Baked Alaska",
    description: "Ice cream encased in toasted meringue—the spectacular dessert that amazed dining car passengers.",
    ingredients: [
      { name: "pound cake or sponge cake", amount: 1, unit: "loaf", notes: "sliced 1-inch thick" },
      { name: "vanilla ice cream", amount: 1, unit: "quart", notes: "slightly softened" },
      { name: "chocolate ice cream", amount: 1, unit: "pint", notes: "slightly softened" },
      { name: "egg whites", amount: 6, unit: "large" },
      { name: "cream of tartar", amount: 0.25, unit: "teaspoon" },
      { name: "sugar", amount: 1, unit: "cup" },
      { name: "vanilla extract", amount: 1, unit: "teaspoon" },
      { name: "brandy", amount: 2, unit: "tablespoons", isOptional: true, group: "For flambé" }
    ],
    instructions: [
      "Line a loaf pan with plastic wrap. Layer cake slices on bottom.",
      "Spread vanilla ice cream in an even layer. Top with chocolate ice cream.",
      "Cover with remaining cake. Press gently. Freeze until solid, at least 4 hours or overnight.",
      "Beat egg whites and cream of tartar until soft peaks form.",
      "Gradually add sugar, beating until stiff and glossy. Beat in vanilla.",
      "Unmold frozen cake onto an oven-safe platter. Working quickly, cover completely with meringue, creating peaks.",
      "Freeze until ready to serve (can freeze up to 2 hours).",
      "Preheat oven to 500°F (260°C). Bake 3-4 minutes until meringue is golden.",
      "For flambé: Warm brandy, pour over top, and ignite. Serve immediately."
    ],
    prepTime: 45,
    cookTime: 5,
    servings: 8,
    source: "Western Pacific Railroad, California Zephyr",
    story: "The California Zephyr's Vista Dome cars offered stunning views, and the dining service matched the scenery. Baked Alaska was prepared tableside with great theater—ice cream that didn't melt in a hot oven seemed like magic.",
    unlockDay: 6,
    sortOrder: 14,
    difficulty: "hard",
    tags: ["dessert", "spectacular", "special occasion"]
  }
];

// New recipes to add to scandinavian-heritage
const SCANDINAVIAN_NEW_RECIPES = [
  {
    id: "scandinavian-heritage-013",
    title: "Finnish Karelian Pies (Karjalanpiirakat)",
    description: "Traditional Finnish rye-crusted pies filled with creamy rice porridge—served with egg butter.",
    ingredients: [
      { name: "rye flour", amount: 1.5, unit: "cups" },
      { name: "all-purpose flour", amount: 0.5, unit: "cup" },
      { name: "water", amount: 0.75, unit: "cup" },
      { name: "salt", amount: 0.5, unit: "teaspoon" },
      { name: "short-grain rice", amount: 0.5, unit: "cup", group: "For filling" },
      { name: "whole milk", amount: 2.5, unit: "cups", group: "For filling" },
      { name: "butter", amount: 2, unit: "tablespoons", group: "For filling" },
      { name: "salt", amount: 0.5, unit: "teaspoon", group: "For filling" },
      { name: "hard-boiled eggs", amount: 4, unit: "large", group: "For egg butter" },
      { name: "butter", amount: 0.5, unit: "cup", notes: "softened", group: "For egg butter" },
      { name: "salt", amount: 0.25, unit: "teaspoon", group: "For egg butter" }
    ],
    instructions: [
      "For filling: Cook rice in milk over low heat, stirring often, until very thick and creamy, about 45 minutes. Stir in butter and salt. Cool.",
      "For dough: Mix flours and salt. Add water gradually to form a stiff dough. Knead until smooth.",
      "Divide dough into 20 pieces. Roll each into a thin oval about 6 inches long.",
      "Place 2 tablespoons filling in center of each oval.",
      "Fold edges up and crimp, leaving center open. The pies should be boat-shaped.",
      "Bake at 450°F (230°C) for 15 minutes until edges are golden.",
      "Brush hot pies generously with melted butter.",
      "For egg butter: Mash eggs with softened butter and salt.",
      "Serve warm pies topped with egg butter."
    ],
    prepTime: 45,
    cookTime: 60,
    servings: 20,
    source: "Finnish-American immigrant tradition",
    story: "Karjalanpiirakat originated in Karelia, a region divided between Finland and Russia. Finnish immigrants to the Upper Midwest kept this tradition alive, and the pies remain a symbol of Finnish identity.",
    unlockDay: 4,
    sortOrder: 13,
    difficulty: "medium",
    tags: ["breakfast", "Finnish", "traditional", "savory pastry"]
  },
  {
    id: "scandinavian-heritage-014",
    title: "Swedish Hasselback Potatoes",
    description: "Crispy-edged, accordion-sliced potatoes with butter and herbs—a Swedish steakhouse classic.",
    ingredients: [
      { name: "medium russet potatoes", amount: 8 },
      { name: "butter", amount: 6, unit: "tablespoons", notes: "melted" },
      { name: "olive oil", amount: 2, unit: "tablespoons" },
      { name: "garlic", amount: 3, unit: "cloves", preparation: "minced" },
      { name: "fresh thyme", amount: 1, unit: "tablespoon", preparation: "chopped" },
      { name: "salt", amount: 1.5, unit: "teaspoons" },
      { name: "black pepper", amount: 0.5, unit: "teaspoon" },
      { name: "Parmesan cheese", amount: 0.5, unit: "cup", preparation: "grated", isOptional: true },
      { name: "fresh parsley", amount: 2, unit: "tablespoons", preparation: "chopped", group: "For garnish" }
    ],
    instructions: [
      "Preheat oven to 425°F (220°C).",
      "Place each potato between two chopsticks or wooden spoon handles. Make thin slices every 3mm, cutting down but not through—the sticks prevent cutting all the way.",
      "Place potatoes in a baking dish. Fan slices open slightly.",
      "Mix melted butter, oil, garlic, thyme, salt, and pepper.",
      "Brush potatoes generously with butter mixture, getting between slices.",
      "Bake 30 minutes. Brush again with butter mixture.",
      "Continue baking 25-30 minutes until potatoes are tender inside and crispy outside.",
      "Sprinkle with Parmesan if using. Bake 5 minutes more.",
      "Garnish with parsley and serve immediately."
    ],
    prepTime: 20,
    cookTime: 65,
    servings: 8,
    source: "Hasselbacken Restaurant, Stockholm",
    story: "These potatoes were invented in the 1950s at Hasselbacken, a restaurant in Stockholm's Djurgården park. The technique creates maximum crispy surface area while keeping the interior creamy.",
    unlockDay: 6,
    sortOrder: 14,
    difficulty: "easy",
    tags: ["side dish", "Swedish", "vegetarian", "elegant"]
  }
];

// New recipes to add to sunday-suppers
const SUNDAY_SUPPERS_NEW_RECIPES = [
  {
    id: "sunday-suppers-013",
    title: "Yorkshire Pudding",
    description: "Golden, puffy, and crisp-edged—the essential British accompaniment to Sunday roast beef.",
    ingredients: [
      { name: "all-purpose flour", amount: 1, unit: "cup" },
      { name: "eggs", amount: 3, unit: "large" },
      { name: "whole milk", amount: 1, unit: "cup" },
      { name: "salt", amount: 0.5, unit: "teaspoon" },
      { name: "beef drippings or vegetable oil", amount: 0.25, unit: "cup" }
    ],
    instructions: [
      "Whisk flour and salt in a bowl. Make a well in center.",
      "Beat eggs and milk together. Pour into well and whisk until smooth.",
      "Let batter rest at room temperature for at least 30 minutes (or refrigerate up to overnight).",
      "Preheat oven to 450°F (230°C).",
      "Divide drippings among 12 muffin cups (about 1 teaspoon each). Place pan in oven until fat is smoking hot, about 5 minutes.",
      "Working quickly, pour batter into hot cups, filling each about half full.",
      "Bake 20-25 minutes until puffed and deeply golden. Do not open oven door during first 15 minutes.",
      "Serve immediately—they deflate as they cool."
    ],
    prepTime: 10,
    cookTime: 25,
    servings: 12,
    source: "British-American Sunday dinner tradition",
    story: "Yorkshire pudding came to America with British immigrants and became synonymous with Sunday roast beef. The batter puffs dramatically in hot fat, creating crispy edges and soft, eggy centers perfect for soaking up gravy.",
    unlockDay: 4,
    sortOrder: 13,
    difficulty: "medium",
    tags: ["side dish", "British", "Sunday dinner", "roast"]
  },
  {
    id: "sunday-suppers-014",
    title: "Honey-Glazed Carrots",
    description: "Tender carrots glistening with butter, honey, and fresh herbs—the bright side dish every table needs.",
    ingredients: [
      { name: "carrots", amount: 2, unit: "pounds", preparation: "peeled and cut into 2-inch pieces" },
      { name: "butter", amount: 4, unit: "tablespoons" },
      { name: "honey", amount: 3, unit: "tablespoons" },
      { name: "chicken broth", amount: 0.5, unit: "cup" },
      { name: "fresh thyme", amount: 1, unit: "tablespoon", preparation: "chopped" },
      { name: "salt", amount: 0.75, unit: "teaspoon" },
      { name: "black pepper", amount: 0.25, unit: "teaspoon" },
      { name: "fresh parsley", amount: 2, unit: "tablespoons", preparation: "chopped", group: "For garnish" }
    ],
    instructions: [
      "Place carrots in a large skillet in a single layer.",
      "Add butter, honey, broth, thyme, salt, and pepper.",
      "Bring to a boil over medium-high heat. Cover and reduce heat to medium.",
      "Cook until carrots are nearly tender, about 12-15 minutes.",
      "Uncover and increase heat to medium-high.",
      "Cook, stirring occasionally, until liquid reduces to a glaze and carrots are tender, about 8-10 minutes.",
      "Adjust seasoning. Garnish with parsley and serve."
    ],
    prepTime: 15,
    cookTime: 25,
    servings: 8,
    source: "American home cooking tradition",
    story: "Glazed carrots have adorned Sunday tables for generations. The combination of butter and honey creates a glaze that caramelizes slightly, bringing out the natural sweetness of the carrots.",
    unlockDay: 6,
    sortOrder: 14,
    difficulty: "easy",
    tags: ["side dish", "vegetarian", "quick", "holiday"]
  }
];

interface Recipe {
  id: string;
  title: string;
  unlockDay: number;
  sortOrder: number;
  [key: string]: any;
}

interface ThemeData {
  themeId: string;
  themeName: string;
  recipes: Recipe[];
}

function addRecipesToTheme(fileName: string, newRecipes: Recipe[], dryRun: boolean): void {
  const filePath = path.join(THEME_RECIPES_DIR, fileName);

  if (!fs.existsSync(filePath)) {
    console.log(`  ⚠️ File not found: ${fileName}`);
    return;
  }

  const data: ThemeData = JSON.parse(fs.readFileSync(filePath, 'utf8'));

  console.log(`\n📚 ${data.themeName} (${data.themeId})`);
  console.log(`   Current recipes: ${data.recipes.length}`);
  console.log(`   Adding: ${newRecipes.length} new recipes`);

  newRecipes.forEach(recipe => {
    console.log(`   + ${recipe.title} (Day ${recipe.unlockDay})`);
  });

  if (!dryRun) {
    data.recipes.push(...newRecipes);
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
    console.log(`   ✅ Updated ${fileName} (now ${data.recipes.length} recipes)`);
  } else {
    console.log(`   [DRY RUN] Would add to ${fileName}`);
  }
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');

  console.log('═'.repeat(60));
  console.log('ADD MISSING RECIPES - 12 → 14 PER THEME');
  console.log('═'.repeat(60));

  if (dryRun) {
    console.log('\n🔍 DRY RUN MODE - No files will be modified\n');
  } else {
    console.log('\n⚠️  LIVE MODE - JSON files will be updated\n');
  }

  console.log('This script adds 2 recipes to each 12-recipe theme,');
  console.log('enabling 1 recipe per day for the full 14-day trial.');

  // Add new recipes to each theme
  addRecipesToTheme('theme-02-railroad-dining.json', RAILROAD_NEW_RECIPES, dryRun);
  addRecipesToTheme('theme-07-scandinavian.json', SCANDINAVIAN_NEW_RECIPES, dryRun);
  addRecipesToTheme('theme-10-sunday-suppers.json', SUNDAY_SUPPERS_NEW_RECIPES, dryRun);

  console.log('\n' + '═'.repeat(60));

  if (!dryRun) {
    console.log('✅ New recipes added to JSON files!');
    console.log('\nNext steps:');
    console.log('  1. Review changes: git diff themerecipes/');
    console.log('  2. Run the unlock days fix script to set proper distribution');
    console.log('  3. Then run Firebase seed when ready');
  } else {
    console.log('Dry run complete. Run without --dry-run to apply changes.');
  }
  console.log('═'.repeat(60));
}

main().catch(console.error);
