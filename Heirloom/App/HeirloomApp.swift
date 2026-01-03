import SwiftUI
import SwiftData
import UserNotifications
import os.log
import FirebaseCore
import FirebaseFirestore

// Device-visible logging
private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "App")

@main
struct HeirloomApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var showDataError = false

    // Deep link coordinator for robust URL handling
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator.shared

    init() {
        // FILE-BASED LOGGING - guaranteed to work on device
        DeviceLogger.shared.log("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        logger.info("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        print("🚀 HeirloomApp.init() called")

        // FIREBASE INITIALIZATION - Phase 1 of migration
        DeviceLogger.shared.log("🔥 [Heirloom] Initializing Firebase...")
        logger.info("🔥 [Heirloom] Initializing Firebase...")
        FirebaseApp.configure()

        // CRITICAL: Configure Firestore settings IMMEDIATELY before any access
        DeviceLogger.shared.log("⚙️ [Heirloom] Configuring Firestore settings...")
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()  // Unlimited offline cache
        Firestore.firestore().settings = settings

        DeviceLogger.shared.log("✅ [Heirloom] Firebase initialized successfully")
        logger.info("✅ [Heirloom] Firebase initialized successfully")
        print("✅ Firebase initialized")

        // Log active backend
        DeviceLogger.shared.log("🔧 [Heirloom] Active backend: Firebase")
        logger.info("🔧 [Heirloom] Active backend: Firebase")
        print("🔧 Active backend: Firebase")

        do {
            DeviceLogger.shared.log("🔧 [Heirloom] Configuring SwiftData schema...")
            logger.info("🔧 [Heirloom] Configuring SwiftData schema...")

            // Use versioned schema for future migrations
            let schema = SchemaV1.schema

            // Configure for LOCAL ONLY storage
            // Firebase handles sync separately - no CloudKit integration
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none  // Firebase-only backend
            )

            let container = try ModelContainer(
                for: schema,
                configurations: config
            )

            DeviceLogger.shared.log("✅ [Heirloom] SwiftData initialized (Local storage with Firebase sync)")
            logger.info("✅ [Heirloom] SwiftData initialized (Local storage with Firebase sync)")
            print("✅ SwiftData initialized (Local storage with Firebase sync)")

            _modelContainer = State(wrappedValue: container)

            // Initialize services
            setupServices()

        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Failed to configure SwiftData: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Heirloom] Failed to configure SwiftData: \(error.localizedDescription)")
            print("❌ Failed to configure SwiftData: \(error.localizedDescription)")
            _showDataError = State(wrappedValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootView(modelContainer: modelContainer)
                    .environmentObject(deepLinkCoordinator)
                    .onOpenURL { url in
                        print("📱 WindowGroup received URL: \(url.absoluteString)")
                        logger.info("📱 WindowGroup received URL: \(url.absoluteString)")
                        DeviceLogger.shared.log("📱 [App] WindowGroup received URL: \(url.absoluteString)")
                        deepLinkCoordinator.handle(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        print("📱 WindowGroup received user activity")
                        logger.info("📱 WindowGroup received user activity")
                        DeviceLogger.shared.log("📱 [App] WindowGroup received user activity: \(userActivity.activityType)")
                        deepLinkCoordinator.handle(userActivity)
                    }
            } else {
                DataErrorView()
            }
        }
    }

    private func setupServices() {
        // Check for pending import from share extension
        checkSharedContainerForPendingImport()

        // Initialize image storage (in background task since it's an actor)
        Task {
            await ImageStorageService.shared.performCleanup()
        }

        // Initialize analytics
        Task { @MainActor in
            AnalyticsService.shared.initialize()
            AnalyticsService.shared.track(event: .appLaunched)
        }

        // Request notification permissions for cooking timers
        Task {
            await requestNotificationPermission()
        }

        // Clean up old broken recipe data (one-time migration)
        if let container = modelContainer {
            cleanupOldRecipeData(container: container)

            // Create system collections on first launch
            Task { @MainActor in
                RecipeCollection.createSystemCollections(context: container.mainContext)
            }

            // Firebase sync configuration
            Task { @MainActor in
                DeviceLogger.shared.log("🔄 [Heirloom] Configuring Firebase sync...")
                logger.info("🔄 [Heirloom] Configuring Firebase sync...")

                FirebaseSyncService.shared.configure(modelContext: container.mainContext)

                DeviceLogger.shared.log("✅ [Heirloom] Firebase sync initialized")
                logger.info("✅ [Heirloom] Firebase sync initialized")
                print("✅ Firebase sync initialized")
            }
        }
    }

    private func checkSharedContainerForPendingImport() {
        // Check if share extension left a pending URL import
        guard let groupDefaults = UserDefaults(suiteName: "group.com.matthanson.heirloom.shared") else {
            print("⚠️ Cannot access shared container")
            return
        }

        guard let pendingURLString = groupDefaults.string(forKey: "pendingImportURL"),
              URL(string: pendingURLString) != nil else {
            // No pending import
            return
        }

        print("✅ Found pending import URL from share extension: \(pendingURLString)")
        DeviceLogger.shared.log("✅ [ShareExtension] Found pending import URL: \(pendingURLString)")

        // Clear it immediately to prevent re-processing
        groupDefaults.removeObject(forKey: "pendingImportURL")
        groupDefaults.removeObject(forKey: "pendingImportTimestamp")

        // Process via deep link handler (will trigger when app is ready)
        let importDeepLink = URL(string: "heirloom://import?url=\(pendingURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        DeepLinkHandler.shared.handle(importDeepLink)

        print("✅ Triggered deep link handler for import")
        DeviceLogger.shared.log("✅ [ShareExtension] Triggered deep link handler for import")
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Failed to request notification permission: \(error)")
        }
    }

    private func cleanupOldRecipeData(container: ModelContainer) {
        let hasCleanedKey = "hasCleanedBrokenRecipeData_v4"  // v4: Parsed ingredients + proper math

        // Only run once
        guard !UserDefaults.standard.bool(forKey: hasCleanedKey) else {
            return
        }

        Task { @MainActor in
            let context = container.mainContext

            // Delete all existing recipes (they don't have proper ingredients)
            let fetchDescriptor = FetchDescriptor<Recipe>()
            if let oldRecipes = try? context.fetch(fetchDescriptor) {
                print("🧹 Cleaning up \(oldRecipes.count) old recipe(s) with broken data...")
                for recipe in oldRecipes {
                    context.delete(recipe)
                }
                try? context.save()
            }

            // Sample recipe auto-population disabled - users can manually add via "Add Sample Recipe" button
            print("✅ Recipe data cleanup complete - starting with clean slate")
            UserDefaults.standard.set(true, forKey: hasCleanedKey)
        }
    }
}

