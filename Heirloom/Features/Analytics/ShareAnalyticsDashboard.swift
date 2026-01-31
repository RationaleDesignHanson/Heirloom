//
//  ShareAnalyticsDashboard.swift
//  Heirloom
//
//  Phase 1: Inter-Heirloom Recipe Sharing - Analytics Dashboard
//  Visual dashboard for share metrics and engagement
//

import SwiftUI
import FirebaseAuth

struct ShareAnalyticsDashboard: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stats: ShareStats?
    @State private var shareHistory: [ShareHistoryItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var analyticsService: ShareAnalyticsService {
        ServiceContainer.shared.resolve(ShareAnalyticsService.self)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let stats = stats {
                    VStack(spacing: HeirloomSpacing.xl) {
                        // Overview Cards
                        overviewSection(stats)

                        // Acceptance Rate Chart
                        acceptanceRateSection(stats)

                        // Most Shared Recipe
                        if stats.mostSharedRecipeTitle != nil {
                            mostSharedSection(stats)
                        }

                        // Share History
                        if !shareHistory.isEmpty {
                            shareHistorySection
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.md)
                    .padding(.vertical, HeirloomSpacing.lg)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Share Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await loadAnalytics()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadAnalytics()
            }
        }
    }

    // MARK: - Overview Section

    private func overviewSection(_ stats: ShareStats) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Overview")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            HStack(spacing: HeirloomSpacing.sm) {
                StatCard(
                    title: "Sent",
                    value: "\(stats.totalSharesSent)",
                    icon: "arrow.up.circle.fill",
                    color: HeirloomColors.tomato
                )

                StatCard(
                    title: "Received",
                    value: "\(stats.totalSharesReceived)",
                    icon: "arrow.down.circle.fill",
                    color: HeirloomColors.familyGreen
                )

                StatCard(
                    title: "Accepted",
                    value: "\(stats.totalSharesAccepted)",
                    icon: "checkmark.circle.fill",
                    color: HeirloomColors.success
                )
            }
        }
    }

    // MARK: - Acceptance Rate Section

    private func acceptanceRateSection(_ stats: ShareStats) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Acceptance Rate")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(spacing: HeirloomSpacing.sm) {
                // Large percentage display
                HStack {
                    Spacer()
                    Text(stats.acceptanceRateString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(acceptanceRateColor(stats.averageAcceptanceRate))
                    Spacer()
                }
                .padding(.vertical, HeirloomSpacing.md)

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(HeirloomColors.warmGray.opacity(0.2))
                            .frame(height: 8)

                        Rectangle()
                            .fill(acceptanceRateColor(stats.averageAcceptanceRate))
                            .frame(
                                width: geometry.size.width * (stats.averageAcceptanceRate / 100),
                                height: 8
                            )
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)

                // Description
                Text("\(stats.totalSharesAccepted) of \(stats.totalRecipientsSent) recipients accepted")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Most Shared Section

    private func mostSharedSection(_ stats: ShareStats) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Most Shared")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            HStack(spacing: HeirloomSpacing.md) {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.mostSharedRecipeTitle ?? "")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Shared \(stats.mostSharedRecipeCount) times")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Share History Section

    private var shareHistorySection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Recent Shares")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(shareHistory.prefix(10)) { item in
                    ShareHistoryRow(item: item)
                }
            }
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading analytics...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Error Loading Analytics")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await loadAnalytics()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Image(systemName: "chart.bar")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))

            Text("No Analytics Yet")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Start sharing recipes with your connections to see your analytics")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Helpers

    private func acceptanceRateColor(_ rate: Double) -> Color {
        if rate >= 75 {
            return HeirloomColors.familyGreen
        } else if rate >= 50 {
            return HeirloomColors.warning
        } else if rate >= 25 {
            return HeirloomColors.amber
        } else {
            return HeirloomColors.warmGray
        }
    }

    // MARK: - Data Loading

    private func loadAnalytics() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let statsTask = analyticsService.fetchShareStats(userId: userId)
            async let historyTask = analyticsService.fetchShareHistory(userId: userId, limit: 50)

            stats = try await statsTask
            shareHistory = try await historyTask
            isLoading = false

            Log.info("Analytics loaded successfully", category: .firebase)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            Log.error("Failed to load analytics", category: .firebase, error: error)
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(HeirloomColors.primaryText)

            Text(title)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Share History Row

struct ShareHistoryRow: View {
    let item: ShareHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.recipeTitle)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                Spacer()

                // Acceptance rate badge
                Text(item.acceptanceRateString)
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(acceptanceColor)
                    .cornerRadius(8)
            }

            HStack {
                // Recipients
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.caption2)
                    Text(item.recipientsText)
                }
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

                Spacer()

                // Time ago
                Text(item.createdAt, style: .relative)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Acceptance stats
            Text("\(item.acceptCount) of \(item.recipientCount) accepted")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private var acceptanceColor: Color {
        let rate = item.acceptanceRate
        if rate >= 75 {
            return HeirloomColors.familyGreen
        } else if rate >= 50 {
            return HeirloomColors.warning
        } else if rate >= 25 {
            return HeirloomColors.amber
        } else {
            return HeirloomColors.warmGray
        }
    }
}

// MARK: - Preview

#Preview {
    ShareAnalyticsDashboard()
}
