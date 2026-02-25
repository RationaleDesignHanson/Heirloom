//
//  OnboardingProfileSetupScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-05.
//  Screen 7: Profile setup during onboarding (simplified)
//

import SwiftUI
import PhotosUI

/// Data collected from onboarding profile setup
struct OnboardingProfileData {
    var displayName: String
    var bio: String?
    var location: String?
    var websiteURL: String?
    var cuisines: [String]
    var avatarImage: UIImage?
}

/// Profile setup screen - Screen 7 of 7
/// Simplified: display name + optional photo only
struct OnboardingProfileSetupScreen: View {
    let onContinue: (OnboardingProfileData) -> Void

    @Environment(\.firebaseAuth) private var firebaseAuth
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var websiteURL: String = ""
    @State private var selectedCuisines: [String] = []
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isLoadingImage = false

    private let bioCharacterLimit = 160

    var body: some View {
        ZStack {
            // Background gradient (matching other onboarding screens)
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90), // Warm cream
                    Color(red: 0.95, green: 0.90, blue: 0.85)  // Soft beige
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                Text("7/7")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Set up your profile")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Just a name to get started.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Avatar picker
                        avatarPicker

                        // Form fields (simplified - just name)
                        VStack(spacing: 20) {
                            // Display name field
                            displayNameField
                        }
                        .padding(.horizontal, 24)

                        // Add more later hint
                        Text("You can add more details anytime in Settings.")
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 140) // Space for fixed bottom CTAs
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }

                // Fixed bottom CTAs
                bottomCTAs
            }
        }
        .onAppear {
            // Pre-populate display name from Firebase Auth
            if displayName.isEmpty, let authDisplayName = firebaseAuth.currentUser?.displayName {
                displayName = authDisplayName
            }
        }
    }

    // MARK: - Continue Button State

    private var isContinueEnabled: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Bottom CTAs

    private var bottomCTAs: some View {
        VStack(spacing: 12) {
            // Microcopy
            Text("You can update this anytime in your profile")
                .font(HeirloomFonts.caption2)
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.bottom, 4)

            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let profileData = OnboardingProfileData(
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    bio: bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines),
                    location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                    websiteURL: websiteURL.isEmpty ? nil : websiteURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    cuisines: selectedCuisines,
                    avatarImage: selectedImage
                )
                onContinue(profileData)
            }) {
                Text("Continue")
                    .font(.headline)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isContinueEnabled ? HeirloomColors.tomato : HeirloomColors.tomato.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 12, y: 6)
            }
            .disabled(!isContinueEnabled)

        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.90, blue: 0.85).opacity(0),
                    Color(red: 0.95, green: 0.90, blue: 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Avatar Picker

    private var avatarPicker: some View {
        ZStack(alignment: .bottomTrailing) {
            // Avatar image
            avatarImage
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 2)
                )

            // Camera button overlay
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    Circle()
                        .fill(HeirloomColors.tomato)
                        .frame(width: 32, height: 32)

                    if isLoadingImage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .disabled(isLoadingImage)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadPhoto(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let image = selectedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
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
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    // MARK: - Display Name Field

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display name")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)

            TextField("Your name", text: $displayName)
                .font(HeirloomFonts.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Bio Field

    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("About you")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)

                Spacer()

                Text("\(bio.count)/\(bioCharacterLimit)")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(
                        bio.count > bioCharacterLimit - 20 ?
                        HeirloomColors.tomato : HeirloomColors.secondaryText
                    )
            }

            TextField("Tell others about your cooking style", text: $bio, axis: .vertical)
                .font(HeirloomFonts.body)
                .lineLimit(3...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                )
                .onChange(of: bio) { _, newValue in
                    if newValue.count > bioCharacterLimit {
                        bio = String(newValue.prefix(bioCharacterLimit))
                    }
                }
        }
    }

    // MARK: - Location Field

    private var locationField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location (optional)")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)

            TextField("City, state, or country", text: $location)
                .font(HeirloomFonts.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Website Field

    private var websiteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Website (optional)")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)

            TextField("Blog, Instagram, or social link", text: $websiteURL)
                .font(HeirloomFonts.body)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Cuisine Section

    private var cuisineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CuisineInterestPicker(selectedCuisines: $selectedCuisines)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Photo Loading

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        isLoadingImage = true
        defer { isLoadingImage = false }

        // Retry logic for transient Photos library errors (e.g., helper process unavailable)
        var lastError: Error?
        let maxAttempts = 2

        for attempt in 1...maxAttempts {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    return
                }

                // Validate image size (max 10MB)
                if data.count > 10 * 1024 * 1024 {
                    Log.warning("Image too large for avatar", category: .onboarding, metadata: [
                        "size": "\(data.count / 1024 / 1024)MB"
                    ])
                    return
                }

                await MainActor.run {
                    selectedImage = uiImage
                }
                return
            } catch {
                lastError = error
                Log.warning("Photo load attempt \(attempt) failed: \(error.localizedDescription)", category: .onboarding)
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }

        if let lastError {
            Log.error("Failed to load photo after \(maxAttempts) attempts", category: .onboarding, error: lastError)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingProfileSetupScreen(
        onContinue: { profileData in
            print("Continue with name: \(profileData.displayName), bio: \(profileData.bio ?? "none"), cuisines: \(profileData.cuisines)")
        }
    )
}
