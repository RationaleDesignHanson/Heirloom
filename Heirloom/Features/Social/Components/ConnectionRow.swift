//
//  ConnectionRow.swift
//  Heirloom
//
//  Social Layer Phase 6: Reusable connection row component
//  Shows avatar, name, type, and activity info
//

import SwiftUI

struct ConnectionRow: View {
    let connection: Connection

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
            avatarView
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
                )

            // User info
            VStack(alignment: .leading, spacing: 4) {
                // Name
                Text(connection.connectedUserDisplayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Handle
                if let handle = connection.connectedUserHandle {
                    Text("@\(handle)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Recipe count
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(connection.recipesSharedCount) recipes shared")
                }
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let photoURL = connection.connectedUserPhotoURL,
           let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.tomato.opacity(0.8),
                        HeirloomColors.tomato.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initials)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = connection.connectedUserDisplayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(1)).uppercased()
        }
    }
}

#Preview {
    VStack {
        ConnectionRow(connection: Connection(
            id: "preview",
            userId: "user1",
            connectedUserId: "user2",
            connectedUserDisplayName: "Chef Julia",
            connectedUserPhotoURL: nil,
            status: .connected,
            initiatedBy: "user2",
            requestedAt: Date(),
            acceptedAt: Date(),
            sourceKitchenTableId: nil,
            recipesSharedCount: 12,
            recipesReceivedCount: 8,
            isFavorite: false,
            privateNote: nil,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
