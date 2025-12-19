import SwiftUI
import SwiftData

/// Complete sheet for sharing a recipe with customization options
/// Allows user to configure what's included, add personal message, and choose share method
struct RecipeShareSheet: View {
    let recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
            .alert("Share Created!", isPresented: $showSuccessMessage) {
                Button("Copy Link") {
                    if let url = shareURL {
                        UIPasteboard.general.string = url.absoluteString
                    }
                }
                Button("Share", action: presentShareSheet)
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your recipe is ready to share!")
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
                // Permission picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permission")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Picker("Permission", selection: $options.permission) {
                        ForEach(ShareOptions.SharePermission.allCases, id: \.self) { permission in
                            Label {
                                VStack(alignment: .leading) {
                                    Text(permission.displayName)
                                        .font(.subheadline)
                                    Text(permission.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: permission.iconName)
                            }
                            .tag(permission)
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
        // Pre-fill sharer name from iCloud if available
        // TODO: Fetch from iCloud user record
        options.sharerName = "You"
    }

    private func createShare() {
        Task {
            isSharing = true
            errorMessage = nil

            do {
                let share = try await RecipeShareService.shared.createShare(
                    for: recipe,
                    options: options,
                    context: modelContext
                )

                shareURL = RecipeShareService.shared.generateShareURL(from: share)
                showSuccessMessage = true
            } catch {
                errorMessage = "Failed to create share: \(error.localizedDescription)"
            }

            isSharing = false
        }
    }

    private func presentShareSheet() {
        guard let url = shareURL else { return }

        let activityVC = UIActivityViewController(
            activityItems: [url, createShareMessage()],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func createShareMessage() -> String {
        var message = "Check out this recipe I'm sharing with you: \(recipe.title)"

        if let personalMessage = options.personalMessage {
            message += "\n\n\(personalMessage)"
        }

        message += "\n\nShared from Heirloom"
        return message
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

// MARK: - Preview

#Preview("Recipe Share Sheet") {
    let recipe = Recipe(title: "Chocolate Chip Cookies")
    recipe.servings = "24 cookies"
    recipe.prepTime = "15 min"
    recipe.provenance = .sampleUserCreated()

    return RecipeShareSheet(recipe: recipe)
        .modelContainer(for: Recipe.self, inMemory: true)
}
