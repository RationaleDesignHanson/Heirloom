//
//  UnifiedProcessingQueueView.swift
//  Heirloom
//
//  Full-screen queue sheet showing ALL job types in priority-based sections
//

import SwiftUI
import SwiftData

/// Section types for the queue view, ordered by priority
enum QueueSection: Int, CaseIterable, Identifiable {
    case processing = 0    // Currently active jobs
    case queue = 1         // Pending jobs waiting to start
    case needsAttention = 2 // Failed jobs with retry option
    case readyToReview = 3 // Completed, awaiting user action
    case recent = 4        // Saved/finished jobs (collapsed by default)

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .processing:
            return "Processing Now"
        case .queue:
            return "Queue"
        case .needsAttention:
            return "Needs Attention"
        case .readyToReview:
            return "Ready to Review"
        case .recent:
            return "Recent"
        }
    }

    var iconName: String {
        switch self {
        case .processing:
            return "bolt.fill"
        case .queue:
            return "clock"
        case .needsAttention:
            return "exclamationmark.triangle.fill"
        case .readyToReview:
            return "checkmark.circle.fill"
        case .recent:
            return "clock.arrow.circlepath"
        }
    }

    var accentColor: Color {
        switch self {
        case .processing:
            return HeirloomColors.tomato
        case .queue:
            return .orange
        case .needsAttention:
            return .red
        case .readyToReview:
            return HeirloomColors.familyGreen
        case .recent:
            return HeirloomColors.warmGray
        }
    }
}

