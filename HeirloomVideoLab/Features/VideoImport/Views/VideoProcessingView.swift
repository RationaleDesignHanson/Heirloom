//
//  VideoProcessingView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Displays processing progress with deterministic indicators

import SwiftUI

struct VideoProcessingView: View {
    @ObservedObject var processor: VideoRecipeProcessor
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss

    @State private var extraction: VideoRecipeExtraction?
    @State private var showReview = false
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Processing indicator
                ProcessingIndicator(
                    state: processor.state,
                    progress: processor.progress
                )

                // Status text
                VStack(spacing: 12) {
                    Text(processor.state.displayTitle)
                        .font(.title2.bold())

                    Text(processor.state.displaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Cancel button
                if processor.canCancel {
                    Button("Cancel", role: .cancel) {
                        processor.cancel()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationBarBackButtonHidden()
            .task {
                do {
                    let result = try await processor.process(videoURL: videoURL)
                    extraction = result
                    showReview = true
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .fullScreenCover(isPresented: $showReview) {
                if let extraction = extraction {
                    VideoRecipeReviewView(
                        extraction: extraction,
                        enhancedExtraction: processor.enhancedExtraction,  // NEW: Pass augmentation data
                        onSave: { updatedExtraction in
                            // In real app: save to SwiftData
                            print("Would save recipe: \(updatedExtraction.structuredRecipe.title)")
                            dismiss()
                        },
                        onCancel: {
                            dismiss()
                        }
                    )
                }
            }
            .alert("Processing Failed", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
}

// MARK: - Processing Indicator

struct ProcessingIndicator: View {
    let state: ProcessingState
    let progress: Double

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 8)
                .frame(width: 120, height: 120)

            // Progress circle or icon
            Group {
                switch state {
                case .transcribing(let transcribeProgress) where transcribeProgress > 0:
                    // Show progress ring for transcription
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color.blue.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                case .reviewing:
                    // Show checkmark when ready for review
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)

                case .failed:
                    // Show error icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.red)

                case .completed:
                    // Show success icon
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)

                default:
                    // Show spinner for other states
                    ProgressView()
                        .scaleEffect(2.0)
                        .tint(.blue)
                }
            }
        }
    }
}

// MARK: - Preview

// Previews commented out - require real VideoRecipeProcessor instance
// Use simulator to test this view

//#Preview("Processing") {
//    VideoProcessingView(
//        processor: VideoRecipeProcessor(...),
//        videoURL: URL(fileURLWithPath: "/tmp/test.mp4")
//    )
//}
