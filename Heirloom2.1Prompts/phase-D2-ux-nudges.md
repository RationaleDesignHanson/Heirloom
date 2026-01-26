# Heirloom Collections Overhaul
## Phase D2: UX Writing and Nudges

**Branch:** `feature/collections-D2-ux-nudges`
**Estimated Time:** 30-45 minutes
**Dependencies:** Phase D1 complete

---

## Objective

Add contextual nudges and UX writing that encourage users to add their own recipes to theme collections, celebrate new unlocks, and guide users through the discovery experience.

---

## Task D2.1: Add Recipe Nudge to Collection Detail

**File:** `Heirloom/Features/Collections/CollectionDetailView.swift`

Add this component below the recipe list when appropriate:

```swift
struct CollectionDetailView: View {
    let collection: RecipeCollection
    
    @Environment(\.modelContext) private var modelContext
    @State private var showAddRecipe = false
    
    // Count of user-added (non-curated) recipes
    private var userAddedRecipeCount: Int {
        collection.recipes?.filter { !$0.isCurated }.count ?? 0
    }
    
    // Should show the "add your own" nudge
    private var shouldShowAddNudge: Bool {
        collection.collectionType == .theme && userAddedRecipeCount == 0
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.md) {
                // Recipe list
                ForEach(collection.recipes ?? []) { recipe in
                    RecipeCard(recipe: recipe)
                }
                
                // Add recipe nudge
                if shouldShowAddNudge {
                    addRecipeNudge
                }
                
                // Spacer for bottom padding
                Color.clear
                    .frame(height: HeirloomSpacing.xl)
            }
            .padding(.horizontal, HeirloomSpacing.lg)
        }
        .navigationTitle(collection.name)
        .sheet(isPresented: $showAddRecipe) {
            AddRecipeView(defaultCollection: collection)
        }
    }
    
    // MARK: - Add Recipe Nudge
    
    private var addRecipeNudge: some View {
        VStack(spacing: 0) {
            // Divider with text
            HStack {
                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.2))
                    .frame(height: 1)
                
                Text("Make it yours")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, HeirloomSpacing.sm)
                
                Rectangle()
                    .fill(HeirloomColors.warmGray.opacity(0.2))
                    .frame(height: 1)
            }
            .padding(.vertical, HeirloomSpacing.lg)
            
            // Nudge card
            Button {
                showAddRecipe = true
            } label: {
                HStack(spacing: HeirloomSpacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato.opacity(0.1))
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                    
                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add Your Own Recipes")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                        
                        Text(nudgeSubtitleText)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(HeirloomColors.tomato)
                }
                .padding(HeirloomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(HeirloomColors.cardBackground)
                        .shadow(color: HeirloomColors.tomato.opacity(0.1), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(HeirloomColors.tomato.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var nudgeSubtitleText: String {
        let themeName = collection.name.lowercased()
        return "Do you have your own \(themeName) recipes? Add them here to keep everything together."
    }
}
```

---

## Task D2.2: Create Unlock Celebration Toast

**New File:** `Heirloom/Features/Themes/UnlockCelebrationView.swift`

```swift
//
//  UnlockCelebrationView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct UnlockCelebrationView: View {
    let newRecipeCount: Int
    let themeNames: [String]
    let onDismiss: () -> Void
    let onViewRecipes: () -> Void
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: HeirloomSpacing.md) {
                // Confetti icon
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.amber)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isVisible)
                
                // Title
                Text("New Recipes Unlocked!")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)
                
                // Description
                Text(descriptionText)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                // Buttons
                HStack(spacing: HeirloomSpacing.md) {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Later")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HeirloomSpacing.md)
                    }
                    
                    Button {
                        onViewRecipes()
                    } label: {
                        Text("View Recipes")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HeirloomSpacing.md)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(HeirloomColors.cardBackground)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, HeirloomSpacing.lg)
            .offset(y: isVisible ? 0 : 300)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)
            
            Spacer()
                .frame(height: 40)
        }
        .background(Color.black.opacity(isVisible ? 0.3 : 0).ignoresSafeArea())
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    private var descriptionText: String {
        if themeNames.count == 1 {
            return "\(newRecipeCount) new recipe\(newRecipeCount == 1 ? "" : "s") from \(themeNames[0]) \(newRecipeCount == 1 ? "is" : "are") ready to explore."
        } else {
            let names = themeNames.prefix(2).joined(separator: " and ")
            let suffix = themeNames.count > 2 ? " and more" : ""
            return "\(newRecipeCount) new recipes from \(names)\(suffix) are ready to explore."
        }
    }
}

// MARK: - Preview

#Preview {
    UnlockCelebrationView(
        newRecipeCount: 3,
        themeNames: ["Automat Classics", "Victory Kitchen"],
        onDismiss: {},
        onViewRecipes: {}
    )
}
```

