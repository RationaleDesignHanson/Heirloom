//
//  InviteConnectionView.swift
//  Heirloom
//
//  Social Layer Phase 6: Invite connections via QR code or share link
//  Shows shareable profile link and QR code
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct InviteConnectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseAuth) private var firebaseAuth

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var qrCodeImage: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle("Invite Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.xl) {
                // Header
                VStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 60))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Invite to Kitchen Table")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Share your profile link or QR code to connect")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, HeirloomSpacing.xl)

                // QR Code
                if let qrImage = qrCodeImage {
                    VStack(spacing: HeirloomSpacing.md) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(HeirloomSpacing.md)
                            .background(.white)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                        Text("Scan to connect")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                // Share link
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Or share link")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    HStack {
                        Text(shareableLink)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            copyLink()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.tomato)
                        }
                    }
                    .padding(HeirloomSpacing.sm)
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, HeirloomSpacing.lg)

                // Share button
                ShareLink(
                    item: URL(string: shareableLink)!,
                    message: Text("Connect with me on Heirloom!")
                ) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Invite")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .padding(.horizontal, HeirloomSpacing.lg)

                // Instructions
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("How it works")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    instructionRow(
                        number: "1",
                        text: "Share your QR code or link"
                    )
                    instructionRow(
                        number: "2",
                        text: "They scan or tap to open Heirloom"
                    )
                    instructionRow(
                        number: "3",
                        text: "They send you a connection request"
                    )
                    instructionRow(
                        number: "4",
                        text: "Accept their request to start sharing recipes"
                    )
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
        }
    }

    private func instructionRow(number: String, text: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Text(number)
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(HeirloomColors.tomato)
                .clipShape(Circle())

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Generating invite...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Computed Properties

    private var shareableLink: String {
        guard let userId = firebaseAuth.currentUser?.uid else {
            return "heirloom://connect"
        }
        // Use custom URL scheme for immediate testing (no universal links needed)
        // Format: heirloom://connect/{userId}
        return "heirloom://connect/\(userId)"
    }

    // MARK: - Actions

    private func copyLink() {
        UIPasteboard.general.string = shareableLink
        // TODO: Show toast confirmation
        Log.info("Copied invite link to clipboard", category: .social)
    }

    // MARK: - Data Loading

    private func loadProfile() async {
        do {
            let profile = try await profileService.fetchCurrentUserProfile()
            let qrImage = generateQRCode(from: shareableLink)

            await MainActor.run {
                self.userProfile = profile
                self.qrCodeImage = qrImage
                self.isLoading = false
            }

            Log.info("Generated invite QR code", category: .social)
        } catch {
            // Even if profile load fails, show invite with userId
            let qrImage = generateQRCode(from: shareableLink)

            await MainActor.run {
                self.qrCodeImage = qrImage
                self.isLoading = false
            }

            Log.error("Failed to load profile for invite", category: .social, error: error)
        }
    }

    // MARK: - QR Code Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    InviteConnectionView()
}
