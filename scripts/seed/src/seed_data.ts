/**
 * Seed data for demo creators and their public recipes
 * Full recipe content for Discovery feature captures
 */

// ============================================================================
// Types
// ============================================================================

export interface DemoCreator {
  id: string;
  creatorName: string;
  creatorProfileSlug: string;
  avatarDescription: string; // Used for image generation prompt
}

export interface SeedRecipe {
  id: string;
  sourceRecipeId: string;
  creatorId: string;
  creatorName: string;
  creatorProfileSlug: string;
  title: string;
  description: string;
  ingredients: string[];
  instructions: string[];
  category: string;
  tags: string[];
  servings: string;
  prepTime: string;
  cookTime: string;
  totalTime?: string;
  viewCount: number;
  saveCount: number;
  publishedDaysAgo: number;
}

// ============================================================================
// Demo Creators
// ============================================================================

export const DEMO_CREATORS: DemoCreator[] = [
  {
    id: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    avatarDescription:
      'a warm friendly grandmother in her 60s with silver hair and a gentle smile, wearing a comfortable apron',
  },
  {
    id: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    avatarDescription:
      'a young man in his late 20s with short brown hair, casual t-shirt, friendly approachable expression',
  },
];

// ============================================================================
// Grandmazing Recipes (7)
// ============================================================================