---

## Task D2.3: Integrate Celebration into Main View

**File:** Main tab view or home view

```swift
struct MainTabView: View {
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @State private var showUnlockCelebration = false
    @State private var newUnlockInfo: (count: Int, themes: [String]) = (0, [])
    
    var body: some View {
        TabView {
            // ... tabs
        }
        .onAppear {
            checkForNewUnlocks()
        }
        .overlay {
            if showUnlockCelebration {
                UnlockCelebrationView(
                    newRecipeCount: newUnlockInfo.count,
                    themeNames: newUnlockInfo.themes,
                    onDismiss: {
                        dismissCelebration()
                    },
                    onViewRecipes: {
                        dismissCelebration()
                        navigateToCollections()
                    }
                )
            }
        }
    }
    
    private func checkForNewUnlocks() {
        guard themeUnlockTracker.checkForNewUnlocks() else { return }
        
        // Get unlock details
        // This requires fetching themes and counting new recipes
        // Simplified for this example:
        let themes = getThemesWithNewUnlocks()
        let count = countNewRecipes()
        
        if count > 0 {
            newUnlockInfo = (count, themes.map { $0.name })
            
            // Slight delay for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showUnlockCelebration = true
            }
        }
    }
    
    private func dismissCelebration() {
        withAnimation {
            showUnlockCelebration = false
        }
        themeUnlockTracker.markUnlocksAsSeen()
    }
}
```

---

## Task D2.4: Add Collection Empty State with Contextual Copy

**File:** `CollectionDetailView.swift`

Add contextual empty states based on collection type:

```swift
@ViewBuilder
private var emptyState: some View {
    VStack(spacing: HeirloomSpacing.lg) {
        Image(systemName: emptyStateIcon)
            .font(.system(size: 48))
            .foregroundStyle(HeirloomColors.warmGray)
        
        Text(emptyStateTitle)
            .font(HeirloomFonts.headline)
            .foregroundStyle(HeirloomColors.primaryText)
        
        Text(emptyStateMessage)
            .font(HeirloomFonts.body)
            .foregroundStyle(HeirloomColors.secondaryText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, HeirloomSpacing.xl)
        
        if let actionTitle = emptyStateActionTitle {
            Button {
                handleEmptyStateAction()
            } label: {
                Text(actionTitle)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
            }
        }
    }
    .padding(.vertical, HeirloomSpacing.xxl)
}

private var emptyStateIcon: String {
    switch collection.collectionType {
    case .theme:
        return "sparkles"
    case .fromFriends:
        return "person.2"
    case .imports:
        return "square.and.arrow.down"
    default:
        return "rectangle.stack"
    }
}

private var emptyStateTitle: String {
    switch collection.collectionType {
    case .theme:
        return "Recipes Coming Soon"
    case .fromFriends:
        return "No Shared Recipes Yet"
    case .imports:
        return "No Imports Yet"
    default:
        return "No Recipes Yet"
    }
}

private var emptyStateMessage: String {
    switch collection.collectionType {
    case .theme:
        return "New \(collection.name) recipes unlock every few days during your trial. Check back soon!"
    case .fromFriends:
        return "When friends share recipes with you, they'll appear here. Share the app with friends to start collecting!"
    case .imports:
        return "Recipes you save from websites will appear here. Try pasting a recipe URL to get started."
    default:
        return "Add recipes to this collection to see them here."
    }
}

private var emptyStateActionTitle: String? {
    switch collection.collectionType {
    case .fromFriends:
        return "Share App"
    case .imports:
        return "Import Recipe"
    case .userCreated:
        return "Add Recipe"
    default:
        return nil
    }
}
```

---

## Task D2.5: Add Trial Progress Banner

**New File:** `Heirloom/Features/Themes/TrialProgressBanner.swift`

