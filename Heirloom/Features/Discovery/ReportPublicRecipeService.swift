import Foundation
import FirebaseFirestore

/// Reasons for reporting a public recipe
enum ReportReason: String, CaseIterable {
    case inappropriate = "Inappropriate content"
    case spam = "Spam or misleading"
    case copyright = "Copyright violation"
    case offensive = "Offensive or hateful"
    case notRecipe = "Not a recipe"
    case other = "Other"

    var description: String {
        return self.rawValue
    }

    var icon: String {
        switch self {
        case .inappropriate: return "exclamationmark.triangle"
        case .spam: return "envelope.badge"
        case .copyright: return "doc.text.magnifyingglass"
        case .offensive: return "hand.raised"
        case .notRecipe: return "questionmark.circle"
        case .other: return "ellipsis.circle"
        }
    }
}

/// Service for reporting inappropriate public recipes
@MainActor
class ReportPublicRecipeService {
    private let db = Firestore.firestore()

    // MARK: - Report Submission

    /// Report a public recipe for moderation review
    /// - Parameters:
    ///   - publicRecipeId: ID of the public recipe to report
    ///   - reason: Reason for reporting
    ///   - details: Optional additional details from reporter
    ///   - reporterId: User ID of the reporter
    /// - Throws: Error if submission fails
    func reportRecipe(
        publicRecipeId: String,
        reason: ReportReason,
        details: String?,
        reporterId: String
    ) async throws {
        Log.info("Submitting recipe report", category: .social, metadata: [
            "publicRecipeId": publicRecipeId,
            "reason": reason.rawValue,
            "reporterId": reporterId
        ])

        // Create report document
        let reportData: [String: Any] = [
            "publicRecipeId": publicRecipeId,
            "reporterId": reporterId,
            "reason": reason.rawValue,
            "details": details ?? "",
            "status": "pending",  // pending, reviewed, action_taken, dismissed
            "createdAt": FieldValue.serverTimestamp(),
            "reviewedAt": NSNull(),
            "reviewedBy": NSNull(),
            "actionTaken": NSNull()
        ]

        // Submit to Firestore
        do {
            let reportRef = try await db.collection("publicRecipeReports").addDocument(data: reportData)

            Log.info("Recipe report submitted successfully", category: .social, metadata: [
                "reportId": reportRef.documentID
            ])

            // Increment report count on public recipe (for auto-moderation threshold)
            try await db.collection("publicRecipes").document(publicRecipeId).updateData([
                "reportCount": FieldValue.increment(Int64(1)),
                "lastReportedAt": FieldValue.serverTimestamp()
            ])

            Log.info("Incremented report count on public recipe", category: .social)

        } catch {
            Log.error("Failed to submit recipe report", category: .social, metadata: [
                "publicRecipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
            throw ReportError.submissionFailed
        }
    }

    // MARK: - Check if User Already Reported

    /// Check if the current user has already reported this recipe
    /// - Parameters:
    ///   - publicRecipeId: ID of the public recipe
    ///   - reporterId: User ID of the reporter
    /// - Returns: True if user has already reported this recipe
    func hasUserReportedRecipe(publicRecipeId: String, reporterId: String) async throws -> Bool {
        let query = db.collection("publicRecipeReports")
            .whereField("publicRecipeId", isEqualTo: publicRecipeId)
            .whereField("reporterId", isEqualTo: reporterId)
            .limit(to: 1)

        let snapshot = try await query.getDocuments()
        return !snapshot.documents.isEmpty
    }
}

// MARK: - Errors

enum ReportError: LocalizedError {
    case submissionFailed
    case alreadyReported
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .submissionFailed:
            return "Failed to submit report. Please try again."
        case .alreadyReported:
            return "You've already reported this recipe."
        case .unauthorized:
            return "You must be signed in to report content."
        }
    }
}
