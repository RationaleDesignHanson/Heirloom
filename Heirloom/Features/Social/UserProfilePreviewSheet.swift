//
//  UserProfilePreviewSheet.swift
//  Heirloom
//
//  Phase 7: User Discovery
//  Preview user profile before sending connection request
//

import SwiftUI

struct UserProfilePreviewSheet: View {
    let user: UserSearchResult

    @Environment(\.dismiss) private var dismiss
    @State private var isSendingRequest = false

    // MARK: - Email Masking Helper

    private func maskEmail(_ email: String) -> String {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return email }

        let username = String(parts[0])
        let domain = String(parts[1])

        if username.count <= 2 {
            return "\(username.prefix(1))***@\(domain)"
        }

        let visibleCount = min(max(Int(Double(username.count) * 0.4), 1), 10)
        let finalVisibleCount: Int
        if visibleCount >= username.count - 1 {
            finalVisibleCount = max(username.count - 2, 1)
        } else {
            finalVisibleCount = visibleCount
        }

        let visiblePart = username.prefix(finalVisibleCount)
        return "\(visiblePart)***@\(domain)"
    }

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Avatar
                AsyncImage(url: user.photoURL.flatMap(URL.init)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.2))
                        .overlay(
                            Text(user.displayName.prefix(1).uppercased())
                                .font(.system(size: 48))
                                .foregroundStyle(HeirloomColors.tomato)
                        )
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())

                // Name
                Text(user.displayName)
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Masked email (for verification before connecting)
                if let email = user.email {
                    Text(maskEmail(email))
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText.opacity(0.8))
                }

                // Bio
                if let bio = user.bio {
                    Text(bio)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.xl)
                }

                Spacer()

                // Send Request Button
                Button {
                    Task {
                        await sendConnectionRequest()
                    }
                } label: {
                    HStack {
                        if isSendingRequest {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Send Connection Request")
                        }
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HeirloomSpacing.md)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .disabled(isSendingRequest)
                .padding(.horizontal, HeirloomSpacing.lg)

                Button("Cancel") {
                    dismiss()
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.bottom, HeirloomSpacing.xl)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sendConnectionRequest() async {
        isSendingRequest = true

        do {
            _ = try await connectionService.sendConnectionRequest(
                to: user.id,
                displayName: user.displayName,
                photoURL: user.photoURL,
                sourceKitchenTableId: nil
            )

            await MainActor.run {
                isSendingRequest = false
                dismiss()

                // Show toast after a brief delay to ensure sheet is dismissed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    toastManager.success(title: "Connection request sent")
                }
            }
        } catch let error as NSError {
            await MainActor.run {
                isSendingRequest = false

                let message: String
                if error.domain == "ConnectionService" {
                    switch error.code {
                    case 400: message = "Cannot connect to yourself"
                    case 409: message = "Connection already exists"
                    default: message = "Failed to send request"
                    }
                } else {
                    message = "Failed to send request"
                }

                toastManager.error(title: message)
            }
        }
    }
}
