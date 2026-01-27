//
//  RecipeListToolbarActions.swift
//  Heirloom
//
//  Created by Claude on 1/5/26.
//

import SwiftUI

/// Primary action toolbar item for RecipeListView
/// Shows select all/deselect all button during selection mode, or add/import menu
struct RecipeListToolbarActions: View {
    let isSelectionMode: Bool
    let selectedCount: Int
    let filteredCount: Int
    let onSelectAllToggle: () -> Void
    let onAddRecipe: () -> Void
    let onImportRecipe: () -> Void
    let onBulkImport: () -> Void
    let onCookbookScanner: () -> Void
    let onVideoImport: () -> Void
    let onAddCollection: () -> Void
    let onAddNormalSample: () -> Void
    let onCollectionSettings: (() -> Void)? // Optional - only shown in collection detail views

    // Track menu presentation state for shimmer control
    @State private var isMenuPresented = false

    var body: some View {
        if isSelectionMode {
            Button(selectedCount == filteredCount ? "Deselect All" : "Select All") {
                onSelectAllToggle()
            }
            .accessibilityLabel(selectedCount == filteredCount ? "Deselect all recipes" : "Select all recipes")
        } else {
            Menu {
                Button {
                    onAddRecipe()
                } label: {
                    Label("New Recipe", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("New Recipe")
                .accessibilityHint("Create a new recipe manually")

                Button {
                    onImportRecipe()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recipe Website Link")
                            Text("Paste URL from recipe website")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "link")
                    }
                }
                .accessibilityLabel("Import from recipe website")
                .accessibilityHint("Paste a URL from a recipe website like AllRecipes or NYT Cooking")

                Button {
                    onBulkImport()
                } label: {
                    Label("Bulk Import", systemImage: "square.stack.3d.down.forward")
                }
                .accessibilityLabel("Bulk Import")
                .accessibilityHint("Import multiple recipes from photos")

                Button {
                    onCookbookScanner()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Cookbook Page")
                            Text("Camera, PDF, or photo from camera roll")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "book.pages")
                    }
                }
                .accessibilityLabel("Scan cookbook page with camera or photo")
                .accessibilityHint("Scan recipe images using camera, PDF, or photos from camera roll")

                Button {
                    onVideoImport()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Video Import")
                            Text("Auto-detects speech, text, or visual content")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "video.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .accessibilityLabel("Import recipe from video")
                .accessibilityHint("Select a cooking video from camera roll or share from Instagram/TikTok")

                Divider()

                // Collection Settings (if in collection detail view)
                if let onCollectionSettings = onCollectionSettings {
                    Button {
                        onCollectionSettings()
                    } label: {
                        Label("Collection Settings", systemImage: "gear")
                    }
                    .accessibilityLabel("Collection Settings")
                    .accessibilityHint("Edit collection name, icon, and settings")
                }

                Button {
                    onAddCollection()
                } label: {
                    Label("New Collection", systemImage: "folder.badge.plus")
                }
                .accessibilityLabel("New Collection")
                .accessibilityHint("Create a new collection")

                Divider()

                Menu {
                    Button {
                        onAddNormalSample()
                    } label: {
                        Label("Normal Recipe", systemImage: "fork.knife")
                    }
                    .accessibilityLabel("Normal Recipe")
                    .accessibilityHint("Add a normal sample recipe")
                } label: {
                    Label("Generate Sample Recipe", systemImage: "sparkles")
                }
                .accessibilityLabel("Generate Sample Recipe")
                .accessibilityHint("Generate a sample recipe for testing")
            } label: {
                Image(systemName: "plus")
                    .holographicShimmer(
                        isActive: !isMenuPresented,
                        shimmerInterval: 12.0
                    )
            }
            .onTapGesture {
                // Track menu presentation for shimmer control
                isMenuPresented = true
            }
            .onChange(of: isMenuPresented) { _, newValue in
                // Reset after menu closes (approximate - Menu doesn't expose state)
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isMenuPresented = false
                    }
                }
            }
            .accessibilityLabel("Add Recipe")
            .accessibilityHint("Opens menu to add or import recipes")
        }
    }
}
