import Foundation

/// Central repository for all help articles and FAQ content
/// Content will be expanded in tasks 4.2-4.6
final class HelpContent {
    // MARK: - All Articles

    /// All help articles organized by section
    /// NOTE: Content is placeholder - will be expanded in tasks 4.2-4.6
    var allArticles: [HelpArticle] {
        gettingStartedArticles +
        recipeArticles +
        shoppingListArticles +
        cardPersonalizationArticles +
        advancedFeaturesArticles +
        troubleshootingArticles
    }

    // MARK: - Getting Started (Task 4.2)

    var gettingStartedArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "getting-started-overview",
                title: "Welcome to Heirloom",
                content: """
                Heirloom helps you collect, organize, and share family recipes in a beautiful, personal way.

                **Key Features:**
                • Import recipes from websites or scan cookbooks
                • Style recipe cards with backgrounds, stickers, and notes
                • Create shopping lists from recipes
                • Share recipes with family members
                • Track recipe lineage across generations

                **Getting Started:**
                1. Tap the + button to add your first recipe
                2. Choose how you want to add it (URL, scan, or manual)
                3. Personalize the recipe card
                4. Start cooking!
                """,
                section: .gettingStarted,
                keywords: ["welcome", "introduction", "overview", "start", "begin"],
                icon: "hand.wave.fill"
            ),
            HelpArticle(
                id: "gestures-guide",
                title: "Gestures & Interactions",
                content: """
                Heirloom uses intuitive gestures to make managing your recipes effortless.

                **Recipe List:**
                • **Pull down** to refresh and sync with CloudKit
                • **Long press** recipe cards for quick actions (favorite, shopping list, delete)
                • **Tap** any recipe to view its details

                **Recipe Details:**
                • **Tap the card** to flip between front (photo) and back (notes/lineage)
                • **Swipe left** on ingredients to delete them
                • **Long press & drag** to reorder ingredients and instructions

                **Shopping List:**
                • **Tap** ingredients to check them off
                • **Long press** recipes to remove or hide items
                • **Long press** ingredients to view recipes, check off, or copy

                **Card Personalization:**
                • **Drag** stickers to position them
                • **Pinch** stickers to resize them
                • **Rotate** stickers with two fingers
                • **Long press** to delete stickers or annotations

                **General:**
                • **Pull down** on sheets to dismiss them
                • **Swipe from left edge** to go back
                • **Tap** text fields to edit

                **Tips:**
                • Haptic feedback confirms most actions
                • Sound effects (if enabled) enhance the card flip experience
                • VoiceOver fully supports all gestures with alternative actions
                """,
                section: .gettingStarted,
                keywords: ["gestures", "tap", "swipe", "long press", "drag", "pinch", "rotate", "interactions", "touch"],
                relatedArticles: ["card-flip-guide", "shopping-list-basics"],
                icon: "hand.tap.fill"
            ),
            HelpArticle(
                id: "adding-first-recipe",
                title: "Adding Your First Recipe",
                content: """
                There are multiple ways to add recipes to Heirloom, depending on where your recipe comes from.

                **Four Ways to Add Recipes:**

                **1. Import from URL**
                Perfect for recipes from cooking websites. Heirloom automatically extracts the title, ingredients, instructions, and even images.

                **2. Scan Cookbook**
                Take photos of cookbook pages and Heirloom uses OCR (Optical Character Recognition) to extract the recipe text.

                **3. Manual Entry**
                Type in recipes from scratch - ideal for family recipes, handwritten cards, or when you want complete control.

                **4. Import from JSON**
                Import previously exported recipes or recipes from other sources in JSON format.

                **Quick Start:**
                1. Tap the **+** button in the tab bar at the bottom
                2. Choose your preferred import method
                3. Follow the on-screen prompts
                4. Review and edit as needed
                5. Save your recipe

                **After Adding:**
                • Add a photo from your library or camera
                • Personalize the card with backgrounds and stickers
                • Add personal notes on the card back
                • Mark it as a favorite

                **Tips:**
                • Start with a recipe from a website to see how automatic import works
                • Don't worry about perfection - you can always edit later
                • Photos make recipes easier to find and more appealing
                """,
                section: .gettingStarted,
                keywords: ["add", "first", "new", "recipe", "import", "create", "start"],
                relatedArticles: ["importing-from-url", "scanning-cookbooks", "manual-entry"],
                icon: "plus.circle.fill"
            ),
            HelpArticle(
                id: "importing-from-url",
                title: "Importing from URL",
                content: """
                Import recipes from cooking websites automatically with just a URL.

                **Step-by-Step:**

                1. **Find the Recipe Online**
                   • Browse to your favorite recipe website
                   • Find the recipe you want to save

                2. **Copy the URL**
                   • Tap the address bar in Safari
                   • Tap "Copy" to copy the URL
                   • Or use the Share button → Copy

                3. **Open Heirloom**
                   • Tap the **+** button in the tab bar
                   • Select **"Import from URL"**

                4. **Paste the URL**
                   • The URL should paste automatically
                   • If not, long press and select "Paste"
                   • Tap **"Import"**

                5. **Review the Import**
                   • Heirloom extracts the recipe data
                   • Check that ingredients and instructions look correct
                   • The recipe photo is usually imported too

                6. **Make Adjustments**
                   • Edit any text that wasn't imported correctly
                   • Add missing information
                   • Adjust ingredient quantities or units if needed

                7. **Save**
                   • Tap **"Save"** to add the recipe to your collection

                **Supported Websites:**
                Heirloom works with most major recipe websites including:
                • AllRecipes, Food Network, NYT Cooking
                • Serious Eats, Bon Appétit, Epicurious
                • Personal food blogs with recipe markup
                • Any site using standard recipe schema

                **Troubleshooting:**
                • **Import fails:** Some sites block automated access - try copying the text manually
                • **Missing ingredients:** Edit the recipe after import to add them
                • **Wrong photo:** You can change the photo after import
                • **Duplicate recipe:** Check if the URL is correct, or delete and reimport

                **Tips:**
                • Works best with full recipe URLs, not homepage links
                • Safari's Reader mode can help find the recipe URL on cluttered pages
                • You can import multiple recipes in a row - no need to wait
                """,
                section: .gettingStarted,
                keywords: ["url", "import", "website", "online", "link", "web", "automatic"],
                relatedArticles: ["adding-first-recipe", "import-failures"],
                icon: "link.circle.fill"
            ),
            HelpArticle(
                id: "scanning-cookbooks",
                title: "Scanning Cookbooks",
                content: """
                Use your camera to scan recipes from cookbooks, magazines, or printed recipe cards.

                **Step-by-Step:**

                1. **Start Scanning**
                   • Tap the **+** button in the tab bar
                   • Select **"Scan Cookbook"**
                   • Grant camera permission if prompted

                2. **Position the Recipe**
                   • Place cookbook on a flat, well-lit surface
                   • Ensure the page is flat (use a book weight if needed)
                   • Avoid shadows falling on the recipe

                3. **Take Photos**
                   • Frame the recipe in the viewfinder
                   • Tap the capture button
                   • Take multiple photos if the recipe spans pages
                   • Tap **"Continue"** when done

                4. **Wait for OCR Processing**
                   • Heirloom uses OCR to extract text
                   • This takes 5-15 seconds per page
                   • A progress indicator shows the extraction status

                5. **Review Extracted Text**
                   • Check that ingredients were captured correctly
                   • Review instructions for accuracy
                   • Look for any OCR errors (common with handwriting)

                6. **Edit as Needed**
                   • Fix any text recognition errors
                   • Correct quantities or measurements
                   • Add missing information
                   • Enter the recipe title if not detected

                7. **Add a Photo** (Optional)
                   • The scanned page isn't used as the recipe photo
                   • Take a photo of the finished dish instead
                   • Or add one from your library

                8. **Save**
                   • Tap **"Save"** to add the recipe

                **Best Practices:**

                **Lighting:**
                • Use bright, even lighting
                • Natural daylight works best
                • Avoid direct flash (causes glare)

                **Camera Positioning:**
                • Hold camera parallel to page
                • Keep page fully in frame
                • Avoid tilting or angling

                **Page Condition:**
                • Flatten pages completely
                • Clean off any stains or marks
                • Use glass to hold pages flat

                **What Works Well:**
                • Printed cookbook text
                • Magazine recipes
                • Typed recipe cards
                • Clear, sans-serif fonts

                **What's Challenging:**
                • Handwritten recipes (especially cursive)
                • Very small text
                • Decorative or script fonts
                • Faded or stained pages

                **Troubleshooting:**
                • **Poor text recognition:** Retake photos with better lighting
                • **Missing ingredients:** Add them manually after scanning
                • **Jumbled text:** OCR may mix columns - edit to fix order
                • **Multiple recipes on page:** Crop or scan separately

                **Tips:**
                • Scan multiple pages and they'll be combined into one recipe
                • You can edit everything after scanning
                • For handwritten family recipes, manual entry may be faster
                • Save original cookbook photos to your device as a backup
                """,
                section: .gettingStarted,
                keywords: ["scan", "camera", "ocr", "cookbook", "photo", "picture", "book"],
                relatedArticles: ["adding-first-recipe", "manual-entry", "import-failures"],
                icon: "doc.text.viewfinder"
            ),
            HelpArticle(
                id: "manual-entry",
                title: "Manual Recipe Entry",
                content: """
                Enter recipes from scratch when you have handwritten cards, family recipes, or want complete control over formatting.

                **Step-by-Step:**

                1. **Start New Recipe**
                   • Tap the **+** button in the tab bar
                   • Select **"New Recipe"**

                2. **Enter Basic Information**
                   • **Title:** Give your recipe a name
                   • **Source Type:** Choose Manual, Family, or Other
                   • **Servings:** Enter portion size (e.g., "6 servings" or "12 cookies")
                   • **Times:** Add prep time and cook time

                3. **Add Ingredients**
                   • Tap **"Add Ingredient"**
                   • Type the full ingredient line (e.g., "2 cups flour")
                   • Heirloom parses quantity, unit, and item automatically
                   • Repeat for each ingredient
                   • Drag to reorder ingredients

                4. **Add Instructions**
                   • Tap **"Add Step"**
                   • Type the instruction text
                   • Each step should be one clear action
                   • Drag to reorder steps
                   • Keep steps concise but complete

                5. **Add Optional Details**
                   • **Description:** Brief overview of the dish
                   • **Notes:** Personal tips or variations
                   • **Tags:** For searching and organizing
                   • **URL:** If the recipe has an online source

                6. **Add a Photo** (Optional but Recommended)
                   • Tap **"Add Photo"**
                   • Choose from library or take a new photo
                   • Photos help you identify recipes quickly

                7. **Save**
                   • Tap **"Save"** to add the recipe to your collection

                **Ingredient Entry Tips:**

                **Format:** "quantity unit item, preparation"
                • "2 cups flour"
                • "1 tablespoon butter, melted"
                • "3 eggs, beaten"
                • "Salt and pepper to taste"

                **Heirloom Parses:**
                • Quantities (whole numbers, fractions, ranges)
                • Units (cups, tablespoons, ounces, grams, etc.)
                • Ingredient names
                • Preparation notes (chopped, diced, minced)

                **Categories:**
                • Ingredients are auto-categorized by grocery aisle
                • Used for shopping list organization
                • You can adjust categories if needed

                **Instruction Writing Tips:**

                **Be Clear and Specific:**
                ✅ "Preheat oven to 350°F"
                ❌ "Heat oven"

                **One Action Per Step:**
                ✅ "Mix flour and salt in a bowl"
                ✅ "In a separate bowl, beat eggs"
                ❌ "Mix dry ingredients while beating eggs"

                **Include Times and Temperatures:**
                ✅ "Bake for 25-30 minutes until golden brown"
                ❌ "Bake until done"

                **Use Active Voice:**
                ✅ "Stir constantly until thickened"
                ❌ "The mixture should be stirred"

                **Best Practices:**

                **Start Simple:**
                • Don't worry about perfection
                • You can always edit later
                • Focus on capturing the recipe first

                **Use Consistent Units:**
                • Stick to metric or imperial
                • Heirloom can convert between units

                **Add Photos Later:**
                • Cook the recipe first
                • Take photos of the finished dish
                • Add them to the recipe afterward

                **Include Personal Notes:**
                • Family history or memories
                • Serving suggestions
                • Variations or substitutions

                **Organize with Tags:**
                • Cuisine type (Italian, Mexican, etc.)
                • Meal type (breakfast, dessert, etc.)
                • Dietary info (vegetarian, gluten-free, etc.)

                **Common Questions:**

                **Can I add recipes without photos?**
                Yes! Photos are optional but recommended.

                **How do I add ingredient notes?**
                Add them after a comma: "2 cups flour, sifted"

                **Can I use ranges?**
                Yes: "2-3 cloves garlic" or "1/4-1/2 teaspoon salt"

                **What if parsing gets it wrong?**
                You can edit ingredients after they're parsed to correct any errors.

                **Tips:**
                • Keep your phone nearby when cooking to capture recipe details
                • Voice dictation can speed up entry
                • Break complex recipes into clear, numbered steps
                • Add recipe variations as separate versions
                """,
                section: .gettingStarted,
                keywords: ["manual", "entry", "type", "create", "write", "from scratch", "new"],
                relatedArticles: ["adding-first-recipe", "ingredient-parsing"],
                icon: "square.and.pencil"
            ),
            HelpArticle(
                id: "recipe-versions",
                title: "Recipe Versions & History",
                content: """
                Track how recipes evolve across generations with Heirloom's version system.

                **What Are Recipe Versions?**

                Recipe versions let you track changes to a recipe over time, perfect for:
                • Family recipes passed down through generations
                • Recipes you're perfecting and iterating on
                • Seasonal variations of the same dish
                • Adapted recipes with dietary modifications

                **Creating Versions:**

                **From an Existing Recipe:**
                1. Open the recipe you want to create a version of
                2. Tap the **•••** menu button
                3. Select **"Create Version"**
                4. Make your changes to the new version
                5. Add a version name (e.g., "Mom's Version", "Gluten-Free")
                6. Save

                **Version Metadata:**
                Each version tracks:
                • Who created it (added by name)
                • When it was created
                • What changed from the original
                • Lineage (parent recipe)

                **Viewing Version History:**

                **On the Recipe Card:**
                • Flip the card to see the back
                • The lineage section shows the recipe's history
                • See who contributed each version

                **In Recipe Details:**
                • Tap **"View Versions"** to see all versions
                • Compare versions side-by-side
                • Switch between versions
                • See what changed

                **Active Version:**

                **What It Means:**
                • The "active" version is the one you cook from
                • Only one version is active at a time
                • All other versions are archived

                **Switching Versions:**
                1. View the recipe
                2. Tap **"View Versions"**
                3. Select a version
                4. Tap **"Make Active"**
                5. The new version becomes your cooking version

                **Example Use Cases:**

                **Generational Recipe:**
                • Original: "Grandma's Chocolate Cake (1950s)"
                • Version 2: "Mom's Chocolate Cake (1980s)" - reduced sugar
                • Version 3: "My Chocolate Cake (2024)" - added espresso

                **Dietary Adaptation:**
                • Original: "Classic Brownies"
                • Version 2: "Gluten-Free Brownies" - almond flour
                • Version 3: "Vegan Brownies" - flax eggs

                **Seasonal Variation:**
                • Original: "Summer Berry Pie"
                • Version 2: "Fall Apple Pie" - swapped fruit
                • Version 3: "Winter Cranberry Pie" - added spices

                **Perfecting a Recipe:**
                • Version 1: "First Try Bread" - too dense
                • Version 2: "Second Try" - added more yeast
                • Version 3: "Final Version" - perfect rise

                **Version Lineage:**

                **Parent-Child Relationship:**
                • Each version knows its parent recipe
                • You can trace back to the original
                • View the full family tree

                **On the Card Back:**
                • "Based on [Parent Recipe]"
                • "Adapted by [Your Name]"
                • "Created on [Date]"

                **Version Notes:**
                • Document what you changed
                • Explain why you made modifications
                • Leave notes for future generations

                **Best Practices:**

                **When to Create Versions:**
                ✅ Making significant ingredient changes
                ✅ Adapting for dietary needs
                ✅ Passing down a family recipe
                ✅ Trying experimental modifications

                **When NOT to Create Versions:**
                ❌ Small typo fixes (just edit)
                ❌ Temporary scaling (use scale feature)
                ❌ Minor quantity adjustments
                ❌ Adding a forgotten ingredient

                **Naming Versions:**
                • Be descriptive: "Gluten-Free Version"
                • Include contributor: "Aunt Mary's Version"
                • Add date context: "2024 Updated Recipe"
                • Note changes: "Reduced Sugar Version"

                **Version Control Tips:**
                • Keep the original version unchanged
                • Document all changes in version notes
                • Add your name so family knows who adapted it
                • Include the year for historical context

                **Sharing Versions:**
                • When you share a recipe, you can choose which version
                • Recipients get the version history
                • Family members can contribute their own versions
                • All versions sync via iCloud

                **Common Questions:**

                **Do all versions count as separate recipes?**
                No - versions are linked and count as one recipe with variations.

                **Can I delete a version?**
                Yes, but you can't delete the original recipe without deleting all versions.

                **Can I see what changed between versions?**
                Yes - use the "Compare Versions" feature to see differences.

                **Do versions affect my recipe count?**
                No - linked versions count as one recipe for milestones and stats.

                **Tips:**
                • Start a version when you first modify a family recipe
                • Use versions for dietary adaptations rather than duplicating
                • Add photos to each version showing the final result
                • Include stories or memories in version notes
                • Share all versions when passing down recipes to family
                """,
                section: .gettingStarted,
                keywords: ["version", "history", "lineage", "adaptation", "variation", "generation", "family"],
                relatedArticles: ["card-flip-guide", "sharing-recipes"],
                icon: "clock.arrow.circlepath"
            )
        ]
    }

    // MARK: - Recipes (Task 4.2)

    var recipeArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "importing-recipes",
                title: "Importing Recipes",
                content: """
                There are several ways to add recipes to Heirloom:

                **From a Website:**
                1. Tap the + button in the tab bar
                2. Select "Import from URL"
                3. Paste the recipe URL
                4. Review and confirm the import

                **Scan a Cookbook:**
                1. Tap the + button
                2. Select "Scan Cookbook"
                3. Take photos of the recipe pages
                4. Review the extracted text

                **Manual Entry:**
                1. Tap the + button
                2. Select "New Recipe"
                3. Enter recipe details manually

                **Tips:**
                • Most major recipe websites are supported
                • OCR works best with clear, well-lit photos
                • You can edit any imported recipe after adding it
                """,
                section: .recipes,
                keywords: ["import", "add", "url", "website", "scan", "ocr"],
                icon: "square.and.arrow.down"
            ),
            // Additional articles will be added in Task 4.2
        ]
    }

    // MARK: - Shopping Lists (Task 4.3)

    var shoppingListArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "shopping-list-basics",
                title: "Shopping List Basics",
                content: """
                Turn your recipes into organized shopping lists with smart ingredient aggregation.

                **Creating Your First Shopping List:**

                1. **Open the Shopping Tab**
                   • Tap the **Shopping** icon in the tab bar
                   • You'll see your current shopping list

                2. **Add Recipes**
                   • Tap **"Add Recipes"** at the top
                   • Browse or search for recipes
                   • Tap recipes to select them (checkmark appears)
                   • Select as many as you want

                3. **Adjust Servings** (Optional)
                   • For each recipe, you can adjust servings
                   • Tap the serving count to modify
                   • Ingredient quantities scale automatically

                4. **Review Your List**
                   • Tap **"Add to List"** when done
                   • Ingredients appear organized by category
                   • Duplicates are automatically combined

                **Using Your Shopping List:**

                **Check Off Items:**
                • Tap any ingredient to check it off
                • Checked items move to the bottom
                • Items stay checked until you clear them

                **View by Recipe:**
                • Toggle between "By Category" and "By Recipe"
                • Category view groups by grocery aisle
                • Recipe view shows ingredients per recipe

                **Manage Items:**
                • Long press items for options:
                  - View which recipes need this ingredient
                  - Copy ingredient text
                  - Remove from specific recipes
                  - Hide ingredient

                **Quick Actions:**
                • **Hide Recipe:** Long press recipe headers to hide/show all items
                • **Clear Checked:** Remove all checked-off items at once
                • **Remove Recipe:** Remove all ingredients from a recipe

                **Smart Features:**

                **Automatic Aggregation:**
                When you add multiple recipes:
                • Identical ingredients combine automatically
                • Quantities add together intelligently
                • Different units convert when possible
                • Source recipes are tracked

                **Category Grouping:**
                Ingredients organize by grocery aisle:
                • Produce, Dairy, Meat, Pantry, etc.
                • Shop efficiently by section
                • Customize categories as needed

                **Persistence:**
                • Lists save automatically
                • Sync across devices via iCloud
                • Checked status syncs too
                • Work offline, sync later

                **Common Tasks:**

                **Adding More Recipes:**
                • Tap "Add Recipes" anytime
                • New ingredients merge with existing list
                • Quantities update automatically

                **Starting Fresh:**
                • Clear all checked items first
                • Remove recipes you don't need
                • Or export to Reminders and start over

                **Sharing Lists:**
                • Export to Apple Reminders
                • Share with family members
                • They can check off items in real-time

                **Tips:**
                • Add recipes before going to the store
                • Check off items as you shop
                • Use "By Category" view at the store for efficiency
                • Long press items to see which recipes need them
                • Export to Reminders for Apple Watch access
                """,
                section: .shoppingLists,
                keywords: ["shopping", "list", "basics", "create", "add", "recipes", "groceries"],
                relatedArticles: ["category-organization", "ingredient-aggregation", "exporting-to-reminders"],
                icon: "cart.fill"
            ),
            HelpArticle(
                id: "category-organization",
                title: "Category Organization",
                content: """
                Heirloom automatically organizes your shopping list by grocery aisle for efficient shopping.

                **How Categories Work:**

                **Automatic Categorization:**
                When you add recipes to your shopping list:
                • Each ingredient is assigned a category
                • Categories match typical grocery store layout
                • Items group together by aisle
                • Shop more efficiently by section

                **Default Categories:**

                Heirloom includes these standard categories:

                **Produce:**
                • Fruits, vegetables, herbs
                • Fresh items typically at store entrance

                **Dairy & Eggs:**
                • Milk, cheese, yogurt, eggs, butter
                • Usually in refrigerated section

                **Meat & Seafood:**
                • Fresh and frozen proteins
                • Butcher counter items

                **Bakery:**
                • Bread, tortillas, baked goods
                • Fresh bakery section

                **Pantry Staples:**
                • Flour, sugar, oils, spices
                • Center store aisles

                **Canned & Jarred:**
                • Canned goods, sauces, condiments
                • Shelf-stable items

                **Frozen:**
                • Frozen vegetables, prepared foods
                • Freezer aisles

                **Beverages:**
                • Drinks, coffee, tea
                • Beverage section

                **Other:**
                • Items that don't fit elsewhere
                • Non-food items mentioned in recipes

                **Category Intelligence:**

                **Smart Detection:**
                Heirloom uses multiple signals to categorize:
                • Ingredient name matching
                • Common usage patterns
                • Recipe context clues
                • Previous categorization history

                **Examples:**
                • "2 cups flour" → Pantry Staples
                • "1 pound chicken breast" → Meat & Seafood
                • "3 tomatoes" → Produce
                • "1 cup milk" → Dairy & Eggs

                **Viewing by Category:**

                **Category View** (Default)
                • Tap "By Category" at the top
                • Ingredients group by aisle
                • Each category is collapsible
                • Shows item count per category

                **Benefits:**
                • Shop store section by section
                • Don't backtrack through the store
                • Check off whole categories
                • See what's left to find

                **Category Display:**
                Each category shows:
                • Category icon and name
                • Number of unchecked items
                • All ingredients in that category
                • Check boxes for each item

                **Collapsing Categories:**
                • Tap category headers to collapse/expand
                • Hide checked-off categories
                • Focus on what you still need
                • Expand to see all items

                **Customization:**

                **Recategorizing Items:**
                Currently, categories are automatic, but you can:
                • Note items in the wrong category
                • Shop knowing the actual location
                • Categories improve over time

                **Store Layout Differences:**
                Grocery stores vary, so:
                • Learn your store's layout
                • Adapt your shopping route
                • Use categories as a guide, not gospel
                • Check related categories if can't find item

                **Tips for Efficient Shopping:**

                **Before You Shop:**
                • Review list by category
                • Know which categories you need
                • Plan your route through the store

                **While Shopping:**
                • Use category view for efficiency
                • Collapse completed categories
                • Long press items to see recipe source
                • Check off items as you go

                **Store Strategies:**
                • Shop perimeter first (produce, meat, dairy)
                • Hit center aisles for pantry items
                • Frozen section last to keep items cold

                **Multi-Store Shopping:**
                If shopping at multiple stores:
                • Check off items at first store
                • Remaining items show clearly
                • Export remainder to Reminders
                • Or keep in Heirloom for next store

                **Common Questions:**

                **Can I change categories?**
                Not currently, but Heirloom's AI learns over time.

                **Why is an item in the wrong category?**
                Some items are ambiguous (e.g., "fresh pasta" could be Produce or Pantry).

                **Can I add custom categories?**
                Not yet, but we're considering this for future updates.

                **Do categories sync across devices?**
                Yes, via iCloud. Your shopping list stays consistent everywhere.

                **Tips:**
                • Trust the categories - they're optimized for most stores
                • Note your store's quirks (e.g., eggs near produce)
                • Collapse categories you've completed
                • Use category view for first-time store visits
                """,
                section: .shoppingLists,
                keywords: ["category", "categories", "organization", "aisle", "groups", "groceries"],
                relatedArticles: ["shopping-list-basics", "ingredient-aggregation"],
                icon: "square.grid.2x2.fill"
            ),
            HelpArticle(
                id: "exporting-to-reminders",
                title: "Exporting to Apple Reminders",
                content: """
                Export your shopping list to Apple Reminders for offline access, Apple Watch support, and sharing with family.

                **Why Export to Reminders?**

                **Benefits:**
                • Access on Apple Watch
                • Works offline (no internet needed)
                • Share with family via iCloud
                • Check off items hands-free with Siri
                • Available on Mac, iPad, iPhone, Apple Watch
                • Notifications and location reminders

                **Use Cases:**
                • Going to a store with poor cell service
                • Want to use Apple Watch while shopping
                • Sharing list with spouse/family
                • Prefer Reminders app interface
                • Need location-based reminders

                **How to Export:**

                **Step-by-Step:**

                1. **Open Your Shopping List**
                   • Go to the Shopping tab in Heirloom
                   • Make sure your list is complete

                2. **Tap Export**
                   • Tap the **share icon** (square with up arrow)
                   • Or tap **•••** menu and select "Export"

                3. **Choose Reminders**
                   • Select **"Export to Reminders"**
                   • Grant Reminders access if prompted

                4. **Choose a List** (Optional)
                   • Select existing Reminders list
                   • Or create a new list
                   • Default: "Heirloom Shopping"

                5. **Confirm Export**
                   • Tap **"Export"**
                   • Items copy to Apple Reminders
                   • Original list stays in Heirloom

                **What Gets Exported:**

                **Format:**
                Each ingredient becomes a reminder with:
                • Ingredient quantity and name
                • Recipe source (in notes)
                • Category grouping (via subtasks or tags)
                • All unchecked items

                **Example:**
                ```
                ☐ 2 cups flour (Chocolate Chip Cookies)
                ☐ 1 pound chicken breast (Chicken Piccata)
                ☐ 3 tomatoes (Caprese Salad)
                ```

                **Organization:**
                • Items group by category
                • Or list alphabetically
                • Checked items excluded
                • Recipe names included

                **Using Reminders:**

                **On iPhone:**
                • Open Reminders app
                • Find your Heirloom list
                • Check off items as you shop
                • Swipe to delete items

                **On Apple Watch:**
                • Open Reminders on watch
                • View your shopping list
                • Tap to check off items
                • Use Siri: "Check off flour"

                **With Siri:**
                • "Hey Siri, show my Heirloom shopping list"
                • "Hey Siri, check off tomatoes"
                • "Hey Siri, add milk to Heirloom Shopping"

                **Sharing with Family:**
                • Open list in Reminders
                • Tap info button (i)
                • Tap "Add Person"
                • Select family members
                • They can view and check off items

                **Location Reminders:**
                • Set reminder for grocery store location
                • Get notified when you arrive
                • Never forget your list

                **After Shopping:**

                **Back in Heirloom:**
                Checking off in Reminders doesn't sync back to Heirloom:
                • Manually clear items in Heirloom
                • Or remove recipes from list
                • Or start fresh for next shopping trip

                **Cleaning Up:**
                • Delete Reminders list when done
                • Or keep it for reference
                • Re-export next time for fresh list

                **Best Practices:**

                **Before Export:**
                • Finalize your shopping list in Heirloom
                • Add all recipes you're cooking
                • Review for accuracy
                • Remove recipes you don't need

                **Export Timing:**
                • Export right before shopping
                • Or night before for planning
                • Update list if plans change
                • Re-export if you add recipes

                **Multiple Exports:**
                • Each export creates new items
                • Don't export twice (creates duplicates)
                • Delete old list before re-exporting
                • Or create separate lists by date

                **Family Coordination:**
                • Export and share with family
                • One person manages the list
                • Others check off as they shop
                • Coordinate who's buying what

                **Common Questions:**

                **Does it sync back to Heirloom?**
                No. Changes in Reminders don't sync back. Export is one-way.

                **Can I export multiple times?**
                Yes, but create new lists to avoid duplicates.

                **What if I add recipes after exporting?**
                Re-export to a new Reminders list, or manually add items.

                **Do checked items export?**
                No, only unchecked items export to Reminders.

                **Can I edit items in Reminders?**
                Yes, Reminders items are fully editable.

                **Does it work with Google Tasks or other apps?**
                Currently only Apple Reminders is supported.

                **Tips:**
                • Export once per shopping trip
                • Use Apple Watch for hands-free shopping
                • Share with family for collaborative shopping
                • Set location reminder at your grocery store
                • Delete Reminders list when done shopping
                • Keep Heirloom as your source of truth
                """,
                section: .shoppingLists,
                keywords: ["export", "reminders", "apple reminders", "watch", "siri", "share", "offline"],
                relatedArticles: ["shopping-list-basics", "ingredient-aggregation"],
                icon: "square.and.arrow.up.fill"
            ),
            HelpArticle(
                id: "ingredient-aggregation",
                title: "Ingredient Aggregation",
                content: """
                When you add multiple recipes to your shopping list, Heirloom intelligently combines duplicate ingredients to minimize your shopping.

                **How Aggregation Works:**

                **The Problem:**
                Say you're making three recipes:
                • Recipe A needs 2 cups flour
                • Recipe B needs 1 cup flour
                • Recipe C needs 3 cups flour

                Without aggregation, you'd see flour listed three times. With aggregation, you see:
                • **6 cups flour** (from 3 recipes)

                **The Solution:**
                Heirloom automatically:
                • Detects identical ingredients
                • Combines their quantities
                • Shows the total amount needed
                • Tracks which recipes need it

                **What Gets Combined:**

                **Exact Matches:**
                Ingredients combine when:
                • Same ingredient name
                • Compatible units (both volume or both weight)
                • Same preparation (optional)

                **Examples That Combine:**
                ✅ "2 cups flour" + "1 cup flour" = "3 cups flour"
                ✅ "1 pound chicken" + "1 pound chicken" = "2 pounds chicken"
                ✅ "3 eggs" + "2 eggs" = "5 eggs"

                **Examples That Don't Combine:**
                ❌ "2 cups flour" + "1 cup flour, sifted" (different prep)
                ❌ "1 cup milk" + "1 ounce milk" (different units)
                ❌ "2 tomatoes" + "1 cup diced tomatoes" (different form)

                **Smart Features:**

                **Unit Conversion:**
                Heirloom converts compatible units:
                • "1 tablespoon butter" + "1 teaspoon butter" = "4 teaspoons butter" (or "1 Tbsp 1 tsp")
                • "1 cup milk" + "8 oz milk" = "2 cups milk"
                • Metric ↔ Imperial when possible

                **Quantity Math:**
                Handles complex quantities:
                • Fractions: "1/2 cup" + "1/4 cup" = "3/4 cup"
                • Ranges: "2-3 cloves" + "1 clove" = "3-4 cloves"
                • Decimals: "1.5 cups" + "0.5 cups" = "2 cups"

                **Preparation Notes:**
                Respects preparation differences:
                • "1 onion, diced" ≠ "1 onion, sliced"
                • "2 cups flour" ≠ "2 cups flour, sifted"
                • Keeps separate to avoid confusion

                **Viewing Aggregated Items:**

                **In Your Shopping List:**
                • Aggregated items show combined quantity
                • Tap item to see source recipes
                • Each recipe's contribution listed
                • Original quantities shown

                **Example Display:**
                ```
                Flour, all-purpose
                ☐ 6 cups total
                   From 3 recipes:
                   • Chocolate Chip Cookies (2 cups)
                   • Banana Bread (1 cup)
                   • Pizza Dough (3 cups)
                ```

                **Recipe Context:**
                • Long press items to see recipes
                • View → "Used in X recipes"
                • Tap recipe name to open it
                • See original ingredient amounts

                **Managing Aggregated Items:**

                **Checking Off:**
                • Check once for all recipes
                • All recipes mark as "in list"
                • Item moves to completed section
                • Uncheck if you forgot to buy

                **Removing from Specific Recipes:**
                • Long press aggregated item
                • Select "Remove from recipe"
                • Choose which recipe(s) to remove from
                • Quantity adjusts automatically
                • Other recipes keep the ingredient

                **Hiding Items:**
                • Already have it at home?
                • Long press → "Hide"
                • Item removed from view
                • Can unhide later if needed

                **Adjusting Quantities:**
                Currently not directly editable, but:
                • Adjust recipe servings before adding
                • Remove recipe and re-add with new servings
                • Or make mental note to buy more/less

                **Edge Cases:**

                **"To Taste" Ingredients:**
                • "Salt and pepper to taste" appears once
                • Doesn't aggregate with measured salt
                • Listed separately for clarity

                **Different Brands/Types:**
                • "Sharp cheddar" vs "Mild cheddar"
                • Treated as different ingredients
                • Listed separately
                • You can buy either or both

                **Ambiguous Quantities:**
                • "A pinch" + "A dash" = separate items
                • "Handful" doesn't aggregate
                • Vague amounts stay separate

                **Benefits:**

                **Efficiency:**
                • Shop once for multiple recipes
                • No duplicate purchases
                • Exact quantities needed
                • Less food waste

                **Clarity:**
                • See total amounts at a glance
                • Know which recipes need what
                • Plan bulk purchases
                • Optimize shopping

                **Flexibility:**
                • Remove ingredients from specific recipes
                • Adjust servings before adding
                • Hide items you have
                • Manage list easily

                **Cost Savings:**
                • Buy correct quantities
                • Avoid overbuying
                • Bulk purchase when beneficial
                • Reduce waste

                **Tips:**

                **Before Adding Recipes:**
                • Check pantry for staples
                • Adjust servings if needed
                • Consider using what you have
                • Plan complementary recipes

                **While Shopping:**
                • Buy total quantity shown
                • Use recipe context to verify
                • Round up if unsure
                • Check item details for recipe sources

                **After Shopping:**
                • Check off aggregated items once
                • All recipes update automatically
                • Remove recipes you didn't cook
                • Clear list for next time

                **Common Questions:**

                **Why didn't two items combine?**
                Different preparations, incompatible units, or different ingredient forms.

                **Can I split aggregated items?**
                Not directly, but remove ingredient from specific recipes to adjust.

                **What if I already have some?**
                Hide the item or make a mental note to buy less.

                **Do quantities scale with servings?**
                Yes, adjust servings before adding recipes.

                **Can I see original amounts?**
                Yes, tap item to see each recipe's contribution.

                **Best Practices:**
                • Review aggregated quantities before shopping
                • Long press items to understand source recipes
                • Adjust recipe servings BEFORE adding to list
                • Hide items you already have at home
                • Check off items once when shopping (applies to all recipes)
                """,
                section: .shoppingLists,
                keywords: ["aggregation", "combine", "duplicate", "quantity", "total", "smart", "merge"],
                relatedArticles: ["shopping-list-basics", "category-organization"],
                icon: "arrow.triangle.merge"
            )
        ]
    }

    // MARK: - Card Personalization (Task 4.4)

    var cardPersonalizationArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "styling-recipe-cards",
                title: "Styling Recipe Cards",
                content: """
                Transform your recipes into beautiful, personalized cards that reflect each dish's character and your family's memories.

                **Why Personalize Cards?**

                Heirloom's card system lets you create recipe cards that feel authentic and personal:
                • Visual distinction between recipes
                • Reflect the dish's personality
                • Preserve family memories and stories
                • Make cooking more enjoyable
                • Create heirloom-quality keepsakes

                **Card Front vs. Card Back:**

                **Front (Photo Side):**
                • Recipe photo or placeholder
                • Title and source
                • Decorative elements (stickers, annotations)
                • Background styling
                • Love marks (if enabled)

                **Back (Details Side):**
                • Personal notes
                • Family memories
                • Recipe lineage
                • Cooking history
                • Tips and variations

                **Choosing Backgrounds:**

                **Background Options:**
                Heirloom offers multiple background styles:

                **Solid Colors:**
                • Clean, modern look
                • Focus on the photo
                • Easy to read text
                • Professional appearance

                **Gradients:**
                • Subtle color transitions
                • Add depth and warmth
                • Vintage or modern feel
                • Complement recipe photos

                **Patterns:**
                • Checkered, striped, dotted
                • Vintage recipe card aesthetic
                • Kitchen-themed designs
                • Add character and texture

                **Textures:**
                • Parchment, linen, kraft paper
                • Vintage cookbook feel
                • Handmade appearance
                • Warm, nostalgic look

                **How to Change Background:**

                1. **Open Recipe Detail**
                   • Tap any recipe to view it

                2. **Tap Edit**
                   • Tap the **Edit** button
                   • Or tap **•••** → "Edit Recipe"

                3. **Select Card Style**
                   • Tap **"Card Style"** section
                   • Browse background options
                   • Tap to preview

                4. **Choose Your Background**
                   • Swipe through styles
                   • See live preview on card
                   • Tap to apply

                5. **Save**
                   • Background applies immediately
                   • Syncs across devices

                **Matching Style to Recipe:**

                **Tips for Choosing:**

                **By Cuisine:**
                • Italian: Warm colors, rustic textures
                • French: Elegant gradients, refined look
                • Mexican: Vibrant colors, bold patterns
                • Asian: Clean lines, subtle colors
                • American: Classic patterns, nostalgic textures

                **By Recipe Type:**
                • Desserts: Soft pastels, sweet colors
                • Grilled/BBQ: Warm browns, rustic textures
                • Salads: Fresh greens, light backgrounds
                • Comfort food: Cozy textures, warm tones
                • Holiday recipes: Festive colors and patterns

                **By Source:**
                • Family recipes: Vintage textures, warm tones
                • Modern recipes: Clean, minimal backgrounds
                • Restaurant-style: Professional solid colors
                • Grandmother's recipes: Nostalgic patterns

                **By Season:**
                • Spring: Light pastels, fresh colors
                • Summer: Bright, vibrant colors
                • Fall: Warm oranges, browns, textures
                • Winter: Cool blues, cozy textures

                **Combining Elements:**

                **Layering Personalization:**
                Background is the foundation. Layer on:
                • Stickers for fun decoration
                • Annotations for notes
                • Love marks for authenticity
                • Photos that complement the background

                **Visual Balance:**
                • Don't over-decorate
                • Let the photo shine
                • Use 1-3 stickers maximum
                • Keep text readable

                **Consistency:**
                • Use similar styles for related recipes
                • Family recipes could share a texture
                • Holiday recipes could use similar colors
                • Create visual collections

                **Best Practices:**

                **Do:**
                ✅ Choose backgrounds that enhance the photo
                ✅ Match the recipe's cultural origin
                ✅ Use textures for vintage family recipes
                ✅ Keep it simple and readable
                ✅ Consider the overall card aesthetic

                **Don't:**
                ❌ Use busy patterns that distract from photo
                ❌ Mix too many decorative elements
                ❌ Make text hard to read
                ❌ Over-stylize every recipe
                ❌ Forget the card back also matters

                **Accessibility:**
                • Ensure good contrast for text
                • Don't rely solely on color to convey meaning
                • Test readability with background
                • Consider VoiceOver users

                **Tips:**
                • Preview backgrounds before committing
                • Change styles seasonally
                • Use patterns sparingly
                • Let textures enhance, not overwhelm
                • Match background to card photo colors
                • Create style guidelines for your collection
                """,
                section: .cardPersonalization,
                keywords: ["style", "styling", "background", "card", "colors", "patterns", "textures"],
                relatedArticles: ["stickers-guide", "annotations-guide", "love-marks", "card-flip-guide"],
                icon: "paintbrush.fill"
            ),
            HelpArticle(
                id: "stickers-guide",
                title: "Adding Stickers",
                content: """
                Decorate your recipe cards with fun, playful stickers that add personality and visual interest.

                **What Are Stickers?**

                Stickers are decorative elements you can add to recipe card fronts:
                • Icons and illustrations
                • Food-related graphics
                • Holiday and seasonal decorations
                • Fun accents and embellishments
                • Personal touches

                **Why Use Stickers?**

                **Visual Benefits:**
                • Make cards instantly recognizable
                • Add playful personality
                • Mark special occasions
                • Create visual categories
                • Express your style

                **Practical Uses:**
                • Indicate difficulty level (chili peppers for spicy)
                • Mark dietary attributes (leaf for vegan)
                • Show seasonal relevance (snowflake for winter)
                • Highlight favorites (star or heart)
                • Celebrate holidays (pumpkin, tree, etc.)

                **Adding Stickers:**

                **Step-by-Step:**

                1. **Open Recipe Card**
                   • Go to recipe detail view
                   • Make sure card front is showing

                2. **Enter Edit Mode**
                   • Tap **Edit** button
                   • Or tap **•••** → "Edit Card"

                3. **Add Sticker**
                   • Tap **"Add Sticker"** button
                   • Or tap **+** on the card

                4. **Browse Stickers**
                   • Scroll through available stickers
                   • Categories: Food, Holidays, Symbols, etc.
                   • Tap to preview on card

                5. **Place Sticker**
                   • Sticker appears on card
                   • Drag to position
                   • Ready to manipulate

                **Manipulating Stickers:**

                **Positioning:**
                • **Drag** with one finger to move
                • Position anywhere on card front
                • Snap to guidelines (optional)
                • Avoid covering important text

                **Resizing:**
                • **Pinch** with two fingers
                • Pinch in to make smaller
                • Pinch out to make larger
                • Maintain aspect ratio

                **Rotating:**
                • **Twist** with two fingers
                • Rotate to any angle
                • Tilt for dynamic look
                • Align horizontally/vertically

                **Deleting:**
                • **Long press** sticker
                • Tap **"Delete"** in menu
                • Or drag to trash icon
                • Confirm deletion

                **Sticker Categories:**

                **Food & Ingredients:**
                • Fruits and vegetables
                • Meats and proteins
                • Desserts and sweets
                • Beverages
                • Kitchen tools

                **Holidays & Seasons:**
                • Christmas, Thanksgiving, Halloween
                • Spring, Summer, Fall, Winter
                • Birthdays and celebrations
                • Cultural holidays
                • Special occasions

                **Symbols & Icons:**
                • Stars and hearts
                • Checkmarks and badges
                • Arrows and markers
                • Numbers and letters
                • Shapes and accents

                **Dietary & Attributes:**
                • Vegetarian/Vegan leaf
                • Gluten-free symbols
                • Spicy peppers
                • Quick/Easy icons
                • Healthy/Fresh markers

                **Best Practices:**

                **Quantity:**
                • Less is more - use 1-3 stickers max
                • Don't cover the recipe photo
                • Leave space for text
                • Avoid cluttered appearance

                **Placement:**
                • Corner placement works well
                • Along top or bottom edges
                • Asymmetric for visual interest
                • Never over the title

                **Size:**
                • Keep stickers proportional
                • Smaller is often better
                • Don't make them compete with photo
                • Consistent sizing across recipes

                **Style:**
                • Match recipe theme
                • Use holiday stickers seasonally
                • Choose relevant food icons
                • Consistent style within collections

                **Purpose:**
                • Have a reason for each sticker
                • Don't add just for decoration
                • Use to communicate something
                • Make them meaningful

                **Example Uses:**

                **By Recipe Type:**
                • Desserts: Cupcake, star, heart
                • Spicy dishes: Chili pepper
                • Quick meals: Clock, lightning bolt
                • Healthy: Leaf, heart
                • Comfort food: Home, heart

                **By Season:**
                • Spring: Flowers, butterflies
                • Summer: Sun, watermelon
                • Fall: Leaf, pumpkin
                • Winter: Snowflake, tree

                **By Occasion:**
                • Thanksgiving: Turkey, pumpkin
                • Christmas: Tree, ornament
                • Birthday: Cake, balloon
                • Valentine's: Heart
                • Easter: Egg, bunny

                **By Source:**
                • Grandma's recipes: Vintage heart
                • Kids' favorites: Star
                • Tried and true: Checkmark
                • New experiments: Question mark

                **Tips:**

                **Creative Ideas:**
                • Rate recipes with stars
                • Mark difficulty with symbols
                • Indicate prep time with clocks
                • Show serving size with plates
                • Highlight kid-friendly with happy face

                **Seasonal Rotation:**
                • Update stickers by season
                • Add holiday stickers temporarily
                • Remove when season passes
                • Keep cards fresh and relevant

                **Collections:**
                • Use same sticker for recipe collections
                • All Italian: Italy flag
                • All desserts: Cupcake
                • All quick meals: Lightning
                • Create visual groups

                **Common Questions:**

                **Can I upload custom stickers?**
                Not currently - use provided sticker library.

                **How many stickers can I add?**
                No hard limit, but 1-3 is recommended for aesthetics.

                **Do stickers print?**
                Yes, stickers appear when exporting cards.

                **Do stickers sync?**
                Yes, via iCloud to all your devices.

                **Can I copy stickers between recipes?**
                Not directly - add individually to each recipe.

                **Tips:**
                • Start with one sticker and see how it looks
                • Remove stickers if card feels cluttered
                • Use stickers to tell a story
                • Seasonal stickers add charm
                • Consistency across recipes creates cohesion
                • Have fun and be creative!
                """,
                section: .cardPersonalization,
                keywords: ["stickers", "decorations", "icons", "graphics", "embellish", "decorate"],
                relatedArticles: ["styling-recipe-cards", "annotations-guide", "card-flip-guide"],
                icon: "star.circle.fill"
            ),
            HelpArticle(
                id: "annotations-guide",
                title: "Adding Annotations",
                content: """
                Add handwritten-style notes directly on your recipe cards to capture memories, tips, and personal touches.

                **What Are Annotations?**

                Annotations are text notes you can place anywhere on recipe cards:
                • Handwritten-style appearance
                • Personal messages
                • Cooking tips and tricks
                • Family memories
                • Recipe modifications

                **Why Add Annotations?**

                **Preserve Memories:**
                • "Mom's favorite!" or "Dad's birthday cake"
                • "Makes the house smell amazing"
                • "Kids request this every week"
                • "Grandma made this for holidays"

                **Record Tips:**
                • "Don't overmix!" or "Let rest 10 min"
                • "Works great in cast iron"
                • "Halve for weeknights"
                • "Best served warm"

                **Note Modifications:**
                • "Try with honey instead"
                • "Double the garlic!"
                • "Reduce salt for kids"
                • "Omit nuts for allergies"

                **Adding Annotations:**

                **Step-by-Step:**

                1. **Open Recipe Card**
                   • View the recipe detail
                   • Can add to front or back

                2. **Enter Edit Mode**
                   • Tap **Edit** button
                   • Or **•••** → "Edit Card"

                3. **Add Annotation**
                   • Tap **"Add Annotation"**
                   • Or tap **📝** icon

                4. **Type Your Note**
                   • Text field appears
                   • Type your message
                   • Keep it short (1-2 lines best)

                5. **Position Annotation**
                   • Drag to desired location
                   • Place anywhere on card
                   • Avoid covering key info

                6. **Style (Optional)**
                   • Choose text color
                   • Select font style
                   • Adjust size
                   • Rotate if needed

                7. **Save**
                   • Tap **Done** or tap away
                   • Annotation saves automatically

                **Manipulating Annotations:**

                **Moving:**
                • Drag with one finger
                • Reposition anywhere
                • Snap to guidelines
                • Keep readable

                **Editing Text:**
                • Tap annotation to edit
                • Change wording
                • Fix typos
                • Update notes

                **Styling:**
                • Change color to match card
                • Adjust size for emphasis
                • Choose handwritten font style
                • Rotate for dynamic feel

                **Deleting:**
                • Long press annotation
                • Tap "Delete"
                • Or drag to trash
                • Confirm removal

                **Annotation Styles:**

                **Handwritten:**
                • Cursive or script font
                • Looks authentic
                • Personal touch
                • Vintage feel

                **Printed:**
                • Clean, readable
                • Modern look
                • Professional
                • High contrast

                **Colors:**
                • Match card background
                • Contrast for readability
                • Red for warnings
                • Black for classic look

                **Best Practices:**

                **Placement:**
                • Top corners for short notes
                • Along edges for tips
                • Bottom for dates or sources
                • Never over photo or title

                **Length:**
                • Keep it brief (1-3 lines)
                • Use abbreviations
                • Short and sweet
                • Easy to read at a glance

                **Content:**
                • Be specific
                • Add value
                • Personal and meaningful
                • Not redundant with recipe

                **Readability:**
                • High contrast
                • Legible size
                • Clear font
                • Not too stylized

                **Example Annotations:**

                **Memories:**
                • "Made for Sarah's wedding shower"
                • "Grandma's secret ingredient"
                • "First recipe I mastered"
                • "Family favorite since 1985"
                • "Kids help make this one"

                **Tips:**
                • "Chill dough overnight"
                • "Don't skip the resting time"
                • "Cast iron works best"
                • "Serve immediately"
                • "Freezes beautifully"

                **Modifications:**
                • "Sub almond milk for dairy"
                • "We prefer dark chocolate"
                • "Reduce sugar by half"
                • "Add extra vanilla"
                • "Works with gluten-free flour"

                **Ratings & Reactions:**
                • "10/10 would make again"
                • "Restaurant quality!"
                • "Kids give it 5 stars"
                • "Better than the original"
                • "Surprisingly easy"

                **Warnings:**
                • "Very spicy!"
                • "Takes longer than stated"
                • "Serves 4, not 6"
                • "Don't overbake"
                • "Needs extra seasoning"

                **Sources:**
                • "From Aunt Mary's cookbook"
                • "Adapted from NYT Cooking"
                • "Family recipe, updated"
                • "Created 2024"
                • "Based on Mom's version"

                **Card Front vs. Back:**

                **Front Annotations:**
                • Short notes or memories
                • Visual accent
                • Part of card design
                • Quick reference

                **Back Annotations:**
                • Longer notes
                • Detailed tips
                • Full stories
                • More space available

                **Combining with Other Elements:**

                **With Stickers:**
                • Sticker + annotation = complete story
                • Star sticker + "Family favorite!"
                • Heart + "Made with love"
                • Pepper + "Extra spicy!"

                **With Love Marks:**
                • Coffee stain + "Morning tradition"
                • Worn edges + "Made 100+ times"
                • Splatter + "Gets messy!"

                **With Photos:**
                • Annotate around photo
                • Point out key details
                • Add context
                • Enhance visual story

                **Tips:**

                **Voice & Tone:**
                • Write in first person
                • Use conversational language
                • Be authentic
                • Show personality

                **Timing:**
                • Add notes right after cooking
                • Capture fresh impressions
                • Update over time
                • Date significant notes

                **Family History:**
                • Include years/dates
                • Name family members
                • Note occasions
                • Build legacy

                **Practical Info:**
                • Cooking time adjustments
                • Equipment notes
                • Ingredient swaps that worked
                • Serving suggestions

                **Common Questions:**

                **Can I add multiple annotations?**
                Yes, add as many as needed (but don't clutter).

                **Do annotations appear when sharing?**
                Yes, annotations share with the recipe.

                **Can I format text (bold, italic)?**
                Limited formatting - focus on color and size.

                **Do annotations print?**
                Yes, annotations appear in exports.

                **Can I use emojis?**
                Yes, emojis are supported in annotations.

                **Best Practices Summary:**
                • Keep annotations short and meaningful
                • Place thoughtfully to enhance, not obscure
                • Use for personal touches, not redundant info
                • Update as you cook and refine recipes
                • Tell the story behind the recipe
                """,
                section: .cardPersonalization,
                keywords: ["annotations", "notes", "handwritten", "text", "memories", "tips"],
                relatedArticles: ["styling-recipe-cards", "stickers-guide", "card-flip-guide"],
                icon: "note.text"
            ),
            HelpArticle(
                id: "love-marks",
                title: "Love Marks & Authenticity",
                content: """
                Add authentic, well-loved character to your recipe cards with coffee stains, worn edges, and other "love marks" that show a recipe's history.

                **What Are Love Marks?**

                Love marks are intentional imperfections that give recipe cards character:
                • Coffee stains and splatter marks
                • Worn or dog-eared edges
                • Faded areas
                • Signs of use and love
                • Vintage authenticity

                **Philosophy:**

                Real recipe cards aren't pristine. They're:
                • Stained from kitchen use
                • Worn from being handled
                • Splattered from cooking
                • Faded from time
                • Loved and used

                Heirloom embraces this authenticity by letting you add these marks intentionally.

                **Types of Love Marks:**

                **Coffee Stains:**
                • Circular brown stains
                • Look like coffee cup rings
                • Varying sizes and opacity
                • Random placement
                • Vintage feel

                **Splatter Marks:**
                • Small spots and droplets
                • Look like ingredient splashes
                • Cooking evidence
                • Adds realism
                • Shows the recipe was made

                **Worn Edges:**
                • Frayed corners
                • Dog-eared look
                • Aged paper appearance
                • Well-handled feel
                • Vintage charm

                **Faded Areas:**
                • Lighter sections
                • Sun-faded look
                • Age marks
                • Antique quality
                • Subtle weathering

                **Adding Love Marks:**

                **Manual Addition:**

                1. **Open Recipe Card**
                   • View recipe detail
                   • Card front shows

                2. **Enter Edit Mode**
                   • Tap **Edit**
                   • Or **•••** → "Edit Card"

                3. **Add Love Mark**
                   • Tap **"Add Love Mark"**
                   • Or tap coffee cup icon

                4. **Choose Type**
                   • Coffee stain
                   • Splatter
                   • Worn edges
                   • Faded areas

                5. **Position**
                   • Drag to place
                   • Resize if needed
                   • Rotate for natural look

                6. **Adjust Opacity**
                   • Slider to control intensity
                   • Subtle or prominent
                   • Blend naturally

                **Automatic Love Marks:**

                Heirloom can add love marks automatically based on recipe usage:

                **Based on Cooking Frequency:**
                • Cook recipe 5+ times → Small stains appear
                • Cook 10+ times → More prominent marks
                • Cook 20+ times → Well-loved appearance
                • Cook 50+ times → Vintage, heavily used look

                **How It Works:**
                • Tracks times you've cooked recipe
                • Gradually adds marks over time
                • Intensity increases with use
                • Can be disabled in settings

                **Enable/Disable:**
                • Settings → Card Personalization
                • Toggle "Automatic Love Marks"
                • Choose intensity level
                • Control how quickly they appear

                **When to Use Love Marks:**

                **Perfect For:**

                **Family Recipes:**
                • Grandma's recipes deserve love marks
                • Show multi-generational use
                • Authentic heirloom quality
                • Honor recipe legacy

                **Frequently Made:**
                • Recipes you make often
                • Weeknight staples
                • Reliable favorites
                • Show they're trusted

                **Vintage Recipes:**
                • Old family recipes
                • Historical dishes
                • Heritage cooking
                • Period authenticity

                **Comfort Food:**
                • Nostalgic dishes
                • Childhood favorites
                • Home-style cooking
                • Warm memories

                **Not Recommended For:**

                **New Recipes:**
                • Recently added
                • Not yet tested
                • Clean, modern look
                • Wait until proven

                **Professional Recipes:**
                • Restaurant-style dishes
                • Formal presentations
                • Clean aesthetic
                • Modern approach

                **Diet/Health Recipes:**
                • Clean eating focus
                • Modern wellness
                • Fresh appearance
                • Pristine presentation

                **Best Practices:**

                **Subtlety:**
                • Less is more
                • Gentle opacity
                • A few marks, not many
                • Natural placement

                **Realism:**
                • Randomize placement
                • Vary sizes
                • Organic positioning
                • Avoid patterns

                **Context:**
                • Match recipe history
                • Consider recipe age
                • Reflect actual usage
                • Tell authentic story

                **Balance:**
                • Don't obscure photo
                • Keep text readable
                • Enhance, don't overwhelm
                • Maintain beauty

                **Combining Love Marks:**

                **With Other Elements:**

                **+ Vintage Textures:**
                • Kraft paper background
                • Parchment texture
                • Aged appearance
                • Complete vintage look

                **+ Handwritten Annotations:**
                • "Made this 100 times!"
                • "Grandma's original"
                • Authentic handwriting
                • Personal history

                **+ Worn Stickers:**
                • Faded sticker colors
                • Peeling edges
                • Aged appearance
                • Complete authenticity

                **Adjusting Love Marks:**

                **Editing:**
                • Tap mark to select
                • Adjust opacity
                • Resize or reposition
                • Change type

                **Removing:**
                • Long press mark
                • Tap "Delete"
                • Remove if too much
                • Start fresh

                **Resetting:**
                • Remove all love marks
                • Start over
                • Clean slate
                • Reapply differently

                **Settings & Preferences:**

                **Global Settings:**
                • Settings → Card Personalization
                • Automatic love marks on/off
                • Default intensity
                • Frequency threshold

                **Per-Recipe:**
                • Disable for specific recipes
                • Override global settings
                • Custom intensity
                • Manual control only

                **Authenticity Slider:**
                • Control overall weathering
                • Subtle → Prominent
                • Your preference
                • Consistent across recipes

                **Common Questions:**

                **Do love marks sync?**
                Yes, via iCloud across all devices.

                **Can I remove automatic marks?**
                Yes, disable in settings or remove individually.

                **Do marks appear in exports?**
                Yes, love marks export with the card.

                **Can I add custom marks?**
                Use pre-set types, but can position and size freely.

                **Will marks fade over time?**
                No, they're permanent until manually removed.

                **Do marks affect recipe data?**
                No, purely visual - recipe data unchanged.

                **Tips:**

                **Creative Uses:**
                • Add coffee stain to morning recipes
                • Splatter marks on messy recipes
                • Worn edges on childhood favorites
                • Faded look on historical recipes

                **Storytelling:**
                • Love marks tell a recipe's journey
                • Show it's been made and loved
                • Create instant nostalgia
                • Honor recipe legacy

                **Restraint:**
                • Start with subtle marks
                • Add more over time
                • Can always add, hard to undo
                • Less is usually more

                **Best Practices Summary:**
                • Use love marks to show authenticity
                • Automatic marks reflect actual usage
                • Keep subtle for best aesthetic
                • Match to recipe's history and character
                • Don't overdo it - let the recipe shine
                """,
                section: .cardPersonalization,
                keywords: ["love marks", "coffee stains", "worn", "authentic", "vintage", "weathered"],
                relatedArticles: ["styling-recipe-cards", "annotations-guide", "card-flip-guide"],
                icon: "heart.circle.fill"
            ),
            HelpArticle(
                id: "card-flip-guide",
                title: "Flipping Recipe Cards",
                content: """
                Recipe cards in Heirloom have two sides - tap to flip between the photo front and the detailed back.

                **Two-Sided Cards:**

                Like traditional recipe cards, Heirloom cards have:

                **Front Side:**
                • Recipe photo (or placeholder)
                • Recipe title
                • Source type badge
                • Decorative elements (stickers, annotations)
                • Background styling
                • Love marks (if added)

                **Back Side:**
                • Personal notes section
                • Recipe lineage (if versioned)
                • Cooking history (times cooked, last cooked)
                • Additional tips and variations
                • Family memories
                • Source information

                **How to Flip:**

                **Tap to Flip:**
                • Simply **tap the card** anywhere
                • Card flips with animation
                • Sound effect plays (if enabled)
                • Haptic feedback (if enabled)

                **Gesture:**
                • Single tap on card
                • Works on both sides
                • Flip back and forth freely
                • Instant response

                **Automatic Flip:**
                • Some actions flip automatically:
                  - Adding notes (flips to back)
                  - Viewing lineage (flips to back)
                  - Editing photo (flips to front)

                **Flip Animation:**

                **Visual Effect:**
                • Smooth 3D flip animation
                • Card rotates on horizontal axis
                • Natural page-turn feel
                • Brief transition

                **Sound Effect:**
                • Satisfying "flip" sound
                • Like turning a real card
                • Can be disabled in Settings
                • Adds tactile feedback

                **Haptics:**
                • Physical feedback on flip
                • Confirms the action
                • Feels responsive
                • Enhances realism

                **Front Side Details:**

                **What's Displayed:**

                **Photo:**
                • Main recipe photo
                • Or placeholder if no photo
                • Full-size, high quality
                • Tap to view larger

                **Title:**
                • Recipe name
                • Positioned over photo
                • Readable typography
                • Color contrasts with photo

                **Source Badge:**
                • Icon showing source type
                • URL, Manual, Scan, etc.
                • Small, unobtrusive
                • Top corner placement

                **Decorations:**
                • Stickers you've added
                • Annotations and notes
                • Love marks
                • Background styling

                **Actions:**
                • Tap card to flip
                • Swipe for next/previous recipe
                • Long press for quick actions
                • Tap photo to zoom

                **Back Side Details:**

                **What's Displayed:**

                **Personal Notes:**
                • Your notes about the recipe
                • Tips, variations, memories
                • Editable text area
                • Add anytime

                **Recipe Lineage:**
                • Shows version history
                • Parent recipe link
                • Who adapted it
                • When created

                **Cooking History:**
                • Times cooked count
                • Last cooked date
                • Favorite status
                • Usage patterns

                **Additional Info:**
                • Source URL (if imported)
                • Date added
                • Last modified
                • Collections it's in

                **Using Both Sides:**

                **Front for:**
                • Quick visual identification
                • Browsing recipes
                • Inspiration and browsing
                • Aesthetic appeal
                • Sharing on social media

                **Back for:**
                • Reading detailed notes
                • Understanding lineage
                • Checking history
                • Adding/editing notes
                • Reference while cooking

                **When Cooking:**

                **Front Side:**
                • Confirm you have right recipe
                • Visual reference for plating
                • Quick identification
                • Stay motivated with photo

                **Back Side:**
                • Read your personal tips
                • Check your last notes
                • See what worked before
                • Family secrets and tricks

                **Flip Workflow:**

                **Typical Flow:**
                1. Browse recipes (front side)
                2. Tap to see details (flips to back)
                3. Read notes and history
                4. Tap to return (flips to front)
                5. Start cooking

                **Editing Flow:**
                1. View recipe (front side)
                2. Flip to back to add notes
                3. Write tips or memories
                4. Flip to front to add stickers
                5. Save changes

                **Settings:**

                **Flip Settings:**
                Settings → Accessibility → Card Flip

                **Sound Effects:**
                • Enable/disable flip sound
                • Adjust volume
                • Choose sound style
                • Silent mode

                **Haptic Feedback:**
                • Enable/disable haptics
                • Adjust intensity
                • Light, Medium, Strong
                • Off for no haptics

                **Animation Speed:**
                • Normal (default)
                • Fast (quick flip)
                • Slow (gentle transition)
                • Match your preference

                **Accessibility:**

                **VoiceOver:**
                • Announces "Card front" or "Card back"
                • Reads card contents
                • Swipe to flip
                • Alternative to tapping

                **Reduce Motion:**
                • If enabled, crossfade instead of flip
                • No rotation animation
                • Gentler transition
                • Reduces motion sickness

                **Contrast:**
                • High contrast mode applies
                • Readable text on both sides
                • Clear visual hierarchy
                • Accessible colors

                **Tips:**

                **Visual Storytelling:**
                • Front shows the dish
                • Back tells the story
                • Complete picture of recipe
                • Honor both sides

                **Balance:**
                • Don't neglect the back
                • Add meaningful notes
                • Use both sides fully
                • Complete the experience

                **Sharing:**
                • Consider both sides when sharing
                • Front impresses, back informs
                • Share complete card
                • Tell full story

                **Common Questions:**

                **Can I disable flipping?**
                No, but you can disable animations in Accessibility.

                **Which side is the default?**
                Front side (photo) is default when opening a recipe.

                **Can I print both sides?**
                Yes, exports include both front and back.

                **Do both sides sync?**
                Yes, all card data syncs via iCloud.

                **Can I customize what's on each side?**
                Front layout is fixed; back is customizable with notes.

                **Best Practices:**
                • Use front for visual appeal and recognition
                • Use back for personal history and tips
                • Flip while cooking to reference notes
                • Keep both sides maintained and updated
                • Embrace the two-sided metaphor - it's like real recipe cards
                """,
                section: .cardPersonalization,
                keywords: ["flip", "flipping", "card front", "card back", "two-sided", "animation"],
                relatedArticles: ["styling-recipe-cards", "annotations-guide", "sharing-recipes"],
                icon: "rectangle.portrait.rotate"
            ),
            HelpArticle(
                id: "sharing-recipe-cards",
                title: "Sharing Recipe Cards",
                content: """
                Share your beautifully styled recipe cards with family, friends, and fellow cooks.

                **What Gets Shared:**

                When you share a recipe card, recipients get:
                • Complete recipe (ingredients, instructions)
                • Recipe photo
                • All styling (background, stickers, annotations)
                • Love marks (if present)
                • Personal notes (optional)
                • Recipe lineage/versions (if shared)

                **Sharing Options:**

                **Share as Image:**
                • Card front as high-res image
                • Perfect for social media
                • Instagram, Facebook, Pinterest
                • Text messages
                • Email attachments

                **Share as PDF:**
                • Printable recipe card
                • Both front and back
                • High quality
                • Print at home
                • Professional appearance

                **Share as Link:**
                • Web-viewable recipe
                • Opens in browser
                • No app required
                • Easy to forward
                • Can be revoked

                **Share as Recipe File:**
                • Import into Heirloom
                • Complete with styling
                • Recipient can edit
                • JSON format
                • Full fidelity

                **Share as Text:**
                • Plain text format
                • Ingredients + instructions
                • No styling
                • Copy/paste friendly
                • Universal compatibility

                **How to Share:**

                **Step-by-Step:**

                1. **Open Recipe**
                   • View the recipe to share

                2. **Tap Share**
                   • Tap share icon (square with arrow up)
                   • Or **•••** → "Share"

                3. **Choose Format**
                   • Image (card front)
                   • PDF (printable)
                   • Link (web view)
                   • Recipe file (Heirloom format)
                   • Text (plain format)

                4. **Select Options**
                   • Include/exclude personal notes
                   • Include/exclude lineage
                   • Front only or both sides
                   • Resolution (for images)

                5. **Choose Method**
                   • Messages, Email, AirDrop
                   • Social media apps
                   • Copy link
                   • Save to Files

                6. **Send**
                   • Select recipients
                   • Add message (optional)
                   • Send

                **Sharing Settings:**

                **What to Include:**

                **Always Shared:**
                • Recipe title
                • Ingredients
                • Instructions
                • Prep/cook times
                • Servings

                **Optional:**
                • Personal notes (toggle on/off)
                • Recipe lineage (toggle on/off)
                • Times cooked (toggle on/off)
                • Your name as source

                **Privacy:**
                • Choose what's included
                • Control personal information
                • Share selectively
                • Respect privacy

                **Sharing by Format:**

                **Image Share:**

                **Best For:**
                • Social media
                • Quick sharing
                • Visual inspiration
                • Showing off your styling

                **Options:**
                • Front only or both sides
                • Resolution (standard, high, maximum)
                • Include watermark (optional)
                • Square crop for Instagram

                **Limitations:**
                • Visual only - not editable
                • May lose detail on small screens
                • No interactive elements

                **PDF Share:**

                **Best For:**
                • Printing
                • Email
                • Professional sharing
                • Archiving

                **Features:**
                • Print-optimized layout
                • Both sides on separate pages
                • High quality
                • Searchable text
                • Universal format

                **Options:**
                • Letter or A4 size
                • Include margins
                • Print guidelines
                • Header/footer

                **Link Share:**

                **Best For:**
                • Group sharing
                • Easy forwarding
                • No recipient setup
                • Temporary sharing

                **Features:**
                • Opens in web browser
                • No app required
                • Mobile-friendly
                • Can be revoked
                • Track views (optional)

                **Security:**
                • Generate unique URL
                • Expiration date (optional)
                • Password protect (optional)
                • Revoke anytime

                **Recipe File Share:**

                **Best For:**
                • Sharing with other Heirloom users
                • Preserving all customization
                • Collaborative cooking
                • Family recipe exchange

                **Features:**
                • Complete fidelity
                • All styling preserved
                • Editable by recipient
                • Includes versions
                • JSON format

                **Import:**
                • Recipient taps file
                • Opens in Heirloom
                • Imports complete recipe
                • Fully editable

                **Text Share:**

                **Best For:**
                • Copy/paste
                • Plain text needs
                • Universal compatibility
                • Cooking apps

                **Format:**
                • Markdown-style
                • Ingredients list
                • Numbered instructions
                • No formatting
                • Easy to read

                **Use Cases:**
                • Paste into notes app
                • Email to non-app users
                • Add to other recipe managers
                • Print simple version

                **Sharing to Social Media:**

                **Instagram:**
                • Share as image (card front)
                • Square crop option
                • High resolution
                • Add caption externally
                • Tag @heirloomapp

                **Facebook:**
                • Share as image or link
                • Recipe displays in feed
                • Friends can save
                • Comment and react

                **Pinterest:**
                • Share as image (card front)
                • Auto-creates pin
                • Links back to web view
                • Add to recipe boards

                **X (Twitter):**
                • Share as image + text
                • Include recipe URL
                • Short description
                • Use hashtags

                **Sharing with Family:**

                **Family Sharing:**
                • Share via Messages or AirDrop
                • Use recipe file format
                • They can import to Heirloom
                • Styling preserved
                • Can modify their copy

                **Group Sharing:**
                • Share link to family group chat
                • Everyone can view
                • Discuss and comment externally
                • Easy distribution

                **Collaborative Recipes:**
                • Share base recipe
                • Family members create versions
                • Everyone maintains their edits
                • Compare versions

                **Permissions:**

                **When You Share:**
                • Recipient gets a copy
                • They can edit their copy
                • Your original unchanged
                • No ongoing connection

                **Link Sharing:**
                • View-only by default
                • Can set to allow import
                • Revocable access
                • Optional expiration

                **Print Sharing:**
                • PDF is standalone
                • No permissions needed
                • Permanent copy
                • Can't be revoked

                **Common Questions:**

                **Do recipients need Heirloom?**
                Only for recipe file imports. Images, PDFs, and links work for everyone.

                **Can I unshare a recipe?**
                Revoke shared links; images/PDFs/files can't be unshared once sent.

                **Does sharing sync changes?**
                No, shares are one-time copies. Changes don't sync.

                **Can I share multiple recipes at once?**
                Yes, select multiple recipes and share as a collection.

                **Do my personal notes share?**
                Only if you choose to include them.

                **Can I share without styling?**
                Yes, use text format for plain recipe data only.

                **Tips:**
                • Choose format based on recipient
                • Use recipe file format for Heirloom users
                • Use images for social media
                • Use PDF for printing
                • Use links for easy group sharing
                • Review what's included before sharing
                • Add context in your message
                • Consider privacy of personal notes
                """,
                section: .cardPersonalization,
                keywords: ["share", "sharing", "export", "send", "social media", "print", "pdf"],
                relatedArticles: ["card-flip-guide", "styling-recipe-cards", "recipe-versions"],
                icon: "square.and.arrow.up"
            )
        ]
    }

    // MARK: - Advanced Features (Task 4.5)

    var advancedFeaturesArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "scaling-recipes-advanced",
                title: "Smart Recipe Scaling",
                content: """
                Heirloom intelligently scales recipes up or down while maintaining flavor balance and providing cooking guidance.

                **Why Smart Scaling Matters:**

                Simply multiplying all ingredients doesn't always work:
                • Spices become overwhelming when doubled
                • Leavening agents don't scale linearly
                • Cooking times change with volume
                • Equipment size matters
                • Some recipes fundamentally don't scale

                Heirloom uses smart scaling algorithms to adjust ingredients appropriately.

                **How to Scale a Recipe:**

                **Step-by-Step:**

                1. **Open Recipe**
                   • View the recipe you want to scale

                2. **Tap Servings**
                   • Tap the serving size (e.g., "Serves 4")
                   • Scaling interface appears

                3. **Choose New Servings**
                   • Use stepper to adjust servings
                   • Or type custom amount
                   • See preview of scaled ingredients

                4. **Review Changes**
                   • Ingredients update in real-time
                   • Check for warnings or notes
                   • Equipment suggestions adjust

                5. **Apply Scale**
                   • Tap "Apply" to scale recipe
                   • Or "Cancel" to keep original

                **Smart Scaling Rules:**

                **Spices & Seasonings (66% scaling):**
                When doubling a recipe, spices scale to 1.66x (not 2x):
                • Salt, pepper, chili powder
                • Dried herbs and spices
                • Hot sauces and spicy elements
                • Garlic and onion powder

                **Why:** Flavor compounds concentrate as volume increases. Over-seasoning ruins dishes.

                **Leavening Agents (75% scaling):**
                Baking powder, baking soda, yeast scale to 1.75x when doubling:
                • Too much creates bitter flavor
                • Chemical reactions aren't linear
                • Over-leavening causes collapse

                **Liquids (90% scaling):**
                Water, broth, milk scale to 1.9x when doubling:
                • Surface area affects evaporation
                • Larger volumes retain more moisture
                • Prevents soup-like consistency

                **Linear Ingredients (100% scaling):**
                Most ingredients scale normally:
                • Flour, sugar, butter
                • Vegetables and proteins
                • Eggs, dairy, fats
                • Pasta, rice, grains

                **Scaling Examples:**

                **Doubling a Recipe (2x):**
                Original → Scaled:
                • 1 cup flour → 2 cups (100%)
                • 1 tsp salt → 1.66 tsp (66%)
                • 1 tsp baking powder → 1.75 tsp (75%)
                • 1 cup milk → 1.9 cups (90%)

                **Halving a Recipe (0.5x):**
                Original → Scaled:
                • 2 cups flour → 1 cup (100%)
                • 2 tsp salt → 1.32 tsp (66%)
                • 2 tsp baking soda → 1.5 tsp (75%)
                • 2 cups water → 1.8 cups (90%)

                **Cooking Time Adjustments:**

                **Baked Goods:**
                • Smaller portions: -10-15% time
                • Larger portions: +15-25% time
                • Thinner items cook faster
                • Monitor doneness closely

                **Stovetop:**
                • More ingredients = more time to heat
                • Use larger pan for larger batches
                • Don't overcrowd pan
                • Adjust heat as needed

                **Slow Cooker:**
                • Timing less affected by scaling
                • Must reach minimum fill level
                • Don't exceed max capacity
                • Temperature stays consistent

                **Equipment Recommendations:**

                Heirloom suggests equipment changes:
                • "Use 9x13 pan instead of 8x8"
                • "Bake in two pans"
                • "Use 6-quart pot instead of 4-quart"
                • "Divide into two slow cookers"

                **Scaling Limits:**

                **Maximum Scale:**
                • Most recipes: 10x
                • Baked goods: 5x
                • Complex recipes: 3x

                **Minimum Scale:**
                • Most recipes: 0.25x (¼)
                • Some desserts: 0.5x (½)

                **Warnings:**
                Heirloom shows warnings for extreme scales:
                • "Very large batch - cooking time significantly longer"
                • "Very small batch - measurements may be imprecise"
                • "Consider baking in multiple pans"

                **Locked Recipes:**

                Some recipes can't be scaled (marked with lock icon):

                **Why Recipes Lock:**

                **Laminated Doughs:**
                • Croissants, puff pastry
                • Butter-to-dough ratio critical
                • Folding technique specific
                • Size affects lamination

                **Emulsions:**
                • Mayonnaise, hollandaise
                • Molecular ratios precise
                • Techniques don't scale
                • Breaking risk increases

                **Candy & Confections:**
                • Temperature-dependent
                • Crystal formation specific
                • Batch size affects outcome
                • Equipment limitations

                **Fermented Breads:**
                • Sourdough starters
                • Yeast activity timing
                • Proofing requirements
                • Shaping limitations

                **Molecular Gastronomy:**
                • Precise ratios required
                • Chemical reactions specific
                • Equipment constraints
                • Timing critical

                **Best Practices:**

                **Before Scaling:**
                • Read original recipe notes
                • Check equipment capacity
                • Consider time available
                • Plan for batch cooking if needed

                **While Scaling:**
                • Review all ingredient changes
                • Note equipment suggestions
                • Check cooking time adjustments
                • Read any warnings

                **After Scaling:**
                • Taste and adjust seasonings
                • Monitor cooking closely
                • Take notes for next time
                • Save successful scales

                **Tips:**

                **Batch Cooking:**
                • Better to cook 2x recipe twice than 4x once
                • Quality maintained better
                • Easier to manage
                • Less risky

                **Testing:**
                • Try 1.5x or 2x before going bigger
                • Make notes on results
                • Adjust next time
                • Build confidence gradually

                **Seasoning:**
                • Under-season initially
                • Taste and adjust at end
                • Easier to add than remove
                • Trust the smart scaling

                **Common Questions:**

                **Can I override smart scaling?**
                No, but you can edit scaled amounts manually after applying.

                **Why can't I scale this recipe?**
                Recipe is locked due to technical limitations (see locked recipes).

                **Do times always adjust automatically?**
                Time suggestions provided, but monitor doneness yourself.

                **Can I save a scaled version?**
                Yes, create a new version with the scaled amounts.

                **Does scaling affect nutrition info?**
                Yes, per-serving nutrition stays consistent.

                **Why does it round amounts?**
                For practicality - "1.83 cups" becomes "1¾ cups + 1 Tbsp".

                **Tips Summary:**
                • Trust smart scaling for spices and leavening
                • Check equipment recommendations
                • Monitor cooking times closely
                • Make notes for future reference
                • Consider batch cooking instead of extreme scaling
                """,
                section: .advancedFeatures,
                keywords: ["scale", "scaling", "servings", "multiply", "adjust", "portions", "smart"],
                relatedArticles: ["recipe-versions", "shopping-list-basics"],
                icon: "chart.bar.fill"
            ),
            HelpArticle(
                id: "cloudkit-sync",
                title: "iCloud Sync & Sharing",
                content: """
                Your recipes automatically sync across all your devices via iCloud, keeping everything up to date.

                **How iCloud Sync Works:**

                **Automatic Syncing:**
                Heirloom uses CloudKit to sync:
                • All recipes and ingredients
                • Card styling and personalization
                • Shopping lists
                • Cooking history
                • Personal notes
                • Collections and favorites

                **Requirements:**
                • Signed into iCloud on device
                • iCloud Drive enabled
                • Internet connection (syncs when available)
                • Heirloom granted iCloud access

                **What Syncs:**

                **Complete Recipe Data:**
                • Title, ingredients, instructions
                • Photos and images
                • Source information
                • Prep/cook times, servings

                **Personalization:**
                • Card backgrounds and styling
                • Stickers and annotations
                • Love marks
                • Front and back customization

                **User Data:**
                • Times cooked, last cooked
                • Favorite status
                • Personal notes
                • Recipe versions and lineage

                **Collections:**
                • Shopping lists
                • Recipe collections
                • Filters and preferences
                • Settings

                **Sync Status:**

                **Checking Sync:**
                Settings → Network & Sync
                • Last sync time
                • Pending operations count
                • Sync status indicator
                • Error messages (if any)

                **Status Indicators:**
                • ✅ Synced - All changes uploaded
                • 🔄 Syncing - Upload in progress
                • ⏸️ Paused - Waiting for connection
                • ⚠️ Error - Sync issue (tap for details)

                **Manual Sync:**
                • Pull down on recipe list to refresh
                • Or Settings → "Sync Now"
                • Forces immediate sync check
                • Useful after big changes

                **Offline Mode:**

                **Working Offline:**
                All features work offline:
                • View and cook from recipes
                • Edit and create recipes
                • Manage shopping lists
                • Personalize cards

                **Changes Queue:**
                • Edits saved locally
                • Auto-sync when online
                • No data loss
                • Seamless experience

                **Conflict Resolution:**
                If edited on multiple devices offline:
                • Most recent change wins
                • Both versions preserved
                • Choose which to keep
                • Merge changes if possible

                **iCloud Storage:**

                **Storage Usage:**
                Settings → iCloud Storage
                • See Heirloom storage used
                • Recipes: ~1-2MB per 100
                • Photos: Varies by size
                • Typically very small

                **Managing Storage:**
                • Delete unused recipes
                • Optimize photos (auto)
                • Clear old shopping lists
                • Export and archive

                **Full:**
                If iCloud storage full:
                • Sync pauses
                • Local changes still saved
                • Upgrade iCloud storage
                • Or free up space

                **Family Sharing:**

                **iCloud Family Sharing:**
                NOT automatic - recipes don't auto-share with family.

                **How to Share:**
                • Share individual recipes via share sheet
                • Send recipe file format
                • Family can import
                • Everyone maintains own copy

                **Why Not Auto-Share:**
                • Recipes are personal
                • Everyone customizes differently
                • Prevents unwanted syncing
                • Maintains privacy

                **Collaborative Recipes:**
                • Share base recipe
                • Family creates versions
                • Each person's edits separate
                • Compare versions

                **Troubleshooting:**

                **Sync Not Working:**

                **Check Internet:**
                • WiFi or cellular connected
                • Stable connection
                • Not in airplane mode

                **Check iCloud:**
                • Signed into iCloud
                • iCloud Drive enabled
                • Settings → [Name] → iCloud
                • Heirloom toggle on

                **Check Permissions:**
                • Settings → Heirloom
                • iCloud permission granted
                • Background refresh enabled
                • Data & cellular allowed

                **Force Sync:**
                • Close and reopen app
                • Pull to refresh recipe list
                • Settings → "Sync Now"
                • Wait 30 seconds

                **Sync Errors:**

                **Common Errors:**

                **"iCloud Not Available":**
                • Sign into iCloud
                • Check Apple system status
                • Try again in a few minutes

                **"Storage Full":**
                • Free up iCloud space
                • Upgrade iCloud storage
                • Delete large items
                • Optimize photos

                **"Network Error":**
                • Check internet connection
                • Try different network
                • Disable VPN temporarily
                • Wait and retry

                **"Sync Conflict":**
                • View conflict details
                • Choose which version to keep
                • Or merge changes manually
                • Conflict resolution guide provided

                **Data Privacy:**

                **Your Data:**
                • Stored in your iCloud account
                • Apple's encryption standards
                • Only you have access
                • Heirloom doesn't see your data

                **Not Shared:**
                • Recipes private by default
                • iCloud sharing is explicit
                • No social features required
                • Complete control

                **Deleting Data:**
                • Delete recipe → removes from iCloud
                • Syncs deletion to all devices
                • Permanent after 30 days
                • Can recover within 30 days

                **Best Practices:**

                **Stay Connected:**
                • Keep WiFi on when home
                • Enable cellular data for Heirloom
                • Sync happens automatically
                • No manual intervention needed

                **Monitor Storage:**
                • Check iCloud storage monthly
                • Delete unused recipes
                • Archive old data
                • Upgrade if needed

                **Verify Sync:**
                • Check recipe on second device
                • Ensure edits appear
                • Confirm after big changes
                • Peace of mind

                **Tips:**
                • Sync happens in background automatically
                • No need to manually sync usually
                • All devices see same data within seconds
                • Works seamlessly across iPhone, iPad, Mac
                • Offline edits sync automatically when online
                """,
                section: .advancedFeatures,
                keywords: ["icloud", "sync", "cloud", "backup", "devices", "sharing", "cloudkit"],
                relatedArticles: ["sharing-recipe-cards", "sync-issues"],
                icon: "icloud.fill"
            ),
            HelpArticle(
                id: "recipe-lineage",
                title: "Recipe Lineage & Family History",
                content: """
                Track how recipes evolve through your family with Heirloom's lineage system.

                **What is Recipe Lineage?**

                Lineage shows the family tree of a recipe:
                • Where it came from
                • Who adapted it
                • When it was modified
                • How it evolved
                • Current generation

                **Why Track Lineage:**

                **Preserve History:**
                • Know original source
                • Honor family contributors
                • Remember adaptations
                • Pass down stories

                **Understand Evolution:**
                • See what changed over time
                • Compare generations
                • Learn improvements
                • Appreciate journey

                **Build Legacy:**
                • Document family recipes
                • Credit contributors
                • Future generations understand
                • Create heirloom collection

                **Viewing Lineage:**

                **On Card Back:**
                1. **Open Recipe**
                2. **Flip Card** (tap card front)
                3. **See Lineage Section:**
                   • "Based on [Parent Recipe]"
                   • "Adapted by [Name]"
                   • "Created [Date]"

                **In Version View:**
                • Tap "View Versions"
                • See full family tree
                • All ancestors and descendants
                • Timeline visualization

                **Lineage Information:**

                **What's Tracked:**

                **Parent Recipe:**
                • Original recipe name
                • Link to parent (if available)
                • Source of original
                • When parent was created

                **Contributor:**
                • Your name (or family member's)
                • Who made this version
                • Date of creation
                • Their role (e.g., "Grandma", "adapted by me")

                **Changes Made:**
                • Description of modifications
                • Why changes were made
                • Notes for future cooks
                • Tips learned

                **Date Information:**
                • When version created
                • Last modified date
                • How old the lineage
                • Generation number

                **Creating Lineage:**

                **Creating a Version:**

                1. **Open Base Recipe**
                   • Start with recipe to adapt

                2. **Create Version**
                   • Tap **•••** → "Create Version"
                   • Or Edit → "Save as New Version"

                3. **Name Version**
                   • Give descriptive name
                   • Include your name or generation
                   • E.g., "Mom's 2024 Version"

                4. **Make Changes**
                   • Modify ingredients
                   • Update instructions
                   • Add personal notes
                   • Adjust to taste

                5. **Add Lineage Notes**
                   • Describe what you changed
                   • Why you changed it
                   • What improved
                   • Tips for next person

                6. **Save**
                   • Lineage automatically tracked
                   • Linked to parent
                   • Your name attached

                **Lineage Best Practices:**

                **Documentation:**
                • Write clear lineage notes
                • Explain all changes
                • Include year/date
                • Name yourself clearly

                **Example Notes:**
                "Reduced sugar by 1/3 cup because the original was too sweet for modern tastes. Added 1 tsp vanilla extract for depth. Baking time reduced to 35 minutes in my oven. - Sarah, 2024"

                **Attribution:**
                • Always credit the original
                • Honor previous contributors
                • Use real names (not just "me")
                • Include relationships when relevant

                **When to Create Version:**
                • Significant ingredient changes
                • Technique modifications
                • Dietary adaptations
                • Cultural adjustments
                • Generational updates

                **When NOT to Version:**
                • Minor typo fixes
                • Quantity corrections
                • Small tweaks
                • Temporary modifications

                **Multi-Generation Example:**

                **Great-Grandma's Apple Pie (1940):**
                • Original family recipe
                • Traditional American
                • Lard crust, tart apples
                • Coal oven instructions

                **↓ Adapted by Grandma (1970):**
                • Changed: Butter instead of lard
                • Added: 1 tsp cinnamon
                • Modernized: Electric oven temps
                • Notes: "Butter makes it flakier"

                **↓ Adapted by Mom (1995):**
                • Changed: Reduced sugar by ¼ cup
                • Added: Lemon juice for brightness
                • Updated: Convection oven timing
                • Notes: "Family prefers less sweet"

                **↓ Adapted by Me (2024):**
                • Changed: Gluten-free flour blend
                • Added: Apple varieties suggestion
                • Modernized: Air fryer option
                • Notes: "Works perfectly GF!"

                **Viewing Full Lineage:**

                **Version Timeline:**
                • Tap recipe → "View Versions"
                • See all versions chronologically
                • Tap any version to view
                • Compare side-by-side
                • See what changed between each

                **Lineage Graph:**
                • Visual family tree
                • Shows branches
                • Multiple adaptations
                • Parallel versions

                **Using Lineage:**

                **While Cooking:**
                • Read parent recipe notes
                • Understand original intent
                • See what worked
                • Learn from others

                **Sharing Recipes:**
                • Include lineage when sharing
                • Recipients see full history
                • Honors all contributors
                • Maintains context

                **Family Reunions:**
                • Compare versions
                • Discuss changes
                • Decide favorites
                • Create new versions together

                **Special Use Cases:**

                **Dietary Adaptations:**
                Create versions for different needs:
                • Vegan version
                • Gluten-free version
                • Low-sugar version
                • Allergy-safe version

                **Regional Variations:**
                Document how recipe travels:
                • Original Italian version
                • American adaptation
                • Personal fusion
                • Each credited properly

                **Seasonal Variants:**
                • Summer fruit version
                • Winter citrus version
                • Holiday spiced version
                • Each linked to original

                **Improvement Journey:**
                • First attempt
                • Second try (fixes)
                • Third time (perfected)
                • Final version
                • All documented

                **Common Questions:**

                **Do I need permission to adapt?**
                No, adapt freely. Heirloom tracks lineage automatically.

                **Can I create version of imported recipe?**
                Yes, even URL imports can have versions.

                **What if I don't know original source?**
                Note "Unknown" or "Traditional" as source.

                **Do versions count as separate recipes?**
                No, they're linked. Milestones count unique recipes only.

                **Can I have multiple versions from same parent?**
                Yes! Multiple people can adapt the same base recipe.

                **Does lineage share with recipe?**
                Optional - you choose whether to include lineage when sharing.

                **Tips:**

                **Documentation:**
                • Take photos of original recipe cards
                • Scan handwritten recipes
                • Note family stories
                • Record who taught you

                **Accuracy:**
                • Use real names
                • Include dates
                • Credit properly
                • Maintain history

                **Storytelling:**
                • Write like leaving note for grandchildren
                • Include personal touches
                • Mention occasions
                • Share memories

                **Best Practices Summary:**
                • Create versions for significant changes
                • Document what and why you changed
                • Credit all contributors properly
                • Share full lineage with family
                • Use lineage to tell your family's food story
                """,
                section: .advancedFeatures,
                keywords: ["lineage", "history", "family", "generations", "versions", "ancestry", "heritage"],
                relatedArticles: ["recipe-versions", "sharing-recipe-cards"],
                icon: "tree.fill"
            )
        ]
    }

    // MARK: - Troubleshooting

    var troubleshootingArticles: [HelpArticle] {
        [
            HelpArticle(
                id: "sync-issues",
                title: "Sync Issues",
                content: """
                If you're experiencing sync issues:

                **Check Network:**
                • Go to Settings → Network & Sync
                • Verify you're online
                • Check pending operations count

                **Check iCloud:**
                • Ensure you're signed into iCloud
                • Verify Heirloom has iCloud permission
                • Check available storage

                **Manual Retry:**
                • Go to Settings → Network & Sync
                • Tap "Retry Sync Now"
                • Wait for pending operations to clear

                **View Error Details:**
                • If there's a sync error, you'll see "View Sync Issues"
                • Tap it for specific error information
                • Follow the recovery steps provided

                **Still Having Issues?**
                Contact support from Settings → Help & Support
                """,
                section: .troubleshooting,
                keywords: ["sync", "icloud", "network", "error", "offline", "pending"],
                icon: "icloud.slash"
            ),
            HelpArticle(
                id: "import-failures",
                title: "Recipe Import Not Working",
                content: """
                If recipe import fails:

                **URL Import Issues:**
                • Verify the URL is correct
                • Some sites block automated access
                • Try copying the recipe text manually

                **Scan Issues:**
                • Ensure good lighting
                • Hold camera steady
                • Take multiple clear photos
                • OCR works best with printed text

                **What Gets Imported:**
                • Recipe title and description
                • Ingredients list
                • Instructions
                • Prep/cook times
                • Servings

                **After Import:**
                • Review and edit as needed
                • Missing info can be added manually
                • Images can be added from your library
                """,
                section: .troubleshooting,
                keywords: ["import", "fail", "error", "url", "scan", "ocr"],
                icon: "exclamationmark.triangle"
            ),
        ]
    }

    // MARK: - Helper Methods

    /// Get all articles for a specific section
    func articles(for section: HelpSection) -> [HelpArticle] {
        allArticles.filter { $0.section == section }
    }

    /// Search articles by query
    func search(_ query: String) -> [HelpArticle] {
        guard !query.isEmpty else { return [] }
        return allArticles.filter { $0.matches(query) }
    }

    /// Get related articles by IDs
    func relatedArticles(for article: HelpArticle) -> [HelpArticle] {
        allArticles.filter { article.relatedArticles.contains($0.id) }
    }

    /// Get article by ID
    func article(withId id: String) -> HelpArticle? {
        allArticles.first { $0.id == id }
    }

    // MARK: - FAQ Content (Task 4.6)

    struct FAQItem: Identifiable {
        let id: String
        let question: String
        let answer: String
        let section: HelpSection

        init(question: String, answer: String, section: HelpSection) {
            self.id = UUID().uuidString
            self.question = question
            self.answer = answer
            self.section = section
        }
    }

    var faqItems: [FAQItem] {
        [
            // MARK: Getting Started
            FAQItem(
                question: "How do I add my first recipe?",
                answer: "There are four ways to add recipes: 1) Import from a URL (paste a recipe website link), 2) Scan cookbook pages with your camera, 3) Manually type in a recipe, or 4) Import from a JSON file. Tap the '+' button to see all options.",
                section: .gettingStarted
            ),
            FAQItem(
                question: "How do I sync my recipes across devices?",
                answer: "Recipes automatically sync via iCloud when you're signed in with the same Apple ID on all devices. Ensure iCloud Drive is enabled in Settings → [Your Name] → iCloud. Check sync status in Heirloom Settings → Network & Sync.",
                section: .gettingStarted
            ),
            FAQItem(
                question: "Can I import recipes from any website?",
                answer: "Heirloom supports most major recipe websites including AllRecipes, Bon Appétit, Food Network, NYT Cooking, Serious Eats, and hundreds more. If a site doesn't work automatically, you can copy and paste the recipe text into manual entry.",
                section: .gettingStarted
            ),
            FAQItem(
                question: "What happens if I scan a cookbook page with poor lighting?",
                answer: "For best OCR results, use bright, even lighting and hold your device steady. If the scan quality is poor, you can retake the photo or edit the extracted text before saving. The app will highlight low-confidence areas for review.",
                section: .gettingStarted
            ),

            // MARK: Recipes
            FAQItem(
                question: "How do I search for recipes?",
                answer: "Use the search bar at the top of the Recipes tab to search by recipe name, ingredients, or keywords. You can also use filters to narrow by source type (website, cookbook, manual), favorites, cooking status, and more.",
                section: .recipes
            ),
            FAQItem(
                question: "What are recipe versions and how do I use them?",
                answer: "Recipe versions let you track how recipes evolve over time. When you edit a recipe, you can save it as a new version while keeping the original. Each version can have notes about what changed and why, creating a history of adaptations.",
                section: .recipes
            ),
            FAQItem(
                question: "How do I track recipe lineage across generations?",
                answer: "Recipe lineage connects related versions to show how recipes are passed down and adapted through families. When creating a new version, the app automatically links it to the original, creating a family tree of recipes showing who adapted it and when.",
                section: .recipes
            ),
            FAQItem(
                question: "Can I edit a recipe after importing it?",
                answer: "Yes! Tap any recipe to view it, then tap 'Edit' in the top right corner. You can modify the title, ingredients, instructions, add notes, change the source information, and customize the card design. All edits sync across your devices.",
                section: .recipes
            ),
            FAQItem(
                question: "How do I mark recipes as favorites?",
                answer: "Tap the heart icon when viewing a recipe to mark it as a favorite. Favorites appear at the top of your recipe list and can be filtered in the Filters menu. This helps you quickly access your most-loved recipes.",
                section: .recipes
            ),

            // MARK: Shopping Lists
            FAQItem(
                question: "How does ingredient aggregation work?",
                answer: "When adding multiple recipes to a shopping list, Heirloom automatically combines identical ingredients. For example, if three recipes need milk, the app adds up the quantities and shows one combined entry like '3 cups milk' instead of three separate items.",
                section: .shoppingLists
            ),
            FAQItem(
                question: "Can I organize my shopping list by grocery store aisle?",
                answer: "Yes! Ingredients are automatically categorized into sections like Produce, Dairy, Meat, Bakery, Pantry, and more. You can customize these categories in Settings to match your preferred grocery store layout.",
                section: .shoppingLists
            ),
            FAQItem(
                question: "How do I export my shopping list to Apple Reminders?",
                answer: "Tap 'Export to Reminders' at the bottom of your shopping list. This creates a new reminder list with each ingredient as a separate item. You can then access it on Apple Watch, ask Siri, or share with family members through shared reminder lists.",
                section: .shoppingLists
            ),
            FAQItem(
                question: "Can I add non-recipe items to my shopping list?",
                answer: "Yes! Tap 'Add Custom Item' at the bottom of your shopping list to add household items, specialty ingredients, or anything else you need. Custom items will be categorized automatically based on common grocery patterns.",
                section: .shoppingLists
            ),

            // MARK: Card Personalization
            FAQItem(
                question: "How do I customize my recipe cards?",
                answer: "Tap 'Edit Card' when viewing a recipe to access customization options. You can choose backgrounds (colors, gradients, patterns, textures), add stickers, write annotations, and apply love marks. Each recipe card can have a unique design reflecting its personality.",
                section: .cardPersonalization
            ),
            FAQItem(
                question: "What are love marks and how do they appear?",
                answer: "Love marks are authentic weathering effects like coffee stains, splatter marks, and worn edges that appear automatically as you cook a recipe more often. Cook 5+ times for small stains, 10+ for more marks, 20+ for a well-loved look, and 50+ times for a vintage appearance.",
                section: .cardPersonalization
            ),
            FAQItem(
                question: "Can I add my own notes to recipe cards?",
                answer: "Yes! Use the Annotations feature to add handwritten-style notes anywhere on your recipe card. These are perfect for recording cooking memories, ingredient substitutions, timing notes, or family stories. Notes sync across devices and stay with the recipe.",
                section: .cardPersonalization
            ),
            FAQItem(
                question: "How do I flip a recipe card to see the back?",
                answer: "Swipe left or right on a recipe card, or tap the flip button in the corner. The back of the card can hold additional notes, ingredient substitutions, cooking tips, or family history. Both sides are fully customizable.",
                section: .cardPersonalization
            ),

            // MARK: Advanced Features
            FAQItem(
                question: "How does smart recipe scaling work?",
                answer: "When you scale a recipe, Heirloom uses intelligent algorithms to adjust ingredients appropriately. Most ingredients scale linearly, but spices scale at 66%, leavening agents at 75%, and liquids at 90% to maintain proper flavor balance and cooking chemistry.",
                section: .advancedFeatures
            ),
            FAQItem(
                question: "Why isn't my recipe syncing to my other devices?",
                answer: "Check these common issues: 1) Ensure iCloud Drive is enabled on all devices, 2) Verify you're signed in with the same Apple ID, 3) Check your internet connection, 4) Go to Settings → Network & Sync to see sync status and error details, 5) Try toggling iCloud sync off and back on.",
                section: .advancedFeatures
            ),
            FAQItem(
                question: "What's the best way to share recipes with family?",
                answer: "You have multiple sharing options: 1) Share as a beautiful recipe card image (great for social media), 2) Export as PDF for printing, 3) Send as a Heirloom recipe file for other Heirloom users to import, 4) Share just the text via Messages or email. Choose the format that works best for your recipient.",
                section: .advancedFeatures
            )
        ]
    }

    /// Search FAQ items
    func searchFAQ(_ query: String) -> [FAQItem] {
        guard !query.isEmpty else { return [] }
        let lowercaseQuery = query.lowercased()

        return faqItems.filter {
            $0.question.lowercased().contains(lowercaseQuery) ||
            $0.answer.lowercased().contains(lowercaseQuery)
        }
    }
}
