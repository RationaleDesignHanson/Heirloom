import Foundation

enum SharedConstants {
    // IMPORTANT: Verify this matches existing App Group in entitlements
    static let appGroupIdentifier = "group.com.rationaledesign.heirloom"

    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var pendingImportsURL: URL? {
        sharedContainerURL?.appendingPathComponent("PendingImports", isDirectory: true)
    }

    static var sharedVideosURL: URL? {
        sharedContainerURL?.appendingPathComponent("SharedVideos", isDirectory: true)
    }

    // Notification names for cross-process communication
    static let pendingImportAddedNotification = Notification.Name("HeirloomPendingImportAdded")

    // UserDefaults keys
    static let pendingImportCountKey = "pendingImportCount"
}
