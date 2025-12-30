import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]

    @State private var showClearDataConfirmation = false
    @State private var iCloudStatus: String = "Checking..."
    @State private var storageSize: String = "Calculating..."

    // Network monitoring
    private let networkMonitor = NetworkMonitor.shared
    private let syncCoordinator = CloudKitSyncCoordinator.shared

    // Developer testing states
    @State private var cloudKitTestResult: String = ""
    @State private var isTestingCloudKit = false
    @State private var manualOfflineMode = false

    var body: some View {
        NavigationStack {
            List {
                // AI Features Section
                aiSection

                // iCloud Section
                iCloudSection

                // Network & Sync Section
                networkSyncSection

                // User Experience Section
                userExperienceSection

                // Data Management Section
                dataManagementSection

                // App Info Section
                appInfoSection

                // Developer Section (for testing)
                developerSection

                // Support Section
                supportSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await checkiCloudStatus()
                await calculateStorageSize()
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(recipes.count) recipes. This cannot be undone.")
            }
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                HStack {
                    Image(systemName: "brain")
                        .foregroundStyle(HeirloomColors.tomato)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Features")
                        Text(AIConfiguration.shared.isConfigured(provider: .anthropic) ? "Configured" : "Not Set")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text("Configure AI-powered features like smart ingredient parsing and recipe enhancement.")
        }
    }

    // MARK: - iCloud Section

    private var iCloudSection: some View {
        Section {
            HStack {
                Image(systemName: "icloud")
                    .foregroundStyle(HeirloomColors.tomato)
                Text("iCloud Sync")
                Spacer()
                Text(iCloudStatus)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
            }

            NavigationLink {
                iCloudDetailView
            } label: {
                Label("Sync Details", systemImage: "info.circle")
            }

            NavigationLink {
                CloudKitDashboardView()
            } label: {
                Label("CloudKit Monitor", systemImage: "chart.xyaxis.line")
            }
        } header: {
            Text("Cloud Storage")
        } footer: {
            Text("Your recipes automatically sync across all your devices using iCloud.")
        }
    }

    private var iCloudDetailView: some View {
        List {
            Section {
                LabeledContent("Status", value: iCloudStatus)
                LabeledContent("Recipes Synced", value: "\(recipes.count)")
                LabeledContent("Storage Used", value: storageSize)
            } header: {
                Text("Sync Status")
            }

            Section {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("How iCloud Sync Works")
                        .font(HeirloomFonts.bodyBold)

                    Text("Heirloom uses iCloud to keep your recipes in sync across all your Apple devices. Changes made on one device automatically appear on your other devices.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text("Your recipe images are stored locally on each device to save iCloud storage.")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.top, HeirloomSpacing.xs)
                }
                .padding(.vertical, HeirloomSpacing.xs)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Network & Sync Section

    private var networkSyncSection: some View {
        Section {
            // Network Status
            HStack {
                Image(systemName: networkMonitor.isConnected ? "wifi" : "wifi.slash")
                    .foregroundStyle(networkMonitor.isConnected ? HeirloomColors.success : HeirloomColors.warmGray)
                Text("Network Status")
                Spacer()
                Text(networkMonitor.isConnected ? "Online" : "Offline")
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
            }

            // Sync Status
            HStack {
                Image(systemName: syncCoordinator.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                    .foregroundStyle(syncCoordinator.isSyncing ? HeirloomColors.amber : HeirloomColors.success)
                Text("Sync Status")
                Spacer()
                Text(syncCoordinator.isSyncing ? "Syncing..." : "Up to Date")
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
            }

            // Pending Operations
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(syncCoordinator.pendingOperations.isEmpty ? HeirloomColors.warmGray : HeirloomColors.tomato)
                Text("Pending Operations")
                Spacer()
                Text("\(syncCoordinator.pendingOperations.count)")
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
                    .padding(.horizontal, HeirloomSpacing.sm)
                    .padding(.vertical, 2)
                    .background(syncCoordinator.pendingOperations.isEmpty ? Color.clear : HeirloomColors.tomato.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Sync Issues Button (show if there's a recent error)
            if syncCoordinator.lastSyncError != nil {
                NavigationLink {
                    SyncIssuesView()
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(HeirloomColors.tomato)
                        Text("View Sync Issues")
                            .foregroundStyle(HeirloomColors.primaryText)
                        Spacer()
                        if let errorTime = syncCoordinator.lastErrorTime {
                            Text(timeAgo(from: errorTime))
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
                }
            }

            // Retry Button (only show if there are pending operations and we're online)
            if !syncCoordinator.pendingOperations.isEmpty && networkMonitor.isConnected {
                Button {
                    Task {
                        await syncCoordinator.processPendingOperations()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(HeirloomColors.tomato)
                        Text("Retry Sync Now")
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }
                .disabled(syncCoordinator.isSyncing)
            }

            // Manual Offline Mode Toggle (for testing)
            #if DEBUG
            Toggle(isOn: $manualOfflineMode) {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Manual Offline Mode")
                }
            }
            .onChange(of: manualOfflineMode) { _, newValue in
                if newValue {
                    networkMonitor.simulateOffline()
                } else {
                    networkMonitor.simulateOnline()
                }
            }
            #endif
        } header: {
            Text("Network & Sync")
        } footer: {
            if !networkMonitor.isConnected {
                Text("Your device is offline. Changes will sync automatically when connection is restored.")
            } else if !syncCoordinator.pendingOperations.isEmpty {
                Text("\(syncCoordinator.pendingOperations.count) operations queued from offline mode. Tap 'Retry Sync Now' to sync immediately.")
            } else {
                Text("Your recipes are syncing automatically when changes are made.")
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            LabeledContent("Recipes", value: "\(recipes.count)")
            LabeledContent("Storage Used", value: storageSize)

            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Clearing data will permanently delete all recipes from this device and iCloud.")
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)

            NavigationLink {
                WhatsNewView()
            } label: {
                HStack {
                    Label("What's New", systemImage: "sparkles")
                    Spacer()
                    Text("NEW")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(HeirloomColors.tomato)
                        )
                }
            }

            NavigationLink {
                AboutView()
            } label: {
                Label("About Heirloom", systemImage: "info.circle")
            }
        } header: {
            Text("App Information")
        }
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            // Debug Log Viewer - FILE-BASED LOGGING FOR DEVICE VISIBILITY
            NavigationLink {
                DebugLogView()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("View Debug Log")
                    Spacer()
                    Text("📁")
                        .font(.caption)
                }
            }

            // Test CloudKit Public Database
            Button {
                testCloudKitPublicDatabase()
            } label: {
                HStack {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Test: Create Public Record")
                    Spacer()
                    if isTestingCloudKit {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isTestingCloudKit)
            
            // Test CloudKit Query
            Button {
                testCloudKitQuery()
            } label: {
                HStack {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Test: Fetch Public Records")
                    Spacer()
                    if isTestingCloudKit {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isTestingCloudKit)
            
            // Test Offline Queue
            Button {
                testOfflineQueue()
            } label: {
                HStack {
                    Image(systemName: "airplane")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Test: Queue Offline Operation")
                    Spacer()
                }
            }
            
            // Process Pending Operations
            Button {
                processPendingOperations()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Process Pending Operations")
                    Spacer()
                    Text("\(CloudKitSyncCoordinator.shared.pendingOperations.count)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            
            // Result display
            if !cloudKitTestResult.isEmpty {
                Text(cloudKitTestResult)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(cloudKitTestResult.contains("✅") ? .green : (cloudKitTestResult.contains("❌") ? .red : HeirloomColors.secondaryText))
            }
        } header: {
            Text("Developer Testing")
        } footer: {
            Text("Test CloudKit sync infrastructure. Records appear in CloudKit Dashboard → Development → Data.")
        }
    }
    
    private func testCloudKitPublicDatabase() {
        isTestingCloudKit = true
        cloudKitTestResult = "Testing..."
        
        Task {
            let coordinator = CloudKitSyncCoordinator.shared
            
            // Create a test record
            let record = CKRecord(recordType: "ProvenanceAggregate")
            record["rootHash"] = "test-\(UUID().uuidString.prefix(8))"
            record["totalUsers"] = 1 as CKRecordValue
            record["totalCooks"] = 0 as CKRecordValue
            record["averageRating"] = 5.0 as CKRecordValue
            record["trendingScore"] = 1.0 as CKRecordValue
            record["lastUpdated"] = Date() as CKRecordValue
            
            do {
                try await coordinator.saveToPublic(record)
                await MainActor.run {
                    cloudKitTestResult = "✅ Record saved! Check CloudKit Dashboard."
                    isTestingCloudKit = false
                }
                print("✅ CloudKit Test: Record saved successfully!")
            } catch {
                await MainActor.run {
                    cloudKitTestResult = "❌ Error: \(error.localizedDescription)"
                    isTestingCloudKit = false
                }
                print("❌ CloudKit Test Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func testCloudKitQuery() {
        isTestingCloudKit = true
        cloudKitTestResult = "Fetching..."
        
        Task {
            let coordinator = CloudKitSyncCoordinator.shared
            
            do {
                let records = try await coordinator.queryPublic(recordType: "ProvenanceAggregate")
                await MainActor.run {
                    cloudKitTestResult = "✅ Fetched \(records.count) records"
                    isTestingCloudKit = false
                }
                print("✅ CloudKit Test: Fetched \(records.count) records")
                for record in records {
                    print("  - rootHash: \(record["rootHash"] as? String ?? "nil")")
                }
            } catch {
                await MainActor.run {
                    cloudKitTestResult = "❌ Error: \(error.localizedDescription)"
                    isTestingCloudKit = false
                }
                print("❌ CloudKit Test Error: \(error.localizedDescription)")
            }
        }
    }
    
    private func testOfflineQueue() {
        let coordinator = CloudKitSyncCoordinator.shared
        
        // Create a test record
        let record = CKRecord(recordType: "ProvenanceAggregate")
        record["rootHash"] = "queued-\(UUID().uuidString.prefix(8))"
        record["totalUsers"] = 1 as CKRecordValue
        record["totalCooks"] = 0 as CKRecordValue
        record["averageRating"] = 5.0 as CKRecordValue
        record["trendingScore"] = 1.0 as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue
        
        // Queue it (simulating offline behavior)
        coordinator.queueOperation(type: .create, record: record)
        
        cloudKitTestResult = "📋 Queued! Pending: \(coordinator.pendingOperations.count)"
        print("📋 Queued operation. Pending count: \(coordinator.pendingOperations.count)")
    }
    
    private func processPendingOperations() {
        cloudKitTestResult = "Processing..."
        
        Task {
            let coordinator = CloudKitSyncCoordinator.shared
            await coordinator.processPendingOperations()
            
            await MainActor.run {
                let remaining = coordinator.pendingOperations.count
                if remaining == 0 {
                    cloudKitTestResult = "✅ All operations processed!"
                } else {
                    cloudKitTestResult = "⚠️ \(remaining) operations remaining"
                }
            }
            print("✅ Processed pending operations. Remaining: \(coordinator.pendingOperations.count)")
        }
    }

    // MARK: - User Experience Section

    private var userExperienceSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "cardFlipHapticsEnabled") },
                set: { UserDefaults.standard.set($0, forKey: "cardFlipHapticsEnabled") }
            )) {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Card Flip Haptics")
                }
            }

            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "cardFlipSoundEnabled") },
                set: { UserDefaults.standard.set($0, forKey: "cardFlipSoundEnabled") }
            )) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Card Flip Sound")
                }
            }
        } header: {
            Text("User Experience")
        } footer: {
            Text("Customize haptic feedback and sounds for card interactions.")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                Label("Help Center", systemImage: "questionmark.circle")
            }

            Button {
                AnalyticsService.shared.track(event: .contactSupportTapped, properties: nil)
                if let url = URL(string: "mailto:support@heirloom.app") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Contact Support", systemImage: "envelope")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                let deviceModel = UIDevice.current.model
                let systemVersion = UIDevice.current.systemVersion

                let subject = "Bug Report - Heirloom v\(appVersion)"
                let body = """


                ---
                Please describe the bug above this line.

                App Version: \(appVersion) (\(buildNumber))
                Device: \(deviceModel)
                iOS Version: \(systemVersion)
                """

                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                AnalyticsService.shared.track(event: .bugReportSubmitted, properties: [
                    "app_version": appVersion,
                    "device_model": deviceModel,
                    "ios_version": systemVersion
                ])

                if let url = URL(string: "mailto:support@heirloom.app?subject=\(encodedSubject)&body=\(encodedBody)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Report a Bug", systemImage: "ladybug")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                let subject = "Feature Request - Heirloom"
                let body = """


                ---
                Please describe your feature request above this line.
                """

                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                AnalyticsService.shared.track(event: .featureRequestSubmitted, properties: nil)

                if let url = URL(string: "mailto:support@heirloom.app?subject=\(encodedSubject)&body=\(encodedBody)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Request a Feature", systemImage: "lightbulb")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Link(destination: URL(string: "https://heirloom.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://heirloom.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        } header: {
            Text("Help & Support")
        } footer: {
            Text("Need help? Browse our Help Center, report bugs, or suggest new features to make Heirloom better.")
        }
    }

    // MARK: - Actions

    private func checkiCloudStatus() async {
        let container = CKContainer.default()

        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                switch status {
                case .available:
                    iCloudStatus = "Active"
                case .noAccount:
                    iCloudStatus = "Not Signed In"
                case .restricted:
                    iCloudStatus = "Restricted"
                case .couldNotDetermine:
                    iCloudStatus = "Unknown"
                case .temporarilyUnavailable:
                    iCloudStatus = "Temporarily Unavailable"
                @unknown default:
                    iCloudStatus = "Unknown"
                }
            }
        } catch {
            await MainActor.run {
                iCloudStatus = "Error"
            }
        }
    }

    private func calculateStorageSize() async {
        // Calculate storage from image files
        let imageService = ImageStorageService.shared
        let totalSize = await imageService.calculateTotalStorageSize()

        await MainActor.run {
            storageSize = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        }
    }

    private func clearAllData() {
        // Delete all recipes (cascade deletes ingredients)
        for recipe in recipes {
            modelContext.delete(recipe)
        }

        do {
            try modelContext.save()

            // Clean up images
            Task {
                await ImageStorageService.shared.performCleanup()
            }

            ToastManager.shared.success(title: "Data cleared")
            AnalyticsService.shared.track(event: .dataCleared, properties: [
                "recipe_count": recipes.count
            ])
        } catch {
            ToastManager.shared.error(title: "Failed to clear data", message: error.localizedDescription)
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
