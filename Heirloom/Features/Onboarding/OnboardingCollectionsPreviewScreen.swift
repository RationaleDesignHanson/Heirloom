//
//  OnboardingCollectionsPreviewScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI
import SwiftData

/// Second onboarding screen - Collections and recipe preview
/// Shows 2 recipe cards + 2 collection cards
struct OnboardingCollectionsPreviewScreen: View {
    let onComplete: () -> Void
    @EnvironmentObject private var notificationService: FirebaseNotificationService

    @Query(filter: #Predicate<RecipeCollection> { $0.heritageCollectionId != nil })
    private var heritageCollections: [RecipeCollection]

    @Query(filter: #Predicate<Recipe> { $0.isHeritageRecipe == true })
    private var heritageRecipes: [Recipe]

    @State private var selectedRecipe: Recipe?
    @State private var selectedCollection: RecipeCollection?

    // MARK: - Computed Data

    private var displayedCollections: (primary: RecipeCollection?, secondary: RecipeCollection?) {
        OnboardingDataSelector.selectCollectionsForPreview(from: heritageCollections)
    }

    private var displayedRecipes: [Recipe] {
        OnboardingDataSelector.selectRecipesForPreview(
            from: heritageRecipes,
            primaryCollection: displayedCollections.primary,
            secondaryCollection: displayedCollections.secondary
        )
    }

    private var canShowPreview: Bool {
        OnboardingDataSelector.canShowOnboardingPreview(
            collections: heritageCollections,
            recipes: heritageRecipes
        )
    }

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.cream
                .ignoresSafeArea()

            if canShowPreview {
                previewContent
            } else {
                fallbackContent
            }
        }
        // Sheet for recipe detail
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeDetailView(recipe: recipe)
                    .environmentObject(notificationService)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back to Onboarding") {
                                selectedRecipe = nil
                            }
                        }
                    }
            }
        }
        // Sheet for collection detail
        .sheet(item: $selectedCollection) { collection in
            NavigationStack {
                CollectionDetailView(collection: collection)
                    .environmentObject(notificationService)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Back to Onboarding") {
                                selectedCollection = nil
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Preview Content

    private var previewContent: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(minHeight: 30, maxHeight: 50)

            // Message
            VStack(spacing: 8) {
                Text("We didn't want you to start empty handed")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)

                Text("We have historical recipes already organized in collections")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            // Top Half - 2 Recipe Cards
            HStack(spacing: HeirloomSpacing.md) {
                ForEach(displayedRecipes.prefix(2), id: \.id) { recipe in
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        if let collection = heritageCollections.first(where: {
                            $0.heritageCollectionId == recipe.heritageCollectionId
                        }) {
                            OnboardingRecipeCard(recipe: recipe, collection: collection)
                        } else {
                            OnboardingRecipeCard(recipe: recipe, collection: nil)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            // Bottom Half - 2 Collection Cards
            VStack(spacing: HeirloomSpacing.sm) {
                if let primary = displayedCollections.primary {
                    Button {
                        selectedCollection = primary
                    } label: {
                        CollectionRow(collection: primary)
                    }
                    .buttonStyle(.plain)
                }

                if let secondary = displayedCollections.secondary {
                    Button {
                        selectedCollection = secondary
                    } label: {
                        CollectionRow(collection: secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)

            Spacer()
                .frame(minHeight: 20, maxHeight: 40)

            // Get Started Button
            Button {
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(minHeight: 30, maxHeight: 50)
        }
    }

    // MARK: - Fallback Content

    private var fallbackContent: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Let's get started")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.charcoal)

                Text("Import your first recipe to begin building your collection")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                completeOnboarding()
            } label: {
                Text("Get Started")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            Spacer()
                .frame(minHeight: 40, maxHeight: 60)
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    let config = FirebaseConfiguration(logger: HeirloomLogger())
    let notificationService = FirebaseNotificationService(configuration: config, logger: HeirloomLogger())

    return OnboardingCollectionsPreviewScreen(onComplete: {})
        .modelContainer(for: [Recipe.self, RecipeCollection.self], inMemory: true)
        .environmentObject(notificationService)
}
