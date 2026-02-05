//
//  ImportProgressBannerContainer.swift
//  Heirloom
//
//  Container view that observes ImportJobs and displays ProcessingBottomBanner
//  Uses both @Query for persistence and manager.pendingJobId for immediate UI response
//

import SwiftUI
import SwiftData

/// Container that observes ImportJob via @Query and displays ProcessingBottomBanner
/// with immediate response via pendingJobId signal
struct ImportProgressBannerContainer: View {
    @Environment(\.modelContext) private var modelContext

    /// Primary observation via @Query
    @Query(sort: \ImportJob.createdAt, order: .reverse)
    private var allJobs: [ImportJob]

    /// Observe manager for immediate signal (bypasses @Query latency)
    @ObservedObject var jobManager: ImportJobManager

    /// Sheet state for full progress view
    @State private var selectedJob: ImportJob?

    /// The job to display in the banner (prioritizes immediate signal)
    private var visibleJob: ImportJob? {
        // First check for immediate pending job signal (fast path)
        if let pendingId = jobManager.pendingJobId,
           let pendingJob = allJobs.first(where: { $0.id == pendingId }) {
            return pendingJob
        }

        // Fall back to filtered @Query results (reliable path)
        return allJobs.first { job in
            job.shouldShowInBanner
        }
    }

    var body: some View {
        if let job = visibleJob {
            ProcessingBottomBanner(job: job) {
                selectedJob = job
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeOut(duration: 0.2), value: job.id)
            .sheet(item: $selectedJob) { job in
                NavigationStack {
                    ImportProgressView(
                        manager: jobManager,
                        job: job
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        ImportProgressBannerContainer(
            jobManager: ServiceContainer.shared.resolve(ImportJobManager.self)
        )
    }
    .modelContainer(for: ImportJob.self, inMemory: true)
}
