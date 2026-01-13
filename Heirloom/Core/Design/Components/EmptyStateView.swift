import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(HeirloomColors.warmGray.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            }

            // Text
            VStack(spacing: HeirloomSpacing.sm) {
                Text(title)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(message)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)

            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.top, HeirloomSpacing.md)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HeirloomColors.appBackground)
    }
}

// MARK: - Preset Empty States

extension EmptyStateView {
    static func noRecipes(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "book.closed",
            title: "Add your first recipe",
            message: "Import from a cooking video, scan a cookbook page, paste a website link, or type it in manually.\n\nYour collection starts here.",
            actionTitle: "Add Recipe",
            action: action
        )
    }

    static func noSearchResults(query: String, clearAction: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results Found",
            message: "No recipes match \"\(query)\". Try a different search term or adjust your filters.",
            actionTitle: "Clear Search",
            action: clearAction
        )
    }

    static func noFilterResults(clearAction: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "line.3.horizontal.decrease.circle",
            title: "No Matching Recipes",
            message: "No recipes match your current filters. Try adjusting your filter settings.",
            actionTitle: "Clear Filters",
            action: clearAction
        )
    }

    static func emptyShoppingList(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "cart.fill.badge.plus",
            title: "Ready to Shop?",
            message: "Your shopping list is empty. Browse your recipes and tap the cart icon on any recipe to add its ingredients here.\n\nWe'll automatically combine duplicate items and organize everything for you.",
            actionTitle: "Browse Recipes",
            action: action
        )
    }

    static func noCollections(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "folder",
            title: "No Collections Yet",
            message: "Organize your recipes into collections like \"Weeknight Dinners\" or \"Holiday Baking\".",
            actionTitle: "Create Collection",
            action: action
        )
    }

    static func noDinnerParties(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.3.fill",
            title: "No Dinner Parties",
            message: "Plan your next gathering by creating a dinner party. Share recipes and combine shopping lists with friends.",
            actionTitle: "Create Dinner Party",
            action: action
        )
    }

    static func noSharedRecipes() -> EmptyStateView {
        EmptyStateView(
            icon: "square.and.arrow.up",
            title: "No Shared Recipes",
            message: "Recipes shared with you will appear here. Friends and family can share their favorite recipes with you.",
            actionTitle: nil,
            action: nil
        )
    }

    static func offline() -> EmptyStateView {
        EmptyStateView(
            icon: "wifi.slash",
            title: "You're Offline",
            message: "Connect to the internet to import recipes from the web or sync with iCloud.",
            actionTitle: nil,
            action: nil
        )
    }

    static func importError(retry: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Import Failed",
            message: "We couldn't import that recipe. Check your connection and make sure the URL points to a recipe page.",
            actionTitle: "Try Again",
            action: retry
        )
    }

    static func permissionDenied(type: PermissionType, action: @escaping () -> Void) -> EmptyStateView {
        let (icon, title, message) = type.content
        return EmptyStateView(
            icon: icon,
            title: title,
            message: message,
            actionTitle: "Open Settings",
            action: action
        )
    }

    enum PermissionType {
        case camera
        case reminders
        case notifications

        var content: (icon: String, title: String, message: String) {
            switch self {
            case .camera:
                return (
                    "camera.fill",
                    "Camera Access Required",
                    "To scan cookbook pages, Heirloom needs access to your camera. You can enable this in Settings."
                )
            case .reminders:
                return (
                    "checklist",
                    "Reminders Access Required",
                    "To export shopping lists to Reminders, Heirloom needs permission. You can enable this in Settings."
                )
            case .notifications:
                return (
                    "bell.fill",
                    "Notifications Disabled",
                    "Enable notifications to get alerts when cooking timers complete and for dinner party updates."
                )
            }
        }
    }
}

// MARK: - Preview

#Preview("No Recipes") {
    EmptyStateView.noRecipes {
        Log.debug("Preview: Add recipe tapped", category: .ui)
    }
}

#Preview("No Search Results") {
    EmptyStateView.noSearchResults(query: "chocolate cake") {
        Log.debug("Preview: Clear search tapped", category: .ui)
    }
}

#Preview("Empty Shopping List") {
    EmptyStateView.emptyShoppingList {
        Log.debug("Preview: Browse recipes tapped", category: .ui)
    }
}

#Preview("Offline") {
    EmptyStateView.offline()
}
