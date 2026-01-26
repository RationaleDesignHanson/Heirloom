# Heirloom Collections Overhaul
## Phase B1: Theme Selection Screen

**Branch:** `feature/collections-B1-theme-selection-ui`
**Estimated Time:** 60-90 minutes
**Dependencies:** Phase A1, A2, A3 complete

---

## Objective

Create an immersive theme selection screen for onboarding. Users pick 2-5 themes that interest them, which determines what recipes they'll receive during the trial.

---

## Task B1.1: Create Theme Card Component

**New File:** `Heirloom/Features/Onboarding/Components/ThemeCard.swift`

```swift
//
//  ThemeCard.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCard: View {
    let theme: RecipeTheme
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 240
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                onTap()
            }
        }) {
            ZStack(alignment: .topTrailing) {
                // Background image
                themeImage
                
                // Gradient overlay
                LinearGradient(
                    colors: [.clear, .clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content overlay
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    
                    // Category badge
                    Text(theme.category.displayName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 4)
                    
                    // Theme name
                    Text(theme.name)
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Tagline
                    Text(theme.tagline)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                        .padding(.top, 4)
                    
                    // Recipe count
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 10))
                        Text("\(theme.totalRecipes) recipes")
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 8)
                }
                .padding(HeirloomSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Selection checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(HeirloomColors.familyGreen)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        )
                        .padding(HeirloomSpacing.sm)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? HeirloomColors.familyGreen : .clear,
                        lineWidth: 3
                    )
            )
            .shadow(
                color: .black.opacity(isSelected ? 0.2 : 0.1),
                radius: isSelected ? 12 : 8,
                x: 0,
                y: isSelected ? 6 : 4
            )
            .opacity(isDisabled && !isSelected ? 0.5 : 1.0)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    @ViewBuilder
    private var themeImage: some View {
        if let urlString = theme.coverImageURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderImage
                case .empty:
                    placeholderImage
                        .overlay(ProgressView())
                @unknown default:
                    placeholderImage
                }
            }
        } else {
            placeholderImage
        }
    }
    
    private var placeholderImage: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warmGray.opacity(0.3),
                        HeirloomColors.warmGray.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: theme.iconName)
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        ThemeCard(
            theme: .preview,
            isSelected: false,
            isDisabled: false,
            onTap: {}
        )
        
        ThemeCard(
            theme: .preview,
            isSelected: true,
            isDisabled: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}

// MARK: - Preview Helper

extension RecipeTheme {
    static var preview: RecipeTheme {
        RecipeTheme(
            firebaseId: "preview",
            name: "Automat Classics",
            tagline: "Recipes from restaurants that no longer exist",
            themeDescription: "Horn & Hardart's legendary cafeteria...",
            iconName: "building.columns",
            category: .source,
            totalRecipes: 14,
            unlockSchedule: [1, 2, 3, 5, 7, 9, 11, 14]
        )
    }
}
```

---

## Task B1.2: Create Category Section Component

**New File:** `Heirloom/Features/Onboarding/Components/ThemeCategorySection.swift`

```swift
//
//  ThemeCategorySection.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct ThemeCategorySection: View {
    let category: ThemeCategory
    let themes: [RecipeTheme]
    @Binding var selectedIds: Set<String>
    let maxSelections: Int
    
    private var isAtMaxSelections: Bool {
        selectedIds.count >= maxSelections
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Section header
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: category.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HeirloomColors.tomato)
                
                Text(category.displayName)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            
            // Horizontal scroll of theme cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HeirloomSpacing.md) {
                    ForEach(themes.sorted(by: { $0.sortOrder < $1.sortOrder })) { theme in
                        ThemeCard(
                            theme: theme,
                            isSelected: selectedIds.contains(theme.firebaseId),
                            isDisabled: isAtMaxSelections && !selectedIds.contains(theme.firebaseId),
                            onTap: {
                                toggleSelection(theme)
                            }
                        )
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
            }
        }
    }
    
    private func toggleSelection(_ theme: RecipeTheme) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedIds.contains(theme.firebaseId) {
                selectedIds.remove(theme.firebaseId)
            } else if selectedIds.count < maxSelections {
                selectedIds.insert(theme.firebaseId)
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
}
```

