//
//  ProfileView.swift
//  Heirloom
//
//  Social Layer Phase 5: Profile View
//  Display user profile with edit and privacy controls
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseAuth) private var firebaseAuth

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var showEditProfile = false
    @State private var showPrivacySettings = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let profile = profile {
                    profileContent(profile)
                } else {
                    emptyView
                }
            }
            .navigationTitle("My Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProfile()
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = profile {
                    EditProfileView(profile: $profile)
                        .onDisappear {
                            Task {
                                await loadProfile()
                            }
                        }
                }
            }
            .sheet(isPresented: $showPrivacySettings) {
                if let profile = profile {
                    PrivacySettingsView(
                        privacySettings: $profile.privacySettings,
                        onSave: {
                            Task {
                                await savePrivacySettings()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.xl) {
                // Avatar & Basic Info
                VStack(spacing: HeirloomSpacing.md) {
                    // Avatar
                    if let photoURL = profile.photoURL, let url = URL(string: photoURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 2)
                                    )
                            case .failure, .empty:
                                placeholderAvatar
                            @unknown default:
                                placeholderAvatar
                            }
                        }
                    } else {
                        placeholderAvatar
                    }

                    // Display Name
                    Text(profile.displayName)
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Handle
                    if let handle = profile.handle {
                        Text("@\(handle)")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Location
                    if let location = profile.location {
                        HStack(spacing: HeirloomSpacing.xs) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text(location)
                                .font(HeirloomFonts.caption1)
                        }
                        .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Bio
                    if let bio = profile.bio {
                        Text(bio)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, HeirloomSpacing.lg)
                    }

                    // Website
                    if let websiteURL = profile.websiteURL, let url = URL(string: websiteURL) {
                        Link(destination: url) {
                            HStack(spacing: HeirloomSpacing.xs) {
                                Image(systemName: "link")
                                    .font(.caption)
                                Text(websiteURL)
                                    .font(HeirloomFonts.caption1)
                            }
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    }
                }
                .padding(.top, HeirloomSpacing.md)

                // Stats
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: HeirloomSpacing.md
                ) {
                    ProfileStatCard(
                        icon: "person.2.fill",
                        value: "\(profile.connectionCount)",
                        label: "Connections",
                        color: HeirloomColors.tomato
                    )

                    ProfileStatCard(
                        icon: "doc.text.fill",
                        value: "\(profile.sharedRecipeCount)",
                        label: "Shared",
                        color: .blue
                    )

                    ProfileStatCard(
                        icon: "arrow.triangle.branch",
                        value: "\(profile.heritageGenerationCount)",
                        label: "Generations",
                        color: .green
                    )
                }
                .padding(.horizontal, HeirloomSpacing.md)

                // Cuisine Interests
                if let specialties = profile.specialties, !specialties.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Cooking Interests")
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)

                        FlowLayout(spacing: HeirloomSpacing.xs) {
                            ForEach(specialties, id: \.self) { cuisine in
                                Text(cuisine)
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.primaryText)
                                    .padding(.horizontal, HeirloomSpacing.sm)
                                    .padding(.vertical, HeirloomSpacing.xs)
                                    .background(HeirloomColors.warmGray.opacity(0.15))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.md)
                }

                // Action Buttons
                VStack(spacing: HeirloomSpacing.md) {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Profile")
                        }
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(HeirloomSpacing.md)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                    }

                    Button {
                        showPrivacySettings = true
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Privacy Settings")
                        }
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(HeirloomSpacing.md)
                        .background(HeirloomColors.warmGray.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, HeirloomSpacing.md)

                // Spacer
                Color.clear.frame(height: HeirloomSpacing.lg)
            }
        }
        .background(HeirloomColors.appBackground)
        .refreshable {
            await loadProfile()
        }
    }

    // MARK: - Placeholder Avatar

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
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
            )
            .overlay(
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 2)
            )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading profile...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Error Loading Profile")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.lg)

            Button {
                Task {
                    await loadProfile()
                }
            } label: {
                Text("Try Again")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
        .padding(HeirloomSpacing.lg)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "person.circle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("No Profile Found")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Unable to load your profile")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.lg)
    }

    // MARK: - Actions

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedProfile = try await profileService.fetchCurrentUserProfile()
            await MainActor.run {
                profile = fetchedProfile
                isLoading = false
            }
            Log.info("Profile loaded successfully", category: .social)
        } catch {
            Log.error("Failed to load profile", category: .social, error: error)
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func savePrivacySettings() async {
        guard let profile = profile else { return }

        do {
            try await profileService.updateProfile(profile)
            Log.info("Privacy settings saved", category: .social)
            await MainActor.run {
                toastManager.success(title: "Privacy settings saved")
            }
        } catch {
            Log.error("Failed to save privacy settings", category: .social, error: error)
            await MainActor.run {
                toastManager.error(title: "Failed to save settings", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Flow Layout (Re-used from CuisineInterestPicker)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
            self.positions = positions
        }
    }
}

#Preview {
    ProfileView()
}
