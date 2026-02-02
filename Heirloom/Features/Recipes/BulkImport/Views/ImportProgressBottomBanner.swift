//
//  ImportProgressBottomBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-16.
//

import SwiftUI
import SwiftData

/// Persistent bottom banner showing active import jobs
/// Similar to VideoProcessingBottomBanner - allows reopening progress after dismissal
struct ImportProgressBottomBanner: View {
    @Environment(\.modelContext) private var modelContext

    // Query for all jobs, sorted by creation date (most recent first)
    @Query(sort: \ImportJob.createdAt, order: .reverse)
    private var allJobs: [ImportJob]

    // Query for all recipes (to fetch titles by ID)
    @Query private var allRecipes: [Recipe]

    @State private var selectedJob: ImportJob?

    // Filter to active jobs (show processing, paused, and failed jobs that can be resumed)
    private var activeJobs: [ImportJob] {
        allJobs.filter { job in
            job.status == .processing ||
            job.status == .paused ||
            (job.status == .failed && job.canResume)
        }
    }

    private var visibleJob: ImportJob? {
        // Show most recent active job
        activeJobs.first
    }

    var body: some View {
        if let job = visibleJob {
            VStack(spacing: 0) {
                // Mini progress bar at top
                ProgressView(value: job.overallProgress)
                    .progressViewStyle(.linear)
                    .tint(HeirloomColors.tomato)

                // Tappable banner content
                Button {
                    selectedJob = job
                } label: {
                    HStack(spacing: 12) {
                        // Icon based on status/phase
                        if job.status == .paused {
                            Image(systemName: "pause.circle.fill")
                                .font(HeirloomFonts.title2)
                                .foregroundStyle(.orange)
                        } else if job.status == .failed && job.canResume {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(HeirloomFonts.title2)
                                .foregroundStyle(.orange)
                        } else {
                            phaseIcon(for: job.phase)
                                .font(HeirloomFonts.title2)
                                .foregroundStyle(HeirloomColors.tomato)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(titleText(for: job))
                                    .font(HeirloomFonts.bodyBold)
                                    .foregroundStyle(HeirloomColors.charcoal)

                                // Recipe count badge for multi-recipe imports
                                if job.totalItems > 1 && job.status != .completed {
                                    Text("+\(job.totalItems)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(HeirloomColors.tomato)
                                        .cornerRadius(8)
                                }
                            }

                            Text(subtitleText(for: job))
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        Spacer()

                        // Percentage or checkmark
                        if job.status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(HeirloomFonts.title2)
                        } else if job.status == .failed {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(HeirloomFonts.title2)
                        } else {
                            Text("\(Int(job.overallProgress * 100))%")
                                .font(HeirloomFonts.caption1Bold)
                                .foregroundStyle(HeirloomColors.tomato)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(Color(.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 8, y: -4)
            .sheet(item: $selectedJob) { job in
                NavigationStack {
                    ImportProgressView(
                        manager: ServiceContainer.shared.resolve(ImportJobManager.self),
                        job: job
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func phaseIcon(for phase: ImportPhase) -> some View {
        Image(systemName: phase.iconName)
    }

    private func titleText(for job: ImportJob) -> String {
        if job.status == .completed {
            // For single-recipe imports, show the actual recipe title
            if job.totalItems == 1,
               let items = job.items,
               let successfulItem = items.first(where: { $0.status == .success }),
               let recipeID = successfulItem.recipeID,
               let recipe = allRecipes.first(where: { $0.id == recipeID }) {
                return recipe.title
            }

            // For multi-recipe imports or when recipe not found, show cookbook name
            if let cookbookName = job.cookbookName, !cookbookName.isEmpty {
                return "Added to \(cookbookName)"
            } else {
                return "Import complete"
            }
        } else if job.status == .paused {
            // Paused state
            return "Import Paused"
        } else if job.status == .failed && job.canResume {
            // Failed but can resume
            return "Import Interrupted"
        } else {
            // Processing state - show phase
            return job.phase.displayName
        }
    }

    private func subtitleText(for job: ImportJob) -> String {
        if job.status == .completed {
            // Show success/failure summary with collection name
            let successCount = job.successfulItems
            let failCount = job.failedItems

            if let collectionName = job.cookbookName, !collectionName.isEmpty {
                if failCount > 0 {
                    return "\(successCount) added to \(collectionName), \(failCount) failed"
                } else {
                    return "Saved to \(collectionName)"
                }
            } else {
                if failCount > 0 {
                    return "\(successCount) recipes added, \(failCount) failed"
                } else {
                    return "\(successCount) recipes added"
                }
            }
        } else if job.status == .paused {
            // Paused state - show call to action
            return "Tap to resume • \(job.completedItems) of \(job.totalItems) complete"
        } else if job.status == .failed && job.canResume {
            // Failed but can resume - show helpful message
            return "Tap to retry from last checkpoint"
        } else {
            // Processing state - show phase-specific progress
            if job.totalItems > 1 {
                return "\(job.phase.displayName) • \(job.completedItems) of \(job.totalItems)"
            } else {
                // Single item - show cookbook name if available, otherwise helpful context
                if let cookbookName = job.cookbookName, !cookbookName.isEmpty {
                    return "Saving to \(cookbookName)"
                } else {
                    return "Processing your recipe"
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var mockJob = {
        let job = ImportJob(jobName: "Test Import")
        job.status = .processing
        job.phase = .analysis
        job.phaseProgress = 0.5
        job.totalItems = 10
        job.completedItems = 5
        return job
    }()

    VStack {
        Spacer()
        ImportProgressBottomBanner()
    }
    .modelContainer(for: ImportJob.self, inMemory: true)
}
