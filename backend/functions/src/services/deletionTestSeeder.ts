/**
 * DeletionTestSeeder
 *
 * Auto-seeds the deletion test account with recipes and collections
 * when the account is created. This runs as a Cloud Function trigger.
 */

import * as admin from 'firebase-admin';
import {v4 as uuidv4} from 'uuid';

interface TestRecipe {
  id: string;
  title: string;
  sourceType: string;
  instructions: string[];
  servings: string;
  prepTime: string;
  cookTime: string;
  isFavorite: boolean;
  collectionId: string;
  firebaseImageURL?: string;
  ingredients: Array<{
    originalText: string;
    name: string;
    quantity: number | null;
    unit: string | null;
    orderIndex: number;
  }>;
}

interface TestCollection {
  id: string;
  name: string;
  icon: string;
  color: string;
  isSystemCollection: boolean;
}

// Storage bucket for pre-generated images
const STORAGE_BUCKET = 'heirloom-ios-prod.firebasestorage.app';
const IMAGE_PREFIX = 'seed/deletion-test';

function getImageUrl(recipeTitle: string): string {
  const slug = recipeTitle
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
  return `https://storage.googleapis.com/${STORAGE_BUCKET}/${IMAGE_PREFIX}/${slug}-image.webp`;
}

export class DeletionTestSeeder {
  private db: admin.firestore.Firestore;

  constructor(db: admin.firestore.Firestore) {
    this.db = db;
  }

  /**
   * Seeds the deletion test account with test data
   */
  async seedAccount(userId: string, email: string): Promise<void> {
    console.log(`🌱 Seeding account for ${email} (${userId})`);

    // Generate consistent IDs for this seeding
    const collectionIds = {
      quickEasy: uuidv4(),
      favorites: uuidv4(),
      bakedGoods: uuidv4(),
    };

    const recipeIds = {
      honeyGarlicSalmon: uuidv4(),
      shepherdsPie: uuidv4(),
      friedRice: uuidv4(),
      shrimpScampi: uuidv4(),
      caesarSalad: uuidv4(),
      frenchOnionSoup: uuidv4(),
      bananaBread: uuidv4(),
      blueberryMuffins: uuidv4(),
      cinnamonRolls: uuidv4(),
    };

    // Create profile
    await this.createProfile(userId, email);

    // Set expired subscription (Apple needs to see paywall)
    await this.setExpiredSubscription(userId);

    // Create collections and recipes
    const collections = this.getCollections(collectionIds);
    const recipes = this.getRecipes(recipeIds, collectionIds);

    await this.createCollections(userId, collections, recipes);
    await this.createRecipes(userId, recipes);

    console.log(`✅ Seeded ${recipes.length} recipes in ${collections.length} collections`);
  }

