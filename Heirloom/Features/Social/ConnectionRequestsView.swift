//
//  ConnectionRequestsView.swift
//  Heirloom
//
//  Social Layer Phase 6: Manage pending connection requests
//  Shows list of requests with accept/decline actions
//

import SwiftUI

struct ConnectionRequestsView: View {
    @Environment(\.dismiss) private var dismiss

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    // MARK: - State

    @State private var pendingRequests: [Connection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingRequestId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if pendingRequests.isEmpty {
                    emptyStateView
                } else {
                    requestsList
                }
            }
            .navigationTitle("Connection Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadRequests()
            }
        }
    }

    // MARK: - Requests List

    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.md) {
                ForEach(pendingRequests) { request in
                    ConnectionRequestCard(
                        request: request,
                        isProcessing: processingRequestId == request.id,
                        onAccept: {
                            await acceptRequest(request)
                        },
                        onDecline: {
                            await declineRequest(request)
                        }
                    )
                }
            }
            .padding(HeirloomSpacing.md)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.3))

            VStack(spacing: HeirloomSpacing.xs) {
                Text("No Pending Requests")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("You're all caught up!")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading requests...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)

            Text("Error Loading Requests")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Button("Try Again") {
                Task {
                    await loadRequests()
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.tomato)
        }
    }

    // MARK: - Data Loading

    private func loadRequests() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch only pending connections
            let pending = try await connectionService.fetchConnections(status: .pending, forceRefresh: false)

            // Filter to only INCOMING requests (where we are the recipient, not the sender)
            let incomingRequests = pending.filter { $0.isIncomingRequest }

            await MainActor.run {
                self.pendingRequests = incomingRequests
                self.isLoading = false
            }

            Log.info("Loaded \(incomingRequests.count) incoming requests (filtered from \(pending.count) total pending)", category: .social)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            Log.error("Failed to load requests", category: .social, error: error)
        }
    }

    // MARK: - Request Actions

    private func acceptRequest(_ request: Connection) async {
        processingRequestId = request.id

        do {
            try await connectionService.acceptRequest(connectionId: request.id)

            await MainActor.run {
                pendingRequests.removeAll { $0.id == request.id }
                processingRequestId = nil
                toastManager.success(title: "Request accepted")
            }

            Log.info("Accepted connection request", category: .social, metadata: [
                "connectionId": request.id
            ])
        } catch {
            await MainActor.run {
                processingRequestId = nil
                toastManager.error(title: "Failed to accept request")
            }
            Log.error("Failed to accept request", category: .social, error: error)
        }
    }

    private func declineRequest(_ request: Connection) async {
        processingRequestId = request.id

        do {
            try await connectionService.declineRequest(connectionId: request.id)

            await MainActor.run {
                pendingRequests.removeAll { $0.id == request.id }
                processingRequestId = nil
                toastManager.success(title: "Request declined")
            }

            Log.info("Declined connection request", category: .social, metadata: [
                "connectionId": request.id
            ])
        } catch {
            await MainActor.run {
                processingRequestId = nil
                toastManager.error(title: "Failed to decline request")
            }
            Log.error("Failed to decline request", category: .social, error: error)
        }
    }
}

#Preview {
    ConnectionRequestsView()
}
