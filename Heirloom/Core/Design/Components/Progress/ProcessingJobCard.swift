//
//  ProcessingJobCard.swift
//  Heirloom
//
//  Unified card component for displaying any processing job in the queue view
//

import SwiftUI

/// Card layout for individual job in queue view
/// Height: ~80pt with thumbnail/icon, title, subtitle, and progress
struct ProcessingJobCard: View {
    let job: AnyProcessingJob
    let onTap: () -> Void
    var onDismiss: (() -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Left: Job type icon with accent background
                jobIcon
                    .frame(width: 56, height: 56)

                // Center: Title and subtitle stack
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(job.bannerTitle)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .lineLimit(1)

                        // Type badge
                        typeBadge
                    }

                    HStack(spacing: 4) {
                        Text(job.bannerSubtitle)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(1)

                        if job.bannerStatus == .processing {
                            Text("•")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            Text(phaseText)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }

                    // Progress bar for processing jobs
                    if job.bannerStatus == .processing || job.bannerStatus == .paused {
                        ProgressView(value: job.overallProgress)
                            .progressViewStyle(.linear)
                            .tint(progressTint)
                            .frame(height: 4)
                    }
                }

                Spacer()

                // Right: Status indicator
                statusIndicator
            }
            .padding(12)
            .background(cardBackground)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var jobIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconBackgroundColor.opacity(0.15))

            statusIcon
                .font(.system(size: 24))
                .foregroundStyle(iconColor)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.bannerStatus {
        case .processing, .pending:
            Image(systemName: job.phaseIconName)
        case .paused:
            Image(systemName: "pause.circle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private var typeBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: job.jobType.typeBadgeIcon)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(job.accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(job.accentColor.opacity(0.12))
        .cornerRadius(6)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch job.bannerStatus {
        case .processing, .pending:
            Text("\(Int(job.overallProgress * 100))%")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(job.accentColor)
                .frame(minWidth: 40)
        case .paused:
            Image(systemName: "play.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(HeirloomColors.familyGreen)
        case .failed:
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
        }
    }

    // MARK: - Computed Properties

    private var phaseText: String {
        // Show current phase name from icon
        job.phaseIconName.isEmpty ? "" : "Working..."
    }

    private var iconColor: Color {
        switch job.bannerStatus {
        case .processing, .pending:
            return job.accentColor
        case .paused:
            return .orange
        case .completed:
            return HeirloomColors.familyGreen
        case .failed:
            return .red
        }
    }

    private var iconBackgroundColor: Color {
        switch job.bannerStatus {
        case .processing, .pending:
            return job.accentColor
        case .paused:
            return .orange
        case .completed:
            return HeirloomColors.familyGreen
        case .failed:
            return .red
        }
    }

    private var progressTint: Color {
        switch job.bannerStatus {
        case .paused:
            return .orange
        default:
            return job.accentColor
        }
    }

    private var cardBackground: Color {
        switch job.bannerStatus {
        case .failed:
            return Color.red.opacity(0.05)
        case .completed:
            return HeirloomColors.familyGreen.opacity(0.05)
        case .paused:
            return Color.orange.opacity(0.05)
        default:
            return Color(.secondarySystemGroupedBackground)
        }
    }
}

// MARK: - Preview

#Preview("Processing") {
    VStack(spacing: 12) {
        ProcessingJobCard(
            job: AnyProcessingJob(
                id: UUID(),
                bannerTitle: "Transcribing",
                bannerSubtitle: "Chocolate chip cookies",
                overallProgress: 0.45,
                phaseIconName: "text.bubble",
                accentColor: HeirloomColors.tomato,
                bannerStatus: .processing,
                totalItems: 1,
                shouldShowInBanner: true,
                jobType: .video
            ),
            onTap: {}
        )

        ProcessingJobCard(
            job: AnyProcessingJob(
                id: UUID(),
                bannerTitle: "Extracting recipes...",
                bannerSubtitle: "Grandma's Cookbook",
                overallProgress: 0.72,
                phaseIconName: "text.badge.checkmark",
                accentColor: HeirloomColors.tomato,
                bannerStatus: .processing,
                totalItems: 15,
                shouldShowInBanner: true,
                jobType: .importJob
            ),
            onTap: {}
        )

        ProcessingJobCard(
            job: AnyProcessingJob(
                id: UUID(),
                bannerTitle: "Generation Failed",
                bannerSubtitle: "Spaghetti Carbonara",
                overallProgress: 0.50,
                phaseIconName: "sparkles",
                accentColor: HeirloomColors.amber,
                bannerStatus: .failed(canRetry: true),
                totalItems: 1,
                shouldShowInBanner: true,
                jobType: .generation
            ),
            onTap: {}
        )

        ProcessingJobCard(
            job: AnyProcessingJob(
                id: UUID(),
                bannerTitle: "Ready to Review",
                bannerSubtitle: "Banana Bread",
                overallProgress: 1.0,
                phaseIconName: "checkmark.circle.fill",
                accentColor: HeirloomColors.tomato,
                bannerStatus: .completed,
                totalItems: 1,
                shouldShowInBanner: true,
                jobType: .video
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
