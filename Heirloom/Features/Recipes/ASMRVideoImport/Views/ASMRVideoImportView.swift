//
//  ASMRVideoImportView.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI
import PhotosUI
import AVFoundation

/// Entry point for ASMR (silent video) recipe extraction
struct ASMRVideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @StateObject private var usageManager = ASMRUsageManager.shared
    @State private var jobManager = VideoProcessingJobManager()

    @State private var selectedVideoURL: URL?
    @State private var userCaption = ""
    @State private var showVideoPicker = false
    @State private var showPaywall = false
    @State private var showOnboarding = false
    @State private var videoThumbnail: UIImage?
    @State private var videoDuration: TimeInterval?

    @AppStorage("has_seen_asmr_onboarding") private var hasSeenOnboarding = false

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon and explanation
                    headerSection

                    // Usage badge (shows credits remaining)
                    ASMRUsageBadge()

                    // Video selection
                    if selectedVideoURL == nil {
                        videoSelectionButton
                    } else {
                        videoPreviewSection
                    }

                    // Caption input (required for context)
                    if selectedVideoURL != nil {
                        captionInputSection
                    }

                    Spacer(minLength: 24)

                    // Process button
                    if selectedVideoURL != nil {
                        processButton
                    }
                }
                .padding()
            }
            .navigationTitle("Silent Video Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Clear coordinator context on cancel
                        tabCoordinator.didCancelCreation()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showOnboarding = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .photosPicker(
                isPresented: $showVideoPicker,
                selection: Binding(
                    get: { nil },
                    set: { newValue in
                        if let item = newValue {
                            loadVideo(from: item)
                        }
                    }
                ),
                matching: .videos
            )
            .sheet(isPresented: $showOnboarding) {
                onboardingSheet
            }
            .sheet(isPresented: $showPaywall) {
                // TODO: Show subscription paywall
                Text("Upgrade to Pro for more extractions")
            }
            .onAppear {
                if !hasSeenOnboarding {
                    showOnboarding = true
                    hasSeenOnboarding = true
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 4) {
                Text("Silent Video Import")
                    .font(.title2.bold())

                // Mode indicator badge
                Text("Video without Instructions")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.purple)
                    .cornerRadius(12)
            }

            Text("Extract recipes from ASMR or cooking videos without narration")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Video Selection

    private var videoSelectionButton: some View {
        Button {
            showVideoPicker = true
        } label: {
            VStack(spacing: 16) {
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Select Video")
                    .font(.headline)

                Text("Choose an ASMR or silent cooking video from your library")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundStyle(.blue.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var videoPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Video")
                    .font(.headline)

                Spacer()

                Button {
                    selectedVideoURL = nil
                    userCaption = ""
                    videoThumbnail = nil
                    videoDuration = nil
                } label: {
                    Text("Change")
                        .font(.subheadline)
                }
            }

            HStack(spacing: 12) {
                // Video thumbnail
                if let thumbnail = videoThumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "video")
                                .foregroundStyle(.secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedVideoURL?.lastPathComponent ?? "Video")
                        .font(.subheadline)
                        .lineLimit(2)

                    if let duration = videoDuration {
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Caption Input

    private var captionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Video Description")
                    .font(.headline)

                Text("(Required)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Help us understand what's being cooked. This improves accuracy significantly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g., Making carbonara pasta", text: $userCaption, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        VStack(spacing: 12) {
            Button {
                processVideo()
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Extract Recipe")
                    Text("(5 credits)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProcess ? Color.blue : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!canProcess)

            if !canProcess && !userCaption.isEmpty && selectedVideoURL != nil {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("Insufficient credits. Upgrade to continue.")
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Onboarding Sheet

    private var onboardingSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)

                        Text("Vision-Based Recipe Extraction")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    infoCard(
                        icon: "video.slash",
                        title: "For Silent Videos",
                        description: "Perfect for ASMR cooking videos, technique-focused content, or any video without narration."
                    )

                    infoCard(
                        icon: "text.bubble",
                        title: "Description Required",
                        description: "A brief description helps our AI understand what's being cooked and improves accuracy."
                    )

                    infoCard(
                        icon: "sparkles",
                        title: "5-Pass AI Analysis",
                        description: "We analyze your video in 5 specialized passes: dish identification, ingredient detection, culinary inference, action recognition, and synthesis."
                    )

                    infoCard(
                        icon: "star.circle",
                        title: "Credit System",
                        description: "Each extraction uses 5 credits. Free users get 5 credits/month (1 extraction), Pro users get 20 credits/month (4 extractions)."
                    )

                    infoCard(
                        icon: "checkmark.seal",
                        title: "Always Verify",
                        description: "You'll have a chance to review and edit the extracted recipe before saving. Validation notes will highlight any uncertainties."
                    )
                }
                .padding()
            }
            .navigationTitle("How It Works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got It") {
                        showOnboarding = false
                    }
                }
            }
        }
    }

    private func infoCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func processVideo() {
        guard canProcess else {
            if !usageManager.canStartExtraction() {
                showPaywall = true
            }
            return
        }

        createJob()
    }

    private var canProcess: Bool {
        selectedVideoURL != nil &&
        !userCaption.isEmpty &&
        userCaption.count >= 5 &&
        usageManager.canStartExtraction()
    }

    private func createJob() {
        guard let videoURL = selectedVideoURL else { return }

        Task {
            do {
                // Create attribution
                let attribution = VideoSourceAttribution(
                    sourceURL: nil,  // ASMR videos from camera roll don't have source URLs
                    captionText: userCaption
                )

                // Create job
                let job = try jobManager.createJob(
                    videoURL: videoURL,
                    videoType: .asmr,
                    userCaption: userCaption,
                    videoDuration: videoDuration,
                    sourceAttribution: attribution,
                    context: modelContext
                )

                // Show success toast
                toastManager.success(
                    title: "Video added to queue (5 credits)",
                    message: "Processing will continue in the background"
                )

                // Notify coordinator
                tabCoordinator.didCreateRecipe()

                // Dismiss immediately
                dismiss()

                Log.info("ASMR video job created successfully", category: .video, metadata: [
                    "jobId": job.id.uuidString,
                    "videoType": "asmr"
                ])
            } catch {
                Log.error("Failed to create ASMR video job", category: .video, metadata: [
                    "error": error.localizedDescription
                ])
            }
        }
    }

    // MARK: - Helpers

    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            guard let movie = try? await item.loadTransferable(type: VideoTransferable.self) else {
                return
            }

            selectedVideoURL = movie.url

            // Extract thumbnail and duration
            let asset = AVAsset(url: movie.url)

            // Get duration
            if let duration = try? await asset.load(.duration) {
                videoDuration = CMTimeGetSeconds(duration)
            }

            // Generate thumbnail
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            if let cgImage = try? await generator.image(at: CMTime(seconds: 0, preferredTimescale: 600)).image {
                videoThumbnail = UIImage(cgImage: cgImage)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "imported_video_\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Preview

#Preview {
    ASMRVideoImportView()
}
