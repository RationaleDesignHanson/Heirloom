# Heirloom Collections Overhaul
## Phase B2: Onboarding Integration

**Branch:** `feature/collections-B2-onboarding-integration`
**Estimated Time:** 30-45 minutes
**Dependencies:** Phase B1 complete

---

## Objective

Integrate the theme selection screen into the existing onboarding flow. Position it after value propositions but before subscription.

---

## Task B2.1: Update Onboarding Flow Enum

**File:** `Heirloom/Features/Onboarding/OnboardingContainerView.swift` (or equivalent)

Find the onboarding step enum and add theme selection:

```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case features = 1      // Value props
    case themeSelection = 2 // NEW
    case subscription = 3
    case complete = 4
    
    var progress: Double {
        Double(rawValue) / Double(Self.allCases.count - 1)
    }
}
```

---

## Task B2.2: Update Onboarding Container

**File:** `Heirloom/Features/Onboarding/OnboardingContainerView.swift`

```swift
struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedThemeIds: [String] = []
    
    var body: some View {
        ZStack {
            // Background
            HeirloomColors.background
                .ignoresSafeArea()
            
            // Current step view
            stepView
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
    
    @ViewBuilder
    private var stepView: some View {
        switch currentStep {
        case .welcome:
            OnboardingWelcomeScreen {
                advanceTo(.features)
            }
            .transition(.move(edge: .trailing))
            
        case .features:
            OnboardingFeaturesScreen {
                advanceTo(.themeSelection)
            }
            .transition(.move(edge: .trailing))
            
        case .themeSelection:
            ThemeSelectionScreen { themeIds in
                handleThemeSelection(themeIds)
            }
            .transition(.move(edge: .trailing))
            .task {
                await loadThemesIfNeeded()
            }
            
        case .subscription:
            OnboardingSubscriptionScreen {
                advanceTo(.complete)
            }
            .transition(.move(edge: .trailing))
            
        case .complete:
            // Handled by parent - dismiss onboarding
            Color.clear
                .onAppear {
                    completeOnboarding()
                }
        }
    }
    
    // MARK: - Navigation
    
    private func advanceTo(_ step: OnboardingStep) {
        withAnimation {
            currentStep = step
        }
    }
    
    // MARK: - Theme Selection Handler
    
    private func handleThemeSelection(_ themeIds: [String]) {
        selectedThemeIds = themeIds
        
        // Start the trial
        themeUnlockTracker.startTrial(withThemeIds: themeIds)
        
        // Create collections for selected themes
        createThemeCollections(for: themeIds)
        
        // Download initial recipes
        Task {
            await downloadInitialRecipes(for: themeIds)
        }
        
        // Continue to subscription
        advanceTo(.subscription)
    }
    
    // MARK: - Theme Loading
    
    private func loadThemesIfNeeded() async {
        let descriptor = FetchDescriptor<RecipeTheme>()
        let existingThemes = (try? modelContext.fetch(descriptor)) ?? []
        
        // Only load if we don't have themes
        if existingThemes.isEmpty {
            let loader = ThemeLoader()
            do {
                _ = try await loader.loadThemes(into: modelContext)
            } catch {
                Log.error("Failed to load themes: \(error)", category: .onboarding)
            }
        }
    }
    
    // MARK: - Collection Creation
    
    private func createThemeCollections(for themeIds: [String]) {
        let descriptor = FetchDescriptor<RecipeTheme>()
        guard let allThemes = try? modelContext.fetch(descriptor) else { return }
        
        let selectedThemes = allThemes.filter { themeIds.contains($0.firebaseId) }
        
        for theme in selectedThemes {
            // Check if collection already exists
            let themeName = theme.name
            let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { $0.name == themeName && $0.collectionType == .theme }
            )
            
            if let existing = try? modelContext.fetch(collectionDescriptor).first {
                // Link existing collection to theme
                existing.sourceTheme = theme
                theme.collection = existing
            } else {
                // Create new collection
                let collection = RecipeCollection(
                    name: theme.name,
                    iconName: theme.iconName
                )
                collection.collectionType = .theme
                collection.sourceTheme = theme
                theme.collection = collection
                modelContext.insert(collection)
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Initial Recipe Download
    
    private func downloadInitialRecipes(for themeIds: [String]) async {
        let service = ThemeRecipeService()
        
        let descriptor = FetchDescriptor<RecipeTheme>(
            predicate: #Predicate { themeIds.contains($0.firebaseId) }
        )
        
        guard let themes = try? modelContext.fetch(descriptor) else { return }
        
        for theme in themes {
            do {
                let recipes = try await service.downloadRecipes(
                    for: theme,
                    upToDay: 1, // Day 1 only for initial load
                    context: modelContext
                )
                
                // Add recipes to theme's collection
                if let collection = theme.collection {
                    for recipe in recipes {
                        recipe.collections = [collection]
                    }
                }
                
                Log.info("Downloaded \(recipes.count) recipes for \(theme.name)", category: .onboarding)
            } catch {
                Log.error("Failed to download recipes for \(theme.name): \(error)", category: .onboarding)
            }
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Completion
    
    private func completeOnboarding() {
        // Mark onboarding complete in UserDefaults
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        
        // Post notification for app to dismiss onboarding
        NotificationCenter.default.post(name: .onboardingComplete, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let onboardingComplete = Notification.Name("onboardingComplete")
}

// MARK: - Log Category

extension Log.Category {
    static let onboarding = Log.Category("onboarding")
}
```

