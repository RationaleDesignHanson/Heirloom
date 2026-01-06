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

    // Dependency Injection Container
    private let serviceContainer = ServiceContainer.shared
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    // Deep link coordinator for robust URL handling
    @State private var deepLinkCoordinator: DeepLinkHandler?

    init() {
        // Initialize DI container with production services
        serviceContainer.registerProductionServices()
        // FILE-BASED LOGGING - guaranteed to work on device
        DeviceLogger.shared.log("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        logger.info("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        Log.info("HeirloomApp initialization started", category: .general)

        // FIREBASE INITIALIZATION - Phase 1 of migration
        // Skip Firebase initialization in test environment to prevent crashes
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                             NSClassFromString("XCTestCase") != nil

        DeviceLogger.shared.log("🧪 [Heirloom] Test detection - XCTestConfigurationFilePath: \(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ? "YES" : "NO"), XCTestCase class: \(NSClassFromString("XCTestCase") != nil ? "YES" : "NO")")

        if !isRunningTests {
            DeviceLogger.shared.log("🔥 [Heirloom] Initializing Firebase...")
            logger.info("🔥 [Heirloom] Initializing Firebase...")

            // Only configure if not already configured
            if FirebaseApp.app() == nil {
                DeviceLogger.shared.log("📝 [Heirloom] Calling FirebaseApp.configure()...")
                FirebaseApp.configure()
                DeviceLogger.shared.log("✅ [Heirloom] FirebaseApp.configure() completed")

                // CRITICAL: Configure Firestore settings IMMEDIATELY after first configuration
                DeviceLogger.shared.log("⚙️ [Heirloom] Configuring Firestore settings...")
                let settings = FirestoreSettings()
                settings.cacheSettings = PersistentCacheSettings()  // Unlimited offline cache

                DeviceLogger.shared.log("📝 [Heirloom] Getting Firestore instance...")
                let firestore = Firestore.firestore()

                DeviceLogger.shared.log("📝 [Heirloom] Setting Firestore settings...")
                firestore.settings = settings

                DeviceLogger.shared.log("✅ [Heirloom] Firebase initialized successfully")
                logger.info("✅ [Heirloom] Firebase initialized successfully")
                Log.info("Firebase initialized successfully", category: .firebase)
            } else {
                DeviceLogger.shared.log("ℹ️ [Heirloom] Firebase already configured")
                logger.info("ℹ️ [Heirloom] Firebase already configured")
            }
        } else {
            DeviceLogger.shared.log("🧪 [Heirloom] Test environment detected - skipping Firebase initialization")
            logger.info("🧪 [Heirloom] Test environment detected - skipping Firebase initialization")
            Log.info("Test environment detected - skipping Firebase initialization", category: .general)
        }

        // Log active backend
        DeviceLogger.shared.log("🔧 [Heirloom] Active backend: Firebase")
        logger.info("🔧 [Heirloom] Active backend: Firebase")
        Log.info("Active backend configured", category: .firebase, metadata: ["backend": "Firebase"])

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
            Log.info("SwiftData initialized with local storage and Firebase sync", category: .database)

            _modelContainer = State(wrappedValue: container)

            // Resolve deep link coordinator after services are registered
            _deepLinkCoordinator = State(wrappedValue: serviceContainer.resolve(DeepLinkHandler.self))

            // Initialize services
            setupServices()

        } catch {
            DeviceLogger.shared.log("❌ [Heirloom] Failed to configure SwiftData: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Heirloom] Failed to configure SwiftData: \(error.localizedDescription)")
            Log.error("Failed to configure SwiftData", category: .database, metadata: ["error": error.localizedDescription])
            _showDataError = State(wrappedValue: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                RootView(
                    modelContainer: modelContainer,
                    authService: serviceContainer.resolve(FirebaseAuthService.self),
                    notificationService: serviceContainer.resolve(FirebaseNotificationService.self)
                )
                    .environmentObject(deepLinkCoordinator ?? serviceContainer.resolve(DeepLinkHandler.self))
                    .onOpenURL { url in
                        Log.info("WindowGroup received URL", category: .general, metadata: ["url": url.absoluteString])
                        logger.info("📱 WindowGroup received URL: \(url.absoluteString)")
                        DeviceLogger.shared.log("📱 [App] WindowGroup received URL: \(url.absoluteString)")
                        deepLinkCoordinator?.handle(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        Log.info("WindowGroup received user activity", category: .general, metadata: ["activityType": userActivity.activityType])
                        logger.info("📱 WindowGroup received user activity")
                        DeviceLogger.shared.log("📱 [App] WindowGroup received user activity: \(userActivity.activityType)")
                        deepLinkCoordinator?.handle(userActivity)
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
            let imageStorageService = serviceContainer.resolve(ImageStorageService.self)
            await imageStorageService.performCleanup()
        }

        // Initialize analytics
        Task { @MainActor in
            analytics.initialize()
            analytics.track(event: .appLaunched)
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

                // Create heritage collections on first launch
                RecipeCollection.createHeritageCollections(context: container.mainContext)

                // Seed heritage recipes if needed (personalized 8-12 recipes)
                let seeder = HeritageRecipeSeeder(modelContext: container.mainContext)
                if !seeder.isSeeded() {
                    do {
                        let count = try await seeder.seedHeritageRecipes()
                        Log.info("Heritage recipes seeded", category: .storage, metadata: ["count": count])
                        DeviceLogger.shared.log("✅ [Heritage] Seeded \(count) personalized heritage recipes")
                        analytics.track(event: .appLaunched, properties: ["heritage_recipes_seeded": count])
                    } catch {
                        Log.error("Failed to seed heritage recipes", category: .storage, metadata: ["error": error.localizedDescription])
                        DeviceLogger.shared.log("❌ [Heritage] Failed to seed recipes: \(error.localizedDescription)")
                    }
                }
            }

            // Firebase sync configuration
            Task { @MainActor in
                DeviceLogger.shared.log("🔄 [Heirloom] Configuring Firebase sync...")
                logger.info("🔄 [Heirloom] Configuring Firebase sync...")

                let syncService = serviceContainer.resolve(FirebaseSyncService.self)
                syncService.configure(modelContext: container.mainContext)

                DeviceLogger.shared.log("✅ [Heirloom] Firebase sync initialized")
                logger.info("✅ [Heirloom] Firebase sync initialized")
                Log.info("Firebase sync service configured", category: .firebase)
            }
        }
    }

    private func checkSharedContainerForPendingImport() {
        // Check if share extension left a pending URL import
        guard let groupDefaults = UserDefaults(suiteName: "group.com.matthanson.heirloom.shared") else {
            Log.warning("Cannot access shared container for pending import", category: .general)
            return
        }

        guard let pendingURLString = groupDefaults.string(forKey: "pendingImportURL"),
              URL(string: pendingURLString) != nil else {
            // No pending import
            return
        }

        Log.info("Found pending import URL from share extension", category: .general, metadata: ["url": pendingURLString])
        DeviceLogger.shared.log("✅ [ShareExtension] Found pending import URL: \(pendingURLString)")

        // Clear it immediately to prevent re-processing
        groupDefaults.removeObject(forKey: "pendingImportURL")
        groupDefaults.removeObject(forKey: "pendingImportTimestamp")

        // Process via deep link handler (will trigger when app is ready)
        let importDeepLink = URL(string: "heirloom://import?url=\(pendingURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
        let deepLinkHandler = serviceContainer.resolve(DeepLinkHandler.self)
        deepLinkHandler.handle(importDeepLink)

        Log.info("Triggered deep link handler for share extension import", category: .general)
        DeviceLogger.shared.log("✅ [ShareExtension] Triggered deep link handler for import")
    }

    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                Log.info("Notification permission granted", category: .general)
            } else {
                Log.warning("Notification permission denied", category: .general)
            }
        } catch {
            Log.error("Failed to request notification permission", category: .general, metadata: ["error": error.localizedDescription])
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
                Log.info("Cleaning up old recipes with broken data", category: .database, metadata: ["count": oldRecipes.count])
                for recipe in oldRecipes {
                    context.delete(recipe)
                }
                try? context.save()
            }

            // Sample recipe auto-population disabled - users can manually add via "Add Sample Recipe" button
            Log.info("Recipe data cleanup complete - starting with clean slate", category: .database)
            UserDefaults.standard.set(true, forKey: hasCleanedKey)
        }
    }
}

