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

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Status Icon
            statusIcon

            // Job Details
            VStack(alignment: .leading, spacing: 6) {
                // Caption or placeholder
                Text(job.userCaption ?? "Video Recipe")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                // Status and progress
                HStack(spacing: 8) {
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
                    HStack(spacing: 4) {
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
        .background(.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4)
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
            if job.canRetry, let onRetry = onRetry {
                Button {
                    onRetry()
                } label: {
                    Text("Retry")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(8)
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Failed")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(Color.red)

                    if let error = job.errorMessage {
                        Text(error)
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

        case .processing, .pending:
            if job.canCancel, let onCancel = onCancel {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.gray)
                }
            }

        case .completed:
            Image(systemName: "chevron.right")
                .font(.caption)
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
    VStack(spacing: 16) {
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
            onCancel: {}
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
            onCancel: nil
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
            onCancel: nil
        )
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
