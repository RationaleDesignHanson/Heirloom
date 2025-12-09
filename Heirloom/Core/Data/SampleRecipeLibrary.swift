import Foundation

/// Library of sample recipes for testing and demonstration
struct SampleRecipeData {
    let recipe: Recipe
    let ingredients: [String]
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

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "1 teaspoon salt"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "1 tablespoon fresh ginger, grated"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "2 large eggs",
            "2 cups buttermilk",
            "1/4 cup butter, melted"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "1/2 cup sour cream"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "2 cans crushed tomatoes",
            "2 cups vegetable broth",
            "1 tablespoon sugar",
            "1/2 cup heavy cream",
            "1 teaspoon salt",
            "1/2 teaspoon black pepper",
            "Fresh basil for garnish"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "1/4 teaspoon black pepper"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "2 slices bread",
            "2 tablespoons butter",
            "2 slices cheddar cheese"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "1 1/2 cups all-purpose flour"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "2 jars marinara sauce",
            "1 teaspoon dried basil",
            "1 teaspoon dried oregano",
            "16 ounces ricotta cheese",
            "1 large egg",
            "1/4 cup fresh parsley, chopped",
            "12 lasagna noodles",
            "3 cups shredded mozzarella cheese",
            "1/2 cup grated Parmesan cheese"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
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
            "Fresh rosemary sprigs"
        ]

        return SampleRecipeData(recipe: recipe, ingredients: ingredients)
    }
}
