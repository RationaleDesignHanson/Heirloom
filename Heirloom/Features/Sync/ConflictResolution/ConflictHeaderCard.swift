//
//  ConflictHeaderCard.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import SwiftUI

/// Header card showing conflict summary at top of resolution UI
struct ConflictHeaderCard: View {
    let recipeTitle: String
    let conflictCount: Int
    let sourceDevice: String?
    let sourceUser: String?

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Icon + Title
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.conflictAlert)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Merge Recipe Changes")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(recipeTitle)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            // Conflict summary
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(HeirloomColors.conflictAlert)
                    .font(.caption)

                Text(conflictSummaryText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Attribution (who made the changes)
            if let attribution = attributionText {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "person.circle")
                        .foregroundStyle(HeirloomColors.conflictInfo)
                        .font(.caption)

                    Text(attribution)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictBannerBackground)
        .cornerRadius(12)
        .shadow(color: HeirloomColors.cardShadow, radius: 4, x: 0, y: 2)
    }

    // MARK: - Computed Text

    private var conflictSummaryText: String {
        if conflictCount == 1 {
            return "1 field needs your attention"
        } else {
            return "\(conflictCount) fields need your attention"
        }
    }

    private var attributionText: String? {
        if let user = sourceUser {
            return "Changes from \(user)"
        } else if let device = sourceDevice {
            return "Changes from \(device)"
        } else {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // With user attribution
        ConflictHeaderCard(
            recipeTitle: "Grandma's Lasagna",
            conflictCount: 3,
            sourceDevice: "Mom's iPad",
            sourceUser: "Mom"
        )

        // With device attribution only
        ConflictHeaderCard(
            recipeTitle: "Chocolate Chip Cookies",
            conflictCount: 1,
            sourceDevice: "Your iPhone",
            sourceUser: nil
        )

        // No attribution
        ConflictHeaderCard(
            recipeTitle: "Banana Bread",
            conflictCount: 5,
            sourceDevice: nil,
            sourceUser: nil
        )
    }
    .padding()
    .background(HeirloomColors.cream)
}
