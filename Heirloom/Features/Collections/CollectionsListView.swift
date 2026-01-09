import SwiftUI
import SwiftData

/// Main Collections tab view showing heritage and user collections
struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @Query(sort: \RecipeCollection.createdDate) private var allCollections: [RecipeCollection]

    @State private var showCreateCollection = false
    @State private var showAddRecipe = false
    @State private var selectedCollection: RecipeCollection?
    @State private var showRecipeCoachMark = false
    @State private var collectionToDelete: RecipeCollection?
    @State private var showDeleteConfirmation = false

    // Filter heritage collections (founding collections)
    var heritageCollections: [RecipeCollection] {
        allCollections.filter { $0.isHeritageCollection }
    }

    // Filter user collections (non-system, non-heritage)
    var userCollections: [RecipeCollection] {
        allCollections.filter { !$0.isSystemCollection && !$0.isHeritageCollection }
    }

    // System collections (Favorites, Quick Meals, etc.)
    var systemCollections: [RecipeCollection] {
        allCollections.filter { $0.isSystemCollection && !$0.isHeritageCollection }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Heritage Collections Section
                    if !heritageCollections.isEmpty {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            Text("Heritage Collections")
                                .font(HeirloomFonts.title3)
                                .foregroundStyle(HeirloomColors.primaryText)
                                .padding(.horizontal, HeirloomSpacing.md)

                            Text("Historic recipes from America's culinary past")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .padding(.horizontal, HeirloomSpacing.md)

                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: HeirloomSpacing.md),
                                GridItem(.flexible(), spacing: HeirloomSpacing.md)
                            ], spacing: HeirloomSpacing.md) {
                                ForEach(heritageCollections, id: \.id) { collection in
                                    HeritageCollectionCard(collection: collection)
                                        .onTapGesture {
                                            // Show coach mark on first tap if not seen
                                            if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
                                                showRecipeCoachMark = true
                                            } else {
                                                selectedCollection = collection
                                            }
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                collectionToDelete = collection
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete Collection", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                        }
                    }

                    // My Collections Section (includes system + user collections)
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        Text("My Collections")
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .padding(.horizontal, HeirloomSpacing.md)

                        if systemCollections.isEmpty && userCollections.isEmpty {
                            emptyUserCollectionsView
                        } else {
                            LazyVStack(spacing: HeirloomSpacing.sm) {
                                // System collections first (Favorites, Quick Meals, etc.)
                                ForEach(systemCollections, id: \.id) { collection in
                                    UserCollectionRow(collection: collection)
                                        .onTapGesture {
                                            selectedCollection = collection
                                        }
                                }

                                // User collections after system collections
                                ForEach(userCollections, id: \.id) { collection in
                                    UserCollectionRow(collection: collection)
                                        .onTapGesture {
                                            selectedCollection = collection
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                collectionToDelete = collection
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete Collection", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                        }
                    }
                }
                .padding(.vertical, HeirloomSpacing.lg)
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddRecipe = true
                        } label: {
                            Label("New Recipe", systemImage: "square.and.pencil")
                        }

                        Button {
                            showCreateCollection = true
                        } label: {
                            Label("New Collection", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCollection) {
                CollectionEditorView()
            }
            .sheet(isPresented: $showAddRecipe) {
                RecipeEditorView()
            }
            .navigationDestination(item: $selectedCollection) { collection in
                CollectionDetailView(collection: collection)
                    .environmentObject(notificationService)
            }
            .overlay {
                if showRecipeCoachMark {
                    CoachMarkView(
                        message: "Tap to view. Edit to make it yours, or share to pass it on.",
                        onDismiss: {
                            showRecipeCoachMark = false
                            UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasSeenRecipeCoachMark)
                        }
                    )
                }
            }
            .confirmationDialog(
                "Delete \(collectionToDelete?.name ?? "Collection")?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Collection Only", role: .destructive) {
                    if let collection = collectionToDelete {
                        Task {
                            await deleteCollectionKeepingRecipes(collection)
                        }
                    }
                }

                Button("Delete Collection & Recipes", role: .destructive) {
                    if let collection = collectionToDelete {
                        Task {
                            await deleteCollectionAndRecipes(collection)
                        }
                    }
                }

                Button("Cancel", role: .cancel) {
                    collectionToDelete = nil
                }
            } message: {
                if let count = collectionToDelete?.recipeCount {
                    Text("This collection has \(count) recipe\(count == 1 ? "" : "s").\n\nDelete collection only or delete with all recipes?")
                } else {
                    Text("Choose what to delete")
                }
            }
            .onAppear {
                // Show coach mark after 10 seconds if not seen before
                if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
                    Task {
                        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                        if !UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasSeenRecipeCoachMark) {
                            showRecipeCoachMark = true
                        }
                    }
                }
            }
        }
    }

    private var emptyUserCollectionsView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))

            Text("No Collections Yet")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Create collections to organize your recipes")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                showCreateCollection = true
            } label: {
                Text("Create Collection")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }
            .padding(.top, HeirloomSpacing.sm)
        }
        .padding(HeirloomSpacing.xl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Delete Actions

    private func deleteCollectionKeepingRecipes(_ collection: RecipeCollection) async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        do {
            // Remove collection-recipe relationships
            if let recipes = collection.recipes {
                for recipe in recipes {
                    recipe.collections?.removeAll { $0.id == collection.id }
                }
            }

            // Delete collection
            await MainActor.run {
                modelContext.delete(collection)
                try? modelContext.save()
            }

            // Firebase sync
            let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
            if backendConfig.isFirebaseActive {
                let firebaseSync = ServiceContainer.shared.resolve(FirebaseSyncServiceProtocol.self)
                try await firebaseSync.deleteCollection(collection.id)
            }

            // Success feedback
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.success(title: "Collection deleted", message: "Recipes remain in your library")
                generator.notificationOccurred(.success)
            }

            // Clear the deleted collection reference
            await MainActor.run {
                collectionToDelete = nil
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete collection", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
        }
    }

    private func deleteCollectionAndRecipes(_ collection: RecipeCollection) async {
        // Prevent deletion of system collections
        guard !collection.isSystemCollection else {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Cannot delete", message: "System collections cannot be deleted")
            }
            return
        }

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        do {
            let recipesToDelete = collection.recipes ?? []
            let recipeCount = recipesToDelete.count

            // Delete all recipes first
            for recipe in recipesToDelete {
                await MainActor.run {
                    modelContext.delete(recipe)
                }
            }

            // Delete collection
            await MainActor.run {
                modelContext.delete(collection)
                try? modelContext.save()
            }

            // Firebase sync
            let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
            if backendConfig.isFirebaseActive {
                let firebaseSync = ServiceContainer.shared.resolve(FirebaseSyncServiceProtocol.self)

                // Delete recipes from Firebase
                for recipe in recipesToDelete {
                    try await firebaseSync.deleteRecipe(recipe.id)
                }

                // Delete collection from Firebase
                try await firebaseSync.deleteCollection(collection.id)
            }

            // Success feedback
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.success(
                    title: "Collection and \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") deleted"
                )
                generator.notificationOccurred(.success)
            }

            // Clear the deleted collection reference
            await MainActor.run {
                collectionToDelete = nil
            }

        } catch {
            let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
            await MainActor.run {
                toastManager.error(title: "Failed to delete", message: error.localizedDescription)
                generator.notificationOccurred(.error)
            }
        }
    }
}

