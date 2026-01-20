//
//  JobRecoverySheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI
import SwiftData

/// Sheet view for recovering from failed video processing jobs
/// Provides contextual recovery options based on error type
struct JobRecoverySheet: View {
    let job: VideoProcessingJob
    let onRecoveryAction: (RecoveryAction) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Error Icon
                    errorIcon
                        .font(.system(size: 64))
                        .foregroundStyle(errorIconColor)

                    VStack(spacing: HeirloomSpacing.md) {
                        // Title
                        Text("Processing Failed")
                            .font(.title2.bold())

                        // Contextual explanation
                        Text(errorExplanation)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Recovery Actions
                    VStack(spacing: 12) {
                        // Special ASMR button (only for audio failures)
                        if shouldShowASMROption {
                            Button {
                                handleAction(.tryASMRMode)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "eye.circle.fill")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Try ASMR Mode")
                                            .fontWeight(.semibold)
                                        Text("5 credits")
                                            .font(HeirloomFonts.caption1)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    if isProcessing {
                                        ProgressView()
                                            .tint(HeirloomColors.buttonTextLight)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                        }

                        // Retry button
                        Button {
                            handleAction(.retry)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry")
                                    .fontWeight(.medium)
                                Spacer()
                                if isProcessing {
                                    ProgressView()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)

                        // Cancel button
                        Button(role: .destructive) {
                            handleAction(.cancel)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "xmark")
                                Text("Cancel")
                                    .fontWeight(.medium)
                                Spacer()
                                if isProcessing {
                                    ProgressView()
                                        .tint(.red)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Job Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Computed Properties

    private var safeErrorType: ProcessingErrorType? {
        // For old jobs created before errorType field was added, infer from errorMessage
        // This avoids SwiftData crashes when accessing fields that don't exist in old schema

        // Check if we have the error message (old field that exists)
        guard let errorMsg = job.errorMessage else {
            return nil
        }

        // Infer error type from message text
        let msgLower = errorMsg.lowercased()
        if msgLower.contains("audio") || msgLower.contains("silent") ||
           msgLower.contains("data couldn't be read") || msgLower.contains("missing") ||
           msgLower.contains("confidence") || msgLower.contains("extraction") {
            return .insufficientAudioData
        } else if msgLower.contains("not found") || msgLower.contains("icloud") {
            return .fileNotFound
        } else if msgLower.contains("permission") {
            return .permissionDenied
        } else {
            return .other
        }
    }

    private var errorIcon: Image {
        guard let errorType = safeErrorType else {
            return Image(systemName: "exclamationmark.triangle")
        }

        switch errorType {
        case .insufficientAudioData:
            return Image(systemName: "waveform.badge.exclamationmark")
        case .fileNotFound:
            return Image(systemName: "doc.badge.exclamationmark")
        case .permissionDenied:
            return Image(systemName: "lock.shield")
        case .other:
            return Image(systemName: "exclamationmark.triangle")
        }
    }

    private var errorIconColor: Color {
        guard let errorType = safeErrorType else {
            return .red
        }

        switch errorType {
        case .insufficientAudioData:
            return .orange
        case .fileNotFound, .permissionDenied, .other:
            return .red
        }
    }

    private var errorExplanation: String {
        if let errorMessage = job.errorMessage {
            return errorMessage
        }

        // Fallback explanations
        guard let errorType = safeErrorType else {
            return "An unexpected error occurred during processing."
        }

        switch errorType {
        case .insufficientAudioData:
            return "Could not extract audio from video. This video appears to be silent or have unclear narration."
        case .fileNotFound:
            return "Video file could not be accessed. It may be stored in iCloud and not downloaded."
        case .permissionDenied:
            return "Permission denied accessing video. Please check app permissions in Settings."
        case .other:
            return "An unexpected error occurred during processing."
        }
    }

    private var shouldShowASMROption: Bool {
        safeErrorType == .insufficientAudioData
    }

    // MARK: - Actions

    private func handleAction(_ action: RecoveryAction) {
        isProcessing = true

        Task {
            do {
                try await onRecoveryAction(action)
                await MainActor.run {
                    dismiss()
                }
            } catch let error as RecoveryError {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var job = VideoProcessingJob(
        videoURL: "/path/to/video.mov",
        videoType: .standard
    )

    job.status = .failed
    job.errorType = .insufficientAudioData
    job.errorMessage = "Could not extract audio from video. This video appears to be silent or have unclear narration."

    return JobRecoverySheet(job: job) { action in
        print("Recovery action: \(action)")
    }
}
