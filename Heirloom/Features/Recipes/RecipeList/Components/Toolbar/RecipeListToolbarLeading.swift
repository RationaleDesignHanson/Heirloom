//
//  RecipeListToolbarLeading.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Leading toolbar item for RecipeListView
/// Shows filter button with badge, or cancel button during selection mode
struct RecipeListToolbarLeading: View {
    let isSelectionMode: Bool
    let isSyncing: Bool
    @Binding var showFilters: Bool
    let filters: RecipeFilters
    let onCancelSelection: () -> Void

    var body: some View {
        if isSelectionMode {
            Button("Cancel") {
                onCancelSelection()
            }
            .accessibilityLabel("Cancel selection")
        } else {
            HStack(spacing: HeirloomSpacing.sm) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("Syncing recipes")
                }

                Button {
                    showFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(filters.isActive ? HeirloomColors.tomato : HeirloomColors.primaryText)

                        if filters.activeFilterCount > 0 {
                            Text("\(filters.activeFilterCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .frame(width: 18, height: 18)
                                .background(HeirloomColors.tomato)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 1.5)
                                )
                                .offset(x: 6, y: -6)
                        }
                    }
                    .padding(4) // Add padding to prevent clipping
                }
                .accessibilityLabel(filters.isActive ? "Filters, \(filters.activeFilterCount) active" : "Filters")
                .accessibilityHint("Opens filter options for recipes")
            }
        }
    }
}