// MARK: - Heritage Collection Card

struct HeritageCollectionCard: View {
    let collection: RecipeCollection

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Icon and badge
            HStack {
                Image(systemName: collection.iconName)
                    .font(.title2)
                    .foregroundStyle(collection.swiftUIColor)

                Spacer()

                // Heritage badge
                Text("HERITAGE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(collection.swiftUIColor.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(collection.swiftUIColor.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer()

            // Collection name
            Text(collection.name)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(2)

            // Recipe count
            Text("\(collection.recipeCount) recipe\(collection.recipeCount == 1 ? "" : "s")")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .frame(height: 140)
        .background(Color(hex: "#F8F8F8"))
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .strokeBorder(collection.swiftUIColor.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }
}

// MARK: - User Collection Row

struct UserCollectionRow: View {
    let collection: RecipeCollection

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Icon
            Image(systemName: collection.iconName)
                .font(.title3)
                .foregroundStyle(collection.swiftUIColor)
                .frame(width: 32)

            // Collection info
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("\(collection.recipeCount) recipe\(collection.recipeCount == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
        }
        .padding(HeirloomSpacing.md)
        .background(Color(hex: "#F8F8F8"))
        .cornerRadius(HeirloomSpacing.cardCornerRadius)
    }
}

#Preview {
    CollectionsListView()
        .modelContainer(for: RecipeCollection.self, inMemory: true)
}
