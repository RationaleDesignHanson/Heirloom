//
//  ProfileHeaderView.swift
//  Heirloom
//
//  Profile header component for Kitchen Table view
//  Shows user avatar, name, location, and connection stats
//

import SwiftUI

struct ProfileHeaderView: View {
    let profile: UserProfile?
    let connectionsCount: Int
    let onEditProfile: () -> Void

    var body: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Avatar and Edit Button
            ZStack(alignment: .bottomTrailing) {
                if let photoURL = profile?.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            avatarPlaceholder
                        @unknown default:
                            avatarPlaceholder
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    avatarPlaceholder
                }

                // Edit button badge
                Button {
                    onEditProfile()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(HeirloomColors.tomato)
                                .frame(width: 28, height: 28)
                        )
                }
            }

            // Name and Location
            VStack(spacing: 4) {
                Text(profile?.displayName ?? "Your Name")
                    .font(HeirloomFonts.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.primaryText)

                if let location = profile?.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                        Text(location)
                            .font(HeirloomFonts.caption1)
                    }
                    .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            // Connection Stats
            HStack(spacing: HeirloomSpacing.xl) {
                StatView(
                    value: "\(connectionsCount)",
                    label: "Connections"
                )

                StatView(
                    value: "\(profile?.sharedRecipeCount ?? 0)",
                    label: "Shared"
                )
            }
            .padding(.top, HeirloomSpacing.sm)
        }
        .padding(.vertical, HeirloomSpacing.lg)
        .padding(.horizontal, HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(HeirloomColors.warmGray.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(HeirloomColors.warmGray)
            )
    }
}

private struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(HeirloomFonts.title3)
                .fontWeight(.bold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }
}
