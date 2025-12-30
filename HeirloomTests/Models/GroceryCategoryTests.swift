import XCTest
@testable import Heirloom

final class GroceryCategoryTests: XCTestCase {

    // MARK: - Frozen Category Tests

    func testCategorize_Frozen_IceCream() {
        XCTAssertEqual(GroceryCategory.categorize("vanilla ice cream"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("ice-cream"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("Ice Cream"), .frozen, "Should be case insensitive")
    }

    func testCategorize_Frozen_CheckedBeforeDairy() {
        // "ice cream" contains "cream" but should be frozen, not dairy
        let result = GroceryCategory.categorize("chocolate ice cream")
        XCTAssertEqual(result, .frozen, "Should prioritize frozen over dairy")
    }

    func testCategorize_Frozen_Popsicle() {
        XCTAssertEqual(GroceryCategory.categorize("popsicle"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("orange popsicle"), .frozen)
    }

    func testCategorize_Frozen_FrozenKeyword() {
        XCTAssertEqual(GroceryCategory.categorize("frozen peas"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("frozen vegetables"), .frozen)
        XCTAssertEqual(GroceryCategory.categorize("Frozen broccoli"), .frozen)
    }

    // MARK: - Beverages Category Tests

    func testCategorize_Beverages_Juice() {
        XCTAssertEqual(GroceryCategory.categorize("orange juice"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("apple juice"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("juice"), .beverages)
    }

    func testCategorize_Beverages_CheckedBeforeProduce() {
        // "orange juice" contains "orange" but should be beverages, not produce
        let result = GroceryCategory.categorize("orange juice")
        XCTAssertEqual(result, .beverages, "Should prioritize beverages over produce")
    }

    func testCategorize_Beverages_Coffee() {
        XCTAssertEqual(GroceryCategory.categorize("coffee"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("ground coffee"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("Coffee beans"), .beverages)
    }

    func testCategorize_Beverages_Tea() {
        XCTAssertEqual(GroceryCategory.categorize("tea"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("green tea"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("Tea bags"), .beverages)
    }

    func testCategorize_Beverages_Soda() {
        XCTAssertEqual(GroceryCategory.categorize("soda"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("cola soda"), .beverages)
    }

    func testCategorize_Beverages_NotBakingSoda() {
        // "baking soda" should NOT be categorized as beverages
        let result = GroceryCategory.categorize("baking soda")
        XCTAssertNotEqual(result, .beverages, "Should exclude 'baking soda' from beverages")
        XCTAssertEqual(result, .pantry, "Baking soda should be pantry")
    }

    func testCategorize_Beverages_Water() {
        XCTAssertEqual(GroceryCategory.categorize("water"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("sparkling water"), .beverages)
    }

    // MARK: - Dairy & Eggs Category Tests

    func testCategorize_Dairy_Milk() {
        XCTAssertEqual(GroceryCategory.categorize("milk"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("whole milk"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("Milk"), .dairy, "Should be case insensitive")
    }

    func testCategorize_Dairy_Cheese() {
        XCTAssertEqual(GroceryCategory.categorize("cheese"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("cheddar cheese"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("shredded cheese"), .dairy)
    }

    func testCategorize_Dairy_Butter() {
        XCTAssertEqual(GroceryCategory.categorize("butter"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("unsalted butter"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("Butter"), .dairy)
    }

    func testCategorize_Dairy_Cream() {
        XCTAssertEqual(GroceryCategory.categorize("cream"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("heavy cream"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("whipped cream"), .dairy)
    }

    func testCategorize_Dairy_Yogurt() {
        XCTAssertEqual(GroceryCategory.categorize("yogurt"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("greek yogurt"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("Yogurt"), .dairy)
    }

    func testCategorize_Dairy_Egg() {
        XCTAssertEqual(GroceryCategory.categorize("egg"), .dairy, "Should match hasPrefix('egg')")
        XCTAssertEqual(GroceryCategory.categorize("eggs"), .dairy, "Should match hasPrefix('egg')")
        XCTAssertEqual(GroceryCategory.categorize("large eggs"), .dairy, "Should match ' egg'")
        XCTAssertEqual(GroceryCategory.categorize("2 eggs"), .dairy, "Should match ' egg'")
    }

    func testCategorize_Dairy_NotEggplant() {
        // "eggplant" should NOT be categorized as dairy
        let result = GroceryCategory.categorize("eggplant")
        XCTAssertNotEqual(result, .dairy, "Should not match 'eggplant' as egg")
        XCTAssertEqual(result, .other, "Eggplant should fall through to other (not in produce keywords)")
    }

    // MARK: - Meat & Seafood Category Tests

    func testCategorize_Meat_Chicken() {
        XCTAssertEqual(GroceryCategory.categorize("chicken"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("chicken breast"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("Chicken thighs"), .meat)
    }

    func testCategorize_Meat_Beef() {
        XCTAssertEqual(GroceryCategory.categorize("beef"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("ground beef"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("Beef steak"), .meat)
    }

    func testCategorize_Meat_Pork() {
        XCTAssertEqual(GroceryCategory.categorize("pork"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("pork chops"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("ground pork"), .meat)
    }

    func testCategorize_Meat_Fish() {
        XCTAssertEqual(GroceryCategory.categorize("fish"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("fresh fish"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("Fish fillet"), .meat)
    }

    func testCategorize_Meat_Bacon() {
        XCTAssertEqual(GroceryCategory.categorize("bacon"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("thick-cut bacon"), .meat)
    }

    func testCategorize_Meat_Sausage() {
        XCTAssertEqual(GroceryCategory.categorize("sausage"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("Italian sausage"), .meat)
    }

    func testCategorize_Meat_Turkey() {
        XCTAssertEqual(GroceryCategory.categorize("turkey"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("ground turkey"), .meat)
    }

    func testCategorize_Meat_Salmon() {
        XCTAssertEqual(GroceryCategory.categorize("salmon"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("salmon fillet"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("Salmon"), .meat)
    }

    func testCategorize_Meat_Tuna() {
        XCTAssertEqual(GroceryCategory.categorize("tuna"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("tuna steak"), .meat)
    }

    func testCategorize_Meat_Shrimp() {
        XCTAssertEqual(GroceryCategory.categorize("shrimp"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("large shrimp"), .meat)
    }

    func testCategorize_Meat_Cod() {
        XCTAssertEqual(GroceryCategory.categorize("cod"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("cod fillet"), .meat)
    }

    // MARK: - Produce Category Tests

    func testCategorize_Produce_Apple() {
        XCTAssertEqual(GroceryCategory.categorize("apple"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("apples"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("Apple"), .produce)
    }

    func testCategorize_Produce_Tomato() {
        XCTAssertEqual(GroceryCategory.categorize("tomato"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("tomatoes"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("cherry tomato"), .produce)
    }

    func testCategorize_Produce_Onion() {
        XCTAssertEqual(GroceryCategory.categorize("onion"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("red onion"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("Onions"), .produce)
    }

    func testCategorize_Produce_Garlic() {
        XCTAssertEqual(GroceryCategory.categorize("garlic"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("garlic cloves"), .produce)
    }

    func testCategorize_Produce_Lettuce() {
        XCTAssertEqual(GroceryCategory.categorize("lettuce"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("romaine lettuce"), .produce)
    }

    func testCategorize_Produce_Carrot() {
        XCTAssertEqual(GroceryCategory.categorize("carrot"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("carrots"), .produce)
    }

    func testCategorize_Produce_Celery() {
        XCTAssertEqual(GroceryCategory.categorize("celery"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("celery stalks"), .produce)
    }

    func testCategorize_Produce_Potato() {
        XCTAssertEqual(GroceryCategory.categorize("potato"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("potatoes"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("russet potato"), .produce)
    }

    func testCategorize_Produce_Lemon() {
        XCTAssertEqual(GroceryCategory.categorize("lemon"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("lemons"), .produce)
    }

    func testCategorize_Produce_Lime() {
        XCTAssertEqual(GroceryCategory.categorize("lime"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("limes"), .produce)
    }

    func testCategorize_Produce_Orange() {
        XCTAssertEqual(GroceryCategory.categorize("orange"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("oranges"), .produce)
    }

    func testCategorize_Produce_Banana() {
        XCTAssertEqual(GroceryCategory.categorize("banana"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("bananas"), .produce)
    }

    // MARK: - Bakery Category Tests

    func testCategorize_Bakery_Bread() {
        XCTAssertEqual(GroceryCategory.categorize("bread"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("sourdough bread"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("Bread"), .bakery)
    }

    func testCategorize_Bakery_Roll() {
        XCTAssertEqual(GroceryCategory.categorize("roll"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("rolls"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("dinner rolls"), .bakery)
    }

    func testCategorize_Bakery_Bun() {
        XCTAssertEqual(GroceryCategory.categorize("bun"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("hamburger buns"), .bakery)
    }

    func testCategorize_Bakery_Tortilla() {
        XCTAssertEqual(GroceryCategory.categorize("tortilla"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("flour tortillas"), .bakery)
    }

    // MARK: - Pantry Category Tests

    func testCategorize_Pantry_Flour() {
        XCTAssertEqual(GroceryCategory.categorize("flour"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("all-purpose flour"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("Flour"), .pantry)
    }

    func testCategorize_Pantry_Sugar() {
        XCTAssertEqual(GroceryCategory.categorize("sugar"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("granulated sugar"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("brown sugar"), .pantry)
    }

    func testCategorize_Pantry_Rice() {
        XCTAssertEqual(GroceryCategory.categorize("rice"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("white rice"), .pantry)
    }

    func testCategorize_Pantry_Pasta() {
        XCTAssertEqual(GroceryCategory.categorize("pasta"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("spaghetti pasta"), .pantry)
    }

    func testCategorize_Pantry_BakingSoda() {
        XCTAssertEqual(GroceryCategory.categorize("baking soda"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("Baking Soda"), .pantry)
    }

    func testCategorize_Pantry_BakingPowder() {
        XCTAssertEqual(GroceryCategory.categorize("baking powder"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("Baking Powder"), .pantry)
    }

    func testCategorize_Pantry_ChocolateChip() {
        XCTAssertEqual(GroceryCategory.categorize("chocolate chip"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("chocolate chips"), .pantry)
    }

    func testCategorize_Pantry_Cocoa() {
        XCTAssertEqual(GroceryCategory.categorize("cocoa"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("cocoa powder"), .pantry)
    }

    func testCategorize_Pantry_Oil() {
        XCTAssertEqual(GroceryCategory.categorize("oil"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("olive oil"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("vegetable oil"), .pantry)
    }

    func testCategorize_Pantry_Vinegar() {
        XCTAssertEqual(GroceryCategory.categorize("vinegar"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("apple cider vinegar"), .pantry)
    }

    func testCategorize_Pantry_Honey() {
        XCTAssertEqual(GroceryCategory.categorize("honey"), .pantry)
    }

    func testCategorize_Pantry_MapleSyrup() {
        XCTAssertEqual(GroceryCategory.categorize("maple syrup"), .pantry)
    }

    // MARK: - Spices & Seasonings Category Tests

    func testCategorize_Spices_Salt() {
        XCTAssertEqual(GroceryCategory.categorize("salt"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("sea salt"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("Salt"), .spices)
    }

    func testCategorize_Spices_Pepper() {
        XCTAssertEqual(GroceryCategory.categorize("pepper"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("black pepper"), .spices)
    }

    func testCategorize_Spices_Cumin() {
        XCTAssertEqual(GroceryCategory.categorize("cumin"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("ground cumin"), .spices)
    }

    func testCategorize_Spices_Paprika() {
        XCTAssertEqual(GroceryCategory.categorize("paprika"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("smoked paprika"), .spices)
    }

    func testCategorize_Spices_Vanilla() {
        XCTAssertEqual(GroceryCategory.categorize("vanilla"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("vanilla extract"), .spices)
    }

    func testCategorize_Spices_Cinnamon() {
        XCTAssertEqual(GroceryCategory.categorize("cinnamon"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("ground cinnamon"), .spices)
    }

    func testCategorize_Spices_Oregano() {
        XCTAssertEqual(GroceryCategory.categorize("oregano"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("dried oregano"), .spices)
    }

    func testCategorize_Spices_Basil() {
        XCTAssertEqual(GroceryCategory.categorize("basil"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("dried basil"), .spices)
    }

    func testCategorize_Spices_Thyme() {
        XCTAssertEqual(GroceryCategory.categorize("thyme"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("fresh thyme"), .spices)
    }

    func testCategorize_Spices_Extract() {
        XCTAssertEqual(GroceryCategory.categorize("extract"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("almond extract"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("peppermint extract"), .spices)
    }

    // MARK: - Condiments & Sauces Category Tests

    func testCategorize_Condiments_Sauce() {
        XCTAssertEqual(GroceryCategory.categorize("sauce"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("tomato sauce"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("soy sauce"), .condiments)
    }

    func testCategorize_Condiments_Ketchup() {
        XCTAssertEqual(GroceryCategory.categorize("ketchup"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("Ketchup"), .condiments)
    }

    func testCategorize_Condiments_Mustard() {
        XCTAssertEqual(GroceryCategory.categorize("mustard"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("dijon mustard"), .condiments)
    }

    func testCategorize_Condiments_Mayonnaise() {
        XCTAssertEqual(GroceryCategory.categorize("mayonnaise"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("Mayonnaise"), .condiments)
    }

    func testCategorize_Condiments_Mayo() {
        XCTAssertEqual(GroceryCategory.categorize("mayo"), .condiments)
    }

    func testCategorize_Condiments_Dressing() {
        XCTAssertEqual(GroceryCategory.categorize("dressing"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("ranch dressing"), .condiments)
    }

    // MARK: - Other Category (Fallback) Tests

    func testCategorize_Other_Fallback() {
        XCTAssertEqual(GroceryCategory.categorize("unknown ingredient"), .other)
        XCTAssertEqual(GroceryCategory.categorize("random text"), .other)
        XCTAssertEqual(GroceryCategory.categorize(""), .other, "Should handle empty string")
    }

    func testCategorize_Other_Eggplant() {
        // Eggplant doesn't match produce keywords, so should fall through
        XCTAssertEqual(GroceryCategory.categorize("eggplant"), .other)
    }

    func testCategorize_Other_UncommonIngredient() {
        XCTAssertEqual(GroceryCategory.categorize("sumac"), .other)
        XCTAssertEqual(GroceryCategory.categorize("tahini"), .other)
    }

    // MARK: - Case Insensitivity Tests

    func testCategorize_CaseInsensitivity() {
        XCTAssertEqual(GroceryCategory.categorize("MILK"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("ChIcKeN"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("APPLE"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("BrEaD"), .bakery)
        XCTAssertEqual(GroceryCategory.categorize("FLOUR"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("SALT"), .spices)
        XCTAssertEqual(GroceryCategory.categorize("KETCHUP"), .condiments)
        XCTAssertEqual(GroceryCategory.categorize("JUICE"), .beverages)
        XCTAssertEqual(GroceryCategory.categorize("FROZEN"), .frozen)
    }

    // MARK: - Complex Multi-Word Tests

    func testCategorize_ComplexNames() {
        XCTAssertEqual(GroceryCategory.categorize("unsweetened almond milk"), .dairy)
        XCTAssertEqual(GroceryCategory.categorize("bone-in chicken breast"), .meat)
        XCTAssertEqual(GroceryCategory.categorize("fresh garlic cloves"), .produce)
        XCTAssertEqual(GroceryCategory.categorize("whole wheat flour"), .pantry)
        XCTAssertEqual(GroceryCategory.categorize("Italian seasoning blend"), .spices)
    }

    // MARK: - Detection Priority Tests

    func testCategorize_DetectionPriority_FrozenBeforeDairy() {
        // Ice cream contains "cream" but should prioritize frozen
        XCTAssertEqual(GroceryCategory.categorize("ice cream"), .frozen)
        XCTAssertNotEqual(GroceryCategory.categorize("ice cream"), .dairy)
    }

    func testCategorize_DetectionPriority_BeveragesBeforeProduce() {
        // Orange juice contains "orange" but should prioritize beverages
        XCTAssertEqual(GroceryCategory.categorize("orange juice"), .beverages)
        XCTAssertNotEqual(GroceryCategory.categorize("orange juice"), .produce)
    }

    func testCategorize_DetectionPriority_DairyBeforeProduce() {
        // Eggs checked before produce to avoid eggplant confusion
        XCTAssertEqual(GroceryCategory.categorize("eggs"), .dairy)
        XCTAssertNotEqual(GroceryCategory.categorize("eggs"), .produce)
    }

    func testCategorize_DetectionPriority_BakingSoda() {
        // Baking soda should be pantry, not beverages (even though it contains "soda")
        XCTAssertEqual(GroceryCategory.categorize("baking soda"), .pantry)
        XCTAssertNotEqual(GroceryCategory.categorize("baking soda"), .beverages)
    }

    // MARK: - Enum Properties Tests

    func testGroceryCategory_IconNames() {
        XCTAssertEqual(GroceryCategory.produce.iconName, "leaf.fill")
        XCTAssertEqual(GroceryCategory.dairy.iconName, "cup.and.saucer.fill")
        XCTAssertEqual(GroceryCategory.meat.iconName, "fish.fill")
        XCTAssertEqual(GroceryCategory.bakery.iconName, "birthday.cake.fill")
        XCTAssertEqual(GroceryCategory.pantry.iconName, "cabinet.fill")
        XCTAssertEqual(GroceryCategory.frozen.iconName, "snowflake")
        XCTAssertEqual(GroceryCategory.spices.iconName, "leaf.circle.fill")
        XCTAssertEqual(GroceryCategory.condiments.iconName, "drop.fill")
        XCTAssertEqual(GroceryCategory.beverages.iconName, "mug.fill")
        XCTAssertEqual(GroceryCategory.other.iconName, "basket.fill")
    }

    func testGroceryCategory_SortOrder() {
        // Verify supermarket-optimized sort order
        XCTAssertEqual(GroceryCategory.produce.sortOrder, 0, "Produce should be first (perimeter)")
        XCTAssertEqual(GroceryCategory.bakery.sortOrder, 1, "Bakery should be second (perimeter)")
        XCTAssertEqual(GroceryCategory.meat.sortOrder, 2, "Meat should be third (perimeter)")
        XCTAssertEqual(GroceryCategory.dairy.sortOrder, 7, "Dairy near end (keep cold)")
        XCTAssertEqual(GroceryCategory.frozen.sortOrder, 8, "Frozen last (stay frozen)")
        XCTAssertEqual(GroceryCategory.other.sortOrder, 9, "Other is catch-all")
    }

    func testGroceryCategory_SortOrder_Ordering() {
        // Verify sort order is sequential and correct
        XCTAssertLessThan(GroceryCategory.produce.sortOrder, GroceryCategory.dairy.sortOrder)
        XCTAssertLessThan(GroceryCategory.dairy.sortOrder, GroceryCategory.frozen.sortOrder)
        XCTAssertLessThan(GroceryCategory.pantry.sortOrder, GroceryCategory.dairy.sortOrder)
    }

    func testGroceryCategory_AisleHints() {
        XCTAssertEqual(GroceryCategory.produce.aisleHint, "Perimeter / Front")
        XCTAssertEqual(GroceryCategory.bakery.aisleHint, "Perimeter")
        XCTAssertEqual(GroceryCategory.meat.aisleHint, "Perimeter / Back")
        XCTAssertEqual(GroceryCategory.pantry.aisleHint, "Center Aisles")
        XCTAssertEqual(GroceryCategory.dairy.aisleHint, "Back Wall")
        XCTAssertEqual(GroceryCategory.frozen.aisleHint, "Back Wall")
        XCTAssertEqual(GroceryCategory.other.aisleHint, "Varies")
    }

    func testGroceryCategory_RawValues() {
        XCTAssertEqual(GroceryCategory.produce.rawValue, "Produce")
        XCTAssertEqual(GroceryCategory.dairy.rawValue, "Dairy & Eggs")
        XCTAssertEqual(GroceryCategory.meat.rawValue, "Meat & Seafood")
        XCTAssertEqual(GroceryCategory.bakery.rawValue, "Bakery")
        XCTAssertEqual(GroceryCategory.pantry.rawValue, "Pantry")
        XCTAssertEqual(GroceryCategory.frozen.rawValue, "Frozen")
        XCTAssertEqual(GroceryCategory.spices.rawValue, "Spices & Seasonings")
        XCTAssertEqual(GroceryCategory.condiments.rawValue, "Condiments & Sauces")
        XCTAssertEqual(GroceryCategory.beverages.rawValue, "Beverages")
        XCTAssertEqual(GroceryCategory.other.rawValue, "Other")
    }

    func testGroceryCategory_CaseIterable() {
        // Verify all 10 categories are present
        XCTAssertEqual(GroceryCategory.allCases.count, 10)

        let allCases = GroceryCategory.allCases
        XCTAssertTrue(allCases.contains(.produce))
        XCTAssertTrue(allCases.contains(.dairy))
        XCTAssertTrue(allCases.contains(.meat))
        XCTAssertTrue(allCases.contains(.bakery))
        XCTAssertTrue(allCases.contains(.pantry))
        XCTAssertTrue(allCases.contains(.frozen))
        XCTAssertTrue(allCases.contains(.spices))
        XCTAssertTrue(allCases.contains(.condiments))
        XCTAssertTrue(allCases.contains(.beverages))
        XCTAssertTrue(allCases.contains(.other))
    }

    func testGroceryCategory_Identifiable() {
        // Verify id matches rawValue
        XCTAssertEqual(GroceryCategory.produce.id, GroceryCategory.produce.rawValue)
        XCTAssertEqual(GroceryCategory.dairy.id, "Dairy & Eggs")
        XCTAssertEqual(GroceryCategory.frozen.id, "Frozen")
    }
}
