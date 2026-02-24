//
//  FirebaseShareService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 6
//  Handles recipe sharing via Firestore
//

import Foundation
import SwiftData
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

/// Firebase-based recipe sharing service
/// Replaces CloudKit CKShare with Firestore-based sharing system
@MainActor
class FirebaseShareService: ObservableObject, FirebaseShareServiceProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfiguration
    private let logger: LoggingService
    private let firebaseSync: FirebaseSyncService
    private let lineageService: FirebaseLineageService
    private let analytics: AnalyticsService

    // MARK: - Initialization

    init(
        configuration: FirebaseConfiguration,
        logger: LoggingService,
        firebaseSync: FirebaseSyncService,
        lineageService: FirebaseLineageService,
        analytics: AnalyticsService
    ) {
        self.configuration = configuration
        self.logger = logger
        self.firebaseSync = firebaseSync
        self.lineageService = lineageService
        self.analytics = analytics
    }

    private var db: Firestore { configuration.db }
    private var auth: Auth { configuration.auth }

    // MARK: - Share Creation

    /// Create a share for a recipe with specified options
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Configuration for what to include
    ///   - recipientUserIds: Optional array of user IDs to share directly with (nil = public link)
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: Share ID and shareable URL
    func createShare(
        for recipe: Recipe,
        options: ShareOptions,
        recipientUserIds: [String]? = nil,
        context: ModelContext
    ) async throws -> (shareId: String, shareURL: URL) {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        // Premium gate: sharing requires active subscription or trial
        let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        guard subscriptionManager.isPremium else {
            throw ShareError.premiumRequired
        }

        logger.log("Creating Firebase share for recipe", category: .firebase, level: .info, metadata: nil)

        // 0. Copy-on-share for heritage and sample recipes
        // If sharing a heritage or sample recipe, create a user copy and share that instead
        // This prevents ID collisions across devices (samples have same IDs)
        var recipeToShare: Recipe
        if recipe.isThemeRecipe {
            Log.info("Heritage recipe detected - creating user copy before sharing", category: .firebase, metadata: [
                "originalRecipeId": recipe.id.firebaseString,
                "title": recipe.title
            ])

            // Create user copy with card back and customizations
            let userCopy = recipe.createUserCopy(context: context)

            // Save the copy
            try context.save()

            Log.info("User copy created for heritage recipe share", category: .firebase, metadata: [
                "originalRecipeId": recipe.id.firebaseString,
                "copyRecipeId": userCopy.id.firebaseString,
                "hasCardBack": userCopy.cardBack != nil
            ])

            // Use the copy for sharing
            recipeToShare = userCopy
        } else if recipe.isSampleRecipe {
            Log.info("Sample recipe detected - creating user copy before sharing", category: .firebase, metadata: [
                "originalRecipeId": recipe.id.firebaseString,
                "title": recipe.title
            ])

            // Create user copy with new ID
            let userCopy = recipe.createUserCopy(context: context)

            // Save the copy
            try context.save()

            Log.info("User copy created for sample recipe share", category: .firebase, metadata: [
                "originalRecipeId": recipe.id.firebaseString,
                "copyRecipeId": userCopy.id.firebaseString
            ])

            // Use the copy for sharing
            recipeToShare = userCopy
        } else {
            // Share the original recipe (user-created recipe)
            recipeToShare = recipe
        }

        // Ensure provenance is properly set for the original recipe
        // This ensures the original owner sees "Original" badge
        if recipeToShare.provenance.sourceType == .userCreated && recipeToShare.provenance.sourceURL == nil && recipeToShare.sourceURL != nil {
            let provenanceSource = recipeToShare.sourceType?.toProvenanceSourceType() ?? .userCreated
            recipeToShare.provenance = ProvenanceMetadata(
                sourceType: provenanceSource,
                sourceURL: recipeToShare.sourceURL,
                generation: 0  // Original recipe
            )
            Log.info("Updated provenance for original recipe", category: .firebase, metadata: [
                "recipeId": recipeToShare.id.firebaseString,
                "title": recipeToShare.title
            ])
        }

        // 1. Ensure recipe is uploaded to Firebase (including image)
        // uploadRecipe() handles the complete upload flow including image upload
        // and updating firebaseImageURL property before it returns
        try await firebaseSync.uploadRecipe(recipeToShare)

        // 2. Force context save to persist any changes from upload
        try context.save()

        // 3. Re-fetch the recipe from context to ensure we have the latest data
        // This eliminates race conditions by getting a fresh instance with
        // the updated firebaseImageURL property
        let recipeId = recipeToShare.id
        let fetchDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.id == recipeId }
        )
        if let freshRecipe = try context.fetch(fetchDescriptor).first {
            recipeToShare = freshRecipe
        }

        // 4. Verify image URL was set (if recipe has an image)
        if recipeToShare.imageFileName != nil && recipeToShare.firebaseImageURL == nil {
            logger.log(
                "⚠️ Recipe has image but firebaseImageURL is nil after upload",
                category: .firebase,
                level: .warning,
                metadata: [
                    "recipeId": recipeToShare.id.firebaseString,
                    "imageFileName": recipeToShare.imageFileName ?? "nil"
                ]
            )
            // Continue with share creation - the image upload may have failed
            // but we should still create the share without the image
        }

        // 1.5. Fetch lineage information if this is a heirloom share
        var lineage: RecipeLineage?
        if options.shareType == .heirloom {
            lineage = try? lineageService.fetchLineage(for: recipeToShare.id, context: context)

            // If no lineage exists and this is a heirloom share, create root lineage
            if lineage == nil {
                try await lineageService.createRootLineage(
                    recipeId: recipeToShare.id,
                    context: context
                )
                lineage = try? lineageService.fetchLineage(for: recipeToShare.id, context: context)
            }
        }

        // 2. Create share document
        let shareId = UUID().uuidString.lowercased()
        var shareData: [String: Any] = [
            "shareId": shareId,
            "recipeId": recipeToShare.id.firebaseString,
            "ownerId": userId,
            "ownerName": options.sharerName ?? "Someone",
            "recipeTitle": recipeToShare.title,
            "shareType": options.shareType.rawValue,
            "createdAt": Timestamp(date: Date()),
            "expiresAt": options.expirationDuration?.expirationDate.map { Timestamp(date: $0) } as Any,

            // Share options
            "includeCardBack": options.includeCardBack,
            "includeRating": options.includeRating,
            "includeNotes": options.includeNotes,
            "includePinnedComments": options.includePinnedComments,
            "includeAllComments": options.includeAllComments,
            "includeCookingHistory": options.includeCookingHistory,
            "includeStickers": options.includeStickers,
            "personalMessage": options.personalMessage as Any,
            "allowReSharing": options.allowReSharing,

            // Metadata
            // Use heritage chain length as source of truth for generation
            // heritageChain excludes current user, so it directly represents the generation number
            "generation": (recipeToShare.heritageChain ?? []).count,
            "servings": recipeToShare.servings as Any,
            "prepTime": recipeToShare.prepTime as Any,
            "cookTime": recipeToShare.cookTime as Any,
            "ingredientCount": recipeToShare.ingredients?.count ?? 0,
            "instructionCount": recipeToShare.instructions.count,

            // Preview data for share preview UI
            "ingredientsPreview": (recipeToShare.ingredients ?? [])
                .prefix(6)
                .compactMap { $0.displayText.isEmpty ? $0.originalText : $0.displayText },
            "instructionsPreview": Array(recipeToShare.instructions.prefix(3)),

            // Image URL (critical for sharing with images)
            "firebaseImageURL": recipeToShare.firebaseImageURL as Any,

            // Lineage tracking (for heirloom shares)
            "rootRecipeId": lineage?.rootRecipeId.firebaseString ?? recipeToShare.id.firebaseString,
            "rootOwnerId": lineage?.rootOwnerId ?? userId,
            "rootProvenanceHash": recipeToShare.provenance.rootProvenanceHash,
            // Heritage chain: ordered list of user IDs from root to current sharer
            // Optionally sanitized to remove demo users
            "heritageChain": sanitizeHeritageChain(
                recipeToShare.heritageChain,
                names: nil,
                sanitize: options.sanitizeDemoUsers
            ).chain + [userId],
            // Heritage chain names: display names for offline viewing
            "heritageChainNames": sanitizeHeritageChain(
                recipeToShare.heritageChain,
                names: recipeToShare.heritageChainNames,
                sanitize: options.sanitizeDemoUsers
            ).names + [options.sharerName ?? "Someone"],

            // Acceptance tracking
            "acceptedBy": [] as [String], // Array of user IDs who accepted
            "acceptCount": 0,
            "viewCount": 0
        ]

        // NEW: Direct sharing fields (Phase 1: Inter-Heirloom Sharing)
        if let recipientUserIds = recipientUserIds, !recipientUserIds.isEmpty {
            shareData["recipientUserIds"] = recipientUserIds
            shareData["isDirectShare"] = true
            shareData["sharedWithCount"] = recipientUserIds.count

            // Fetch recipient display names for UI
            var recipientDisplayNames: [String: String] = [:]
            for recipientId in recipientUserIds {
                if let userDoc = try? await db.collection("users").document(recipientId).getDocument(),
                   let displayName = userDoc.data()?["displayName"] as? String {
                    recipientDisplayNames[recipientId] = displayName
                }
            }
            shareData["recipientDisplayNames"] = recipientDisplayNames
        } else {
            shareData["isDirectShare"] = false
        }

        // 3. Save to Firestore shares collection (top-level, not user-scoped)
        try await db.collection("shares").document(shareId).setData(shareData)

        logger.log("Firebase share created successfully", category: .firebase, level: .info, metadata: nil)

        // 4. Generate shareable URL
        let shareURL = generateShareURL(shareId: shareId)

        // 5. Update recipe metadata
        recipeToShare.sharedDate = Date()
        recipeToShare.sharedBy = options.sharerName
        try context.save()

        // 6. Track analytics
        analytics.track(event: .recipeShared, properties: [
            "method": "firebase",
            "share_type": options.shareType.rawValue,
            "has_message": options.personalMessage != nil
        ])

        return (shareId, shareURL)
    }

    // MARK: - Direct Sharing (Phase 1: Inter-Heirloom Sharing)

    /// Create a direct share to specific connections
    /// - Parameters:
    ///   - recipe: The recipe to share
    ///   - options: Configuration for what to include
    ///   - recipientUserIds: Array of user IDs to share with
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: Share ID and shareable URL
    func createDirectShare(
        for recipe: Recipe,
        options: ShareOptions,
        recipientUserIds: [String],
        context: ModelContext
    ) async throws -> (shareId: String, shareURL: URL) {
        guard !recipientUserIds.isEmpty else {
            throw ShareError.noRecipients
        }

        guard let currentUserId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        logger.log("Creating direct share to \(recipientUserIds.count) recipients", category: .firebase, level: .info, metadata: nil)

        // 1. Create share using extended createShare() method
        let (shareId, shareURL) = try await createShare(
            for: recipe,
            options: options,
            recipientUserIds: recipientUserIds,
            context: context
        )

        // 2. Send notification to each recipient
        for recipientId in recipientUserIds {
            do {
                // Create notification document
                let notificationData: [String: Any] = [
                    "type": "connectionSharedRecipe",
                    "shareId": shareId,
                    "recipeId": recipe.id.firebaseString,
                    "recipeTitle": recipe.title,
                    "recipeImageURL": recipe.firebaseImageURL as Any,
                    "actorUserId": currentUserId,
                    "actorDisplayName": options.sharerName ?? "Someone",
                    "actorPhotoURL": auth.currentUser?.photoURL?.absoluteString as Any,
                    "timestamp": Timestamp(date: Date()),
                    "read": false,
                    "deepLinkURL": "heirloom://share/\(shareId)"
                ]

                try await db.collection("users/\(recipientId)/notifications")
                    .document(UUID().uuidString.lowercased())
                    .setData(notificationData)

                logger.log("Notification sent to recipient", category: .firebase, level: .info, metadata: ["recipientId": recipientId])
            } catch {
                logger.log("Failed to send notification to recipient", category: .firebase, level: .error, metadata: ["recipientId": recipientId, "error": error.localizedDescription])
                // Continue sending to other recipients even if one fails
            }
        }

        // 3. Update connection recipesSharedCount for each connection
        // Get connection service
        let connectionService = ServiceContainer.shared.resolve(ConnectionServiceProtocol.self) as? FirebaseConnectionService

        for recipientId in recipientUserIds {
            do {
                // Find connection ID for this recipient
                let connectionsQuery = db.collection("users/\(currentUserId)/connections")
                    .whereField("connectedUserId", isEqualTo: recipientId)
                    .whereField("status", isEqualTo: ConnectionStatus.connected.rawValue)

                let snapshot = try await connectionsQuery.getDocuments()

                if let connectionDoc = snapshot.documents.first {
                    try await connectionService?.recordRecipeShare(connectionId: connectionDoc.documentID)
                    logger.log("Updated recipe share count for connection", category: .firebase, level: .info, metadata: ["connectionId": connectionDoc.documentID])
                }
            } catch {
                logger.log("Failed to update connection share count", category: .firebase, level: .error, metadata: ["recipientId": recipientId, "error": error.localizedDescription])
                // Continue with other recipients
            }
        }

        // 4. Track analytics
        analytics.track(event: .recipeShared, properties: [
            "method": "direct",
            "recipient_count": recipientUserIds.count,
            "share_type": options.shareType.rawValue
        ])

        // 5. Trigger demo social behavior for demo user recipients
        Task { @MainActor in
            for recipientId in recipientUserIds {
                if DemoSocialBehaviorService.demoUserIds.contains(recipientId) {
                    DemoSocialBehaviorService.shared.onRecipeSharedWithDemoUser(
                        shareId: shareId,
                        recipeId: recipe.id.firebaseString,
                        recipeTitle: recipe.title,
                        demoUserId: recipientId
                    )
                }
            }
        }

        logger.log("Direct share created successfully", category: .firebase, level: .info, metadata: ["shareId": shareId, "recipientCount": recipientUserIds.count])

        return (shareId, shareURL)
    }

    /// Fetch direct shares sent to the current user
    /// - Parameter userId: User ID to fetch shares for
    /// - Returns: Array of share documents
    func fetchDirectSharesForUser(userId: String) async throws -> [[String: Any]] {
        logger.log("Fetching direct shares for user", category: .firebase, level: .info, metadata: ["userId": userId])

        // Query shares where recipientUserIds contains this user
        let snapshot = try await db.collection("shares")
            .whereField("recipientUserIds", arrayContains: userId)
            .whereField("isDirectShare", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let shares = snapshot.documents.map { $0.data() }

        // Filter out expired shares and already accepted shares (client-side)
        let now = Date()
        let filteredShares = shares.filter { share in
            // Check expiration
            if let expiresAt = (share["expiresAt"] as? Timestamp)?.dateValue(),
               expiresAt < now {
                return false // Expired
            }

            // Check if already accepted by this user
            let acceptedBy = share["acceptedBy"] as? [String] ?? []
            if acceptedBy.contains(userId) {
                return false // Already accepted
            }

            return true // Include this share
        }

        logger.log("Fetched direct shares", category: .firebase, level: .info, metadata: ["count": filteredShares.count])

        return filteredShares
    }

    /// Generate a shareable URL from a share ID
    func generateShareURL(shareId: String) -> URL {
        // Use heirloom:// deep link format for app launching
        // Format: heirloom://share/{shareId}
        let urlString = "heirloom://share/\(shareId)"
        return URL(string: urlString)!
    }

    /// Generate a web-friendly shareable URL
    func generateWebShareURL(shareId: String) -> URL {
        // Format: https://heirloom.app/share/{shareId}
        // This redirects to app if installed, otherwise shows web preview
        let urlString = "https://heirloom.app/share/\(shareId)"
        return URL(string: urlString)!
    }

    // MARK: - Share Acceptance

    /// Accept a shared recipe
    /// - Parameters:
    ///   - shareId: The share ID from the URL
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The accepted recipe
    func acceptShare(
        shareId: String,
        context: ModelContext
    ) async throws -> Recipe {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        logger.log("Accepting Firebase share", category: .firebase, level: .info, metadata: nil)

        // 1. Fetch share document
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()

        guard shareDoc.exists else {
            throw ShareError.shareNotFound
        }

        guard let shareData = shareDoc.data() else {
            throw ShareError.invalidShareData
        }

        // 2. Check expiration
        if let expiresAt = (shareData["expiresAt"] as? Timestamp)?.dateValue(),
           expiresAt < Date() {
            throw ShareError.shareExpired
        }

        // 3. Extract share metadata
        // IMPORTANT: Lowercase recipeId to match Firebase document convention
        // Old shares may have uppercase IDs, but documents are stored lowercase
        let recipeId = (shareData["recipeId"] as? String ?? "").lowercased()
        let ownerId = shareData["ownerId"] as? String ?? ""
        let shareType = ShareOptions.ShareType(rawValue: shareData["shareType"] as? String ?? "heirloom") ?? .heirloom

        Log.info("Accepting share", category: .firebase, metadata: [
            "shareId": shareId,
            "shareType": shareType.rawValue,
            "recipeId": recipeId
        ])

        // Prevent accepting own share
        if ownerId == userId {
            throw ShareError.cannotAcceptOwnShare
        }

        // Check if already accepted
        let acceptedBy = shareData["acceptedBy"] as? [String] ?? []
        if acceptedBy.contains(userId) {
            logger.log("Share already accepted by user", category: .firebase, level: .info, metadata: nil)
            // Try to fetch the already-imported recipe
            if let existingRecipe = try? await fetchAcceptedRecipe(recipeId: recipeId, context: context) {
                return existingRecipe
            }
        }

        // 4. Fetch the shared recipe from owner's collection
        let recipeDoc = try await db.collection("users/\(ownerId)/recipes").document(recipeId).getDocument()

        guard recipeDoc.exists, let recipeData = recipeDoc.data() else {
            throw ShareError.recipeNotFound
        }

        // 5. Convert to Recipe model
        var sharedRecipe = firebaseSync.convertFromFirestoreData(recipeData, id: recipeId, context: context)

        // 6. Download ingredients
        let ingredientsSnapshot = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/ingredients").getDocuments()
        var ingredients: [Ingredient] = []

        for ingredientDoc in ingredientsSnapshot.documents {
            let ingredientData = ingredientDoc.data()
            let ingredient = firebaseSync.convertIngredientFromFirestoreData(
                ingredientData,
                id: ingredientDoc.documentID
            )
            ingredient.recipe = sharedRecipe
            ingredients.append(ingredient)
            context.insert(ingredient)
        }

        sharedRecipe.ingredients = ingredients.isEmpty ? nil : ingredients

        // 6.5. Download instructions from subcollection (legacy support)
        // NOTE: Instructions are typically stored on the recipe document itself (loaded via convertFromFirestoreData),
        // but some older recipes may have them in a subcollection. Only overwrite if subcollection has content.
        let instructionsSnapshot = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/instructions").getDocuments()

        if !instructionsSnapshot.documents.isEmpty {
            var instructionItems: [(order: Int, text: String)] = []

            for instructionDoc in instructionsSnapshot.documents {
                let instructionData = instructionDoc.data()
                let order = instructionData["orderIndex"] as? Int ?? instructionData["order"] as? Int ?? 0
                let text = instructionData["text"] as? String ?? ""
                if !text.isEmpty {
                    instructionItems.append((order: order, text: text))
                }
            }

            // Sort by order and extract text - only overwrite if we found instructions in subcollection
            if !instructionItems.isEmpty {
                instructionItems.sort { $0.order < $1.order }
                sharedRecipe.instructions = instructionItems.map { $0.text }
            }

            Log.debug("Downloaded instructions from subcollection for shared recipe", category: .firebase, metadata: [
                "count": instructionItems.count,
                "recipeId": recipeId
            ])
        } else {
            Log.debug("No instructions subcollection found, using instructions from recipe document", category: .firebase, metadata: [
                "count": sharedRecipe.instructions.count,
                "recipeId": recipeId
            ])
        }

        // 7. Download comments if included
        if shareData["includePinnedComments"] as? Bool == true || shareData["includeAllComments"] as? Bool == true {
            let commentsSnapshot = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/comments").getDocuments()
            var comments: [RecipeComment] = []

            for commentDoc in commentsSnapshot.documents {
                let commentData = commentDoc.data()
                let comment = firebaseSync.convertCommentFromFirestoreData(
                    commentData,
                    id: commentDoc.documentID
                )
                comment.recipe = sharedRecipe
                comments.append(comment)
                context.insert(comment)
            }

            sharedRecipe.comments = comments.isEmpty ? nil : comments
        }

        // 8. Download card back if included
        if shareData["includeCardBack"] as? Bool == true {
            let cardBackDoc = try await db.collection("users/\(ownerId)/recipes/\(recipeId)/cardBack").document("metadata").getDocument()

            if cardBackDoc.exists, let cardBackData = cardBackDoc.data() {
                let cardBack = firebaseSync.convertCardBackFromFirestoreData(cardBackData)
                cardBack.recipe = sharedRecipe
                sharedRecipe.cardBack = cardBack
                context.insert(cardBack)
            }
        }

        // 9. Download image if available (non-fatal — recipe is still usable without image)
        if let firebaseImageURL = shareData["firebaseImageURL"] as? String {
            sharedRecipe.firebaseImageURL = firebaseImageURL
            do {
                try await firebaseSync.downloadImage(for: sharedRecipe)
            } catch {
                Log.warning("Image download failed during share accept, continuing without image", category: .firebase, metadata: ["url": firebaseImageURL, "error": error.localizedDescription])
            }
        }

        // 10. Update provenance with INHERITED rootProvenanceHash for cryptographic lineage
        let generation = (shareData["generation"] as? Int ?? 0) + 1
        let ownerName = shareData["ownerName"] as? String
        let inheritedRootHash = shareData["rootProvenanceHash"] as? String
        let parentShareId = shareId  // The share document ID links us to the parent

        Log.info("Setting sharedBy for accepted recipe", category: .firebase, metadata: [
            "ownerName": ownerName ?? "nil",
            "recipeId": recipeId,
            "inheritedRootHash": inheritedRootHash ?? "none (legacy share)",
            "generation": generation
        ])

        sharedRecipe.provenance = ProvenanceMetadata(
            sourceType: .shared,
            sourceURL: nil,
            sourceAttribution: ownerName,
            rootProvenanceHash: inheritedRootHash,  // CRITICAL: Inherit root hash for cryptographic lineage
            generation: generation,
            parentShareID: parentShareId,  // Link back to parent share document
            sharedByName: ownerName,
            createdAt: Date()
        )

        sharedRecipe.sharedBy = ownerName
        sharedRecipe.sharedByUserId = ownerId // Store sharer's user ID for querying their recipes
        sharedRecipe.sharedFromRecipeId = recipeId.lowercased() // Store original recipe UUID (lowercase) for update checks
        sharedRecipe.sharedDate = Date()
        sharedRecipe.generationCount = generation + 1

        // Build heritage chain: inherit from share data and add current user
        let inheritedChain = shareData["heritageChain"] as? [String] ?? []
        sharedRecipe.heritageChain = inheritedChain + [userId]

        // Build heritage chain names: inherit and add current user's display name
        let inheritedChainNames = shareData["heritageChainNames"] as? [String] ?? []
        let currentUserName = auth.currentUser?.displayName ?? "You"
        sharedRecipe.heritageChainNames = inheritedChainNames + [currentUserName]

        Log.info("Built heritage chain for sharedRecipe", category: .firebase, metadata: [
            "inheritedChainCount": inheritedChain.count,
            "finalChainCount": sharedRecipe.heritageChain?.count ?? -1,
            "finalChainNames": sharedRecipe.heritageChainNames?.joined(separator: ", ") ?? "nil"
        ])

        // Mark demo recipes - they cannot be shared (onboarding only)
        let isDemoShare = shareData["isDemoShare"] as? Bool ?? false
        sharedRecipe.isDemoRecipe = isDemoShare
        if isDemoShare {
            Log.info("Recipe marked as demo - sharing will be blocked", category: .firebase, metadata: [
                "recipeId": recipeId
            ])
        }

        // 11. KEEP ORIGINAL ID for immutable recipe identity (v2.0+)
        // Original: sharedRecipe.id = UUID() // This broke lineage tracking
        // New: Keep original ID so recipe maintains identity across shares
        let originalRecipeId = sharedRecipe.id
        logger.log("Using immutable recipe ID for share", category: .firebase, level: .info, metadata: nil)

        // Check if recipe with this ID already exists locally
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate<Recipe> { $0.id == originalRecipeId })
        let existingRecipes = try context.fetch(descriptor)

        if let existingRecipe = existingRecipes.first {
            // CRITICAL: Don't update sample recipes - create a new recipe instead
            // Sample recipes can have the same ID across devices, but they should remain separate
            if existingRecipe.isSampleRecipe {
                Log.info("Existing recipe is a sample - creating new recipe with new ID", category: .firebase, metadata: [
                    "existingTitle": existingRecipe.title,
                    "sharedTitle": sharedRecipe.title
                ])

                // Create new recipe with new ID
                sharedRecipe.id = UUID()
                sharedRecipe.dateAdded = Date()
                context.insert(sharedRecipe)

                Log.info("Inserted new recipe with new ID (sample collision avoided)", category: .firebase, metadata: [
                    "newRecipeId": sharedRecipe.id.firebaseString
                ])
            } else {
                // Recipe already exists (not a sample) - merge/update instead of insert
                // This handles re-accepting the same share
                Log.info("Recipe already exists locally (not sample), updating instead of inserting", category: .firebase, metadata: [
                    "recipeId": existingRecipe.id.firebaseString
                ])
                existingRecipe.title = sharedRecipe.title
                existingRecipe.instructions = sharedRecipe.instructions
                existingRecipe.ingredients = sharedRecipe.ingredients
                existingRecipe.servings = sharedRecipe.servings
                existingRecipe.prepTime = sharedRecipe.prepTime
                existingRecipe.cookTime = sharedRecipe.cookTime
                existingRecipe.notes = sharedRecipe.notes
                existingRecipe.sharedBy = ownerName
                existingRecipe.sharedDate = Date()
                existingRecipe.generationCount = generation + 1
                existingRecipe.modifiedAt = Date()
                existingRecipe.dateAdded = Date() // Update so recipe appears at top of list

                // Copy heritage chain fields (needed for offline lineage download affordance)
                existingRecipe.heritageChain = sharedRecipe.heritageChain
                existingRecipe.heritageChainNames = sharedRecipe.heritageChainNames
                existingRecipe.sharedByUserId = sharedRecipe.sharedByUserId
                existingRecipe.sharedFromRecipeId = sharedRecipe.sharedFromRecipeId

                Log.info("Copied heritage chain to existing recipe", category: .firebase, metadata: [
                    "heritageChainCount": existingRecipe.heritageChain?.count ?? -1,
                    "heritageChainNames": existingRecipe.heritageChainNames?.joined(separator: ", ") ?? "nil",
                    "sharedByUserId": existingRecipe.sharedByUserId ?? "nil"
                ])

                sharedRecipe = existingRecipe // Use existing recipe for subsequent operations
            }
        } else {
            // 12. Insert new recipe into local database (keeps original ID)
            sharedRecipe.dateAdded = Date()
            context.insert(sharedRecipe)
            logger.log("Inserted new recipe with original ID", category: .firebase, level: .info, metadata: nil)
        }

        try context.save()

        // 13. Upload to recipient's Firebase collection (with original ID)
        try await firebaseSync.uploadRecipe(sharedRecipe)

        // 13.5. Create lineage record if this is a heirloom share
        if shareType == .heirloom {
            let rootRecipeIdString = shareData["rootRecipeId"] as? String ?? recipeId
            let rootOwnerId = shareData["rootOwnerId"] as? String ?? ownerId

            Log.info("Creating lineage for heirloom share", category: .firebase, metadata: [
                "rootRecipeIdString": rootRecipeIdString,
                "parentRecipeId": recipeId,
                "currentRecipeId": sharedRecipe.id.firebaseString,
                "rootOwnerId": rootOwnerId,
                "generation": generation
            ])

            if let rootRecipeId = UUID(uuidString: rootRecipeIdString),
               let parentRecipeId = UUID(uuidString: recipeId) {
                do {
                    try await lineageService.createDescendantLineage(
                        rootRecipeId: rootRecipeId,
                        parentRecipeId: parentRecipeId,
                        currentRecipeId: sharedRecipe.id,
                        rootOwnerId: rootOwnerId,
                        generation: generation,
                        sharedByName: ownerName,
                        context: context
                    )
                    Log.info("Lineage record created for shared recipe", category: .firebase)
                } catch {
                    Log.error("Failed to create lineage for shared recipe", category: .firebase, error: error)
                    // Continue without lineage tracking
                }
            } else {
                Log.warning("Invalid lineage IDs, skipping lineage tracking", category: .firebase, metadata: [
                    "rootRecipeIdString": rootRecipeIdString,
                    "parentRecipeId": recipeId
                ])
            }
        } else {
            Log.warning("Skipping lineage creation - not a heirloom share", category: .firebase, metadata: [
                "shareType": shareType.rawValue
            ])
        }

        // 14. Update share document (track acceptance)
        var updatedAcceptedBy = acceptedBy
        if !updatedAcceptedBy.contains(userId) {
            updatedAcceptedBy.append(userId)
        }

        try await db.collection("shares").document(shareId).updateData([
            "acceptedBy": updatedAcceptedBy,
            "acceptCount": FieldValue.increment(Int64(1)),
            "lastAcceptedAt": Timestamp(date: Date())
        ])

        logger.log("Firebase share accepted successfully", category: .firebase, level: .info, metadata: nil)

        // 14.5. Route to "From Friends" collection
        let collectionRouter = CollectionRouter(modelContext: context)
        collectionRouter.routeSharedRecipe(sharedRecipe, from: ownerName)

        // 14.6. Update connection counts for both sender and receiver
        // Get connection service
        let connectionService = ServiceContainer.shared.resolve(ConnectionServiceProtocol.self) as? FirebaseConnectionService

        // Find connection between recipient (current user) and sender (owner)
        do {
            let connectionsQuery = db.collection("users/\(userId)/connections")
                .whereField("connectedUserId", isEqualTo: ownerId)
                .whereField("status", isEqualTo: ConnectionStatus.connected.rawValue)

            let snapshot = try await connectionsQuery.getDocuments()

            if let connectionDoc = snapshot.documents.first {
                // Increment recipesReceivedCount for the recipient
                try await connectionService?.recordRecipeReceived(connectionId: connectionDoc.documentID)
                logger.log("Updated recipe received count for connection", category: .firebase, level: .info, metadata: ["connectionId": connectionDoc.documentID])
            }
        } catch {
            logger.log("Failed to update connection received count", category: .firebase, level: .error, metadata: ["ownerId": ownerId, "error": error.localizedDescription])
            // Continue even if this fails - don't block share acceptance
        }

        // 15. Track analytics
        analytics.track(event: .recipeImported, properties: [
            "source": "firebase_share",
            "method": "firebase",
            "generation": generation,
            "has_message": shareData["personalMessage"] != nil
        ])

        return sharedRecipe
    }

    // MARK: - Share Management

    /// Fetch share metadata without accepting
    func fetchShareMetadata(shareId: String) async throws -> [String: Any] {
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()

        guard shareDoc.exists, let shareData = shareDoc.data() else {
            throw ShareError.shareNotFound
        }

        // Check expiration
        if let expiresAt = (shareData["expiresAt"] as? Timestamp)?.dateValue(),
           expiresAt < Date() {
            throw ShareError.shareExpired
        }

        // Increment view count
        try await db.collection("shares").document(shareId).updateData([
            "viewCount": FieldValue.increment(Int64(1))
        ])

        return shareData
    }

    /// Revoke a share (delete it)
    func revokeShare(shareId: String) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        // Verify ownership
        let shareDoc = try await db.collection("shares").document(shareId).getDocument()
        guard let shareData = shareDoc.data(),
              let ownerId = shareData["ownerId"] as? String,
              ownerId == userId else {
            throw ShareError.notAuthorized
        }

        // Delete share
        try await db.collection("shares").document(shareId).delete()

        logger.log("Firebase share revoked", category: .firebase, level: .info, metadata: nil)
    }

    /// List all shares created by current user for a recipe
    func listShares(for recipe: Recipe) async throws -> [[String: Any]] {
        guard let userId = auth.currentUser?.uid else {
            throw ShareError.notAuthenticated
        }

        let snapshot = try await db.collection("shares")
            .whereField("recipeId", isEqualTo: recipe.id.firebaseString)
            .whereField("ownerId", isEqualTo: userId)
            .getDocuments()

        return snapshot.documents.map { $0.data() }
    }

    // MARK: - Helper Methods

    private func fetchAcceptedRecipe(recipeId: String, context: ModelContext) async throws -> Recipe? {
        // Query local database for recipe with matching original ID
        // (This would require storing the original share recipeId in a field)
        // For now, return nil and let it re-import
        return nil
    }

    /// Sanitize heritage chain by removing demo users
    /// - Parameters:
    ///   - chain: Array of user IDs in the heritage chain
    ///   - names: Optional array of display names (parallel to chain)
    ///   - sanitize: Whether to actually perform sanitization
    /// - Returns: Tuple of (sanitized chain, sanitized names)
    private func sanitizeHeritageChain(
        _ chain: [String]?,
        names: [String]?,
        sanitize: Bool
    ) -> (chain: [String], names: [String]) {
        guard let chain = chain else {
            return ([], [])
        }

        guard sanitize else {
            return (chain, names ?? [])
        }

        var sanitizedChain: [String] = []
        var sanitizedNames: [String] = []

        for (index, userId) in chain.enumerated() {
            if !DemoSocialBehaviorService.isDemoUser(userId) {
                sanitizedChain.append(userId)
                if let names = names, index < names.count {
                    sanitizedNames.append(names[index])
                }
            }
        }

        Log.info("Sanitized heritage chain", category: .firebase, metadata: [
            "originalCount": chain.count,
            "sanitizedCount": sanitizedChain.count,
            "removedDemoUsers": chain.count - sanitizedChain.count
        ])

        return (sanitizedChain, sanitizedNames)
    }
}

// MARK: - Errors

extension FirebaseShareService {
    enum ShareError: LocalizedError {
        case notAuthenticated
        case notAuthorized
        case shareNotFound
        case shareExpired
        case recipeNotFound
        case invalidShareData
        case cannotAcceptOwnShare
        case noRecipients
        case premiumRequired

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to share recipes"
            case .notAuthorized:
                return "You don't have permission to perform this action"
            case .shareNotFound:
                return "This share link is invalid or has been deleted"
            case .shareExpired:
                return "This share link has expired"
            case .recipeNotFound:
                return "The shared recipe could not be found"
            case .invalidShareData:
                return "The share data is invalid or corrupted"
            case .cannotAcceptOwnShare:
                return "You cannot accept your own share"
            case .noRecipients:
                return "You must select at least one person to share with"
            case .premiumRequired:
                return "Sharing recipes requires an active subscription"
            }
        }
    }
}

// MARK: - Global Convenience

extension FirebaseShareService {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    /// Note: Safe to use from any context - ServiceContainer is thread-safe
    nonisolated(unsafe) static var shared: FirebaseShareService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(FirebaseShareService.self)
        }
    }
}
