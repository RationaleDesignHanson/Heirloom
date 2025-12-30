import Foundation

/// Library of sample recipes for testing and demonstration
struct SampleRecipeData {
    let recipe: Recipe
    let ingredients: [String]
    let imageURL: String
    let cardBack: CardBackData
    let comments: [String]

    struct CardBackData {
        let noteToFriends: String?
        let personalTips: [String]
        let rating: Int?
    }
}

struct SampleRecipeLibrary {
    static var all: [SampleRecipeData] {
        [
            chocolateChipCookies,
            spaghettiCarbonara,
            chickenStirFry,
            classicPancakes,
            tacos,
            tomatoSoup,
            caesarSalad,
            grilledCheese,
            beefStew,
            bananaBread,
            lasagna,
            roastedChicken
        ]
    }

    // MARK: - Recipe 1: Chocolate Chip Cookies
    static var chocolateChipCookies: SampleRecipeData {
        let recipe = Recipe(
            title: "Grandma's Chocolate Chip Cookies",
            sourceType: .family,
            instructions: [
                "Preheat oven to 375°F",
                "Cream together butter and sugars",
                "Beat in eggs and vanilla",
                "Gradually blend in dry ingredients",
                "Stir in chocolate chips",
                "Drop by rounded tablespoon onto ungreased cookie sheets",
                "Bake for 9 to 11 minutes or until golden brown"
            ],
            servings: "48 cookies",
            prepTime: "15 min",
            cookTime: "11 min"
        )
        recipe.sourcePerson = "Grandma Rose"
        recipe.sourceDate = "1987"
        recipe.timesCooked = 12
        recipe.isFavorite = true

        let ingredients = [
            "2 1/4 cups all-purpose flour",
            "1 teaspoon baking soda",
            "1 teaspoon salt",
            "1 cup butter, softened",
            "3/4 cup granulated sugar",
            "3/4 cup packed brown sugar",
            "2 large eggs",
            "2 teaspoons vanilla extract",
            "2 cups chocolate chips"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "This is my grandmother's famous recipe! These cookies have been bringing joy to our family for decades. The secret is using real butter and not over-baking them.",
            personalTips: [
                "Don't skip the rest time - let dough chill for 30 min for thicker cookies",
                "Use a cookie scoop for perfectly uniform sizes",
                "They're done when edges are golden but centers still look slightly underdone"
            ],
            rating: 5
        )

        let comments = [
            "Pro tip: Add a pinch of sea salt on top before baking for that bakery-style finish!",
            "I use half dark chocolate, half milk chocolate chips for more complex flavor",
            "These freeze beautifully - I always make a double batch"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 2: Spaghetti Carbonara
    static var spaghettiCarbonara: SampleRecipeData {
        let recipe = Recipe(
            title: "Spaghetti Carbonara",
            sourceType: .url,
            instructions: [
                "Cook spaghetti according to package directions",
                "Fry bacon until crispy, then chop",
                "Whisk eggs, Parmesan, and black pepper in a bowl",
                "Drain pasta, reserving 1 cup pasta water",
                "Toss hot pasta with bacon",
                "Remove from heat, add egg mixture, toss quickly",
                "Add pasta water as needed for creamy sauce"
            ],
            servings: "4 servings",
            prepTime: "10 min",
            cookTime: "20 min"
        )
        recipe.timesCooked = 8

        let ingredients = [
            "1 pound spaghetti",
            "6 slices bacon",
            "4 large eggs",
            "1 cup grated Parmesan cheese",
            "2 teaspoons black pepper",
            "1 teaspoon salt",
            "2 cloves garlic, minced",
            "1/4 cup fresh parsley, chopped"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "Authentic Roman carbonara - creamy without cream! The key is using the pasta water and residual heat to cook the eggs without scrambling them.",
            personalTips: [
                "Use the best quality Parmesan you can find - it makes all the difference",
                "Work quickly when adding eggs - have everything ready before draining pasta",
                "The pasta must be hot enough to cook the eggs but not scramble them"
            ],
            rating: 5
        )

        let comments = [
            "If you're nervous about raw eggs, temper them first with a bit of hot pasta water",
            "Guanciale is traditional, but bacon works great and is easier to find",
            "Save extra pasta water - you can always add more but can't take it away!"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 3: Chicken Stir-Fry
    static var chickenStirFry: SampleRecipeData {
        let recipe = Recipe(
            title: "Quick Chicken Stir-Fry",
            sourceType: .manual,
            instructions: [
                "Cut chicken into bite-sized pieces",
                "Heat oil in wok or large skillet",
                "Cook chicken until no longer pink",
                "Add vegetables, stir-fry 3-4 minutes",
                "Mix soy sauce, garlic, ginger",
                "Pour sauce over chicken and veggies",
                "Serve over rice"
            ],
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "15 min"
        )
        recipe.timesCooked = 15

        let ingredients = [
            "1 1/2 pounds chicken breast",
            "2 cups broccoli florets",
            "1 red bell pepper, sliced",
            "1/4 cup soy sauce",
            "2 tablespoons vegetable oil",
            "3 cloves garlic, minced",
            "1 tablespoon fresh ginger, grated",
            "2 tablespoons cornstarch",
            "1 tablespoon sesame oil",
            "2 green onions, sliced"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "My go-to weeknight dinner! This stir-fry comes together in under 30 minutes and is endlessly customizable with whatever vegetables you have on hand.",
            personalTips: [
                "Cut everything before you start cooking - stir-frying moves fast!",
                "Get your wok smoking hot for the best flavor and texture",
                "Don't overcrowd the pan - cook in batches if needed"
            ],
            rating: 4
        )

        let comments = [
            "I add a tablespoon of hoisin sauce for extra depth of flavor",
            "Cashews or peanuts are a great addition for crunch",
            "Works great with shrimp instead of chicken - just reduce cook time"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 4: Classic Pancakes
    static var classicPancakes: SampleRecipeData {
        let recipe = Recipe(
            title: "Classic Buttermilk Pancakes",
            sourceType: .cookbook,
            instructions: [
                "Whisk flour, sugar, baking powder, salt",
                "In separate bowl, beat eggs, buttermilk, melted butter",
                "Pour wet ingredients into dry ingredients",
                "Stir until just combined (lumps are okay)",
                "Heat griddle to 375°F",
                "Pour 1/4 cup batter per pancake",
                "Flip when bubbles form and edges look dry"
            ],
            servings: "12 pancakes",
            prepTime: "10 min",
            cookTime: "15 min"
        )
        recipe.sourceBookTitle = "The Joy of Cooking"

        let ingredients = [
            "2 cups all-purpose flour",
            "2 tablespoons sugar",
            "2 teaspoons baking powder",
            "1 teaspoon salt",
            "1/2 teaspoon baking soda",
            "2 large eggs",
            "2 cups buttermilk",
            "1/4 cup butter, melted",
            "1 teaspoon vanilla extract"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "The fluffiest pancakes you'll ever make! The secret is in the buttermilk and not overmixing the batter. Perfect for lazy Sunday mornings.",
            personalTips: [
                "Don't overmix! Lumpy batter = fluffy pancakes",
                "Let batter rest 5 minutes before cooking for extra fluffiness",
                "Keep finished pancakes warm in a 200°F oven while cooking the rest"
            ],
            rating: 5
        )

        let comments = [
            "Add blueberries or chocolate chips right after pouring batter on griddle",
            "I substitute half the flour with whole wheat for heartier pancakes",
            "These freeze great - just pop in the toaster for quick breakfasts!"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1528207776546-365bb710ee93?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 5: Tacos
    static var tacos: SampleRecipeData {
        let recipe = Recipe(
            title: "Easy Beef Tacos",
            sourceType: .manual,
            instructions: [
                "Brown ground beef in large skillet",
                "Drain excess fat",
                "Add taco seasoning and water",
                "Simmer 5 minutes until thickened",
                "Warm taco shells",
                "Fill shells with beef",
                "Top with cheese, lettuce, tomato, sour cream"
            ],
            servings: "8 tacos",
            prepTime: "10 min",
            cookTime: "15 min"
        )
        recipe.timesCooked = 20

        let ingredients = [
            "1 pound ground beef",
            "1 packet taco seasoning",
            "3/4 cup water",
            "8 taco shells",
            "1 cup shredded cheddar cheese",
            "2 cups shredded lettuce",
            "1 large tomato, diced",
            "1/2 cup sour cream",
            "1/2 cup salsa",
            "1 avocado, sliced"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "Taco Tuesday essential! This is our family's go-to quick dinner. Simple, customizable, and everyone loves building their own tacos.",
            personalTips: [
                "Toast shells in the oven for 5 min at 350°F for extra crunch",
                "Use 85% lean beef for best flavor without too much grease",
                "Set up a taco bar and let everyone customize their own"
            ],
            rating: 4
        )

        let comments = [
            "I use ground turkey for a lighter version - works great!",
            "Add jalapeños for heat or leave them on the side for picky eaters",
            "Leftover taco meat is perfect for nachos the next day"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 6: Tomato Soup
    static var tomatoSoup: SampleRecipeData {
        let recipe = Recipe(
            title: "Creamy Tomato Soup",
            sourceType: .cookbook,
            instructions: [
                "Sauté onion and garlic in butter",
                "Add tomatoes, broth, sugar",
                "Simmer 20 minutes",
                "Blend until smooth",
                "Stir in cream",
                "Season with salt and pepper",
                "Garnish with basil"
            ],
            servings: "6 servings",
            prepTime: "10 min",
            cookTime: "30 min"
        )
        recipe.sourceBookTitle = "Soups & Stews"

        let ingredients = [
            "2 tablespoons butter",
            "1 onion, diced",
            "2 cloves garlic, minced",
            "2 cans (28 oz each) crushed tomatoes",
            "2 cups vegetable broth",
            "1 tablespoon sugar",
            "1/2 cup heavy cream",
            "1 teaspoon salt",
            "1/2 teaspoon black pepper",
            "Fresh basil for garnish"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "The ultimate comfort food! Perfect with grilled cheese sandwiches. This soup is so much better than anything from a can and comes together in under an hour.",
            personalTips: [
                "Use fire-roasted tomatoes for extra depth of flavor",
                "An immersion blender makes this super easy - no need to transfer to a regular blender",
                "Add a pinch of red pepper flakes for a little kick"
            ],
            rating: 5
        )

        let comments = [
            "I make a big batch and freeze in portions for quick lunches",
            "Swap cream for coconut milk to make it dairy-free",
            "Fresh tomatoes in summer are amazing - use 3 lbs and roast them first"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1547592166-23ac45744acd?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 7: Caesar Salad
    static var caesarSalad: SampleRecipeData {
        let recipe = Recipe(
            title: "Classic Caesar Salad",
            sourceType: .url,
            instructions: [
                "Whisk together lemon juice, garlic, Dijon",
                "Slowly whisk in olive oil",
                "Stir in Parmesan",
                "Season with salt and pepper",
                "Toss romaine with dressing",
                "Top with croutons and extra Parmesan"
            ],
            servings: "4 servings",
            prepTime: "15 min",
            cookTime: "0 min"
        )

        let ingredients = [
            "1 large head romaine lettuce, chopped",
            "1/4 cup lemon juice",
            "2 cloves garlic, minced",
            "1 teaspoon Dijon mustard",
            "1/2 cup olive oil",
            "1/2 cup grated Parmesan cheese",
            "2 cups croutons",
            "1/2 teaspoon salt",
            "1/4 teaspoon black pepper",
            "4 anchovy fillets (optional)"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "The classic restaurant favorite made at home! This dressing is so much better than store-bought. Make extra - it keeps for a week in the fridge.",
            personalTips: [
                "Dry your lettuce really well - wet lettuce makes watery dressing",
                "Make your own croutons from day-old bread - toast with olive oil and garlic",
                "Add grilled chicken to make it a complete meal"
            ],
            rating: 4
        )

        let comments = [
            "I skip the anchovies and add a splash of Worcestershire sauce instead",
            "Massage the lettuce for 30 seconds before dressing for a more tender salad",
            "This dressing is also fantastic on roasted vegetables!"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1546793665-c74683f339c1?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 8: Grilled Cheese
    static var grilledCheese: SampleRecipeData {
        let recipe = Recipe(
            title: "Perfect Grilled Cheese",
            sourceType: .manual,
            instructions: [
                "Butter one side of each bread slice",
                "Place cheese between unbuttered sides",
                "Heat skillet over medium heat",
                "Cook sandwich 3-4 minutes per side",
                "Flip when golden brown",
                "Remove when cheese is melted"
            ],
            servings: "1 sandwich",
            prepTime: "5 min",
            cookTime: "8 min"
        )
        recipe.timesCooked = 25

        let ingredients = [
            "2 slices sourdough bread",
            "2 tablespoons butter, softened",
            "2 slices sharp cheddar cheese",
            "2 slices Gruyère cheese",
            "1 tablespoon Dijon mustard (optional)",
            "2 slices tomato (optional)",
            "4 slices bacon, cooked (optional)",
            "1 teaspoon garlic powder"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "The simple comfort food that never gets old! While the classic is perfect, don't be afraid to mix in different cheeses or add-ins for variety.",
            personalTips: [
                "Use mayo instead of butter on the outside for extra crispy bread",
                "Mix cheeses - cheddar + Gruyère is my favorite combo",
                "Low and slow wins the race - medium heat ensures melted cheese and golden bread"
            ],
            rating: 5
        )

        let comments = [
            "Add a thin slice of apple for a sweet-savory twist!",
            "Sourdough bread makes all the difference - try it!",
            "I always make tomato soup when I make grilled cheese - perfect pairing"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1528736235302-52922df5c122?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 9: Beef Stew
    static var beefStew: SampleRecipeData {
        let recipe = Recipe(
            title: "Hearty Beef Stew",
            sourceType: .family,
            instructions: [
                "Brown beef cubes in large pot",
                "Add onions and garlic, cook 3 minutes",
                "Add broth, tomato paste, herbs",
                "Bring to boil, then simmer 1 hour",
                "Add potatoes, carrots, celery",
                "Simmer 30 more minutes until tender",
                "Season with salt and pepper"
            ],
            servings: "8 servings",
            prepTime: "20 min",
            cookTime: "1 hour 45 min"
        )
        recipe.sourcePerson = "Mom"
        recipe.timesCooked = 10

        let ingredients = [
            "2 pounds beef stew meat",
            "1 onion, diced",
            "3 cloves garlic, minced",
            "4 cups beef broth",
            "2 tablespoons tomato paste",
            "1 teaspoon dried thyme",
            "2 bay leaves",
            "4 potatoes, cubed",
            "3 carrots, sliced",
            "2 celery stalks, sliced",
            "Salt and pepper to taste"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "Mom's famous stew that warms you up on cold winter days. This is true comfort food - it tastes even better the next day after the flavors have had time to meld.",
            personalTips: [
                "Don't skip browning the meat - it adds so much flavor!",
                "Use a Dutch oven if you have one - perfect for this recipe",
                "Add a splash of red wine with the broth for extra richness"
            ],
            rating: 5
        )

        let comments = [
            "I add frozen peas in the last 5 minutes for extra color",
            "Cornstarch slurry at the end if you want thicker gravy",
            "This freezes beautifully - I always make a double batch"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1608039755401-742074f0548d?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 10: Banana Bread
    static var bananaBread: SampleRecipeData {
        let recipe = Recipe(
            title: "Classic Banana Bread",
            sourceType: .cookbook,
            instructions: [
                "Preheat oven to 350°F",
                "Grease a 9x5 inch loaf pan",
                "Mash bananas in large bowl",
                "Mix in melted butter, sugar, egg, vanilla",
                "Sprinkle baking soda and salt over mixture",
                "Stir in flour until just combined",
                "Pour into pan, bake 60 minutes"
            ],
            servings: "1 loaf",
            prepTime: "15 min",
            cookTime: "60 min"
        )
        recipe.sourceBookTitle = "Better Homes & Gardens"

        let ingredients = [
            "3 ripe bananas, mashed",
            "1/3 cup butter, melted",
            "3/4 cup sugar",
            "1 large egg, beaten",
            "1 teaspoon vanilla extract",
            "1 teaspoon baking soda",
            "1/4 teaspoon salt",
            "1 1/2 cups all-purpose flour",
            "1/2 cup chopped walnuts (optional)",
            "1/2 teaspoon cinnamon"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "The perfect way to use up overripe bananas! This recipe has been in my family for generations. The house smells amazing while it bakes.",
            personalTips: [
                "The blacker the bananas, the better - seriously!",
                "Don't overmix the batter - it should still be slightly lumpy",
                "A toothpick inserted in center should come out with just a few moist crumbs"
            ],
            rating: 5
        )

        let comments = [
            "I add chocolate chips for a decadent twist - about 3/4 cup",
            "Freeze ripe bananas when you have them - perfect for this recipe later",
            "This keeps for 4-5 days wrapped tightly, or freeze slices for quick snacks"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1606890737304-57a1ca8a5b62?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 11: Lasagna
    static var lasagna: SampleRecipeData {
        let recipe = Recipe(
            title: "Meat Lasagna",
            sourceType: .family,
            instructions: [
                "Brown ground beef with onion and garlic",
                "Stir in tomato sauce and seasonings, simmer 30 min",
                "Mix ricotta, egg, and parsley",
                "Cook lasagna noodles according to package",
                "Layer sauce, noodles, ricotta, mozzarella",
                "Repeat layers twice",
                "Top with remaining mozzarella and Parmesan",
                "Bake at 375°F for 25 minutes"
            ],
            servings: "12 servings",
            prepTime: "30 min",
            cookTime: "55 min"
        )
        recipe.sourcePerson = "Aunt Maria"
        recipe.isFavorite = true
        recipe.timesCooked = 6

        let ingredients = [
            "1 pound ground beef",
            "1 onion, diced",
            "3 cloves garlic, minced",
            "2 jars (24 oz each) marinara sauce",
            "1 teaspoon dried basil",
            "1 teaspoon dried oregano",
            "16 ounces ricotta cheese",
            "1 large egg",
            "1/4 cup fresh parsley, chopped",
            "12 lasagna noodles",
            "3 cups shredded mozzarella cheese",
            "1/2 cup grated Parmesan cheese"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "Aunt Maria's famous lasagna that she makes for every family gathering! This is the recipe everyone asks for. It feeds a crowd and tastes even better as leftovers.",
            personalTips: [
                "Use no-boil noodles to save time - they work perfectly!",
                "Let it rest 15 minutes after baking for cleaner slices",
                "Cover with foil for first 20 min, then uncover to brown the cheese"
            ],
            rating: 5
        )

        let comments = [
            "I add Italian sausage along with the beef for extra flavor",
            "Make ahead and refrigerate overnight - even better the next day!",
            "This freezes beautifully - I make two and freeze one for busy weeks"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1574894709920-11b28e7367e3?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }

    // MARK: - Recipe 12: Roasted Chicken
    static var roastedChicken: SampleRecipeData {
        let recipe = Recipe(
            title: "Herb Roasted Chicken",
            sourceType: .cookbook,
            instructions: [
                "Preheat oven to 425°F",
                "Pat chicken dry with paper towels",
                "Mix butter, garlic, herbs, salt, pepper",
                "Rub mixture under and over chicken skin",
                "Place lemon halves and rosemary inside cavity",
                "Tie legs together with kitchen twine",
                "Roast 1 hour 15 minutes until golden",
                "Let rest 15 minutes before carving"
            ],
            servings: "6 servings",
            prepTime: "15 min",
            cookTime: "1 hour 15 min"
        )
        recipe.sourceBookTitle = "The Art of Simple Food"

        let ingredients = [
            "1 whole chicken, 4-5 pounds",
            "4 tablespoons butter, softened",
            "4 cloves garlic, minced",
            "2 teaspoons dried thyme",
            "1 teaspoon dried rosemary",
            "2 teaspoons salt",
            "1 teaspoon black pepper",
            "1 lemon, halved",
            "Fresh rosemary sprigs",
            "1 tablespoon olive oil"
        ]

        let cardBack = SampleRecipeData.CardBackData(
            noteToFriends: "A perfectly roasted chicken is a fundamental skill every cook should master. This recipe produces crispy golden skin and juicy, flavorful meat every single time.",
            personalTips: [
                "Dry skin = crispy skin! Pat it really well with paper towels",
                "Use a meat thermometer - breast should hit 165°F, thigh 175°F",
                "Save the bones for homemade chicken stock!"
            ],
            rating: 5
        )

        let comments = [
            "I stuff the cavity with onion quarters and fresh herbs for extra flavor",
            "Roast on a bed of root vegetables for an easy one-pan meal",
            "Leftover chicken is perfect for sandwiches, salads, or chicken soup"
        ]

        return SampleRecipeData(
            recipe: recipe,
            ingredients: ingredients,
            imageURL: "https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800&q=80",
            cardBack: cardBack,
            comments: comments
        )
    }
}
