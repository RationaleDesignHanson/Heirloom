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
                Text(user.displayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

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
