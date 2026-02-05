//
//  ProcessingBottomBanner.swift
//  Heirloom
//
//  Unified bottom banner for all processing job types
//

import SwiftUI

/// Generic bottom banner for displaying any ProcessingBannerJob
struct ProcessingBottomBanner<Job: ProcessingBannerJob>: View {
    let job: Job
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Linear progress bar at top
            ProgressView(value: job.overallProgress)
                .progressViewStyle(.linear)
                .tint(progressTint)

            // Tappable banner content
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Phase/status icon
                    statusIcon
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(iconColor)

                    // Title/subtitle stack
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(job.bannerTitle)
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.charcoal)

                            // Item count badge for multi-item jobs
                            if job.totalItems > 1 && job.bannerStatus == .processing {
                                Text("+\(job.totalItems)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(job.accentColor)
                                    .cornerRadius(8)
                            }
                        }

                        Text(job.bannerSubtitle)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    // Status indicator (percentage, checkmark, or error)
                    statusIndicator
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch job.bannerStatus {
        case .paused:
            Image(systemName: "pause.circle.fill")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
        case .pending, .processing:
            Image(systemName: job.phaseIconName)
        }
    }

    private var iconColor: Color {
        switch job.bannerStatus {
        case .paused:
            return .orange
        case .failed:
            return .red
        case .completed:
            return HeirloomColors.familyGreen
        case .pending, .processing:
            return job.accentColor
        }
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private var statusIndicator: some View {
        switch job.bannerStatus {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HeirloomColors.familyGreen)
                .font(HeirloomFonts.title2)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(HeirloomFonts.title2)
        case .paused:
            Image(systemName: "play.circle.fill")
                .foregroundStyle(.blue)
                .font(HeirloomFonts.title2)
        case .pending, .processing:
            Text("\(Int(job.overallProgress * 100))%")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(job.accentColor)
        }
    }

    // MARK: - Progress Tint

    private var progressTint: Color {
        switch job.bannerStatus {
        case .completed:
            return HeirloomColors.familyGreen
        case .failed:
            return .red
        default:
            return job.accentColor
        }
    }
}
