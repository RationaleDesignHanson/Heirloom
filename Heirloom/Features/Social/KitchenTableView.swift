//
//  KitchenTableView.swift
//  Heirloom
//
//  Social Layer Phase 6: Kitchen Table view for managing connections
//  Shows connections list with filtering, search, and request management
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct KitchenTableView: View {
    @Environment(\.dismiss) private var dismiss

    private var connectionService: ConnectionServiceProtocol {
        ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
    }

    private var profileService: ProfileServiceProtocol {
        ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
    }

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    // MARK: - State

    @State private var profile: UserProfile?
    @State private var connections: [Connection] = []
    @State private var pendingRequests: [Connection] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedFilter: ConnectionFilter = .all
    @ObservedObject private var badgeService = ServiceContainer.shared.resolve(BadgeService.self)

    // Navigation
    @State private var showConnectionRequests = false
    @State private var showInviteView = false
    @State private var showUserSearch = false
    @State private var selectedConnection: Connection?
    @State private var showEditProfile = false

    // Phase 1: Inter-Heirloom Sharing
    @State private var pendingSharesCount: Int = 0
    @State private var showSharedWithMe = false
    @State private var showShareAnalytics = false
    @State private var showSettings = false

    // Real-time listener
    @State private var connectionsListener: ListenerRegistration?

    // Share counts for profile header
    @State private var directSharesCount: Int = 0
    @State private var publicSharesCount: Int = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    contentView
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Table")
                        .font(HeirloomFonts.title2)
                        .fontWeight(.semibold)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await loadConnections(forceRefresh: true)
                            }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)

                        Button {
                            showUserSearch = true
                        } label: {
                            Label("Search Users", systemImage: "magnifyingglass")
                        }

                        Button {
                            showInviteView = true
                        } label: {
                            Label("Invite Connection", systemImage: "person.badge.plus")
                        }

                        Button {
                            showShareAnalytics = true
                        } label: {
                            Label("Analytics", systemImage: "chart.bar")
                        }

                        Divider()

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showConnectionRequests) {
                ConnectionRequestsView()
            }
            .sheet(isPresented: $showInviteView) {
                InviteConnectionView()
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
            .sheet(item: $selectedConnection) { connection in
                ContributorProfileSheet(connection: connection)
            }
            .sheet(isPresented: $showSharedWithMe) {
                SharedWithMeView()
                    .onDisappear {
                        // Refresh pending shares count after closing
                        Task {
                            await loadPendingSharesCount()
                        }
                    }
            }
            .sheet(isPresented: $showShareAnalytics) {
                ShareAnalyticsDashboard()
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let unwrappedProfile = Binding($profile) {
                    EditProfileView(profile: unwrappedProfile)
                        .onDisappear {
                            Task {
                                await loadProfile()
                            }
                        }
                }
            }
            .task {
                await loadProfile()
                await loadPendingSharesCount()
                await loadShareCounts()
                setupConnectionsListener()
            }
            .onDisappear {
                cleanupConnectionsListener()
            }
            .refreshable {
                await loadConnections(forceRefresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Listener will automatically update when app returns to foreground
                // Just refresh pending shares count
                Task {
                    await loadPendingSharesCount()
                }
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Profile Header
                ProfileHeaderView(
                    profile: profile,
                    connectionsCount: connections.count,
                    directSharesCount: directSharesCount,
                    publicSharesCount: publicSharesCount,
                    onEditProfile: { showEditProfile = true }
                )
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.top, HeirloomSpacing.sm)

                VStack(spacing: 0) {
                    // Pending shares banner (Phase 1: Inter-Heirloom Sharing)
                    if pendingSharesCount > 0 {
                        pendingSharesBanner
                    }

                    // Pending requests banner (Phase 9: Badge System)
                    if badgeService.pendingRequestCount > 0 {
                        pendingRequestsBanner
                    }

                    // Search bar
                    searchBar

                    // Filter tabs
                    filterTabs

                    // Connections list
                    if filteredConnections.isEmpty {
                        emptyStateView
                    } else {
                        connectionsList
                    }
                }
            }
        }
    }

    // MARK: - Pending Shares Banner (Phase 1: Inter-Heirloom Sharing)

    private var pendingSharesBanner: some View {
        Button {
            showSharedWithMe = true
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "tray.full")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recipes Shared With You")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)

                    Text("\(pendingSharesCount) pending")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Badge
                Text("\(pendingSharesCount)")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.familyGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white)
                    .cornerRadius(12)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.familyGreen)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.top, HeirloomSpacing.sm)
    }

    // MARK: - Pending Requests Banner

    private var pendingRequestsBanner: some View {
        Button {
            showConnectionRequests = true
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "person.2.badge.gearshape")
                    .font(.title3)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection Requests")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)

                    Text("\(badgeService.pendingRequestCount) pending")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                // Badge
                Text("\(badgeService.pendingRequestCount)")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.tomato)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white)
                    .cornerRadius(12)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.top, HeirloomSpacing.sm)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(HeirloomColors.secondaryText)

            TextField("Search connections", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.warmGray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal, HeirloomSpacing.md)
        .padding(.vertical, HeirloomSpacing.sm)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HeirloomSpacing.sm) {
                ForEach(ConnectionFilter.allCases, id: \.self) { filter in
                    filterTab(filter)
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
        }
        .padding(.bottom, HeirloomSpacing.sm)
    }

    private func filterTab(_ filter: ConnectionFilter) -> some View {
        Button {
            selectedFilter = filter
        } label: {
            Text(filter.displayName)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(selectedFilter == filter ? .white : HeirloomColors.primaryText)
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.xs)
                .background(selectedFilter == filter ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.1))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connections List

    private var connectionsList: some View {
        ScrollView {
            LazyVStack(spacing: HeirloomSpacing.sm) {
                ForEach(groupedConnections.keys.sorted(), id: \.self) { letter in
                    if let letterConnections = groupedConnections[letter], !letterConnections.isEmpty {
                        Section {
                            ForEach(letterConnections) { connection in
                                ConnectionRow(connection: connection)
                                    .onTapGesture {
                                        selectedConnection = connection
                                    }
                            }
                        } header: {
                            HStack {
                                Text(letter)
                                    .font(HeirloomFonts.caption1Bold)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                                    .textCase(.uppercase)

                                Spacer()

                                Text("\(letterConnections.count)")
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                            .padding(.horizontal, HeirloomSpacing.md)
                            .padding(.top, HeirloomSpacing.md)
                            .padding(.bottom, HeirloomSpacing.xs)
                        }
                    }
                }
            }
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.bottom, HeirloomSpacing.xl)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            Spacer()

            Image(systemName: "person.2")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.warmGray.opacity(0.3))

            VStack(spacing: HeirloomSpacing.xs) {
                Text("No Connections Yet")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Start building your cooking network by inviting friends and family")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, HeirloomSpacing.xl)
            }

            Button {
                showInviteView = true
            } label: {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Invite Someone")
                }
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(.white)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.vertical, HeirloomSpacing.md)
                .background(HeirloomColors.tomato)
                .cornerRadius(12)
            }

            Spacer()
        }
    }

    // MARK: - Loading & Error Views

    private var loadingView: some View {
        VStack(spacing: HeirloomSpacing.md) {
            ProgressView()
            Text("Loading connections...")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(HeirloomColors.warmGray)

            Text("Error Loading Connections")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HeirloomSpacing.xl)

            Button("Try Again") {
                Task {
                    await loadConnections()
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.tomato)
        }
    }

    // MARK: - Data Loading

    private func loadConnections(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            // Load all connections (bypass cache if force refresh)
            let allConnections = try await connectionService.fetchConnections(status: nil, forceRefresh: forceRefresh)

            // Filter connected vs pending
            let (connected, pending) = allConnections.partition { $0.status == .connected }

            await MainActor.run {
                self.connections = connected
                self.pendingRequests = pending
                self.isLoading = false
            }

            Log.info("Loaded \(connected.count) connections and \(pending.count) pending requests", category: .social)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            Log.error("Failed to load connections", category: .social, error: error)
        }
    }

    /// Load count of pending direct shares (Phase 1: Inter-Heirloom Sharing)
    private func loadPendingSharesCount() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            return
        }

        do {
            let firebaseShare = ServiceContainer.shared.resolve(FirebaseShareService.self)
            let shares = try await firebaseShare.fetchDirectSharesForUser(userId: userId)

            await MainActor.run {
                self.pendingSharesCount = shares.count
            }

            Log.info("Loaded pending shares count", category: .social, metadata: ["count": shares.count])
        } catch {
            Log.error("Failed to load pending shares count", category: .social, error: error)
            // Don't show error to user - just log it
        }
    }

    /// Load current user's profile
    private func loadProfile() async {
        do {
            let userProfile = try await profileService.fetchCurrentUserProfile()
            await MainActor.run {
                self.profile = userProfile
            }
            Log.info("Loaded user profile for Kitchen Table", category: .social)
        } catch {
            Log.error("Failed to load user profile for Kitchen Table", category: .social, error: error)
            // Don't show error to user - profile header will show placeholder
        }
    }

    /// Load share counts for profile header
    private func loadShareCounts() async {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            return
        }

        do {
            let db = Firestore.firestore()

            // Count direct shares (recipes shared to friends via shares collection)
            let directSharesSnapshot = try await db.collection("shares")
                .whereField("ownerId", isEqualTo: userId)
                .whereField("isDirectShare", isEqualTo: true)
                .getDocuments()

            // Count public recipes
            let publicRecipesSnapshot = try await db.collection("publicRecipes")
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()

            await MainActor.run {
                self.directSharesCount = directSharesSnapshot.documents.count
                self.publicSharesCount = publicRecipesSnapshot.documents.count
            }

            Log.info("Loaded share counts", category: .social, metadata: [
                "directShares": directSharesSnapshot.documents.count,
                "publicShares": publicRecipesSnapshot.documents.count
            ])
        } catch {
            Log.error("Failed to load share counts", category: .social, error: error)
            // Don't show error to user - just log it
        }
    }

    private func setupConnectionsListener() {
        // Clean up any existing listener first
        cleanupConnectionsListener()

        // Set up real-time listener for all connections
        connectionsListener = connectionService.observeConnections(status: nil) { allConnections in
            Task { @MainActor in
                // Separate pending requests from connected
                self.pendingRequests = allConnections.filter { $0.status == .pending }
                self.connections = allConnections.filter { $0.status == .connected }

                self.isLoading = false

                Log.info("Loaded \(self.connections.count) connections and \(self.pendingRequests.count) pending requests", category: .social)
            }
        }

        Log.debug("Set up connections real-time listener", category: .social)
    }

    private func cleanupConnectionsListener() {
        connectionsListener?.remove()
        connectionsListener = nil
        Log.debug("Removed connections real-time listener", category: .social)
    }

    // MARK: - Computed Properties

    private var filteredConnections: [Connection] {
        var filtered = connections.filter { $0.status == .connected }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { connection in
                connection.connectedUserDisplayName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply favorite filter if selected
        if selectedFilter == .favorites {
            filtered = filtered.filter { $0.isFavorite }
        }

        return filtered
    }

    private var groupedConnections: [String: [Connection]] {
        // Group by first letter of name
        Dictionary(grouping: filteredConnections) { connection in
            String(connection.connectedUserDisplayName.prefix(1)).uppercased()
        }
    }
}

// MARK: - Connection Filter

enum ConnectionFilter: String, CaseIterable {
    case all
    case favorites

    var displayName: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        }
    }
}

// MARK: - Array Extension

extension Array {
    func partition(where predicate: (Element) -> Bool) -> ([Element], [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []

        for element in self {
            if predicate(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }

        return (matching, nonMatching)
    }
}

#Preview {
    KitchenTableView()
}
