//
//  CollectionRouter+IntegrationGuide.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//
//  Integration guide for CollectionRouter
//

import Foundation
import SwiftData

/*

 ## CollectionRouter Integration Guide

 The CollectionRouter automatically routes recipes to appropriate collections based on their source.

 ### How to Use

 1. Create a router instance with your ModelContext:
 ```swift
 let router = CollectionRouter(modelContext: modelContext)
 ```

 2. After inserting a recipe into SwiftData, route it based on its source:

 ### URL Import Example:
 ```swift
 func importFromURL(_ url: URL) async throws -> Recipe {
     // Parse recipe (existing logic)
     let importedRecipe = try await scrapeRecipe(from: url)

     // Convert to Recipe model and insert
     let recipe = Recipe(title: importedRecipe.title, ...)
     modelContext.insert(recipe)

     // Route to "My Imports" collection
     let router = CollectionRouter(modelContext: modelContext)
     router.routeURLImport(recipe, sourceURL: url)

     return recipe
 }
 ```

 ### Shared Recipe Example:
 ```swift
 func handleIncomingShare(_ shareData: ShareData) async throws -> Recipe {
     // Parse shared recipe (existing logic)
     let recipe = try parseSharedRecipe(shareData)

     // Insert into context
     modelContext.insert(recipe)

     // Route to "From Friends" collection
     let router = CollectionRouter(modelContext: modelContext)
     router.routeSharedRecipe(recipe, from: shareData.senderName)

     return recipe
 }
 ```

 ### Cookbook Import Example:
 ```swift
 func importCookbook(_ file: URL) async throws -> [Recipe] {
     // Parse cookbook (existing logic)
     let result = try await parseCookbook(file)
     let recipes = result.recipes
     let cookbookName = result.title ?? file.lastPathComponent

     // Insert recipes
     for recipe in recipes {
         modelContext.insert(recipe)
     }

     // Route all recipes to cookbook collection
     let router = CollectionRouter(modelContext: modelContext)
     router.routeCookbookImport(recipes, cookbookName: cookbookName)

     return recipes
 }
 ```

 ### Theme Recipe Download Example:
 ```swift
 func downloadRecipes(for theme: RecipeTheme, upToDay: Int) async throws -> [Recipe] {
     // Fetch from Firebase (existing logic)
     let recipes = try await fetchThemeRecipes(theme: theme, day: upToDay)

     // Insert recipes
     for recipe in recipes {
         modelContext.insert(recipe)
     }

     // Route to theme collection
     let router = CollectionRouter(modelContext: modelContext)
     for recipe in recipes {
         router.routeThemeRecipe(recipe, to: theme)
     }

     return recipes
 }
 ```

 ### Key Benefits:
 - Automatic collection creation (no need to manually check if collection exists)
 - Prevents duplicate collections
 - Sets appropriate metadata (sharedBy, sourceURL, sourceCookbook)
 - Consistent routing logic across all import types
 - Collections are visible immediately in CollectionsListView

 ### TODO: Integration Points
 The following files should integrate CollectionRouter when convenient:
 - RecipeImportView.swift (URL imports)
 - FirebaseShareService.swift (shared recipes)
 - CookbookImportService.swift / PDFImportView.swift (cookbook imports)
 - ThemeRecipeService.swift (when created - theme recipe downloads)

 */
