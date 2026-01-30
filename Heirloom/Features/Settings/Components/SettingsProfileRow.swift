//
//  SettingsProfileRow.swift
//  Heirloom
//
//  Social Layer Phase 4: Reusable profile row for settings
//  Shows avatar preview + user name
//

import SwiftUI
import FirebaseAuth

struct SettingsProfileRow: View {
    @Environment(\.firebaseAuth) private var firebaseAuth

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar preview
            avatarView
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
                )

            // User info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                if let email = firebaseAuth.currentUser?.email {
                    Text(email)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.vertical, HeirloomSpacing.xs)
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let photoURL = firebaseAuth.currentUser?.photoURL {
            // User has profile photo
            AsyncImage(url: photoURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderAvatar
                case .empty:
                    ProgressView()
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

    // MARK: - Computed Properties

    private var displayName: String {
        firebaseAuth.currentUser?.displayName ?? "User"
    }

    private var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            // First and last initial
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            // Just first initial
            return String(name.prefix(1)).uppercased()
        }
    }
}

#Preview("Signed In with Photo") {
    List {
        SettingsProfileRow()
    }
}

#Preview("Signed In No Photo") {
    List {
        SettingsProfileRow()
    }
}
