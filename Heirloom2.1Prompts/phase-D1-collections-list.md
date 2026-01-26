# Heirloom Collections Overhaul
## Phase D1: Collections List Updates

**Branch:** `feature/collections-D1-list-updates`
**Estimated Time:** 45-60 minutes
**Dependencies:** Phase A1 (CollectionType), Phase C1 (routing)

---

## Objective

Update the Collections list view to hide empty/system collections, show only relevant content, and display unlock progress for theme collections.

---

## Task D1.1: Update CollectionsListView Filtering

**File:** `Heirloom/Features/Collections/CollectionsListView.swift`

```swift
//
//  CollectionsListView.swift
//  Heirloom
//
//  Updated by Claude Code on 2026-01-26.
//

import SwiftUI
import SwiftData

struct CollectionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    
    @Query(sort: \RecipeCollection.createdAt, order: .reverse)
    private var allCollections: [RecipeCollection]
    
    @State private var showCreateCollection = false
    
    // MARK: - Filtered Collections
    
    /// Collections visible on the main list (no empty, no system)
    private var visibleCollections: [RecipeCollection] {
        allCollections
            .filter { $0.isVisibleInMainList }
            .sorted { a, b in
                // Sort by type priority first
                if a.collectionType.sortPriority != b.collectionType.sortPriority {
                    return a.collectionType.sortPriority < b.collectionType.sortPriority
                }
                // Then by creation date (newer first)
                return a.createdAt > b.createdAt
            }
    }
    
    /// Theme collections (shown in their own section)
    private var themeCollections: [RecipeCollection] {
        visibleCollections.filter { $0.collectionType == .theme }
    }
    
    /// Non-theme collections
    private var otherCollections: [RecipeCollection] {
        visibleCollections.filter { $0.collectionType != .theme }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: HeirloomSpacing.lg) {
                    // Theme collections section
                    if !themeCollections.isEmpty {
                        themeSection
                    }
                    
                    // Other collections section
                    if !otherCollections.isEmpty {
                        otherCollectionsSection
                    }
                    
                    // Empty state
                    if visibleCollections.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
            }
            .background(HeirloomColors.background)
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateCollection = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionView()
            }
        }
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Section header with trial progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Discoveries")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    if !themeUnlockTracker.isTrialComplete {
                        Text("Day \(themeUnlockTracker.currentTrialDay) of 14")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // New unlocks badge
                if themeUnlockTracker.hasNewUnlocks {
                    Text("New!")
                        .font(HeirloomFonts.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
            }
            
            // Theme collection cards (full width)
            ForEach(themeCollections) { collection in
                NavigationLink(value: collection) {
                    ThemeCollectionCard(
                        collection: collection,
                        currentDay: themeUnlockTracker.currentTrialDay
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Other Collections Section
    
    private var otherCollectionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Section header
            if !themeCollections.isEmpty {
                Text("Your Collections")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            
            // Collection cards
            ForEach(otherCollections) { collection in
                NavigationLink(value: collection) {
                    StandardCollectionCard(collection: collection)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()
                .frame(height: 60)
            
            Image(systemName: "rectangle.stack")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)
            
            VStack(spacing: HeirloomSpacing.sm) {
                Text("No Collections Yet")
                    .font(HeirloomFonts.headline)
                    .foregroundStyle(HeirloomColors.primaryText)
                
                Text("Import recipes, have friends share with you, or create your own collections.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                showCreateCollection = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Collection")
                }
                .font(HeirloomFonts.bodyBold)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .foregroundStyle(.white)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }
            
            Spacer()
        }
        .padding(.horizontal, HeirloomSpacing.xl)
    }
}
```

---

## Task D1.2: Create Theme Collection Card

**New File:** `Heirloom/Features/Collections/Components/ThemeCollectionCard.swift`

