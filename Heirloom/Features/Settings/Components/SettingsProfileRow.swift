//
//  SettingsProfileRow.swift
//  Heirloom
//
//  Social Layer Phase 4: Reusable profile row for settings
//  Shows avatar preview + user name
//

import SwiftUI
import SwiftData
import FirebaseAuth

struct SettingsProfileRow: View {
    @Environment(\.firebaseAuth) private var firebaseAuth
    @Environment(\.modelContext) private var modelContext
    @Query private var allUserCredits: [UserCredits]

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    @State private var userProfile: UserProfile?
    @State private var showCreditsStore = false

    /// Current user's credits
    private var userCredits: UserCredits? {
        guard let userId = firebaseAuth.currentUserId else { return nil }
        return allUserCredits.first { $0.userId == userId }
    }

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
                Text(authDisplayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Show profile display name if different from auth name
                if let profileName = userProfile?.displayName,
                   profileName != authDisplayName {
                    Text(profileName)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Credits badge - tappable to open credits store
            Button {
                showCreditsStore = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "giftcard.fill")
                        .font(.caption2)
                    Text("\(userCredits?.availableCredits ?? 0)")
                        .font(HeirloomFonts.caption1.weight(.medium))
                }
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.familyGreen.opacity(0.12))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.vertical, HeirloomSpacing.xs)
        .task {
            await loadProfile()
        }
        .sheet(isPresented: $showCreditsStore) {
            if let userId = firebaseAuth.currentUserId {
                let storeManager = CreditStoreManager(
                    logger: ServiceContainer.shared.resolve(LoggingService.self),
                    analytics: ServiceContainer.shared.resolve(AnalyticsService.self),
                    modelContext: modelContext,
                    userId: userId
                )
                CreditsStoreView(storeManager: storeManager, userCredits: userCredits)
            }
        }
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        // Priority 1: Profile photo from UserProfile (uploaded by user)
        if let profilePhotoURL = userProfile?.photoURL,
           let url = URL(string: profilePhotoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    authAvatarOrPlaceholder
                case .empty:
                    ProgressView()
                @unknown default:
                    authAvatarOrPlaceholder
                }
            }
        } else {
            authAvatarOrPlaceholder
        }
    }

    // Fallback to Firebase Auth photo or placeholder
    @ViewBuilder
    private var authAvatarOrPlaceholder: some View {
        if let photoURL = firebaseAuth.currentUser?.photoURL {
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

    private var authDisplayName: String {
        firebaseAuth.currentUser?.displayName ?? "User"
    }

    private var initials: String {
        // Use profile display name if available, otherwise auth name
        let name = userProfile?.displayName ?? authDisplayName
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

    // MARK: - Actions

    private func loadProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUserProfile()
            await MainActor.run {
                self.userProfile = profile
            }
        } catch {
            // Silently fail - just show auth info if profile can't be loaded
            Log.debug("Could not load profile for settings row", category: .social)
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
