import SwiftUI
import CloudKit

struct PassDownView: View {
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe

    @State private var recipientName: String = ""
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
            .navigationTitle("Pass Down Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if shareURL == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Pass Down") {
                            passDownRecipe()
                        }
                        .disabled(recipientName.trimmingCharacters(in: .whitespaces).isEmpty || isSharing)
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Special Header
                passDownHeader

                // Provenance Chain
                provenanceSection

                // Recipient Section
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Who are you passing this to?")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    TextField("Recipient's name", text: $recipientName)
                        .textFieldStyle(.roundedBorder)
                        .font(HeirloomFonts.body)

                    Text("This will be recorded in the recipe's history")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // Message Section
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Add a Personal Message")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    TextField("Share the story behind this recipe...", text: $message, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(HeirloomFonts.body)
                        .lineLimit(4...10)

                    Text("Tell them why this recipe is special and what it means to you")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                // What Happens Section
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    Text("What Happens When You Pass Down")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    infoRow(
                        icon: "person.2.fill",
                        title: "Attribution Preserved",
                        description: "Your name is recorded in the recipe's provenance"
                    )

                    infoRow(
                        icon: "number",
                        title: "Generation Tracked",
                        description: "Recipe generation count increments (currently Gen \(recipe.generationCount))"
                    )

                    infoRow(
                        icon: "heart.text.square.fill",
                        title: "Message Saved",
                        description: "Your message becomes part of the recipe's story"
                    )

                    infoRow(
                        icon: "doc.on.doc.fill",
                        title: "Complete Copy",
                        description: "Recipient gets all customizations and love marks"
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

                            Text("Creating generational link...")
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

    private var passDownHeader: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ZStack {
                Circle()
                    .fill(HeirloomColors.amber.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.down.heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.amber)
            }

            VStack(spacing: HeirloomSpacing.xs) {
                Text("Pass Down a Family Recipe")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Create a lasting connection by passing this recipe to the next generation")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(HeirloomColors.amber.opacity(0.05))
        .cornerRadius(12)
    }

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(HeirloomColors.tomato)
                Text("Recipe History")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                provenanceRow(
                    label: "Current Generation",
                    value: "Generation \(recipe.generationCount)",
                    icon: "number"
                )

                if recipe.timesCooked > 0 {
                    provenanceRow(
                        label: "Times Cooked",
                        value: "\(recipe.timesCooked) times",
                        icon: "flame.fill"
                    )
                }

                if let passedDownBy = recipe.passedDownBy {
                    provenanceRow(
                        label: "Received From",
                        value: passedDownBy,
                        icon: "person.fill"
                    )
                }

                if let message = recipe.passedDownMessage {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        HStack(spacing: 6) {
                            Image(systemName: "quote.opening")
                                .font(.caption2)
                                .foregroundStyle(HeirloomColors.secondaryText)
                            Text("Previous Message")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        Text(message)
                            .font(HeirloomFonts.body.italic())
                            .foregroundStyle(HeirloomColors.primaryText)
                            .padding(HeirloomSpacing.sm)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func provenanceRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
                .frame(width: 20)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Success View

    private func successView(_ url: URL) -> some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Success Animation
            ZStack {
                Circle()
                    .fill(HeirloomColors.amber.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(HeirloomColors.amber)
            }

            VStack(spacing: HeirloomSpacing.sm) {
                Text("Recipe Passed Down!")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Generation \(recipe.generationCount) → \(recipe.generationCount + 1)")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.amber)

                Text("This recipe's journey continues with \(recipientName)")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.xl)
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

    private func passDownRecipe() {
        let trimmedRecipient = recipientName.trimmingCharacters(in: .whitespaces)
        guard !trimmedRecipient.isEmpty else { return }

        isSharing = true
        errorMessage = nil

        CloudKitShareService.shared.passDownRecipe(
            recipe,
            to: trimmedRecipient,
            message: message
        ) { result in
            Task { @MainActor in
                isSharing = false

                switch result {
                case .success(let url):
                    // Haptic feedback with celebration
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Confetti or special animation could go here

                    shareURL = url

                case .failure(let error):
                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PassDownView(recipe: .example)
        .toastContainer()
}
