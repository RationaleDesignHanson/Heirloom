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
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
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

            // Name, Location, and Stats
            VStack(alignment: .leading, spacing: 4) {
                Text(profile?.displayName ?? "Your Name")
                    .font(HeirloomFonts.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                if let location = profile?.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption2)
                        Text(location)
                            .font(HeirloomFonts.caption1)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }

                // Compact stats row
                HStack(spacing: HeirloomSpacing.lg) {
                    VStack(spacing: 2) {
                        Text("\(connectionsCount)")
                            .font(HeirloomFonts.bodyBold)
                        Text("Connections")
                            .font(HeirloomFonts.caption2)
                    }

                    if directSharesCount > 0 || publicSharesCount > 0 {
                        Text("•")
                            .font(HeirloomFonts.caption2)
                            .opacity(0.5)
                            .padding(.horizontal, 8)

                        HStack(spacing: 16) {
                            if directSharesCount > 0 {
                                VStack(spacing: 2) {
                                    Text("\(directSharesCount)")
                                        .font(HeirloomFonts.bodyBold)
                                    Text("shared")
                                        .font(HeirloomFonts.caption2)
                                        .lineLimit(1)
                                }
                            }

                            if directSharesCount > 0 && publicSharesCount > 0 {
                                Text("·")
                                    .font(HeirloomFonts.caption2)
                                    .opacity(0.5)
                            }

                            if publicSharesCount > 0 {
                                VStack(spacing: 2) {
                                    Text("\(publicSharesCount)")
                                        .font(HeirloomFonts.bodyBold)
                                    Text("public")
                                        .font(HeirloomFonts.caption2)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding(.top, 2)
            }

            Spacer()

            // Edit button
            Button {
                onEditProfile()
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.familyGreen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: HeirloomColors.familyGreen.opacity(0.3), radius: 8, y: 4)
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

