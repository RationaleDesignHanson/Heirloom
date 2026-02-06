//
//  CreditsCostSheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-03.
//

import SwiftUI

/// Shows credit cost breakdown BEFORE import starts
/// - Displays text-rich vs scanned PDF counts
/// - Shows remaining quota
/// - Offers purchase or queue for tomorrow if quota exceeded
struct CreditsCostSheet: View {

    // MARK: - Properties

    let costBreakdown: PDFCostCalculator.CostBreakdown
    let userCredits: UserCredits
    let onConfirm: (Bool) -> Void  // Now passes generateAIImages flag
    let onBuyCredits: () -> Void
    let onQueueForTomorrow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var generateAIImages: Bool = false

    // MARK: - Computed Properties

    /// Total cost including AI images if enabled
    private var effectiveTotalCredits: Int {
        costBreakdown.totalWithAIImages(enabled: generateAIImages)
    }

    /// Whether user can afford with current AI images toggle state
    private var canAffordWithCurrentSettings: Bool {
        costBreakdown.canAfford(withAIImages: generateAIImages, userCredits: userCredits)
    }

    /// Credits needed with current AI images toggle state
    private var creditsNeededWithCurrentSettings: Int {
        costBreakdown.creditsNeeded(withAIImages: generateAIImages, userCredits: userCredits)
    }