```swift
//
//  TrialProgressBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct TrialProgressBanner: View {
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    
    private var daysRemaining: Int {
        themeUnlockTracker.daysRemaining
    }
    
    private var isTrialComplete: Bool {
        themeUnlockTracker.isTrialComplete
    }
    
    var body: some View {
        if !isTrialComplete {
            HStack(spacing: HeirloomSpacing.md) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(themeUnlockTracker.currentTrialDay) / 14.0)
                        .stroke(HeirloomColors.tomato, style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round
                        ))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(themeUnlockTracker.currentTrialDay)")
                        .font(HeirloomFonts.caption1)
                        .fontWeight(.bold)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .frame(width: 40, height: 40)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(themeUnlockTracker.currentTrialDay) of 14")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                    
                    Text(bannerSubtitle)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(HeirloomColors.cardBackground)
            )
        }
    }
    
    private var bannerSubtitle: String {
        if daysRemaining == 1 {
            return "Last day! Final recipes unlock tomorrow."
        } else if daysRemaining <= 3 {
            return "\(daysRemaining) days left in your discovery trial"
        } else {
            return "New recipes unlock every few days"
        }
    }
}
```

---

## Task D2.6: UX Copy Constants

**New File:** `Heirloom/Core/Constants/UXCopy.swift`

```swift
//
//  UXCopy.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import Foundation

/// Centralized UX copy for consistency
enum UXCopy {
    
    // MARK: - Theme Selection
    
    enum ThemeSelection {
        static let title = "What sounds delicious?"
        static let subtitle = "Pick 2-5 themes. We'll unlock recipes from your selections over the next 14 days."
        static let minSelectionsHint = "Select at least %d more theme%@"
        static let maxSelectionsHint = "Maximum themes selected"
        static let continueButton = "Continue"
    }
    
    // MARK: - Collections
    
    enum Collections {
        static let discoverySectionTitle = "Your Discoveries"
        static let collectionsSectionTitle = "Your Collections"
        static let emptyTitle = "No Collections Yet"
        static let emptySubtitle = "Import recipes, have friends share with you, or create your own collections."
    }
    
    // MARK: - Unlock Progress
    
    enum Unlock {
        static func dayProgress(_ current: Int) -> String {
            "Day \(current) of 14"
        }
        
        static func recipesUnlocked(_ unlocked: Int, _ total: Int) -> String {
            if unlocked < total {
                return "\(unlocked) of \(total) recipes unlocked"
            }
            return "All \(total) recipes unlocked"
        }
        
        static let complete = "Complete"
        static let newBadge = "New!"
    }
    
    // MARK: - Nudges
    
    enum Nudges {
        static let addYourOwn = "Make it yours"
        static let addRecipeTitle = "Add Your Own Recipes"
        
        static func addRecipeSubtitle(themeName: String) -> String {
            "Do you have your own \(themeName.lowercased()) recipes? Add them here to keep everything together."
        }
    }
    
    // MARK: - Celebration
    
    enum Celebration {
        static let title = "New Recipes Unlocked!"
        static let viewButton = "View Recipes"
        static let laterButton = "Later"
        
        static func description(count: Int, themeNames: [String]) -> String {
            let recipeWord = count == 1 ? "recipe" : "recipes"
            let verb = count == 1 ? "is" : "are"
            
            if themeNames.count == 1 {
                return "\(count) new \(recipeWord) from \(themeNames[0]) \(verb) ready to explore."
            } else {
                let names = themeNames.prefix(2).joined(separator: " and ")
                let suffix = themeNames.count > 2 ? " and more" : ""
                return "\(count) new \(recipeWord) from \(names)\(suffix) \(verb) ready to explore."
            }
        }
    }
}
```

---

## Verification Checklist

- [ ] Add recipe nudge shows on theme collections with no user recipes
- [ ] Nudge hides once user adds a recipe
- [ ] Unlock celebration shows when new recipes unlock
- [ ] Celebration can be dismissed
- [ ] Celebration "View Recipes" navigates to collections
- [ ] Empty states show contextual copy per collection type
- [ ] Trial progress banner shows correct day
- [ ] UX copy is consistent throughout
- [ ] `xcodebuild` succeeds

---

## Commit Message

```
feat(ux): Add nudges and celebration for collections

- Add "Make it yours" recipe nudge to theme collections
- Create unlock celebration overlay
- Add contextual empty states per collection type
- Create trial progress banner
- Centralize UX copy in constants file
- Add haptic feedback for celebrations

Part of collections overhaul Phase D2
```

---

## Next Phase

→ **Firebase Schema:** Set up Firebase structure for themes and recipes
