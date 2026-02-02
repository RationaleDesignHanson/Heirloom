//
//  RecipeGenerationBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-02.
//

import SwiftUI

/// Bottom banner showing recipe generation progress
/// Follows cookbook scan pattern: simple, non-blocking, auto-dismisses
struct RecipeGenerationBanner: View {
    @ObservedObject var service: RecipeGenerationService

    var body: some View {
        if let job = service.activeJob {
            VStack(spacing: 0) {
                // Progress bar at top
                GeometryReader { geometry in
                    Rectangle()
                        .fill(HeirloomColors.tomato)
                        .frame(width: geometry.size.width * progressPercentage(job))
                }
                .frame(height: 3)

                // Content
                HStack(spacing: HeirloomSpacing.md) {
                    // Phase icon
                    Image(systemName: job.currentPhase.iconName)
                        .font(.title2)
                        .foregroundStyle(iconColor(for: job))

                    // Text
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.dishName)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text(statusText(for: job))
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    // Status indicator
                    statusIndicator(for: job)
                }
                .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.cardBackground)
            .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func statusIndicator(for job: RecipeGenerationJob) -> some View {
        switch job.status {
        case .processing:
            ProgressView()
                .tint(HeirloomColors.tomato)

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)

        case .failed:
            Button {
                retryGeneration(job)
            } label: {
                Text("Retry")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Helper Methods

    private func progressPercentage(_ job: RecipeGenerationJob) -> Double {
        switch job.currentPhase {
        case .analyzing:
            return 0.2
        case .extracting:
            return 0.5
        case .enriching:
            return 0.8
        case .complete:
            return 1.0
        }
    }

    private func statusText(for job: RecipeGenerationJob) -> String {
        switch job.status {
        case .processing:
            return job.currentPhase.displayText
        case .completed:
            return "Recipe generated!"
        case .failed:
            return job.error ?? "Generation failed"
        }
    }

    private func iconColor(for job: RecipeGenerationJob) -> Color {
        switch job.status {
        case .processing:
            return HeirloomColors.tomato
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }

    private func retryGeneration(_ job: RecipeGenerationJob) {
        Task {
            do {
                // Get model context from service
                guard let context = service.context else {
                    Log.error("No model context available for retry", category: .general)
                    return
                }

                // Restart generation
                try await service.generateRecipe(
                    dishName: job.dishName,
                    ingredients: job.ingredients,
                    context: context
                )
            } catch {
                Log.error("Failed to retry generation", category: .general, error: error)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var service: RecipeGenerationService = {
        let aiGenerator = ServiceContainer.shared.resolve(AIRecipeGeneratorProtocol.self)
        let imageGenerator = ServiceContainer.shared.resolve(RecipeImageGeneratorProtocol.self)
        let service = RecipeGenerationService(
            aiGenerator: aiGenerator,
            imageGenerator: imageGenerator
        )
        return service
    }()

    VStack {
        Spacer()
        RecipeGenerationBanner(service: service)
    }
}