    /// Estimated time for import
    private var estimatedTime: String {
        let estimatedRecipes = max(1, costBreakdown.estimatedTotalPages / 2)

        if generateAIImages {
            // With AI images: parallel generation ~5 seconds per image with 6 concurrency
            // Plus extraction time
            let imageTime = (estimatedRecipes * 5) / 6  // Parallel with 6 workers
            let extractionTime = estimatedRecipes / 10  // ~6 recipes per minute extraction
            let totalMinutes = max(1, (imageTime + extractionTime) / 60)

            if totalMinutes < 2 {
                return "~1 minute"
            } else if totalMinutes < 5 {
                return "~\(totalMinutes) minutes"
            } else {
                return "~\(totalMinutes) minutes"
            }
        } else {
            // Without AI images: just extraction
            let extractionMinutes = max(1, estimatedRecipes / 10)
            if extractionMinutes < 2 {
                return "~1 minute"
            }
            return "~\(extractionMinutes) minutes"
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header Icon
                    Image(systemName: "doc.badge.gearshape")
                        .font(.system(size: 60))
                        .foregroundStyle(HeirloomColors.familyGreen.gradient)
                        .padding(.top, 20)

                    // Title
                    VStack(spacing: 8) {
                        Text("Import Cost")
                            .font(.title.bold())

                        Text("Here's what this import will cost")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Cost Breakdown Card
                    VStack(alignment: .leading, spacing: 16) {

                        // Text-rich PDFs
                        if costBreakdown.hasTextRich {
                            CostRow(
                                icon: "doc.text",
                                iconColor: .green,
                                label: "\(costBreakdown.textRichCount) text-rich PDF\(costBreakdown.textRichCount == 1 ? "" : "s")",
                                credits: costBreakdown.textRichCount,
                                badge: "Fast"
                            )
                        }

                        // Mixed PDFs
                        if costBreakdown.hasMixed {
                            CostRow(
                                icon: "doc.badge.gearshape",
                                iconColor: .orange,
                                label: "\(costBreakdown.mixedCount) mixed PDF\(costBreakdown.mixedCount == 1 ? "" : "s")",
                                credits: costBreakdown.mixedCount * 3,
                                badge: nil
                            )
                        }

                        // Scanned PDFs
                        if costBreakdown.hasScanned {
                            CostRow(
                                icon: "doc.viewfinder",
                                iconColor: .red,
                                label: "\(costBreakdown.scannedCount) scanned PDF\(costBreakdown.scannedCount == 1 ? "" : "s")",
                                credits: costBreakdown.scannedCount * 5,
                                badge: "Premium"
                            )
                        }

                        // AI Image Generation (shown when enabled)
                        if generateAIImages {
                            if costBreakdown.aiImageCredits > 0 {
                                CostRow(
                                    icon: "sparkles",
                                    iconColor: .purple,
                                    label: "AI image generation",
                                    credits: costBreakdown.aiImageCredits,
                                    badge: "Premium"
                                )
                            } else {
                                // Free AI images for small imports
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                        .frame(width: 24)
                                    Text("AI image generation")
                                    Spacer()
                                    Text("Free")
                                        .font(.subheadline)
                                        .foregroundColor(HeirloomColors.familyGreen)
                                        .fontWeight(.medium)
                                }
                            }
                        }

                        Divider()

                        // Total
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("\(effectiveTotalCredits) credits")
                                .font(.headline)
                                .foregroundColor(HeirloomColors.familyGreen)
                        }

                        // Time estimate
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("Estimated time: \(estimatedTime)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Quota Status Card
                    QuotaStatusCard(
                        userCredits: userCredits,
                        costBreakdown: costBreakdown,
                        effectiveTotalCredits: effectiveTotalCredits,
                        canAfford: canAffordWithCurrentSettings
                    )

                    // AI Image Generation Option
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $generateAIImages) {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Generate AI images")
                                        .font(.body)

                                    Text("Replace page images with AI-generated photos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: HeirloomColors.familyGreen))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Action Buttons
                    VStack(spacing: 12) {
                        if canAffordWithCurrentSettings {
                            // Can afford - show import button
                            Button {
                                onConfirm(generateAIImages)
                            } label: {
                                Label("Import Now", systemImage: "arrow.down.doc")
                                    .frame(maxWidth: .infinity)
                                    .font(.headline)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                        } else {
                            // Can't afford - show purchase and queue options
                            VStack(spacing: 12) {

                                // Need credits message
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("You need \(creditsNeededWithCurrentSettings) more credits")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)

                                // Buy credits button (primary)
                                Button {
                                    onBuyCredits()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("Buy 25 Credits")
                                            .font(.headline)
                                        Text("$5 - Import right away")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)

                                // Queue for later button (secondary) - only show for premium users with monthly reset
                                if userCredits.hasPeriodicReset {
                                    Button {
                                        onQueueForTomorrow()
                                    } label: {
                                        VStack(spacing: 4) {
                                            Text("Queue for Later")
                                                .font(.headline)
                                            Text("Free - Credits reset next month")
                                                .font(.caption)
                                                .opacity(0.8)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.large)
                                }
                            }
                        }

                        // Cancel button
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Cost Row

struct CostRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let credits: Int
    let badge: String?

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)

            // Label
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)

                if let badge = badge {
                    Text(badge)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Credits
            Text("\(credits)")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Credits Status Card

struct QuotaStatusCard: View {
    let userCredits: UserCredits
    let costBreakdown: PDFCostCalculator.CostBreakdown
    let effectiveTotalCredits: Int
    let canAfford: Bool

    var body: some View {
        VStack(spacing: 12) {
            // Current credits
            HStack {
                Image(systemName: "giftcard")
                    .foregroundColor(HeirloomColors.familyGreen)
                Text("Available credits:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(userCredits.availableCredits) credits")
                    .font(.headline)
            }

            // After import projection
            if canAfford {
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    Text("After import:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(max(0, userCredits.availableCredits - effectiveTotalCredits)) credits")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }

            // Credit reset time (only for premium users with monthly reset)
            if userCredits.hasPeriodicReset, let resetTime = userCredits.tierResetTime {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Credits reset \(resetTime, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    CreditsCostSheet(
        costBreakdown: PDFCostCalculator.CostBreakdown(
            totalCredits: 7,
            textRichCount: 2,
            scannedCount: 1,
            mixedCount: 0,
            classifications: [:],
            canAfford: false,
            needsCredits: 2,
            estimatedTotalPages: 100
        ),
        userCredits: UserCredits(userId: "test"),
        onConfirm: { _ in },
        onBuyCredits: {},
        onQueueForTomorrow: {}
    )
}
