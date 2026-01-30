//
//  ConnectionNotification.swift
//  Heirloom
//
//  Social Layer Phase 2: Connection Notification Extensions
//  Extends existing notification system for connection-related events
//

import Foundation

/// Connection-specific notification types
/// Extends existing HeirloomNotification system
enum ConnectionNotificationType: String, Codable {
    // Connection Requests
    case connectionRequestReceived
    case connectionRequestAccepted
    case connectionRequestRejected

    // Connection Activity
    case connectionSharedRecipe
    case connectionCookedYourRecipe
    case connectionCommentedOnRecipe

    // Kitchen Table
    case kitchenTableInviteReceived
    case kitchenTableMemberJoined
    case kitchenTableRecipeShared

    // Heritage / Lineage
    case recipeGenerationCreated    // Someone created a new generation from your recipe
    case recipeReachedMilestone     // Recipe reached X generations or accepts

    // Social Milestones
    case connectionMilestone        // Reached 10, 50, 100 connections
    case heritageGenerationMilestone // Your recipes reached X generations
}

/// Connection notification data structure
/// Stored as part of the notification payload
struct ConnectionNotificationData: Codable {
    // MARK: - Actor Info

    /// User ID of the person who triggered the notification
    let actorUserId: String

    /// Display name of the actor
    var actorDisplayName: String

    /// Photo URL of the actor
    var actorPhotoURL: String?

    /// Handle of the actor (for @mentions)
    var actorHandle: String?

    // MARK: - Connection Info

    /// Connection ID (if applicable)
    var connectionId: String?

    /// Connection status (for connection request notifications)
    var connectionStatus: ConnectionStatus?

    // MARK: - Recipe Info (if applicable)

    /// Recipe ID that triggered the notification
    var recipeId: String?

    /// Recipe title
    var recipeTitle: String?

    /// Recipe image URL
    var recipeImageURL: String?

    // MARK: - Kitchen Table Info (if applicable)

    /// Kitchen Table ID
    var kitchenTableId: String?

    /// Kitchen Table name
    var kitchenTableName: String?

    // MARK: - Heritage Info (if applicable)

    /// Generation number (for lineage notifications)
    var generation: Int?

    /// Root recipe ID (for lineage tracking)
    var rootRecipeId: String?

    // MARK: - Milestone Info (if applicable)

    /// Milestone value (e.g., "10" for 10 connections, "5" for 5 generations)
    var milestoneValue: Int?

    // MARK: - Metadata

    /// When the event occurred
    let occurredAt: Date

    /// Deep link URL to take user to relevant screen
    var deepLinkURL: String?

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case actorUserId
        case actorDisplayName
        case actorPhotoURL
        case actorHandle
        case connectionId
        case connectionStatus
        case recipeId
        case recipeTitle
        case recipeImageURL
        case kitchenTableId
        case kitchenTableName
        case generation
        case rootRecipeId
        case milestoneValue
        case occurredAt
        case deepLinkURL
    }
}

// MARK: - Notification Factory

extension ConnectionNotificationData {
    /// Create notification data for connection request received
    static func connectionRequest(
        from actorUserId: String,
        actorDisplayName: String,
        actorPhotoURL: String?,
        connectionId: String
    ) -> ConnectionNotificationData {
        return ConnectionNotificationData(
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: actorPhotoURL,
            actorHandle: nil,
            connectionId: connectionId,
            connectionStatus: .pending,
            recipeId: nil,
            recipeTitle: nil,
            recipeImageURL: nil,
            kitchenTableId: nil,
            kitchenTableName: nil,
            generation: nil,
            rootRecipeId: nil,
            milestoneValue: nil,
            occurredAt: Date(),
            deepLinkURL: "heirloom://connections/requests"
        )
    }

    /// Create notification data for connection accepted
    static func connectionAccepted(
        by actorUserId: String,
        actorDisplayName: String,
        actorPhotoURL: String?,
        connectionId: String
    ) -> ConnectionNotificationData {
        return ConnectionNotificationData(
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: actorPhotoURL,
            actorHandle: nil,
            connectionId: connectionId,
            connectionStatus: .connected,
            recipeId: nil,
            recipeTitle: nil,
            recipeImageURL: nil,
            kitchenTableId: nil,
            kitchenTableName: nil,
            generation: nil,
            rootRecipeId: nil,
            milestoneValue: nil,
            occurredAt: Date(),
            deepLinkURL: "heirloom://connections/\(connectionId)"
        )
    }

    /// Create notification data for recipe shared
    static func recipeShared(
        by actorUserId: String,
        actorDisplayName: String,
        actorPhotoURL: String?,
        recipeId: String,
        recipeTitle: String,
        recipeImageURL: String?
    ) -> ConnectionNotificationData {
        return ConnectionNotificationData(
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: actorPhotoURL,
            actorHandle: nil,
            connectionId: nil,
            connectionStatus: nil,
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            recipeImageURL: recipeImageURL,
            kitchenTableId: nil,
            kitchenTableName: nil,
            generation: nil,
            rootRecipeId: nil,
            milestoneValue: nil,
            occurredAt: Date(),
            deepLinkURL: "heirloom://recipes/\(recipeId)"
        )
    }

