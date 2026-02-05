//
//  ThemeCategorySection.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCategorySection: View {
    let category: ThemeCategory
    let themes: [RecipeTheme]
    @Binding var selectedIds: Set<String>
    let maxSelections: Int

    private var isAtMaxSelections: Bool {
        selectedIds.count >= maxSelections
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Section header
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HeirloomColors.tomato)

                Text(category.displayName)
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            .padding(.horizontal, HeirloomSpacing.md)

            // Horizontal scroll of theme cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HeirloomSpacing.sm) {
                    ForEach(themes.sorted(by: { $0.sortOrder < $1.sortOrder })) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: selectedIds.contains(theme.firebaseId),
                            isDisabled: isAtMaxSelections && !selectedIds.contains(theme.firebaseId),
                            onTap: {
                                toggleSelection(theme)
                            }
                        )
                    }
                }
                .padding(.horizontal, HeirloomSpacing.md)
            }
        }
    }

    private func toggleSelection(_ theme: RecipeTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedIds.contains(theme.firebaseId) {
                selectedIds.remove(theme.firebaseId)
            } else if selectedIds.count < maxSelections {
                selectedIds.insert(theme.firebaseId)

                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
}
