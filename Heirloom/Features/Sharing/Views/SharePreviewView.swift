//
//  SharePreviewView.swift
//  Heirloom
//
//  Displays a preview of a shared recipe from a public share link.
//  Allows the user to import the recipe into their collection.
//

import SwiftUI
import SwiftData

/// Sheet displayed when user opens a recipe share link
/// Shows preview, sharer info, lineage, and acceptance options
struct SharePreviewView: View {
    let shareURL: URL
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.deepLinkHandler) private var deepLinkHandler
    @Environment(\.firebaseShare) private var shareService
    
    // State
    @State private var sharedData: SharedRecipeData?
    @State private var isLoading = true
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importedRecipe: Recipe?
    @State private var showSuccessAlert = false
    @State private var showSignInPrompt = false
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let data = sharedData {
                    contentView(data: data)
                } else if let error = errorMessage {
                    errorView(message: error)
                }
            }
            .navigationTitle("Shared Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        deepLinkHandler.clearPendingShare()
                        dismiss()
                    }
                    .disabled(isImporting)
                }
            }
            .alert("Recipe Added!", isPresented: $showSuccessAlert) {
                Button("View Recipe") {
                    deepLinkHandler.clearPendingShare()
                    dismiss()
                    // TODO: Navigate to imported recipe
                }
                Button("Done") {
                    deepLinkHandler.clearPendingShare()
                    dismiss()
                }
            } message: {
                if let recipe = importedRecipe {
                    Text("\(recipe.title) has been added to your collection!")
                }
            }
        }
        .sheet(isPresented: $showSignInPrompt) {
            SignInPromptSheet()
        }
        .task {
            await loadSharePreview()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading recipe...")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Fetching share details...")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content View
    
    private func contentView(data: SharedRecipeData) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with recipe info
                headerCard(data: data)
                
                // Lineage visualization
                lineageCard(data: data)
                
                // Recipe preview
                recipePreviewCard(data: data)
                
                // Personal message
                if let message = data.personalMessage, !message.isEmpty {
                    messageCard(message: message, from: data.sharerName)
                }
                
                // Expiration warning
                if let expiresAt = data.expiresAt {
                    expirationBanner(expiresAt: expiresAt, isExpired: data.isExpired)
                }
                
                // Import button
                importButton(data: data)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
    }
    
    // MARK: - Header Card
    
    private func headerCard(data: SharedRecipeData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Recipe title
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.accent)
                
                Text(data.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            
            Divider()
            
            // Sharer info
            HStack(spacing: 12) {
                Circle()
                    .fill(HeirloomColors.amber.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(HeirloomColors.amber)
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.sharerName)
                        .font(.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    Text("shared this recipe with you")
                        .font(.subheadline)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(HeirloomColors.cream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: HeirloomColors.cardShadow, radius: 8)
    }
    
    // MARK: - Lineage Card
    
    private func lineageCard(data: SharedRecipeData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(HeirloomColors.familyGreen)
                Text("Recipe Lineage")
                    .font(.headline)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            
            Text(data.generationDisplay)
                .font(.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)
            
            // Visual lineage chain
            if data.generation > 0 {
                HStack(spacing: 6) {
                    ForEach(0...min(data.generation, 5), id: \.self) { gen in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(gen == data.generation ? HeirloomColors.familyGreen : HeirloomColors.warmGray.opacity(0.5))
                                .frame(width: 10, height: 10)
                            
                            if gen < min(data.generation, 5) {
                                Rectangle()
                                    .fill(HeirloomColors.warmGray.opacity(0.3))
                                    .frame(width: 16, height: 2)
                            }
                        }
                    }
                    
                    if data.generation > 5 {
                        Text("...")
                            .font(.caption)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Text("You'll be Gen \(data.generation + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.familyGreen.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                Text("You'll receive the original recipe")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Recipe Preview Card
    
    private func recipePreviewCard(data: SharedRecipeData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .foregroundStyle(HeirloomColors.accent)
                Text("Recipe Preview")
                    .font(.headline)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            
            // Metadata row
            HStack(spacing: 16) {
                if let servings = data.servings {
                    Label(servings, systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                
                if let prepTime = data.prepTime {
                    Label(prepTime, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                
                if let cookTime = data.cookTime {
                    Label(cookTime, systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            
            // Ingredients preview
            if !data.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients (\(data.ingredients.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(data.ingredients.prefix(4), id: \.self) { ingredient in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(HeirloomColors.amber)
                                    .frame(width: 4, height: 4)
                                Text(ingredient)
                                    .font(.caption)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                        }
                        
                        if data.ingredients.count > 4 {
                            Text("+ \(data.ingredients.count - 4) more...")
                                .font(.caption)
                                .foregroundStyle(HeirloomColors.warmGray)
                                .padding(.leading, 12)
                        }
                    }
                }
            }
            
            // Instructions preview
            if !data.instructions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions (\(data.instructions.count) steps)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    if let firstStep = data.instructions.first {
                        Text("1. \(firstStep)")
                            .font(.caption)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Message Card
    
    private func messageCard(message: String, from sharerName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(HeirloomColors.amber)
                Text("Personal Note")
                    .font(.headline)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            
            Text("\"\(message)\"")
                .font(.body)
                .italic()
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(HeirloomColors.amber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text("— \(sharerName)")
                .font(.caption)
                .foregroundStyle(HeirloomColors.warmGray)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(HeirloomColors.cream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Expiration Banner
    
    private func expirationBanner(expiresAt: Date, isExpired: Bool) -> some View {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let text = isExpired ? "This share has expired" : "Expires \(formatter.localizedString(for: expiresAt, relativeTo: Date()))"
        
        return HStack(spacing: 10) {
            Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                .foregroundStyle(isExpired ? .red : .orange)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isExpired ? .red : .orange)
            
            Spacer()
        }
        .padding()
        .background((isExpired ? Color.red : Color.orange).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Import Button
    
    private func importButton(data: SharedRecipeData) -> some View {
        Button(action: { Task { await importRecipe(data) } }) {
            HStack(spacing: 10) {
                if isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to My Recipes")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(data.isExpired ? Color.gray : HeirloomColors.familyGreen)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isImporting || data.isExpired)
        .shadow(color: data.isExpired ? .clear : HeirloomColors.familyGreen.opacity(0.3), radius: 8, y: 4)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)
            
            Text("Unable to Load Share")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(HeirloomColors.primaryText)
            
            Text(message)
                .font(.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { Task { await loadSharePreview() } }) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func loadSharePreview() async {
        isLoading = true
        errorMessage = nil

        Log.debug("Loading share preview from URL", category: .firebase, metadata: ["shareURL": shareURL.absoluteString])

        do {
            // Extract shareId from URL
            // URL format: heirloom://share/{shareId} or https://heirloom.app/share/{shareId}
            let shareId = shareURL.lastPathComponent

            guard !shareId.isEmpty else {
                throw FirebaseShareService.ShareError.invalidShareData
            }

            Log.debug("Fetching share metadata", category: .firebase, metadata: ["shareId": shareId])

            // Fetch metadata from Firebase
            let metadata = try await shareService.fetchShareMetadata(shareId: shareId)

            // Convert to SharedRecipeData
            sharedData = try SharedRecipeData.from(shareMetadata: metadata)

            Log.info("Successfully loaded share preview", category: .firebase, metadata: ["shareURL": shareURL.absoluteString])
        } catch {
            Log.error("Failed to load share preview", category: .firebase, metadata: ["error": error.localizedDescription, "shareURL": shareURL.absoluteString])
            // Show more detailed error
            if let shareError = error as? FirebaseShareService.ShareError {
                switch shareError {
                case .shareNotFound:
                    errorMessage = "This shared recipe no longer exists or has been revoked"
                case .shareExpired:
                    errorMessage = "This share link has expired"
                case .notAuthenticated:
                    // Show sign-in prompt instead of error message
                    showSignInPrompt = true
                    errorMessage = "Authentication required"
                case .invalidShareData:
                    errorMessage = "The shared data is corrupted or invalid"
                default:
                    errorMessage = "Failed to load share: \(error.localizedDescription)"
                }
            } else if let dataError = error as? SharedRecipeDataError {
                switch dataError {
                case .invalidMetadata:
                    errorMessage = "Invalid share metadata - missing required fields"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
    
    private func importRecipe(_ data: SharedRecipeData) async {
        isImporting = true
        errorMessage = nil

        Log.info("Importing shared recipe", category: .firebase, metadata: ["shareId": data.shareId, "title": data.title])

        do {
            // Accept the share using Firebase service
            let recipe = try await shareService.acceptShare(shareId: data.shareId, context: modelContext)
            importedRecipe = recipe

            Log.info("Successfully imported shared recipe", category: .firebase, metadata: ["recipeId": recipe.id.uuidString, "title": recipe.title])

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            showSuccessAlert = true
        } catch {
            Log.error("Failed to import shared recipe", category: .firebase, metadata: ["error": error.localizedDescription, "shareId": data.shareId])

            errorMessage = error.localizedDescription

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }

        isImporting = false
    }
}

// MARK: - Preview

#Preview("Share Preview - Loading") {
    let url = URL(string: "heirloom://share/test-123")!
    
    return SharePreviewView(shareURL: url)
        .modelContainer(for: Recipe.self, inMemory: true)
}

#Preview("Share Preview - Error") {
    let url = URL(string: "heirloom://share/invalid")!
    
    return SharePreviewView(shareURL: url)
        .modelContainer(for: Recipe.self, inMemory: true)
}
