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
    let onConfirm: () -> Void
    let onBuyCredits: () -> Void
    let onQueueForTomorrow: () -> Void

    @Environment(\.dismiss) private var dismiss

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

                        Divider()

                        // Total
                        HStack {
                            Text("Total")
                                .font(.headline)
                            Spacer()
                            Text("\(costBreakdown.totalCredits) credits")
                                .font(.headline)
                                .foregroundColor(HeirloomColors.familyGreen)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Quota Status Card
                    QuotaStatusCard(
                        userCredits: userCredits,
                        costBreakdown: costBreakdown
                    )

                    // Action Buttons
                    VStack(spacing: 12) {
                        if costBreakdown.canAfford {
                            // Can afford - show import button
                            Button {
                                onConfirm()
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
                                    Text("You need \(costBreakdown.needsCredits) more credits")
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

                                // Queue for tomorrow button (secondary)
                                Button {
                                    onQueueForTomorrow()
                                } label: {
                                    VStack(spacing: 4) {
                                        Text("Queue for Tomorrow")
                                            .font(.headline)
                                        Text("Free - Your quota resets at midnight")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
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

// MARK: - Quota Status Card

struct QuotaStatusCard: View {
    let userCredits: UserCredits
    let costBreakdown: PDFCostCalculator.CostBreakdown

    var body: some View {
        VStack(spacing: 12) {
            // Current quota
            HStack {
                Image(systemName: "giftcard")
                    .foregroundColor(HeirloomColors.familyGreen)
                Text("Your quota today:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(userCredits.availableToday) credits")
                    .font(.headline)
            }

            // After import projection
            if costBreakdown.canAfford {
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    Text("After import:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(max(0, userCredits.availableToday - costBreakdown.totalCredits)) credits")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }

            // Quota reset time
            if userCredits.quotaRemaining < UserCredits.dailyFreeQuota {
                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Quota resets \(userCredits.quotaResetTime, style: .relative)")
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
    let mockCostBreakdown = PDFCostCalculator.CostBreakdown(
        totalCredits: 7,
        textRichCount: 2,
        scannedCount: 1,
        mixedCount: 0,
        classifications: [:],
        canAfford: false,
        needsCredits: 2
    )

    let mockUserCredits = UserCredits(userId: "test")
    mockUserCredits.dailyQuotaUsed = 20

    return CreditsCostSheet(
        costBreakdown: mockCostBreakdown,
        userCredits: mockUserCredits,
        onConfirm: {},
        onBuyCredits: {},
        onQueueForTomorrow: {}
    )
}
