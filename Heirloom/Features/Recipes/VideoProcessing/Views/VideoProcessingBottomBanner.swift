//
//  VideoProcessingBottomBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import SwiftUI
import SwiftData

/// Persistent bottom banner showing active video processing job
struct VideoProcessingBottomBanner: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showJobList = false
    @State private var selectedFailedJob: VideoProcessingJob?
    @State private var jobManager: VideoProcessingJobManager?

    // Query for all jobs, sorted by creation date
    @Query(sort: \VideoProcessingJob.createdAt, order: .forward)
    private var allJobs: [VideoProcessingJob]

    // Filter to active jobs (processing, pending, completed, or failed - exclude only saved/cancelled)
    private var activeJobs: [VideoProcessingJob] {
        allJobs.filter { job in
            job.status == .processing || job.status == .pending ||
            job.status == .completed || job.status == .failed
        }
    }

    // Separate job types
    private var processingJobs: [VideoProcessingJob] {
        allJobs.filter { job in
            job.status == .processing
        }
    }

    private var queuedJobs: [VideoProcessingJob] {
        allJobs.filter { job in
            job.status == .pending
        }
    }

    private var completedJobs: [VideoProcessingJob] {
        allJobs.filter { job in
            job.status == .completed
        }
    }

    private var failedJobs: [VideoProcessingJob] {
        allJobs.filter { job in
            job.status == .failed
        }
    }

    var body: some View {
        Group {
            if !activeJobs.isEmpty {
                // Priority: processing > failed > completed
                if let processingJob = processingJobs.first {
                    bannerContent(for: processingJob, showProcessing: true)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: processingJob.id)
                        .sheet(isPresented: $showJobList) {
                            VideoProcessingJobListView()
                        }
                        .onAppear {
                            initializeJobManager()
                        }
                } else if !failedJobs.isEmpty {
                    failedBannerContent()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: failedJobs.count)
                        .sheet(isPresented: $showJobList) {
                            VideoProcessingJobListView()
                        }
                } else if !completedJobs.isEmpty {
                    completedBannerContent()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: completedJobs.count)
                        .sheet(isPresented: $showJobList) {
                            VideoProcessingJobListView()
                        }
                }
            }
        }
        .sheet(item: $selectedFailedJob) { (job: VideoProcessingJob) in
            JobRecoverySheet(job: job) { action in
                let manager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)
                try await manager.handleRecoveryAction(for: job, action: action, context: modelContext)
            }
        }
    }

    private func bannerContent(for job: VideoProcessingJob, showProcessing: Bool) -> some View {
        Button {
            showJobList = true
        } label: {
            VStack(spacing: 0) {
                // Linear progress bar at top (matching PDF banner)
                ProgressView(value: job.progress)
                    .progressViewStyle(.linear)
                    .tint(HeirloomColors.tomato)

                HStack(spacing: 12) {
                    // Phase icon
                    Image(systemName: phaseIcon(for: job))
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.tomato)

                    // Two-line text layout (matching PDF banner)
                    VStack(alignment: .leading, spacing: 2) {
                        // Title: Status text
                        Text(job.detailedStatusText)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        // Subtitle: Queue info or video name
                        if !queuedJobs.isEmpty {
                            Text("\(queuedJobs.count) in queue")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        } else {
                            Text(job.userCaption ?? "Processing video")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    // Percentage (matching PDF banner)
                    if job.progress < 1.0 {
                        Text("\(Int(job.progress * 100))%")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.tomato)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(HeirloomFonts.title2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        }
        .buttonStyle(.plain)
    }

    private func completedBannerContent() -> some View {
        Button {
            showJobList = true
        } label: {
            VStack(spacing: 0) {
                // Full progress bar (completed)
                ProgressView(value: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.green)

                HStack(spacing: 12) {
                    // Checkmark icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(.green)

                    // Two-line text layout
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Processing complete")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        Text(completedJobs.count == 1 ? "1 recipe ready" : "\(completedJobs.count) recipes ready")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(HeirloomFonts.title2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        }
        .buttonStyle(.plain)
    }

    private func failedBannerContent() -> some View {
        Button {
            // If only one failed job, show recovery sheet directly for better UX
            if failedJobs.count == 1, let failedJob = failedJobs.first {
                selectedFailedJob = failedJob
            } else {
                // Multiple failed jobs, show full list
                showJobList = true
            }
        } label: {
            VStack(spacing: 0) {
                // Error indicator progress bar
                ProgressView(value: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.red)

                HStack(spacing: 12) {
                    // Error icon
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(.red)

                    // Two-line text layout
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Processing failed")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        if !completedJobs.isEmpty {
                            Text("\(failedJobs.count) failed, \(completedJobs.count) ready")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        } else {
                            Text(failedJobs.count == 1 ? "Tap to retry" : "\(failedJobs.count) videos")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }

                    Spacer()

                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(HeirloomFonts.title2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        }
        .buttonStyle(.plain)
    }

    private func phaseIcon(for job: VideoProcessingJob) -> String {
        switch job.currentPhase {
        case .queued:
            return "clock"
        case .loadingModel:
            return "arrow.down.circle"
        case .extractingAudio:
            return "waveform"
        case .transcribing:
            return "text.bubble"
        case .analyzingFrames:
            return "photo.on.rectangle"
        case .structuringRecipe:
            return "text.badge.checkmark"
        case .augmenting:
            return "sparkles"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private func initializeJobManager() {
        if jobManager == nil {
            jobManager = VideoProcessingJobManager()

            // Start auto-resume
            Task {
                await jobManager?.resumePendingJobs(context: modelContext)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: VideoProcessingJob.self, configurations: config)

    // Create a sample job
    let job = VideoProcessingJob(
        videoURL: "/tmp/video.mp4",
        videoType: .standard,
        userCaption: "Chocolate chip cookies"
    )
    job.status = .processing
    job.currentPhase = .transcribing
    job.progress = 0.45

    container.mainContext.insert(job)

    return ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()

        VStack {
            Spacer()
            VideoProcessingBottomBanner()
                .modelContainer(container)
        }
    }
}
