import SwiftUI
import SwiftData

struct CollectionCardView: View {
    @Bindable var collection: RecipeCollection

    @Environment(\.modelContext) private var modelContext

    private var recipeImages: [Recipe] {
        Array((collection.recipes ?? []).prefix(3))
    }

    /// Check if collection contains any recipes added within last 24 hours
    private var hasNewRecipes: Bool {
        guard let recipes = collection.recipes else { return false }
        return recipes.contains { $0.dateAdded.timeIntervalSinceNow > -86400 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Background section - custom/generated or recipe collage
            // Show custom/generated background if enabled OR if generated image exists
            if collection.useCustomBackground || collection.generatedBackgroundImagePath != nil {
                customBackgroundView
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // Image collage section
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        // Large image (60% width)
                        if let firstRecipe = recipeImages.first {
                            recipeImageView(firstRecipe)
                                .frame(width: geometry.size.width * 0.6)
                        } else {
                            placeholderView
                                .frame(width: geometry.size.width * 0.6)
                        }

                        // Stacked small images (40% width)
                        VStack(spacing: 2) {
                            if recipeImages.count > 1 {
                                recipeImageView(recipeImages[1])
                            } else {
                                placeholderView
                            }

                            if recipeImages.count > 2 {
                                recipeImageView(recipeImages[2])
                            } else {
                                placeholderView
                            }
                        }
                        .frame(width: geometry.size.width * 0.4 - 2)
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Info bar
            HStack {
                Text(collection.name)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                HStack(spacing: HeirloomSpacing.xs) {
                    // "NEW" badge if collection has recipes added within last 24 hours
                    if hasNewRecipes {
                        Text("NEW")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(6)
                            .accessibilityLabel("Contains recently added recipes")
                    }

                    Image(systemName: collection.iconName)
                        .font(.system(size: 14))
                    Text("\(collection.recipes?.count ?? 0)")
                        .font(HeirloomFonts.subheadline)
                }
                .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func recipeImageView(_ recipe: Recipe) -> some View {
        if recipe.imageFileName != nil {
            AsyncRecipeImage(
                imageFileName: recipe.imageFileName,
                firebaseImageURL: recipe.firebaseImageURL,
                placeholder: collection.iconName
            )
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(HeirloomColors.warmGray.opacity(0.3))
            .overlay {
                Image(systemName: collection.iconName)
                    .font(.title)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
    }

    @ViewBuilder
    private var customBackgroundView: some View {
        if let bgPath = collection.customBackgroundImagePath ?? collection.generatedBackgroundImagePath {
            // Detect if path is a URL (Firebase Storage) or local file
            let isFirebaseURL = bgPath.hasPrefix("http://") || bgPath.hasPrefix("https://")

            AsyncRecipeImage(
                imageFileName: isFirebaseURL ? nil : bgPath,
                firebaseImageURL: isFirebaseURL ? bgPath : nil,
                placeholder: collection.iconName
            )
        } else {
            // Fallback to collage if custom background enabled but no image
            placeholderView
        }
    }
}