/// Root view that handles authentication gating for Firebase
struct RootView: View {
    let modelContainer: ModelContainer
    @StateObject private var authService = FirebaseAuthService.shared

    var body: some View {
        Group {
            // Show sign-in if Firebase is active and user not authenticated
            if BackendConfig.shared.isFirebaseActive && !authService.isAuthenticated {
                FirebaseSignInView()
            } else {
                ContentView()
                    .modelContainer(modelContainer)
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showAddRecipe = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var hasViewedRecipesList = false

    // Deep link coordinator (injected via environment)
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator

    // Notification service
    @StateObject private var notificationService = FirebaseNotificationService.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                RecipeListView()
                    .environmentObject(notificationService)
            }
            .tabItem {
                Label("Recipes", systemImage: "book.closed.fill")
            }
            .if(!hasViewedRecipesList && notificationService.unreadCount > 0) { view in
                view.badge(notificationService.unreadCount)
            }
            .tag(0)
            .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.recipesTab)
            .accessibilityLabel("Recipes")
            .accessibilityHint("View and manage your recipe collection")
            .onAppear {
                // Clear tab badge on first view of recipes list
                if !hasViewedRecipesList {
                    hasViewedRecipesList = true
                }
            }

            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.addTab)
                .accessibilityLabel("Add Recipe")
                .accessibilityHint("Opens sheet to create a new recipe")

            ShoppingListView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.shoppingTab)
                .accessibilityLabel("Shopping List")
                .accessibilityHint("View your shopping list with ingredients from recipes")

            DinnerPartyListView()
                .tabItem {
                    Label("Parties", systemImage: "fork.knife")
                }
                .tag(3)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.partiesTab)
                .accessibilityLabel("Dinner Parties")
                .accessibilityHint("Plan and manage dinner parties")

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.settingsTab)
                .accessibilityLabel("Settings")
                .accessibilityHint("App settings and preferences")
        }
        .preferredColorScheme(.light)
        .tint(HeirloomColors.tomato)
        .toastContainer()
        .milestonesCelebration()
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 1 {
                showAddRecipe = true
                selectedTab = oldValue
            }
        }
        .sheet(isPresented: $showAddRecipe) {
            RecipeEditorView()
        }
        .sheet(isPresented: $deepLinkCoordinator.showShareAcceptanceSheet) {
            if let shareURL = deepLinkCoordinator.pendingShareURL {
                RecipeReceiveSheet(
                    shareURL: shareURL,
                    shareMetadata: deepLinkCoordinator.pendingShareMetadata
                )
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showURLImportSheet) {
            if let importURL = deepLinkCoordinator.pendingImportURL {
                RecipeImportView(url: importURL)
                    .onDisappear {
                        deepLinkCoordinator.clearPendingImport()
                    }
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            // Mark app as ready to process deep links
            print("✅ ContentView appeared - marking app as ready for deep links")
            DeviceLogger.shared.log("✅ [App] ContentView appeared - marking app as ready for deep links")
            deepLinkCoordinator.markAppReady()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DeepLinkCoordinator.shared)
        .modelContainer(for: Recipe.self, inMemory: true)
}
