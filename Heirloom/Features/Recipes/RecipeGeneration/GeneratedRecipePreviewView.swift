//
//  GeneratedRecipePreviewView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI
import SwiftData

/// Preview screen for AI-generated recipes before saving
struct GeneratedRecipePreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onSave: () -> Void
    let onRegenerate: () -> Void

    @State private var showingRecipeDetail = false
    @State private var showingCollectionPicker = false
    @State private var recipeImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Recipe Image
                if let image = recipeImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if recipe.imageFileName != nil {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .task {
                            await loadRecipeImage()
                        }
                }

                // Title
                Text(recipe.title)
                    .font(HeirloomFonts.largeTitle)
                    .fontWeight(.bold)

                // Summary/Notes
                if let notes = recipe.notes, !notes.isEmpty {
                    Text(notes)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(.secondary)
                }

                // Meta Info
                HStack(spacing: 16) {
                    if let prepTime = recipe.prepTime {
                        Label(prepTime, systemImage: "clock")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                    if let cookTime = recipe.cookTime {
                        Label(cookTime, systemImage: "flame")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                    if let servings = recipe.servings {
                        Label(servings, systemImage: "person.2")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(HeirloomFonts.title2)
                        .fontWeight(.semibold)

                    if let ingredients = recipe.ingredients {
                        ForEach(ingredients, id: \.id) { ingredient in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)

                                Text(ingredient.displayText)
                                    .font(HeirloomFonts.body)
                            }
                        }
                    }
                }

                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(HeirloomFonts.title2)
                        .fontWeight(.semibold)

                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(HeirloomFonts.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color.accentColor))

                            Text(instruction)
                                .font(HeirloomFonts.body)
                        }
                    }
                }

                // Tags
                if let tags = recipe.tags, !tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)

                        // Simple horizontal scroll for tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.id) { tag in
                                    Text(tag.name)
                                        .font(HeirloomFonts.caption1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(tag.swiftUIColor.opacity(0.2))
                                        .foregroundStyle(tag.swiftUIColor)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Regenerate") {
                    onRegenerate()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        saveRecipe()
                    } label: {
                        Label("Save Recipe", systemImage: "checkmark")
                    }

                    Button {
                        showingRecipeDetail = true
                    } label: {
                        Label("Save & View", systemImage: "doc.text")
                    }

                    Button {
                        saveRecipe()
                        showingCollectionPicker = true
                    } label: {
                        Label("Save to Collection", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingCollectionPicker) {
            TagCollectionPickerView(recipe: recipe)
        }
        .fullScreenCover(isPresented: $showingRecipeDetail) {
            NavigationStack {
                RecipeDetailView(recipe: recipe)
            }
        }
    }

    // MARK: - Actions

    private func saveRecipe() {
        // Recipe is already inserted in context by generator
        // Just save the context and call onSave
        do {
            try modelContext.save()
            onSave()
        } catch {
            Log.error("Failed to save recipe", category: .database, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func loadRecipeImage() async {
        guard let fileName = recipe.imageFileName else { return }
        let imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
        recipeImage = await imageStorageService.loadImage(fileName: fileName)
    }
}

// Note: FlowLayout is defined in PublicRecipeDetailView.swift and reused across the app
