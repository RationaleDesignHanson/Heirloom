import SwiftUI
import SwiftData
import UserNotifications
import os.log
import FirebaseCore
import FirebaseFirestore

// Device-visible logging
private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "App")

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    weak var deepLinkHandler: DeepLinkHandler?

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap or action button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier

        // Extract job ID from userInfo
        guard let jobIdString = userInfo["jobId"] as? String,
              let jobId = UUID(uuidString: jobIdString) else {
            Log.warning("No valid jobId in notification", category: .video)
            completionHandler()
            return
        }

        Log.info("Handling notification action", category: .video, metadata: [
            "jobId": jobIdString,
            "action": actionIdentifier
        ])

        // Map action identifier to deep link action
        let action: String
        switch actionIdentifier {
        case "REVIEW_RECIPE":
            action = "review"
        case "RETRY_JOB":
            action = "retry"
        case "VIEW_ERROR":
            action = "view-error"
        case UNNotificationDefaultActionIdentifier:
            // User tapped notification body - default action
            let category = response.notification.request.content.categoryIdentifier
            action = category == "VIDEO_PROCESSING_COMPLETE" ? "review" : "view-error"
        default:
            Log.warning("Unknown notification action", category: .video, metadata: ["action": actionIdentifier])
            completionHandler()
            return
        }

        // Create deep link URL
        let deepLinkURL = URL(string: "heirloom://video-job/\(jobId.uuidString)/\(action)")!

        Log.info("Triggering deep link from notification", category: .video, metadata: [
            "url": deepLinkURL.absoluteString
        ])

        // Handle deep link on main actor
        Task { @MainActor in
            deepLinkHandler?.handle(deepLinkURL)
        }

        completionHandler()
    }
}

