//
//  VideoProcessingJobListView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import SwiftUI
import SwiftData

/// Full sheet view showing all video processing jobs
struct VideoProcessingJobListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \VideoProcessingJob.createdAt, order: .reverse)
    private var allJobs: [VideoProcessingJob]

    @State private var jobManager = VideoProcessingJobManager()
    @State private var selectedJob: VideoProcessingJob?

    private var processingJobs: [VideoProcessingJob] {
        allJobs.filter { $0.status == .processing }
    }

    private var queuedJobs: [VideoProcessingJob] {
        allJobs.filter { $0.status == .pending || $0.status == .paused }
    }

    private var completedJobs: [VideoProcessingJob] {
        allJobs.filter { $0.status == .completed }
    }

    private var failedJobs: [VideoProcessingJob] {
        allJobs.filter { $0.status == .failed }
    }

    private var savedJobs: [VideoProcessingJob] {
        allJobs.filter { $0.status == .saved }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Processing Now
                    if !processingJobs.isEmpty {
                        jobSection(
                            title: "Processing Now",
                            icon: "video.fill",
                            color: HeirloomColors.tomato,
                            jobs: processingJobs
                        )
                    }

                    // Queue
                    if !queuedJobs.isEmpty {
                        jobSection(
                            title: "Queue",
                            icon: "clock.fill",
                            color: .orange,
                            jobs: queuedJobs
                        )
                    }

                    // Ready to Review
                    if !completedJobs.isEmpty {
                        jobSection(
                            title: "Ready to Review",
                            icon: "checkmark.circle.fill",
                            color: HeirloomColors.familyGreen,
                            jobs: completedJobs
                        )
                    }

                    // Failed
                    if !failedJobs.isEmpty {
                        jobSection(
                            title: "Failed",
                            icon: "exclamationmark.triangle.fill",
                            color: .red,
                            jobs: failedJobs
                        )
                    }

                    // Saved (collapsed by default)
                    if !savedJobs.isEmpty {
                        DisclosureGroup {
                            ForEach(savedJobs) { job in
                                jobRow(for: job)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(HeirloomColors.familyGreen)
                                Text("Saved (\(savedJobs.count))")
                                    .font(HeirloomFonts.title3)
                                    .foregroundStyle(HeirloomColors.primaryText)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Empty state
                    if allJobs.isEmpty {
                        emptyState
                    }
                }
                .padding(.vertical)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Video Processing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedJob) { job in
                if job.status == .completed {
                    // Navigate to review screen
                    Text("Review Screen Coming Soon")
                        .font(HeirloomFonts.title2)
                }
            }
        }
    }

    // MARK: - Job Section

    private func jobSection(
        title: String,
        icon: String,
        color: Color,
        jobs: [VideoProcessingJob]
    ) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Section Header
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text("\(jobs.count)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            // Jobs
            ForEach(jobs) { job in
                jobRow(for: job)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Job Row

    private func jobRow(for job: VideoProcessingJob) -> some View {
        Button {
            if job.status == .completed {
                selectedJob = job
            }
        } label: {
            JobRow(
                job: job,
                onRetry: job.canRetry ? {
                    retryJob(job)
                } : nil,
                onCancel: job.canCancel ? {
                    cancelJob(job)
                } : nil
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if job.status == .completed {
                Button {
                    selectedJob = job
                } label: {
                    Label("Review Recipe", systemImage: "doc.text.magnifyingglass")
                }
            }

            if job.canRetry {
                Button {
                    retryJob(job)
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
            }

            if job.canCancel {
                Button(role: .destructive) {
                    cancelJob(job)
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
            }

            Button(role: .destructive) {
                deleteJob(job)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("No Video Jobs")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Video processing jobs will appear here")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions

    private func retryJob(_ job: VideoProcessingJob) {
        Task {
            do {
                try await jobManager.retryJob(job, context: modelContext)
            } catch {
                Log.error("Failed to retry job", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "error": error.localizedDescription
                ])
            }
        }
    }

    private func cancelJob(_ job: VideoProcessingJob) {
        do {
            try jobManager.cancelJob(job, context: modelContext)
        } catch {
            Log.error("Failed to cancel job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "error": error.localizedDescription
            ])
        }
    }

    private func deleteJob(_ job: VideoProcessingJob) {
        modelContext.delete(job)
        try? modelContext.save()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: VideoProcessingJob.self, configurations: config)

    // Create sample jobs
    let processingJob = VideoProcessingJob(
        videoURL: "/tmp/video1.mp4",
        videoType: .standard,
        userCaption: "Chocolate Chip Cookies"
    )
    processingJob.status = .processing
    processingJob.currentPhase = .transcribing
    processingJob.progress = 0.45

    let queuedJob = VideoProcessingJob(
        videoURL: "/tmp/video2.mp4",
        videoType: .asmr,
        userCaption: "ASMR Baking"
    )
    queuedJob.status = .pending

    let completedJob = VideoProcessingJob(
        videoURL: "/tmp/video3.mp4",
        videoType: .standard,
        userCaption: "Pasta Carbonara"
    )
    completedJob.status = .completed
    completedJob.progress = 1.0

    let failedJob = VideoProcessingJob(
        videoURL: "/tmp/video4.mp4",
        videoType: .standard
    )
    failedJob.status = .failed
    failedJob.errorMessage = "Audio extraction failed"

    container.mainContext.insert(processingJob)
    container.mainContext.insert(queuedJob)
    container.mainContext.insert(completedJob)
    container.mainContext.insert(failedJob)

    return VideoProcessingJobListView()
        .modelContainer(container)
}
