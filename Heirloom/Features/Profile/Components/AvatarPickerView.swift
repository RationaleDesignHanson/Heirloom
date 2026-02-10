//
//  AvatarPickerView.swift
//  Heirloom
//
//  Social Layer Phase 5: Avatar picker component
//  Allows user to select and upload profile photo
//

import SwiftUI
import PhotosUI

struct AvatarPickerView: View {
    let currentPhotoURL: String?
    let onPhotoSelected: (UIImage) -> Void

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessingImage = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        VStack(spacing: HeirloomSpacing.md) {
            // Avatar preview
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 2)
                    )

                // Edit button overlay
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack {
                        Circle()
                            .fill(HeirloomColors.tomato)
                            .frame(width: 36, height: 36)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task {
                        await loadPhoto(from: newItem)
                    }
                }
            }

            if isProcessingImage {
                ProgressView("Uploading...")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Avatar Image

    @ViewBuilder
    private var avatarImage: some View {
        if let photoURL = currentPhotoURL, let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    placeholderAvatar
                @unknown default:
                    placeholderAvatar
                }
            }
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.tomato.opacity(0.8),
                        HeirloomColors.tomato.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    // MARK: - Photo Loading

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        isProcessingImage = true
        defer { isProcessingImage = false }

        // Retry logic for transient Photos library errors (e.g., helper process unavailable)
        var lastError: Error?
        let maxAttempts = 2

        for attempt in 1...maxAttempts {
            do {
                // Load the image data
                guard let data = try await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else {
                    errorMessage = "Failed to load image"
                    showError = true
                    return
                }

                // Validate image size (max 10MB)
                if data.count > 10 * 1024 * 1024 {
                    errorMessage = "Image too large. Please select an image under 10MB."
                    showError = true
                    return
                }

                await MainActor.run {
                    onPhotoSelected(uiImage)
                }
                return
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }

        if let lastError {
            errorMessage = "Failed to process image: \(lastError.localizedDescription)"
            showError = true
        }
    }
}

#Preview {
    VStack(spacing: HeirloomSpacing.xl) {
        AvatarPickerView(
            currentPhotoURL: nil,
            onPhotoSelected: { _ in }
        )

        AvatarPickerView(
            currentPhotoURL: "https://example.com/photo.jpg",
            onPhotoSelected: { _ in }
        )
    }
    .padding()
    .background(HeirloomColors.appBackground)
}
