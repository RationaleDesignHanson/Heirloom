import SwiftUI
import SwiftData

/// Sheet for verifying ownership before publishing a recipe publicly
/// Shows before PublishRecipeSheet to ensure user attests to ownership
struct OwnershipVerificationSheet: View {
    let recipe: Recipe
    let onConfirmed: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasConfirmed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(HeirloomColors.familyGreen)

                // Title
                Text("Confirm you can share this")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .multilineTextAlignment(.center)

                // Body text
                Text("By publishing, you confirm this is your own recipe or you have permission to share it publicly.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)

                // Explanation bullets
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    bulletPoint(
                        icon: "camera.fill",
                        text: "Recipes you photographed from handwritten cards"
                    )
                    bulletPoint(
                        icon: "heart.fill",
                        text: "Family recipes passed down to you"
                    )
                    bulletPoint(
                        icon: "pencil",
                        text: "Recipes you created yourself"
                    )
                }
                .padding()
                .background(HeirloomColors.cream)
                .cornerRadius(12)

                Spacer()

                // Checkbox
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        hasConfirmed.toggle()
                    }
                } label: {
                    HStack(spacing: HeirloomSpacing.md) {
                        Image(systemName: hasConfirmed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 24))
                            .foregroundStyle(hasConfirmed ? HeirloomColors.familyGreen : HeirloomColors.secondaryText)

                        Text("I confirm this is my recipe or I have permission")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .multilineTextAlignment(.leading)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding()
                .background(hasConfirmed ? HeirloomColors.familyGreen.opacity(0.1) : HeirloomColors.warmGray.opacity(0.1))
                .cornerRadius(12)

                // CTA Button
                Button {
                    // Record attestation timestamp
                    recipe.publisherAttestationAcceptedAt = Date()

                    Log.info("Publisher attestation accepted", category: .social, metadata: [
                        "recipeId": recipe.id.uuidString
                    ])

                    dismiss()
                    onConfirmed()
                } label: {
                    HStack(spacing: HeirloomSpacing.sm) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))

                        Text("Continue to publish")
                            .font(HeirloomFonts.bodyBold)
                    }
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasConfirmed ? HeirloomColors.familyGreen : HeirloomColors.warmGray)
                    .cornerRadius(12)
                }
                .disabled(!hasConfirmed)
                .animation(.easeInOut(duration: 0.2), value: hasConfirmed)
            }
            .padding(HeirloomSpacing.lg)
            .background(HeirloomColors.appBackground)
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

    @ViewBuilder
    private func bulletPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(HeirloomColors.familyGreen)
                .frame(width: 24)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)

    let recipe = Recipe(
        title: "Grandma's Apple Pie",
        sourceType: .scan,
        instructions: [],
        servings: "8"
    )

    container.mainContext.insert(recipe)

    return OwnershipVerificationSheet(recipe: recipe) {
        print("Confirmed!")
    }
    .modelContainer(container)
}