@main
struct HeirloomApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var showDataError = false

    // Dependency Injection Container
    private let serviceContainer = ServiceContainer.shared
    // DISABLED: These computed properties can trigger early service resolution
    // private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    // private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }

    // Deep link coordinator for robust URL handling
    @State private var deepLinkCoordinator: DeepLinkHandler?

    // Notification delegate for handling notification taps
    @StateObject private var notificationDelegate = NotificationDelegate()

    // Test environment detection - computed once at initialization
    private let isRunningTests: Bool

    // Pre-resolved services (only available in production, nil in test environment)
    @State private var authService: FirebaseAuthService?
    @State private var notificationService: FirebaseNotificationService?

    init() {
        print("🚀 [INIT] HeirloomApp.init() START")

        // Detect test environment ONCE at initialization - use multiple checks
        let hasXCTestConfig = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let hasXCTestClass = NSClassFromString("XCTestCase") != nil
        let hasXCTestBundle = Bundle.allBundles.contains(where: { $0.bundlePath.contains("xctest") })
        self.isRunningTests = hasXCTestConfig || hasXCTestClass || hasXCTestBundle

        print("🧪 [INIT] Test detection: XCTestConfig=\(hasXCTestConfig), XCTestClass=\(hasXCTestClass), XCTestBundle=\(hasXCTestBundle)")
        print("🧪 [INIT] isRunningTests = \(self.isRunningTests)")

        // FILE-BASED LOGGING - guaranteed to work on device
        DeviceLogger.shared.log("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        DeviceLogger.shared.log("🧪 [Heirloom] Test detection: XCTestConfig=\(hasXCTestConfig), XCTestClass=\(hasXCTestClass), XCTestBundle=\(hasXCTestBundle)")
        DeviceLogger.shared.log("🧪 [Heirloom] isRunningTests = \(self.isRunningTests)")
        logger.info("🚀 [Heirloom] HeirloomApp.init() called - starting initialization")
        Log.info("HeirloomApp initialization started", category: .general)

        // CONFIGURE UIKIT APPEARANCE
        // Must happen early to ensure all UIKit components render correctly
        // Skip in test environment to avoid affecting test execution
        if !isRunningTests {
            print("🎨 [INIT] Configuring UIKit appearance for forced light mode...")
            UIKitAppearance.configure()
            print("✅ [INIT] UIKit appearance configured")
            DeviceLogger.shared.log("✅ [Heirloom] UIKit appearance configured for light mode")
        }

        // FIREBASE INITIALIZATION - Phase 1 of migration
        // Skip Firebase initialization in test environment to prevent crashes
        DeviceLogger.shared.log("🧪 [Heirloom] Test detection - XCTestConfigurationFilePath: \(ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ? "YES" : "NO"), XCTestCase class: \(NSClassFromString("XCTestCase") != nil ? "YES" : "NO")")

        print("📦 [INIT] About to register services...")

        // Initialize DI container - skip production services in test environment
        if !isRunningTests {
            print("📦 [INIT] Registering PRODUCTION services...")
            serviceContainer.registerProductionServices()
            print("✅ [INIT] Production services registered")
            DeviceLogger.shared.log("✅ [Heirloom] Production services registered")
        } else {
            print("🧪 [INIT] Test environment - SKIPPING production service registration")
            DeviceLogger.shared.log("🧪 [Heirloom] Test environment - skipping production service registration")
        }

        print("🔥 [INIT] Checking Firebase initialization...")

        if !isRunningTests {
            print("🔥 [INIT] Initializing Firebase...")
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

        print("💾 [INIT] Starting SwiftData configuration...")

        do {
            print("💾 [INIT] Getting SchemaV2.schema...")
            DeviceLogger.shared.log("🔧 [Heirloom] Configuring SwiftData schema (V2 - Multilingual Support)...")
            logger.info("🔧 [Heirloom] Configuring SwiftData schema (V2 - Multilingual Support)...")

            // Use SchemaV2 with migration plan from V1 → V2
            // V2 adds optional multilingual fields without breaking existing data
            let schema = SchemaV2.schema
            print("✅ [INIT] Got SchemaV2.schema successfully")

            // Configure for LOCAL ONLY storage
            // Firebase handles sync separately - no CloudKit integration
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none  // Firebase-only backend
            )

            print("📦 [INIT] Creating ModelContainer...")

            // Initialize container without migration plan for testing
            // TODO: Re-enable migration plan once app can launch successfully
            let container = try ModelContainer(
                for: schema,
                configurations: config
            )

            print("✅ [INIT] ModelContainer created successfully")
            DeviceLogger.shared.log("✅ [Heirloom] SwiftData initialized (Local storage with Firebase sync)")
            logger.info("✅ [Heirloom] SwiftData initialized (Local storage with Firebase sync)")
            Log.info("SwiftData initialized with local storage and Firebase sync", category: .database)

            _modelContainer = State(wrappedValue: container)

            print("🔧 [INIT] Checking service resolution...")

            // Resolve deep link coordinator and services after they're registered (skip in test environment)
            if !isRunningTests {
                print("🔧 [INIT] Resolving production services...")
                DeviceLogger.shared.log("🔧 [Heirloom] Resolving DeepLinkHandler...")
                _deepLinkCoordinator = State(wrappedValue: serviceContainer.resolve(DeepLinkHandler.self))
                print("✅ [INIT] DeepLinkHandler resolved")

                DeviceLogger.shared.log("🔧 [Heirloom] Resolving FirebaseAuthService...")
                let authSvc = serviceContainer.resolve(FirebaseAuthService.self)
                _authService = State(wrappedValue: authSvc)
                print("✅ [INIT] FirebaseAuthService resolved")

                DeviceLogger.shared.log("🔧 [Heirloom] Setting up FirebaseAuthService listener...")
                authSvc.setupAuthListener()
                print("✅ [INIT] FirebaseAuthService listener setup complete")

                DeviceLogger.shared.log("🔧 [Heirloom] Resolving FirebaseNotificationService...")
                _notificationService = State(wrappedValue: serviceContainer.resolve(FirebaseNotificationService.self))
                print("✅ [INIT] FirebaseNotificationService resolved")

                DeviceLogger.shared.log("✅ [Heirloom] All services resolved successfully")

                // Initialize services
                setupServices()
            } else {
                print("🧪 [INIT] Test environment - SKIPPING service resolution and initialization")
                DeviceLogger.shared.log("🧪 [Heirloom] Test environment - skipping service initialization")
            }

            print("✅ [INIT] HeirloomApp.init() COMPLETED SUCCESSFULLY")

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
                // In test environment, skip RootView since it requires Firebase services
                if !isRunningTests, let authService, let notificationService {
                    RootView(
                        modelContainer: modelContainer,
                        authService: authService,
                        notificationService: notificationService
                    )
                        .environmentObject(deepLinkCoordinator!)
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
                    // Test environment - show minimal view
                    Text("Test Environment")
                        .modelContainer(modelContainer)
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
            let analytics = serviceContainer.resolve(AnalyticsService.self)
            analytics.initialize()
            analytics.track(event: .appLaunched)
        }

        // Personal API keys should be added via Settings, not hardcoded here
        // The default key from Config.xcconfig will be used automatically

        // Initialize subscription system
        Task { @MainActor in
            let storeManager = serviceContainer.resolve(StoreManager.self)
            let subscriptionManager = serviceContainer.resolve(SubscriptionManager.self)
            let paywallManager = serviceContainer.resolve(PaywallManager.self)

            // Load products from App Store
            try? await storeManager.loadProducts()

            // Refresh subscription status
            await subscriptionManager.refreshStatus()

            Log.info("Subscription system initialized", category: .store)
            DeviceLogger.shared.log("✅ [Store] Subscription system initialized")

            // Check for day-based paywall triggers (if not premium)
            if !subscriptionManager.isPremium {
                // Day 7: "You're getting the hang of it" soft nudge
                if paywallManager.shouldShow(for: .fiveRecipesOrDay7) {
                    paywallManager.show(for: .fiveRecipesOrDay7)
                    Log.info("Day 7 paywall triggered", category: .store)
                }

                // Day 13: "Your trial ends soon" urgency nudge
                else if paywallManager.shouldShow(for: .day13Urgency) {
                    paywallManager.show(for: .day13Urgency)
                    Log.info("Day 13 paywall triggered", category: .store)
                }
            }
        }

        // Request notification permissions and register categories
        Task {
            await requestNotificationPermission()
            registerNotificationCategories()

            // Set up notification delegate
            if let deepLinkCoordinator = deepLinkCoordinator {
                notificationDelegate.deepLinkHandler = deepLinkCoordinator
                UNUserNotificationCenter.current().delegate = notificationDelegate
                Log.info("Notification delegate configured", category: .video)
                DeviceLogger.shared.log("✅ [Notifications] Delegate configured for deep links")
            }
        }

        // Preload WhisperKit ML model in background
        // Downloads ~40-250MB model so video import is instant when user needs it
        Task.detached(priority: .background) {
            await MainActor.run {
                WhisperKitTranscriptionService.preloadModel()
            }
            await MainActor.run {
                DeviceLogger.shared.log("✅ [Video] WhisperKit model preload initiated")
            }
        }

        // Clean up old broken recipe data (one-time migration)
        if let container = modelContainer {
            cleanupOldRecipeData(container: container)

            // Run collections-first migration for existing users
            Task { @MainActor in
                let didRunMigration = CollectionsFirstMigration.runIfNeeded(context: container.mainContext)
                if didRunMigration {
                    DeviceLogger.shared.log("✅ [Migration] Collections-First migration completed")
                }

                // Create system collections on first launch (handles migration idempotently)
                RecipeCollection.createSystemCollections(context: container.mainContext)

                // Create heritage collections on first launch
                RecipeCollection.createHeritageCollections(context: container.mainContext)

                // CRITICAL: DO NOT seed heritage recipes here!
                // Heritage seeding now happens AFTER sign-in to ensure Firebase state syncs properly
                // See: preOnboardingSignInView.onChange and OnboardingContainerView.onAppear
                DeviceLogger.shared.log("✅ [Heritage] Collections created - recipes will seed after auth")
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

            // Initialize video processing queue coordinator
            Task { @MainActor in
                let jobManager = VideoProcessingJobManager()
                serviceContainer.register(VideoProcessingJobManager.self, instance: jobManager)

                // Resume pending jobs on app launch
                let modelContext = container.mainContext
                await jobManager.resumePendingJobs(context: modelContext)
                Log.info("Video processing queue coordinator initialized", category: .video)
                DeviceLogger.shared.log("✅ [Video] Queue coordinator initialized, pending jobs resumed")
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

        // Check timestamp to prevent re-processing stale URLs from previous sessions
        if let timestamp = groupDefaults.object(forKey: "pendingImportTimestamp") as? Date {
            let ageInSeconds = Date().timeIntervalSince(timestamp)
            let maxAgeSeconds: TimeInterval = 300 // 5 minutes

            if ageInSeconds > maxAgeSeconds {
                Log.warning("Ignoring stale pending import URL", category: .general, metadata: [
                    "url": pendingURLString,
                    "ageSeconds": ageInSeconds
                ])
                DeviceLogger.shared.log("⚠️ [ShareExtension] Ignoring stale URL (age: \(Int(ageInSeconds))s): \(pendingURLString)")

                // Clear the stale URL
                groupDefaults.removeObject(forKey: "pendingImportURL")
                groupDefaults.removeObject(forKey: "pendingImportTimestamp")
                groupDefaults.synchronize()
                return
            }
        }

        Log.info("Found pending import URL from share extension", category: .general, metadata: ["url": pendingURLString])
        DeviceLogger.shared.log("✅ [ShareExtension] Found pending import URL: \(pendingURLString)")

        // Clear it immediately to prevent re-processing
        groupDefaults.removeObject(forKey: "pendingImportURL")
        groupDefaults.removeObject(forKey: "pendingImportTimestamp")
        groupDefaults.synchronize()

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

    private func registerNotificationCategories() {
        // MARK: - Video Processing Complete Category
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_RECIPE",
            title: "Review Recipe",
            options: [.foreground]
        )

        let completeCategory = UNNotificationCategory(
            identifier: "VIDEO_PROCESSING_COMPLETE",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )

        // MARK: - Video Processing Failed Category
        let retryAction = UNNotificationAction(
            identifier: "RETRY_JOB",
            title: "Retry",
            options: [.foreground]
        )

        let viewErrorAction = UNNotificationAction(
            identifier: "VIEW_ERROR",
            title: "View Details",
            options: [.foreground]
        )

        let failedCategory = UNNotificationCategory(
            identifier: "VIDEO_PROCESSING_FAILED",
            actions: [retryAction, viewErrorAction],
            intentIdentifiers: [],
            options: []
        )

        // Register all categories
        UNUserNotificationCenter.current().setNotificationCategories([
            completeCategory,
            failedCategory
        ])

        Log.info("Notification categories registered", category: .video)
        DeviceLogger.shared.log("✅ [Notifications] Video processing categories registered")
    }

    private func cleanupOldRecipeData(container: ModelContainer) {
        let hasCleanedKey = "hasCleanedBrokenRecipeData_v4"  // v4: Parsed ingredients + proper math

        // Only run once
        guard !UserDefaults.standard.bool(forKey: hasCleanedKey) else {
            return
        }

        Task { @MainActor in
            let context = container.mainContext

            // CRITICAL FIX: Only delete user-created recipes with broken data
            // NEVER delete Heritage recipes, shared recipes, or any system recipes
            let fetchDescriptor = FetchDescriptor<Recipe>()
            if let oldRecipes = try? context.fetch(fetchDescriptor) {
                // Filter to ONLY user-created recipes (exclude Heritage, shared, system recipes)
                let recipesToDelete = oldRecipes.filter { recipe in
                    // NEVER delete Heritage recipes
                    guard !recipe.isHeritageRecipe else {
                        Log.info("🛡️ PROTECTED: Skipping Heritage recipe from cleanup", category: .database, metadata: ["title": recipe.title])
                        return false
                    }

                    // NEVER delete shared recipes
                    if let provenance = recipe.provenance, provenance.sourceType == .shared {
                        Log.info("🛡️ PROTECTED: Skipping shared recipe from cleanup", category: .database, metadata: ["title": recipe.title])
                        return false
                    }

                    // NEVER delete sample recipes
                    if recipe.isSampleRecipe {
                        Log.info("🛡️ PROTECTED: Skipping sample recipe from cleanup", category: .database, metadata: ["title": recipe.title])
                        return false
                    }

                    // Only delete plain user-created recipes
                    return true
                }

                Log.info("Cleaning up old user recipes with broken data", category: .database, metadata: [
                    "total": oldRecipes.count,
                    "toDelete": recipesToDelete.count,
                    "protected": oldRecipes.count - recipesToDelete.count
                ])

                for recipe in recipesToDelete {
                    Log.debug("Deleting old recipe", category: .database, metadata: ["title": recipe.title])
                    context.delete(recipe)
                }
                try? context.save()
            }

            // Sample recipe auto-population disabled - users can manually add via "Add Sample Recipe" button
            Log.info("Recipe data cleanup complete", category: .database)
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
        let tabCoordinator = ServiceContainer.shared.resolve(TabNavigationCoordinator.self)
        ContentView(
            tabCoordinator: tabCoordinator,
            notificationService: notificationService
        )
            .modelContainer(modelContainer)
            .environment(\.firebaseAuth, authService)
            .onAppear {
                // Start automatic sync if already authenticated on app launch
                if authService.isAuthenticated {
                    Log.info("User already authenticated on launch - starting automatic sync", category: .sync)
                    DeviceLogger.shared.log("✅ [Auth] User already authenticated - starting automatic sync")

                    // CRITICAL: Start notification listener for real-time badge updates
                    notificationService.startListening()
                    Log.info("Started notification listener on authenticated app launch", category: .firebase)

                    // Check for premium subscription (sync is premium-only)
                    let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)

                    #if DEBUG
                    // DEVELOPMENT BYPASS: Enable sync for testing without premium
                    let shouldEnableSync = true
                    Log.warning("DEBUG MODE: Bypassing premium check for sync testing", category: .sync)
                    #else
                    let shouldEnableSync = subscriptionManager.isPremium
                    #endif

                    if shouldEnableSync {
                        // Resolve sync service now (after Firebase is initialized)
                        let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                        syncService.startAutomaticSync()
                    } else {
                        Log.info("Sync requires premium subscription - not starting automatic sync", category: .sync)
                    }

                    // Heritage sync moved to AFTER recipe seeding (in ContentView and OnboardingContainerView)
                    // This ensures recipes are seeded before creating the unlock schedule
                }
            }
            .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                // When user signs in, start automatic sync
                if !oldValue && newValue {
                    Log.info("User authenticated - starting automatic Firebase sync", category: .sync)
                    DeviceLogger.shared.log("✅ [Auth] User authenticated - starting automatic sync")

                    // CRITICAL: Start notification listener for real-time badge updates
                    notificationService.startListening()
                    Log.info("Started notification listener after user sign-in", category: .firebase)

                    // Check for premium subscription (sync is premium-only)
                    let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)

                    #if DEBUG
                    // DEVELOPMENT BYPASS: Enable sync for testing without premium
                    let shouldEnableSync = true
                    Log.warning("DEBUG MODE: Bypassing premium check for sync testing", category: .sync)
                    #else
                    let shouldEnableSync = subscriptionManager.isPremium
                    #endif

                    if shouldEnableSync {
                        // Resolve sync service now (after Firebase is initialized)
                        let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                        syncService.startAutomaticSync()
                    } else {
                        Log.info("Sync requires premium subscription - not starting automatic sync", category: .sync)
                    }

                    // Heritage sync moved to AFTER recipe seeding (in ContentView and OnboardingContainerView)
                    // This ensures recipes are seeded before creating the unlock schedule
                }
            }
    }
}

struct ContentView: View {
    @State private var showAddRecipe = false
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var hasViewedRecipesList = false
    @State private var showSignInSheet = false
    @State private var needsHeritageSeeding = false
    @State private var isDownloadingHeritageAfterSignIn = false

    // Deep link coordinator (injected via environment)
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator

    // Firebase auth (injected via environment)
    @Environment(\.firebaseAuth) private var firebaseAuth

    // Tab navigation coordinator (injected from DI container)
    @ObservedObject var tabCoordinator: TabNavigationCoordinator

    // Notification service (injected from DI container)
    @ObservedObject var notificationService: FirebaseNotificationService

    // Daily unlock state
    @State private var showDailyUnlock = false
    @State private var unlockedRecipeIds: [String] = []
    @State private var currentBatch = 0
    @State private var totalBatches = 20

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainContent
            } else {
                OnboardingContainerView(
                    selectedTab: $tabCoordinator.selectedTab,
                    onComplete: {
                        hasCompletedOnboarding = true
                    }
                )
                .environmentObject(notificationService)
            }
        }
        .sheet(isPresented: $showSignInSheet) {
            FirebaseSignInView()
        }
        .onAppear {
            // CRITICAL: On first launch, require sign-in before onboarding
            if !hasCompletedOnboarding && !firebaseAuth.isAuthenticated {
                showSignInSheet = true
                needsHeritageSeeding = true
            }

            // CRITICAL: Auto-recover Heritage recipes on every app launch if user is already authenticated
            // This handles case where recipes were lost between sessions (SwiftData WAL not checkpointed)
            if firebaseAuth.isAuthenticated && hasCompletedOnboarding {
                Task { @MainActor in
                    guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
                        return
                    }
                    await autoRevealBlindBoxesIfNeeded(modelContext: modelContainer.mainContext)
                }
            }
        }
        .onChange(of: firebaseAuth.isAuthenticated) { oldValue, newValue in
            if newValue && needsHeritageSeeding {
                // CRITICAL: Download Heritage recipes BEFORE allowing access to main app
                // This ensures recipes persist because download completes before user can quit
                isDownloadingHeritageAfterSignIn = true
                Task { @MainActor in
                    await seedHeritageRecipesAfterAuth()
                    needsHeritageSeeding = false
                    isDownloadingHeritageAfterSignIn = false
                }
            }
        }
        .overlay {
            if isDownloadingHeritageAfterSignIn {
                heritageDownloadLoadingScreen
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        TabView(selection: $tabCoordinator.selectedTab) {
            CollectionsListView()
                .environmentObject(notificationService)
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Collections", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.collectionsTab)
                .accessibilityLabel("Collections")
                .accessibilityHint("View heritage and user collections")

            ShoppingListView()
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.shoppingTab)
                .accessibilityLabel("Shopping List")
                .accessibilityHint("View your shopping list with ingredients from recipes")

            DinnerPartyListView()
                .tabItem {
                    Label("Meal Planning", systemImage: "calendar")
                }
                .tag(2)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.mealPlanningTab)
                .accessibilityLabel("Meal Planning")
                .accessibilityHint("Plan and manage dinner parties")

            SettingsView()
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.settingsTab)
                .accessibilityLabel("Settings")
                .accessibilityHint("App settings and preferences")
        }
        .preferredColorScheme(.light)
        .tint(HeirloomColors.familyGreen)
        .toastContainer()
        .milestonesCelebration()
        .sheet(isPresented: $showAddRecipe) {
            RecipeEditorView()
                .environmentObject(tabCoordinator)
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
        .sheet(isPresented: $deepLinkCoordinator.showVideoImportSheet) {
            if let importID = deepLinkCoordinator.pendingVideoImportID {
                UnifiedVideoImportView(pendingImportID: importID)
                    .environmentObject(ServiceContainer.shared.resolve(SubscriptionManager.self))
                    .environmentObject(ServiceContainer.shared.resolve(PaywallManager.self))
                    .onDisappear {
                        deepLinkCoordinator.clearPendingVideoImport()
                    }
            }
        }
        .sheet(isPresented: $showDailyUnlock) {
            DailyUnlockView(
                unlockedRecipeIds: unlockedRecipeIds,
                currentBatch: currentBatch,
                totalBatches: totalBatches,
                onDismiss: {
                    showDailyUnlock = false
                }
            )
        }
        .onAppear {
            // Mark app as ready to process deep links
            Log.info("ContentView appeared - marking app ready for deep links", category: .ui)
            DeviceLogger.shared.log("✅ [App] ContentView appeared - marking app as ready for deep links")
            deepLinkCoordinator.markAppReady()

            // Set up notification observer for premium unlock
            setupPremiumUnlockObserver()

            // Check for daily unlocks
            checkForDailyUnlock()
        }
    }

    // MARK: - Daily Unlock Logic

    private func checkForDailyUnlock() {
        Task {
            do {
                // Get auth service and model container
                guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
                      authService.isAuthenticated else {
                    Log.info("Not authenticated, skipping daily unlock check", category: .firebase)
                    return
                }

                guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
                    Log.warning("ModelContainer not available, skipping daily unlock check", category: .firebase)
                    return
                }

                // Create unlock service
                let unlockService = HeritageUnlockService(
                    modelContext: modelContainer.mainContext,
                    firebaseAuth: authService
                )

                // Try to unlock daily batch
                let newlyUnlocked = try await unlockService.unlockDailyBatch()

                if !newlyUnlocked.isEmpty {
                    // Get user state for progress display
                    let userState = try await unlockService.getUserHeritageState()

                    // Show unlock UI
                    unlockedRecipeIds = newlyUnlocked
                    currentBatch = userState.currentBatch
                    totalBatches = userState.totalBatches
                    showDailyUnlock = true

                    Log.info("Daily unlock triggered", category: .firebase, metadata: [
                        "newlyUnlocked": newlyUnlocked.count,
                        "currentBatch": userState.currentBatch
                    ])
                }
            } catch {
                // Silent fail - don't interrupt user experience
                Log.warning("Daily unlock check failed", category: .firebase, metadata: ["error": error.localizedDescription])
            }
        }
    }

    // MARK: - Premium Unlock Observer

    /// Set up observer for premium status changes to unlock all heritage recipes
    private func setupPremiumUnlockObserver() {
        NotificationCenter.default.addObserver(
            forName: .userBecamePremium,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                Log.info("User became premium - unlocking all heritage recipes", category: .store)
                DeviceLogger.shared.log("✅ [Premium] User became premium - unlocking all heritage recipes")

                do {
                    // Get auth service and model container
                    guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
                          authService.isAuthenticated else {
                        Log.warning("Not authenticated, cannot unlock heritage recipes", category: .store)
                        return
                    }

                    guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
                        Log.warning("ModelContainer not available, cannot unlock heritage recipes", category: .store)
                        return
                    }

                    // Create unlock service
                    let unlockService = HeritageUnlockService(
                        modelContext: modelContainer.mainContext,
                        firebaseAuth: authService
                    )

                    // Unlock all heritage recipes
                    try await unlockService.unlockAllRecipes()

                    Log.info("All heritage recipes unlocked successfully", category: .store)
                    DeviceLogger.shared.log("✅ [Premium] All heritage recipes unlocked")

                    // Note: User will see unlocked recipes next time they browse collections
                } catch {
                    Log.error("Failed to unlock all heritage recipes", category: .store, metadata: [
                        "error": error.localizedDescription
                    ])
                    DeviceLogger.shared.log("❌ [Premium] Failed to unlock heritage recipes: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Heritage Recipe Seeding

    /// Setup heritage collections after user authentication
    /// NOTE: Recipes are NOT seeded here - they download on-demand when blind boxes are revealed
    private func seedHeritageRecipesAfterAuth() async {
        guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
            Log.warning("ModelContainer not available, cannot setup heritage collections", category: .storage)
            return
        }

        do {
            // Create heritage collections (but NO recipes)
            RecipeCollection.createHeritageCollections(context: modelContainer.mainContext)

            // Create blind boxes for onboarding
            let blindBoxSeeder = BlindBoxSeeder(modelContext: modelContainer.mainContext)
            if !blindBoxSeeder.isSeeded() {
                try blindBoxSeeder.seedBlindBoxes()
                Log.info("Heritage blind boxes created", category: .storage)
                DeviceLogger.shared.log("✅ [Heritage] Blind boxes created (no recipes downloaded)")
            }

            // CRITICAL: Check if blind boxes were already revealed on another device
            // If downloadedRecipeIds exist in Firebase, auto-reveal blind boxes and download recipes
            await autoRevealBlindBoxesIfNeeded(modelContext: modelContainer.mainContext)

            // Analytics tracking for heritage setup
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: .appLaunched, properties: ["heritage_setup": "collections_created"])
        } catch {
            Log.error("Failed to setup heritage collections", category: .storage, metadata: ["error": error.localizedDescription])
            DeviceLogger.shared.log("❌ [Heritage] Failed to setup collections: \(error.localizedDescription)")
        }
    }

    /// Check Firebase heritageState and auto-reveal blind boxes if already revealed on another device
    private func autoRevealBlindBoxesIfNeeded(modelContext: ModelContext) async {
        guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
              let userId = authService.currentUser?.uid else {
            Log.info("Not authenticated, skipping auto-reveal check", category: .heritage)
            return
        }

        // CRITICAL: Request background time to complete recovery downloads/saves
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        await MainActor.run {
            backgroundTaskID = UIApplication.shared.beginBackgroundTask {
                if backgroundTaskID != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                    backgroundTaskID = .invalid
                }
            }
        }

        defer {
            if backgroundTaskID != .invalid {
                Task { @MainActor in
                    UIApplication.shared.endBackgroundTask(backgroundTaskID)
                }
            }
        }

        do {
            let db = Firestore.firestore()
            let heritageStateDoc = try await db.collection("users").document(userId)
                .collection("heritageState").document("current").getDocument()

            guard heritageStateDoc.exists,
                  let data = heritageStateDoc.data(),
                  let downloadedRecipeIds = data["downloadedRecipeIds"] as? [String],
                  !downloadedRecipeIds.isEmpty else {
                Log.info("No existing heritage state found - blind boxes not yet revealed", category: .heritage)
                return
            }

            // Blind boxes were already revealed on another device!
            Log.info("Found existing heritage state - auto-revealing blind boxes", category: .heritage, metadata: [
                "downloadedRecipeCount": downloadedRecipeIds.count
            ])

            // Reveal all blind boxes
            let descriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate { $0.isBlindBox == true }
            )
            let blindBoxes = try modelContext.fetch(descriptor)

            for blindBox in blindBoxes {
                blindBox.isRevealed = true
                blindBox.revealedDate = Date()
            }

            try modelContext.save()

            // Download recipes that should already exist
            let onDemandService = HeritageOnDemandService(
                modelContext: modelContext,
                firebaseAuth: authService
            )

            let schedule = try await onDemandService.getUserSchedule()
            let recipes = try await onDemandService.downloadRecipesForDay(day: 1, schedule: schedule)

            Log.info("Auto-downloaded heritage recipes for revealed blind boxes", category: .heritage, metadata: [
                "recipeCount": recipes.count
            ])
            DeviceLogger.shared.log("✅ [Heritage] Auto-revealed blind boxes and downloaded \(recipes.count) recipes from other device")

            // CRITICAL: Triple-save with delays to force WAL checkpoint
            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.debug("First auto-reveal save complete", category: .heritage)

            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.debug("Second auto-reveal save complete", category: .heritage)

            try? await Task.sleep(nanoseconds: 100_000_000)
            try modelContext.save()
            Log.info("✅ Heritage auto-reveal saved to disk (3x saves)", category: .heritage)

            // Wait 3 seconds for iOS to checkpoint WAL
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            Log.info("✅ Heritage auto-reveal complete - safe to continue", category: .heritage)

        } catch {
            Log.error("Failed to auto-reveal blind boxes", category: .heritage, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    /// Elegant loading screen shown during Heritage recipe download after sign-in
    /// This blocks access to main app until recipes are downloaded and saved
    @ViewBuilder
    private var heritageDownloadLoadingScreen: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                // Heritage icon
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Setting up your Heritage recipes")
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .multilineTextAlignment(.center)

                    Text("This will only take a moment")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.3)
            }
            .padding(40)
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
        tabCoordinator: container.resolve(TabNavigationCoordinator.self),
        notificationService: container.resolve(FirebaseNotificationService.self)
    )
    .environmentObject(container.resolve(DeepLinkHandler.self))
    .modelContainer(for: Recipe.self, inMemory: true)
}
