# Heirloom Collections Overhaul
## Phase C1: Collection Routing

**Branch:** `feature/collections-C1-routing`
**Estimated Time:** 45-60 minutes
**Dependencies:** Phase A1 complete (CollectionType enum)

---

## Objective

Implement automatic routing of recipes to appropriate collections based on their source: shared recipes go to "From Friends", URL imports go to "My Imports", and cookbook imports inherit the cookbook name.

---

## Task C1.1: Create Collection Router Service

**New File:** `Heirloom/Core/Services/Collections/CollectionRouter.swift`

```swift
//
//  CollectionRouter.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData

/// Routes recipes to appropriate collections based on their source
@MainActor
class CollectionRouter {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Public Routing Methods
    
    /// Route a recipe shared by a friend
    func routeSharedRecipe(_ recipe: Recipe, from senderName: String?) {
        let collection = findOrCreateCollection(
            name: "From Friends",
            type: .fromFriends,
            iconName: "person.2.fill"
        )
        
        // Set sharing metadata
        recipe.sharedBy = senderName
        recipe.sharedAt = Date()
        
        // Add to collection
        addRecipeToCollection(recipe, collection: collection)
        
        Log.info("Routed shared recipe to From Friends", category: .collections, metadata: [
            "recipe": recipe.title,
            "from": senderName ?? "unknown"
        ])
    }
    
    /// Route a recipe imported from a URL
    func routeURLImport(_ recipe: Recipe, sourceURL: URL) {
        let collection = findOrCreateCollection(
            name: "My Imports",
            type: .imports,
            iconName: "square.and.arrow.down.fill"
        )
        
        // Set source metadata
        recipe.sourceURL = sourceURL.absoluteString
        
        // Add to collection
        addRecipeToCollection(recipe, collection: collection)
        
        Log.info("Routed URL import to My Imports", category: .collections, metadata: [
            "recipe": recipe.title,
            "source": sourceURL.host ?? "unknown"
        ])
    }
    
    /// Route recipes imported from a cookbook
    func routeCookbookImport(_ recipes: [Recipe], cookbookName: String) {
        // Clean up cookbook name
        let cleanName = cleanCookbookName(cookbookName)
        
        let collection = findOrCreateCollection(
            name: cleanName,
            type: .cookbook,
            iconName: "book.closed.fill"
        )
        
        collection.sourceCookbook = cookbookName
        
        for recipe in recipes {
            recipe.sourceCookbook = cookbookName
            addRecipeToCollection(recipe, collection: collection)
        }
        
        Log.info("Routed \(recipes.count) recipes to cookbook collection", category: .collections, metadata: [
            "cookbook": cleanName,
            "count": String(recipes.count)
        ])
    }
    
    /// Route a curated theme recipe
    func routeThemeRecipe(_ recipe: Recipe, to theme: RecipeTheme) {
        guard let collection = theme.collection else {
            Log.warning("Theme has no collection, creating one", category: .collections)
            let newCollection = RecipeCollection(name: theme.name, iconName: theme.iconName)
            newCollection.collectionType = .theme
            newCollection.sourceTheme = theme
            theme.collection = newCollection
            modelContext.insert(newCollection)
            
            addRecipeToCollection(recipe, collection: newCollection)
            return
        }
        
        addRecipeToCollection(recipe, collection: collection)
    }
    
    // MARK: - Helper Methods
    
    /// Find existing collection or create new one
    func findOrCreateCollection(
        name: String,
        type: CollectionType,
        iconName: String
    ) -> RecipeCollection {
        // Try to find existing
        let descriptor = FetchDescriptor<RecipeCollection>(
            predicate: #Predicate { collection in
                collection.name == name && collection.collectionType == type
            }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        // Create new collection
        let collection = RecipeCollection(name: name, iconName: iconName)
        collection.collectionType = type
        collection.createdAt = Date()
        modelContext.insert(collection)
        
        Log.info("Created new collection", category: .collections, metadata: [
            "name": name,
            "type": type.rawValue
        ])
        
        return collection
    }
    
    /// Add recipe to collection if not already present
    private func addRecipeToCollection(_ recipe: Recipe, collection: RecipeCollection) {
        // Initialize collections array if needed
        if recipe.collections == nil {
            recipe.collections = []
        }
        
        // Check if already in collection
        let alreadyInCollection = recipe.collections?.contains(where: { $0.id == collection.id }) ?? false
        
        if !alreadyInCollection {
            recipe.collections?.append(collection)
        }
        
        try? modelContext.save()
    }
    
    /// Clean up cookbook name for display
    private func cleanCookbookName(_ name: String) -> String {
        var clean = name
        
        // Remove file extensions
        let extensions = [".pdf", ".epub", ".mobi"]
        for ext in extensions {
            if clean.lowercased().hasSuffix(ext) {
                clean = String(clean.dropLast(ext.count))
            }
        }
        
        // Remove common prefixes
        let prefixes = ["the ", "a "]
        for prefix in prefixes {
            if clean.lowercased().hasPrefix(prefix) {
                clean = String(clean.dropFirst(prefix.count))
            }
        }
        
        // Capitalize first letter
        if let first = clean.first {
            clean = first.uppercased() + clean.dropFirst()
        }
        
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Log Category

extension Log.Category {
    static let collections = Log.Category("collections")
}
```

---

## Task C1.2: Integrate with Share Handling

**File:** Find your share handling code (likely in `RecipeShareService.swift` or similar)

