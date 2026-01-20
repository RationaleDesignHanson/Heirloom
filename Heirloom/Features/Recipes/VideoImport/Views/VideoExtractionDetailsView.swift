//
//  VideoExtractionDetailsView.swift
//  Heirloom
//
//  Created by Claude on 1/13/26.
//
//  Post-save transparency view showing AI extraction rationale
//  Part of Phase 3.2: Progressive disclosure for AI transparency

import SwiftUI
import SwiftData

struct VideoExtractionDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    let extraction: VideoRecipeExtraction
    let recipe: Recipe

    @State private var expandedSections: Set<Section> = []

    enum Section: String, CaseIterable {
        case transcript = "Full Transcript"
        case ingredients = "Ingredients Analysis"
        case instructions = "Instructions Analysis"
        case augmentation = "Similar Recipes Used"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Summary Card
                    extractionSummaryCard

                    // Processing Details
                    processingDetailsCard

                    // Expandable Sections
                    ForEach(Section.allCases, id: \.self) { section in
                        expandableSection(section)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Extraction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Summary Card

    private var extractionSummaryCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(confidenceColor)

                Text("Extraction Summary")
                    .font(HeirloomFonts.title3)
                    .fontWeight(.bold)
            }

            // Confidence Score
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                HStack {
                    Text("Confidence")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Spacer()

                    Text("\(Int(extraction.metadata.transcriptionConfidence * 100))%")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(confidenceColor)
                }

                ProgressView(value: extraction.metadata.transcriptionConfidence)
                    .tint(confidenceColor)
            }

            Divider()

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HeirloomSpacing.md) {
                statItem(label: "Ingredients", value: "\(extraction.structuredRecipe.ingredients.count)")
                statItem(label: "Steps", value: "\(extraction.structuredRecipe.steps.count)")
                statItem(label: "Processing Time", value: formatDuration(extraction.processingTime))
                statItem(label: "Transcript Words", value: "\(extraction.transcript.text.split(separator: " ").count)")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            Text(label)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text(value)
                .font(HeirloomFonts.title3)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Processing Details

    private var processingDetailsCard: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Processing Details")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)

            detailRow(label: "Transcription Provider", value: extraction.metadata.transcriptionProvider)
            detailRow(label: "Video Duration", value: formatDuration(extraction.metadata.videoDuration))
            detailRow(label: "Processing Cost", value: "$\(extraction.estimatedCost)")
            detailRow(label: "Processed At", value: formatDate(extraction.metadata.processedAt))

            if !extraction.visualElements.isEmpty {
                detailRow(label: "Visual Elements Detected", value: "\(extraction.visualElements.count) items")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(.white)
                .heirloomShadow(HeirloomShadows.subtle)
        )
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()

            Text(value)
                .font(HeirloomFonts.callout)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    // MARK: - Expandable Sections

    @ViewBuilder
    private func expandableSection(_ section: Section) -> some View {
        let isExpanded = expandedSections.contains(section)

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation {
                    if isExpanded {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack {
                    Text(section.rawValue)
                        .font(HeirloomFonts.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(HeirloomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .fill(.white)
                )
            }

            if isExpanded {
                sectionContent(section)
                    .padding(HeirloomSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func sectionContent(_ section: Section) -> some View {
        switch section {
        case .transcript:
            transcriptContent
        case .ingredients:
            ingredientsContent
        case .instructions:
            instructionsContent
        case .augmentation:
            augmentationContent
        }
    }

    // MARK: - Section Content

    private var transcriptContent: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Complete audio transcription from the video")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Divider()

            Text(extraction.transcript.text)
                .font(HeirloomFonts.callout)
                .foregroundStyle(HeirloomColors.primaryText)
                .textSelection(.enabled)
        }
    }

    private var ingredientsContent: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("How ingredients were detected from the transcript")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Divider()

            ForEach(Array(extraction.structuredRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack {
                        Text("\(index + 1).")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        Text(ingredient.displayString)
                            .font(HeirloomFonts.callout)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Spacer()

                        confidenceBadge(ingredient.confidence)
                    }

                    if ingredient.wasAugmented, let source = ingredient.augmentationSource {
                        Text("Quantity inferred from: \(source)")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(.orange)
                            .padding(.leading, 20)
                    }
                }
                .padding(.vertical, 4)

                if index < extraction.structuredRecipe.ingredients.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var instructionsContent: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("How steps were structured from the narration")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Divider()

            ForEach(Array(extraction.structuredRecipe.steps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    HStack(alignment: .top) {
                        Text("\(index + 1).")
                            .font(HeirloomFonts.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(HeirloomColors.secondaryText)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                            Text(step.instruction)
                                .font(HeirloomFonts.callout)
                                .foregroundStyle(HeirloomColors.primaryText)

                            HStack(spacing: HeirloomSpacing.sm) {
                                if let duration = step.duration {
                                    Label(duration, systemImage: "clock")
                                        .font(HeirloomFonts.caption2)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }

                                if let temp = step.temperature {
                                    Label(temp, systemImage: "thermometer")
                                        .font(HeirloomFonts.caption2)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }

                                Spacer()

                                confidenceBadge(step.confidence)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                if index < extraction.structuredRecipe.steps.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var augmentationContent: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            if extraction.structuredRecipe.usedAugmentation {
                Text("These similar recipes were used to fill in missing quantities")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Divider()

                if let sources = extraction.structuredRecipe.augmentationSources, !sources.isEmpty {
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(HeirloomColors.tomato)

                            Text(source)
                                .font(HeirloomFonts.callout)
                                .foregroundStyle(HeirloomColors.primaryText)
                        }
                        .padding(.vertical, 4)

                        if index < sources.count - 1 {
                            Divider()
                        }
                    }
                } else {
                    Text("Augmentation was used but source information not available")
                        .font(HeirloomFonts.callout)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .italic()
                }
            } else {
                Text("No augmentation needed - all ingredient quantities were directly detected from the video")
                    .font(HeirloomFonts.callout)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .italic()
            }
        }
    }

    // MARK: - Helper Views

    private func confidenceBadge(_ confidence: ExtractionConfidence) -> some View {
        let (text, color) = confidenceInfo(confidence)

        return Text(text)
            .font(HeirloomFonts.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }

    private func confidenceInfo(_ confidence: ExtractionConfidence) -> (String, Color) {
        switch confidence {
        case .high:
            return ("High", .green)
        case .medium:
            return ("Medium", .orange)
        case .approximate:
            return ("Approx", .yellow)
        case .unknown:
            return ("Unknown", .gray)
        }
    }

    // MARK: - Computed Properties

    private var confidenceColor: Color {
        let confidence = extraction.metadata.transcriptionConfidence
        if confidence >= 0.85 {
            return .green
        } else if confidence >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes)m \(secs)s"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let extraction = VideoRecipeExtraction(
        structuredRecipe: StructuredRecipe(
            title: "Chocolate Chip Cookies",
            description: "Classic homemade cookies",
            servings: 24,
            prepTime: "15 minutes",
            cookTime: "12 minutes",
            ingredients: [
                ExtractedIngredient(
                    item: "flour",
                    quantity: "2",
                    unit: "cups",
                    preparation: nil,
                    confidence: .high,
                    originalText: "2 cups flour",
                    wasAugmented: false,
                    augmentationSource: nil
                ),
                ExtractedIngredient(
                    item: "chocolate chips",
                    quantity: "1",
                    unit: "cup",
                    preparation: nil,
                    confidence: .medium,
                    originalText: "chocolate chips",
                    wasAugmented: true,
                    augmentationSource: "Classic Chocolate Chip Cookies"
                )
            ],
            steps: [
                ExtractedStep(
                    instruction: "Mix flour and sugar together",
                    duration: "2 minutes",
                    temperature: nil,
                    confidence: .high
                ),
                ExtractedStep(
                    instruction: "Add chocolate chips and mix",
                    duration: nil,
                    temperature: nil,
                    confidence: .high
                )
            ],
            overallConfidence: 0.92,
            warnings: [],
            usedAugmentation: true,
            augmentationSources: ["Classic Chocolate Chip Cookies", "Nestle Toll House Recipe"]
        ),
        transcript: TranscriptionResult(
            text: "Today we're making chocolate chip cookies. Start by mixing two cups of flour with sugar. Then add your chocolate chips and mix everything together.",
            language: "en",
            confidence: 0.92,
            duration: 180
        ),
        visualElements: ["measuring cup", "mixing bowl"],
        metadata: VideoImportMetadata(
            attribution: VideoSourceAttribution(),
            videoDuration: 180,
            transcriptionProvider: "WhisperKit",
            transcriptionConfidence: 0.92,
            processingCost: 0.15,
            processingTime: 120,
            transcriptText: "Today we're making chocolate chip cookies...",
            processedAt: Date()
        ),
        processingTime: 120,
        estimatedCost: 0.15
    )

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)
    let recipe = Recipe(title: "Chocolate Chip Cookies", sourceType: .video, instructions: ["Step 1", "Step 2"])

    return VideoExtractionDetailsView(extraction: extraction, recipe: recipe)
        .modelContainer(container)
}
