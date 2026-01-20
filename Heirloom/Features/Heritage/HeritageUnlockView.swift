//
//  HeritageUnlockView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI
import SwiftData

/// UI for managing daily heritage recipe unlocks during trial period
struct HeritageUnlockView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<RecipeCollection> { $0.heritageCollectionId != nil && $0.isBlindBox == true })
    private var blindBoxes: [RecipeCollection]

    @State private var unlockTracker: HeritageUnlockTracker?
    @State private var subscriptionManager: SubscriptionManager?
    @State private var paywallManager: PaywallManager?
    @State private var showConfetti = false
    @State private var isUnlocking = false
    @State private var errorMessage: String?
    @State private var showTrialExpired = false

    private var allBlindBoxesRevealed: Bool {
        let revealedCount = blindBoxes.filter { $0.isRevealed }.count
        return revealedCount == blindBoxes.count && blindBoxes.count > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Hero Section
                    heroSection

                    // Progress Bar
                    if let tracker = unlockTracker {
                        progressBar(tracker: tracker)
                    }

                    // Subscription Info
                    subscriptionInfoCard

                    // Unlock Button
                    unlockButton

                    // Collections Grid
                    collectionsGrid
                }
                .padding()
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Heritage Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeServices()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .sheet(isPresented: $showTrialExpired) {
                TrialExpiredView()
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.orange.gradient)

            Text("Heritage Collection")
                .font(HeirloomFonts.title2)

            if let tracker = unlockTracker {
                Text("\(tracker.unlockedRecipeIds.count) of 100 unlocked")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Trial countdown badge
            if let manager = subscriptionManager, manager.isInTrial, let daysRemaining = manager.daysRemaining, daysRemaining > 0 {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.orange)

                    Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in trial")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.sm)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Progress Bar

    private func progressBar(tracker: HeritageUnlockTracker) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                    .cornerRadius(4)

                // Progress
                Rectangle()
                    .fill(.orange.gradient)
                    .frame(
                        width: geometry.size.width * CGFloat(tracker.unlockedRecipeIds.count) / 100,
                        height: 8
                    )
                    .cornerRadius(4)
                    .animation(.spring(), value: tracker.unlockedRecipeIds.count)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }

    // MARK: - Subscription Info Card

    @ViewBuilder
    private var subscriptionInfoCard: some View {
        if let manager = subscriptionManager {
            VStack(spacing: HeirloomSpacing.md) {
                // Status header
                HStack {
                    Image(systemName: manager.isPremium ? "checkmark.circle.fill" : "clock.fill")
                        .foregroundStyle(manager.isPremium ? .green : .orange)

                    Text(manager.isPremium ? "Premium Member" : "Trial")
                        .font(HeirloomFonts.body)
                        .fontWeight(.bold)

                    Spacer()

                    if manager.isInTrial, let daysRemaining = manager.daysRemaining {
                        Text("\(daysRemaining)d left")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.orange.opacity(0.2)))
                    }
                }

                // Benefits / CTA
                if manager.isInTrial {
                    Text("Subscribe to keep all 100 recipes forever + unlock new features")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showTrialExpired = true
                    } label: {
                        HStack {
                            Text("View Plans")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.gradient)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(10)
                    }
                } else if manager.isPremium {
                    Text("You have full access to all 100 heritage recipes")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Trial expired • Subscribe to unlock remaining recipes")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showTrialExpired = true
                    } label: {
                        HStack {
                            Text("Subscribe Now")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue.gradient)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Unlock Button

    private var unlockButton: some View {
        Group {
            if !allBlindBoxesRevealed {
                // Blind boxes need to be revealed first
                blindBoxMessage
            } else if let manager = subscriptionManager, manager.isTrialExpired && !manager.isPremium {
                // Trial expired - show post-trial options
                trialExpiredMessage
            } else if let tracker = unlockTracker {
                if tracker.hasUnlocksAvailableToday && tracker.recipesToUnlockToday > 0 {
                    // Unlock button
                    Button {
                        unlockDaily()
                    } label: {
                        HStack(spacing: HeirloomSpacing.sm) {
                            Image(systemName: "gift.fill")
                            Text("Unlock Today's Recipes (\(tracker.recipesToUnlockToday))")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange.gradient)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(12)
                    }
                    .disabled(isUnlocking)
                    .padding(.horizontal)
                } else if tracker.totalRecipesRemaining == 0 {
                    // All unlocked
                    completionMessage
                } else {
                    // Already unlocked today
                    comeLaterMessage
                }
            }
        }
    }

    private var blindBoxMessage: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "gift")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Reveal Collections First")
                .font(HeirloomFonts.body)
                .fontWeight(.semibold)

            Text("Go to Collections tab and tap the mystery boxes to begin your heritage recipe journey")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var completionMessage: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("All 100 recipes unlocked!")
                .font(HeirloomFonts.body)
                .fontWeight(.semibold)

            Text("Enjoy the complete Heritage Collection")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var comeLaterMessage: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 32))
                .foregroundStyle(.orange)

            Text("Come back tomorrow!")
                .font(HeirloomFonts.body)
                .fontWeight(.semibold)

            Text("More recipes will be available")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var trialExpiredMessage: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text("Trial Complete!")
                .font(HeirloomFonts.body)
                .fontWeight(.semibold)

            if let tracker = unlockTracker {
                Text("You unlocked \(tracker.unlockedRecipeIds.count) recipes — they're yours forever!")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                showTrialExpired = true
            } label: {
                Text("See Your Options")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue.gradient)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Collections Grid

    private var collectionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HeirloomSpacing.md) {
            CollectionCard(
                id: "presidential-pantry",
                name: "Presidential Pantry",
                icon: "flag.fill",
                color: .blue
            )
            CollectionCard(
                id: "literary-kitchen",
                name: "Literary Kitchen",
                icon: "book.fill",
                color: .purple
            )
            CollectionCard(
                id: "ancient-table",
                name: "Ancient Table",
                icon: "scroll.fill",
                color: .brown
            )
            CollectionCard(
                id: "american-foundation",
                name: "American Foundation",
                icon: "star.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func initializeServices() {
        if unlockTracker == nil {
            unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
        }
        if subscriptionManager == nil {
            subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        }
        if paywallManager == nil {
            paywallManager = ServiceContainer.shared.resolve(PaywallManager.self)
        }

        // Initialize trial tracking if needed
        if let tracker = unlockTracker, tracker.trialStartDate == nil {
            tracker.startTrialPeriod()
        }
    }

    private func unlockDaily() {
        guard let tracker = unlockTracker else { return }

        isUnlocking = true

        Task {
            do {
                try await tracker.unlockDailyBatch(context: modelContext)

                await MainActor.run {
                    isUnlocking = false
                    showConfetti = true

                    // Hide confetti after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showConfetti = false
                    }

                    // Show success toast
                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    toastManager.success(
                        title: "Recipes Unlocked!",
                        message: "Explore \(tracker.recipesToUnlockToday) new heritage recipes"
                    )

                    // Show soft wall after positive moment (if eligible)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if let manager = subscriptionManager, !manager.isPremium,
                           let paywall = paywallManager {
                            if paywall.shouldShow(for: .fiveRecipesOrDay7) {
                                paywall.show(for: .fiveRecipesOrDay7)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isUnlocking = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Collection Card

struct CollectionCard: View {
    let id: String
    let name: String
    let icon: String
    let color: Color

    @Query private var recipes: [Recipe]
    @State private var unlockTracker: HeritageUnlockTracker?

    init(id: String, name: String, icon: String, color: Color) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color

        _recipes = Query(
            filter: #Predicate<Recipe> { recipe in
                recipe.heritageCollectionId == id
            }
        )
    }

    private var unlockedCount: Int {
        guard let tracker = unlockTracker else { return 0 }
        return recipes.filter { tracker.isUnlocked($0) }.count
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(color)

            Text(name)
                .font(HeirloomFonts.caption1)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(unlockedCount) unlocked")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .onAppear {
            if unlockTracker == nil {
                unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, RecipeCollection.self, configurations: config)

    // Create sample heritage recipes
    let recipe1 = Recipe(title: "Test Recipe 1", sourceType: .heritage, instructions: [], servings: nil)
    recipe1.isHeritageRecipe = true
    recipe1.heritageCollectionId = "presidential-pantry"
    container.mainContext.insert(recipe1)

    return HeritageUnlockView()
        .modelContainer(container)
}
