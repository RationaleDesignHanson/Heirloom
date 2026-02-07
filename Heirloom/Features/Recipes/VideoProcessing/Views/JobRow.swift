//
//  JobRow.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import SwiftUI

/// Row component for displaying a video processing job
struct JobRow: View {
    let job: VideoProcessingJob
    let onRetry: (() -> Void)?
    let onCancel: (() -> Void)?
    let onDelete: (() -> Void)?
    let onResume: (() -> Void)?

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Thumbnail or Status Icon
            thumbnailOrIcon

            // Job Details
            VStack(alignment: .leading, spacing: 6) {
                // Caption or placeholder
                Text(job.userCaption ?? "Video Recipe")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                // Status and progress
                HStack(spacing: HeirloomSpacing.sm) {
                    Text(job.statusText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(statusColor)

                    if job.status == .processing {
                        Text("•")
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text("\(Int(job.progress * 100))%")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                // Video type badge
                if job.videoType == .asmr {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                        Text("ASMR")
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(HeirloomColors.amber)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HeirloomColors.amber.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            Spacer()

            // Action buttons or status indicator
            actionContent
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4)
    }

    // MARK: - Thumbnail or Icon

    @ViewBuilder
    private var thumbnailOrIcon: some View {
        if let thumbnailData = job.thumbnailData,
           let uiImage = UIImage(data: thumbnailData) {
            // Show video thumbnail with status badge
            ZStack(alignment: .bottomTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Status badge overlay
                statusBadge
                    .offset(x: 4, y: 4)
            }
            .frame(width: 64, height: 64)
        } else {
            // Fallback to status icon
            statusIcon
        }
    }

    private var statusBadge: some View {
        ZStack {
            Circle()
                .fill(statusColor)
                .frame(width: 24, height: 24)

            if job.status == .processing {
                // Mini circular progress
                Circle()
                    .trim(from: 0, to: job.progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
            } else {
                Image(systemName: statusIconName)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 2)
    }

    // MARK: - Status Icon

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.1))
                .frame(width: 48, height: 48)

            if job.status == .processing {
                // Circular progress
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: job.progress)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "video.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor)
            } else {
                Image(systemName: statusIconName)
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusIconName: String {
        switch job.status {
        case .pending:
            return "clock.fill"
        case .analyzing:
            return "magnifyingglass"
        case .awaitingConfirmation:
            return "questionmark.circle.fill"
        case .processing:
            return "video.fill"
        case .paused:
            return "pause.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .saved:
            return "checkmark.seal.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch job.status {
        case .pending:
            return Color.orange
        case .analyzing:
            return HeirloomColors.tomato
        case .awaitingConfirmation:
            return Color.blue
        case .processing:
            return HeirloomColors.tomato
        case .paused:
            return Color.blue
        case .completed:
            return HeirloomColors.familyGreen
        case .saved:
            return HeirloomColors.familyGreen
        case .failed:
            return Color.red
        case .cancelled:
            return Color.gray
        }
    }

    // MARK: - Action Content

    @ViewBuilder
    private var actionContent: some View {
        switch job.status {
        case .failed:
            HStack(spacing: HeirloomSpacing.sm) {
                // Delete button (always visible for failed jobs)
                if let onDelete = onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Text("Delete")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Retry button
                if job.canRetry, let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text("Retry")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(8)
                    }
                }
            }

        case .analyzing:
            // Show cancel button during analysis
            if job.canCancel, let onCancel = onCancel {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(Color.gray)
                }
            }

        case .awaitingConfirmation:
            // Show "Confirm" button for jobs awaiting user confirmation
            Image(systemName: "chevron.right")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

        case .processing, .pending:
            // Resume button for interrupted jobs (force-quit)
            if job.canResume, let onResume = onResume {
                Button {
                    onResume()
                } label: {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Resume")
                            .font(HeirloomFonts.caption1Bold)
                    }
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
                }
            } else if job.canCancel, let onCancel = onCancel {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(Color.gray)
                }
            }

        case .completed:
            Image(systemName: "chevron.right")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

        case .saved:
            Text("Saved")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(HeirloomColors.familyGreen)

        case .cancelled, .paused:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: HeirloomSpacing.md) {
        // Processing
        JobRow(
            job: {
                let job = VideoProcessingJob(videoURL: "/tmp/video.mp4", videoType: .standard, userCaption: "Chocolate Chip Cookies")
                job.status = .processing
                job.currentPhase = .transcribing
                job.progress = 0.65
                return job
            }(),
            onRetry: nil,
            onCancel: {},
            onDelete: nil,
            onResume: nil
        )

        // Completed
        JobRow(
            job: {
                let job = VideoProcessingJob(videoURL: "/tmp/video.mp4", videoType: .asmr, userCaption: "ASMR Baking")
                job.status = .completed
                job.progress = 1.0
                return job
            }(),
            onRetry: nil,
            onCancel: nil,
            onDelete: nil,
            onResume: nil
        )

        // Failed
        JobRow(
            job: {
                let job = VideoProcessingJob(videoURL: "/tmp/video.mp4", videoType: .standard)
                job.status = .failed
                job.errorMessage = "Audio extraction failed"
                return job
            }(),
            onRetry: {},
            onCancel: nil,
            onDelete: {},
            onResume: nil
        )
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
