import SwiftUI
import SwiftData

/// Main Collections tab view showing heritage and user collections
struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeCollection.createdDate) private var allCollections: [RecipeCollection]

    @State private var showCreateCollection = false
    @State private var showAddRecipe = false
    @State private var selectedCollection: RecipeCollection?

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
                                            selectedCollection = collection
                                        }
                                }
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                        }
                    }

                    // User Collections Section
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        HStack {
                            Text("My Collections")
                                .font(HeirloomFonts.title3)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Spacer()

                            Button {
                                showCreateCollection = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("New")
                                }
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.tomato)
                            }
                        }
                        .padding(.horizontal, HeirloomSpacing.md)

                        if userCollections.isEmpty {
                            emptyUserCollectionsView
                        } else {
                            LazyVStack(spacing: HeirloomSpacing.sm) {
                                ForEach(userCollections, id: \.id) { collection in
                                    UserCollectionRow(collection: collection)
                                        .onTapGesture {
                                            selectedCollection = collection
                                        }
                                }
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                        }
                    }

                    // System Collections Section
                    if !systemCollections.isEmpty {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            Text("Smart Collections")
                                .font(HeirloomFonts.title3)
                                .foregroundStyle(HeirloomColors.primaryText)
                                .padding(.horizontal, HeirloomSpacing.md)

                            LazyVStack(spacing: HeirloomSpacing.sm) {
                                ForEach(systemCollections, id: \.id) { collection in
                                    UserCollectionRow(collection: collection)
                                        .onTapGesture {
                                            selectedCollection = collection
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
                    Button {
                        showAddRecipe = true
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
