//
//  ConnectionPickerView.swift
//  Heirloom
//
//  Phase 1: Inter-Heirloom Recipe Sharing
//  Multi-select connection picker for direct sharing
//

import SwiftUI
import SwiftData

struct ConnectionPickerView: View {
    @Binding var selectedConnectionIds: Set<String>
    @State private var connections: [Connection] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.sm)

            // Connection list
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if filteredConnections.isEmpty {
                emptyStateView
            } else {
                connectionsList
            }
        }
        .task {
            await loadConnections()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HeirloomColors.secondaryText)

            TextField("Search connections...", text: $searchText)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - Connections List

    private var connectionsList: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.sm) {
                ForEach(filteredConnections) { connection in
                    ConnectionPickerRow(
                        connection: connection,
                        isSelected: selectedConnectionIds.contains(connection.connectedUserId)
                    )
                    .onTapGesture {
                        toggleSelection(connection.connectedUserId)
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
            Text("Loading connections...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Error Loading Connections")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.5))

            if searchText.isEmpty {
                Text("No Connections Yet")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Connect with friends to share recipes directly")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Text("No Matching Connections")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Try a different search term")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var filteredConnections: [Connection] {
        let connected = connections.filter { $0.status == .connected }

        if searchText.isEmpty {
            return connected
        }

        return connected.filter { connection in
            connection.connectedUserDisplayName
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private func toggleSelection(_ userId: String) {
        if selectedConnectionIds.contains(userId) {
            selectedConnectionIds.remove(userId)
        } else {
            selectedConnectionIds.insert(userId)
        }
    }

    private func loadConnections() async {
        isLoading = true
        errorMessage = nil

        do {
            connections = try await connectionService.fetchConnections(
                status: .connected,
                forceRefresh: false
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            Log.error("Failed to load connections for picker", category: .social, error: error)
        }
    }
}

// MARK: - Connection Picker Row

struct ConnectionPickerRow: View {
    let connection: Connection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Avatar
            avatarView
                .frame(width: 45, height: 45)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
                )

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.connectedUserDisplayName)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "doc.text")
                        .font(.caption2)
                    Text("\(connection.recipesSharedCount) recipes shared")
                }
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()

            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? HeirloomColors.tomato : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if let photoURL = connection.connectedUserPhotoURL,
           let url = URL(string: photoURL) {
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
                Text(initials)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
            )
    }

    private var initials: String {
        let name = connection.connectedUserDisplayName
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
    @Previewable @State var selectedIds: Set<String> = []

    ConnectionPickerView(selectedConnectionIds: $selectedIds)
        .frame(height: 400)
        .padding()
        .background(HeirloomColors.appBackground)
}
