import SwiftUI
import SwiftData

/// UI component for selecting which recipe version to cook
/// Displays all available versions with attribution and change counts
struct VersionSelectorView: View {
    let recipe: Recipe
    @Binding var selectedVersionID: UUID?
    @Environment(\.modelContext) private var modelContext

    // Local state
    @State private var isExpanded: Bool = false

    var body: some View {
        if recipe.hasMultipleVersions {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(HeirloomColors.tomato)

                        Text("Recipe Version")
                            .font(HeirloomFonts.caption1)
                            .fontWeight(.semibold)
                            .foregroundColor(HeirloomColors.charcoal)

                        Spacer()

                        // Current version indicator
                        if let activeVersion = recipe.activeVersion {
                            Text(activeVersion.attributionLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(HeirloomColors.familyGreen)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HeirloomColors.charcoal.opacity(0.5))
                    }
                    .padding(.horizontal, HeirloomSpacing.md)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.cream.opacity(0.5))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // Version list
                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(recipe.sortedVersions, id: \.id) { version in
                            VersionRow(
                                version: version,
                                isSelected: selectedVersionID == version.id,
                                onSelect: {
                                    selectVersion(version)
                                }
                            )
                            .padding(.horizontal, HeirloomSpacing.sm)
                            .padding(.vertical, HeirloomSpacing.xs)
                        }
                    }
                    .padding(.top, HeirloomSpacing.xs)
                    .background(HeirloomColors.cream.opacity(0.3))
                    .cornerRadius(8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
    }

    // MARK: - Actions

    private func selectVersion(_ version: RecipeVersion) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedVersionID = version.id

            // Persist selection
            do {
                try RecipeVersionService.shared.selectVersion(
                    version,
                    for: recipe,
                    context: modelContext
                )
            } catch {
                Log.error("Failed to select recipe version", category: .database, metadata: ["error": error.localizedDescription, "versionId": version.id.uuidString])
            }
        }
    }
}

// MARK: - Version Row

private struct VersionRow: View {
    let version: RecipeVersion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: HeirloomSpacing.sm) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isSelected ? HeirloomColors.tomato : HeirloomColors.charcoal.opacity(0.3))

                VStack(alignment: .leading, spacing: 2) {
                    // Creator name
                    Text(version.creatorDisplayName)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(HeirloomColors.charcoal)

                    // Metadata
                    HStack(spacing: 6) {
                        // Year or "Original" label
                        if version.isBaseVersion {
                            Text("Original")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HeirloomColors.familyGreen)
                        } else {
                            Text(version.creationYear)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HeirloomColors.charcoal.opacity(0.6))
                        }

                        // Change count
                        if version.hasChanges {
                            Text("·")
                                .foregroundColor(HeirloomColors.charcoal.opacity(0.3))
                            Text("\(version.changeCount) change\(version.changeCount == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HeirloomColors.tomato.opacity(0.8))
                        }

                        // Times cooked
                        if version.timesCooked > 0 {
                            Text("·")
                                .foregroundColor(HeirloomColors.charcoal.opacity(0.3))
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundColor(HeirloomColors.tomato.opacity(0.7))
                            Text("\(version.timesCooked)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(HeirloomColors.charcoal.opacity(0.6))
                        }
                    }
                }

                Spacer()

                // Arrow indicator if selected
                if isSelected {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HeirloomColors.tomato)
                }
            }
            .padding(.horizontal, HeirloomSpacing.sm)
            .padding(.vertical, HeirloomSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? HeirloomColors.tomato.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Version Selector (Alternative Style)

/// Compact version selector for use in navigation bar or toolbar
struct CompactVersionSelector: View {
    let recipe: Recipe
    @Binding var selectedVersionID: UUID?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if recipe.hasMultipleVersions, let activeVersion = recipe.activeVersion {
            Menu {
                ForEach(recipe.sortedVersions, id: \.id) { version in
                    Button {
                        selectVersion(version)
                    } label: {
                        HStack {
                            Text(version.fullAttribution)
                            if selectedVersionID == version.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12, weight: .medium))

                    Text(activeVersion.attributionLabel)
                        .font(.system(size: 13, weight: .medium))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(HeirloomColors.tomato)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(HeirloomColors.tomato.opacity(0.1))
                )
            }
        }
    }

    private func selectVersion(_ version: RecipeVersion) {
        selectedVersionID = version.id
        do {
            try RecipeVersionService.shared.selectVersion(
                version,
                for: recipe,
                context: modelContext
            )
        } catch {
            Log.error("Failed to select recipe version", category: .database, metadata: ["error": error.localizedDescription, "versionId": version.id.uuidString])
        }
    }
}

// MARK: - Preview

#if DEBUG
struct VersionSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Multiple versions
            VersionSelectorPreview(hasMultipleVersions: true)
                .previewDisplayName("Multiple Versions")

            // Single version
            VersionSelectorPreview(hasMultipleVersions: false)
                .previewDisplayName("Single Version (No Selector)")
        }
    }
}

private struct VersionSelectorPreview: View {
    let hasMultipleVersions: Bool
    @State private var selectedVersionID: UUID?

    var body: some View {
        let recipe = createSampleRecipe(withMultipleVersions: hasMultipleVersions)

        VStack {
            VersionSelectorView(
                recipe: recipe,
                selectedVersionID: $selectedVersionID
            )

            Spacer()

            // Show compact version too
            if hasMultipleVersions {
                Divider()
                    .padding()

                Text("Compact Version:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                CompactVersionSelector(
                    recipe: recipe,
                    selectedVersionID: $selectedVersionID
                )
            }

            Spacer()
        }
        .modelContainer(for: [Recipe.self, RecipeVersion.self], inMemory: true)
    }

    private func createSampleRecipe(withMultipleVersions: Bool) -> Recipe {
        let recipe = Recipe(title: "Grandma's Lasagna")

        let baseVersion = RecipeVersion.sampleBase()
        recipe.versions = [baseVersion]
        recipe.selectedVersionID = baseVersion.id

        if withMultipleVersions {
            let momVersion = RecipeVersion.sampleContributor()
            recipe.versions?.append(momVersion)
        }

        return recipe
    }
}
#endif
