//
//  TrialExpiredView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI
import SwiftData

/// Post-trial experience view offering upgrade, pay-per-recipe, export, or free tier options
struct TrialExpiredView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var unlockTracker: HeritageUnlockTracker?
    @State private var subscriptionManager: SubscriptionManager?
    @State private var showPaywall = false
    @State private var showHeritageUnlock = false
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Header
                    headerSection

                    // Option 1: Upgrade to Premium
                    premiumOptionCard

                    // Option 2: Buy Recipes Individually
                    payPerRecipeCard

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
            .sheet(isPresented: $showHeritageUnlock) {
                HeritageUnlockView()
            }
            .sheet(isPresented: $showExportSheet) {
                RecipeExportView()
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
                    .foregroundStyle(.white)
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
                        .foregroundStyle(.white)

                    Text("Upgrade to Premium")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)

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
                        .foregroundStyle(.white)
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
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

    // MARK: - Option 2: Pay Per Recipe

    private var payPerRecipeCard: some View {
        Button {
            showHeritageUnlock = true
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(.green.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buy Recipes Individually")
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Unlock heritage recipes for $0.99 each")
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
                    .stroke(.green, lineWidth: 2)
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
                VStack(alignment: .leading, spacing: 4) {
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
