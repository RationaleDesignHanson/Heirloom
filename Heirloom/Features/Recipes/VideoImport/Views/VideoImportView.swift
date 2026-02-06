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
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isLoadingVideo = false
    @StateObject private var jobManager = VideoProcessingJobManager()

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    VStack(spacing: HeirloomSpacing.xs) {
                        Text("Import from Video")
                            .font(.title.bold())

                        // Mode indicator badge
                        Text("From Camera Roll")
                            .font(.caption.bold())
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }

                    Text("Select a video from your camera roll with spoken cooking instructions. Works best with clear narration.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Source options
                VStack(spacing: HeirloomSpacing.md) {
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
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Attribution Required")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)

                    Text("You'll be asked to credit the original creator during review.")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Videos are processed on-device when possible. Audio is never stored permanently.")
                        .font(HeirloomFonts.caption1)
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
                    isLoading: $isLoadingVideo,
                    onError: { error in
                        errorMessage = error
                        showErrorAlert = true
                    }
                )
            }
            .overlay {
                // Loading overlay while video is being copied from Photos library
                if isLoadingVideo {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: HeirloomSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Loading video...")
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(.white)
                        }
                        .padding(HeirloomSpacing.xl)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
            .alert("Video Loading Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedVideoURL) { _, newURL in
                if newURL != nil {
                    // Queue job immediately (Phase 1.2: Skip source details screen)
                    createJob()
                }
            }
        }
    }

    // MARK: - Actions

    private func createJob() {
        guard let videoURL = selectedVideoURL else { return }

        Task {
            do {
                // Create empty attribution (Phase 1.2: Defer metadata collection)
                // Attribution will be collected post-save via VideoAttributionSheet
                let attribution = VideoSourceAttribution(
                    sourceURL: nil,
                    captionText: nil
                )

                // Create job
                let job = try jobManager.createJob(
                    videoURL: videoURL,
                    videoType: .standard,
                    userCaption: nil,  // No caption upfront
                    videoDuration: nil,
                    sourceAttribution: attribution,
                    context: modelContext
                )

                // Get total queue count for toast
                let descriptor = FetchDescriptor<VideoProcessingJob>(
                    sortBy: [SortDescriptor(\.createdAt, order: .forward)]
                )
                let allJobs = try modelContext.fetch(descriptor)
                let activeJobs = allJobs.filter { $0.status == .pending || $0.status == .processing }
                let queuePosition = activeJobs.firstIndex(where: { $0.id == job.id }) ?? 0
                let totalInQueue = activeJobs.count

                // Show success toast with queue position
                toastManager.success(
                    title: "Video \(queuePosition + 1) of \(totalInQueue)",
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

// MARK: - Source Option Row

struct SourceOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(HeirloomColors.buttonTextLight)
                .frame(width: 52, height: 52)
                .background(color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius))

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(HeirloomFonts.caption1)
        }
        .padding(HeirloomSpacing.md)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Video Picker

struct VideoPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Binding var isLoading: Bool
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

        // Save video data to persistent processing storage
        private func saveToProcessingStorage(_ data: Data) throws -> URL {
            // Create processing directory if needed
            let processingDir = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("VideoProcessing", isDirectory: true)

            try FileManager.default.createDirectory(at: processingDir, withIntermediateDirectories: true)

            // Create unique file path
            let destinationURL = processingDir
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")

            // Write video data
            try data.write(to: destinationURL)

            Log.info("Video saved to persistent storage", category: .video, metadata: [
                "path": destinationURL.path
            ])

            return destinationURL
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss picker immediately
            parent.dismiss()

            guard let result = results.first else { return }

            // Show loading indicator while video is being copied
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }

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
                        self.parent.isLoading = false
                        self.parent.onError(errorMsg)
                    }
                    return
                }

                // Write data to persistent processing directory
                do {
                    let persistentURL = try self.saveToProcessingStorage(data)
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
                        self.parent.selectedURL = persistentURL
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.parent.isLoading = false
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
                VStack(spacing: HeirloomSpacing.md) {
                    ProgressView()
                    Text(isInitializing ? "Initializing transcription..." : "Failed to initialize")
                        .font(HeirloomFonts.caption1)
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
        let aiService = ServiceContainer.shared.resolve((any AIServiceProtocol).self)
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
