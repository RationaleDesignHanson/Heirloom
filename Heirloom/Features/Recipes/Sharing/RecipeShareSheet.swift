import SwiftUI
import SwiftData
import CloudKit

/// Sheet for sharing a recipe with friends/family via CKShare
/// Provides options for share method, permissions, and customization
struct RecipeShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let recipe: Recipe

    @State private var isCreatingShare = false
    @State private var shareError: Error?
    @State private var createdShare: CKShare?
    @State private var showShareSheet = false

    // Share options
    @State private var personalMessage = ""
    @State private var sharerName = ""
    @State private var permission: ShareOptions.Permission = .readOnly
    @State private var includeCardBack = true
    @State private var includeRating = true
    @State private var allowReSharing = true
    @State private var expirationDuration: ShareOptions.ExpirationDuration?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Recipe Preview
                    recipePreviewCard

                    // Share Options
                    shareOptionsSection

                    // Share Button
                    shareButton
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(Color(hex: "FDF6E3"))
            .navigationTitle("Share Recipe")
            .preferredColorScheme(.light)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Share Error", isPresented: .constant(shareError != nil)) {
                Button("OK") {
                    shareError = nil
                }
            } message: {
                if let error = shareError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Recipe Preview

    private var recipePreviewCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("You're Sharing")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.warmGray)

            HStack(spacing: HeirloomSpacing.md) {
                // Recipe Image
                if let imageFileName = recipe.imageFileName,
                   let image = ImageStorageService.shared.loadImage(fileName: imageFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(HeirloomColors.warmGray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "fork.knife")
                                .font(.title)
                                .foregroundStyle(HeirloomColors.warmGray)
                        }
                }

                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text(recipe.title)
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.charcoal)

                    if let servings = recipe.servings {
                        Text(servings)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.warmGray)
                    }

                    HStack(spacing: HeirloomSpacing.xs) {
                        if let prepTime = recipe.prepTime, !prepTime.isEmpty {
                            Label(prepTime, systemImage: "clock")
                                .font(HeirloomFonts.caption2)
                        }
                        if let cookTime = recipe.cookTime, !cookTime.isEmpty {
                            Label(cookTime, systemImage: "flame")
                                .font(HeirloomFonts.caption2)
                        }
                    }
                    .foregroundStyle(HeirloomColors.warmGray)
                }

                Spacer()
            }
        }
        .padding(HeirloomSpacing.md)
        .background(Color.white)
        .cornerRadius(16)
    }

    // MARK: - Share Options

    private var shareOptionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
            Text("Share Options")
                .font(HeirloomFonts.headline)
                .foregroundStyle(HeirloomColors.charcoal)

            // Personal Message
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Personal Message (Optional)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.warmGray)

                TextField("Add a note...", text: $personalMessage, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }

            // Your Name
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Your Name (Optional)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.warmGray)

                TextField("e.g., Mom, Grandma, Sarah", text: $sharerName)
                    .textFieldStyle(.roundedBorder)
            }

            // Permission Level
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Permission")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.warmGray)

                Picker("Permission", selection: $permission) {
                    ForEach(ShareOptions.Permission.allCases, id: \.self) { perm in
                        Text(perm.displayName).tag(perm)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Toggles
            VStack(spacing: HeirloomSpacing.md) {
                Toggle("Include Card Back Design", isOn: $includeCardBack)
                    .font(HeirloomFonts.body)

                Toggle("Include My Rating", isOn: $includeRating)
                    .font(HeirloomFonts.body)

                Toggle("Allow Re-Sharing", isOn: $allowReSharing)
                    .font(HeirloomFonts.body)
            }

            // Expiration (Optional)
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Link Expiration (Optional)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.warmGray)

                Picker("Expiration", selection: $expirationDuration) {
                    Text("Never").tag(nil as ShareOptions.ExpirationDuration?)
                    ForEach(ShareOptions.ExpirationDuration.allCases, id: \.self) { duration in
                        Text(duration.displayName).tag(duration as ShareOptions.ExpirationDuration?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            createAndShare()
        } label: {
            HStack {
                if isCreatingShare {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Recipe")
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .disabled(isCreatingShare)
    }

    // MARK: - Actions

    private func createAndShare() {
        isCreatingShare = true

        Task {
            do {
                // Build share options
                let options = ShareOptions(
                    permission: permission,
                    personalMessage: personalMessage.isEmpty ? nil : personalMessage,
                    sharerName: sharerName.isEmpty ? nil : sharerName,
                    includeCardBack: includeCardBack,
                    includeRating: includeRating,
                    allowReSharing: allowReSharing,
                    expirationDuration: expirationDuration
                )

                // Create CKShare
                let share = try await RecipeShareService.shared.createShare(
                    for: recipe,
                    options: options,
                    context: modelContext
                )

                await MainActor.run {
                    createdShare = share
                    isCreatingShare = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    ToastManager.shared.success(
                        title: "Share Created",
                        message: "Recipe ready to share!"
                    )

                    // Present iOS share sheet directly
                    if let url = share.url {
                        presentShareSheet(url: url)
                    }
                }

            } catch {
                await MainActor.run {
                    shareError = error
                    isCreatingShare = false

                    // Haptic feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)

                    print("❌ Share creation failed: \(error)")
                }
            }
        }
    }

    // MARK: - Share Sheet Presentation

    private func presentShareSheet(url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        // For iPad - set the popover presentation controller
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        rootViewController.present(activityVC, animated: true)
    }
}

// MARK: - Share Options Extension

extension ShareOptions.Permission {
    var displayName: String {
        switch self {
        case .readOnly: return "View Only"
        case .readWrite: return "Can Edit"
        }
    }

    static var allCases: [ShareOptions.Permission] {
        return [.readOnly, .readWrite]
    }
}

extension ShareOptions.ExpirationDuration {
    var displayName: String {
        switch self {
        case .oneDay: return "1 Day"
        case .oneWeek: return "1 Week"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        }
    }

    static var allCases: [ShareOptions.ExpirationDuration] {
        return [.oneDay, .oneWeek, .oneMonth, .threeMonths]
    }
}

// MARK: - Preview

#Preview {
    let container = try! ModelContainer(for: Recipe.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    let recipe = Recipe(
        title: "Grandma's Apple Pie",
        sourceType: .family,
        instructions: ["Mix ingredients", "Bake at 350°F"],
        servings: "8",
        prepTime: "30 min",
        cookTime: "45 min"
    )

    return RecipeShareSheet(recipe: recipe)
        .modelContainer(container)
}