---

## Task B2.3: Update Skip Logic (if exists)

If there's a "Skip" button anywhere in onboarding, ensure it still works but skips to subscription (user can still use app without themes, but won't get curated recipes):

```swift
// If user skips theme selection
private func skipThemeSelection() {
    // Don't start trial with no themes
    // Just continue to subscription
    advanceTo(.subscription)
}
```

---

## Task B2.4: Handle Returning Users

**File:** App entry point or root view

```swift
// Check if user has already completed onboarding
struct RootView: View {
    @AppStorage("has_completed_onboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    
    var body: some View {
        if hasCompletedOnboarding || themeUnlockTracker.hasSelectedThemes {
            MainTabView()
        } else {
            OnboardingContainerView()
        }
    }
}
```

---

## Task B2.5: Add Re-onboarding Option (Settings)

**File:** Settings view (for users who want to re-select themes)

```swift
// In Settings
Section("Discovery") {
    Button("Re-select Recipe Themes") {
        showThemeReselection = true
    }
}
.sheet(isPresented: $showThemeReselection) {
    NavigationStack {
        ThemeSelectionScreen { themeIds in
            handleThemeReselection(themeIds)
            showThemeReselection = false
        }
        .navigationTitle("Select Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    showThemeReselection = false
                }
            }
        }
    }
}

private func handleThemeReselection(_ themeIds: [String]) {
    // Reset and restart with new themes
    themeUnlockTracker.resetTrial()
    themeUnlockTracker.startTrial(withThemeIds: themeIds)
    
    // Recreate collections
    // ... same logic as onboarding
}
```

---

## Verification Checklist

- [ ] Onboarding flows: Welcome → Features → Themes → Subscription
- [ ] Theme selection persists after completing onboarding
- [ ] Returning users skip onboarding
- [ ] Trial starts when themes selected
- [ ] Collections created for selected themes
- [ ] Day 1 recipes downloaded
- [ ] Settings allows theme re-selection
- [ ] Skip works (goes to subscription without themes)
- [ ] `xcodebuild` succeeds

---

## Test Flow

1. Fresh install → Onboarding starts
2. Tap through Welcome, Features
3. Select 3 themes
4. Tap Continue
5. Verify trial started (check UserDefaults)
6. Verify collections created
7. Complete subscription flow
8. Verify main app shows theme collections
9. Kill and relaunch → Main app (no onboarding)

---

## Commit Message

```
feat(onboarding): Integrate theme selection into flow

- Add themeSelection step to onboarding
- Create theme collections on selection
- Download Day 1 recipes after selection
- Start trial tracker on theme selection
- Add re-selection option in Settings
- Handle returning users correctly

Part of collections overhaul Phase B2
```

---

## Next Phase

→ **Phase C1:** Collection Routing (From Friends, Imports)
