import SwiftUI
import SwiftData
import StoreKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseCrashlytics

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @Query private var recipes: [Recipe]

    // User-created recipes only (excludes theme/discovery recipes)
    private var userRecipes: [Recipe] {
        recipes.filter { !$0.isThemeRecipe }
    }

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

    // Units configuration for measurement system
    @ObservedObject private var unitsConfig: UnitsConfiguration = ServiceContainer.shared.resolve(UnitsConfiguration.self)

    // Visual style configuration for AI-generated images
    @ObservedObject private var visualStyleConfig: VisualStyleConfiguration = ServiceContainer.shared.resolve(VisualStyleConfiguration.self)

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var storageSize: String = "Calculating..."
    @State private var authStateChanged = false // Force view updates when auth state changes
    @State private var isClearingData = false // Show loading indicator while clearing
    @State private var isExporting = false
    @State private var isRestoringPurchases = false
    @State private var showDowngradeAlert = false
    @State private var showClearCollectionsConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                subscriptionSection

                // Account Section (moved UP - common user need)
                accountSection

                // User Experience Section (moved UP - user preferences)
                userExperienceSection

                // AI Features Section
                aiSection

                // Data Management Section
                dataManagementSection

                // App Info Section
                appInfoSection

                // Support Section
                supportSection

                // Developer Section (moved DOWN - debug tools isolated)
                developerSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
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
                Text("This will permanently delete all \(userRecipes.count) user recipes and \(recipes.count - userRecipes.count) discovery recipes. This cannot be undone.")
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
                Text("This will delete all collections but keep your recipes. Use this for clean testing. This cannot be undone.")
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
                                .foregroundStyle(HeirloomColors.buttonTextLight)
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
                                .font(HeirloomFonts.caption1)
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

                // Manage Subscription button (cancel, etc.)
                // ⭐ MODIFIED: Disable when fake payments active (no real subscription to manage)
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Button {
                        openManageSubscription()
                    } label: {
                        Label("Manage Subscription", systemImage: "gearshape")
                    }
                    .disabled(ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled)
                    .opacity(ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled ? 0.5 : 1.0)

                    // Show hint when disabled
                    if ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled {
                        Text("Only available for real subscriptions")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 32)
                    }
                }
            }

            // Upgrade button (for free users)
            if !subscriptionManager.isPremium {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    // Trial countdown badge
                    if subscriptionManager.isInTrial, let daysRemaining = subscriptionManager.daysRemaining {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(HeirloomFonts.caption1)
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
            LabeledContent("Recipes", value: "\(userRecipes.count)")
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
            .disabled(isExporting || userRecipes.isEmpty)

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

                // Sign Out button
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Account")
        } footer: {
            if firebaseAuth.currentUser != nil {
                Text("Your recipes are safely stored in Firebase and will sync across all your devices.")
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
                    .onAppear {
                        markWhatsNewAsViewed()
                    }
            } label: {
                HStack {
                    Label("What's New", systemImage: "sparkles")
                    Spacer()
                    if showWhatsNewBadge {
                        Text("NEW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(HeirloomColors.tomato)
                            )
                    }
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
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // ⭐ Subscription Testing Tools
            // Auto Premium Toggle (MOVED FROM SUBSCRIPTION SECTION)
            Toggle(isOn: Binding(
                get: {
                    subscriptionManager.isAutoPremiumEnabled
                },
                set: { enabled in
                    subscriptionManager.isAutoPremiumEnabled = enabled

                    // Show toast notification
                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    if enabled {
                        toastManager.info(
                            title: "Auto Premium Enabled",
                            message: "Paywalls will show but won't block access"
                        )
                    } else {
                        toastManager.info(
                            title: "Auto Premium Disabled",
                            message: "Paywalls will block access normally"
                        )
                    }
                }
            )) {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Auto Premium (Debug)")
                        Text("Show paywalls without blocking access")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.orange)

            // Fake Payments Toggle (MOVED FROM SUBSCRIPTION SECTION)
            Toggle(isOn: Binding(
                get: {
                    ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled
                },
                set: { enabled in
                    UserDefaults.standard.set(enabled, forKey: "debug_fake_payments_enabled")

                    Log.info("Fake payments: \(enabled ? "ENABLED" : "DISABLED")", category: .store)

                    // Show toast notification
                    let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                    if enabled {
                        toastManager.info(
                            title: "Fake Payments Enabled",
                            message: "Subscribe buttons will grant premium without payment"
                        )
                    } else {
                        toastManager.info(
                            title: "Fake Payments Disabled",
                            message: "Real StoreKit purchases will be used"
                        )
                    }
                }
            )) {
                HStack {
                    Image(systemName: "theatermasks.fill")
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading) {
                        Text("Fake Payments (Debug)")
                        Text("Grants premium without real transactions")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .tint(.purple)

            // Cancel Fake Subscription (MOVED FROM SUBSCRIPTION SECTION)
            if subscriptionManager.isPremium && ServiceContainer.shared.resolve(StoreManager.self).isFakePaymentsEnabled {
                Button(role: .destructive) {
                    cancelFakeSubscription()
                } label: {
                    Label("Cancel Fake Subscription", systemImage: "xmark.circle.fill")
                }
            }

            Divider()

            // Demo Social Mode Toggle
            // Only show if Remote Config hasn't globally disabled demo mode
            if DemoSocialGate.shared.isRemotelyAvailable {
                Toggle(isOn: Binding(
                    get: {
                        !DemoSocialGate.shared.isLocallyDisabled
                    },
                    set: { enabled in
                        DemoSocialGate.shared.setLocallyDisabled(!enabled)

                        let toastManager = ServiceContainer.shared.resolve(ToastManager.self)
                        if enabled {
                            toastManager.info(
                                title: "Demo Mode Enabled",
                                message: "Demo accounts will appear in search and auto-accept invites"
                            )
                        } else {
                            toastManager.info(
                                title: "Demo Mode Disabled",
                                message: "Demo accounts hidden and behaviors stopped"
                            )
                        }

                        Log.info("Demo social mode: \(enabled ? "ENABLED" : "DISABLED")", category: .general)
                    }
                )) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(HeirloomColors.sage)
                        VStack(alignment: .leading) {
                            Text("Demo Social Mode")
                            Text("Simulated demo accounts will auto-accept invites and share sample recipes")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(HeirloomColors.sage)
            }

            Divider()

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
                        .font(HeirloomFonts.caption1)
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
                        .font(HeirloomFonts.caption1)
                }
            }

            // Credits System Test - TEST PDF IMPORT CREDITS
            NavigationLink {
                CreditsTestView()
            } label: {
                HStack {
                    Image(systemName: "giftcard.fill")
                        .foregroundStyle(HeirloomColors.familyGreen)
                    Text("Credits System Test")
                    Spacer()
                    Text("💳")
                        .font(HeirloomFonts.caption1)
                }
            }

            #if DEBUG
            // Test Crashlytics Reporting - VERIFY CRASH REPORTING
            Button(role: .destructive) {
                Crashlytics.crashlytics().log("User triggered test crash from Settings")
                fatalError("Test crash for Crashlytics verification")
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("Test Crash Reporting")
                        Text("Verify Crashlytics is working")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            #endif

            // Feature Flags Debug - VIEW AND TOGGLE FEATURE FLAGS
            NavigationLink {
                FeatureFlagsDebugView()
            } label: {
                HStack {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Feature Flags")
                    Spacer()
                    Text("🚩")
                        .font(HeirloomFonts.caption1)
                }
            }

            Divider()

            // Clear Collections - FOR CLEAN TESTING
            Button(role: .destructive) {
                showClearCollectionsConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "folder.fill.badge.minus")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text("Clear All Collections")
                        Text("Removes all collections (keeps recipes)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Developer Testing")
        } footer: {
            Text("Debug features for testing subscription flows and app behavior:\n\n• Auto Premium: See paywalls without blocking access (default ON in debug)\n• Fake Payments: Grant premium without real transactions\n• Force Non-Premium: Test progressive heritage unlock (7 recipes/day)\n• Demo Social: \(DemoSocialGate.shared.debugStatus)\n• Build: \(BuildChannel.current.displayName)\n\nThese tools are for development only and help ensure the app works correctly for both free and premium users.")
        }
    }

    // MARK: - User Experience Section

    private var userExperienceSection: some View {
        Section {
            Picker("Measurement System", selection: $unitsConfig.preferredSystem) {
                ForEach(UnitSystem.allCases) { system in
                    Text(system.displayName).tag(system)
                }
            }
            .pickerStyle(.menu)

            // Visual Style for AI-generated images
            NavigationLink {
                VisualStylePickerView(styleConfig: visualStyleConfig)
            } label: {
                HStack {
                    Label("Visual Style", systemImage: visualStyleConfig.selectedStyle.iconName)
                    Spacer()
                    Text(visualStyleConfig.selectedStyle.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("User Experience")
        } footer: {
            Text("Choose your preferred measurement system and visual style for AI-generated collection images.")
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
                // Filter out theme recipes - only export user-created recipes
                let userRecipes = recipes.filter { !$0.isThemeRecipe }
                Log.info("Exporting user recipes", category: .storage, metadata: [
                    "total": recipes.count,
                    "userOnly": userRecipes.count,
                    "filtered": recipes.count - userRecipes.count
                ])

                // Create backup directory with JSON + images
                let backupURL = try await createBackupWithImages(recipes: userRecipes)

                await MainActor.run {
                    // Show share sheet
                    let activityVC = UIActivityViewController(
                        activityItems: [backupURL],
                        applicationActivities: nil
                    )

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let rootVC = window.rootViewController {
                        activityVC.completionWithItemsHandler = { _, _, _, _ in
                            // Clean up temp directory
                            try? FileManager.default.removeItem(at: backupURL)
                        }
                        rootVC.present(activityVC, animated: true)
                    }

                    isExporting = false

                    // Count recipes with images
                    let recipesWithImages = userRecipes.filter { $0.imageFileName != nil }.count
                    toastManager.success(
                        title: "Recipes exported",
                        message: "Saved \(userRecipes.count) recipes (\(recipesWithImages) with images)"
                    )
                }

                analytics.track(event: .recipesExported, properties: ["count": userRecipes.count])

            } catch {
                await MainActor.run {
                    isExporting = false
                    toastManager.error(title: "Export failed", message: error.localizedDescription)
                }
            }
        }
    }

    /// Creates a backup directory containing recipes.json and an images/ folder
    private func createBackupWithImages(recipes: [Recipe]) async throws -> URL {
        let fileManager = FileManager.default
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupDirName = "RecipeBackup_\(timestamp)"
        let backupURL = fileManager.temporaryDirectory.appendingPathComponent(backupDirName)

        // Create backup directory structure
        try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)

        // 1. Export recipes to JSON
        let jsonData = try recipeExporter.exportToJSON(recipes: recipes)
        let jsonURL = backupURL.appendingPathComponent("recipes.json")
        try jsonData.write(to: jsonURL)

        Log.info("Created recipes.json", category: .storage, metadata: [
            "recipeCount": recipes.count,
            "path": jsonURL.path
        ])

        // 2. Copy recipe images to images/ folder
        let recipesWithImages = recipes.filter { $0.imageFileName != nil }

        if !recipesWithImages.isEmpty {
            let imagesURL = backupURL.appendingPathComponent("images")
            try fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)

            // Get images directory from ImageStorageService
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let sourceImagesDir = documentsPath.appendingPathComponent("RecipeImages", isDirectory: true)

            var copiedCount = 0
            for recipe in recipesWithImages {
                guard let imageFileName = recipe.imageFileName else { continue }

                let sourceURL = sourceImagesDir.appendingPathComponent(imageFileName)
                let destURL = imagesURL.appendingPathComponent(imageFileName)

                // Copy image if it exists
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try? fileManager.copyItem(at: sourceURL, to: destURL)
                    copiedCount += 1
                }
            }

            Log.info("Copied recipe images to backup", category: .storage, metadata: [
                "totalRecipes": recipes.count,
                "recipesWithImages": recipesWithImages.count,
                "imagesCopied": copiedCount
            ])
        }

        return backupURL
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

    // ⭐ NEW: Cancel Fake Subscription (DEBUG ONLY)
    private func cancelFakeSubscription() {
        // Reset to trial state
        UserDefaults.standard.removeObject(forKey: "subscription_status")
        UserDefaults.standard.removeObject(forKey: "subscription_expiry_date")
        UserDefaults.standard.removeObject(forKey: "cached_product_id")

        // Re-enable trial
        let now = Date()
        let trialExpiry = Calendar.current.date(byAdding: .day, value: 14, to: now)!
        UserDefaults.standard.set(now, forKey: "first_launch_date")
        UserDefaults.standard.set(trialExpiry, forKey: "trial_expiry_date")
        UserDefaults.standard.set("trial", forKey: "subscription_status")
        UserDefaults.standard.synchronize()

        // Trigger refresh
        Task {
            await subscriptionManager.refreshStatus(force: true)
        }

        toastManager.success(
            title: "Fake Subscription Cancelled",
            message: "Restored to 14-day trial period"
        )

        Log.info("Cancelled fake subscription, restored trial", category: .store)
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
            // CRITICAL: Give any ongoing recipe imports time to complete or cancel
            // This prevents crashes where imports try to access deleted ingredients
            // during recipe save operations (web import, video import, etc.)
            Log.info("Waiting for ongoing operations before clearing data", category: .storage)
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

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
                // Delete all recipes
                for recipe in recipes {
                    modelContext.delete(recipe)
                }

                // Delete all collections (with tombstones)
                do {
                    let collectionDescriptor = FetchDescriptor<RecipeCollection>()
                    let collections = try modelContext.fetch(collectionDescriptor)

                    // Create tombstones BEFORE deleting
                    for collection in collections {
                        let tombstone = DeletedCollectionRecord(collectionId: collection.id)
                        modelContext.insert(tombstone)
                        Log.info("Created deletion tombstone for clear all data", category: .collections, metadata: [
                            "collectionId": collection.id.uuidString
                        ])
                    }

                    // Now delete the collections
                    for collection in collections {
                        modelContext.delete(collection)
                    }
                } catch {
                    Log.error("Failed to fetch collections for deletion", category: .general, metadata: ["error": error.localizedDescription])
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

            // Clean up images - pass empty set since all recipes are deleted
            _ = await imageStorageService.cleanupOrphanedImages(validImageFileNames: [])

            // CRITICAL: Wait for Firebase deletion to complete BEFORE showing success
            // This prevents recipes and collections from coming back if user closes app too quickly
            if backendConfig.isFirebaseActive {
                await clearFirebaseData(recipeIds: recipeIds)
                await clearFirebaseCollections()
            }

            // CRITICAL: Clear sync timestamp at the VERY END, after all Firebase operations
            // This ensures that any internal Firebase writes during cleanup don't restore the timestamp
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
                UserDefaults.standard.removeObject(forKey: "OnboardingRecipeSeeded")
                Log.info("Cleared onboarding flag", category: .storage)
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

    private func clearFirebaseCollections() async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let collectionsRef = db.collection("users/\(userId)/collections")

            Log.info("Clearing collections from Firebase", category: .firebase, metadata: ["userId": userId])

            // Fetch all collections
            let collectionsSnapshot = try await collectionsRef.getDocuments()

            // Delete each collection document
            for collectionDoc in collectionsSnapshot.documents {
                try await collectionDoc.reference.delete()
            }

            Log.info("Firebase collections cleared successfully", category: .firebase, metadata: ["count": collectionsSnapshot.documents.count, "userId": userId])
        } catch {
            Log.error("Failed to clear Firebase collections", category: .firebase, metadata: ["error": error.localizedDescription, "userId": userId])
        }
    }

    private func signOut() {
        do {
            // Sign out from Firebase
            try firebaseAuth.signOut()

            // Note: We intentionally DO NOT clear local data here to prevent data loss
            // If we cleared data before sync completed, user recipes could be lost forever
            //
            // Instead, data clearing happens in FirebaseAuthService when:
            // 1. A DIFFERENT user signs in (user switch scenario)
            // 2. After sign out is complete (in the auth state listener)
            //
            // This ensures data is safely synced to Firebase before being removed

            // Success feedback
            toastManager.success(title: "Signed out successfully")
        } catch {
            toastManager.error(
                title: "Sign out failed",
                message: error.localizedDescription
            )
        }
    }

    private func clearAllCollections() {
        Task {
            await MainActor.run {
                do {
                    // Fetch all collections
                    let descriptor = FetchDescriptor<RecipeCollection>()
                    let collections = try modelContext.fetch(descriptor)

                    Log.info("Clearing all collections", category: .general, metadata: ["count": collections.count])

                    // Delete each collection
                    for collection in collections {
                        modelContext.delete(collection)
                    }

                    // Save changes
                    try modelContext.save()

                    Log.info("All collections cleared successfully", category: .general)
                    toastManager.success(
                        title: "Collections Cleared",
                        message: "All \(collections.count) collections removed. Recipes are safe."
                    )
                } catch {
                    Log.error("Failed to clear collections", category: .general, metadata: ["error": error.localizedDescription])
                    toastManager.error(
                        title: "Clear Failed",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var showWhatsNewBadge: Bool {
        let lastViewedVersion = UserDefaults.standard.string(forKey: "last_viewed_whats_new_version")
        let currentVersion = appVersion
        return lastViewedVersion != currentVersion
    }

    private func markWhatsNewAsViewed() {
        UserDefaults.standard.set(appVersion, forKey: "last_viewed_whats_new_version")
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