---

## Task B1.3: Create Theme Selection Screen

**New File:** `Heirloom/Features/Onboarding/ThemeSelectionScreen.swift`

```swift
//
//  ThemeSelectionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI
import SwiftData

struct ThemeSelectionScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecipeTheme.sortOrder) private var themes: [RecipeTheme]
    
    @State private var selectedThemeIds: Set<String> = []
    @State private var isLoading = false
    
    let onComplete: ([String]) -> Void
    
    // Configuration
    private let minSelections = 2
    private let maxSelections = 5
    
    // Grouped themes by category
    private var groupedThemes: [(ThemeCategory, [RecipeTheme])] {
        let grouped = Dictionary(grouping: themes) { $0.category }
        return ThemeCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let themes = grouped[category], !themes.isEmpty else {
                    return nil
                }
                return (category, themes)
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Theme categories
            if themes.isEmpty {
                loadingOrEmptyState
            } else {
                themesScrollView
            }
            
            // Continue button
            continueSection
        }
        .background(HeirloomColors.background)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Text("What sounds delicious?")
                .font(HeirloomFonts.largeTitle)
                .foregroundStyle(HeirloomColors.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Pick \(minSelections)-\(maxSelections) themes. We'll unlock recipes from your selections over the next 14 days.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)
        }
        .padding(.top, HeirloomSpacing.xl)
        .padding(.bottom, HeirloomSpacing.lg)
    }
    
    // MARK: - Themes
    
    private var themesScrollView: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.xl) {
                ForEach(groupedThemes, id: \.0) { category, categoryThemes in
                    ThemeCategorySection(
                        category: category,
                        themes: categoryThemes,
                        selectedIds: $selectedThemeIds,
                        maxSelections: maxSelections
                    )
                }
            }
            .padding(.vertical, HeirloomSpacing.md)
        }
    }
    
    private var loadingOrEmptyState: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading themes...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Continue Button
    
    private var continueSection: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            // Selection counter
            if selectedThemeIds.count > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<maxSelections, id: \.self) { index in
                        Circle()
                            .fill(index < selectedThemeIds.count ?
                                  HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, HeirloomSpacing.sm)
            }
            
            // Continue button
            Button {
                completeSelection()
            } label: {
                HStack(spacing: HeirloomSpacing.sm) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Continue")
                        
                        if selectedThemeIds.count >= minSelections {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .font(HeirloomFonts.bodyBold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, HeirloomSpacing.md)
                .background(canContinue ? HeirloomColors.tomato : HeirloomColors.warmGray)
                .foregroundStyle(.white)
                .cornerRadius(HeirloomSpacing.cardCornerRadius)
            }
            .disabled(!canContinue || isLoading)
            
            // Helper text
            if selectedThemeIds.count < minSelections {
                Text("Select at least \(minSelections - selectedThemeIds.count) more theme\(minSelections - selectedThemeIds.count == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            } else if selectedThemeIds.count == maxSelections {
                Text("Maximum themes selected")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.lg)
        .background(
            Rectangle()
                .fill(HeirloomColors.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: -5)
        )
    }
    
    // MARK: - Helpers
    
    private var canContinue: Bool {
        selectedThemeIds.count >= minSelections
    }
    
    private func completeSelection() {
        guard canContinue else { return }
        
        isLoading = true
        
        // Mark themes as selected in the model
        for theme in themes {
            theme.isSelected = selectedThemeIds.contains(theme.firebaseId)
        }
        
        try? modelContext.save()
        
        // Short delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(Array(selectedThemeIds))
        }
    }
}

// MARK: - Preview

#Preview {
    ThemeSelectionScreen { selectedIds in
        print("Selected: \(selectedIds)")
    }
    .modelContainer(for: RecipeTheme.self, inMemory: true)
}
```

---

## Task B1.4: Create Theme Loader (Fetch from Firebase)

