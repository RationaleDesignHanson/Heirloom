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
