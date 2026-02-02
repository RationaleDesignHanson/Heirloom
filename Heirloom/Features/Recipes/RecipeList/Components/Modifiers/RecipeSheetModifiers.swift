//
//  RecipeSheetModifiers.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI
import SwiftData

/// ViewModifier that handles all sheet and dialog presentations for RecipeListView
/// Encapsulates: add recipe, import, bulk import, cookbook scanner, collection editor, filters, delete confirmations, collection picker, conflict resolution
struct RecipeSheetModifiers: ViewModifier {
    @Binding var showRecipeGenerator: Bool
    @Binding var showImportRecipe: Bool
    @Binding var showBulkImport: Bool
    @Binding var showCookbookScanner: Bool
    @Binding var showVideoImport: Bool
    @Binding var showCreateCollection: Bool
    @Binding var showFilters: Bool
    @Binding var filters: RecipeFilters
    @Binding var showDeleteConfirmation: Bool
    let recipeToDelete: Recipe?
    let onDeleteRecipe: (Recipe) -> Void
    @Binding var showBatchDeleteConfirmation: Bool
    let selectedRecipeIds: Set<UUID>
    let onBatchDelete: () -> Void
    @Binding var showCollectionPicker: Bool
    let onExitSelection: () -> Void
    @Binding var recipeForCollectionPicker: Recipe?
    @Binding var showConflictResolution: Bool
    let conflictResolutionSheet: AnyView

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showRecipeGenerator) {
                RecipeGeneratorView(
                    generator: ServiceContainer.shared.resolve(AIRecipeGeneratorProtocol.self),
                    imageGenerator: ServiceContainer.shared.resolve(RecipeImageGeneratorProtocol.self)
                )
            }
            .sheet(isPresented: $showImportRecipe) {
                RecipeImportView()
            }
            .sheet(isPresented: $showBulkImport) {
                BulkImportView()
            }
            .sheet(isPresented: $showCookbookScanner) {
                CookbookScannerView()
            }
            .sheet(isPresented: $showVideoImport) {
                UnifiedVideoImportView()
            }
            .sheet(isPresented: $showCreateCollection) {
                CollectionEditorView()
            }
            .sheet(isPresented: $showFilters) {
                RecipeFiltersView(filters: $filters)
            }
            .confirmationDialog(
                "Delete Recipe?",
                isPresented: $showDeleteConfirmation,
                presenting: recipeToDelete
            ) { recipe in
                Button("Delete", role: .destructive) {
                    onDeleteRecipe(recipe)
                }
                Button("Cancel", role: .cancel) {}
            } message: { recipe in
                Text("Are you sure you want to delete \"\(recipe.title)\"? You can undo this action within 5 seconds.")
            }
            .confirmationDialog(
                "Delete \(selectedRecipeIds.count) Recipes?",
                isPresented: $showBatchDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete \(selectedRecipeIds.count) Recipes", role: .destructive) {
                    onBatchDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete \(selectedRecipeIds.count) selected recipes? You can undo this action within 5 seconds.")
            }
            .sheet(isPresented: $showCollectionPicker) {
                BatchTagCollectionPickerView(
                    selectedRecipeIds: selectedRecipeIds,
                    onComplete: {
                        onExitSelection()
                    }
                )
            }
            .sheet(item: $recipeForCollectionPicker) { recipe in
                TagCollectionPickerView(recipe: recipe)
            }
            .sheet(isPresented: $showConflictResolution) {
                conflictResolutionSheet
            }
    }
}
