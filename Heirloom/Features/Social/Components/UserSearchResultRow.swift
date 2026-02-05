//
//  UserSearchResultRow.swift
//  Heirloom
//
//  Phase 7: User Discovery
//  Displays a single user search result
//

import SwiftUI

struct UserSearchResultRow: View {
    let user: UserSearchResult

    // MARK: - Email Masking Helper

    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }

        let username = String(parts[0])
        let domain = String(parts[1])

        if username.count <= 2 {
            return "\(username.prefix(1))***@\(domain)"
        }

        let visibleCount = min(max(Int(Double(username.count) * 0.4), 1), 10)
        let finalVisibleCount: Int
        if visibleCount >= username.count - 1 {
            finalVisibleCount = max(username.count - 2, 1)
        } else {
            finalVisibleCount = visibleCount
        }

        let visiblePart = username.prefix(finalVisibleCount)
        return "\(visiblePart)***@\(domain)"
    }

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
            AsyncImage(url: user.photoURL.flatMap(URL.init)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle()
                    .fill(HeirloomColors.tomato.opacity(0.2))
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.tomato)
                    )
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Demo badge when applicable
                    if user.shouldShowDemoBadge {
                        DemoBadge()
                    }
                }

                // Show masked email for disambiguation (especially important for duplicate names)
                if let email = user.email {
                    Text(maskEmail(email))
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText.opacity(0.8))
                }

                if let bio = user.bio {
                    Text(bio)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }
}
