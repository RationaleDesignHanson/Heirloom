import Foundation

enum RecipeKeywords {

    static let ingredients: Set<String> = [
        // Baking
        "flour", "sugar", "salt", "butter", "oil", "egg", "eggs", "yeast",
        "baking powder", "baking soda", "vanilla", "cocoa", "chocolate",
        // Dairy
        "milk", "cream", "cheese", "yogurt", "sour cream", "ricotta", "mozzarella",
        "parmesan", "cheddar", "feta", "goat cheese", "cream cheese",
        // Proteins
        "chicken", "beef", "pork", "fish", "salmon", "shrimp", "tofu", "bacon",
        "sausage", "lamb", "turkey", "duck", "crab", "lobster", "scallops",
        "steak", "ground beef", "chicken breast", "thighs",
        // Vegetables
        "garlic", "onion", "tomato", "pepper", "carrot", "celery", "potato",
        "broccoli", "spinach", "lettuce", "mushroom", "zucchini", "eggplant",
        "cucumber", "avocado", "corn", "beans", "peas", "asparagus",
        "bell pepper", "jalape\u{00F1}o", "green beans", "cabbage", "kale",
        // Fruits
        "lemon", "lime", "orange", "apple", "banana", "strawberry", "blueberry",
        "raspberry", "blackberry", "mango", "pineapple", "peach", "pear",
        // Grains
        "rice", "pasta", "noodles", "bread", "tortilla", "quinoa", "oats",
        "couscous", "barley", "bulgur", "farro", "spaghetti", "penne",
        // Condiments & Sauces
        "soy sauce", "vinegar", "mustard", "ketchup", "mayonnaise", "honey",
        "olive oil", "vegetable oil", "sesame oil", "hot sauce", "worcestershire",
        "fish sauce", "oyster sauce", "sriracha",
        // Herbs & Spices
        "basil", "oregano", "thyme", "rosemary", "cilantro", "parsley",
        "cumin", "paprika", "cinnamon", "ginger", "turmeric", "pepper",
        "black pepper", "cayenne", "chili powder", "garlic powder", "onion powder",
        "bay leaf", "bay leaves", "mint", "dill", "sage", "tarragon",
        // Nuts & Seeds
        "almonds", "walnuts", "pecans", "cashews", "peanuts", "sesame seeds",
        "sunflower seeds", "pumpkin seeds", "pine nuts",
        // Other Common
        "stock", "broth", "water", "wine", "beer", "coconut milk", "almond milk"
    ]

    static let cookingVerbs: Set<String> = [
        "add", "mix", "stir", "whisk", "fold", "pour", "bake", "cook", "fry",
        "saut\u{00E9}", "saute", "boil", "simmer", "roast", "chop", "dice", "slice",
        "mince", "grate", "peel", "marinate", "season", "taste", "serve",
        "plate", "combine", "blend", "knead", "roll", "spread", "drizzle",
        "garnish", "broil", "grill", "steam", "poach", "braise", "sear",
        "caramelize", "deglaze", "reduce", "whip", "cream", "melt", "heat",
        "preheat", "brown", "toss", "flip", "coat", "drain", "rinse",
        "squeeze", "zest", "julienne", "blanch", "toast", "grind"
    ]

    static let measurements: Set<String> = [
        "cup", "cups", "tablespoon", "tablespoons", "tbsp", "teaspoon",
        "teaspoons", "tsp", "ounce", "ounces", "oz", "pound", "pounds",
        "lb", "lbs", "gram", "grams", "g", "kilogram", "kg", "milliliter",
        "ml", "liter", "pinch", "dash", "handful", "bunch", "clove", "cloves",
        "quart", "gallon", "pint", "fluid ounce", "fl oz"
    ]

    static let cookingTerms: Set<String> = [
        "preheat", "oven", "degrees", "fahrenheit", "celsius", "temperature",
        "minutes", "minute", "hours", "hour", "seconds", "medium", "high",
        "low", "heat", "golden", "brown", "crispy", "tender", "done", "ready",
        "room temperature", "refrigerate", "freeze", "thaw", "rest", "cool",
        "skillet", "pan", "pot", "saucepan", "baking sheet", "bowl", "mixer",
        "food processor", "blender", "spatula", "whisk", "spoon", "knife",
        "cutting board", "recipe", "ingredients", "instructions", "directions"
    ]

    /// Calculate recipe relevance score (0-1)
    static func relevanceScore(for text: String) -> Float {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let uniqueWords = Set(words)

        var score: Float = 0
        score += Float(uniqueWords.intersection(ingredients).count) * 2.0
        score += Float(uniqueWords.intersection(cookingVerbs).count) * 1.5
        score += Float(uniqueWords.intersection(measurements).count) * 2.0
        score += Float(uniqueWords.intersection(cookingTerms).count) * 1.0

        // Normalize to 0-1 (max expected ~30 hits for a good recipe video)
        let maxExpectedScore: Float = 30.0
        return min(score / maxExpectedScore, 1.0)
    }
}
