//
//  UnifiedProcessingBanner.swift
//  Heirloom
//
//  Single unified banner for all processing job types (video, import, generation)
//  Replaces VideoProcessingBottomBanner and ImportProgressBannerContainer
//

import SwiftUI
import SwiftData

/// Unified bottom banner showing the most important active job
/// Tapping always opens UnifiedProcessingQueueView
struct UnifiedProcessingBanner: View {
    @Environment(\.modelContext) private var modelContext

    // Query all job types
    @Query(sort: \VideoProcessingJob.createdAt, order: .reverse)
    private var videoJobs: [VideoProcessingJob]

    @Query(sort: \ImportJob.createdAt, order: .reverse)
    private var importJobs: [ImportJob]

    @Query(sort: \RecipeGenerationJob.createdAt, order: .reverse)
    private var generationJobs: [RecipeGenerationJob]

    @Query(sort: \SyncJob.createdAt, order: .reverse)
    private var syncJobs: [SyncJob]

    // State for showing queue view
    @State private var showQueueView = false

    // Track jobs scheduled for auto-dismiss to prevent duplicate timers
    @State private var autoDismissScheduled: Set<UUID> = []

    // Callbacks for job interactions from queue view
    var onVideoJobTap: ((VideoProcessingJob) -> Void)?
    var onImportJobTap: ((ImportJob) -> Void)?
    var onGenerationJobTap: ((RecipeGenerationJob) -> Void)?

