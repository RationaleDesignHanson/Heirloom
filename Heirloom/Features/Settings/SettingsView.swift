import SwiftUI
import SwiftData
import StoreKit
import FirebaseFirestore
import FirebaseStorage

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @Query private var recipes: [Recipe]

    // Services resolved at view initialization - prevents lazy evaluation crashes
    @State private var imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)
    @State private var analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
    @State private var backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
    @State private var aiConfig = ServiceContainer.shared.resolve(AIConfiguration.self)
    @State private var firebaseSyncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
    @State private var subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
    @State private var storeManager = ServiceContainer.shared.resolve(StoreManager.self)
    @State private var recipeExporter = ServiceContainer.shared.resolve(RecipeExporter.self)

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var storageSize: String = "Calculating..."
    @State private var showHeritageCleanup = false
    @State private var authStateChanged = false // Force view updates when auth state changes
    @State private var isClearingData = false // Show loading indicator while clearing
    @State private var isExporting = false
    @State private var isRestoringPurchases = false
    @State private var showDowngradeAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                subscriptionSection

                // AI Features Section
                aiSection

                // User Experience Section
                userExperienceSection

                // Data Management Section
                dataManagementSection

                // Heritage Collections Section
                heritageCollectionsSection

                // Account Section
                accountSection

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
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your recipes.")
            }
            .alert(
                "Switch to Monthly Plan",
                isPresented: $showDowngradeAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    openManageSubscription()
                }
            } message: {
                Text("To switch from Annual to Monthly, you'll need to manage your subscription in iOS Settings. Your Annual subscription will remain active until it expires, then you can subscribe to Monthly.")
            }
            .sheet(isPresented: $showSignIn) {
                FirebaseSignInView()
            }
            .sheet(isPresented: $showHeritageCleanup) {
                HeritageRecipeCleanupView()
            }
            .onChange(of: firebaseAuth.isAuthenticated) { _, _ in
                // Toggle state to force view refresh when auth state changes
                authStateChanged.toggle()
            }
            .onChange(of: firebaseAuth.currentUser?.uid) { _, _ in
                // Also watch for user changes (different account sign-in)
                authStateChanged.toggle()
            }
            .overlay {
                if isClearingData {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Clearing data...")
                                .foregroundColor(.white)
                                .font(HeirloomFonts.bodyBold)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.2))
                        )
                    }
                }
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
                        Text(aiConfig.isConfigured(provider: .anthropic) ? "Configured" : "Not Set")
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

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            // Status row
            LabeledContent("Status", value: subscriptionStatusText)
                .foregroundStyle(subscriptionStatusColor)

            // Current plan row (if subscribed)
            if subscriptionManager.isPremium, let planName = subscriptionManager.currentPlanName {
                LabeledContent("Current Plan", value: planName)
                    .font(HeirloomFonts.body)
            }

            // Renewal/Expiry date row (if applicable)
            if let dateText = subscriptionDateText {
                LabeledContent(subscriptionDateLabel, value: dateText)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Change Plan button (for subscribers who can upgrade/downgrade)
            if subscriptionManager.isPremium && subscriptionManager.status != .lifetime {
                if subscriptionManager.canUpgrade {
                    NavigationLink {
                        PaywallView()
                    } label: {
                        HStack {
                            Label("Upgrade to Annual", systemImage: "arrow.up.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Text("Save 50%")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                } else if subscriptionManager.canDowngrade {
                    Button {
                        showDowngradeAlert = true
                    } label: {
                        Label("Switch to Monthly", systemImage: "arrow.down.circle")
                            .foregroundStyle(HeirloomColors.primaryText)
                    }
                }

                Divider()

                // Manage Subscription button (cancel, etc.)
                Button {
                    openManageSubscription()
                } label: {
                    Label("Manage Subscription", systemImage: "gearshape")
                }
            }

            // Upgrade button (for free users)
            if !subscriptionManager.isPremium {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    // Trial countdown badge
                    if subscriptionManager.isInTrial, let daysRemaining = subscriptionManager.daysRemaining {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in trial")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.orange)

                            Spacer()
                        }
                        .padding(HeirloomSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange.opacity(0.1))
                        )
                    }

                    NavigationLink {
                        PaywallView()
                    } label: {
                        Label("Upgrade to Premium", systemImage: "crown.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }

            // Restore Purchases button
            Button {
                restorePurchases()
            } label: {
                if isRestoringPurchases {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Restoring...")
                    }
                } else {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
            .disabled(isRestoringPurchases)

        } header: {
            Text("Subscription")
        } footer: {
            Text(subscriptionFooterText)
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            LabeledContent("Recipes", value: "\(recipes.count)")
            LabeledContent("Storage Used", value: storageSize)

            Button {
                exportRecipes()
            } label: {
                if isExporting {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Exporting...")
                    }
                } else {
                    Label("Export All Recipes", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isExporting || recipes.isEmpty)

            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Export your recipes as JSON. Your recipes are always yours, even without a subscription.")
        }
    }

    // MARK: - Heritage Collections Section

    private var heritageCollectionsSection: some View {
        Section {
            let heritageCount = recipes.filter { $0.isHeritageRecipe }.count
            let heritageCollections = recipes.filter { $0.isHeritageRecipe }
                .compactMap { $0.heritageCollectionId }
                .reduce(into: Set<String>()) { $0.insert($1) }
                .count

            // Status Display
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Heritage Recipes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(heritageCount) recipes")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                if heritageCount > 0 {
                    HStack {
                        Text("Collections")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(heritageCollections) unlocked")
                            .font(.subheadline.bold())
                            .foregroundStyle(.brown)
                    }
                }
            }
            .padding(.vertical, 4)

            // Download Heritage Button
            Button {
                // Navigate to Collections tab to download Heritage collections
                Log.info("Navigating to Collections tab to download Heritage recipes", category: .heritage)
                tabCoordinator.selectedTab = TabNavigationCoordinator.Tab.collections.rawValue
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.brown)
                    Text("Download Heritage Collections")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Test Protection Button (for testing - should be protected)
            Button(role: .destructive) {
                testHeritageProtection()
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(.orange)
                    Text("Test Heritage Protection")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("(Dev)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                showHeritageCleanup = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.brown)
                    Text("Review Unused Heritage Recipes")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Heritage Collections")
        } footer: {
            Text("Heritage recipes are protected from deletion. Test Protection verifies the safeguard is working.")
        }
    }

    // MARK: - Heritage Protection Test

    private func testHeritageProtection() {
        let heritageRecipes = recipes.filter { $0.isHeritageRecipe }

        guard !heritageRecipes.isEmpty else {
            showAlert(title: "No Heritage Recipes", message: "Download Heritage collections first to test protection.")
            return
        }

        Log.info("🛡️ Testing Heritage protection - attempting to delete \(heritageRecipes.count) recipes", category: .heritage)

        var deletedCount = 0
        var protectedCount = 0

        for recipe in heritageRecipes {
            if recipe.isHeritageRecipe {
                // This should be protected by the migration code
                Log.info("🛡️ PROTECTED: Heritage recipe should not be deletable", category: .heritage, metadata: ["title": recipe.title])
                protectedCount += 1
            } else {
                deletedCount += 1
            }
        }

        let message = """
        Protection Test Results:

        ✅ Protected: \(protectedCount) recipes
        ❌ Would delete: \(deletedCount) recipes

        Heritage recipes are safeguarded from migration cleanup. Even if UserDefaults is cleared or app is reinstalled, these recipes cannot be deleted by system migrations.
        """

        showAlert(title: "🛡️ Protection Verified", message: message)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Force view dependency on authStateChanged to trigger re-renders
            let _ = authStateChanged

            if let user = firebaseAuth.currentUser {
                // Determine sign-in provider for fallback display
                let provider = user.providerData.first?.providerID ?? "Unknown"
                let providerName: String = {
                    switch provider {
                    case "apple.com": return "Apple"
                    case "google.com": return "Google"
                    case "password": return "Email"
                    default: return "Unknown Provider"
                    }
                }()

                let userDisplay = user.displayName ?? user.email ?? "Signed in with \(providerName)"
                LabeledContent("Signed in as", value: userDisplay)
                    .font(HeirloomFonts.caption1)

                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in to sync your recipes across devices and share with friends")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }
        } header: {
            Text("Account")
        } footer: {
            if firebaseAuth.currentUser != nil {
                Text("Signing out will clear local data. Your recipes are safely stored in Firebase and will sync when you sign back in.")
            } else {
                Text("Your recipes are stored locally. Sign in to enable cloud sync and sharing.")
            }
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
            // Premium Mode Toggle (defaults to ON for testing)
            Toggle(isOn: Binding(
                get: {
                    UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true
                },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "debug_force_non_premium")
                }
            )) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle((UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true) ? .gray : .orange)
                    VStack(alignment: .leading) {
                        Text("Force Non-Premium Mode")
                        Text((UserDefaults.standard.object(forKey: "debug_force_non_premium") as? Bool ?? true) ? "Testing progressive unlock" : "Premium access enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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

            // Trial Debug View - TEST TRIAL PERIOD SCENARIOS
            NavigationLink {
                TrialDebugView()
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Trial Debug")
                    Spacer()
                    Text("🔬")
                        .font(.caption)
                }
            }

            // Feature Flags Debug - VIEW AND TOGGLE FEATURE FLAGS
            // TODO: Re-enable after fixing module visibility
            // NavigationLink {
            //     FeatureFlagsDebugView()
            // } label: {
            //     HStack {
            //         Image(systemName: "flag.checkered")
            //             .foregroundStyle(HeirloomColors.tomato)
            //         Text("Feature Flags")
            //         Spacer()
            //         Text("🚩")
            //             .font(.caption)
            //     }
            // }

            // RevenueCat Toggle - STUB FOR PHASE 3
            Toggle(isOn: Binding(
                get: {
                    UserDefaults.standard.bool(forKey: "feature_revenuecat_enabled")
                },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "feature_revenuecat_enabled")
                }
            )) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading) {
                        Text("Enable RevenueCat (Stub)")
                        Text("Not yet implemented")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(true) // Disabled until Phase 3 implementation
        } header: {
            Text("Developer Testing")
        } footer: {
            Text("Enable 'Force Non-Premium Mode' to test the progressive heritage unlock flow (7 recipes per day). RevenueCat integration will be implemented in Phase 3.")
        }
    }

    // MARK: - User Experience Section

    private var userExperienceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { UserDefaults.standard.string(forKey: "units_preferred_system") ?? "Metric" },
                set: { UserDefaults.standard.set($0, forKey: "units_preferred_system") }
            )) {
                Text("Imperial (US)").tag("Imperial")
                Text("Metric").tag("Metric")
            } label: {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Measurement System")
                }
            }
            .pickerStyle(.menu)

            Toggle(isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "cardFlipHapticsEnabled") as? Bool ?? true },
                set: { UserDefaults.standard.set($0, forKey: "cardFlipHapticsEnabled") }
            )) {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Card Flip Haptics")
                }
            }

            Toggle(isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "cardFlipSoundEnabled") as? Bool ?? true },
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
            Text("Choose your preferred measurement system for recipes. This preference will be used for future recipe imports and conversions.")
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
                analytics.track(event: .contactSupportTapped, properties: nil)
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

                analytics.track(event: .bugReportSubmitted, properties: [
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

                analytics.track(event: .featureRequestSubmitted, properties: nil)

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

    // MARK: - Subscription Helpers

    private var subscriptionStatusText: String {
        switch subscriptionManager.status {
        case .none:
            return "Free"
        case .trial:
            if let days = subscriptionManager.daysRemaining {
                return "Premium Trial • \(days) day\(days == 1 ? "" : "s") remaining"
            }
            return "Premium Trial"
        case .monthly:
            return "Premium (Monthly)"
        case .annual:
            return "Premium (Annual)"
        case .lifetime:
            return "Premium (Lifetime)"
        case .expired:
            return "Subscription Expired"
        case .grace:
            return "Payment Issue"
        }
    }

    private var subscriptionStatusColor: Color {
        subscriptionManager.isPremium ? HeirloomColors.tomato : HeirloomColors.secondaryText
    }

    private var subscriptionDateText: String? {
        if let expiryDate = subscriptionManager.subscriptionExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: expiryDate)
        } else if let trialExpiry = subscriptionManager.trialExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: trialExpiry)
        }
        return nil
    }

    private var subscriptionDateLabel: String {
        if subscriptionManager.status == .trial {
            return "Trial Ends"
        } else if subscriptionManager.status == .expired {
            return "Ended"
        } else {
            return "Renews"
        }
    }

    private var subscriptionFooterText: String {
        if subscriptionManager.isPremium {
            return "Manage your subscription or restore purchases on another device."
        } else {
            return "Upgrade to unlock URL import, cookbook scanning, and device sync."
        }
    }

    // MARK: - Actions

    private func exportRecipes() {
        isExporting = true

        Task {
            do {
                let jsonData = try recipeExporter.exportToJSON(recipes: recipes)
                let filename = recipeExporter.generateFilename()

                await MainActor.run {
                    // Create temporary file
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                    try? jsonData.write(to: tempURL)

                    // Show share sheet
                    let activityVC = UIActivityViewController(
                        activityItems: [tempURL],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            // Clean up temp file
                            try? FileManager.default.removeItem(at: tempURL)
                        }
                        rootVC.present(activityVC, animated: true)
                    }

                    isExporting = false
                    toastManager.success(title: "Recipes exported", message: "Saved \(recipes.count) recipes to JSON")
                }

                analytics.track(event: .recipesExported, properties: ["count": recipes.count])

            } catch {
                await MainActor.run {
                    isExporting = false
                    toastManager.error(title: "Export failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func restorePurchases() {
        isRestoringPurchases = true

        Task {
            do {
                let transactions = try await storeManager.restorePurchases()

                await MainActor.run {
                    isRestoringPurchases = false

                    if !transactions.isEmpty {
                        toastManager.success(
                            title: "Purchases restored",
                            message: "Your subscription has been restored"
                        )

                        // Refresh subscription status
                        Task {
                            await subscriptionManager.refreshStatus(force: true)
                        }
                    } else {
                        toastManager.info(
                            title: "No purchases found",
                            message: "We couldn't find any previous purchases to restore"
                        )
                    }
                }

                analytics.track(event: .purchasesRestored, properties: ["count": transactions.count])

            } catch {
                await MainActor.run {
                    isRestoringPurchases = false
                    toastManager.error(title: "Restore failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func openManageSubscription() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            toastManager.error(title: "Could not open", message: "Unable to find window scene")
            return
        }

        Task {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
                analytics.track(event: .manageSubscriptionOpened)
            } catch {
                // Log the actual error for debugging
                await MainActor.run {
                    Log.error(
                        "Failed to open subscription management",
                        category: .store,
                        error: error,
                        metadata: ["error_description": error.localizedDescription]
                    )

                    // Show helpful error message
                    if error.localizedDescription.contains("account") || error.localizedDescription.contains("sign in") {
                        toastManager.error(
                            title: "Apple ID Required",
                            message: "Please sign in to your Apple account in Settings to manage subscriptions"
                        )
                    } else {
                        toastManager.error(
                            title: "Could not open",
                            message: "Unable to open subscription management. Please try again or manage via the App Store."
                        )
                    }
                }
            }
        }
    }

    private func calculateStorageSize() async {
        // Calculate storage from image files
        let totalSize = await imageStorageService.calculateTotalStorageSize()

        await MainActor.run {
            storageSize = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        }
    }

    private func clearAllData() {
        let recipeCount = recipes.count

        // Show loading indicator
        isClearingData = true

        // CRITICAL: Wait for any ongoing Firebase sync to complete
        // This prevents crashes where sync tries to access deleted recipes
        Task {
            // Wait for sync to finish (with timeout of 10 seconds)
            var waitTime = 0
            while firebaseSyncService.isSyncing && waitTime < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                waitTime += 1
            }

            // CRITICAL: Force-resolve all Recipe attributes to prevent SwiftData faulting errors
            // When we delete recipes, SwiftData marks them as "faulted" (detached from context)
            // If any code later tries to access an attribute that wasn't loaded, it crashes
            // Solution: Access all optional properties BEFORE deletion to force SwiftData to load them
            let recipeIds = await MainActor.run {
                recipes.map { recipe in
                    // Force-resolve all optional attributes by accessing them
                    _ = recipe.sourceType  // This was causing the crash!
                    _ = recipe.sourceURL
                    _ = recipe.imageFileName
                    _ = recipe.ingredients
                    _ = recipe.tags
                    _ = recipe.collections

                    return recipe.id.uuidString
                }
            }

            // Delete all recipes from local database
            await MainActor.run {
                for recipe in recipes {
                    modelContext.delete(recipe)
                }

                do {
                    try modelContext.save()
                } catch {
                    toastManager.error(title: "Failed to clear data", message: error.localizedDescription)
                    isClearingData = false
                    return
                }
            }

            // CRITICAL: Give SwiftUI time to process the deletion and update all views
            // This prevents crashes where views try to access deleted (faulted) recipe objects
            // The delay ensures all @Query views have updated before we proceed
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Clean up images
            await imageStorageService.performCleanup()

            // CRITICAL: Wait for Firebase deletion to complete BEFORE showing success
            // This prevents recipes from coming back if user closes app too quickly
            if backendConfig.isFirebaseActive {
                await clearFirebaseData(recipeIds: recipeIds)
            }

            // CRITICAL: Clear sync timestamp at the VERY END, after all Firebase operations
            // This ensures that any internal Firebase writes during cleanup don't restore the timestamp
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
            }

            // Show success only after ALL cleanup completes (including Firebase)
            await MainActor.run {
                isClearingData = false
                toastManager.success(title: "Data cleared")
                analytics.track(event: .dataCleared, properties: [
                    "recipe_count": recipeCount
                ])
            }
        }
    }

    private func clearFirebaseData(recipeIds: [String]) async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let recipesRef = db.collection("users/\(userId)/recipes")

            Log.info("Clearing recipes from Firebase", category: .firebase, metadata: ["count": recipeIds.count, "userId": userId])

            // Delete each recipe and its subcollections using pre-captured IDs
            for recipeId in recipeIds {
                // Delete ingredients subcollection
                let ingredientsSnapshot = try await recipesRef.document(recipeId)
                    .collection("ingredients").getDocuments()
                for ingredient in ingredientsSnapshot.documents {
                    try await ingredient.reference.delete()
                }

                // Delete comments subcollection
                let commentsSnapshot = try await recipesRef.document(recipeId)
                    .collection("comments").getDocuments()
                for comment in commentsSnapshot.documents {
                    try await comment.reference.delete()
                }

                // Delete the recipe document
                try await recipesRef.document(recipeId).delete()

                // Delete image from Storage if exists
                let storage = Storage.storage()
                let imagePath = "users/\(userId)/recipes/\(recipeId)/image.jpg"
                let imageRef = storage.reference().child(imagePath)
                try? await imageRef.delete() // Don't fail if image doesn't exist
            }

            Log.info("Firebase data cleared successfully", category: .firebase, metadata: ["userId": userId])
        } catch {
            Log.error("Failed to clear Firebase data", category: .firebase, metadata: ["error": error.localizedDescription, "userId": userId])
        }
    }

    private func signOut() {
        do {
            // Sign out from Firebase
            try firebaseAuth.signOut()

            // Clear sync timestamps (but keep local recipes for offline use)
            UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")

            // Success feedback
            toastManager.success(title: "Signed out successfully")
        } catch {
            toastManager.error(
                title: "Sign out failed",
                message: error.localizedDescription
            )
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
