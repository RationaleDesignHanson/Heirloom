//
//  VideoImportView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Entry point for video recipe import

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct VideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: FirebaseNotificationService
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var showSourceDetails = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var jobManager = VideoProcessingJobManager()

    // Optional source metadata
    @State private var sourceURL: String = ""
    @State private var captionText: String = ""

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    VStack(spacing: 4) {
                        Text("Import from Video")
                            .font(.title.bold())

                        // Mode indicator badge
                        Text("Video with Instructions")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    Text("Extract a recipe from a cooking video. Works best with clear audio narration.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Source options
                VStack(spacing: 16) {
                    // Camera Roll option (primary)
                    Button {
                        showVideoPicker = true
                    } label: {
                        SourceOptionRow(
                            icon: "photo.on.rectangle",
                            title: "From Camera Roll",
                            subtitle: "Select a video you've recorded or saved",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Privacy note
                VStack(spacing: 8) {
                    Text("Attribution Required")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)

                    Text("You'll be asked to credit the original creator during review.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Videos are processed on-device when possible. Audio is never stored permanently.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Clear coordinator context on cancel
                        tabCoordinator.didCancelCreation()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPickerView(
                    selectedURL: $selectedVideoURL,
                    onError: { error in
                        errorMessage = error
                        showErrorAlert = true
                    }
                )
            }
            .alert("Video Loading Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedVideoURL) { _, newURL in
                if newURL != nil {
                    // Show source details sheet (optional step)
                    showSourceDetails = true
                }
            }
            .sheet(isPresented: $showSourceDetails) {
                VideoSourceDetailsView(
                    sourceURL: $sourceURL,
                    captionText: $captionText,
                    onContinue: {
                        showSourceDetails = false
                        createJob()
                    },
                    onSkip: {
                        showSourceDetails = false
                        createJob()
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func createJob() {
        guard let videoURL = selectedVideoURL else { return }

        Task {
            do {
                // Create attribution
                let attribution = VideoSourceAttribution(
                    sourceURL: sourceURL.isEmpty ? nil : sourceURL,
                    captionText: captionText.isEmpty ? nil : captionText
                )

                // Create job
                let job = try jobManager.createJob(
                    videoURL: videoURL,
                    videoType: .standard,
                    userCaption: captionText.isEmpty ? nil : captionText,
                    videoDuration: nil,
                    sourceAttribution: attribution,
                    context: modelContext
                )

                // Show success toast
                toastManager.success(
                    title: "Video added to queue",
                    message: "Processing will continue in the background"
                )

                // Notify coordinator
                tabCoordinator.didCreateRecipe()

                // Dismiss immediately
                dismiss()

                Log.info("Video job created successfully", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "videoType": "standard"
                ])
            } catch {
                errorMessage = "Failed to create job: \(error.localizedDescription)"
                showErrorAlert = true

                Log.error("Failed to create video job", category: .video, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
}

// MARK: - Video Source Details View

/// Optional step to capture source link and caption text
struct VideoSourceDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sourceURL: String
    @Binding var captionText: String
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Optional Enhancement", systemImage: "sparkles")
                            .font(.subheadline.bold())
                            .foregroundStyle(.blue)

                        Text("If this video is from social media (Instagram, TikTok, YouTube), you can paste additional info to improve recipe extraction accuracy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    TextField("Original Post Link (optional)", text: $sourceURL, axis: .vertical)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .lineLimit(2...3)

                    TextField("Video Caption/Description (optional)", text: $captionText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Source Information")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Link is for attribution only - displayed as \"View Original\" on recipe card")
                        Text("• Caption text helps AI find missing ingredient quantities")
                        Text("• Both fields are optional - skip if not applicable")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("We do NOT scrape websites")
                                .font(.caption.bold())
                            Text("Links are for attribution only, never used for extraction")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Video Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onContinue()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Source Option Row

struct SourceOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Video Picker

struct VideoPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    let onError: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .videos
        config.preferredAssetRepresentationMode = .current  // Force download from iCloud if needed

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPickerView

        init(_ parent: VideoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()

            guard let result = results.first else { return }

            // Try to load as data (more reliable in simulator and with iCloud videos)
            result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.movie") { data, error in
                guard let data = data else {
                    let errorMsg: String
                    if let error = error as NSError? {
                        if error.domain == "CloudPhotoLibraryErrorDomain" ||
                           error.code == 1006 ||
                           error.localizedDescription.contains("iCloud") {
                            errorMsg = "This video is stored in iCloud and couldn't be downloaded. Please ensure the video is fully downloaded to your device and try again."
                        } else {
                            errorMsg = "Failed to load video: \(error.localizedDescription)"
                        }
                    } else {
                        errorMsg = "Failed to load video. Please try another video."
                    }

                    DispatchQueue.main.async {
                        self.parent.onError(errorMsg)
                    }
                    return
                }

                // Write data to temp file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")

                do {
                    try data.write(to: tempURL)
                    DispatchQueue.main.async {
                        self.parent.selectedURL = tempURL
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.onError("Failed to save video: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Processing Container (Async Init)

/// Wrapper view that handles async initialization of VideoRecipeProcessor
struct VideoProcessingContainerView: View {
    let videoURL: URL
    let sourceAttribution: VideoSourceAttribution
    let modelContext: ModelContext
    let onComplete: (Recipe) -> Void  // NEW: Called when recipe is saved, passes recipe

    @State private var processor: VideoRecipeProcessor?
    @State private var isInitializing = true

    var body: some View {
        Group {
            if let processor = processor {
                VideoProcessingView(
                    processor: processor,
                    videoURL: videoURL,
                    sourceAttribution: sourceAttribution,
                    onComplete: onComplete
                )
            } else {
                // Show loading while initializing
                VStack(spacing: 16) {
                    ProgressView()
                    Text(isInitializing ? "Initializing transcription..." : "Failed to initialize")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await initializeProcessor()
        }
    }

    private func initializeProcessor() async {
        // Initialize services
        let aiService = ServiceContainer.shared.resolve(AnthropicAIService.self)
        let transcriptionService = await WhisperKitTranscriptionService()
        let recipeStructurer = ClaudeRecipeStructurer(aiService: aiService)

        let newProcessor = VideoRecipeProcessor(
            transcriptionService: transcriptionService,
            recipeStructurer: recipeStructurer,
            modelContext: modelContext,
            aiService: aiService,
            enableFrameAnalysis: true,
            enableCaching: true,
            enableAugmentation: true
        )

        await MainActor.run {
            self.processor = newProcessor
            self.isInitializing = false
        }
    }
}

// MARK: - Preview

#Preview {
    VideoImportView()
}