**New File:** `Heirloom/Core/Services/Themes/ThemeLoader.swift`

```swift
//
//  ThemeLoader.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Loads available themes from Firebase
actor ThemeLoader {
    
    private let firestore = Firestore.firestore()
    
    /// Fetch all available themes from Firebase and save to local database
    func loadThemes(into context: ModelContext) async throws -> [RecipeTheme] {
        let snapshot = try await firestore
            .collection("themes")
            .order(by: "sortOrder")
            .getDocuments()
        
        var themes: [RecipeTheme] = []
        
        for document in snapshot.documents {
            if let theme = try? parseTheme(from: document) {
                // Check if already exists locally
                let firebaseId = theme.firebaseId
                let descriptor = FetchDescriptor<RecipeTheme>(
                    predicate: #Predicate { $0.firebaseId == firebaseId }
                )
                
                if let existing = try? context.fetch(descriptor).first {
                    // Update existing
                    updateTheme(existing, from: theme)
                    themes.append(existing)
                } else {
                    // Insert new
                    context.insert(theme)
                    themes.append(theme)
                }
            }
        }
        
        try context.save()
        return themes
    }
    
    private func parseTheme(from document: QueryDocumentSnapshot) throws -> RecipeTheme {
        let data = document.data()
        
        guard let name = data["name"] as? String,
              let tagline = data["tagline"] as? String,
              let description = data["description"] as? String,
              let iconName = data["iconName"] as? String,
              let categoryRaw = data["category"] as? String,
              let category = ThemeCategory(rawValue: categoryRaw),
              let totalRecipes = data["totalRecipes"] as? Int,
              let unlockSchedule = data["unlockSchedule"] as? [Int]
        else {
            throw ThemeLoadError.invalidData(document.documentID)
        }
        
        let theme = RecipeTheme(
            firebaseId: document.documentID,
            name: name,
            tagline: tagline,
            themeDescription: description,
            iconName: iconName,
            category: category,
            totalRecipes: totalRecipes,
            unlockSchedule: unlockSchedule
        )
        
        // Optional fields
        theme.coverImageURL = data["coverImageURL"] as? String
        theme.source = data["source"] as? String
        theme.era = data["era"] as? String
        theme.region = data["region"] as? String
        theme.sortOrder = data["sortOrder"] as? Int ?? 0
        
        return theme
    }
    
    private func updateTheme(_ existing: RecipeTheme, from new: RecipeTheme) {
        existing.name = new.name
        existing.tagline = new.tagline
        existing.themeDescription = new.themeDescription
        existing.iconName = new.iconName
        existing.category = new.category
        existing.totalRecipes = new.totalRecipes
        existing.unlockSchedule = new.unlockSchedule
        existing.coverImageURL = new.coverImageURL
        existing.source = new.source
        existing.era = new.era
        existing.region = new.region
        existing.sortOrder = new.sortOrder
        existing.updatedAt = Date()
    }
}

enum ThemeLoadError: Error {
    case invalidData(String)
    case networkError(Error)
}
```

---

## Verification Checklist

- [ ] ThemeCard displays correctly with image/placeholder
- [ ] ThemeCard shows selection state
- [ ] ThemeCard disabled state works at max selections
- [ ] ThemeCategorySection scrolls horizontally
- [ ] ThemeSelectionScreen shows all categories
- [ ] Selection counter updates correctly
- [ ] Cannot continue with < 2 selections
- [ ] Cannot select > 5 themes
- [ ] ThemeLoader fetches from Firebase
- [ ] Themes persist to SwiftData
- [ ] `xcodebuild` succeeds

---

## Commit Message

```
feat(onboarding): Create theme selection screen

- Add ThemeCard component with selection states
- Add ThemeCategorySection with horizontal scroll
- Create ThemeSelectionScreen with 2-5 selection limit
- Add ThemeLoader for Firebase fetch
- Include selection counter and helper text
- Add haptic feedback on selection

Part of collections overhaul Phase B1
```

---

## Next Phase

→ **Phase B2:** Integrate into Onboarding Flow
