//
//  PublicProfileSheet.swift
//  Heirloom
//
//  Phase 10: Public Profile URLs
//  View for displaying public user profiles from deep links
//

import SwiftUI

struct PublicProfileSheet: View {
    let userId: String

    @Environment(\.dismiss) private var dismiss

    private var userProfileService: FirebaseUserProfileService {
        ServiceContainer.shared.resolve(FirebaseUserProfileService.self)
    }

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    @State private var displayName: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var connectionStatus: ConnectionStatus = .none

    enum ConnectionStatus {
        case none          // Not connected
        case pending       // Request sent
        case connected     // Already connected
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if let displayName = displayName {
                    profileContent(displayName)
                } else {
                    emptyView
                }
            }
            .navigationTitle("Profile")
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading profile...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Profile Content

    @ViewBuilder
    private func profileContent(_ displayName: String) -> some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.xl) {
                // Avatar & Basic Info
                VStack(spacing: HeirloomSpacing.md) {
                    // Avatar
                    placeholderAvatar

                    // Display Name
                    Text(displayName)
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .padding(.top, HeirloomSpacing.md)

                // Connect Button
                connectionButton
                    .padding(.horizontal, HeirloomSpacing.md)
            }
            .padding(.bottom, HeirloomSpacing.xl)
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Connection Button

    @ViewBuilder
    private var connectionButton: some View {
        switch connectionStatus {
        case .none:
            Button {
                Task {
                    await sendConnectionRequest()
                }
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Connect")
                }
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .cornerRadius(12)
            }

        case .pending:
            HStack {
                Image(systemName: "clock")
                Text("Request Pending")
            }
            .font(HeirloomFonts.body)
            .foregroundStyle(HeirloomColors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.warmGray.opacity(0.1))
            .cornerRadius(12)

        case .connected:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Connected")
            }
            .font(HeirloomFonts.body)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.warmGray.opacity(0.1))
            .cornerRadius(12)
        }
    }

    // MARK: - Placeholder Avatar

    private var placeholderAvatar: some View {
        Circle()
            .fill(HeirloomColors.warmGray.opacity(0.2))
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))
            )
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Error Loading Profile")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.lg)

            Button {
                Task {
                    await loadProfile()
                }
            } label: {
                Text("Try Again")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, HeirloomSpacing.lg)
                    .padding(.vertical, HeirloomSpacing.sm)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(8)
            }
        }
        .padding(HeirloomSpacing.lg)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "person.circle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("Profile Not Found")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("This profile may not be public or may not exist")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(HeirloomSpacing.lg)
    }

    // MARK: - Actions

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch public profile display name
            guard let name = try await userProfileService.fetchDisplayName(for: userId) else {
                throw NSError(domain: "PublicProfileSheet", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Profile not found"
                ])
            }

            // Check connection status
            let connectedConnections = try await connectionService.fetchConnections(status: .connected, forceRefresh: false)
            let pendingConnections = try await connectionService.fetchConnections(status: .pending, forceRefresh: false)

            let status: ConnectionStatus
            if connectedConnections.contains(where: { $0.connectedUserId == userId }) {
                status = .connected
            } else if pendingConnections.contains(where: { $0.connectedUserId == userId }) {
                status = .pending
            } else {
                status = .none
            }

            await MainActor.run {
                displayName = name
                connectionStatus = status
                isLoading = false
            }

            Log.info("Public profile loaded successfully", category: .social, metadata: ["userId": userId])
        } catch {
            Log.error("Failed to load public profile", category: .social, error: error)
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func sendConnectionRequest() async {
        guard let name = displayName else { return }

        do {
            _ = try await connectionService.sendConnectionRequest(
                to: userId,
                displayName: name,
                photoURL: nil,
                sourceKitchenTableId: nil
            )

            await MainActor.run {
                connectionStatus = .pending
                toastManager.success(title: "Connection request sent")
            }

            Log.info("Connection request sent from public profile", category: .social, metadata: ["userId": userId])
        } catch {
            Log.error("Failed to send connection request", category: .social, error: error)
            await MainActor.run {
                toastManager.error(title: "Failed to send request", message: error.localizedDescription)
            }
        }
    }
}
