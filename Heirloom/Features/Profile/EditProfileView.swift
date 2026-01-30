//
//  EditProfileView.swift
//  Heirloom
//
//  Social Layer Phase 5: Edit Profile View
//  Form for editing user profile information
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: UserProfile

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    @State private var displayName: String
    @State private var bio: String
    @State private var location: String
    @State private var selectedCuisines: [String]
    @State private var websiteURL: String
    @State private var handle: String

    @State private var isSaving = false
    @State private var isUploadingAvatar = false
    @State private var showHandleError = false
    @State private var handleErrorMessage = ""

    private let bioCharacterLimit = 160

    init(profile: Binding<UserProfile>) {
        self._profile = profile
        _displayName = State(initialValue: profile.wrappedValue.displayName)
        _bio = State(initialValue: profile.wrappedValue.bio ?? "")
        _location = State(initialValue: profile.wrappedValue.location ?? "")
        _selectedCuisines = State(initialValue: profile.wrappedValue.specialties ?? [])
        _websiteURL = State(initialValue: profile.wrappedValue.websiteURL ?? "")
        _handle = State(initialValue: profile.wrappedValue.handle ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()
                        AvatarPickerView(
                            currentPhotoURL: profile.photoURL,
                            onPhotoSelected: { image in
                                Task {
                                    await uploadAvatar(image)
                                }
                            }
                        )
                        Spacer()
                    }

                    if isUploadingAvatar {
                        HStack {
                            Spacer()
                            ProgressView("Uploading avatar...")
                                .font(HeirloomFonts.caption1)
                            Spacer()
                        }
                    }
                }

                // Basic Info
                Section {
                    TextField("Display Name", text: $displayName)
                        .autocorrectionDisabled()

                    TextField("@handle (optional)", text: $handle)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: handle) { _, newValue in
                            // Clean handle input (alphanumeric + underscore only)
                            let filtered = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if filtered != newValue {
                                handle = filtered
                            }
                        }

                    if showHandleError {
                        Text(handleErrorMessage)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Basic Info")
                } footer: {
                    Text("Your handle is used for @mentions and public profile URLs")
                }

                // Bio Section
                Section {
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(4...6)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > bioCharacterLimit {
                                bio = String(newValue.prefix(bioCharacterLimit))
                            }
                        }

                    HStack {
                        Spacer()
                        Text("\(bio.count)/\(bioCharacterLimit)")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(
                                bio.count > bioCharacterLimit - 20 ?
                                HeirloomColors.tomato : HeirloomColors.secondaryText
                            )
                    }
                } header: {
                    Text("About You")
                } footer: {
                    Text("Tell others about your cooking style and background")
                }

                // Location
                Section {
                    TextField("Location (optional)", text: $location)
                        .autocorrectionDisabled()
                } header: {
                    Text("Location")
                } footer: {
                    Text("City, state, or country")
                }

                // Cuisine Interests
                Section {
                    CuisineInterestPicker(selectedCuisines: $selectedCuisines)
                } header: {
                    Text("Cooking Interests")
                }

                // Website
                Section {
                    TextField("Website URL (optional)", text: $websiteURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("Website")
                } footer: {
                    Text("Link to your blog, Instagram, or other social media")
                }

                // Save Button
                Section {
                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .padding(.trailing, HeirloomSpacing.xs)
                            }
                            Text(isSaving ? "Saving..." : "Save Changes")
                            Spacer()
                        }
                    }
                    .disabled(isSaving || displayName.isEmpty)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func uploadAvatar(_ image: UIImage) async {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            let photoPath = try await profileService.uploadAvatar(image)
            await MainActor.run {
                profile.photoURL = photoPath
                toastManager.success(title: "Avatar uploaded")
            }
            Log.info("Avatar uploaded successfully", category: .social)
        } catch {
            Log.error("Failed to upload avatar", category: .social, error: error)
            await MainActor.run {
                toastManager.error(title: "Failed to upload avatar", message: error.localizedDescription)
            }
        }
    }

    private func saveProfile() async {
        // Validate display name
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            toastManager.error(title: "Display name is required")
            return
        }

        // Validate handle if provided
        if !handle.isEmpty {
            guard handle.count >= 3 && handle.count <= 30 else {
                showHandleError = true
                handleErrorMessage = "Handle must be 3-30 characters"
                return
            }

            // Check if handle is available (if changed)
            if handle != profile.handle {
                do {
                    let isAvailable = try await profileService.isHandleAvailable(handle)
                    if !isAvailable {
                        showHandleError = true
                        handleErrorMessage = "This handle is already taken"
                        return
                    }
                } catch {
                    Log.error("Failed to check handle availability", category: .social, error: error)
                }
            }
        }

        showHandleError = false
        isSaving = true
        defer { isSaving = false }

        // Update profile object
        await MainActor.run {
            profile.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.bio = bio.isEmpty ? nil : bio.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.location = location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.specialties = selectedCuisines.isEmpty ? nil : selectedCuisines
            profile.websiteURL = websiteURL.isEmpty ? nil : websiteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.handle = handle.isEmpty ? nil : handle.lowercased()
            profile.updatedAt = Date()
        }

        // Save to Firestore
        do {
            try await profileService.updateProfile(profile)
            Log.info("Profile updated successfully", category: .social)

            await MainActor.run {
                toastManager.success(title: "Profile saved")
                dismiss()
            }
        } catch {
            Log.error("Failed to save profile", category: .social, error: error)
            await MainActor.run {
                toastManager.error(title: "Failed to save profile", message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    @Previewable @State var profile = UserProfile(userId: "preview", displayName: "John Chef")

    EditProfileView(profile: $profile)
}
