import Foundation
import EventKit

/// Service for exporting shopping lists to iOS Reminders app
@MainActor
class RemindersService {
    static let shared = RemindersService()

    private let eventStore = EKEventStore()

    private init() {}

    /// Request permission to access Reminders
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
        } catch {
            Log.error("Failed to request Reminders access", category: .general, metadata: ["error": error.localizedDescription])
            return false
        }
    }

    /// Export shopping list items to Reminders
    func exportToReminders(items: [ShoppingListItem]) async throws {
        // Request access first
        let hasAccess = await requestAccess()
        guard hasAccess else {
            throw RemindersError.accessDenied
        }

        // Find or create "Heirloom Shopping" list
        let calendar = try getOrCreateHeirloomList()

        // Create reminder for each item
        var successCount = 0
        for item in items {
            do {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = calendar
                reminder.title = item.displayText
                reminder.priority = item.isAggregated ? 3 : 0  // Medium priority for aggregated items

                // Add note with recipe sources if aggregated
                if item.isAggregated {
                    reminder.notes = "From \(item.recipeCount) recipes"
                }

                try eventStore.save(reminder, commit: false)
                successCount += 1
            } catch {
                Log.warning("Failed to save individual reminder", category: .general, metadata: ["itemText": item.displayText, "error": error.localizedDescription])
            }
        }

        // Commit all changes at once
        try eventStore.commit()

        Log.info("Exported shopping list items to Reminders", category: .general, metadata: ["successCount": successCount, "totalCount": items.count])
    }

    /// Find existing "Heirloom Shopping" list or create a new one
    private func getOrCreateHeirloomList() throws -> EKCalendar {
        // Look for existing list
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == "Heirloom Shopping" }) {
            return existing
        }

        // Create new list
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = "Heirloom Shopping"

        // Find the default source for reminders
        if let source = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = source
        } else {
            // Fallback to first available source
            guard let source = eventStore.sources.first(where: { $0.sourceType == .local || $0.sourceType == .calDAV }) else {
                throw RemindersError.noSourceAvailable
            }
            newCalendar.source = source
        }

        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
}

// MARK: - Shopping List Item

/// Simplified item structure for Reminders export
struct ShoppingListItem {
    let displayText: String
    let recipeCount: Int
    let isAggregated: Bool
}

// MARK: - Errors

enum RemindersError: LocalizedError {
    case accessDenied
    case noSourceAvailable

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Please enable Reminders access in Settings to export your shopping list."
        case .noSourceAvailable:
            return "No reminders source available. Please check your Reminders app."
        }
    }
}