  private async createProfile(userId: string, email: string): Promise<void> {
    await this.db
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('data')
        .set({
          displayName: 'Delete Test User',
          email: email,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
  }

  private async setExpiredSubscription(userId: string): Promise<void> {
    await this.db
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('status')
        .set({
          isActive: false,
          productId: 'com.rationaledesign.heirloom.premium.annual.v2',
          planType: 'annual',
          expiresAt: admin.firestore.Timestamp.fromDate(new Date('2024-01-01')),
          startedAt: admin.firestore.FieldValue.serverTimestamp(),
          source: 'deletion_test_auto_seed',
        });
  }

  private async createCollections(
      userId: string,
      collections: TestCollection[],
      recipes: TestRecipe[]
  ): Promise<void> {
    for (const collection of collections) {
      const recipeIds = recipes
          .filter((r) => r.collectionId === collection.id)
          .map((r) => r.id);

      await this.db
          .collection('users')
          .doc(userId)
          .collection('collections')
          .doc(collection.id)
          .set({
            id: collection.id,
            name: collection.name,
            icon: collection.icon,
            color: collection.color,
            isSystemCollection: collection.isSystemCollection,
            isAllRecipes: false,
            isDemoSeed: false,
            recipeIds: recipeIds,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            modifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
    }
  }

  private async createRecipes(
      userId: string,
      recipes: TestRecipe[]
  ): Promise<void> {
    const now = new Date();

    for (const recipe of recipes) {
      const recipeRef = this.db
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .doc(recipe.id);

      await recipeRef.set({
        id: recipe.id,
        title: recipe.title,
        sourceType: recipe.sourceType,
        instructions: recipe.instructions,
        servings: recipe.servings,
        prepTime: recipe.prepTime,
        cookTime: recipe.cookTime,
        isFavorite: recipe.isFavorite,
        firebaseImageURL: recipe.firebaseImageURL || null,
        timesCooked: 0,
        generationCount: 0,
        collectionIds: [recipe.collectionId],
        createdAt: admin.firestore.Timestamp.fromDate(now),
        modifiedAt: admin.firestore.Timestamp.fromDate(now),
        lastSyncedAt: admin.firestore.Timestamp.fromDate(now),
      });

      // Create ingredients subcollection
      for (const ingredient of recipe.ingredients) {
        const ingredientId = uuidv4();
        await recipeRef.collection('ingredients').doc(ingredientId).set({
          id: ingredientId,
          originalText: ingredient.originalText,
          name: ingredient.name,
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          orderIndex: ingredient.orderIndex,
          isChecked: false,
        });
      }
    }
  }

  private getCollections(ids: {
    quickEasy: string;
    favorites: string;
    bakedGoods: string;
  }): TestCollection[] {
    return [
      {
        id: ids.quickEasy,
        name: 'Quick & Easy',
        icon: 'bolt',
        color: '#FF9500',
        isSystemCollection: false,
      },
      {
        id: ids.favorites,
        name: 'Favorites',
        icon: 'heart.fill',
        color: '#E05A3A',
        isSystemCollection: true,
      },
      {
        id: ids.bakedGoods,
        name: 'Baked Goods',
        icon: 'flame',
        color: '#8B4513',
        isSystemCollection: false,
      },
    ];
  }

  private getRecipes(
      recipeIds: Record<string, string>,
      collectionIds: Record<string, string>
  ): TestRecipe[] {
    return [
      {
        id: recipeIds.honeyGarlicSalmon,
        title: 'Honey Garlic Salmon',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Honey Garlic Salmon'),
        instructions: [
          'Pat salmon fillets dry and season with salt and pepper.',
          'Heat olive oil in a large oven-safe skillet over medium-high heat.',
          'Add salmon skin-side up and sear 3 minutes until golden.',
          'Flip salmon and transfer skillet to oven at 400°F for 5 minutes.',
          'Meanwhile, mix honey, soy sauce, garlic, and ginger.',
          'Remove salmon from oven and pour sauce over fillets.',
          'Return to stovetop and simmer 2 minutes, basting salmon.',
          'Garnish with sesame seeds and green onions. Serve immediately.',
        ],
        servings: '4',
        prepTime: '10 mins',
        cookTime: '15 mins',
        isFavorite: true,
        collectionId: collectionIds.quickEasy,
        ingredients: [
          {originalText: '4 salmon fillets (6 oz each)', name: 'salmon fillets', quantity: 4, unit: null, orderIndex: 0},
          {originalText: '3 tablespoons honey', name: 'honey', quantity: 3, unit: 'tablespoon', orderIndex: 1},
          {originalText: '2 tablespoons soy sauce', name: 'soy sauce', quantity: 2, unit: 'tablespoon', orderIndex: 2},
          {originalText: '4 cloves garlic, minced', name: 'garlic', quantity: 4, unit: 'clove', orderIndex: 3},
          {originalText: '1 teaspoon fresh ginger', name: 'fresh ginger', quantity: 1, unit: 'teaspoon', orderIndex: 4},
          {originalText: '2 tablespoons olive oil', name: 'olive oil', quantity: 2, unit: 'tablespoon', orderIndex: 5},
        ],
      },
      {
        id: recipeIds.shepherdsPie,
        title: 'Classic Shepherd\'s Pie',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Classic Shepherd\'s Pie'),
        instructions: [
          'Boil potatoes until tender, about 15-20 minutes. Drain and mash with butter and cream.',
          'Brown ground lamb in a large skillet over medium-high heat.',
          'Add onion, carrots, and celery. Cook 5 minutes until softened.',
          'Stir in tomato paste, beef broth, and Worcestershire sauce.',
          'Add frozen peas and simmer 10 minutes until thickened.',
          'Transfer meat mixture to a baking dish.',
          'Spread mashed potatoes evenly over the top.',
          'Bake at 400°F for 25 minutes until golden and bubbling.',
        ],
        servings: '6',
        prepTime: '25 mins',
        cookTime: '45 mins',
        isFavorite: false,
        collectionId: collectionIds.quickEasy,
        ingredients: [
          {originalText: '1.5 lbs ground lamb', name: 'ground lamb', quantity: 1.5, unit: 'lb', orderIndex: 0},
          {originalText: '2 lbs russet potatoes, peeled', name: 'russet potatoes', quantity: 2, unit: 'lb', orderIndex: 1},
          {originalText: '1 onion, diced', name: 'onion', quantity: 1, unit: null, orderIndex: 2},
          {originalText: '2 carrots, diced', name: 'carrots', quantity: 2, unit: null, orderIndex: 3},
          {originalText: '1 cup frozen peas', name: 'frozen peas', quantity: 1, unit: 'cup', orderIndex: 4},
          {originalText: '1 cup beef broth', name: 'beef broth', quantity: 1, unit: 'cup', orderIndex: 5},
          {originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 6},
        ],
      },
      {
        id: recipeIds.friedRice,
        title: 'Easy Vegetable Fried Rice',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Easy Vegetable Fried Rice'),
        instructions: [
          'Use day-old cold rice for best results.',
          'Heat vegetable oil in a wok or large skillet over high heat.',
          'Scramble eggs and set aside.',
          'Add vegetables and stir-fry 3-4 minutes.',
          'Add cold rice, breaking up any clumps.',
          'Push rice to the side and add soy sauce to the pan.',
          'Toss everything together with scrambled eggs.',
          'Season with sesame oil and white pepper. Serve hot.',
        ],
        servings: '4',
        prepTime: '10 mins',
        cookTime: '10 mins',
        isFavorite: true,
        collectionId: collectionIds.favorites,
        ingredients: [
          {originalText: '4 cups cold cooked rice', name: 'cooked rice', quantity: 4, unit: 'cup', orderIndex: 0},
          {originalText: '3 eggs, beaten', name: 'eggs', quantity: 3, unit: null, orderIndex: 1},
          {originalText: '1 cup mixed vegetables', name: 'mixed vegetables', quantity: 1, unit: 'cup', orderIndex: 2},
          {originalText: '3 tablespoons soy sauce', name: 'soy sauce', quantity: 3, unit: 'tablespoon', orderIndex: 3},
          {originalText: '2 tablespoons vegetable oil', name: 'vegetable oil', quantity: 2, unit: 'tablespoon', orderIndex: 4},
          {originalText: '1 teaspoon sesame oil', name: 'sesame oil', quantity: 1, unit: 'teaspoon', orderIndex: 5},
        ],
      },
      {
        id: recipeIds.shrimpScampi,
        title: 'Garlic Shrimp Scampi',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Garlic Shrimp Scampi'),
        instructions: [
          'Cook linguine according to package directions. Reserve 1 cup pasta water.',
          'Pat shrimp dry and season with salt and pepper.',
          'Heat olive oil and butter in a large skillet over medium-high heat.',
          'Add shrimp and cook 2 minutes per side. Remove and set aside.',
          'Add garlic to the pan and sauté 30 seconds until fragrant.',
          'Add white wine and lemon juice. Simmer 2 minutes.',
          'Toss in cooked pasta and shrimp.',
          'Add pasta water as needed. Top with parsley and red pepper flakes.',
        ],
        servings: '4',
        prepTime: '15 mins',
        cookTime: '15 mins',
        isFavorite: false,
        collectionId: collectionIds.quickEasy,
        ingredients: [
          {originalText: '1 lb large shrimp, peeled', name: 'large shrimp', quantity: 1, unit: 'lb', orderIndex: 0},
          {originalText: '12 oz linguine pasta', name: 'linguine pasta', quantity: 12, unit: 'oz', orderIndex: 1},
          {originalText: '6 cloves garlic, minced', name: 'garlic', quantity: 6, unit: 'clove', orderIndex: 2},
          {originalText: '1/2 cup white wine', name: 'white wine', quantity: 0.5, unit: 'cup', orderIndex: 3},
          {originalText: '1/4 cup lemon juice', name: 'lemon juice', quantity: 0.25, unit: 'cup', orderIndex: 4},
          {originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 5},
          {originalText: '3 tablespoons olive oil', name: 'olive oil', quantity: 3, unit: 'tablespoon', orderIndex: 6},
        ],
      },
      {
        id: recipeIds.caesarSalad,
        title: 'Classic Caesar Salad',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Classic Caesar Salad'),
        instructions: [
          'Chop romaine lettuce into bite-sized pieces.',
          'For dressing: whisk together anchovy paste, garlic, lemon juice, and Dijon mustard.',
          'Slowly stream in olive oil while whisking to emulsify.',
          'Stir in grated parmesan and black pepper.',
          'Toss lettuce with dressing until evenly coated.',
          'Add croutons and more parmesan.',
          'Top with grilled chicken if desired.',
          'Serve immediately while croutons are crisp.',
        ],
        servings: '4',
        prepTime: '15 mins',
        cookTime: '0 mins',
        isFavorite: true,
        collectionId: collectionIds.favorites,
        ingredients: [
          {originalText: '2 heads romaine lettuce', name: 'romaine lettuce', quantity: 2, unit: 'head', orderIndex: 0},
          {originalText: '1/2 cup olive oil', name: 'olive oil', quantity: 0.5, unit: 'cup', orderIndex: 1},
          {originalText: '2 cloves garlic, minced', name: 'garlic', quantity: 2, unit: 'clove', orderIndex: 2},
          {originalText: '2 tablespoons lemon juice', name: 'lemon juice', quantity: 2, unit: 'tablespoon', orderIndex: 3},
          {originalText: '1 teaspoon anchovy paste', name: 'anchovy paste', quantity: 1, unit: 'teaspoon', orderIndex: 4},
          {originalText: '1/2 cup parmesan cheese', name: 'parmesan cheese', quantity: 0.5, unit: 'cup', orderIndex: 5},
          {originalText: '1 cup croutons', name: 'croutons', quantity: 1, unit: 'cup', orderIndex: 6},
        ],
      },
      {
        id: recipeIds.frenchOnionSoup,
        title: 'French Onion Soup',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('French Onion Soup'),
        instructions: [
          'Slice onions into thin half-moons.',
          'Melt butter in a large pot over medium heat.',
          'Add onions and cook 45 minutes, stirring occasionally, until deeply caramelized.',
          'Add thyme, bay leaf, and a pinch of sugar to help caramelization.',
          'Deglaze with white wine, scraping up brown bits.',
          'Add beef broth and simmer 20 minutes.',
          'Ladle soup into oven-safe bowls. Top with baguette slices and gruyere.',
          'Broil until cheese is bubbly and golden.',
        ],
        servings: '4',
        prepTime: '15 mins',
        cookTime: '75 mins',
        isFavorite: false,
        collectionId: collectionIds.quickEasy,
        ingredients: [
          {originalText: '4 large yellow onions', name: 'yellow onions', quantity: 4, unit: null, orderIndex: 0},
          {originalText: '4 tablespoons butter', name: 'butter', quantity: 4, unit: 'tablespoon', orderIndex: 1},
          {originalText: '4 cups beef broth', name: 'beef broth', quantity: 4, unit: 'cup', orderIndex: 2},
          {originalText: '1/2 cup white wine', name: 'white wine', quantity: 0.5, unit: 'cup', orderIndex: 3},
          {originalText: '1 baguette, sliced', name: 'baguette', quantity: 1, unit: null, orderIndex: 4},
          {originalText: '2 cups gruyere cheese, shredded', name: 'gruyere cheese', quantity: 2, unit: 'cup', orderIndex: 5},
        ],
      },
      {
        id: recipeIds.bananaBread,
        title: 'Classic Banana Bread',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Classic Banana Bread'),
        instructions: [
          'Preheat oven to 350°F. Grease a 9x5 loaf pan.',
          'Mash ripe bananas in a large bowl until smooth.',
          'Stir in melted butter, sugar, egg, and vanilla.',
          'Mix in baking soda and salt.',
          'Gently fold in flour until just combined.',
          'Add walnuts if using.',
          'Pour batter into prepared pan.',
          'Bake 55-60 minutes until a toothpick comes out clean.',
          'Cool in pan 10 minutes before removing.',
        ],
        servings: '10',
        prepTime: '15 mins',
        cookTime: '60 mins',
        isFavorite: true,
        collectionId: collectionIds.bakedGoods,
        ingredients: [
          {originalText: '3 ripe bananas', name: 'bananas', quantity: 3, unit: null, orderIndex: 0},
          {originalText: '1/3 cup melted butter', name: 'melted butter', quantity: 0.33, unit: 'cup', orderIndex: 1},
          {originalText: '3/4 cup sugar', name: 'sugar', quantity: 0.75, unit: 'cup', orderIndex: 2},
          {originalText: '1 egg, beaten', name: 'egg', quantity: 1, unit: null, orderIndex: 3},
          {originalText: '1 teaspoon vanilla extract', name: 'vanilla extract', quantity: 1, unit: 'teaspoon', orderIndex: 4},
          {originalText: '1 teaspoon baking soda', name: 'baking soda', quantity: 1, unit: 'teaspoon', orderIndex: 5},
          {originalText: '1.5 cups all-purpose flour', name: 'all-purpose flour', quantity: 1.5, unit: 'cup', orderIndex: 6},
        ],
      },
      {
        id: recipeIds.blueberryMuffins,
        title: 'Homemade Blueberry Muffins',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Homemade Blueberry Muffins'),
        instructions: [
          'Preheat oven to 375°F. Line muffin tin with paper liners.',
          'Whisk together flour, sugar, baking powder, and salt.',
          'In another bowl, mix melted butter, milk, eggs, and vanilla.',
          'Pour wet ingredients into dry and stir until just combined.',
          'Gently fold in blueberries.',
          'Divide batter among muffin cups.',
          'Sprinkle tops with coarse sugar if desired.',
          'Bake 20-25 minutes until golden and a toothpick comes out clean.',
        ],
        servings: '12',
        prepTime: '15 mins',
        cookTime: '25 mins',
        isFavorite: false,
        collectionId: collectionIds.bakedGoods,
        ingredients: [
          {originalText: '2 cups all-purpose flour', name: 'all-purpose flour', quantity: 2, unit: 'cup', orderIndex: 0},
          {originalText: '3/4 cup sugar', name: 'sugar', quantity: 0.75, unit: 'cup', orderIndex: 1},
          {originalText: '2.5 teaspoons baking powder', name: 'baking powder', quantity: 2.5, unit: 'teaspoon', orderIndex: 2},
          {originalText: '1/3 cup vegetable oil', name: 'vegetable oil', quantity: 0.33, unit: 'cup', orderIndex: 3},
          {originalText: '1 cup milk', name: 'milk', quantity: 1, unit: 'cup', orderIndex: 4},
          {originalText: '1 egg', name: 'egg', quantity: 1, unit: null, orderIndex: 5},
          {originalText: '1.5 cups fresh blueberries', name: 'blueberries', quantity: 1.5, unit: 'cup', orderIndex: 6},
        ],
      },
      {
        id: recipeIds.cinnamonRolls,
        title: 'Homemade Cinnamon Rolls',
        sourceType: 'manual',
        firebaseImageURL: getImageUrl('Homemade Cinnamon Rolls'),
        instructions: [
          'Warm milk to 110°F. Add yeast and 1 tablespoon sugar. Let sit 5 minutes.',
          'Mix in remaining sugar, butter, eggs, and salt. Add flour gradually.',
          'Knead dough 5 minutes until smooth. Let rise 1 hour.',
          'Roll dough into a 16x12 rectangle.',
          'Spread softened butter over dough. Sprinkle with cinnamon-sugar mixture.',
          'Roll up tightly from the long side. Cut into 12 pieces.',
          'Place in greased 9x13 pan. Let rise 30 minutes.',
          'Bake at 350°F for 25 minutes.',
          'Drizzle with cream cheese frosting while warm.',
        ],
        servings: '12',
        prepTime: '30 mins',
        cookTime: '25 mins',
        isFavorite: true,
        collectionId: collectionIds.bakedGoods,
        ingredients: [
          {originalText: '1 cup warm milk', name: 'warm milk', quantity: 1, unit: 'cup', orderIndex: 0},
          {originalText: '2.25 teaspoons active dry yeast', name: 'active dry yeast', quantity: 2.25, unit: 'teaspoon', orderIndex: 1},
          {originalText: '1/2 cup sugar', name: 'sugar', quantity: 0.5, unit: 'cup', orderIndex: 2},
          {originalText: '1/3 cup butter, softened', name: 'butter', quantity: 0.33, unit: 'cup', orderIndex: 3},
          {originalText: '4 cups all-purpose flour', name: 'all-purpose flour', quantity: 4, unit: 'cup', orderIndex: 4},
          {originalText: '2 tablespoons cinnamon', name: 'cinnamon', quantity: 2, unit: 'tablespoon', orderIndex: 5},
          {originalText: '1 cup brown sugar', name: 'brown sugar', quantity: 1, unit: 'cup', orderIndex: 6},
          {originalText: '4 oz cream cheese', name: 'cream cheese', quantity: 4, unit: 'oz', orderIndex: 7},
        ],
      },
    ];
  }
}
