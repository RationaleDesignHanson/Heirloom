import SwiftUI
import SwiftData

/// Main bulk import view - paste URLs or import from files
struct BulkImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator

    @StateObject private var manager = ServiceContainer.shared.resolve(ImportJobManager.self)

    @State private var pastedText = ""
    @State private var showingPreview = false
    @State private var extractedURLs: [String] = []
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                if showingPreview {
                    ImportPreviewView(
                        urls: extractedURLs,
                        onConfirm: { urls in
                            Task {
                                await startImport(urls: urls)
                            }
                        },
                        onCancel: {
                            showingPreview = false
                            pastedText = ""
                        }
                    )
                } else {
                    pasteInputView
                }
            }
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Clear coordinator context on cancel
                        tabCoordinator.didCancelCreation()
                        dismiss()
                    }
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Paste Input View

    private var pasteInputView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.xl) {
                // Header
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Import Multiple Recipes")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Paste a list of recipe URLs from your notes, bookmarks, or documents")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.lg)
                }
                .padding(.top, HeirloomSpacing.xxl)

                // Paste Area
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Paste URLs")
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.horizontal, HeirloomSpacing.lg)

                    TextEditor(text: $pastedText)
                        .font(HeirloomFonts.body)
                        .frame(minHeight: 200)
                        .padding(HeirloomSpacing.md)
                        .scrollContentBackground(.hidden)
                        .background(HeirloomColors.cardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, HeirloomSpacing.lg)

                    if !pastedText.isEmpty {
                        HStack {
                            Text("\(URLNormalizer.extractURLs(from: pastedText).count) URLs detected")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Spacer()

                            Button {
                                cleanupURLs()
                            } label: {
                                HStack(spacing: HeirloomSpacing.xs) {
                                    Image(systemName: "wand.and.stars")
                                        .font(HeirloomFonts.caption1)
                                    Text("Clean Up")
                                        .font(HeirloomFonts.caption1Bold)
                                }
                                .foregroundStyle(HeirloomColors.tomato)
                            }
                        }
                        .padding(.horizontal, HeirloomSpacing.lg)
                    }
                }

                // Examples
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Supported Formats")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        exampleRow("Full URLs", "https://example.com/recipe")
                        exampleRow("Without https://", "example.com/recipe")
                        exampleRow("Any separator", "Commas, spaces, or new lines")
                        exampleRow("Auto-cleanup", "Tap 'Clean Up' to format")
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(HeirloomColors.cardBackground)
                .cornerRadius(12)
                .padding(.horizontal, HeirloomSpacing.lg)

                // Import Button
                Button {
                    extractAndPreview()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Continue")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pastedText.isEmpty ? HeirloomColors.warmGray : HeirloomColors.tomato)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(12)
                }
                .disabled(pastedText.isEmpty)
                .padding(.horizontal, HeirloomSpacing.lg)

                Spacer()
            }
        }
    }

    private func exampleRow(_ title: String, _ example: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HeirloomColors.tomato)
                .font(HeirloomFonts.caption1)

            Text(title)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text(example)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Actions

    private func cleanupURLs() {
        // Extract and format URLs cleanly
        let cleaned = URLNormalizer.cleanupText(pastedText)

        // Update the text field with cleaned URLs
        pastedText = cleaned

        // Optional: Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func extractAndPreview() {
        let urls = URLNormalizer.extractURLs(from: pastedText)

        guard !urls.isEmpty else {
            errorMessage = "No valid recipe URLs found. Please paste URLs like:\nhttps://example.com/recipe"
            showingError = true
            return
        }

        extractedURLs = urls
        showingPreview = true
    }

    private func startImport(urls: [String]) async {
        do {
            let job = try manager.createJob(
                urls: urls,
                jobName: "Bulk Import \(Date().formatted(date: .abbreviated, time: .shortened))",
                collectionName: "Photo Imports",
                collectionType: .photoImports,
                context: modelContext
            )

            // Dismiss sheet immediately — processing continues in background
            tabCoordinator.didCreateRecipe()
            dismiss()

            // Start processing in the background (non-blocking)
            let ctx = modelContext
            Task {
                try? await manager.startJob(job, context: ctx)
            }

        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Preview

#Preview {
    BulkImportView()
        .modelContainer(for: [ImportJob.self, ImportItem.self], inMemory: true)
}
