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
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HeirloomColors.tomato)

                Text(category.displayName)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            .padding(.horizontal, 20)

            // Horizontal scroll of theme cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(themes.sorted(by: { $0.sortOrder < $1.sortOrder })) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: selectedIds.contains(theme.firebaseId),
                            isDisabled: isAtMaxSelections && !selectedIds.contains(theme.firebaseId),
                            onTap: {
                                toggleSelection(theme)
                            }
                        )
                        .frame(width: 180, height: 240)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 260)
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
