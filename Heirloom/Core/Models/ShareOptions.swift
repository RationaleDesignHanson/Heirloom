import Foundation

/// Configuration options for sharing a recipe via CKShare
struct ShareOptions {
    // MARK: - Content Inclusion

    /// Include the card back (personal notes, comments)
    var includeCardBack: Bool = true

    /// Include user's personal rating
    var includeRating: Bool = true

    /// Include user's personal notes to friends
    var includeNotes: Bool = true

    /// Include pinned comments
    var includePinnedComments: Bool = true

    /// Include all comments (not just pinned)
    var includeAllComments: Bool = false

    /// Include cooking history (times cooked)
    var includeCookingHistory: Bool = false

    /// Include stickers and annotations
    var includeStickers: Bool = true

    // MARK: - Personal Message

    /// Personal message to accompany share
    var personalMessage: String?

    /// Display name of sharer (auto-filled from iCloud)
    var sharerName: String?

    // MARK: - Share Permissions

    /// Permission level for share
    var permission: SharePermission = .readOnly

    /// Whether recipient can re-share
    var allowReSharing: Bool = true

    // MARK: - Expiration

    /// Expiration duration (nil = never expires)
    var expirationDuration: ExpirationDuration? = .sevenDays

    /// Whether to notify when share is accepted
    var notifyOnAccept: Bool = true

    // MARK: - Initialization

    init(
        includeCardBack: Bool = true,
        includeRating: Bool = true,
        includeNotes: Bool = true,
        includePinnedComments: Bool = true,
        includeAllComments: Bool = false,
        includeCookingHistory: Bool = false,
        includeStickers: Bool = true,
        personalMessage: String? = nil,
        sharerName: String? = nil,
        permission: SharePermission = .readOnly,
        allowReSharing: Bool = true,
        expirationDuration: ExpirationDuration? = .sevenDays,
        notifyOnAccept: Bool = true
    ) {
        self.includeCardBack = includeCardBack
        self.includeRating = includeRating
        self.includeNotes = includeNotes
        self.includePinnedComments = includePinnedComments
        self.includeAllComments = includeAllComments
        self.includeCookingHistory = includeCookingHistory
        self.includeStickers = includeStickers
        self.personalMessage = personalMessage
        self.sharerName = sharerName
        self.permission = permission
        self.allowReSharing = allowReSharing
        self.expirationDuration = expirationDuration
        self.notifyOnAccept = notifyOnAccept
    }
}

// MARK: - Supporting Types

extension ShareOptions {
    enum SharePermission: String, CaseIterable {
        case readOnly = "readOnly"
        case readWrite = "readWrite"

        var displayName: String {
            switch self {
            case .readOnly: return "View Only"
            case .readWrite: return "Can Edit"
            }
        }

        var description: String {
            switch self {
            case .readOnly:
                return "Recipient can view and copy the recipe, but cannot modify your original"
            case .readWrite:
                return "Recipient can edit the recipe, and changes will sync back to you"
            }
        }

        var iconName: String {
            switch self {
            case .readOnly: return "eye.fill"
            case .readWrite: return "pencil.circle.fill"
            }
        }
    }

    enum ExpirationDuration: Int, CaseIterable {
        case oneDay = 1
        case threeDays = 3
        case sevenDays = 7
        case thirtyDays = 30
        case ninetyDays = 90
        case never = 0

        var displayName: String {
            switch self {
            case .oneDay: return "1 Day"
            case .threeDays: return "3 Days"
            case .sevenDays: return "7 Days"
            case .thirtyDays: return "30 Days"
            case .ninetyDays: return "90 Days"
            case .never: return "Never"
            }
        }

        var description: String {
            switch self {
            case .never:
                return "Link never expires"
            default:
                return "Link expires after \(displayName.lowercased())"
            }
        }

        /// Calculate expiration date from now
        var expirationDate: Date? {
            guard self != .never else { return nil }
            return Calendar.current.date(byAdding: .day, value: self.rawValue, to: Date())
        }

        var iconName: String {
            switch self {
            case .never: return "infinity"
            default: return "clock.fill"
            }
        }
    }
}

// MARK: - Presets

extension ShareOptions {
    /// Default share options (safe, privacy-focused)
    static var `default`: ShareOptions {
        ShareOptions(
            includeCardBack: true,
            includeRating: true,
            includeNotes: true,
            includePinnedComments: true,
            includeAllComments: false,
            includeCookingHistory: false,
            permission: .readOnly,
            expirationDuration: .sevenDays
        )
    }

    /// Minimal share (recipe only, no personalization)
    static var minimal: ShareOptions {
        ShareOptions(
            includeCardBack: false,
            includeRating: false,
            includeNotes: false,
            includePinnedComments: false,
            includeAllComments: false,
            includeCookingHistory: false,
            includeStickers: false,
            permission: .readOnly,
            expirationDuration: .sevenDays
        )
    }

    /// Full share (everything included)
    static var full: ShareOptions {
        ShareOptions(
            includeCardBack: true,
            includeRating: true,
            includeNotes: true,
            includePinnedComments: true,
            includeAllComments: true,
            includeCookingHistory: true,
            includeStickers: true,
            permission: .readOnly,
            allowReSharing: true,
            expirationDuration: .never
        )
    }

    /// Collaborative share (editable by recipient)
    static var collaborative: ShareOptions {
        ShareOptions(
            includeCardBack: true,
            includeRating: true,
            includeNotes: true,
            includePinnedComments: true,
            permission: .readWrite,
            allowReSharing: false,
            expirationDuration: .never
        )
    }
}

// MARK: - Computed Properties

extension ShareOptions {
    /// Human-readable summary of what's included
    var inclusionSummary: String {
        var items: [String] = []

        if includeCardBack { items.append("card back") }
        if includeRating { items.append("rating") }
        if includeNotes { items.append("notes") }
        if includePinnedComments { items.append("comments") }
        if includeStickers { items.append("stickers") }

        if items.isEmpty {
            return "Recipe only"
        } else if items.count == 1 {
            return "Recipe + \(items[0])"
        } else {
            let last = items.removeLast()
            return "Recipe + \(items.joined(separator: ", ")) and \(last)"
        }
    }

    /// Whether any personalization is included
    var includesPersonalization: Bool {
        includeCardBack || includeRating || includeNotes || includePinnedComments || includeStickers
    }

    /// Privacy level indicator
    var privacyLevel: String {
        if !includesPersonalization {
            return "Public"
        } else if includeAllComments || includeCookingHistory {
            return "Very Personal"
        } else {
            return "Personal"
        }
    }
}