/// Unified queue view showing all processing jobs across types
struct UnifiedProcessingQueueView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Query all job types
    @Query(sort: \VideoProcessingJob.createdAt, order: .reverse)
    private var videoJobs: [VideoProcessingJob]

    @Query(sort: \ImportJob.createdAt, order: .reverse)
    private var importJobs: [ImportJob]

    @Query(sort: \RecipeGenerationJob.createdAt, order: .reverse)
    private var generationJobs: [RecipeGenerationJob]

    // Callbacks for job interactions
    var onVideoJobTap: ((VideoProcessingJob) -> Void)?
    var onImportJobTap: ((ImportJob) -> Void)?
    var onGenerationJobTap: ((RecipeGenerationJob) -> Void)?

    // State for section collapse
    @State private var isRecentCollapsed = true

    var body: some View {
        NavigationStack {
            Group {
                if allJobs.isEmpty {
                    emptyState
                } else {
                    queueContent
                }
            }
            .navigationTitle("Processing Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Queue Content

    private var queueContent: some View {
        List {
            ForEach(QueueSection.allCases) { section in
                let jobs = jobsFor(section: section)
                if !jobs.isEmpty {
                    queueSectionView(section, jobs: jobs)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func queueSectionView(_ section: QueueSection, jobs: [AnyProcessingJob]) -> some View {
        Section {
            // Section content (jobs with swipe actions)
            if section != .recent || !isRecentCollapsed {
                ForEach(jobs) { job in
                    ProcessingJobCard(job: job, onTap: {
                        handleJobTap(job)
                    }, onDismiss: canDismiss(job) ? {
                        dismissJob(job)
                    } : nil)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if canDismiss(job) {
                            Button(role: .destructive) {
                                dismissJob(job)
                            } label: {
                                Label("Remove", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if canResume(job) {
                            Button {
                                resumeJob(job)
                            } label: {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .tint(HeirloomColors.familyGreen)
                        }
                    }
                }
            }
        } header: {
            // Section header
            Button {
                if section == .recent {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRecentCollapsed.toggle()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: section.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(section.accentColor)

                    Text(section.title)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("\(jobs.count)")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(section.accentColor)
                        .cornerRadius(10)

                    Spacer()

                    if section == .recent {
                        Image(systemName: isRecentCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(section != .recent)
            .textCase(nil)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("🍳")
                .font(.system(size: 64))

            Text("No recipes processing")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Import recipes from videos, PDFs, or websites to see them here.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Job Data

    /// All jobs converted to AnyProcessingJob for unified display
    private var allJobs: [AnyProcessingJob] {
        var jobs: [AnyProcessingJob] = []

        // Add video jobs
        for job in videoJobs where job.shouldShowInBanner {
            jobs.append(AnyProcessingJob(job, type: .video))
        }

        // Add import jobs
        for job in importJobs where job.shouldShowInBanner {
            jobs.append(AnyProcessingJob(job, type: .importJob))
        }

        // Add generation jobs
        for job in generationJobs where job.shouldShowInBanner {
            jobs.append(AnyProcessingJob(job, type: .generation))
        }

        return jobs
    }

    /// Jobs filtered by section
    private func jobsFor(section: QueueSection) -> [AnyProcessingJob] {
        var jobs: [AnyProcessingJob] = []

        switch section {
        case .processing:
            // Video jobs
            for job in videoJobs where job.status == .processing {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
            // Import jobs
            for job in importJobs where job.status == .processing {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }
            // Generation jobs
            for job in generationJobs where job.status == .processing {
                jobs.append(AnyProcessingJob(job, type: .generation))
            }

        case .queue:
            for job in videoJobs where job.status == .pending {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
            for job in importJobs where job.status == .pending {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }
            for job in generationJobs where job.status == .pending {
                jobs.append(AnyProcessingJob(job, type: .generation))
            }

        case .needsAttention:
            for job in videoJobs where job.status == .failed {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
            for job in importJobs where job.status == .failed {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }
            for job in generationJobs where job.status == .failed {
                jobs.append(AnyProcessingJob(job, type: .generation))
            }
            // Also paused jobs
            for job in videoJobs where job.status == .paused {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
            for job in importJobs where job.status == .paused {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }

        case .readyToReview:
            for job in videoJobs where job.status == .completed {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
            for job in importJobs where job.status == .completed {
                jobs.append(AnyProcessingJob(job, type: .importJob))
            }
            for job in generationJobs where job.status == .completed {
                jobs.append(AnyProcessingJob(job, type: .generation))
            }

        case .recent:
            // Saved/cancelled video jobs (last 10)
            let recentVideoJobs = videoJobs.filter { $0.status == .saved || $0.status == .cancelled }
            for job in recentVideoJobs.prefix(10) {
                jobs.append(AnyProcessingJob(job, type: .video))
            }
        }

        // Sort by priority within section
        return jobs.sorted { $0.bannerStatus.priority > $1.bannerStatus.priority }
    }

    // MARK: - Actions

    private func handleJobTap(_ job: AnyProcessingJob) {
        // Find the original job and call the appropriate callback
        switch job.jobType {
        case .video:
            if let videoJob = videoJobs.first(where: { $0.id == job.id }) {
                onVideoJobTap?(videoJob)
            }
        case .importJob:
            if let importJob = importJobs.first(where: { $0.id == job.id }) {
                onImportJobTap?(importJob)
            }
        case .generation:
            if let genJob = generationJobs.first(where: { $0.id == job.id }) {
                onGenerationJobTap?(genJob)
            }
        }
    }

    /// Check if a job can be dismissed (processing, completed, or failed jobs)
    /// Processing jobs can be cancelled/removed if stuck
    private func canDismiss(_ job: AnyProcessingJob) -> Bool {
        switch job.bannerStatus {
        case .processing, .pending, .paused, .completed, .failed:
            return true
        }
    }

    /// Check if a job can be resumed (stuck or interrupted import jobs)
    private func canResume(_ job: AnyProcessingJob) -> Bool {
        guard job.jobType == .importJob else { return false }
        guard let importJob = importJobs.first(where: { $0.id == job.id }) else { return false }
        return importJob.canResume || importJob.appearsStuck
    }

    /// Resume a stuck or interrupted job
    private func resumeJob(_ job: AnyProcessingJob) {
        guard job.jobType == .importJob else { return }
        guard let importJob = importJobs.first(where: { $0.id == job.id }) else { return }

        Task {
            do {
                let jobManager = ServiceContainer.shared.resolve(ImportJobManager.self)
                try await jobManager.resumeInterruptedJob(importJob, context: modelContext)
                Log.info("Resumed import job from queue", category: .import, metadata: [
                    "job_id": importJob.id.uuidString
                ])
            } catch {
                Log.error("Failed to resume import job", category: .import, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    /// Dismiss a job from the queue
    private func dismissJob(_ job: AnyProcessingJob) {
        withAnimation(.easeOut(duration: 0.25)) {
            switch job.jobType {
            case .video:
                if let videoJob = videoJobs.first(where: { $0.id == job.id }) {
                    // Mark as saved to remove from banner
                    videoJob.status = .saved
                }
            case .importJob:
                if let importJob = importJobs.first(where: { $0.id == job.id }) {
                    // Delete the import job
                    modelContext.delete(importJob)
                }
            case .generation:
                if let genJob = generationJobs.first(where: { $0.id == job.id }) {
                    // Mark as dismissed to remove from banner
                    genJob.status = .dismissed
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UnifiedProcessingQueueView()
        .modelContainer(for: [VideoProcessingJob.self, ImportJob.self, RecipeGenerationJob.self], inMemory: true)
}
