//
//  ThemeSelectionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI
import SwiftData

struct ThemeSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeTheme.sortOrder) private var themes: [RecipeTheme]

    @State private var selectedThemeIds: Set<String> = []
    @State private var isLoading = false

    let onComplete: ([String]) -> Void

    // Configuration
    private let minSelections = 2
    private let maxSelections = 5

    // Grouped themes by category
    private var groupedThemes: [(ThemeCategory, [RecipeTheme])] {
        let grouped = Dictionary(grouping: themes) { $0.category }
        return ThemeCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let themes = grouped[category], !themes.isEmpty else {
                    return nil
                }
                return (category, themes)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            // Theme categories
            if themes.isEmpty {
                loadingOrEmptyState
            } else {
                themesScrollView
            }

            // Continue button
            continueSection
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Text("Preserve culinary heritage")
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.primaryText)
                .multilineTextAlignment(.center)

            Text("Choose \(minSelections)-\(maxSelections) heritage themes to explore.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.lg)
        }
        .padding(.top, HeirloomSpacing.lg)
        .padding(.bottom, HeirloomSpacing.md)
    }

    // MARK: - Themes

    private var themesScrollView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.md) {
                ForEach(groupedThemes, id: \.0) { category, categoryThemes in
                    ThemeCategorySection(
                        category: category,
                        themes: categoryThemes,
                        selectedIds: $selectedThemeIds,
                        maxSelections: maxSelections
                    )
                }
            }
            .padding(.vertical, HeirloomSpacing.sm)
        }
    }

    private var loadingOrEmptyState: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)

            Text("Loading themes...")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()
        }
    }

    // MARK: - Continue Button

    private var continueSection: some View {
        VStack(spacing: HeirloomSpacing.xs) {
            // Selection counter
            if selectedThemeIds.count > 0 {
                Text("\(selectedThemeIds.count) of \(maxSelections) themes selected")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(canContinue ? HeirloomColors.tomato : HeirloomColors.secondaryText)
                    .padding(.top, HeirloomSpacing.xs)
            }

            // Continue button
            Button {
                completeSelection()
            } label: {
                HStack(spacing: HeirloomSpacing.xs) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")

                        if selectedThemeIds.count >= minSelections {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.sm + 4)
                .background(canContinue ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!canContinue || isLoading)

            // Skip button
            Button {
                skipSelection()
            } label: {
                Text("Skip for now")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .disabled(isLoading)

            // Helper text
            if selectedThemeIds.count < minSelections {
                Text("Select at least \(minSelections - selectedThemeIds.count) more, or skip")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            } else if selectedThemeIds.count == maxSelections {
                Text("Maximum themes selected")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(
            Rectangle()
                .fill(HeirloomColors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        )
    }

    // MARK: - Helpers

    private var canContinue: Bool {
        selectedThemeIds.count >= minSelections
    }

    private func completeSelection() {
        guard canContinue else { return }

        isLoading = true

        // Mark themes as selected in the model
        for theme in themes {
            theme.isSelected = selectedThemeIds.contains(theme.firebaseId)
        }

        try? modelContext.save()

        // Short delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(Array(selectedThemeIds))
        }
    }

    private func skipSelection() {
        // User chose to skip theme selection - complete with empty array
        onComplete([])
    }
}

// MARK: - Preview

#Preview {
    ThemeSelectionScreen { selectedIds in
        print("Selected: \(selectedIds)")
    }
    .modelContainer(for: RecipeTheme.self, inMemory: true)
}
