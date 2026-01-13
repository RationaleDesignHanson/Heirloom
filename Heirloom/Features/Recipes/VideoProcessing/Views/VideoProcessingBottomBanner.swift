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
            HStack(spacing: 12) {
                // Progress Circle (smaller)
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2.5)
                        .frame(width: 36, height: 36)

                    Circle()
                        .trim(from: 0, to: job.progress)
                        .stroke(HeirloomColors.tomato, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: job.progress)

                    if job.progress < 1.0 {
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(HeirloomColors.tomato)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(HeirloomColors.familyGreen)
                    }
                }

                // Job Info - Single line when possible
                HStack(spacing: 6) {
                    Text(job.detailedStatusText)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if !queuedJobs.isEmpty {
                        Text("•")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text("\(queuedJobs.count) in queue")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }

    private func completedBannerContent() -> some View {
        Button {
            showJobList = true
        } label: {
            HStack(spacing: 12) {
                // Checkmark Icon (smaller)
                ZStack {
                    Circle()
                        .fill(HeirloomColors.familyGreen.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(HeirloomColors.familyGreen)
                }

                // Completed Info - Single line
                HStack(spacing: 6) {
                    Text(completedJobs.count == 1 ? "Recipe ready to review" : "\(completedJobs.count) recipes ready to review")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.top, 8)
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
            HStack(spacing: 12) {
                // Error Icon (smaller)
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.red)
                }

                // Failed Info - Single line when possible
                HStack(spacing: 6) {
                    Text(failedJobs.count == 1 ? "Video processing failed" : "\(failedJobs.count) videos failed")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Show context if there are also completed jobs
                    if !completedJobs.isEmpty {
                        Text("•")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Text("\(completedJobs.count) ready")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.familyGreen)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
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
