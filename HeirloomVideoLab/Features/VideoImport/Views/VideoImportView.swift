//
//  VideoImportView.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Entry point for video recipe import

import SwiftUI
import PhotosUI

struct VideoImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideoURL: URL?
    @State private var showVideoPicker = false
    @State private var showProcessing = false
    @State private var processor = MockVideoRecipeProcessor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.waveform")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("Import from Video")
                        .font(.title.bold())

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
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showVideoPicker) {
                VideoPickerView(selectedURL: $selectedVideoURL)
            }
            .onChange(of: selectedVideoURL) { _, newURL in
                if newURL != nil {
                    showProcessing = true
                }
            }
            .fullScreenCover(isPresented: $showProcessing) {
                if let videoURL = selectedVideoURL {
                    VideoProcessingView(
                        processor: processor,
                        videoURL: videoURL
                    )
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
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .videos

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

            // Load video as file URL
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                guard let url = url else {
                    print("Failed to load video: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                // Copy to temp location (original URL is temporary)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)

                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    DispatchQueue.main.async {
                        self.parent.selectedURL = tempURL
                    }
                } catch {
                    print("Failed to copy video: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VideoImportView()
}
