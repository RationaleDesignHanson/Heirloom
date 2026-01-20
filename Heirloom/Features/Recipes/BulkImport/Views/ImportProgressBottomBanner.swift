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

    // Filter to active jobs (processing or completed)
    private var activeJobs: [ImportJob] {
        allJobs.filter { job in
            job.status == .processing || job.status == .completed
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
                        // Icon based on phase
                        phaseIcon(for: job.phase)
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.tomato)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(titleText(for: job))
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.charcoal)

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
        } else {
            // Processing state - show phase
            return job.phase.displayName
        }
    }

    private func subtitleText(for job: ImportJob) -> String {
        if job.status == .completed {
            // Show success/failure summary
            let successCount = job.successfulItems
            let failCount = job.failedItems

            if failCount > 0 {
                return "\(successCount) recipes added, \(failCount) failed"
            } else {
                return "\(successCount) recipes added"
            }
        } else {
            // Processing state - show progress
            return "\(job.completedItems) of \(job.totalItems) recipes"
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