/// Root view that handles authentication gating for Firebase
struct RootView: View {
    let modelContainer: ModelContainer
    @ObservedObject var authService: FirebaseAuthService
    let notificationService: FirebaseNotificationService

    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    var body: some View {
        // OPTION A (HYBRID AUTH UX): Always show ContentView
        // Users can browse heritage recipes without signing in
        // Sign-in is optional via Settings, contextual prompts when needed (e.g., sharing)
        ContentView(notificationService: notificationService)
            .modelContainer(modelContainer)
            .onAppear {
                // Start automatic sync if already authenticated on app launch
                if authService.isAuthenticated {
                    Log.info("User already authenticated on launch - starting automatic sync", category: .sync)
                    DeviceLogger.shared.log("✅ [Auth] User already authenticated - starting automatic sync")

                    // Resolve sync service now (after Firebase is initialized)
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                    syncService.startAutomaticSync()
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                // When user signs in, start automatic sync
                if !oldValue && newValue {
                    Log.info("User authenticated - starting automatic Firebase sync", category: .sync)
                    DeviceLogger.shared.log("✅ [Auth] User authenticated - starting automatic sync")

                    // Resolve sync service now (after Firebase is initialized)
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                    syncService.startAutomaticSync()
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

    // Notification service (injected from DI container)
    @ObservedObject var notificationService: FirebaseNotificationService

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

            CollectionsListView()
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2.fill")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.collectionsTab)
                .accessibilityLabel("Collections")
                .accessibilityHint("View heritage and user collections")

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
                    Label("Meal Planning", systemImage: "calendar")
                }
                .tag(3)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.mealPlanningTab)
                .accessibilityLabel("Meal Planning")
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
            Log.info("ContentView appeared - marking app ready for deep links", category: .ui)
            DeviceLogger.shared.log("✅ [App] ContentView appeared - marking app as ready for deep links")
            deepLinkCoordinator.markAppReady()
        }
    }
}

#Preview {
    @Previewable @State var container = {
        let c = ServiceContainer(forTesting: true)
        c.registerProductionServices()
        return c
    }()

    ContentView(
        notificationService: container.resolve(FirebaseNotificationService.self)
    )
    .environmentObject(container.resolve(DeepLinkHandler.self))
    .modelContainer(for: Recipe.self, inMemory: true)
}