const GRANDMAZING_RECIPES: SeedRecipe[] = [
  {
    id: 'demo_grandmazing_lemon_garlic_chicken',
    sourceRecipeId: 'seed-uuid-001',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Lemon Garlic Chicken',
    description:
      "This was my mother's Sunday dinner staple. The secret is marinating for at least two hours - the lemon tenderizes the chicken beautifully while the garlic infuses every bite. I've made this for three generations of my family now.",
    ingredients: [
      '4 bone-in chicken thighs',
      '3 tablespoons olive oil',
      '4 cloves garlic, minced',
      '2 lemons, juiced and zested',
      '1 tablespoon fresh rosemary, chopped',
      '1 teaspoon dried oregano',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '1/4 cup chicken broth',
      '2 tablespoons butter',
      '1 tablespoon fresh parsley, chopped',
    ],
    instructions: [
      'In a bowl, combine olive oil, minced garlic, lemon juice, lemon zest, rosemary, oregano, salt, and pepper.',
      'Place chicken thighs in a large zip-lock bag and pour the marinade over them. Refrigerate for at least 2 hours, or overnight for best results.',
      'Preheat your oven to 425°F (220°C).',
      'Remove chicken from marinade and pat dry with paper towels. Reserve the marinade.',
      'Heat an oven-safe skillet over medium-high heat. Sear chicken skin-side down for 4-5 minutes until golden and crispy.',
      'Flip the chicken and pour the reserved marinade and chicken broth around the pieces.',
      'Transfer the skillet to the oven and roast for 25-30 minutes until the internal temperature reaches 165°F.',
      'Remove from oven, add butter to the pan, and baste the chicken with the pan juices.',
      'Let rest for 5 minutes, then garnish with fresh parsley and serve.',
    ],
    category: 'Dinner',
    tags: ['Chicken', 'Lemon', 'Garlic', 'Family Recipe', 'Sunday Dinner'],
    servings: '4 servings',
    prepTime: '15',
    cookTime: '35',
    totalTime: '50',
    viewCount: 3500,
    saveCount: 480,
    publishedDaysAgo: 14,
  },
  {
    id: 'demo_grandmazing_tomato_basil_soup',
    sourceRecipeId: 'seed-uuid-002',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Cozy Tomato Basil Soup',
    description:
      "There's nothing like a warm bowl of tomato soup on a chilly day. I started making this when my kids were small and refused to eat their vegetables - they never knew this soup was packed with carrots and celery. It's been our family's comfort food ever since.",
    ingredients: [
      '2 cans (28 oz each) whole peeled tomatoes',
      '1 medium onion, diced',
      '2 carrots, peeled and chopped',
      '2 celery stalks, chopped',
      '4 cloves garlic, minced',
      '3 tablespoons olive oil',
      '4 cups vegetable broth',
      '1/2 cup fresh basil leaves, plus more for garnish',
      '1/2 cup heavy cream',
      '1 teaspoon sugar',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '1/4 teaspoon red pepper flakes',
    ],
    instructions: [
      'Heat olive oil in a large Dutch oven over medium heat. Add onion, carrots, and celery. Cook for 8-10 minutes until softened.',
      'Add garlic and cook for another minute until fragrant.',
      'Pour in the canned tomatoes with their juices and the vegetable broth. Bring to a simmer.',
      'Add sugar, salt, pepper, and red pepper flakes. Simmer uncovered for 25-30 minutes.',
      'Remove from heat and add fresh basil leaves.',
      'Using an immersion blender, puree the soup until smooth. Alternatively, blend in batches in a regular blender.',
      'Stir in the heavy cream and heat through for 2-3 minutes.',
      'Taste and adjust seasonings as needed.',
      'Serve hot, garnished with fresh basil leaves and a drizzle of olive oil.',
    ],
    category: 'Soup',
    tags: ['Soup', 'Tomato', 'Comfort Food', 'Vegetarian', 'Kid-Friendly'],
    servings: '6 servings',
    prepTime: '15',
    cookTime: '40',
    totalTime: '55',
    viewCount: 1200,
    saveCount: 180,
    publishedDaysAgo: 30,
  },
  {
    id: 'demo_grandmazing_salmon_rice_bowls',
    sourceRecipeId: 'seed-uuid-003',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Crispy Salmon Rice Bowls',
    description:
      "My granddaughter taught me this one! She came home from college talking about 'salmon rice' from the internet, so we worked on this version together. The crispy rice on the bottom is the best part - don't skip that step!",
    ingredients: [
      '2 salmon fillets (6 oz each)',
      '2 cups cooked jasmine rice, day-old works best',
      '3 tablespoons soy sauce',
      '1 tablespoon rice vinegar',
      '1 tablespoon sesame oil',
      '1 tablespoon sriracha mayo',
      '2 tablespoons vegetable oil',
      '1 avocado, sliced',
      '2 green onions, sliced',
      '1 tablespoon sesame seeds',
      '1 sheet nori, cut into strips',
      'Pickled ginger for serving',
    ],
    instructions: [
      'Season salmon fillets with salt and pepper. Heat 1 tablespoon vegetable oil in a non-stick pan over medium-high heat.',
      'Cook salmon skin-side up for 4 minutes, then flip and cook 3-4 more minutes until cooked through. Set aside.',
      'In the same pan, add remaining oil. Press day-old rice into the pan in an even layer.',
      'Let rice cook undisturbed for 5-6 minutes until bottom is golden and crispy.',
      'While rice crisps, mix soy sauce, rice vinegar, and sesame oil in a small bowl.',
      'Break salmon into large flakes, removing skin if desired.',
      'Flip the crispy rice onto a plate, crispy-side up. Top with salmon flakes.',
      'Drizzle with the soy sauce mixture and sriracha mayo.',
      'Add sliced avocado, green onions, sesame seeds, and nori strips. Serve with pickled ginger.',
    ],
    category: 'Dinner',
    tags: ['Salmon', 'Rice Bowl', 'Asian-Inspired', 'Quick Dinner', 'Crispy Rice'],
    servings: '2 servings',
    prepTime: '10',
    cookTime: '20',
    totalTime: '30',
    viewCount: 4200,
    saveCount: 620,
    publishedDaysAgo: 5,
  },
  {
    id: 'demo_grandmazing_chocolate_chip_cookies',
    sourceRecipeId: 'seed-uuid-004',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Brown Butter Chocolate Chip Cookies',
    description:
      "I've been making chocolate chip cookies for over 50 years, but browning the butter was a game-changer I discovered just five years ago. The nutty, caramel notes make these absolutely irresistible. My grandkids say these are better than any bakery.",
    ingredients: [
      '1 cup (2 sticks) unsalted butter',
      '2 1/4 cups all-purpose flour',
      '1 teaspoon baking soda',
      '1 teaspoon salt',
      '1 cup packed brown sugar',
      '1/2 cup granulated sugar',
      '2 large eggs',
      '2 teaspoons vanilla extract',
      '2 cups semi-sweet chocolate chips',
      '1 cup chopped walnuts (optional)',
      'Flaky sea salt for topping',
    ],
    instructions: [
      'In a light-colored saucepan, melt butter over medium heat. Continue cooking, swirling occasionally, until butter turns golden brown and smells nutty, about 5-7 minutes. Pour into a heat-proof bowl and refrigerate until solid but still soft, about 1 hour.',
      'Whisk together flour, baking soda, and salt in a medium bowl.',
      'Using a mixer, beat the cooled brown butter with both sugars until light and fluffy, about 3 minutes.',
      'Beat in eggs one at a time, then add vanilla extract.',
      'Gradually mix in the flour mixture until just combined.',
      'Fold in chocolate chips and walnuts if using.',
      'Cover dough and refrigerate for at least 30 minutes (or up to 3 days).',
      'Preheat oven to 375°F. Line baking sheets with parchment paper.',
      'Scoop 2-tablespoon portions of dough onto prepared sheets, spacing 2 inches apart.',
      'Bake for 10-12 minutes until edges are golden but centers look slightly underdone.',
      'Sprinkle with flaky sea salt immediately. Cool on pan for 5 minutes before transferring.',
    ],
    category: 'Dessert',
    tags: ['Cookies', 'Chocolate', 'Brown Butter', 'Baking', 'Family Favorite'],
    servings: '36 cookies',
    prepTime: '20',
    cookTime: '12',
    totalTime: '32',
    viewCount: 1800,
    saveCount: 250,
    publishedDaysAgo: 14,
  },
  {
    id: 'demo_grandmazing_peanut_noodles',
    sourceRecipeId: 'seed-uuid-005',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: '15-Minute Spicy Peanut Noodles',
    description:
      "When my grandkids come over hungry and I don't have much time, these noodles save the day. The sauce comes together while the pasta cooks - true 15-minute magic. They always ask for seconds.",
    ingredients: [
      '8 oz linguine or spaghetti',
      '1/2 cup creamy peanut butter',
      '3 tablespoons soy sauce',
      '2 tablespoons rice vinegar',
      '1 tablespoon sesame oil',
      '1 tablespoon honey',
      '1 tablespoon sriracha (adjust to taste)',
      '2 cloves garlic, minced',
      '1/4 cup warm water',
      '2 cups shredded rotisserie chicken (optional)',
      '1 cup shredded carrots',
      '1/2 cup chopped cilantro',
      '1/4 cup chopped peanuts',
      'Lime wedges for serving',
    ],
    instructions: [
      'Bring a large pot of salted water to boil. Cook pasta according to package directions. Reserve 1/2 cup pasta water before draining.',
      'While pasta cooks, whisk together peanut butter, soy sauce, rice vinegar, sesame oil, honey, sriracha, and garlic in a large bowl.',
      'Add warm water gradually to thin the sauce to your desired consistency.',
      'Drain pasta and add to the bowl with the peanut sauce. Toss to coat completely.',
      'Add shredded chicken if using and toss again.',
      'If sauce is too thick, add reserved pasta water a little at a time.',
      'Divide among bowls and top with shredded carrots, cilantro, and chopped peanuts.',
      'Serve with lime wedges for squeezing over the top.',
    ],
    category: 'Dinner',
    tags: ['Noodles', 'Peanut', 'Quick Meal', '15-Minute', 'Kid-Friendly'],
    servings: '4 servings',
    prepTime: '5',
    cookTime: '10',
    totalTime: '15',
    viewCount: 380,
    saveCount: 52,
    publishedDaysAgo: 2,
  },
  {
    id: 'demo_grandmazing_sheet_pan_veggies',
    sourceRecipeId: 'seed-uuid-006',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Sheet-Pan Roasted Vegetables',
    description:
      "I make these at least twice a week. The high heat caramelizes everything beautifully, and the herbs make the whole kitchen smell wonderful. My secret is not overcrowding the pan - give those vegetables room to breathe!",
    ingredients: [
      '2 medium zucchini, cut into half-moons',
      '1 red bell pepper, cut into chunks',
      '1 yellow bell pepper, cut into chunks',
      '1 red onion, cut into wedges',
      '8 oz cremini mushrooms, halved',
      '2 cups broccoli florets',
      '4 tablespoons olive oil',
      '4 cloves garlic, minced',
      '1 tablespoon fresh thyme leaves',
      '1 teaspoon dried Italian seasoning',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '2 tablespoons balsamic glaze',
      '1/4 cup fresh parsley, chopped',
    ],
    instructions: [
      'Preheat oven to 425°F (220°C). Line two large baking sheets with parchment paper.',
      'In a very large bowl, combine all the cut vegetables.',
      'Drizzle with olive oil and add garlic, thyme, Italian seasoning, salt, and pepper. Toss until everything is evenly coated.',
      'Spread vegetables in a single layer across both baking sheets - don\'t overcrowd!',
      'Roast for 20 minutes, then rotate pans and flip vegetables.',
      'Continue roasting for another 15-20 minutes until vegetables are tender and caramelized at the edges.',
      'Transfer to a serving platter.',
      'Drizzle with balsamic glaze and sprinkle with fresh parsley.',
    ],
    category: 'Side Dish',
    tags: ['Vegetables', 'Roasted', 'Sheet Pan', 'Healthy', 'Vegan'],
    servings: '6 servings',
    prepTime: '15',
    cookTime: '40',
    totalTime: '55',
    viewCount: 950,
    saveCount: 140,
    publishedDaysAgo: 30,
  },
  {
    id: 'demo_grandmazing_steak_bites',
    sourceRecipeId: 'seed-uuid-007',
    creatorId: 'demo_grandmazing',
    creatorName: 'Grandmazing',
    creatorProfileSlug: 'grandmazing',
    title: 'Garlic Butter Steak Bites',
    description:
      "My husband requests these every Friday night. The key is getting your pan screaming hot and not moving the steak around too much. Those caramelized edges are pure gold, and the garlic butter at the end ties it all together.",
    ingredients: [
      '1.5 lbs sirloin steak, cut into 1-inch cubes',
      '4 tablespoons butter, divided',
      '2 tablespoons olive oil',
      '6 cloves garlic, minced',
      '1 tablespoon fresh rosemary, chopped',
      '1 tablespoon fresh thyme leaves',
      '1 teaspoon salt',
      '1 teaspoon black pepper',
      '1/2 teaspoon smoked paprika',
      '2 tablespoons fresh parsley, chopped',
    ],
    instructions: [
      'Pat steak cubes completely dry with paper towels. Season generously with salt, pepper, and smoked paprika.',
      'Heat a large cast-iron skillet over high heat until smoking hot.',
      'Add olive oil and 1 tablespoon butter to the pan.',
      'Working in batches to avoid crowding, add steak cubes in a single layer. Let them sear undisturbed for 2 minutes.',
      'Flip and sear another 1-2 minutes for medium-rare. Transfer to a plate.',
      'Reduce heat to medium. Add remaining butter, garlic, rosemary, and thyme.',
      'Cook for 30 seconds until garlic is fragrant but not browned.',
      'Return steak bites to the pan and toss to coat in the garlic butter.',
      'Garnish with fresh parsley and serve immediately.',
    ],
    category: 'Dinner',
    tags: ['Steak', 'Garlic', 'Quick Dinner', 'Cast Iron', 'Date Night'],
    servings: '4 servings',
    prepTime: '10',
    cookTime: '10',
    totalTime: '20',
    viewCount: 220,
    saveCount: 35,
    publishedDaysAgo: 2,
  },
];

