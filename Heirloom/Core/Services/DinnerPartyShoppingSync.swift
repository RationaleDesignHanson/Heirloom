//
//  DinnerPartyShoppingSync.swift
//  Heirloom
//
//  Service for automatically syncing dinner party recipes to shopping cart
//  Eliminates the need for manual "Add All to Shopping List" approval
//

import Foundation
import SwiftData

@MainActor
final class DinnerPartyShoppingSync {

    // MARK: - Main Sync Method

    /// Syncs all recipes from a dinner party to the shopping cart
    /// - Parameters:
    ///   - dinnerParty: The dinner party to sync
    ///   - context: SwiftData ModelContext for database operations
    func syncRecipesToShoppingCart(_ dinnerParty: DinnerParty, context: ModelContext) {
        guard let partyRecipes = dinnerParty.recipes, !partyRecipes.isEmpty else {
            print("⚠️ No recipes in dinner party to sync")
            return
        }

        print("🔄 Syncing \(partyRecipes.count) recipes from dinner party '\(dinnerParty.name)' to shopping cart")

        for partyRecipe in partyRecipes {
            guard let recipe = partyRecipe.recipe else {
                print("⚠️ Skipping party recipe with missing recipe reference")
                continue
            }

            syncSingleRecipe(
                recipe: recipe,
                partyRecipe: partyRecipe,
                dinnerParty: dinnerParty,
                context: context
            )
        }

        print("✅ Shopping cart sync complete for '\(dinnerParty.name)'")
    }

    // MARK: - Single Recipe Sync

    private func syncSingleRecipe(
        recipe: Recipe,
        partyRecipe: DinnerPartyRecipe,
        dinnerParty: DinnerParty,
        context: ModelContext
    ) {
        // Calculate target servings from scaling factor
        let originalServings = recipe.parsedServingCount
        let targetServings = Int(Double(originalServings) * partyRecipe.scalingFactor)

        // Check if recipe already exists in shopping cart
        if let existingCartRecipe = recipe.shoppingCartRecipe(context: context) {
            handleExistingCartRecipe(
                existingCartRecipe,
                recipe: recipe,
                dinnerParty: dinnerParty,
                targetServings: targetServings,
                partyRecipeId: partyRecipe.id
            )
        } else {
            createNewCartRecipe(
                recipe: recipe,
                dinnerParty: dinnerParty,
                targetServings: targetServings,
                partyRecipeId: partyRecipe.id,
                context: context
            )
        }
    }

    private func handleExistingCartRecipe(
        _ cartRecipe: ShoppingCartRecipe,
        recipe: Recipe,
        dinnerParty: DinnerParty,
        targetServings: Int,
        partyRecipeId: UUID
    ) {
        // Check if this dinner party is already tracked
        if cartRecipe.dinnerPartyIds.contains(dinnerParty.id) {
            // Same party - update servings
            print("📝 Updating servings for '\(recipe.title)' from '\(dinnerParty.name)'")
            cartRecipe.targetServings = targetServings
            cartRecipe.dinnerPartyRecipeId = partyRecipeId
        } else {
            // Different party or manually added - add party ID and use max servings
            print("📝 Adding '\(dinnerParty.name)' to '\(recipe.title)' (max servings: \(max(cartRecipe.targetServings, targetServings)))")
            cartRecipe.dinnerPartyIds.append(dinnerParty.id)
            cartRecipe.targetServings = max(cartRecipe.targetServings, targetServings)
            // Note: Keep existing dinnerPartyRecipeId as it points to the primary party
        }
    }

    private func createNewCartRecipe(
        recipe: Recipe,
        dinnerParty: DinnerParty,
        targetServings: Int,
        partyRecipeId: UUID,
        context: ModelContext
    ) {
        print("✨ Adding '\(recipe.title)' to shopping cart (\(targetServings) servings)")
        let cartRecipe = ShoppingCartRecipe(recipe: recipe, targetServings: targetServings)
        cartRecipe.dinnerPartyIds = [dinnerParty.id]
        cartRecipe.dinnerPartyRecipeId = partyRecipeId
        context.insert(cartRecipe)
        recipe.isInShoppingList = true
    }

    // MARK: - Guest Count Update

    /// Updates shopping cart servings when dinner party guest count changes
    /// - Parameters:
    ///   - dinnerParty: The dinner party that was modified
    ///   - context: SwiftData ModelContext
    func updateTargetServings(_ dinnerParty: DinnerParty, context: ModelContext) {
        guard let partyRecipes = dinnerParty.recipes, !partyRecipes.isEmpty else { return }

        print("🔄 Updating shopping cart servings for '\(dinnerParty.name)' (guests: \(dinnerParty.guestCount))")

        for partyRecipe in partyRecipes {
            guard let recipe = partyRecipe.recipe,
                  let cartRecipe = recipe.shoppingCartRecipe(context: context) else {
                continue
            }

            // Calculate new target servings
            let originalServings = recipe.parsedServingCount
            let newTargetServings = Int(Double(originalServings) * partyRecipe.scalingFactor)

            if cartRecipe.dinnerPartyIds.count == 1 && cartRecipe.dinnerPartyIds.contains(dinnerParty.id) {
                // Only in this party - update directly
                cartRecipe.targetServings = newTargetServings
                print("📝 Updated '\(recipe.title)' to \(newTargetServings) servings")
            } else if cartRecipe.dinnerPartyIds.contains(dinnerParty.id) {
                // In multiple parties - recalculate max
                recalculateMaxServings(cartRecipe: cartRecipe, context: context)
            }
        }
    }

