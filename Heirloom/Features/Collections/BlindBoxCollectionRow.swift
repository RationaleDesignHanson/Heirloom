//
//  BlindBoxCollectionRow.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import SwiftUI
import SwiftData

/// Collection row with blind box wrapped state
struct BlindBoxCollectionRow: View {
    let collection: RecipeCollection
    let onReveal: () -> Void

    @State private var isRevealing = false
    @State private var unlockTracker: HeritageUnlockTracker?

    var body: some View {
        if collection.isRevealed {
            // Show normal collection row after reveal
            CollectionRow(collection: collection)
        } else {
            // Show wrapped blind box
            wrappedBox
                .onAppear {
                    if unlockTracker == nil {
                        unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
                    }
                }
        }
    }

    private var wrappedBox: some View {
        Button {
            // Only allow reveal if seeding is complete
            guard unlockTracker?.isSeedingInProgress != true else { return }
            revealBox()
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Mystery icon with blur
                ZStack {
                    Image(systemName: "gift.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(width: 32, height: 32)
                        .background(
                            LinearGradient(
                                colors: [
                                    HeirloomColors.tomato,
                                    HeirloomColors.tomato.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(8)
                }
                .blur(radius: isRevealing ? 0 : 2)

                // Mystery text
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heritage Collection")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .blur(radius: isRevealing ? 0 : 1.5)

                    // Show loading message if seeding, otherwise normal tap message
                    if unlockTracker?.isSeedingInProgress == true {
                        HStack(spacing: HeirloomSpacing.xs) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(HeirloomColors.tomato)
                            Text("Preparing some recipes so you're not starting empty-handed")
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(HeirloomColors.tomato)
                        }
                    } else {
                        Text("Tap to unlock")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()

                // Shimmer indicator
                Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundStyle(HeirloomColors.tomato)
                    .opacity(isRevealing ? 0 : 1)
            }
            .padding(HeirloomSpacing.md)
            .background(
                ZStack {
                    Color(hex: "#F8F8F8")

                    // Shimmer overlay
                    if !isRevealing {
                        LinearGradient(
                            colors: [
                                .white.opacity(0),
                                .white.opacity(0.3),
                                .white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blur(radius: 4)
                    }
                }
            )
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .strokeBorder(
                        HeirloomColors.tomato.opacity(0.3),
                        lineWidth: isRevealing ? 0 : 2,
                        antialiased: true
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isRevealing ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRevealing)
    }

    private func revealBox() {
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Animate reveal
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            isRevealing = true
        }

        // Complete reveal after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onReveal()

            // Second haptic
            impact.impactOccurred()
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Query var collections: [RecipeCollection]

    if let collection = collections.first(where: { $0.heritageCollectionId != nil }) {
        VStack {
            BlindBoxCollectionRow(collection: collection) {
                print("Revealed!")
            }
        }
        .padding()
        .background(HeirloomColors.cream)
        .modelContainer(for: [RecipeCollection.self], inMemory: true)
    } else {
        Text("No heritage collections available")
    }
}
