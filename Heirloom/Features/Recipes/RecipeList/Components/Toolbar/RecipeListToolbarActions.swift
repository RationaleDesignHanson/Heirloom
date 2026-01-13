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
    let onNarratedVideoImport: () -> Void
    let onSilentVideoImport: () -> Void
    let onAddCollection: () -> Void
    let onAddNormalSample: () -> Void
    let onAddHeritageSample: () -> Void

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
                    Label("Import from URL", systemImage: "link")
                }
                .accessibilityLabel("Import from URL")
                .accessibilityHint("Import a recipe from a website URL")

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
                    Label("Scan Cookbook", systemImage: "book.pages")
                }
                .accessibilityLabel("Scan Cookbook")
                .accessibilityHint("Scan a recipe from a cookbook page")

                Button {
                    onNarratedVideoImport()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Narrated Video")
                            Text("With spoken instructions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "video.badge.waveform")
                            .foregroundStyle(.blue)
                    }
                }
                .accessibilityLabel("Import recipe from narrated cooking video")
                .accessibilityHint("Extract recipes from videos with spoken instructions")

                Button {
                    onSilentVideoImport()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Silent Video (ASMR)")
                            Text("Visual cooking steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "eye.circle.fill")
                            .foregroundStyle(.purple)
                    }
                }
                .accessibilityLabel("Import recipe from silent cooking video")
                .accessibilityHint("Extract recipes from silent videos using visual analysis")

                Divider()

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

                    Button {
                        onAddHeritageSample()
                    } label: {
                        Label("Heritage Recipe", systemImage: "scroll.fill")
                    }
                    .accessibilityLabel("Heritage Recipe")
                    .accessibilityHint("Add a heritage sample recipe")
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
