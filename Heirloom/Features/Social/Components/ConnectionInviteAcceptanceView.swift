//
//  ConnectionInviteAcceptanceView.swift
//  Heirloom
//
//  Social Layer Phase 6: Accept connection invite from deep link
//  Shows user info and allows accepting connection
//

import SwiftUI

struct ConnectionInviteAcceptanceView: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    // MARK: - State

    @State private var isSendingRequest = false

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(HeirloomColors.tomato)

                // Message
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Connection Invite")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Accept this invite to connect and start sharing recipes")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, HeirloomSpacing.xl)
                }

                Spacer()

                // Actions
                VStack(spacing: HeirloomSpacing.md) {
                    Button {
                        Task {
                            await acceptInvite()
                        }
                    } label: {
                        HStack {
                            if isSendingRequest {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Accept Invite")
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

                    Button("Not Now") {
                        dismiss()
                    }
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
            .navigationTitle("Accept Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func acceptInvite() async {
        Log.info("Accept invite tapped", category: .social, metadata: [
            "inviterUserId": userId
        ])

        isSendingRequest = true

        do {
            Log.debug("Calling connectionService.acceptConnectionInvite", category: .social)

            // Accept the connection invite (creates connected status immediately)
            let connection = try await connectionService.acceptConnectionInvite(
                from: userId,
                inviterDisplayName: "Connection" // Will be updated when profiles sync
            )

            await MainActor.run {
                isSendingRequest = false
                toastManager.success(title: "Connected!")
                dismiss()
            }

            Log.info("Connection invite accepted from deep link", category: .social, metadata: [
                "inviterUserId": userId,
                "connectionId": connection.id
            ])
        } catch let error as NSError {
            await MainActor.run {
                isSendingRequest = false

                // Show more specific error messages
                let errorMessage: String
                if error.domain == "ConnectionService" {
                    switch error.code {
                    case 400:
                        errorMessage = "Cannot connect to yourself"
                    case 409:
                        errorMessage = "Already connected"
                    case 403:
                        errorMessage = "Cannot accept invite"
                    case 401:
                        errorMessage = "Please sign in first"
                    default:
                        errorMessage = error.localizedDescription
                    }
                } else {
                    errorMessage = "Failed to accept invite"
                }

                toastManager.error(title: errorMessage)
            }

            Log.error("Failed to accept connection invite from deep link", category: .social, error: error, metadata: [
                "errorDomain": error.domain,
                "errorCode": "\(error.code)",
                "errorDescription": error.localizedDescription
            ])
        } catch {
            await MainActor.run {
                isSendingRequest = false
                toastManager.error(title: "Failed to accept invite")
            }

            Log.error("Failed to accept connection invite from deep link", category: .social, error: error)
        }
    }
}

#Preview {
    ConnectionInviteAcceptanceView(userId: "preview-user-id")
}
