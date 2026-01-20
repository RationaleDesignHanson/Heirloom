//
//  SelectionActionBar.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Bottom action bar shown during multi-selection mode
/// Provides delete and add-to-collection actions for selected recipes
struct SelectionActionBar: View {
    let selectedCount: Int
    let onDelete: () -> Void
    let onAddToCollection: () -> Void

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Button {
                onDelete()
            } label: {
                Label("Delete (\(selectedCount))", systemImage: "trash")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Delete \(selectedCount) selected recipes")

            Button {
                onAddToCollection()
            } label: {
                Label("Add to Collection", systemImage: "folder.badge.plus")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Add \(selectedCount) recipes to collection")
        }
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
