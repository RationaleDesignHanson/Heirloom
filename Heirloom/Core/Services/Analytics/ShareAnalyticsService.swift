//
//  ShareAnalyticsService.swift
//  Heirloom
//
//  Phase 1: Inter-Heirloom Recipe Sharing - Analytics Layer
//  Aggregates share statistics for discovery and insights
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Service Protocol

@MainActor
protocol ShareAnalyticsServiceProtocol {
    /// Fetch user's share statistics
    func fetchShareStats(userId: String) async throws -> ShareStats

    /// Fetch detailed share history
    func fetchShareHistory(userId: String, limit: Int) async throws -> [ShareHistoryItem]

    /// Record a share event (for future analytics)
    func recordShareEvent(userId: String, eventType: ShareEventType, shareId: String) async throws
}

// MARK: - Service Implementation

@MainActor
class ShareAnalyticsService: ShareAnalyticsServiceProtocol {
    private let db = Firestore.firestore()

    // MARK: - Fetch Share Statistics

    /// Fetch aggregated share statistics for a user
    func fetchShareStats(userId: String) async throws -> ShareStats {
        Log.info("Fetching share stats", category: .firebase, metadata: ["userId": userId])

        // Fetch all shares sent by user
        let sentSnapshot = try await db.collection("shares")
            .whereField("ownerId", isEqualTo: userId)
            .whereField("isDirectShare", isEqualTo: true)
            .getDocuments()

        // Fetch all shares received by user
        let receivedSnapshot = try await db.collection("shares")
            .whereField("recipientUserIds", arrayContains: userId)
            .whereField("isDirectShare", isEqualTo: true)
            .getDocuments()

        // Calculate sent statistics
        let sentShares = sentSnapshot.documents.map { $0.data() }
        let totalSharesSent = sentShares.count

        let totalRecipientsSent = sentShares.reduce(0) { sum, share in
            sum + ((share["recipientUserIds"] as? [String])?.count ?? 0)
        }

        let totalAcceptancesSent = sentShares.reduce(0) { sum, share in
            sum + (share["acceptCount"] as? Int ?? 0)
        }

        // Calculate received statistics
        let receivedShares = receivedSnapshot.documents.map { $0.data() }
        let totalSharesReceived = receivedShares.count

        _ = receivedShares.filter { share in
            let acceptedBy = share["acceptedBy"] as? [String] ?? []
            return acceptedBy.contains(userId)
        }.count

        // Calculate acceptance rate (shares sent that were accepted by at least one recipient)
        let sharesWithAcceptances = sentShares.filter { share in
            (share["acceptCount"] as? Int ?? 0) > 0
        }.count

        let averageAcceptanceRate = totalSharesSent > 0
            ? Double(sharesWithAcceptances) / Double(totalSharesSent) * 100
            : 0.0

        // Find most shared recipe
        var recipeCounts: [String: (title: String, count: Int)] = [:]
        for share in sentShares {
            guard let recipeId = share["recipeId"] as? String,
                  let recipeTitle = share["recipeTitle"] as? String else {
                continue
            }

            if var existing = recipeCounts[recipeId] {
                existing.count += 1
                recipeCounts[recipeId] = existing
            } else {
                recipeCounts[recipeId] = (title: recipeTitle, count: 1)
            }
        }

        let mostShared = recipeCounts.values.max(by: { $0.count < $1.count })

        let stats = ShareStats(
            totalSharesSent: totalSharesSent,
            totalSharesReceived: totalSharesReceived,
            totalSharesAccepted: totalAcceptancesSent,
            totalRecipientsSent: totalRecipientsSent,
            averageAcceptanceRate: averageAcceptanceRate,
            mostSharedRecipeTitle: mostShared?.title,
            mostSharedRecipeCount: mostShared?.count ?? 0
        )

        Log.info("Share stats fetched", category: .firebase, metadata: [
            "sent": totalSharesSent,
            "received": totalSharesReceived,
            "accepted": totalAcceptancesSent
        ])

        return stats
    }

    // MARK: - Fetch Share History

