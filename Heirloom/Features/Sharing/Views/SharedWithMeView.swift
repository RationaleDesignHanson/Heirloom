//
//  SharedWithMeView.swift
//  Heirloom
//
//  Phase 1: Inter-Heirloom Recipe Sharing
//  Inbox view for recipes shared directly with the user
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SharedWithMeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.network) private var networkMonitor

    @State private var pendingShares: [[String: Any]] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedShare: [String: Any]?
    @State private var showReceiveSheet = false

    // Offline handling (local state for instant UI updates)
    @State private var isOffline = false

    private var firebaseShare: FirebaseShareService {
        ServiceContainer.shared.resolve(FirebaseShareService.self)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isOffline {
                    offlineView
                } else if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if pendingShares.isEmpty {
                    emptyStateView
                } else {
                    sharesList
                }
            }
            .navigationTitle("Shared With Me")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                isOffline = !networkMonitor.isConnected
                if !isOffline {
                    await loadShares()
                }
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                // Poll the NetworkMonitor's isConnected property for reliable UI updates
                let currentlyOffline = !networkMonitor.isConnected
                if isOffline != currentlyOffline {
                    let wasOffline = isOffline
                    isOffline = currentlyOffline
                    // Reload when coming back online
                    if wasOffline && !currentlyOffline {
                        Task {
                            await loadShares()
                        }
                    }
                }
            }
            .sheet(isPresented: $showReceiveSheet) {
                if let share = selectedShare,
                   let shareId = share["shareId"] as? String,
                   let shareURL = URL(string: "https://heirloom.page.link/share/\(shareId)") {
                    RecipeReceiveSheet(shareURL: shareURL, shareMetadata: share)
                        .onDisappear {
                            // Refresh shares after accepting/declining
                            Task {
                                await loadShares()
                            }
                        }
                }
            }
        }
    }

    // MARK: - Shares List

    private var sharesList: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.md) {
                ForEach(Array(pendingShares.enumerated()), id: \.offset) { index, share in
                    ShareInboxRow(share: share)
                        .onTapGesture {
                            selectedShare = share
                            showReceiveSheet = true
                        }
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.vertical, HeirloomSpacing.sm)
        }
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading shared recipes...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Error Loading Shares")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task {
                    await loadShares()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()

            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))

            Text("No Recipe Invites Yet")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            // Green banner with helpful message
            VStack(alignment: .leading, spacing: 4) {
                Text("Check back when you see the badge")
                    .font(HeirloomFonts.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("When friends share recipes with you, they'll appear here and you'll see a notification badge on Tables.")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(HeirloomColors.familyGreen)
                    .shadow(color: HeirloomColors.familyGreen.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, HeirloomSpacing.lg)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var offlineView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()

            Image(systemName: "wifi.slash")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))

            Text("You're Offline")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Connect to the internet to see recipes shared with you.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Data Loading

    private func loadShares() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            pendingShares = try await firebaseShare.fetchDirectSharesForUser(userId: userId)
            isLoading = false
            Log.info("Loaded direct shares", category: .firebase, metadata: ["count": pendingShares.count])
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            Log.error("Failed to load direct shares", category: .firebase, error: error)
        }
    }
}

// MARK: - Share Inbox Row

struct ShareInboxRow: View {
    let share: [String: Any]

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Sender avatar
            senderAvatar
                .frame(width: 55, height: 55)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
                )

            // Share info
            VStack(alignment: .leading, spacing: 6) {
                // Recipe title
                Text(recipeTitle)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                // From sender
                HStack(spacing: 4) {
                    Text("From")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                    Text(senderName)
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                // Timestamp
                Text(timeAgo)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Computed Properties

    private var recipeTitle: String {
        share["recipeTitle"] as? String ?? "Recipe"
    }

    private var senderName: String {
        share["ownerName"] as? String ?? "Someone"
    }

    private var senderPhotoURL: String? {
        share["ownerPhotoURL"] as? String
    }

    private var createdAt: Date {
        if let timestamp = share["createdAt"] as? FirebaseFirestore.Timestamp {
            return timestamp.dateValue()
        }
        return Date()
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    // MARK: - Sender Avatar

    @ViewBuilder
    private var senderAvatar: some View {
        if let photoURLString = senderPhotoURL,
           let url = URL(string: photoURLString) {
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
                        HeirloomColors.familyGreen.opacity(0.8),
                        HeirloomColors.familyGreen.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(initials)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = senderName
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

// MARK: - Preview

#Preview {
    SharedWithMeView()
}
