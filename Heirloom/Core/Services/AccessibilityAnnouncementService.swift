import Foundation
import UIKit

/// Service for posting accessibility announcements to VoiceOver
/// Provides consistent, descriptive announcements for key user actions and state changes
@MainActor
final class AccessibilityAnnouncementService {

    /// Shared singleton instance
    static let shared = AccessibilityAnnouncementService()

    private init() {}

    // MARK: - Core Announcement Method

    /// Post an announcement to VoiceOver
    /// - Parameters:
    ///   - message: The message to announce
    ///   - priority: Optional priority for the announcement (default: .announcement)
    func announce(_ message: String, priority: UIAccessibility.Notification = .announcement) {
        guard UIAccessibility.isVoiceOverRunning else { return }

        // Post announcement on next run loop to ensure it's not interrupted
        DispatchQueue.main.async {
            UIAccessibility.post(notification: priority, argument: message)
        }
    }

    // MARK: - Recipe Import Announcements

    func announceImportStarted() {
        announce("Importing recipe")
    }

    func announceImportSuccess(recipeTitle: String) {
        announce("Successfully imported \(recipeTitle)")
    }

    func announceImportFailed(error: String) {
        announce("Import failed: \(error)", priority: .announcement)
    }

    func announceMultiRecipeDetected(count: Int) {
        announce("Found \(count) recipes on this page")
    }

    func announceBulkImportProgress(current: Int, total: Int) {
        announce("Importing recipe \(current) of \(total)")
    }

    func announceBulkImportComplete(successCount: Int, totalCount: Int) {
        if successCount == totalCount {
            announce("Successfully imported all \(totalCount) recipes")
        } else {
            announce("Imported \(successCount) of \(totalCount) recipes")
        }
    }

    // MARK: - Shopping List Announcements

    func announceRecipeAddedToShoppingList(recipeTitle: String, servings: Int) {
        announce("\(recipeTitle) added to shopping list for \(servings) servings")
    }

    func announceRecipeRemovedFromShoppingList(recipeTitle: String) {
        announce("\(recipeTitle) removed from shopping list")
    }

    func announceShoppingListCleared() {
        announce("Shopping list cleared")
    }

    func announceAllItemsChecked() {
        announce("All items checked off")
    }

    func announceAllItemsUnchecked() {
        announce("All items unchecked")
    }

    func announceItemChecked(itemName: String) {
        announce("\(itemName) checked off")
    }

    func announceItemUnchecked(itemName: String) {
        announce("\(itemName) unchecked")
    }

    func announceExportToRemindersStarted() {
        announce("Exporting to Reminders")
    }

    func announceExportToRemindersSuccess(listName: String) {
        announce("Exported to \(listName) in Reminders")
    }

    func announceExportToRemindersFailed(error: String) {
        announce("Export failed: \(error)")
    }

    // MARK: - Recipe Save/Delete Announcements

    func announceRecipeSaved(title: String) {
        announce("\(title) saved")
    }

    func announceRecipeDeleted(title: String) {
        announce("\(title) deleted")
    }

    func announceRecipeRestored(title: String) {
        announce("\(title) restored")
    }

    func announceRecipeFavorited(title: String) {
        announce("\(title) added to favorites")
    }

    func announceRecipeUnfavorited(title: String) {
        announce("\(title) removed from favorites")
    }

    // MARK: - Scaling Announcements

    func announceScalingApplied(fromServings: Int, toServings: Int) {
        announce("Scaled from \(fromServings) to \(toServings) servings")
    }

    func announceScalingReset() {
        announce("Scaling reset to original servings")
    }

    func announceScalingWarning(message: String) {
        announce("Warning: \(message)")
    }

    // MARK: - Card Flip Announcements

    func announceCardFlipped(showingBack: Bool) {
        if showingBack {
            announce("Showing card back with personal notes and tips")
        } else {
            announce("Showing card front with recipe details")
        }
    }

    // MARK: - Card Personalization Announcements

    func announceBackgroundChanged(colorHex: String) {
        announce("Background color changed")
    }

    func announceStickerAdded(type: String) {
        announce("\(type) sticker added")
    }

    func announceStickerRemoved(type: String) {
        announce("\(type) sticker removed")
    }

    func announceAnnotationAdded() {
        announce("Note added")
    }

    func announceAnnotationUpdated() {
        announce("Note updated")
    }

    func announceAnnotationRemoved() {
        announce("Note removed")
    }

    func announceLoveMarkToggled(name: String, enabled: Bool) {
        announce("\(name) \(enabled ? "enabled" : "disabled")")
    }

    func announceCardStyleSaved() {
        announce("Card personalization saved")
    }

    // MARK: - Network Status Announcements

    func announceNetworkStatusChanged(isOnline: Bool) {
        if isOnline {
            announce("Back online")
        } else {
            announce("Offline. Changes will sync when connection is restored")
        }
    }

    func announceSyncStarted() {
        announce("Syncing with iCloud")
    }

    func announceSyncCompleted() {
        announce("Sync complete")
    }

    func announceSyncFailed(error: String) {
        announce("Sync failed: \(error)")
    }

    // MARK: - Collection Announcements

    func announceAddedToCollection(recipeTitle: String, collectionName: String) {
        announce("\(recipeTitle) added to \(collectionName)")
    }

    func announceRemovedFromCollection(recipeTitle: String, collectionName: String) {
        announce("\(recipeTitle) removed from \(collectionName)")
    }

    func announceCollectionCreated(name: String) {
        announce("\(name) collection created")
    }

    func announceCollectionDeleted(name: String) {
        announce("\(name) collection deleted")
    }

    // MARK: - Search & Filter Announcements

    func announceSearchResults(count: Int, query: String) {
        if count == 0 {
            announce("No results found for \(query)")
        } else if count == 1 {
            announce("Found 1 recipe for \(query)")
        } else {
            announce("Found \(count) recipes for \(query)")
        }
    }

    func announceFilterApplied(activeFilterCount: Int) {
        if activeFilterCount == 0 {
            announce("Filters cleared")
        } else if activeFilterCount == 1 {
            announce("1 filter applied")
        } else {
            announce("\(activeFilterCount) filters applied")
        }
    }

    // MARK: - Version Management Announcements

    func announceVersionCreated(versionNumber: Int) {
        announce("Version \(versionNumber) created")
    }

    func announceVersionActivated(versionNumber: Int) {
        announce("Switched to version \(versionNumber)")
    }

    func announceVersionDeleted(versionNumber: Int) {
        announce("Version \(versionNumber) deleted")
    }

    // MARK: - Sharing Announcements

    func announceRecipeShared(method: String) {
        announce("Recipe shared via \(method)")
    }

    func announceRecipeReceived(title: String, from: String) {
        announce("Received \(title) from \(from)")
    }

    func announceShareLinkCopied() {
        announce("Share link copied to clipboard")
    }

    // MARK: - Generic Announcements

    func announceSuccess(message: String) {
        announce(message)
    }

    func announceError(message: String) {
        announce("Error: \(message)", priority: .announcement)
    }

    func announceLoading(message: String) {
        announce(message)
    }
}
