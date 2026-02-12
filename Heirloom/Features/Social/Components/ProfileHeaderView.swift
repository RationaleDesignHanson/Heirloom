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
    let directSharesCount: Int
    let publicSharesCount: Int
    let onEditProfile: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Top row: Avatar + Name/Location + Edit
            HStack(spacing: HeirloomSpacing.md) {
                // Avatar
                profileAvatar

                // Name and Location
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile?.displayName ?? "Your Name")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(.white)

                    if let location = profile?.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 12))
                            Text(location)
                                .font(HeirloomFonts.subheadline)
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer()

                // Edit button
                Button {
                    onEditProfile()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            // Divider
            Rectangle()
                .fill(.white.opacity(0.15))
                .frame(height: 1)

            // Bottom row: Stats across full width
            HStack {
                statItem(count: connectionsCount, label: "Connections")

                if directSharesCount > 0 {
                    Spacer()
                    statItem(count: directSharesCount, label: "Shared")
                }

                if publicSharesCount > 0 {
                    Spacer()
                    statItem(count: publicSharesCount, label: "Public")
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.familyGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: HeirloomColors.familyGreen.opacity(0.3), radius: 8, y: 4)
    }

    // MARK: - Components

    @ViewBuilder
    private var profileAvatar: some View {
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
            .frame(width: 60, height: 60)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
            )
        } else {
            avatarPlaceholder
        }
    }

    private func statItem(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(HeirloomFonts.title3)
                .foregroundStyle(.white)
            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.white.opacity(0.2))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.8))
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
            )
    }
}

