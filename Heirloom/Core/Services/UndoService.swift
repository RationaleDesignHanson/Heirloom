import Foundation
import SwiftData

// MARK: - Undo Service
/// Service for managing undo functionality for destructive actions
/// Provides temporary storage and restore capabilities for deleted items
@MainActor
class UndoService: ObservableObject {
    static let shared = UndoService()

    /// Default undo window duration (5 seconds)
    static let defaultUndoWindow: TimeInterval = 5.0

    // MARK: - Undo Item
    struct UndoItem: Identifiable {
        let id = UUID()
        let recipe: Recipe
        let expirationDate: Date
        let description: String

        var isExpired: Bool {
            Date() > expirationDate
        }
    }

    // MARK: - Published State
    @Published private(set) var pendingUndos: [UndoItem] = []

    // Store model context reference
    private var modelContext: ModelContext?

    private init() {}

    // MARK: - Configuration
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Delete with Undo
    /// Soft-delete a recipe with undo capability
    /// - Parameters:
    ///   - recipe: The recipe to delete
    ///   - context: The SwiftData model context
    ///   - undoWindow: Duration for undo window (default: 5 seconds)
    func deleteRecipe(
        _ recipe: Recipe,
        context: ModelContext,
        undoWindow: TimeInterval = defaultUndoWindow
    ) {
        // Store recipe data for potential undo
        let undoItem = UndoItem(
            recipe: recipe,
            expirationDate: Date().addingTimeInterval(undoWindow),
            description: recipe.title
        )

        // Remove from SwiftData
        context.delete(recipe)
        try? context.save()

        // Add to pending undos
        pendingUndos.append(undoItem)

        // Schedule permanent deletion after undo window expires
        Task {
            try? await Task.sleep(nanoseconds: UInt64(undoWindow * 1_000_000_000))
            await self.expireUndoItem(undoItem)
        }

        // Analytics
        AnalyticsService.shared.track(event: .recipeDeleted, properties: [
            "Recipe Title": recipe.title,
            "Undo Available": true
        ])
    }

    // MARK: - Undo
    /// Restore a deleted recipe
    /// - Parameter undoItem: The undo item to restore
    func undoDelete(_ undoItem: UndoItem) {
        guard let context = modelContext else {
            Log.warning("UndoService: No model context configured", category: .database)
            return
        }

        // Remove from pending undos
        pendingUndos.removeAll { $0.id == undoItem.id }

        // Re-insert into SwiftData
        context.insert(undoItem.recipe)
        try? context.save()

        // Re-upload to Firebase if active
        if BackendConfig.shared.isFirebaseActive {
            Task {
                do {
                    try await FirebaseSyncService.shared.uploadRecipe(undoItem.recipe)
                    Log.info("Recipe restored to Firebase", category: .firebase, metadata: ["title": undoItem.recipe.title])
                } catch {
                    Log.warning("Failed to restore recipe to Firebase", category: .firebase, metadata: ["error": error.localizedDescription])
                }
            }
        }

        // Analytics
        AnalyticsService.shared.track(event: .featureUsed, properties: [
            "feature": "undo_delete",
            "recipe_title": undoItem.recipe.title
        ])

        Log.info("Recipe restored locally", category: .database, metadata: ["title": undoItem.recipe.title])
    }

    // MARK: - Expiration
    /// Remove expired undo item (permanent deletion)
    private func expireUndoItem(_ undoItem: UndoItem) {
        // Only remove if still pending and expired
        if let index = pendingUndos.firstIndex(where: { $0.id == undoItem.id }),
           pendingUndos[index].isExpired {
            pendingUndos.remove(at: index)
            Log.info("Permanently deleted expired recipe", category: .database, metadata: ["description": undoItem.description])
        }
    }

    // MARK: - Clear All
    /// Clear all pending undos (useful for cleanup)
    func clearAll() {
        pendingUndos.removeAll()
    }

    // MARK: - Has Pending Undos
    var hasPendingUndos: Bool {
        !pendingUndos.isEmpty
    }
}

// MARK: - Toast Manager Extension
extension ToastManager {
    /// Show undo toast for recipe deletion
    /// - Parameters:
    ///   - undoItem: The undo item
    ///   - onUndo: Closure to execute when undo is tapped
    func showUndoToast(for undoItem: UndoService.UndoItem, onUndo: @escaping () -> Void) {
        // Note: Current Toast system doesn't support action buttons
        // Show a simple info toast instead
        // TODO: Enhance Toast to support undo action buttons
        info(
            title: "Recipe Deleted",
            message: undoItem.description
        )
    }
}
