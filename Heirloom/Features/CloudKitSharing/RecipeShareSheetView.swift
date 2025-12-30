import SwiftUI
import SwiftData

struct RecipeShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var shareService = PublicShareService.shared

    let recipe: Recipe

    @State private var message: String = ""
    @State private var isSharing = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let shareURL = shareURL {
                    // Success State
                    successView(shareURL)
                } else {
                    // Input State
                    inputView
                }
            }
            .navigationTitle("Share Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if shareURL == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Share") {
                            shareRecipe()
                        }
                        .disabled(isSharing)
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
            .alert("Share Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .alert("Debug: CloudKit Status", isPresented: .init(
                get: { debugMessage != nil },
                set: { if !$0 { debugMessage = nil } }
            )) {
                Button("OK") { debugMessage = nil }
            } message: {
                Text(debugMessage ?? "")
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Recipe Preview
                recipePreviewCard

                // Message Section
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Add a Personal Message (Optional)")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    TextField("Why are you sharing this recipe?", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(HeirloomFonts.body)
                        .lineLimit(3...8)

                    Text("Your message will be visible to everyone who receives this recipe")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Info Section
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    Text("How Recipe Sharing Works")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    infoRow(
                        icon: "icloud.fill",
                        text: "Shared via iCloud securely"
                    )

                    infoRow(
                        icon: "person.2.fill",
                        text: "Recipient gets a complete copy"
                    )

                    infoRow(
                        icon: "clock.arrow.circlepath",
                        text: "Tracks recipe provenance"
                    )

                    infoRow(
                        icon: "heart.fill",
                        text: "Recipient can customize their copy"
                    )
                }

                // Error Message
                if let error = errorMessage {
                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)

                        Text(error)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                // Loading State
                if isSharing {
                    HStack {
                        Spacer()
                        VStack(spacing: HeirloomSpacing.sm) {
                            ProgressView()
                                .tint(HeirloomColors.tomato)

                            Text("Creating share link...")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    private var recipePreviewCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                placeholder: "fork.knife"
            )
            .aspectRatio(16/9, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(recipe.title)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                HStack(spacing: HeirloomSpacing.md) {
                    if let servings = recipe.servings {
                        metadataItem(icon: "person.2", text: servings)
                    }
                    if let prepTime = recipe.prepTime {
                        metadataItem(icon: "clock", text: prepTime)
                    }
                    if recipe.timesCooked > 0 {
                        metadataItem(icon: "flame.fill", text: "\(recipe.timesCooked)x")
                    }
                }
            }
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func metadataItem(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(HeirloomFonts.caption1)
        }
        .foregroundStyle(HeirloomColors.secondaryText)
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 24)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Success View

    private func successView(_ url: URL) -> some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Success Icon
            ZStack {
                Circle()
                    .fill(HeirloomColors.familyGreen.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(HeirloomColors.familyGreen)
            }

            VStack(spacing: HeirloomSpacing.sm) {
                Text("Recipe Ready to Share!")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Your share link is ready. Choose how you'd like to send it.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.xl)
                
                // Show the actual URL for debugging
                Text(url.absoluteString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(HeirloomColors.warmGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.md)
                    .padding(.top, HeirloomSpacing.sm)
            }

            Spacer()

            // Action Buttons
            VStack(spacing: HeirloomSpacing.md) {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share Link", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .font(HeirloomFonts.bodyBold)
                        .cornerRadius(12)
                }

                Button {
                    UIPasteboard.general.string = url.absoluteString

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    ToastManager.shared.success(title: "Link copied!")
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundStyle(HeirloomColors.primaryText)
                        .font(HeirloomFonts.bodyBold)
                        .cornerRadius(12)
                }

                Button("Done") {
                    dismiss()
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Actions

    private func shareRecipe() {
        isSharing = true
        errorMessage = nil
        
        Task {
            do {
                // Create share options with personal message
                var options = ShareOptions.default
                options.personalMessage = message.isEmpty ? nil : message
                
                print("🚀 Starting share for: \(recipe.title)")
                
                // Use the public share service
                let url = try await shareService.shareRecipe(recipe, options: options)
                
                print("✅✅✅ SHARE COMPLETE - URL: \(url.absoluteString)")
                
                await MainActor.run {
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    
                    shareURL = url
                    isSharing = false
                    
                    // Show alert to confirm CloudKit save worked
                    debugMessage = "CloudKit save succeeded!\nShare ID: \(url.lastPathComponent)"
                }
            } catch {
                print("❌❌❌ SHARE FAILED: \(error)")
                
                await MainActor.run {
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                    
                    errorMessage = "Share failed: \(error.localizedDescription)"
                    isSharing = false
                }
            }
        }
    }
    
    @State private var debugMessage: String?
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    RecipeShareSheetView(recipe: .example)
        .toastContainer()
}
