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
    @State private var showDishNamePrompt = false
    @State private var dishName = ""

    // Check premium status for visual extraction
    private var subscriptionManager: SubscriptionManager {
        ServiceContainer.shared.resolve(SubscriptionManager.self)
    }

    private var paywallManager: PaywallManager {
        ServiceContainer.shared.resolve(PaywallManager.self)
    }

    private var isPremium: Bool {
        subscriptionManager.isPremium
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Error Icon
                    errorIcon
                        .font(.system(size: 64))
                        .foregroundStyle(errorIconColor)

                    VStack(spacing: HeirloomSpacing.md) {
                        // Title - different for ASMR vs real errors
                        Text(errorTitle)
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
                        // "Re-import Video" button (only for file not found errors)
                        if safeErrorType == .fileNotFound {
                            Button {
                                handleAction(.startOver)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Re-import Video")
                                            .fontWeight(.semibold)
                                        Text("Start fresh with a new video")
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
                                .background(HeirloomColors.tomato)
                                .foregroundStyle(HeirloomColors.buttonTextLight)
                                .cornerRadius(12)
                            }
                            .disabled(isProcessing)
                        }

                        // Special ASMR button (only for audio failures)
                        if shouldShowASMROption {
                            if isPremium {
                                // Premium user: Can use ASMR mode
                                Button {
                                    showDishNamePrompt = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "eye.circle.fill")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Try Visual Extraction")
                                                .fontWeight(.semibold)
                                            Text("Analyzes video frames")
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
                            } else {
                                // Non-premium: Show upgrade button
                                Button {
                                    paywallManager.show(for: .visualVideoExtraction)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "crown.fill")
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Upgrade to Premium")
                                                .fontWeight(.semibold)
                                            Text("Unlock visual extraction for silent videos")
                                                .font(HeirloomFonts.caption1)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundStyle(HeirloomColors.buttonTextLight)
                                    .cornerRadius(12)
                                }
                            }
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
            .onChange(of: isPremium) {
                // If user just upgraded to premium while viewing this sheet, show dish name prompt
                if isPremium && shouldShowASMROption {
                    showDishNamePrompt = true
                }
            }
            .sheet(isPresented: $showDishNamePrompt) {
                dishNamePromptSheet
            }
        }
    }

    // MARK: - Dish Name Prompt Sheet

    private var dishNamePromptSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.purple)

                    Text("Visual Extraction")
                        .font(.title2.bold())

                    Text("Help us understand what's being cooked. This improves accuracy significantly.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What dish is this?")
                        .font(.subheadline.bold())

                    TextField("e.g., Making carbonara pasta", text: $dishName, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...5)

                    Text("At least 5 characters required")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    handleAction(.tryASMRMode(dishName: dishName))
                    showDishNamePrompt = false
                } label: {
                    Text("Start Visual Extraction")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canSubmitDishName ? Color.purple : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(!canSubmitDishName || isProcessing)
                .padding(.horizontal)
            }
            .padding(.vertical, 24)
            .navigationTitle("Dish Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDishNamePrompt = false
                        dishName = ""
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    private var canSubmitDishName: Bool {
        dishName.count >= 5
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

    private var errorTitle: String {
        if shouldShowASMROption {
            return "Visual Processing Available"
        }
        return "Processing Failed"
    }

    private var errorIcon: Image {
        guard let errorType = safeErrorType else {
            return Image(systemName: "exclamationmark.triangle")
        }

        switch errorType {
        case .insufficientAudioData:
            // Special icon for visual extraction feature (not an error)
            return Image(systemName: "eye.circle.fill")
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
            // Purple to match visual extraction feature color
            return .purple
        case .fileNotFound, .permissionDenied, .other:
            return .red
        }
    }

    private var errorExplanation: String {
        // For ASMR/visual extraction scenarios, use positive messaging
        if shouldShowASMROption {
            return "This video doesn't have clear narration. Our visual extraction feature can analyze the video frames to extract the recipe."
        }

        // Special messaging for fileNotFound after crash
        if safeErrorType == .fileNotFound {
            return "The video file was removed (possibly after an app crash or by iCloud). Please re-import your video to try again."
        }

        // For other errors, show error message or fallback
        if let errorMessage = job.errorMessage {
            return errorMessage
        }

        // Fallback explanations
        guard let errorType = safeErrorType else {
            return "An unexpected error occurred during processing."
        }

        switch errorType {
        case .insufficientAudioData:
            return "This video doesn't have clear narration. Our visual extraction feature can analyze the video frames to extract the recipe."
        case .fileNotFound:
            return "The video file was removed (possibly after an app crash or by iCloud). Please re-import your video to try again."
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