```swift
// Update share handling to use router

class RecipeShareService {
    private let modelContext: ModelContext
    private lazy var router = CollectionRouter(modelContext: modelContext)
    
    func handleIncomingShare(_ shareData: ShareData) async throws -> Recipe {
        // Parse the shared recipe
        let recipe = try await parseSharedRecipe(shareData)
        
        // Insert into context
        modelContext.insert(recipe)
        
        // Route to From Friends collection
        router.routeSharedRecipe(recipe, from: shareData.senderName)
        
        return recipe
    }
}
```

---

## Task C1.3: Integrate with URL Import

**File:** Find your URL import handling code

```swift
// Update URL import to use router

class RecipeImportService {
    private let modelContext: ModelContext
    private lazy var router = CollectionRouter(modelContext: modelContext)
    
    func importFromURL(_ url: URL) async throws -> Recipe {
        // Scrape/parse the recipe
        let recipe = try await scrapeRecipe(from: url)
        
        // Insert into context
        modelContext.insert(recipe)
        
        // Route to My Imports collection
        router.routeURLImport(recipe, sourceURL: url)
        
        return recipe
    }
}
```

---

## Task C1.4: Integrate with Cookbook Import

**File:** Find your cookbook/PDF import handling code

```swift
// Update cookbook import to use router

class CookbookImportService {
    private let modelContext: ModelContext
    private lazy var router = CollectionRouter(modelContext: modelContext)
    
    func importCookbook(_ file: URL) async throws -> [Recipe] {
        // Parse the cookbook
        let result = try await parseCookbook(file)
        let recipes = result.recipes
        let cookbookName = result.title ?? file.lastPathComponent
        
        // Insert recipes into context
        for recipe in recipes {
            modelContext.insert(recipe)
        }
        
        // Route all recipes to cookbook collection
        router.routeCookbookImport(recipes, cookbookName: cookbookName)
        
        return recipes
    }
}
```

---

## Task C1.5: Update Theme Recipe Download

**File:** `Heirloom/Core/Services/Themes/ThemeRecipeService.swift`

```swift
class ThemeRecipeService {
    private let modelContext: ModelContext
    private let firestore: Firestore
    private lazy var router = CollectionRouter(modelContext: modelContext)
    
    func downloadRecipes(
        for theme: RecipeTheme,
        upToDay: Int,
        context: ModelContext
    ) async throws -> [Recipe] {
        // Fetch from Firebase
        let query = firestore
            .collection("themes")
            .document(theme.firebaseId)
            .collection("recipes")
            .whereField("unlockDay", isLessThanOrEqualTo: upToDay)
            .order(by: "sortOrder")
        
        let snapshot = try await query.getDocuments()
        
        var recipes: [Recipe] = []
        
        for document in snapshot.documents {
            // Check if already downloaded
            let recipeId = document.documentID
            let descriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate { $0.firebaseId == recipeId }
            )
            
            if let existing = try? context.fetch(descriptor).first {
                recipes.append(existing)
                continue
            }
            
            // Parse and create new recipe
            let recipe = try parseRecipe(from: document)
            recipe.isCurated = true
            recipe.sourceThemeId = theme.firebaseId
            
            context.insert(recipe)
            
            // Route to theme collection
            router.routeThemeRecipe(recipe, to: theme)
            
            recipes.append(recipe)
        }
        
        try context.save()
        return recipes
    }
    
    private func parseRecipe(from document: QueryDocumentSnapshot) throws -> Recipe {
        let data = document.data()
        
        let recipe = Recipe(
            title: data["title"] as? String ?? "Untitled",
            ingredients: data["ingredients"] as? [String] ?? [],
            instructions: data["instructions"] as? [String] ?? []
        )
        
        recipe.firebaseId = document.documentID
        recipe.recipeDescription = data["description"] as? String
        recipe.prepTime = data["prepTime"] as? Int
        recipe.cookTime = data["cookTime"] as? Int
        recipe.servings = data["servings"] as? Int
        recipe.imageURL = data["imageURL"] as? String
        recipe.sourceAttribution = data["source"] as? String
        recipe.story = data["story"] as? String
        recipe.unlockDay = data["unlockDay"] as? Int
        
        return recipe
    }
}
```

---

## Task C1.6: Add firebaseId to Recipe Model

**File:** `Heirloom/Core/Models/Recipe.swift`

```swift
// Add to Recipe model if not present
var firebaseId: String?
```

---

## Verification Checklist

- [ ] CollectionRouter compiles
- [ ] Shared recipes route to "From Friends"
- [ ] URL imports route to "My Imports"
- [ ] Cookbook imports create named collection
- [ ] Theme recipes route to theme collection
- [ ] Collections auto-create when needed
- [ ] No duplicate collections created
- [ ] Recipe metadata (sharedBy, sourceURL, etc.) set correctly
- [ ] `xcodebuild` succeeds

---

## Test Scenarios

1. **Share Flow:**
   - Receive shared recipe
   - Verify "From Friends" collection created
   - Verify recipe in collection with `sharedBy` set

2. **URL Import Flow:**
   - Import recipe from URL
   - Verify "My Imports" collection created
   - Verify recipe in collection with `sourceURL` set

3. **Cookbook Flow:**
   - Import cookbook PDF
   - Verify collection created with cookbook name
   - Verify all recipes in collection

4. **Theme Flow:**
   - Select themes in onboarding
   - Verify theme collections created
   - Verify Day 1 recipes in correct collections

---

## Commit Message

```
feat(collections): Implement automatic collection routing

- Create CollectionRouter service
- Route shared recipes to "From Friends"
- Route URL imports to "My Imports"
- Route cookbook imports to named collections
- Route theme recipes to theme collections
- Auto-create collections as needed
- Add recipe metadata tracking (sharedBy, sourceURL, etc.)

Part of collections overhaul Phase C1
```

---

## Next Phase

→ **Phase D1:** Collections List Updates