    /// Create notification data for Kitchen Table invite
    static func kitchenTableInvite(
        from actorUserId: String,
        actorDisplayName: String,
        actorPhotoURL: String?,
        kitchenTableId: String,
        kitchenTableName: String
    ) -> ConnectionNotificationData {
        return ConnectionNotificationData(
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: actorPhotoURL,
            actorHandle: nil,
            connectionId: nil,
            connectionStatus: nil,
            recipeId: nil,
            recipeTitle: nil,
            recipeImageURL: nil,
            kitchenTableId: kitchenTableId,
            kitchenTableName: kitchenTableName,
            generation: nil,
            rootRecipeId: nil,
            milestoneValue: nil,
            occurredAt: Date(),
            deepLinkURL: "heirloom://kitchentable/\(kitchenTableId)/invite"
        )
    }

    /// Create notification data for recipe generation
    static func recipeGeneration(
        by actorUserId: String,
        actorDisplayName: String,
        actorPhotoURL: String?,
        recipeId: String,
        recipeTitle: String,
        generation: Int,
        rootRecipeId: String
    ) -> ConnectionNotificationData {
        return ConnectionNotificationData(
            actorUserId: actorUserId,
            actorDisplayName: actorDisplayName,
            actorPhotoURL: actorPhotoURL,
            actorHandle: nil,
            connectionId: nil,
            connectionStatus: nil,
            recipeId: recipeId,
            recipeTitle: recipeTitle,
            recipeImageURL: nil,
            kitchenTableId: nil,
            kitchenTableName: nil,
            generation: generation,
            rootRecipeId: rootRecipeId,
            milestoneValue: nil,
            occurredAt: Date(),
            deepLinkURL: "heirloom://recipes/\(rootRecipeId)/lineage"
        )
    }

    /// Create notification data for milestone
    static func milestone(
        type: ConnectionNotificationType,
        milestoneValue: Int
    ) -> ConnectionNotificationData {
        let deepLink: String
        switch type {
        case .connectionMilestone:
            deepLink = "heirloom://connections"
        case .heritageGenerationMilestone:
            deepLink = "heirloom://heritage"
        default:
            deepLink = "heirloom://home"
        }

        return ConnectionNotificationData(
            actorUserId: "", // System notification
            actorDisplayName: "Heirloom",
            actorPhotoURL: nil,
            actorHandle: nil,
            connectionId: nil,
            connectionStatus: nil,
            recipeId: nil,
            recipeTitle: nil,
            recipeImageURL: nil,
            kitchenTableId: nil,
            kitchenTableName: nil,
            generation: nil,
            rootRecipeId: nil,
            milestoneValue: milestoneValue,
            occurredAt: Date(),
            deepLinkURL: deepLink
        )
    }
}

// MARK: - Display Helpers

extension ConnectionNotificationData {
    /// Generate notification title based on type
    func title(for type: ConnectionNotificationType) -> String {
        switch type {
        case .connectionRequestReceived:
            return "New Connection Request"
        case .connectionRequestAccepted:
            return "Connection Accepted!"
        case .connectionRequestRejected:
            return "Connection Request Declined"
        case .connectionSharedRecipe:
            return "Recipe Shared"
        case .connectionCookedYourRecipe:
            return "\(actorDisplayName) Cooked Your Recipe"
        case .connectionCommentedOnRecipe:
            return "New Comment"
        case .kitchenTableInviteReceived:
            return "Kitchen Table Invitation"
        case .kitchenTableMemberJoined:
            return "New Kitchen Table Member"
        case .kitchenTableRecipeShared:
            return "New Recipe in Kitchen Table"
        case .recipeGenerationCreated:
            return "Your Recipe Lives On!"
        case .recipeReachedMilestone:
            return "Recipe Milestone!"
        case .connectionMilestone:
            return "Connection Milestone!"
        case .heritageGenerationMilestone:
            return "Heritage Milestone!"
        }
    }

    /// Generate notification body based on type
    func body(for type: ConnectionNotificationType) -> String {
        switch type {
        case .connectionRequestReceived:
            return "\(actorDisplayName) wants to connect with you"
        case .connectionRequestAccepted:
            return "\(actorDisplayName) accepted your connection request"
        case .connectionRequestRejected:
            return "Your connection request was declined"
        case .connectionSharedRecipe:
            return "\(actorDisplayName) shared \"\(recipeTitle ?? "a recipe")\" with you"
        case .connectionCookedYourRecipe:
            return "Made \"\(recipeTitle ?? "your recipe")\""
        case .connectionCommentedOnRecipe:
            return "\(actorDisplayName) commented on \"\(recipeTitle ?? "a recipe")\""
        case .kitchenTableInviteReceived:
            return "\(actorDisplayName) invited you to join \"\(kitchenTableName ?? "a Kitchen Table")\""
        case .kitchenTableMemberJoined:
            return "\(actorDisplayName) joined \"\(kitchenTableName ?? "your Kitchen Table")\""
        case .kitchenTableRecipeShared:
            return "New recipe \"\(recipeTitle ?? "")\" in \(kitchenTableName ?? "Kitchen Table")"
        case .recipeGenerationCreated:
            return "\(actorDisplayName) created Generation \(generation ?? 0) of \"\(recipeTitle ?? "your recipe")\""
        case .recipeReachedMilestone:
            return "\"\(recipeTitle ?? "Your recipe")\" has been passed down \(milestoneValue ?? 0) times!"
        case .connectionMilestone:
            return "You've reached \(milestoneValue ?? 0) connections!"
        case .heritageGenerationMilestone:
            return "Your recipes have reached \(milestoneValue ?? 0) generations!"
        }
    }
}
