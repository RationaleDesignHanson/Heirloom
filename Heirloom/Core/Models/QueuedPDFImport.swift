//
//  QueuedPDFImport.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import Foundation
import SwiftData
import UserNotifications

/// Stores PDFs queued for tomorrow when daily quota is exceeded
/// - Uses security-scoped URL bookmarks to persist access
/// - Triggers local notification when quota refreshes
@Model
final class QueuedPDFImport {

    // MARK: - Properties

    var id: UUID
    var pdfBookmark: Data              // Security-scoped URL bookmark
    var pdfName: String                // Display name (e.g., "The Joy of Cooking.pdf")
    var creditCost: Int                // How many credits this PDF will cost
    var queuedAt: Date                 // When user queued this PDF
    var scheduledFor: Date             // When to process (tomorrow's quota reset)
    var notificationSent: Bool         // Whether we've sent "quota refreshed" notification
    var userId: String                 // Associated user ID

    // MARK: - Initialization

    init(
        pdfBookmark: Data,
        pdfName: String,
        creditCost: Int,
        userId: String
    ) {
        self.id = UUID()
        self.pdfBookmark = pdfBookmark
        self.pdfName = pdfName
        self.creditCost = creditCost
        self.queuedAt = Date()
        self.scheduledFor = Calendar.current.startOfDay(for: Date().addingTimeInterval(24 * 60 * 60))
        self.notificationSent = false
        self.userId = userId
    }

    // MARK: - Public Methods

    /// Create a bookmark for security-scoped URL access
    /// - Parameter url: The PDF URL to bookmark
    /// - Returns: Bookmark data
    static func createBookmark(for url: URL) throws -> Data {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// Resolve bookmark back to URL
    /// - Returns: The PDF URL if bookmark is still valid
    func resolveURL() throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: pdfBookmark,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            Log.warning("Bookmark is stale for queued PDF", category: .general, metadata: [
                "pdfName": pdfName,
                "queuedAt": queuedAt.ISO8601Format()
            ])
        }

        return url
    }

    /// Check if this PDF is ready to import (quota has refreshed)
    var isReadyToImport: Bool {
        return Date() >= scheduledFor
    }

    // MARK: - Static Methods

    /// Queue a PDF for tomorrow's import
    /// - Parameters:
    ///   - url: The PDF URL
    ///   - creditCost: How many credits this PDF costs
    ///   - userId: User ID
    ///   - context: SwiftData model context
    /// - Returns: The queued import record
    @MainActor
    static func queuePDF(
        url: URL,
        creditCost: Int,
        userId: String,
        context: ModelContext
    ) throws -> QueuedPDFImport {

        // Create security-scoped bookmark
        let bookmark = try createBookmark(for: url)

        let queuedImport = QueuedPDFImport(
            pdfBookmark: bookmark,
            pdfName: url.lastPathComponent,
            creditCost: creditCost,
            userId: userId
        )

        context.insert(queuedImport)

        Log.info("PDF queued for tomorrow", category: .general, metadata: [
            "pdfName": url.lastPathComponent,
            "creditCost": creditCost,
            "scheduledFor": queuedImport.scheduledFor.ISO8601Format()
        ])

        // Schedule local notification for tomorrow
        scheduleNotification(for: queuedImport)

        return queuedImport
    }

    /// Schedule local notification when quota refreshes
    /// - Parameter queuedImport: The queued import record
    private static func scheduleNotification(for queuedImport: QueuedPDFImport) {
        let content = UNMutableNotificationContent()
        content.title = "Your quota refreshed!"
        content.body = "You have \(UserCredits.dailyFreeQuota) credits available. Ready to import \(queuedImport.pdfName)?"
        content.sound = .default
        content.categoryIdentifier = "QUEUED_PDF_READY"
        content.userInfo = [
            "queuedImportId": queuedImport.id.uuidString,
            "type": "queued_pdf_ready"
        ]

        // Trigger at scheduled time (tomorrow's midnight)
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: queuedImport.scheduledFor
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: "queued_pdf_\(queuedImport.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Failed to schedule queued PDF notification", category: .general, error: error)
            } else {
                Log.info("Scheduled notification for queued PDF", category: .general, metadata: [
                    "pdfName": queuedImport.pdfName,
                    "triggerDate": queuedImport.scheduledFor.ISO8601Format()
                ])
            }
        }
    }

    /// Fetch all queued PDFs ready to import
    /// - Parameters:
    ///   - userId: User ID
    ///   - context: SwiftData model context
    /// - Returns: Array of queued imports ready to process
    @MainActor
    static func fetchReadyImports(
        for userId: String,
        context: ModelContext
    ) throws -> [QueuedPDFImport] {
        let now = Date()
        var descriptor = FetchDescriptor<QueuedPDFImport>()
        descriptor.predicate = #Predicate<QueuedPDFImport> { queuedImport in
            queuedImport.userId == userId &&
            queuedImport.scheduledFor <= now
        }
        descriptor.sortBy = [SortDescriptor(\.queuedAt, order: .forward)]

        return try context.fetch(descriptor)
    }

    /// Delete a queued import (e.g., after successful import or user cancellation)
    /// - Parameters:
    ///   - queuedImport: The import to delete
    ///   - context: SwiftData model context
    @MainActor
    static func deleteQueuedImport(
        _ queuedImport: QueuedPDFImport,
        context: ModelContext
    ) {
        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["queued_pdf_\(queuedImport.id.uuidString)"]
        )

        context.delete(queuedImport)

        Log.info("Deleted queued PDF import", category: .general, metadata: [
            "pdfName": queuedImport.pdfName
        ])
    }
}
