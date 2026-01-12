//
//  VideoProcessingJobListView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import SwiftUI
import SwiftData
import AVFoundation

/// Full sheet view showing all video processing jobs
struct VideoProcessingJobListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \VideoProcessingJob.createdAt, order: .reverse)
    private var allJobs: [VideoProcessingJob]

    @State private var jobManager = VideoProcessingJobManager()
    @State private var selectedJob: VideoProcessingJob?
    @State private var selectedExtraction: VideoRecipeExtraction?
    @State private var showReviewSheet = false

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
            .sheet(isPresented: $showReviewSheet) {
                if let extraction = selectedExtraction, let job = selectedJob {
                    VideoRecipeReviewView(
                        extraction: extraction,
                        enhancedExtraction: nil,
                        onSave: { updatedExtraction in
                            saveRecipe(from: updatedExtraction, job: job)
                            showReviewSheet = false
                        },
                        onCancel: {
                            showReviewSheet = false
                        }
                    )
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
                openReviewScreen(for: job)
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
                    openReviewScreen(for: job)
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

    private func openReviewScreen(for job: VideoProcessingJob) {
        guard job.status == .completed,
              let extractionData = job.extractionJSON else {
            Log.error("Cannot open review screen - job not completed or no extraction data", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "status": job.status.rawValue
            ])
            return
        }

        do {
            let extraction = try JSONDecoder().decode(VideoRecipeExtraction.self, from: extractionData)
            selectedJob = job
            selectedExtraction = extraction
            showReviewSheet = true
        } catch {
            Log.error("Failed to decode extraction from job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "error": error.localizedDescription
            ])
        }
    }

    private func saveRecipe(from extraction: VideoRecipeExtraction, job: VideoProcessingJob) {
        // Create Recipe from extraction
        let recipe = Recipe(
            title: extraction.structuredRecipe.title,
            sourceType: .video,
            sourceURL: extraction.metadata.attribution.sourceURL,
            instructions: extraction.structuredRecipe.steps.map { $0.instruction },
            servings: extraction.structuredRecipe.servings,
            prepTime: extraction.structuredRecipe.prepTime,
            cookTime: extraction.structuredRecipe.cookTime
        )

        // Set additional metadata
        recipe.notes = extraction.structuredRecipe.description
        recipe.sourcePerson = extraction.metadata.attribution.creatorName

        // Add ingredients
        for (index, extractedIng) in extraction.structuredRecipe.ingredients.enumerated() {
            // Simple conversion like original code - if quantity is "2", convert to 2.0; if "to taste", becomes nil
            let quantityDouble = extractedIng.quantity.flatMap { Double($0) }

            let ingredient = Ingredient(
                originalText: extractedIng.originalText,
                name: extractedIng.item,
                quantity: quantityDouble,
                unit: extractedIng.unit,
                category: .other,
                orderIndex: index
            )
            ingredient.preparation = extractedIng.preparation

            // Use proper SwiftData relationship pattern
            ingredient.recipe = recipe
            modelContext.insert(ingredient)
        }

        // Insert recipe
        modelContext.insert(recipe)

        // Update job status to saved
        job.status = .saved
        job.recipeID = recipe.id

        // Save context first
        do {
            try modelContext.save()
            Log.info("Recipe saved from video job", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "recipeId": recipe.id.uuidString,
                "title": recipe.title
            ])

            // Extract and save video thumbnail asynchronously after recipe is saved
            let videoURL = URL(fileURLWithPath: job.videoURL)
            Task {
                await saveVideoThumbnail(from: videoURL, to: recipe, context: modelContext)
            }
        } catch {
            Log.error("Failed to save recipe", category: .video, metadata: [
                "jobId": job.id.uuidString,
                "error": error.localizedDescription
            ])
        }
    }

    /// Extract thumbnail from video and save to recipe
    private func saveVideoThumbnail(from videoURL: URL, to recipe: Recipe, context: ModelContext) async {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero

        do {
            // Load duration asynchronously (iOS 16+)
            let duration = try await asset.load(.duration).seconds
            let time = CMTime(seconds: min(2.0, duration * 0.1), preferredTimescale: 600)

            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: cgImage)

            // Save via ImageStorageService from ServiceContainer
            await MainActor.run {
                let imageService = ServiceContainer.shared.resolve(ImageStorageService.self)
                Task {
                    if let fileName = try? await imageService.saveImage(image, recipeId: recipe.id) {
                        await MainActor.run {
                            recipe.imageFileName = fileName
                            try? context.save()
                            Log.info("Saved video thumbnail as recipe image", category: .video, metadata: [
                                "recipeId": recipe.id.uuidString,
                                "fileName": fileName
                            ])
                        }
                    }
                }
            }
        } catch {
            Log.error("Failed to extract video thumbnail", category: .video, metadata: [
                "error": error.localizedDescription
            ])
        }
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