// ============================================================================
// Phillip Fry Recipes (5)
// ============================================================================

const PHILLIP_FRY_RECIPES: SeedRecipe[] = [
  {
    id: 'demo_phillipfry_one_pot_pasta',
    sourceRecipeId: 'seed-uuid-008',
    creatorId: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    title: 'Creamy One-Pot Pasta',
    description:
      "This is my go-to weeknight dinner. Everything cooks in one pot - pasta, sauce, everything. The starchy pasta water creates the creamiest sauce without any heavy cream. Plus, minimal dishes to wash. What's not to love?",
    ingredients: [
      '1 lb penne pasta',
      '4 cups chicken broth',
      '2 cups water',
      '1 can (14 oz) diced tomatoes',
      '1 medium onion, thinly sliced',
      '4 cloves garlic, sliced',
      '2 tablespoons olive oil',
      '1 teaspoon dried basil',
      '1/2 teaspoon red pepper flakes',
      '1 teaspoon salt',
      '1 cup fresh spinach',
      '1/2 cup parmesan cheese, grated',
      '1/4 cup fresh basil, torn',
    ],
    instructions: [
      'Combine pasta, chicken broth, water, diced tomatoes, onion, garlic, olive oil, dried basil, red pepper flakes, and salt in a large pot.',
      'Bring to a boil over high heat, stirring occasionally.',
      'Reduce heat to medium and maintain a steady simmer.',
      'Cook for 10-12 minutes, stirring every few minutes, until pasta is al dente and most liquid is absorbed.',
      'The mixture should be saucy but not soupy. If too dry, add a splash of water.',
      'Remove from heat and stir in fresh spinach until wilted.',
      'Add parmesan cheese and stir until melted and creamy.',
      'Taste and adjust seasoning as needed.',
      'Serve topped with fresh torn basil and extra parmesan.',
    ],
    category: 'Dinner',
    tags: ['Pasta', 'One-Pot', 'Weeknight Dinner', 'Easy', 'Vegetarian'],
    servings: '4-6 servings',
    prepTime: '5',
    cookTime: '15',
    totalTime: '20',
    viewCount: 3800,
    saveCount: 550,
    publishedDaysAgo: 5,
  },
  {
    id: 'demo_phillipfry_smashed_potatoes',
    sourceRecipeId: 'seed-uuid-009',
    creatorId: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    title: 'Crispy Smashed Potatoes',
    description:
      "I learned this technique watching cooking videos at 2am and it changed my potato game forever. Boil, smash, roast. That's it. The edges get impossibly crispy while the insides stay fluffy. Perfect for any meal.",
    ingredients: [
      '2 lbs baby gold potatoes',
      '4 tablespoons olive oil',
      '4 tablespoons butter, melted',
      '4 cloves garlic, minced',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '1/2 teaspoon garlic powder',
      '1/4 cup parmesan cheese, grated',
      '2 tablespoons fresh chives, chopped',
      '2 tablespoons fresh parsley, chopped',
      'Sour cream for serving',
    ],
    instructions: [
      'Place potatoes in a large pot, cover with cold salted water. Bring to a boil and cook until fork-tender, about 15-20 minutes.',
      'Preheat oven to 450°F (230°C). Line a baking sheet with parchment paper.',
      'Drain potatoes and arrange on the baking sheet.',
      'Using a fork or the bottom of a glass, gently press down on each potato to flatten to about 1/2 inch thick.',
      'Mix olive oil, melted butter, and minced garlic. Brush generously over each smashed potato.',
      'Season with salt, pepper, and garlic powder.',
      'Roast for 25-30 minutes until edges are golden brown and crispy.',
      'Sprinkle with parmesan cheese and return to oven for 5 more minutes.',
      'Top with fresh chives and parsley. Serve with sour cream.',
    ],
    category: 'Side Dish',
    tags: ['Potatoes', 'Crispy', 'Side Dish', 'Comfort Food', 'Vegetarian'],
    servings: '4 servings',
    prepTime: '10',
    cookTime: '50',
    totalTime: '60',
    viewCount: 1400,
    saveCount: 200,
    publishedDaysAgo: 14,
  },
  {
    id: 'demo_phillipfry_chickpea_salad',
    sourceRecipeId: 'seed-uuid-010',
    creatorId: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    title: 'Lemony Chickpea Salad',
    description:
      "I started meal-prepping this when I was trying to eat healthier. It keeps in the fridge for days and actually tastes better after the flavors meld together. Great on its own, in a wrap, or on top of greens.",
    ingredients: [
      '2 cans (15 oz each) chickpeas, drained and rinsed',
      '1 cucumber, diced',
      '1 cup cherry tomatoes, halved',
      '1/2 red onion, finely diced',
      '1/2 cup kalamata olives, halved',
      '1/2 cup feta cheese, crumbled',
      '1/4 cup fresh parsley, chopped',
      '3 tablespoons olive oil',
      '2 tablespoons lemon juice',
      '1 clove garlic, minced',
      '1 teaspoon dried oregano',
      '1/2 teaspoon salt',
      '1/4 teaspoon black pepper',
    ],
    instructions: [
      'In a large bowl, combine chickpeas, cucumber, tomatoes, red onion, and olives.',
      'In a small bowl, whisk together olive oil, lemon juice, garlic, oregano, salt, and pepper.',
      'Pour dressing over the chickpea mixture and toss to combine.',
      'Add feta cheese and parsley, tossing gently.',
      'Taste and adjust seasoning as needed - it might need more lemon or salt.',
      'For best flavor, refrigerate for at least 30 minutes before serving.',
      'Can be stored in the fridge for up to 5 days.',
    ],
    category: 'Lunch',
    tags: ['Salad', 'Chickpeas', 'Meal Prep', 'Mediterranean', 'Vegetarian'],
    servings: '4 servings',
    prepTime: '15',
    cookTime: '0',
    totalTime: '15',
    viewCount: 180,
    saveCount: 28,
    publishedDaysAgo: 2,
  },
  {
    id: 'demo_phillipfry_pantry_chili',
    sourceRecipeId: 'seed-uuid-011',
    creatorId: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    title: 'Quick Pantry Chili',
    description:
      "Made this for the first time when I had basically nothing in my fridge but a well-stocked pantry. Turns out canned goods can make an incredible chili. Now it's my game day staple.",
    ingredients: [
      '1 lb ground beef',
      '1 can (28 oz) crushed tomatoes',
      '1 can (15 oz) kidney beans, drained',
      '1 can (15 oz) black beans, drained',
      '1 can (15 oz) corn, drained',
      '1 medium onion, diced',
      '3 cloves garlic, minced',
      '2 tablespoons chili powder',
      '1 tablespoon cumin',
      '1 teaspoon smoked paprika',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '1 cup beef broth',
      'Shredded cheese, sour cream, green onions for topping',
    ],
    instructions: [
      'In a large pot or Dutch oven, brown ground beef over medium-high heat, breaking it into crumbles. Drain excess fat.',
      'Add onion and cook for 5 minutes until softened. Add garlic and cook 1 minute more.',
      'Stir in chili powder, cumin, smoked paprika, salt, and pepper. Cook for 30 seconds until fragrant.',
      'Add crushed tomatoes, kidney beans, black beans, corn, and beef broth.',
      'Bring to a boil, then reduce heat and simmer uncovered for 25-30 minutes, stirring occasionally.',
      'The chili should thicken as it simmers. Add more broth if it gets too thick.',
      'Taste and adjust seasonings.',
      'Serve hot with shredded cheese, sour cream, and green onions.',
    ],
    category: 'Dinner',
    tags: ['Chili', 'Beef', 'Pantry Meal', 'Game Day', 'Comfort Food'],
    servings: '6 servings',
    prepTime: '10',
    cookTime: '40',
    totalTime: '50',
    viewCount: 1100,
    saveCount: 160,
    publishedDaysAgo: 30,
  },
  {
    id: 'demo_phillipfry_breakfast_hash',
    sourceRecipeId: 'seed-uuid-012',
    creatorId: 'demo_phillipfry',
    creatorName: 'Phillip Fry',
    creatorProfileSlug: 'phillip-fry',
    title: 'Breakfast Sheet-Pan Hash',
    description:
      "Brunch for a crowd without standing over a stove? Yes please. Everything roasts on one pan while you make coffee and set the table. The runny egg yolks mixing with the crispy potatoes is absolutely perfect.",
    ingredients: [
      '1.5 lbs baby potatoes, quartered',
      '1 red bell pepper, diced',
      '1 green bell pepper, diced',
      '1 medium onion, diced',
      '8 oz breakfast sausage, crumbled (or sliced kielbasa)',
      '4 tablespoons olive oil',
      '1 teaspoon paprika',
      '1 teaspoon garlic powder',
      '1 teaspoon salt',
      '1/2 teaspoon black pepper',
      '4-6 large eggs',
      '1/4 cup fresh chives, chopped',
      'Hot sauce for serving',
    ],
    instructions: [
      'Preheat oven to 425°F (220°C). Line a large sheet pan with parchment paper.',
      'Toss potatoes with 2 tablespoons olive oil, paprika, garlic powder, salt, and pepper. Spread on the pan.',
      'Roast for 20 minutes until potatoes start to get tender.',
      'Remove pan and add bell peppers, onion, and sausage. Drizzle with remaining olive oil and toss everything together.',
      'Spread in an even layer and roast for another 15-20 minutes until vegetables are tender and sausage is cooked.',
      'Remove pan and create 4-6 wells in the hash. Crack an egg into each well.',
      'Season eggs with salt and pepper. Return to oven for 8-10 minutes until egg whites are set but yolks are still runny.',
      'Sprinkle with fresh chives and serve immediately with hot sauce.',
    ],
    category: 'Breakfast',
    tags: ['Breakfast', 'Sheet Pan', 'Eggs', 'Brunch', 'Meal Prep'],
    servings: '4-6 servings',
    prepTime: '15',
    cookTime: '50',
    totalTime: '65',
    viewCount: 320,
    saveCount: 45,
    publishedDaysAgo: 5,
  },
];

// ============================================================================
// Exports
// ============================================================================

export const ALL_RECIPES: SeedRecipe[] = [...GRANDMAZING_RECIPES, ...PHILLIP_FRY_RECIPES];

export function getRecipesByCreator(creatorId: string): SeedRecipe[] {
  return ALL_RECIPES.filter((r) => r.creatorId === creatorId);
}

export function getCreatorById(creatorId: string): DemoCreator | undefined {
  return DEMO_CREATORS.find((c) => c.id === creatorId);
}
