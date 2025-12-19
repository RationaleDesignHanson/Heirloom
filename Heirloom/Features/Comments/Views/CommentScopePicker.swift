import SwiftUI

/// Picker for selecting comment visibility scope
struct CommentScopePicker: View {
    @Binding var selectedScope: CommentScope
    let showPublicOption: Bool

    init(selectedScope: Binding<CommentScope>, showPublicOption: Bool = false) {
        self._selectedScope = selectedScope
        self.showPublicOption = showPublicOption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Who can see this comment?")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            VStack(spacing: HeirloomSpacing.xs) {
                // Private option
                scopeOption(.private)

                // Lineage option
                scopeOption(.lineage)

                // Public option (if enabled)
                if showPublicOption {
                    scopeOption(.public)
                }
            }
        }
    }

    @ViewBuilder
    private func scopeOption(_ scope: CommentScope) -> some View {
        Button {
            selectedScope = scope
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                Image(systemName: scope.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedScope == scope ? HeirloomColors.tomato : HeirloomColors.charcoal)
                    .frame(width: 28)

                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(scope.displayName)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(scope.description)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                // Checkmark
                if selectedScope == scope {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedScope == scope ? HeirloomColors.cream : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        selectedScope == scope ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3),
                        lineWidth: selectedScope == scope ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// Sheet view for selecting comment scope
struct CommentScopeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedScope: CommentScope
    let showPublicOption: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Explanation
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Comment Privacy")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Choose who can see your comment when this recipe is shared.")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Picker
                    CommentScopePicker(
                        selectedScope: $selectedScope,
                        showPublicOption: showPublicOption
                    )

                    // Recommendation
                    recommendationCard
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Recommendation")
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text(recommendationText)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    private var recommendationText: String {
        switch selectedScope {
        case .private:
            return "Perfect for personal notes you don't want to share, like recipe critiques or ingredient substitutions you're testing."
        case .lineage:
            return "Great for helpful tips and tricks that will benefit anyone who gets this recipe from you. Your insights will follow the recipe through generations."
        case .public:
            return "Use this when you want to share broadly with the Heirloom community. Your comment will be visible to anyone viewing this recipe."
        }
    }
}

// MARK: - Compact Scope Indicator

/// Compact badge showing current comment scope
struct CommentScopeBadge: View {
    let scope: CommentScope
    let compact: Bool

    init(scope: CommentScope, compact: Bool = false) {
        self.scope = scope
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: scope.iconName)
                .font(.system(size: compact ? 10 : 12))

            if !compact {
                Text(scope.displayName)
                    .font(HeirloomFonts.caption2)
            }
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }

    private var badgeColor: Color {
        switch scope {
        case .private: return HeirloomColors.warmGray
        case .lineage: return HeirloomColors.tomato
        case .public: return .blue
        }
    }
}

// MARK: - Preview

#Preview("Scope Picker") {
    @Previewable @State var scope: CommentScope = .private

    VStack(spacing: HeirloomSpacing.xl) {
        CommentScopePicker(selectedScope: $scope)

        Divider()

        HStack {
            Text("Selected:")
            CommentScopeBadge(scope: scope)
        }
    }
    .padding()
}

#Preview("Scope Sheet") {
    @Previewable @State var scope: CommentScope = .lineage

    CommentScopeSheet(selectedScope: $scope, showPublicOption: true)
}

#Preview("Scope Badges") {
    VStack(spacing: HeirloomSpacing.md) {
        HStack(spacing: HeirloomSpacing.sm) {
            CommentScopeBadge(scope: .private)
            CommentScopeBadge(scope: .lineage)
            CommentScopeBadge(scope: .public)
        }

        HStack(spacing: HeirloomSpacing.sm) {
            CommentScopeBadge(scope: .private, compact: true)
            CommentScopeBadge(scope: .lineage, compact: true)
            CommentScopeBadge(scope: .public, compact: true)
        }
    }
    .padding()
}
