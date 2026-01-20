//
//  TrialExpiredView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI
import SwiftData

/// Post-trial experience view offering upgrade, video credits, export, or free tier options
struct TrialExpiredView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var unlockTracker: HeritageUnlockTracker?
    @State private var subscriptionManager: SubscriptionManager?
    @State private var showPaywall = false
    @State private var showExportSheet = false
    @State private var showVideoCredits = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Header
                    headerSection

                    // Option 1: Upgrade to Premium
                    premiumOptionCard

                    // Option 2: Buy Video Translation Credits
                    videoCreditsCard

                    // Option 3: Export Your Recipes
                    exportDataCard

                    // Option 4: Continue with Free Version
                    continueFreeLinkButton
                }
                .padding()
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Trial Complete")
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
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showExportSheet) {
                RecipeExportView()
            }
            .sheet(isPresented: $showVideoCredits) {
                // TODO: Create VideoCreditsPurchaseView
                Text("Video Credits Purchase - Coming Soon")
                    .font(HeirloomFonts.title2)
                    .padding()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Success checkmark
            ZStack {
                Circle()
                    .fill(.green.gradient)
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(HeirloomColors.buttonTextLight)
            }

            Text("Trial Complete!")
                .font(HeirloomFonts.title2)
                .fontWeight(.bold)

            if let tracker = unlockTracker {
                Text("You unlocked \(tracker.unlockedRecipeIds.count) heritage recipes")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(.top)
    }

    // MARK: - Option 1: Premium

    private var premiumOptionCard: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                // Header
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(HeirloomColors.buttonTextLight)

                    Text("Upgrade to Premium")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)

                    Spacer()
                }

                // Benefits
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    benefitRow(icon: "sparkles", text: "All 100 heritage recipes")
                    benefitRow(icon: "wand.and.stars", text: "Unlimited AI imports")
                    benefitRow(icon: "icloud.fill", text: "Cloud sync across devices")
                    benefitRow(icon: "camera.fill", text: "Advanced cookbook scanner")
                }

                // CTA
                HStack {
                    Spacer()
                    Text("See Premium Plans")
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                    Spacer()
                }
                .padding(.vertical, HeirloomSpacing.sm)
                .background(.white.opacity(0.2))
                .cornerRadius(8)
            }
            .padding(HeirloomSpacing.lg)
            .background(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .shadow(
                color: .blue.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Option 2: Video Translation Credits

    private var videoCreditsCard: some View {
        Button {
            showVideoCredits = true
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.purple.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "video.badge.waveform")
                        .font(.title2)
                        .foregroundStyle(.purple)
                }

                // Content
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Buy Video Translation Credits")
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("$0.99 per video-to-recipe conversion")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
            }
            .padding(HeirloomSpacing.md)
            .background(Color(.systemBackground))
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(.purple, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Option 3: Export Data

    private var exportDataCard: some View {
        Button {
            showExportSheet = true
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.orange.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }

                // Content
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text("Export Your Recipes")
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Download as PDF or JSON")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.3))
            }
            .padding(HeirloomSpacing.md)
            .background(Color(.systemBackground))
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(.orange, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Option 4: Continue Free

    private var continueFreeLinkButton: some View {
        Button {
            dismiss()
        } label: {
            VStack(spacing: HeirloomSpacing.sm) {
                Text("Continue with Free Version")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

                Text("Keep your unlocked recipes and continue using basic features")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, HeirloomSpacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Views

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 20)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Helpers

    private func initializeServices() {
        if unlockTracker == nil {
            unlockTracker = ServiceContainer.shared.resolve(HeritageUnlockTracker.self)
        }
        if subscriptionManager == nil {
            subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
        }
    }
}

// MARK: - Preview

#Preview {
    TrialExpiredView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
