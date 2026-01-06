import SwiftUI
import SwiftData

/// Complete sheet for sharing a recipe with customization options via Firebase
/// Allows user to configure what's included, add personal message, and choose share method
struct RecipeShareSheet: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseShare) private var firebaseShare

    // State
    @State private var options = ShareOptions.default
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Live preview
                    SharePreviewCard(recipe: recipe, options: options)
                        .padding(.horizontal)

                    // Customization section
                    customizationSection

                    // Personal message
                    personalMessageSection

                    // Share settings
                    shareSettingsSection

                    // Share button
                    shareButtonSection
                }
                .padding(.vertical)
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSuccessMessage) {
                if let url = shareURL {
                    ShareSuccessView(shareURL: url, recipeName: recipe.title) {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
        .onAppear {
            setupDefaultOptions()
        }
    }

    // MARK: - Customization Section

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "slider.horizontal.3", title: "What to Include")

            VStack(spacing: 12) {
                Toggle(isOn: $options.includeCardBack) {
                    ToggleLabel(
                        icon: "rectangle.portrait.fill",
                        title: "Card Back",
                        subtitle: "Personal notes and layout"
                    )
                }

                Toggle(isOn: $options.includeRating) {
                    ToggleLabel(
                        icon: "star.fill",
                        title: "My Rating",
                        subtitle: "Your personal rating"
                    )
                }

                Toggle(isOn: $options.includeNotes) {
                    ToggleLabel(
                        icon: "note.text",
                        title: "Notes to Friends",
                        subtitle: "Your personal message on card"
                    )
                }

                Toggle(isOn: $options.includePinnedComments) {
                    ToggleLabel(
                        icon: "pin.fill",
                        title: "Pinned Comments",
                        subtitle: "Highlighted tips and tricks"
                    )
                }

                Toggle(isOn: $options.includeAllComments) {
                    ToggleLabel(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "All Comments",
                        subtitle: "Include all comments, not just pinned"
                    )
                }
                .disabled(!options.includePinnedComments)

                Toggle(isOn: $options.includeStickers) {
                    ToggleLabel(
                        icon: "star.circle.fill",
                        title: "Stickers & Decorations",
                        subtitle: "Visual customizations"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Personal Message Section

    private var personalMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "quote.bubble.fill", title: "Personal Message")

            TextField("Add a personal note (optional)", text: Binding(
                get: { options.personalMessage ?? "" },
                set: { options.personalMessage = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .textFieldStyle(.roundedBorder)
            .lineLimit(3...6)
            .padding(.horizontal)

            Text("This message will appear at the top of the recipe for the recipient")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Share Settings Section

    private var shareSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "gearshape.fill", title: "Share Settings")

            VStack(spacing: 12) {
                // Sharer name text field (Bug #3 fix)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Name")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    TextField("Enter your name", text: Binding(
                        get: { options.sharerName ?? "" },
                        set: { options.sharerName = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
                    .autocorrectionDisabled(true)

                    Text("This will appear as the sender's name on the shared recipe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Share type picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Share Type")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Picker("Share Type", selection: $options.shareType) {
                        ForEach(ShareOptions.ShareType.allCases, id: \.self) { shareType in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(shareType.displayName)
                                        .font(.subheadline)
                                    Text(shareType.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: shareType.iconName)
                            }
                            .tag(shareType)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Expiration picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link Expires")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Picker("Expiration", selection: $options.expirationDuration) {
                        ForEach(ShareOptions.ExpirationDuration.allCases, id: \.self) { duration in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(duration.displayName)
                                        .font(.subheadline)
                                    Text(duration.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: duration.iconName)
                            }
                            .tag(duration as ShareOptions.ExpirationDuration?)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Allow re-sharing toggle
                Toggle(isOn: $options.allowReSharing) {
                    ToggleLabel(
                        icon: "arrow.triangle.branch",
                        title: "Allow Re-sharing",
                        subtitle: "Recipients can share with others"
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Share Button Section

    private var shareButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: createShare) {
                HStack {
                    if isSharing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Create Share Link")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(HeirloomColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSharing)

            Text(options.inclusionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func setupDefaultOptions() {
        // Pre-fill sharer name from user defaults or Firebase auth
        options.sharerName = "You"
    }

    private func createShare() {
        Task {
            isSharing = true
            errorMessage = nil

            do {
                // Create share via Firebase
                Log.info("Creating Firebase share for recipe", category: .firebase, metadata: ["title": recipe.title])
                let (shareId, url) = try await firebaseShare.createShare(
                    for: recipe,
                    options: options,
                    context: modelContext
                )

                shareURL = url
                Log.info("Firebase share created successfully", category: .firebase, metadata: ["shareId": shareId, "shareURL": url.absoluteString])
                DeviceLogger.shared.log("✅ Firebase share created for recipe: \(recipe.title)")
                showSuccessMessage = true

            } catch {
                Log.error("Firebase share creation failed", category: .firebase, metadata: ["error": error.localizedDescription])
                DeviceLogger.shared.log("❌ Firebase share creation failed: \(error.localizedDescription)", level: .error)

                // User-friendly error message
                errorMessage = error.localizedDescription
            }

            isSharing = false
        }
    }
}

// MARK: - Subcomponents

private struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(HeirloomColors.accent)
            Text(title)
                .font(.headline)
        }
        .padding(.horizontal)
    }
}

private struct ToggleLabel: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(HeirloomColors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Share Success View

private struct ShareSuccessView: View {
    let shareURL: URL
    let recipeName: String
    let onDismiss: () -> Void

    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .padding(.top, 32)

                // Success message
                VStack(spacing: 8) {
                    Text("Share Created!")
                        .font(.title2.bold())

                    Text("Your recipe is ready to share")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Share via iOS share sheet (Bug #4 fix)
                    ShareLink(item: shareURL, subject: Text("Check out this recipe!"), message: Text(createShareMessage())) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                            Text("Share Link")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Copy link button (Bug #6 fix)
                    Button {
                        UIPasteboard.general.string = shareURL.absoluteString
                        copied = true

                        // Reset after 2 seconds
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                            Text(copied ? "Copied!" : "Copy Link")
                        }
                        .font(.headline)
                        .foregroundStyle(HeirloomColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button("Done", action: onDismiss)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Share Created")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func createShareMessage() -> String {
        return "Check out this recipe: \(recipeName)\n\nShared from Heirloom"
    }
}

// MARK: - Preview

#Preview("Recipe Share Sheet") {
    let recipe = Recipe(title: "Chocolate Chip Cookies")
    recipe.servings = "24 cookies"
    recipe.prepTime = "15 min"
    recipe.provenance = .sampleUserCreated()

    return RecipeShareSheet(recipe: recipe)
        .modelContainer(for: Recipe.self, inMemory: true)
}
