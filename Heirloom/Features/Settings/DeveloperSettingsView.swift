import SwiftUI
import SwiftData
#if DEBUG
import FirebaseCrashlytics
#endif

/// Developer settings organized into tappable subsections
struct DeveloperSettingsView: View {
    var body: some View {
        List {
            // Subscription Testing
            NavigationLink {
                SubscriptionTestingView()
            } label: {
                Label("Subscription Testing", systemImage: "crown.fill")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            // Debug Tools
            NavigationLink {
                DebugToolsView()
            } label: {
                Label("Debug Tools", systemImage: "ladybug.fill")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            // Screen Recording
            NavigationLink {
                ScreenRecordingSettingsView()
            } label: {
                Label("Screen Recording", systemImage: "record.circle")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            // Data Tools
            NavigationLink {
                DataToolsView()
            } label: {
                Label("Data Tools", systemImage: "cylinder.split.1x2.fill")
                    .foregroundStyle(HeirloomColors.primaryText)
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subscription Testing

struct SubscriptionTestingView: View {
    @State private var subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    var body: some View {
        List {
            Section {
                // Force Non-Premium Mode
                Toggle(isOn: Binding(
                    get: {
                        UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true
                    },
                    set: { newValue in
                        UserDefaults.standard.set(newValue, forKey: "debug_force_non_premium")
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Force Non-Premium Mode")
                        Text("Test progressive unlock (7 recipes/day)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }

                // Auto Premium
                Toggle(isOn: Binding(
                    get: { subscriptionManager.isAutoPremiumEnabled },
                    set: { enabled in
                        subscriptionManager.isAutoPremiumEnabled = enabled
                        if enabled {
                            toastManager.info(title: "Auto Premium Enabled", message: "Paywalls show but don't block")
                        } else {
                            toastManager.info(title: "Auto Premium Disabled", message: "Paywalls block normally")
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Auto Premium (Debug)")
                        Text("Show paywalls without blocking access")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.orange)

                // Fake Payments
                Toggle(isOn: Binding(
                    get: { ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled },
                    set: { enabled in
                        UserDefaults.standard.set(enabled, forKey: "debug_fake_payments_enabled")
                        Log.info("Fake payments: \(enabled ? "ENABLED" : "DISABLED")", category: .store)
                        if enabled {
                            toastManager.info(title: "Fake Payments Enabled", message: "Subscribe grants premium without payment")
                        } else {
                            toastManager.info(title: "Fake Payments Disabled", message: "Real StoreKit purchases used")
                        }
                    }
                )) {
                    VStack(alignment: .leading) {
                        Text("Fake Payments (Debug)")
                        Text("Grants premium without real transactions")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.purple)

                // Cancel Fake Subscription
                if subscriptionManager.isPremium && ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled {
                    Button(role: .destructive) {
                        cancelFakeSubscription()
                    } label: {
                        Label("Cancel Fake Subscription", systemImage: "xmark.circle.fill")
                    }
                }
            } header: {
                Text("Subscription Simulation")
            } footer: {
                Text("Test subscription flows without real payments. Build: \(BuildChannel.current.displayName)")
            }
        }
        .navigationTitle("Subscription Testing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func cancelFakeSubscription() {
        UserDefaults.standard.removeObject(forKey: "subscription_status")
        UserDefaults.standard.removeObject(forKey: "subscription_expiry_date")
        UserDefaults.standard.removeObject(forKey: "cached_product_id")

        let now = Date()
        let trialExpiry = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        UserDefaults.standard.set(now, forKey: "first_launch_date")
        UserDefaults.standard.set(trialExpiry, forKey: "trial_expiry_date")
        UserDefaults.standard.set("trial", forKey: "subscription_status")
        UserDefaults.standard.synchronize()

        Task {
            await subscriptionManager.refreshStatus(force: true)
        }

        toastManager.success(title: "Fake Subscription Cancelled", message: "Restored to 14-day trial")
        Log.info("Cancelled fake subscription, restored trial", category: .store)
    }
}

// MARK: - Debug Tools

struct DebugToolsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    DebugLogView()
                } label: {
                    Label("Debug Log", systemImage: "doc.text.magnifyingglass")
                }

                NavigationLink {
                    LogViewerView()
                } label: {
                    Label("Device Logs", systemImage: "doc.text.magnifyingglass")
                }

                NavigationLink {
                    TrialDebugView()
                } label: {
                    Label("Trial Debug", systemImage: "calendar.badge.clock")
                }

                NavigationLink {
                    CreditsTestView()
                } label: {
                    Label("Credits System Test", systemImage: "giftcard.fill")
                }

                NavigationLink {
                    FeatureFlagsDebugView()
                } label: {
                    Label("Feature Flags", systemImage: "flag.checkered")
                }
            } header: {
                Text("Diagnostics")
            }

            #if DEBUG
            Section {
                Button(role: .destructive) {
                    Crashlytics.crashlytics().log("User triggered test crash from Settings")
                    fatalError("Test crash for Crashlytics verification")
                } label: {
                    Label("Test Crash Reporting", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Crashlytics")
            } footer: {
                Text("Triggers a fatal crash to verify Crashlytics reporting.")
            }
            #endif
        }
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Screen Recording Settings

struct ScreenRecordingSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var resetService = ScreenRecordingResetService.shared
    @State private var showFirstTimeUserReset = false
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    var body: some View {
        List {
            Section {
                Toggle(isOn: $resetService.hideThemeCollections) {
                    VStack(alignment: .leading) {
                        Text("Hide Theme Collections")
                        Text("Hides heritage/discovery collections")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.purple)

                Toggle(isOn: $resetService.hideDemoSeedCollections) {
                    VStack(alignment: .leading) {
                        Text("Hide Demo Collections")
                        Text("Hides collections marked as demo seed")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.orange)
            } header: {
                Text("Collection Visibility")
            } footer: {
                Text("Hide specific collection types when recording app demos.")
            }

            Section {
                Button(role: .destructive) {
                    showFirstTimeUserReset = true
                } label: {
                    HStack {
                        Label("First Time User Reset", systemImage: "arrow.counterclockwise.circle.fill")
                        Spacer()
                        if resetService.isResetting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(resetService.isResetting)

                if resetService.isResetting {
                    Text(resetService.resetProgress)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.secondary)
                }

                if let verification = resetService.lastResetVerification {
                    HStack {
                        Image(systemName: verification.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(verification.success ? .green : .orange)
                        VStack(alignment: .leading) {
                            Text(verification.success ? "Reset Verified" : "Reset Issues")
                                .font(HeirloomFonts.caption1Bold)
                            Text(verification.summary)
                                .font(HeirloomFonts.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Clears all data and resets to fresh start. Theme recipes preserved.")
            }
        }
        .navigationTitle("Screen Recording")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset to First Time User",
            isPresented: $showFirstTimeUserReset,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                performFirstTimeUserReset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will:\n• Delete all recipes and collections\n• Clear cloud data and connections\n• Reset to first-time user experience")
        }
    }

    private func performFirstTimeUserReset() {
        Task {
            do {
                let verification = try await resetService.resetToFirstTimeUser(context: modelContext)
                if verification.success {
                    toastManager.success(title: "Reset Complete", message: "App reset to first-time user state")
                } else {
                    toastManager.warning(title: "Reset Completed with Issues", message: verification.errors.first ?? "Check verification details")
                }
            } catch {
                toastManager.error(title: "Reset Failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Data Tools

struct DataToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showClearCollectionsConfirmation = false
    @State private var showClearDemoDataConfirmation = false
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    var body: some View {
        List {
            // Demo Social Mode
            if DemoSocialGate.shared.isRemotelyAvailable {
                Section {
                    Toggle(isOn: Binding(
                        get: { !DemoSocialGate.shared.isLocallyDisabled },
                        set: { enabled in
                            DemoSocialGate.shared.setLocallyDisabled(!enabled)
                            if enabled {
                                toastManager.info(title: "Demo Mode Enabled", message: "Demo accounts appear and auto-accept")
                            } else {
                                toastManager.info(title: "Demo Mode Disabled", message: "Demo accounts hidden")
                            }
                            Log.info("Demo social mode: \(enabled ? "ENABLED" : "DISABLED")", category: .general)
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Demo Social Mode")
                            Text("Demo accounts auto-accept invites")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(HeirloomColors.familyGreen)
                } header: {
                    Text("Social Simulation")
                } footer: {
                    Text("Status: \(DemoSocialGate.shared.debugStatus)")
                }
            }

            Section {
                Button(role: .destructive) {
                    showClearDemoDataConfirmation = true
                } label: {
                    Label("Remove Demo Data", systemImage: "person.2.slash")
                }

                Button(role: .destructive) {
                    showClearCollectionsConfirmation = true
                } label: {
                    Label("Clear All Collections", systemImage: "folder.fill.badge.minus")
                }
            } header: {
                Text("Destructive Actions")
            } footer: {
                Text("Remove Demo Data clears demo connections and demo recipes. Clear Collections removes all collections but keeps recipes.")
            }
        }
        .navigationTitle("Data Tools")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Clear All Collections",
            isPresented: $showClearCollectionsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Collections", role: .destructive) {
                clearAllCollections()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all collections but keep your recipes. This cannot be undone.")
        }
        .confirmationDialog(
            "Remove Demo Data",
            isPresented: $showClearDemoDataConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Demo Data", role: .destructive) {
                clearDemoData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all demo connections and demo recipes (recipes received from demo users during onboarding). This cannot be undone.")
        }
    }

    private func clearAllCollections() {
        Task {
            await MainActor.run {
                do {
                    let descriptor = FetchDescriptor<RecipeCollection>()
                    let collections = try modelContext.fetch(descriptor)

                    Log.info("Clearing all collections", category: .general, metadata: ["count": collections.count])

                    for collection in collections {
                        modelContext.delete(collection)
                    }

                    try modelContext.save()

                    Log.info("All collections cleared successfully", category: .general)
                    toastManager.success(title: "Collections Cleared", message: "All \(collections.count) collections removed.")
                } catch {
                    Log.error("Failed to clear collections", category: .general, metadata: ["error": error.localizedDescription])
                    toastManager.error(title: "Clear Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func clearDemoData() {
        Task { @MainActor in
            var demoRecipesDeleted = 0
            var demoConnectionsDeleted = 0

            do {
                // 1. Delete demo recipes (recipes received from demo users)
                let recipeDescriptor = FetchDescriptor<Recipe>(
                    predicate: #Predicate<Recipe> { $0.isDemoRecipe == true }
                )
                let demoRecipes = try modelContext.fetch(recipeDescriptor)
                demoRecipesDeleted = demoRecipes.count

                Log.info("Deleting demo recipes", category: .general, metadata: ["count": demoRecipes.count])

                for recipe in demoRecipes {
                    modelContext.delete(recipe)
                }

                // 2. Delete demo connections from Firebase
                let connectionService = ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
                let connections = try await connectionService.fetchConnections(status: .connected, forceRefresh: true)
                for connection in connections {
                    if DemoSocialBehaviorService.isDemoUser(connection.connectedUserId) {
                        try await connectionService.removeConnection(connectionId: connection.id)
                        demoConnectionsDeleted += 1
                    }
                }

                try modelContext.save()

                // Reset demo social state
                UserDefaults.standard.removeObject(forKey: "demo_social_proactive_request_sent")

                Log.info("Demo data cleared successfully", category: .general, metadata: [
                    "recipesDeleted": demoRecipesDeleted,
                    "connectionsDeleted": demoConnectionsDeleted
                ])

                toastManager.success(
                    title: "Demo Data Removed",
                    message: "\(demoRecipesDeleted) recipe(s) and \(demoConnectionsDeleted) connection(s) deleted."
                )
            } catch {
                Log.error("Failed to clear demo data", category: .general, metadata: ["error": error.localizedDescription])
                toastManager.error(title: "Clear Failed", message: error.localizedDescription)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
    }
}
