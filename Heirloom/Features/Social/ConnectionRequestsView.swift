//
//  ConnectionRequestsView.swift
//  Heirloom
//
//  Social Layer Phase 6: Manage pending connection requests
//  Shows both inbound and outbound requests with accept/decline/cancel actions
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

    @State private var incomingRequests: [Connection] = []
    @State private var outgoingRequests: [Connection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var processingRequestId: String?

    private var hasAnyRequests: Bool {
        !incomingRequests.isEmpty || !outgoingRequests.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if !hasAnyRequests {
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
            LazyVStack(spacing: HeirloomSpacing.lg) {
                // Incoming requests section
                if !incomingRequests.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Received")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .padding(.horizontal, HeirloomSpacing.xs)

                        ForEach(incomingRequests) { request in
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
                }

                // Outgoing requests section
                if !outgoingRequests.isEmpty {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Sent")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .padding(.horizontal, HeirloomSpacing.xs)

                        ForEach(outgoingRequests) { request in
                            OutgoingRequestCard(
                                request: request,
                                isProcessing: processingRequestId == request.id,
                                onCancel: {
                                    await cancelRequest(request)
                                }
                            )
                        }
                    }
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
            // Fetch all pending connections
            let pending = try await connectionService.fetchConnections(status: .pending, forceRefresh: true)

            // Separate into incoming and outgoing
            let incoming = pending.filter { $0.isIncomingRequest }
            let outgoing = pending.filter { !$0.isIncomingRequest }

            await MainActor.run {
                self.incomingRequests = incoming
                self.outgoingRequests = outgoing
                self.isLoading = false
            }

            Log.info("Loaded connection requests", category: .social, metadata: [
                "incoming": incoming.count,
                "outgoing": outgoing.count
            ])
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
                incomingRequests.removeAll { $0.id == request.id }
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
                incomingRequests.removeAll { $0.id == request.id }
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

    private func cancelRequest(_ request: Connection) async {
        processingRequestId = request.id

        do {
            // Use removeConnection to cancel the outgoing request
            try await connectionService.removeConnection(connectionId: request.id)

            await MainActor.run {
                outgoingRequests.removeAll { $0.id == request.id }
                processingRequestId = nil
                toastManager.success(title: "Request cancelled")
            }

            Log.info("Cancelled outgoing connection request", category: .social, metadata: [
                "connectionId": request.id
            ])
        } catch {
            await MainActor.run {
                processingRequestId = nil
                toastManager.error(title: "Failed to cancel request")
            }
            Log.error("Failed to cancel request", category: .social, error: error)
        }
    }
}

// MARK: - Outgoing Request Card

struct OutgoingRequestCard: View {
    let request: Connection
    let isProcessing: Bool
    let onCancel: () async -> Void

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
            if let photoURL = request.connectedUserPhotoURL,
               let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    case .failure, .empty:
                        placeholderAvatar
                    @unknown default:
                        placeholderAvatar
                    }
                }
            } else {
                placeholderAvatar
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(request.connectedUserDisplayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Pending • Sent \(request.requestedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Cancel button
            Button {
                Task {
                    await onCancel()
                }
            } label: {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.secondaryText))
                } else {
                    Text("Cancel")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(HeirloomColors.warmGray.opacity(0.15))
                        .cornerRadius(8)
                }
            }
            .disabled(isProcessing)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: HeirloomColors.cardShadow, radius: 4, x: 0, y: 2)
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        HeirloomColors.warning.opacity(0.8),
                        HeirloomColors.warning.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(initials)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = request.connectedUserDisplayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[components.count - 1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else {
            return String(name.prefix(1)).uppercased()
        }
    }
}

#Preview {
    ConnectionRequestsView()
}