    private func recalculateMaxServings(cartRecipe: ShoppingCartRecipe, context: ModelContext) {
        guard let recipe = cartRecipe.recipe else { return }

        var maxServings = 0

        // Find max servings across all dinner parties
        for partyId in cartRecipe.dinnerPartyIds {
            if let servings = findServingsForParty(recipe: recipe, partyId: partyId, context: context) {
                maxServings = max(maxServings, servings)
            }
        }

        if maxServings > 0 {
            cartRecipe.targetServings = maxServings
            print("📝 Recalculated max servings for '\(recipe.title)': \(maxServings)")
        }
    }

    private func findServingsForParty(recipe: Recipe, partyId: UUID, context: ModelContext) -> Int? {
        // Fetch the dinner party
        let partyDescriptor = FetchDescriptor<DinnerParty>(
            predicate: #Predicate { $0.id == partyId }
        )
        guard let party = try? context.fetch(partyDescriptor).first,
              let partyRecipes = party.recipes else {
            return nil
        }

        // Find the DinnerPartyRecipe for this recipe
        guard let partyRecipe = partyRecipes.first(where: { $0.recipe?.id == recipe.id }) else {
            return nil
        }

        // Calculate servings
        let originalServings = recipe.parsedServingCount
        return Int(Double(originalServings) * partyRecipe.scalingFactor)
    }

    // MARK: - Recipe Removal

    /// Handles recipe removal from dinner party with user confirmation
    /// - Parameters:
    ///   - recipe: The recipe being removed
    ///   - dinnerParty: The dinner party it's being removed from
    ///   - context: SwiftData ModelContext
    ///   - completion: Callback with boolean indicating if user wants to remove from shopping list
    func handleRecipeRemoval(
        recipe: Recipe,
        dinnerParty: DinnerParty,
        context: ModelContext,
        completion: @escaping (Bool) -> Void
    ) {
        guard let cartRecipe = recipe.shoppingCartRecipe(context: context),
              cartRecipe.dinnerPartyIds.contains(dinnerParty.id) else {
            // Not in shopping cart or not from this party - no action needed
            completion(false)
            return
        }

        // Check if recipe is in other parties
        let isInOtherParties = cartRecipe.dinnerPartyIds.count > 1

        if isInOtherParties {
            // Remove this party's ID but keep recipe in cart
            removePartyFromCartRecipe(cartRecipe, partyId: dinnerParty.id, context: context)
            completion(false)
        } else {
            // Only in this party - ask user
            // The calling view should show a confirmation dialog
            // For now, return true to indicate confirmation is needed
            completion(true)
        }
    }

    /// Removes a recipe from shopping cart (called after user confirmation)
    func removeRecipeFromShoppingCart(recipe: Recipe, context: ModelContext) {
        guard let cartRecipe = recipe.shoppingCartRecipe(context: context) else { return }
        print("🗑 Removing '\(recipe.title)' from shopping cart")
        context.delete(cartRecipe)
        recipe.isInShoppingList = false
    }

    private func removePartyFromCartRecipe(_ cartRecipe: ShoppingCartRecipe, partyId: UUID, context: ModelContext) {
        cartRecipe.dinnerPartyIds.removeAll { $0 == partyId }
        print("📝 Removed party tracking from '\(cartRecipe.recipe?.title ?? "recipe")'")

        // Recalculate max servings from remaining parties
        if !cartRecipe.dinnerPartyIds.isEmpty {
            recalculateMaxServings(cartRecipe: cartRecipe, context: context)
        }
    }

    // MARK: - Dinner Party Cleanup

    /// Cleans up shopping cart when dinner party is deleted
    /// - Parameters:
    ///   - dinnerParty: The dinner party being deleted
    ///   - context: SwiftData ModelContext
    func cleanupShoppingCart(_ dinnerParty: DinnerParty, context: ModelContext) {
        guard let partyRecipes = dinnerParty.recipes else { return }

        print("🧹 Cleaning up shopping cart for deleted party '\(dinnerParty.name)'")

        for partyRecipe in partyRecipes {
            guard let recipe = partyRecipe.recipe,
                  let cartRecipe = recipe.shoppingCartRecipe(context: context) else {
                continue
            }

            if cartRecipe.dinnerPartyIds.count == 1 && cartRecipe.dinnerPartyIds.contains(dinnerParty.id) {
                // Only in this party - remove from cart
                print("🗑 Removing '\(recipe.title)' from shopping cart")
                context.delete(cartRecipe)
                recipe.isInShoppingList = false
            } else if cartRecipe.dinnerPartyIds.contains(dinnerParty.id) {
                // In multiple parties - just remove this party's ID
                removePartyFromCartRecipe(cartRecipe, partyId: dinnerParty.id, context: context)
            }
        }
    }

    // MARK: - Migration

    /// One-time migration to sync existing dinner parties to shopping cart
    /// - Parameter context: SwiftData ModelContext
    func migrateExistingDinnerParties(context: ModelContext) {
        let descriptor = FetchDescriptor<DinnerParty>()
        guard let allParties = try? context.fetch(descriptor) else {
            print("⚠️ Failed to fetch dinner parties for migration")
            return
        }

        print("🔄 Migrating \(allParties.count) existing dinner parties to shopping cart")

        for party in allParties {
            syncRecipesToShoppingCart(party, context: context)
        }

        print("✅ Migration complete")
    }
}
