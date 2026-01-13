//
//  VideoAttributionSheet.swift
//  Heirloom
//
//  Created by Claude on 1/13/26.
//
//  Lightweight sheet for collecting video attribution after recipe save
//  Part of Phase 2.2: Deferred attribution collection

import SwiftUI
import SwiftData

struct VideoAttributionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let recipe: Recipe
    let onSave: () -> Void

    @State private var creatorName: String
    @State private var videoTitle: String
    @State private var selectedPlatform: VideoPlatform?
    @State private var sourceURL: String
    @State private var notes: String

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    init(recipe: Recipe, onSave: @escaping () -> Void = {}) {
        self.recipe = recipe
        self.onSave = onSave

        // Initialize with existing attribution if available
        _creatorName = State(initialValue: recipe.provenance?.sourceAttribution ?? "")
        _videoTitle = State(initialValue: "")
        _sourceURL = State(initialValue: recipe.provenance?.sourceURL ?? "")
        _notes = State(initialValue: "")
        _selectedPlatform = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Header section
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)

                        Text("Add Attribution")
                            .font(.title2.bold())

                        Text("Credit the original creator of this recipe. This information will appear on the recipe card.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Attribution fields
                Section {
                    TextField("Creator Name", text: $creatorName)
                        .textContentType(.name)

                    TextField("Video Title", text: $videoTitle)

                    Picker("Platform", selection: $selectedPlatform) {
                        Text("Select Platform").tag(nil as VideoPlatform?)
                        ForEach(VideoPlatform.allCases, id: \.self) { platform in
                            HStack {
                                Image(systemName: platform.iconName)
                                Text(platform.displayName)
                            }
                            .tag(platform as VideoPlatform?)
                        }
                    }

                    TextField("Source URL (optional)", text: $sourceURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                } header: {
                    Text("Video Information")
                } footer: {
                    Text("Adding attribution helps others discover the original creator and shows respect for their work.")
                        .foregroundStyle(.secondary)
                }

                // Notes section
                Section {
                    TextField("Additional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes (Optional)")
                }

                // Actions
                Section {
                    Button {
                        saveAttribution()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save Attribution")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(creatorName.isEmpty)

                    Button("Skip for Now") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Add Attribution")
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

    private func saveAttribution() {
        // Update recipe provenance with attribution
        if recipe.provenance == nil {
            recipe.provenance = ProvenanceMetadata(
                sourceType: .imported,
                sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                sourceAttribution: creatorName.trimmingCharacters(in: .whitespaces),
                generation: 0,
                sharedByName: nil,
                createdAt: Date()
            )
        } else {
            recipe.provenance?.sourceAttribution = creatorName.trimmingCharacters(in: .whitespaces)
            recipe.provenance?.sourceURL = sourceURL.isEmpty ? nil : sourceURL
        }

        recipe.lastModified = Date()

        do {
            try modelContext.save()

            toastManager.success(
                title: "Attribution Saved",
                message: "Thank you for crediting the creator"
            )

            onSave()
            dismiss()
        } catch {
            toastManager.error(
                title: "Failed to Save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)
    let recipe = Recipe(title: "Test Recipe", sourceType: .video, instructions: ["Step 1"])

    return VideoAttributionSheet(recipe: recipe)
        .modelContainer(container)
}
