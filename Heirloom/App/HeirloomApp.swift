import SwiftUI
import SwiftData
import UserNotifications

@main
struct HeirloomApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var showDataError = false

    init() {
        do {
            // Use versioned schema for future migrations
            let schema = SchemaV1.schema

            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .automatic  // iCloud sync enabled
            )

            let container = try ModelContainer(
                for: schema,
                configurations: config
            )

            _modelContainer = State(wrappedValue: container)

            // Initialize services
            setupServices()

        } catch {
            print("⚠️ Failed to configure SwiftData: \(error.localizedDescription)")
            _showDataError = State(wrappedValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView()
                    .modelContainer(modelContainer)
            } else {
                DataErrorView()
            }
        }
    }

    private func setupServices() {
        // Initialize image storage (in background task since it's an actor)
        Task {
            await ImageStorageService.shared.performCleanup()
        }

        // Initialize analytics
        Task { @MainActor in
            AnalyticsService.shared.initialize()
            AnalyticsService.shared.track(event: .appLaunched)
        }

        // Request notification permissions for cooking timers
        Task {
            await requestNotificationPermission()
        }

        // Clean up old broken recipe data (one-time migration)
        if let container = modelContainer {
            cleanupOldRecipeData(container: container)
        }
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }

    private func cleanupOldRecipeData(container: ModelContainer) {
        let hasCleanedKey = "hasCleanedBrokenRecipeData_v4"  // v4: Parsed ingredients + proper math

        // Only run once
        guard !UserDefaults.standard.bool(forKey: hasCleanedKey) else {
            return
        }

        Task { @MainActor in
            let context = container.mainContext

            // Delete all existing recipes (they don't have proper ingredients)
            let fetchDescriptor = FetchDescriptor<Recipe>()
            if let oldRecipes = try? context.fetch(fetchDescriptor) {
                print("🧹 Cleaning up \(oldRecipes.count) old recipe(s) with broken data...")
                for recipe in oldRecipes {
                    context.delete(recipe)
                }
                try? context.save()
            }

            // Add a fresh sample recipe with proper ingredients using parser
            let sampleData = SampleRecipeLibrary.chocolateChipCookies
            let recipe = sampleData.recipe
            context.insert(recipe)

            var ingredients: [Ingredient] = []
            for (index, text) in sampleData.ingredients.enumerated() {
                // Parse the ingredient text
                let parsed = IngredientParser.parse(text)

                let ingredient = Ingredient(
                    originalText: text,
                    name: parsed.name,
                    quantity: parsed.quantity,
                    unit: parsed.unit,
                    orderIndex: index
                )
                ingredient.quantityMax = parsed.quantityMax
                ingredient.recipe = recipe
                context.insert(ingredient)
                ingredients.append(ingredient)
            }

            recipe.ingredients = ingredients

            do {
                try context.save()
                print("✅ Fresh sample recipe added with \(ingredients.count) ingredients")
                UserDefaults.standard.set(true, forKey: hasCleanedKey)
            } catch {
                print("❌ Failed to save sample recipe: \(error)")
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddRecipe = false

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }
                .tag(0)

            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(1)

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(HeirloomColors.tomato)
        .toastContainer()
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                showAddRecipe = true
                selectedTab = oldValue
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            RecipeEditorView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
