//
//  ASMRProcessingView.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI
import SwiftData
import AVFoundation

/// Shows real-time progress and findings during ASMR video processing
struct ASMRProcessingView: View {
    let videoURL: URL
    let userCaption: String
    @ObservedObject var processor: ASMRVideoProcessor
    let skipSoundAnalysis: Bool

    let onComplete: (ASMRRecipeExtraction) -> Void
    let onCancel: () -> Void

    @State private var processingError: Error?
    @State private var showError = false
    @State private var passFindings: [ASMRProcessingPass: [String]] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: HeirloomSpacing.xl) {
                        // Progress ring
                        progressRingSection

                        // Important notice
                        if processor.progress < 1.0 {
                            HStack(spacing: HeirloomSpacing.sm) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Keep this screen open during processing")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Current state description
                        stateDescriptionView

                        // Pass progress cards with live findings
                        passProgressSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Extracting Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .completed = processor.state {
                        EmptyView()
                    } else {
                        Button("Cancel") {
                            processor.cancel()
                            onCancel()
                        }
                    }
                }
            }
            .alert("Processing Error", isPresented: $showError) {
                Button("OK") {
                    onCancel()
                }
            } message: {
                if let error = processingError {
                    Text(error.localizedDescription)
                }
            }
            .task {
                await processVideo()
            }
        }
    }

    // MARK: - Progress Ring Section

    private var progressRingSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)

                // Progress circle
                Circle()
                    .trim(from: 0, to: processor.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: processor.progress)

                VStack(spacing: HeirloomSpacing.sm) {
                    Text("\(Int(processor.progress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if let pass = processor.currentPass {
                        Text("Pass \(pass.rawValue + 1)/5")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Processing time estimate
            if processor.progress < 1.0 {
                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "clock")
                        .font(HeirloomFonts.caption1)
                    Text(estimatedTimeRemaining)
                        .font(HeirloomFonts.caption1)
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - State Description

    @ViewBuilder
    private var stateDescriptionView: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            switch processor.state {
            case .idle:
                EmptyView()

            case .preparingVideo:
                stateLabel(
                    icon: "video",
                    title: "Preparing video...",
                    subtitle: "Loading and verifying video file",
                    color: .blue
                )

            case .analyzingSounds:
                stateLabel(
                    icon: "waveform",
                    title: "Analyzing audio...",
                    subtitle: "Checking video suitability for ASMR processing",
                    color: .blue
                )

            case .extractingFrames:
                stateLabel(
                    icon: "photo.on.rectangle.angled",
                    title: "Extracting frames...",
                    subtitle: "Capturing key moments from video",
                    color: .blue
                )

            case .processingPass(let pass, _):
                stateLabel(
                    icon: passIcon(for: pass),
                    title: pass.displayName,
                    subtitle: pass.description,
                    color: .blue
                )

            case .completed:
                stateLabel(
                    icon: "checkmark.circle.fill",
                    title: "Extraction Complete!",
                    subtitle: "Recipe successfully extracted",
                    color: .green
                )

            case .failed(let error):
                stateLabel(
                    icon: "exclamationmark.triangle.fill",
                    title: "Processing Failed",
                    subtitle: error.localizedDescription,
                    color: .red
                )

            case .cancelled:
                stateLabel(
                    icon: "xmark.circle.fill",
                    title: "Processing Cancelled",
                    subtitle: "Extraction was cancelled by user",
                    color: .orange
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func stateLabel(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)

                Text(subtitle)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Pass Progress Section

    private var passProgressSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Processing Passes")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(ASMRProcessingPass.allCases, id: \.self) { pass in
                    ASMRPassProgressCard(
                        pass: pass,
                        isActive: processor.currentPass == pass,
                        isComplete: passIsComplete(pass),
                        findings: findingsForPass(pass)
                    )
                }
            }
        }
    }

    // MARK: - Processing Logic

    private func processVideo() async {
        do {
            let result = try await processor.process(
                videoURL: videoURL,
                userCaption: userCaption,
                videoHash: nil,
                skipSoundAnalysis: skipSoundAnalysis
            )

            // Update findings as passes complete
            if case .processingPass(let pass, let findings) = processor.state {
                passFindings[pass] = findings
            }

            print("✅ ASMR processing complete, calling onComplete...")

            // Call onComplete on MainActor with the extraction
            await MainActor.run {
                onComplete(result)
            }

        } catch {
            await MainActor.run {
                processingError = error
                showError = true
            }
        }
    }

    // MARK: - Helpers

    private func passIsComplete(_ pass: ASMRProcessingPass) -> Bool {
        guard let currentPass = processor.currentPass else {
            return false
        }
        return pass.rawValue < currentPass.rawValue || processor.progress >= 1.0
    }

    private func findingsForPass(_ pass: ASMRProcessingPass) -> [String] {
        return passFindings[pass] ?? []
    }

    private func passIcon(for pass: ASMRProcessingPass) -> String {
        switch pass {
        case .identifying:
            return "eye"
        case .detecting:
            return "magnifyingglass"
        case .inferring:
            return "brain"
        case .analyzing:
            return "chart.bar"
        case .validating:
            return "checkmark.seal"
        }
    }

    private var estimatedTimeRemaining: String {
        // Average processing time is ~3-5 minutes
        // Estimate based on current progress
        let totalEstimatedSeconds: Double = 240  // 4 minutes average
        let remainingProgress = max(0, 1.0 - processor.progress)
        let remainingSeconds = Int(totalEstimatedSeconds * remainingProgress)

        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60

        if minutes > 0 {
            return "~\(minutes)m \(seconds)s remaining"
        } else {
            return "~\(seconds)s remaining"
        }
    }
}

// MARK: - ASMRProcessingPass Extension

extension ASMRProcessingPass {
    var description: String {
        switch self {
        case .identifying:
            return "Identifying the dish from final frames"
        case .detecting:
            return "Detecting visible ingredients and transformations"
        case .inferring:
            return "Inferring hidden ingredients and seasonings"
        case .analyzing:
            return "Recognizing cooking actions and techniques"
        case .validating:
            return "Synthesizing and validating complete recipe"
        }
    }
}

// MARK: - Preview

#Preview {
    ASMRProcessingView(
        videoURL: URL(string: "file:///test.mov")!,
        userCaption: "Making carbonara pasta",
        processor: ASMRVideoProcessor(),
        skipSoundAnalysis: false,
        onComplete: { extraction in
            print("Extraction complete: \(extraction.structuredRecipe.title)")
        },
        onCancel: {}
    )
}