    /// Fetch detailed share history with acceptance tracking
    func fetchShareHistory(userId: String, limit: Int = 50) async throws -> [ShareHistoryItem] {
        Log.info("Fetching share history", category: .firebase, metadata: [
            "userId": userId,
            "limit": limit
        ])

        let snapshot = try await db.collection("shares")
            .whereField("ownerId", isEqualTo: userId)
            .whereField("isDirectShare", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        let items = snapshot.documents.compactMap { doc -> ShareHistoryItem? in
            let data = doc.data()

            guard let shareId = data["shareId"] as? String,
                  let recipeId = data["recipeId"] as? String,
                  let recipeTitle = data["recipeTitle"] as? String,
                  let recipientUserIds = data["recipientUserIds"] as? [String],
                  let createdAtTimestamp = data["createdAt"] as? Timestamp else {
                return nil
            }

            let acceptedBy = data["acceptedBy"] as? [String] ?? []
            let recipientDisplayNames = data["recipientDisplayNames"] as? [String: String] ?? [:]

            return ShareHistoryItem(
                id: shareId,
                recipeId: recipeId,
                recipeTitle: recipeTitle,
                recipientCount: recipientUserIds.count,
                acceptCount: acceptedBy.count,
                declineCount: 0, // Not tracking declines yet
                createdAt: createdAtTimestamp.dateValue(),
                recipientDisplayNames: recipientDisplayNames
            )
        }

        Log.info("Share history fetched", category: .firebase, metadata: ["count": items.count])

        return items
    }

    // MARK: - Record Share Events (Future Enhancement)

    /// Record share event for future analytics aggregation
    func recordShareEvent(userId: String, eventType: ShareEventType, shareId: String) async throws {
        // Future: Could write to analytics collection for trend tracking
        Log.debug("Share event recorded", category: .firebase, metadata: [
            "userId": userId,
            "eventType": eventType.rawValue,
            "shareId": shareId
        ])
    }
}

// MARK: - Data Models

/// Aggregated share statistics for a user
struct ShareStats: Codable {
    let totalSharesSent: Int
    let totalSharesReceived: Int
    let totalSharesAccepted: Int
    let totalRecipientsSent: Int
    let averageAcceptanceRate: Double
    let mostSharedRecipeTitle: String?
    let mostSharedRecipeCount: Int

    /// User-friendly acceptance rate display
    var acceptanceRateString: String {
        String(format: "%.0f%%", averageAcceptanceRate)
    }
}

/// Detailed share history item
struct ShareHistoryItem: Codable, Identifiable {
    let id: String  // shareId
    let recipeId: String
    let recipeTitle: String
    let recipientCount: Int
    let acceptCount: Int
    let declineCount: Int
    let createdAt: Date
    let recipientDisplayNames: [String: String]

    /// Acceptance rate for this share
    var acceptanceRate: Double {
        guard recipientCount > 0 else { return 0 }
        return Double(acceptCount) / Double(recipientCount) * 100
    }

    /// User-friendly acceptance rate display
    var acceptanceRateString: String {
        String(format: "%.0f%%", acceptanceRate)
    }

    /// User-friendly recipient list
    var recipientsText: String {
        let names = Array(recipientDisplayNames.values)
        if names.isEmpty {
            return "\(recipientCount) recipients"
        } else if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let first = names.prefix(2).joined(separator: ", ")
            return "\(first), +\(names.count - 2) more"
        }
    }
}

/// Share event types for analytics tracking
enum ShareEventType: String, Codable {
    case sent
    case received
    case accepted
    case declined
    case viewed
}

// MARK: - Global Convenience

extension ShareAnalyticsService {
    /// Global accessor via ServiceContainer
    nonisolated(unsafe) static var shared: ShareAnalyticsService {
        MainActor.assumeIsolated {
            // Try to resolve from container, or create fallback
            if let service = ServiceContainer.shared.resolveOptional(ShareAnalyticsService.self) {
                return service
            }
            return ShareAnalyticsService()
        }
    }
}
