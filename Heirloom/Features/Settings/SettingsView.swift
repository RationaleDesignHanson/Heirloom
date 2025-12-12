import SwiftUI
import SwiftData
import CloudKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]

    @State private var showClearDataConfirmation = false
    @State private var iCloudStatus: String = "Checking..."
    @State private var storageSize: String = "Calculating..."

    var body: some View {
        NavigationStack {
            List {
                // AI Features Section
                aiSection

                // iCloud Section
                iCloudSection

                // Data Management Section
                dataManagementSection

                // App Info Section
                appInfoSection

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
                aboutView
            } label: {
                Label("About Heirloom", systemImage: "info.circle")
            }
        } header: {
            Text("App Information")
        }
    }

    private var aboutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // App Icon and Name
                VStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Heirloom")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Recipes Worth Passing Down")
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, HeirloomSpacing.xl)

                Divider()

                // Mission
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Our Mission")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Heirloom helps you preserve and share family recipes. From Grandma's cookies to your own creations, keep your culinary legacy alive for future generations.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Divider()

                // Features
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Features")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    FeatureRow(icon: "icloud", title: "iCloud Sync", description: "Access recipes on all devices")
                    FeatureRow(icon: "cart", title: "Smart Shopping", description: "Organized by store layout")
                    FeatureRow(icon: "camera", title: "Photo Import", description: "Digitize family recipe cards")
                    FeatureRow(icon: "square.stack.3d.up", title: "Quantity Math", description: "Auto-combine ingredients")
                }

                Divider()

                // Credits
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Made with ❤️")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Heirloom is designed to bring families together through food and shared memories.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            Link(destination: URL(string: "mailto:support@heirloom.app")!) {
                Label("Contact Support", systemImage: "envelope")
            }

            Link(destination: URL(string: "https://heirloom.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://heirloom.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        } header: {
            Text("Support")
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
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