    var body: some View {
        Group {
            if let priorityJob = priorityJob {
                bannerContent(for: priorityJob)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: priorityJob.id)
                    .onAppear {
                        // Auto-dismiss completed jobs after 3 seconds
                        if canDismiss(priorityJob) {
                            scheduleAutoDismiss(for: priorityJob)
                        }
                    }
                    .onChange(of: priorityJob.bannerStatus) { _, newStatus in
                        // Auto-dismiss when job completes
                        if case .completed = newStatus {
                            scheduleAutoDismiss(for: priorityJob)
                        }
                    }
            }
        }
        .sheet(isPresented: $showQueueView) {
            UnifiedProcessingQueueView(
                onVideoJobTap: onVideoJobTap,
                onImportJobTap: onImportJobTap,
                onGenerationJobTap: onGenerationJobTap
            )
        }
    }

    // MARK: - Banner Content

    private func bannerContent(for job: AnyProcessingJob) -> some View {
        Button {
            showQueueView = true
        } label: {
            VStack(spacing: 0) {
                // Linear progress bar at top (4px height for better visibility)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))

                        // Progress fill
                        Rectangle()
                            .fill(progressTint(for: job))
                            .frame(width: geometry.size.width * aggregatedProgress)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 12) {
                    // Phase icon
                    statusIcon(for: job)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(iconColor(for: job))

                    // Title/subtitle stack
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(bannerTitle(for: job))
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.charcoal)

                            // "+N more" badge when multiple jobs
                            if activeJobCount > 1 {
                                Text("+\(activeJobCount - 1) more")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(HeirloomColors.tomato)
                                    .cornerRadius(8)
                            }
                        }

                        Text(bannerSubtitle(for: job))
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status indicator (percentage or status icon)
                    statusIndicator(for: job)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel(for: job)))
        .accessibilityHint(Text("Double tap to view all processing jobs"))
    }

    // MARK: - Banner State Components

    @ViewBuilder
    private func statusIcon(for job: AnyProcessingJob) -> some View {
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

    private func iconColor(for job: AnyProcessingJob) -> Color {
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

    @ViewBuilder
    private func statusIndicator(for job: AnyProcessingJob) -> some View {
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
            Text("\(Int(aggregatedProgress * 100))%")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(job.accentColor)
        }
    }

    private func progressTint(for job: AnyProcessingJob) -> Color {
        switch job.bannerStatus {
        case .completed:
            return HeirloomColors.familyGreen
        case .failed:
            return .red
        case .paused:
            return .orange
        default:
            return job.accentColor
        }
    }

    // MARK: - Banner Text

    private func bannerTitle(for job: AnyProcessingJob) -> String {
        if activeJobCount > 1 && job.bannerStatus == .processing {
            return "Processing \(activeJobCount) jobs"
        }
        return job.bannerTitle
    }

    private func bannerSubtitle(for job: AnyProcessingJob) -> String {
        if queuedCount > 0 && job.bannerStatus == .processing {
            return "\(queuedCount) in queue"
        }
        return job.bannerSubtitle
    }

    private func accessibilityLabel(for job: AnyProcessingJob) -> String {
        let progress = Int(aggregatedProgress * 100)
        if activeJobCount > 1 {
            return "Processing \(activeJobCount) jobs, \(progress)% complete"
        }
        return "\(job.bannerTitle), \(progress)% complete"
    }

    // MARK: - Job Aggregation

    /// The highest priority job to display in the banner
    private var priorityJob: AnyProcessingJob? {
        var allJobs: [AnyProcessingJob] = []

        // Collect all visible jobs
        for job in videoJobs where job.shouldShowInBanner {
            allJobs.append(AnyProcessingJob(job, type: .video))
        }
        for job in importJobs where job.shouldShowInBanner {
            allJobs.append(AnyProcessingJob(job, type: .importJob))
        }
        for job in generationJobs where job.shouldShowInBanner {
            allJobs.append(AnyProcessingJob(job, type: .generation))
        }
        for job in syncJobs where job.shouldShowInBanner {
            allJobs.append(AnyProcessingJob(job, type: .sync))
        }

        // Sort by priority and return the highest
        return allJobs.sorted { $0.bannerStatus.priority > $1.bannerStatus.priority }.first
    }

    /// Count of all active jobs (processing, paused, failed with retry)
    private var activeJobCount: Int {
        let videoCount = videoJobs.filter { $0.shouldShowInBanner }.count
        let importCount = importJobs.filter { $0.shouldShowInBanner }.count
        let genCount = generationJobs.filter { $0.shouldShowInBanner }.count
        let syncCount = syncJobs.filter { $0.shouldShowInBanner }.count
        return videoCount + importCount + genCount + syncCount
    }

    /// Count of queued (pending) jobs
    private var queuedCount: Int {
        let videoQueued = videoJobs.filter { $0.status == .pending }.count
        let importQueued = importJobs.filter { $0.status == .pending }.count
        return videoQueued + importQueued
    }

    /// Aggregated progress across all processing jobs
    private var aggregatedProgress: Double {
        var totalProgress: Double = 0
        var count = 0

        // Include both .analyzing and .processing video jobs
        for job in videoJobs where job.status == .processing || job.status == .analyzing {
            totalProgress += job.progress
            count += 1
        }
        for job in importJobs where job.status == .processing {
            totalProgress += job.overallProgress
            count += 1
        }
        for job in generationJobs where job.status == .processing {
            // Estimate progress based on phase
            let progress: Double
            switch job.currentPhase {
            case .analyzing: progress = 0.25
            case .extracting: progress = 0.50
            case .enriching: progress = 0.75
            case .complete: progress = 1.0
            }
            totalProgress += progress
            count += 1
        }
        for job in syncJobs where job.status == .processing {
            totalProgress += job.overallProgress
            count += 1
        }

        guard count > 0 else { return 0 }
        return totalProgress / Double(count)
    }

    // MARK: - Dismiss Actions

    /// Check if the priority job can be dismissed (completed or failed)
    /// Note: Video jobs with .completed status need user review, so don't auto-dismiss them
    private func canDismiss(_ job: AnyProcessingJob) -> Bool {
        // Video jobs need review when completed - don't auto-dismiss
        if job.jobType == .video {
            if case .completed = job.bannerStatus {
                return false  // Needs user review
            }
        }

        switch job.bannerStatus {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }

    /// Schedule auto-dismiss for a completed job after 3 seconds
    private func scheduleAutoDismiss(for job: AnyProcessingJob) {
        // Don't schedule if already scheduled
        guard !autoDismissScheduled.contains(job.id) else { return }
        autoDismissScheduled.insert(job.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Only dismiss if the job is still the priority job and still completed
            if let currentPriority = priorityJob,
               currentPriority.id == job.id,
               canDismiss(currentPriority) {
                withAnimation(.easeOut(duration: 0.3)) {
                    dismissJob(job)
                }
            }
            autoDismissScheduled.remove(job.id)
        }
    }

    /// Dismiss a specific job
    private func dismissJob(_ job: AnyProcessingJob) {
        switch job.jobType {
        case .video:
            if let videoJob = videoJobs.first(where: { $0.id == job.id }) {
                videoJob.status = .saved
            }
        case .importJob:
            if let importJob = importJobs.first(where: { $0.id == job.id }) {
                modelContext.delete(importJob)
            }
        case .generation:
            if let genJob = generationJobs.first(where: { $0.id == job.id }) {
                genJob.status = .dismissed
            }
        case .sync:
            if let syncJob = syncJobs.first(where: { $0.id == job.id }) {
                modelContext.delete(syncJob)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        UnifiedProcessingBanner()
    }
    .modelContainer(for: [VideoProcessingJob.self, ImportJob.self, RecipeGenerationJob.self, SyncJob.self], inMemory: true)
}