```swift
//
//  ThemeCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCollectionCard: View {
    let collection: RecipeCollection
    let currentDay: Int
    
    private var theme: RecipeTheme? {
        collection.sourceTheme
    }
    
    private var recipeImages: [Recipe] {
        Array((collection.recipes ?? []).prefix(3))
    }
    
    private var unlockProgress: (unlocked: Int, total: Int) {
        let unlocked = collection.recipes?.count ?? 0
        let total = theme?.totalRecipes ?? unlocked
        return (unlocked, total)
    }
    
    private var isComplete: Bool {
        unlockProgress.unlocked >= unlockProgress.total
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image collage (60/40 split)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    // Large image (60%)
                    recipeImageView(for: recipeImages.first)
                        .frame(width: geo.size.width * 0.6)
                    
                    // Stacked small images (40%)
                    VStack(spacing: 2) {
                        recipeImageView(for: recipeImages.count > 1 ? recipeImages[1] : nil)
                        recipeImageView(for: recipeImages.count > 2 ? recipeImages[2] : nil)
                    }
                    .frame(width: geo.size.width * 0.4 - 2)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // Status badge
                statusBadge
                    .padding(HeirloomSpacing.sm)
            }
            
            // Info bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name)
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    Text(collection.subtitleText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                
                Spacer()
                
                // Progress indicator
                if !isComplete {
                    CircularProgressView(
                        progress: Double(unlockProgress.unlocked) / Double(unlockProgress.total),
                        lineWidth: 3
                    )
                    .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func recipeImageView(for recipe: Recipe?) -> some View {
        if let recipe = recipe,
           let urlString = recipe.imageURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderView
            }
            .clipped()
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(HeirloomColors.warmGray.opacity(0.2))
            .overlay(
                Image(systemName: collection.iconName)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if isComplete {
            Text("Complete")
                .font(HeirloomFonts.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.familyGreen)
                .foregroundStyle(.white)
                .cornerRadius(6)
        } else {
            Text("Day \(currentDay)")
                .font(HeirloomFonts.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(HeirloomColors.amber)
                .foregroundStyle(.white)
                .cornerRadius(6)
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(HeirloomColors.tomato, style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
        }
    }
}
```

---

## Task D1.3: Create Standard Collection Card

**New File:** `Heirloom/Features/Collections/Components/StandardCollectionCard.swift`

```swift
//
//  StandardCollectionCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct StandardCollectionCard: View {
    let collection: RecipeCollection
    
    private var recipeCount: Int {
        collection.recipes?.count ?? 0
    }
    
    private var previewRecipe: Recipe? {
        collection.recipes?.first
    }
    
    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Thumbnail
            thumbnailView
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                // Collection type badge
                HStack(spacing: 4) {
                    Image(systemName: collection.collectionType.defaultIconName)
                        .font(.system(size: 10))
                    Text(collection.collectionType.displayName)
                        .font(HeirloomFonts.caption2)
                }
                .foregroundStyle(HeirloomColors.secondaryText)
                
                // Name
                Text(collection.name)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)
                
                // Subtitle
                Text(collection.subtitleText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HeirloomColors.warmGray)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let recipe = previewRecipe,
           let urlString = recipe.imageURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholderView
            }
            .clipped()
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warmGray.opacity(0.15),
                        HeirloomColors.warmGray.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: collection.iconName)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }
}
```

---

## Task D1.4: Add Navigation Destination

**File:** `CollectionsListView.swift` or parent navigation container

```swift
// Add navigation destination for collection detail
.navigationDestination(for: RecipeCollection.self) { collection in
    CollectionDetailView(collection: collection)
}
```

---

## Verification Checklist

- [ ] System collections hidden (Favorites, All Recipes)
- [ ] Empty collections hidden
- [ ] Theme collections show in "Your Discoveries" section
- [ ] Theme cards show 3-image collage
- [ ] Theme cards show unlock progress
- [ ] Theme cards show day badge
- [ ] Non-theme collections show in "Your Collections"
- [ ] Standard cards show type badge
- [ ] Empty state shows when no collections
- [ ] Navigation to collection detail works
- [ ] `xcodebuild` succeeds

---

## Commit Message

```
feat(collections): Update collections list with filtering and cards

- Filter out system and empty collections
- Add ThemeCollectionCard with image collage and progress
- Add StandardCollectionCard for other collection types
- Split into "Your Discoveries" and "Your Collections" sections
- Show trial day and unlock progress
- Add empty state with create button

Part of collections overhaul Phase D1
```

---

## Next Phase

→ **Phase D2:** UX Writing and Nudges
