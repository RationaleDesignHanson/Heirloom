//
//  OnboardingScreen2.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI
import SwiftData

/// Second onboarding screen - Heritage Collections introduction
struct OnboardingScreen2: View {
    let onComplete: () -> Void
    @EnvironmentObject private var notificationService: FirebaseNotificationService

    @Query(filter: #Predicate<RecipeCollection> { $0.heritageCollectionId != nil }, sort: \RecipeCollection.createdDate)
    private var heritageCollections: [RecipeCollection]

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.cream
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Text("You're not starting empty")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)

                    Text("We've included 4 Heritage Collections with curated recipes from different culinary traditions. Explore, cook, and make them your own.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 40)

                // 2x2 Grid of Heritage Collections (tappable)
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: HeirloomSpacing.md),
                    GridItem(.flexible(), spacing: HeirloomSpacing.md)
                ], spacing: HeirloomSpacing.md) {
                    ForEach(heritageCollections.prefix(4), id: \.id) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                                .environmentObject(notificationService)
                                .onDisappear {
                                    // When user backs out, complete onboarding
                                    completeOnboarding()
                                }
                        } label: {
                            HeritageCollectionCard(collection: collection)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)

                Spacer()

                // Explore Collections Button
                Button {
                    completeOnboarding()
                } label: {
                    Text("Explore Collections")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.hasCompletedOnboarding)
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    OnboardingScreen2(onComplete: {})
        .modelContainer(for: RecipeCollection.self, inMemory: true)
}
