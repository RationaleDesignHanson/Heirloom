import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import BackgroundTasks
import os.log
import FirebaseCore
import FirebaseFirestore
import FirebaseCrashlytics
import RevenueCat

// Device-visible logging
private let logger = Logger(subsystem: "com.rationaledesign.heirloom", category: "App")

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

// MARK: - App Delegate

/// AppDelegate for handling background URL session events
class HeirloomAppDelegate: NSObject, UIApplicationDelegate {

    /// Handle background URL session events
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        Log.info("Handling background URL session events", category: .network, metadata: [
            "identifier": identifier
        ])

        // TODO: Phase B - Pass completion handler to BackgroundDownloadService
        // Background downloads service not yet fully integrated
        completionHandler()
    }
}

@main
struct HeirloomApp: App {
    @UIApplicationDelegateAdaptor(HeirloomAppDelegate.self) var appDelegate
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

    // Theme unlock tracker for progressive theme recipe unlocking (resolved from DI)
    @State private var themeUnlockTracker: ThemeUnlockTracker?

    // Test environment detection - computed once at initialization
    private let isRunningTests: Bool

    // Pre-resolved services (only available in production, nil in test environment)
    @State private var authService: FirebaseAuthService?
    @State private var notificationService: FirebaseNotificationService?
    @State private var syncService: FirebaseSyncService?

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

                // Enable Crashlytics for crash reporting and monitoring
                DeviceLogger.shared.log("🔧 [Heirloom] Enabling Crashlytics...")
                Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                DeviceLogger.shared.log("✅ [Heirloom] Crashlytics enabled")
                Log.info("Crashlytics crash reporting enabled", category: .general)

                // CRITICAL: Configure Firestore settings IMMEDIATELY after first configuration
                DeviceLogger.shared.log("⚙️ [Heirloom] Configuring Firestore settings...")
                let settings = FirestoreSettings()
                settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))  // 100MB cache (~10k+ recipes)

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

        // MARK: - RevenueCat Configuration
        // NOTE: Test API key only works in DEBUG builds
        // For production, configure with production API key from RevenueCat dashboard
        #if DEBUG
        if !isRunningTests {
            DeviceLogger.shared.log("💰 [Heirloom] Configuring RevenueCat (DEBUG)...")
            Purchases.logLevel = .debug
            Purchases.configure(withAPIKey: "test_RefGbqhSIbSECFNGUGbUDnNRRNw")
            DeviceLogger.shared.log("✅ [Heirloom] RevenueCat configured")
            Log.info("RevenueCat initialized", category: .store)
        }
        #else
        // Release builds use production RevenueCat API key
        if !isRunningTests {
            DeviceLogger.shared.log("💰 [Heirloom] Configuring RevenueCat (RELEASE)...")
            Purchases.logLevel = .error  // Minimal logging in production
            Purchases.configure(withAPIKey: "appl_OobJujIDPRIrgfkTuTZvuJpMZSc")
            DeviceLogger.shared.log("✅ [Heirloom] RevenueCat configured (production)")
            Log.info("RevenueCat initialized (production)", category: .store)
        }
        #endif

        // Log active backend
        DeviceLogger.shared.log("🔧 [Heirloom] Active backend: Firebase")
        logger.info("🔧 [Heirloom] Active backend: Firebase")
        Log.info("Active backend configured", category: .firebase, metadata: ["backend": "Firebase"])

        // REGISTER BACKGROUND TASKS
        if !isRunningTests {
            registerBackgroundTasks()
        }

        print("💾 [INIT] Starting SwiftData configuration...")

        do {
            print("💾 [INIT] Getting SchemaV3.schema...")
            DeviceLogger.shared.log("🔧 [Heirloom] Configuring SwiftData schema (V3 - Source Attribution Registry)...")
            logger.info("🔧 [Heirloom] Configuring SwiftData schema (V3 - Source Attribution Registry)...")

            // Use SchemaV3 with migration plan from V1 → V2 → V3
            // V3 adds KnownSource model for source attribution registry
            let schema = SchemaV3.schema
            print("✅ [INIT] Got SchemaV3.schema successfully")

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

                DeviceLogger.shared.log("🔧 [Heirloom] Resolving FirebaseSyncService...")
                _syncService = State(wrappedValue: serviceContainer.resolve(FirebaseSyncService.self))
                print("✅ [INIT] FirebaseSyncService resolved")

                // Initialize NetworkMonitor early so it's monitoring before views need it
                DeviceLogger.shared.log("🔧 [Heirloom] Resolving NetworkMonitor...")
                _ = serviceContainer.resolve(NetworkMonitor.self)
                print("✅ [INIT] NetworkMonitor resolved")

                DeviceLogger.shared.log("🔧 [Heirloom] Resolving ThemeUnlockTracker...")
                let tracker = serviceContainer.resolve(ThemeUnlockTracker.self)
                _themeUnlockTracker = State(wrappedValue: tracker)
                print("✅ [INIT] ThemeUnlockTracker resolved")

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
                if !isRunningTests, let authService, let notificationService, let syncService, let themeUnlockTracker {
                    RootView(
                        modelContainer: modelContainer,
                        authService: authService,
                        notificationService: notificationService
                    )
                        .environmentObject(deepLinkCoordinator!)
                        .environmentObject(themeUnlockTracker)
                        .environmentObject(syncService)
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
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        // Check for pending imports when app enters foreground
                        Log.info("App entering foreground - checking for pending imports", category: .general)
                        DeviceLogger.shared.log("✅ [App] App entering foreground - checking for pending imports")
                        checkSharedContainerForPendingImport()

                        // Phase 9: Refresh badge count when returning to foreground
                        if authService.isAuthenticated {
                            Task {
                                let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                                await badgeService.refreshCount()
                                Log.debug("Badge count refreshed on foreground", category: .social)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                        // TODO: Schedule collection image refresh when implemented for theme collections
                        Log.info("App entering background", category: .general)
                        DeviceLogger.shared.log("✅ [App] Entered background")
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

        // Check for pending single URL imports that were interrupted
        checkForPendingURLImport()

        // Clean up stale data on app launch (runs in background to not block UI)
        // Note: Image cleanup is handled by JobCleanupService during daily background cleanup
        // which properly checks for orphaned images using recipe references
        if modelContainer != nil {
            Task.detached(priority: .utility) {
                // Clean up old pending imports from Share Extension (older than 30 days)
                let thirtyDaysInSeconds: TimeInterval = 30 * 24 * 60 * 60
                await PendingImportManager.shared.cleanupOldImports(olderThan: thirtyDaysInSeconds)

                // TODO: Phase B - Run full job cleanup service (jobs, video files, App Group temp files)
                // JobCleanupService not yet fully integrated

                Log.info("App launch cleanup completed", category: .general)
                DeviceLogger.shared.log("✅ [Cleanup] App launch cleanup completed")
            }
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

            // Run collections-first migration for existing users (synchronous to ensure collections exist before UI)
            let didRunMigration = CollectionsFirstMigration.runIfNeeded(context: container.mainContext)
            if didRunMigration {
                DeviceLogger.shared.log("✅ [Migration] Collections-First migration completed")
            }

            // Run community recipe ingredient migration (fixes scaling for recipes saved from discover)
            do {
                let fixedCount = try CommunityRecipeIngredientMigration.run(context: container.mainContext)
                if fixedCount > 0 {
                    DeviceLogger.shared.log("✅ [Migration] Fixed ingredients for \(fixedCount) community recipes")
                }
            } catch {
                DeviceLogger.shared.log("⚠️ [Migration] Community recipe migration failed: \(error)")
            }

            // Run source attribution migration (seeds KnownSource registry from existing recipes)
            do {
                let firebaseConfig = serviceContainer.resolve(FirebaseConfiguration.self)
                let attributionService = SourceAttributionService(
                    modelContext: container.mainContext,
                    firebaseConfig: firebaseConfig
                )
                serviceContainer.register(SourceAttributionService.self, instance: attributionService)

                let seededCount = try SourceAttributionMigration.run(
                    context: container.mainContext,
                    attributionService: attributionService
                )
                if seededCount > 0 {
                    DeviceLogger.shared.log("✅ [Migration] Seeded \(seededCount) known sources from existing recipes")
                }

                // DEBUG: Dump graph state on every launch for testing
                attributionService.dumpStats()
            } catch {
                DeviceLogger.shared.log("⚠️ [Migration] Source attribution migration failed: \(error)")
            }

            // Create system collections on first launch (synchronous - must complete before UI renders)
            RecipeCollection.createSystemCollections(context: container.mainContext)
            // Deduplicate any collections sharing the same name (idempotent)
            RecipeCollection.deduplicateCollections(context: container.mainContext)
            // Explicitly save to ensure collections are persisted before UI renders
            do {
                try container.mainContext.save()
                DeviceLogger.shared.log("✅ System collections created and saved")
            } catch {
                DeviceLogger.shared.log("⚠️ Failed to save system collections: \(error)")
            }

            // Firebase sync configuration
            Task { @MainActor in
                DeviceLogger.shared.log("🔄 [Heirloom] Configuring Firebase sync...")
                logger.info("🔄 [Heirloom] Configuring Firebase sync...")

                let syncService = serviceContainer.resolve(FirebaseSyncService.self)
                syncService.configure(modelContext: container.mainContext)

                // Set up background handling to pause/resume Firebase listeners
                // This prevents battery drain from continuous connections when backgrounded
                syncService.setupBackgroundHandling()

                // Clean up old tombstones (deleted collection records older than 30 days)
                syncService.cleanupOldTombstones(context: container.mainContext)
                Log.info("Cleaned up old tombstones on launch", category: .sync)

                // Configure UndoService with model context (needed for recipe/collection undo to work)
                let undoService = serviceContainer.resolve(UndoService.self)
                undoService.configure(modelContext: container.mainContext)
                Log.info("UndoService configured with model context", category: .database)

                DeviceLogger.shared.log("✅ [Heirloom] Firebase sync initialized")
                logger.info("✅ [Heirloom] Firebase sync initialized")
                Log.info("Firebase sync service configured", category: .firebase)
            }

            // Initialize video processing queue coordinator
            Task { @MainActor in
                let jobManager = VideoProcessingJobManager()

                // Inject ModelContext for job state persistence
                let modelContext = container.mainContext
                jobManager.setModelContext(modelContext)

                serviceContainer.register(VideoProcessingJobManager.self, instance: jobManager)

                // Resume pending jobs on app launch
                await jobManager.resumePendingJobs(context: modelContext)
                Log.info("Video processing queue coordinator initialized", category: .video)
                DeviceLogger.shared.log("✅ [Video] Queue coordinator initialized, pending jobs resumed")
            }

            // Check for interrupted PDF import jobs on app launch (shown via ContentView)
            Task { @MainActor in
                let modelContext = container.mainContext

                // Query for interrupted jobs (filter by status in memory since predicates don't support enum)
                let descriptor = FetchDescriptor<ImportJob>(
                    predicate: #Predicate<ImportJob> { job in
                        job.wasInterrupted == true
                    },
                    sortBy: [SortDescriptor(\.interruptedAt, order: .reverse)]
                )

                do {
                    let jobs = try modelContext.fetch(descriptor)
                    let resumableJobs = jobs.filter { $0.status == .processing && $0.canResume }

                    if !resumableJobs.isEmpty {
                        Log.info("Detected interrupted PDF imports", category: .import, metadata: [
                            "count": resumableJobs.count
                        ])
                        DeviceLogger.shared.log("✅ [Import] Detected \(resumableJobs.count) interrupted PDF imports - resume prompt will appear in ContentView")
                    }
                } catch {
                    Log.error("Failed to detect interrupted imports", category: .import, metadata: [
                        "error": error.localizedDescription
                    ])
                }
            }

            // Check for interrupted video jobs (logging only - marking happens in RootView.onAppear)
            Task { @MainActor in
                let modelContext = container.mainContext

                // Query for video jobs that were marked as interrupted
                let videoDescriptor = FetchDescriptor<VideoProcessingJob>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )

                do {
                    let allVideoJobs = try modelContext.fetch(videoDescriptor)
                    let interruptedVideoJobs = allVideoJobs.filter { $0.status == .processing && $0.canResume }

                    Log.info("🎬 SETUPSERVICES: Checked for interrupted video jobs", category: .video, metadata: [
                        "total_jobs": allVideoJobs.count,
                        "interrupted_count": interruptedVideoJobs.count
                    ])
                    DeviceLogger.shared.log("🎬 [Video] setupServices: Found \(interruptedVideoJobs.count) interrupted video jobs (total: \(allVideoJobs.count))")

                    if !interruptedVideoJobs.isEmpty {
                        Log.info("Detected interrupted video jobs", category: .video, metadata: [
                            "count": interruptedVideoJobs.count,
                            "job_ids": interruptedVideoJobs.map { $0.id.uuidString }
                        ])
                        DeviceLogger.shared.log("✅ [Video] Detected \(interruptedVideoJobs.count) interrupted video jobs - resume button will appear in UI")
                    }
                } catch {
                    Log.error("Failed to check for interrupted video jobs", category: .video, metadata: [
                        "error": error.localizedDescription
                    ])
                }
            }
        }
    }

    private func checkSharedContainerForPendingImport() {
        // Check if share extension left a pending URL import
        guard let groupDefaults = UserDefaults(suiteName: SharedConstants.appGroupIdentifier) else {
            Log.warning("Cannot access shared container for pending import", category: .general)
            return
        }

        // Check for pending video imports first (new Share Extension format)
        checkForPendingVideoImport(groupDefaults: groupDefaults)

        // Check for pending URL imports (old format)
        guard let pendingURLString = groupDefaults.string(forKey: "pendingImportURL"),
              URL(string: pendingURLString) != nil else {
            // No pending URL import
            return
        }

        // Check timestamp to prevent re-processing stale URLs from previous sessions
        if let timestamp = groupDefaults.object(forKey: "pendingImportTimestamp") as? Date {
            let ageInSeconds = Date().timeIntervalSince(timestamp)
            let maxAgeSeconds: TimeInterval = 86400 // 24 hours (was 5 minutes - too short, lost imports on crash)

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

    private func checkForPendingVideoImport(groupDefaults: UserDefaults) {
        // Check PendingImportManager for any pending imports
        Task {
            let pendingImports = await PendingImportManager.shared.loadAll()

            guard !pendingImports.isEmpty else {
                return
            }

            // Get the most recent import
            guard let mostRecent = pendingImports.sorted(by: { $0.createdAt > $1.createdAt }).first else {
                return
            }

            Log.info("Found pending video import from share extension", category: .general, metadata: ["importId": mostRecent.id.uuidString])
            DeviceLogger.shared.log("✅ [ShareExtension] Found pending video import: \(mostRecent.id.uuidString)")

            // Trigger deep link on main actor
            await MainActor.run {
                let importDeepLink = URL(string: "heirloom://import?id=\(mostRecent.id.uuidString)")!
                let deepLinkHandler = serviceContainer.resolve(DeepLinkHandler.self)
                deepLinkHandler.handle(importDeepLink)

                Log.info("Triggered deep link handler for video import", category: .general)
                DeviceLogger.shared.log("✅ [ShareExtension] Triggered deep link handler for video import")
            }
        }
    }

    private func checkForPendingURLImport() {
        // TODO: Phase B - Check for single URL imports that were interrupted mid-import
        // PendingURLImportManager not yet fully integrated
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

    // MARK: - Background Task Registration

    private func registerBackgroundTasks() {
        // Register video processing background task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.rationaledesign.heirloom.video-processing",
            using: nil
        ) { task in
            self.handleVideoProcessingBackgroundTask(task: task as! BGProcessingTask)
        }

        // Register daily cleanup background task
        // Cleans up old jobs, orphaned files, and App Group temp files
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.rationaledesign.heirloom.cleanup",
            using: nil
        ) { task in
            self.handleCleanupBackgroundTask(task: task as! BGProcessingTask)
        }

        // Register periodic sync refresh task (BGAppRefreshTask for lightweight sync)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.rationaledesign.heirloom.sync-refresh",
            using: nil
        ) { task in
            self.handleSyncRefreshTask(task: task as! BGAppRefreshTask)
        }

        // Register collection image refresh background task
        // NOTE: CollectionImageRefreshTask.swift must be added to the Xcode project
        if let container = modelContainer {
            let generator = ServiceContainer.shared.resolve(CollectionImageGenerator.self)
            CollectionImageRefreshTask.register(generator: generator, modelContainer: container)
            Log.info("Collection image refresh task registered", category: .general)
        }

        Log.info("Background tasks registered", category: .general)
        DeviceLogger.shared.log("✅ [BackgroundTasks] All background tasks registered (video, cleanup, sync, collection images)")

        // Schedule cleanup task to run daily
        scheduleCleanupBackgroundTask()

        // Schedule periodic sync refresh
        scheduleSyncRefreshTask()
    }

    private func handleVideoProcessingBackgroundTask(task: BGProcessingTask) {
        Log.info("Background video processing task started", category: .video)
        DeviceLogger.shared.log("🔄 [BackgroundTasks] Video processing task started")

        // Schedule expiration handler with fallback notification
        task.expirationHandler = {
            Log.warning("Background task expired", category: .video)
            DeviceLogger.shared.log("⚠️ [BackgroundTasks] Task expired, scheduling fallback notification")

            let content = UNMutableNotificationContent()
            content.title = "Processing paused"
            content.body = "Open Heirloom to continue processing your recipe."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "video_task_expired",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )
            UNUserNotificationCenter.current().add(request)

            task.setTaskCompleted(success: false)
        }

        // Get job manager and process pending jobs
        Task { @MainActor in
            guard let container = self.modelContainer else {
                task.setTaskCompleted(success: false)
                return
            }

            let jobManager = ServiceContainer.shared.resolve(VideoProcessingJobManager.self)
            let context = container.mainContext

            // Resume any pending jobs (doesn't throw - handles errors internally)
            await jobManager.resumePendingJobs(context: context)

            // Mark task as complete
            task.setTaskCompleted(success: true)
            Log.info("Background task completed successfully", category: .video)
            DeviceLogger.shared.log("✅ [BackgroundTasks] Task completed successfully")

            // Schedule next background task if there are still jobs
            scheduleNextBackgroundTask()
        }
    }

    // TODO: Implement collection image refresh task for theme collections
    // private func handleCollectionImageRefreshTask(task: BGProcessingTask) {
    //     Log.info("Collection image refresh background task started", category: .general)
    //     DeviceLogger.shared.log("🔄 [BackgroundTasks] Collection image refresh started")
    //     task.setTaskCompleted(success: false)
    // }

    private func scheduleNextBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.rationaledesign.heirloom.video-processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false // Allow on battery
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // Try again in 1 minute

        // Try to submit the task (may fail if too many tasks scheduled)
        try? BGTaskScheduler.shared.submit(request)
        Log.info("Scheduled next background task", category: .video)
        DeviceLogger.shared.log("✅ [BackgroundTasks] Scheduled next task")
    }

    // MARK: - Cleanup Background Task

    private func handleCleanupBackgroundTask(task: BGProcessingTask) {
        Log.info("Cleanup background task started", category: .general)
        DeviceLogger.shared.log("🧹 [BackgroundTasks] Cleanup task started")

        // Schedule expiration handler
        task.expirationHandler = {
            Log.warning("Cleanup background task expired", category: .general)
            DeviceLogger.shared.log("⚠️ [BackgroundTasks] Cleanup task expired")
        }

        // Perform comprehensive cleanup using JobCleanupService
        // NOTE: JobCleanupService.swift must be added to the Xcode project
        Task { @MainActor in
            guard let container = self.modelContainer else {
                task.setTaskCompleted(success: false)
                return
            }

            let context = container.mainContext

            // Use JobCleanupService for comprehensive cleanup
            // This cleans: old jobs, orphaned video files, App Group temp files, orphaned images
            let cleanupService = JobCleanupService()
            await cleanupService.performDailyCleanup(context: context)

            // Also clean old pending imports from share extension
            let thirtyDaysInSeconds: TimeInterval = 30 * 24 * 60 * 60
            await PendingImportManager.shared.cleanupOldImports(olderThan: thirtyDaysInSeconds)

            // Mark task as complete
            task.setTaskCompleted(success: true)
            Log.info("Cleanup background task completed", category: .general)
            DeviceLogger.shared.log("✅ [BackgroundTasks] Cleanup task completed")

            // Schedule next cleanup (runs daily)
            self.scheduleCleanupBackgroundTask()
        }
    }

    // MARK: - Sync Refresh Background Task

    private func handleSyncRefreshTask(task: BGAppRefreshTask) {
        Log.info("Sync refresh background task started", category: .firebase)
        DeviceLogger.shared.log("🔄 [BackgroundTasks] Sync refresh task started")

        // Schedule expiration handler
        task.expirationHandler = {
            Log.warning("Sync refresh task expired", category: .firebase)
            DeviceLogger.shared.log("⚠️ [BackgroundTasks] Sync refresh task expired")
        }

        // Perform lightweight sync
        Task { @MainActor in
            guard self.modelContainer != nil else {
                task.setTaskCompleted(success: false)
                return
            }

            // Only sync if user is authenticated
            let backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
            guard backendConfig.isFirebaseActive else {
                task.setTaskCompleted(success: true)
                self.scheduleSyncRefreshTask()
                return
            }

            do {
                // Perform a lightweight sync (fetch latest changes)
                let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                try await syncService.syncChanges()

                Log.info("Background sync completed", category: .firebase)
                DeviceLogger.shared.log("✅ [BackgroundTasks] Sync refresh completed")
                task.setTaskCompleted(success: true)
            } catch {
                Log.error("Background sync failed", category: .firebase, metadata: [
                    "error": error.localizedDescription
                ])
                DeviceLogger.shared.log("❌ [BackgroundTasks] Sync refresh failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }

            // Schedule next sync
            self.scheduleSyncRefreshTask()
        }
    }

    private func scheduleSyncRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: "com.rationaledesign.heirloom.sync-refresh")
        // Schedule for ~15 minutes from now (iOS will optimize based on usage patterns)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.info("Scheduled sync refresh task", category: .firebase)
        } catch {
            // BGAppRefreshTask may fail to schedule if user has disabled background refresh
            Log.debug("Could not schedule sync refresh task", category: .firebase, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func scheduleCleanupBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: "com.rationaledesign.heirloom.cleanup")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true // Prefer when charging to minimize battery impact
        // Schedule for tomorrow (roughly 24 hours from now)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            Log.info("Scheduled cleanup background task", category: .general)
            DeviceLogger.shared.log("✅ [BackgroundTasks] Cleanup task scheduled for ~24h from now")
        } catch {
            Log.warning("Failed to schedule cleanup background task", category: .general, metadata: [
                "error": error.localizedDescription
            ])
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

            // CRITICAL FIX: Only delete user-created recipes with broken data
            // NEVER delete Heritage recipes, shared recipes, or any system recipes
            let fetchDescriptor = FetchDescriptor<Recipe>()
            if let oldRecipes = try? context.fetch(fetchDescriptor) {
                // Filter to ONLY user-created recipes (exclude Heritage, shared, system recipes)
                let recipesToDelete = oldRecipes.filter { recipe in
                    // NEVER delete Heritage recipes
                    guard !recipe.isThemeRecipe else {
                        Log.info("🛡️ PROTECTED: Skipping Heritage recipe from cleanup", category: .database, metadata: ["title": recipe.title])
                        return false
                    }

                    // NEVER delete shared recipes
                    if recipe.provenance.sourceType == .shared {
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

    // Use the singleton from ServiceContainer so all views share the same instance
    @ObservedObject private var generationService: RecipeGenerationService = ServiceContainer.shared.resolve(RecipeGenerationService.self)

    var body: some View {
        // MANDATORY AUTH: Require Firebase authentication to access app
        // Recipes require Firebase for sync, sharing, and lineage tracking
        Group {
            if authService.isAuthenticated {
                let tabCoordinator = ServiceContainer.shared.resolve(TabNavigationCoordinator.self)
                ContentView(
                    tabCoordinator: tabCoordinator,
                    notificationService: notificationService
                )
                    .modelContainer(modelContainer)
                    .environment(\.firebaseAuth, authService)
            } else {
                // Show sign-in screen if not authenticated
                FirebaseSignInView()
                    .modelContainer(modelContainer)
                    .environment(\.firebaseAuth, authService)
            }
        }
        // Bottom banner removed - progress now shown in UnifiedProcessingBanner at top
            .onAppear {
                Log.info("🚀 ROOTVIEW.ONAPPEAR: Starting", category: .video)
                DeviceLogger.shared.log("🚀 [Video] RootView.onAppear: Starting detection tasks")

                // CRITICAL: Set up listener for user data clearing (user switch scenario)
                setupUserDataClearListener()

                // Set up listener for credit tier updates (subscription changes)
                setupCreditTierUpdateListener()

                // Mark interrupted imports on app launch
                Task {
                    await markInterruptedImportsOnLaunch(modelContainer: modelContainer)
                }

                // Mark interrupted video jobs on app launch
                Task {
                    Log.info("🎬 ROOTVIEW.ONAPPEAR: About to call video detection", category: .video)
                    DeviceLogger.shared.log("🎬 [Video] RootView.onAppear: Calling markInterruptedVideoJobsOnLaunch NOW")

                    await markInterruptedVideoJobsOnLaunch(modelContainer: modelContainer)

                    Log.info("🎬 ROOTVIEW.ONAPPEAR: Video detection task completed", category: .video)
                    DeviceLogger.shared.log("🎬 [Video] RootView.onAppear: Video detection task completed")
                }

                // Recover missed notifications for completed/failed video jobs
                Task {
                    await checkForUnnotifiedCompletedJobs(modelContainer: modelContainer)
                }

                // Start automatic sync if already authenticated on app launch
                if authService.isAuthenticated {
                    Log.info("User already authenticated on launch - starting automatic sync", category: .sync)
                    DeviceLogger.shared.log("✅ [Auth] User already authenticated - starting automatic sync")

                    // CRITICAL: Start notification listener for real-time badge updates
                    notificationService.startListening()
                    Log.info("Started notification listener on authenticated app launch", category: .firebase)

                    // Phase 9: Start badge listener for connection requests
                    let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                    badgeService.startListening()
                    Log.info("Started badge listener on authenticated app launch", category: .social)

                    // Cloud sync is now available to all users
                    // Resolve sync service now (after Firebase is initialized)
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                    syncService.startAutomaticSync()

                    // Configure deletion test account themes on launch (not just sign-in)
                    let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
                    if subscriptionManager.isDeletionTestAccount(email: authService.currentUserEmail) {
                        Log.info("Deletion test account detected on launch - configuring themes", category: .theme)
                        let themeTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
                        themeTracker.configureForDeletionTest()

                        // Re-download theme recipes if missing (happens after sign-out clears local data)
                        let context = modelContainer.mainContext
                        Task { @MainActor in
                            let selectedThemes = themeTracker.selectedThemeIds
                            guard !selectedThemes.isEmpty else { return }

                            let descriptor = FetchDescriptor<Recipe>(
                                predicate: #Predicate { $0.isThemeRecipe == true }
                            )
                            let existingCount = (try? context.fetch(descriptor).count) ?? 0
                            if existingCount > 0 { return }

                            Log.info("Theme recipes missing - re-downloading for deletion test", category: .theme)
                            let themeRecipeService = ThemeRecipeService()
                            if let recipes = try? await themeRecipeService.downloadRecipes(for: selectedThemes, into: context) {
                                try? context.save()
                                Log.info("Re-downloaded \(recipes.count) theme recipes", category: .theme)
                            }
                        }
                    }

                    // Heritage sync moved to AFTER recipe seeding (in ContentView and OnboardingContainerView)
                    // This ensures recipes are seeded before creating the unlock schedule
                    // Theme sync is handled in ContentView.onAppear via syncThemeDataOnLogin()
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

                    // Phase 9: Start badge listener for connection requests
                    let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                    badgeService.startListening()
                    Log.info("Started badge listener after user sign-in", category: .social)

                    // Cloud sync is now available to all users
                    // Resolve sync service now (after Firebase is initialized)
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)

                    // CRITICAL: Clear lastSyncDate to force full sync on sign-in
                    // This ensures all user data is downloaded, not just changes since last sync
                    UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
                    syncService.lastSyncDate = nil
                    Log.info("Cleared lastSyncDate for fresh full sync on sign-in", category: .sync)

                    syncService.startAutomaticSync()

                    // Heritage sync moved to AFTER recipe seeding (in ContentView and OnboardingContainerView)
                    // This ensures recipes are seeded before creating the unlock schedule

                    // App Store Review: Configure demo account for Apple's review
                    // - Expires any active trial so Apple sees the paywall
                    // - Zeros out credits so Apple can test credit purchases
                    // - Configures themes at day 3 so Apple can see theme content
                    let subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
                    if subscriptionManager.isDemoAccount(email: authService.currentUserEmail) {
                        Log.info("Demo account detected - configuring for App Store Review", category: .store)
                        DeviceLogger.shared.log("🍎 [AppStoreReview] Demo account sign-in - configuring for review")

                        // CRITICAL: Always skip onboarding for demo account (App Store Review)
                        // Apple reviewers should see content immediately, not onboarding
                        // Use UserDefaults directly since we're in RootView, not ContentView
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                        // Check if this is a session restoration (already configured) vs fresh sign-in
                        // If already configured AND user has purchased, don't reset - preserve purchase state
                        // This handles the case where Firebase auth state fires again during a session
                        if subscriptionManager.isDemoAccountConfigured && subscriptionManager.demoAccountHasPurchased {
                            Log.info("Demo account already configured with purchase - preserving state", category: .store)
                            DeviceLogger.shared.log("🍎 [AppStoreReview] Session restore - preserving purchase state", level: .info)
                            // Skip reset and reconfiguration - user is actively using the app
                        } else {
                            // Fresh sign-in or no purchase yet - reset for clean testing
                            subscriptionManager.resetDemoAccountPurchaseFlag()
                            subscriptionManager.configureForAppStoreReview()
                        }

                        // Configure themes at day 3 so Apple can see theme content
                        let themeTracker = ServiceContainer.shared.resolve(ThemeUnlockTracker.self)
                        themeTracker.configureForDemoAccount()
                        DeviceLogger.shared.log("🍎 [AppStoreReview] Theme trial set to day 3 with demo themes", level: .info)

                        // Set up theme collections and recipes for demo account
                        let context = modelContainer.mainContext
                        Task { @MainActor in
                            let selectedThemeIds = themeTracker.selectedThemeIds
                            guard !selectedThemeIds.isEmpty else { return }

                            // Check if theme recipes already exist
                            let recipeDescriptor = FetchDescriptor<Recipe>(
                                predicate: #Predicate { $0.isThemeRecipe == true }
                            )
                            let existingRecipeCount = (try? context.fetch(recipeDescriptor).count) ?? 0

                            if existingRecipeCount > 0 {
                                DeviceLogger.shared.log("🍎 [AppStoreReview] Theme recipes already exist (\(existingRecipeCount)), skipping setup", level: .info)
                                return
                            }

                            // Load themes from Firebase to get their metadata
                            Log.info("Loading themes from Firebase for demo account", category: .theme)
                            let themeLoader = ThemeLoader()
                            guard let themes = try? await themeLoader.loadThemes(into: context) else {
                                Log.error("Failed to load themes for demo account", category: .theme)
                                return
                            }

                            // Create theme collections for selected themes
                            let selectedThemes = themes.filter { selectedThemeIds.contains($0.firebaseId) }
                            for theme in selectedThemes {
                                // Check if collection already exists
                                let themeName = theme.name
                                let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                                    predicate: #Predicate<RecipeCollection> { collection in
                                        collection.name == themeName && collection.collectionType == "theme"
                                    }
                                )

                                if let existing = try? context.fetch(collectionDescriptor).first {
                                    existing.sourceTheme = theme
                                    existing.sourceThemeId = theme.firebaseId
                                    // Set theme cover image as collection background
                                    if let coverImageURL = theme.coverImageURL {
                                        existing.generatedBackgroundImagePath = coverImageURL
                                        existing.useCustomBackground = true
                                    }
                                    theme.collection = existing
                                } else {
                                    let collection = RecipeCollection(
                                        name: theme.name,
                                        iconName: theme.iconName,
                                        collectionType: .theme
                                    )
                                    collection.sourceTheme = theme
                                    collection.sourceThemeId = theme.firebaseId
                                    // Set theme cover image as collection background
                                    if let coverImageURL = theme.coverImageURL {
                                        collection.generatedBackgroundImagePath = coverImageURL
                                        collection.useCustomBackground = true
                                    }
                                    theme.collection = collection
                                    context.insert(collection)
                                }
                            }
                            try? context.save()
                            DeviceLogger.shared.log("🍎 [AppStoreReview] Created \(selectedThemes.count) theme collections", level: .info)

                            // Download theme recipes (will link to collections)
                            Log.info("Downloading theme recipes for demo account", category: .theme)
                            let themeRecipeService = ThemeRecipeService()
                            if let recipes = try? await themeRecipeService.downloadRecipes(for: selectedThemeIds, into: context) {
                                try? context.save()
                                Log.info("Downloaded \(recipes.count) theme recipes for demo account", category: .theme)
                                DeviceLogger.shared.log("🍎 [AppStoreReview] Downloaded \(recipes.count) theme recipes", level: .info)
                            }

                            // Ensure Favorites collection exists for demo account
                            let favoritesDescriptor = FetchDescriptor<RecipeCollection>(
                                predicate: #Predicate<RecipeCollection> { $0.name == "Favorites" }
                            )
                            if (try? context.fetch(favoritesDescriptor).first) == nil {
                                let favorites = RecipeCollection(name: "Favorites", iconName: "heart.fill", color: "#FF6B6B", isSystemCollection: true, collectionType: .system)
                                context.insert(favorites)
                                try? context.save()
                                DeviceLogger.shared.log("🍎 [AppStoreReview] Created Favorites collection", level: .info)
                            }

                            // Trigger UI refresh after theme content setup (collections + recipes as a package)
                            NotificationCenter.default.post(name: .themeContentReady, object: nil)
                            DeviceLogger.shared.log("🍎 [AppStoreReview] Posted themeContentReady notification", level: .info)
                        }

                        // Zero out credits so Apple can test credit purchases
                        Task { @MainActor in
                            do {
                                let modelContext = modelContainer.mainContext
                                if let userId = authService.currentUser?.uid {
                                    var descriptor = FetchDescriptor<UserCredits>()
                                    descriptor.predicate = #Predicate<UserCredits> { credits in
                                        credits.userId == userId
                                    }

                                    let userCredits: UserCredits
                                    if let existing = try modelContext.fetch(descriptor).first {
                                        userCredits = existing
                                        DeviceLogger.shared.log("🍎 [AppStoreReview] Found existing UserCredits record", level: .info)
                                    } else {
                                        // Create new record for demo account
                                        userCredits = UserCredits(userId: userId)
                                        modelContext.insert(userCredits)
                                        DeviceLogger.shared.log("🍎 [AppStoreReview] Created new UserCredits record for demo", level: .info)
                                    }

                                    // Zero out both tier and purchased credits
                                    // Set tier to expired FIRST so allocation is 0
                                    userCredits.tierType = "expired"
                                    userCredits.tierCreditsUsed = 0  // No tier credits used (allocation is 0 anyway)
                                    userCredits.creditsBalance = 0   // No purchased credits
                                    try modelContext.save()

                                    DeviceLogger.shared.log("🍎 [AppStoreReview] Credits zeroed: tier=expired, tierUsed=0, purchased=0, total=\(userCredits.availableCredits)", level: .info)
                                    Log.info("Credits zeroed for App Store Review demo account", category: .store)
                                }
                            } catch {
                                DeviceLogger.shared.log("🍎 [AppStoreReview] ERROR zeroing credits: \(error.localizedDescription)", level: .error)
                                Log.error("Failed to zero credits for demo account: \(error.localizedDescription)", category: .store)
                            }
                        }

                        // Profile seeding for demo account (with avatar)
                        Task { @MainActor in
                            let profileService = ServiceContainer.shared.resolve(FirebaseProfileService.self)
                            do {
                                var profile = try await profileService.fetchCurrentUserProfile()

                                // Demo account avatar - a friendly chef icon
                                // Using a stable placeholder that works for App Store Review
                                let demoAvatarURL = "https://api.dicebear.com/7.x/avataaars/png?seed=ApplePurchaseDemo&backgroundColor=b6e3f4"

                                // Update if display name or photo doesn't match expected demo values
                                var needsUpdate = false
                                if profile.displayName != "ApplePurchaseDemo" {
                                    profile.displayName = "ApplePurchaseDemo"
                                    needsUpdate = true
                                }
                                if profile.photoURL != demoAvatarURL {
                                    profile.photoURL = demoAvatarURL
                                    needsUpdate = true
                                }

                                if needsUpdate {
                                    try await profileService.updateProfile(profile)
                                    DeviceLogger.shared.log("🍎 [AppStoreReview] Profile seeded: displayName=ApplePurchaseDemo, avatar=set", level: .info)
                                    Log.info("Demo account profile seeded with display name and avatar", category: .auth)
                                } else {
                                    DeviceLogger.shared.log("🍎 [AppStoreReview] Profile already configured", level: .info)
                                }
                            } catch {
                                DeviceLogger.shared.log("🍎 [AppStoreReview] ERROR seeding profile: \(error.localizedDescription)", level: .error)
                                Log.error("Failed to seed demo account profile: \(error.localizedDescription)", category: .auth)
                            }
                        }
                    } else if subscriptionManager.isDeletionTestAccount(email: authService.currentUserEmail) {
                        // DISABLED: Self-healing code for deletion test account
                        // Re-enable when Apple needs to test: delete account → re-create → see content immediately
                        // For now, deletetest@ goes through normal onboarding to test restore from backup
                        Log.info("Deletion test account detected - self-healing DISABLED, using normal onboarding", category: .theme)
                        DeviceLogger.shared.log("🧪 [DeletionTest] Deletion test account sign-in - self-healing DISABLED")
                    } else {
                        // Tester accounts (tester01-05@) are treated as normal users
                        // They experience the full new user flow including paywall and Apple-managed trials
                        // Non-demo user: clear any demo/tester account configuration
                        // This restores normal trial behavior if device was previously used for App Store Review testing
                        if subscriptionManager.isDemoAccountConfigured {
                            subscriptionManager.clearDemoAccountConfiguration()
                            DeviceLogger.shared.log("🔄 [Auth] Cleared demo account config for non-demo user", level: .info)
                        }
                        if subscriptionManager.isTesterAccountConfigured {
                            subscriptionManager.clearTesterAccountConfiguration()
                            DeviceLogger.shared.log("🔄 [Auth] Cleared tester account config for non-tester user", level: .info)
                        }

                        // Create UserCredits for regular users on sign-in
                        if let userId = authService.currentUserId {
                            Task { @MainActor in
                                do {
                                    let modelContext = modelContainer.mainContext
                                    var descriptor = FetchDescriptor<UserCredits>()
                                    descriptor.predicate = #Predicate<UserCredits> { credits in
                                        credits.userId == userId
                                    }

                                    if try modelContext.fetch(descriptor).first == nil {
                                        let newCredits = UserCredits(userId: userId)
                                        modelContext.insert(newCredits)
                                        try modelContext.save()
                                        Log.info("Created UserCredits on sign-in", category: .store, metadata: [
                                            "userId": userId,
                                            "tierType": newCredits.tierType,
                                            "availableCredits": newCredits.availableCredits
                                        ])
                                    }
                                } catch {
                                    Log.error("Failed to create UserCredits on sign-in: \(error)", category: .store)
                                }
                            }
                        }
                    }
                }

                // When user signs out, stop listeners, sync, and clear badges
                if oldValue && !newValue {
                    Log.info("User signed out - stopping listeners and sync", category: .auth)
                    DeviceLogger.shared.log("✅ [Auth] User signed out - stopping listeners and sync")

                    // Stop automatic sync so it can restart on next sign-in
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                    syncService.stopAutomaticSync()
                    // Reset initial sync flag so loader shows on next login
                    syncService.hasCompletedInitialSync = false
                    Log.info("Stopped automatic sync and reset initial sync flag on sign out", category: .sync)

                    // Phase 9: Stop badge listener and clear badge
                    let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                    badgeService.clearBadge()
                    Log.info("Cleared badge and stopped listener on sign out", category: .social)

                    // Clear demo/tester account configuration so next login starts fresh
                    let subscriptionMgr = ServiceContainer.shared.resolve(SubscriptionManager.self)
                    subscriptionMgr.clearDemoAccountConfiguration()
                    subscriptionMgr.clearTesterAccountConfiguration()
                    Log.info("Cleared demo/tester account configuration on sign out", category: .store)
                }
            }
    }

    // MARK: - User Data Clear Listener

    /// Set up notification listener for clearing user data when different user signs in
    /// This prevents privacy leak where User B sees User A's cached recipes on same device
    private func setupUserDataClearListener() {
        let container = self.modelContainer

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ClearAllUserDataNotification"),
            object: nil,
            queue: .main
        ) { _ in
            Log.info("🧹 Received user data clear notification - clearing SwiftData", category: .auth)
            DeviceLogger.shared.log("🧹 [Auth] Clearing all SwiftData (user switch detected)")

            // Skip if we're inside a reset flow — the reset handles its own data clearing.
            // This check must be synchronous (not inside Task) because the defer block
            // in resetToFirstTimeUser sets isResetInProgress=false after return.
            let shouldSkip = MainActor.assumeIsolated {
                ScreenRecordingResetService.shared.isResetInProgress
            }
            if shouldSkip {
                Log.info("Skipping ClearAllUserData — reset flow handles its own cleanup", category: .auth)
                return
            }

            Task { @MainActor in
                do {
                    let modelContext = container.mainContext

                    // Delete all recipes
                    let recipeDescriptor = FetchDescriptor<Recipe>()
                    let allRecipes = try modelContext.fetch(recipeDescriptor)

                    Log.info("Deleting recipes from local storage", category: .auth, metadata: [
                        "count": allRecipes.count
                    ])

                    for recipe in allRecipes {
                        modelContext.delete(recipe)
                    }

                    // Delete all collections
                    let collectionDescriptor = FetchDescriptor<RecipeCollection>()
                    let allCollections = try modelContext.fetch(collectionDescriptor)

                    Log.info("Deleting collections from local storage", category: .auth, metadata: [
                        "count": allCollections.count
                    ])

                    for collection in allCollections {
                        modelContext.delete(collection)
                    }

                    // Save changes
                    try modelContext.save()

                    // Recreate system collections (All Recipes, Generated Recipes)
                    // These are local-only and never synced to Firebase
                    RecipeCollection.createSystemCollections(context: modelContext)
                    try modelContext.save()

                    Log.info("✅ Successfully cleared all user data from SwiftData", category: .auth)
                    DeviceLogger.shared.log("✅ [Auth] All user data cleared from local storage")

                } catch {
                    Log.error("Failed to clear user data from SwiftData", category: .auth, metadata: [
                        "error": error.localizedDescription
                    ])
                    DeviceLogger.shared.log("❌ [Auth] Failed to clear user data: \(error.localizedDescription)", level: .error)
                }
            }
        }

        Log.info("User data clear listener registered", category: .auth)
        DeviceLogger.shared.log("✅ [Auth] User data clear listener registered")
    }

    // MARK: - Credit Tier Update Listener

    /// Set up notification listener for credit tier updates when subscription status changes
    /// Handles trial → premium transitions with credit carry-over
    private func setupCreditTierUpdateListener() {
        let container = self.modelContainer

        NotificationCenter.default.addObserver(
            forName: .creditTierShouldUpdate,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let oldStatusRaw = userInfo["oldStatus"] as? String,
                  let newStatusRaw = userInfo["newStatus"] as? String else {
                Log.warning("Credit tier update notification missing status info", category: .store)
                return
            }

            Task { @MainActor in
                do {
                    let modelContext = container.mainContext
                    let firebaseAuth = ServiceContainer.shared.resolve(FirebaseAuthService.self)

                    // Get current user ID
                    guard let userId = firebaseAuth.currentUserId else {
                        Log.warning("No user ID found for tier update", category: .store)
                        return
                    }

                    // Fetch user credits, create if doesn't exist
                    var descriptor = FetchDescriptor<UserCredits>()
                    descriptor.predicate = #Predicate<UserCredits> { credits in
                        credits.userId == userId
                    }

                    let userCredits: UserCredits
                    if let existing = try modelContext.fetch(descriptor).first {
                        userCredits = existing
                    } else {
                        // Create new UserCredits for this user
                        let newCredits = UserCredits(userId: userId)
                        modelContext.insert(newCredits)
                        try modelContext.save()
                        userCredits = newCredits
                        Log.info("Created UserCredits for tier update", category: .store, metadata: [
                            "userId": userId,
                            "initialTier": newCredits.tierType,
                            "initialCredits": newCredits.availableCredits
                        ])
                    }

                    // Determine new tier type based on subscription status
                    let newTierType: UserCredits.TierType
                    switch newStatusRaw {
                    case "trial":
                        newTierType = .trial
                    case "monthly", "annual", "lifetime", "grace":
                        newTierType = .premium
                    case "expired", "none":
                        newTierType = .expired
                    default:
                        newTierType = .none
                    }

                    // Calculate carry-over credits if upgrading from trial to premium
                    var carryOverCredits = 0
                    if oldStatusRaw == "trial" && newTierType == .premium {
                        // Carry over remaining trial credits
                        carryOverCredits = userCredits.tierCreditsRemaining
                        Log.info("Carrying over trial credits to premium", category: .store, metadata: [
                            "carryOver": carryOverCredits
                        ])
                    }

                    // Update tier (only if it actually changed)
                    if userCredits.currentTierType != newTierType {
                        userCredits.updateTier(newTierType, resetCredits: true, carryOverCredits: carryOverCredits)
                        try modelContext.save()

                        Log.info("Credit tier updated", category: .store, metadata: [
                            "oldTier": userCredits.tierType,
                            "newTier": newTierType.rawValue,
                            "carryOver": carryOverCredits,
                            "newAvailable": userCredits.availableCredits
                        ])
                    }

                } catch {
                    Log.error("Failed to update credit tier", category: .store, metadata: [
                        "error": error.localizedDescription
                    ])
                }
            }
        }

        Log.info("Credit tier update listener registered", category: .store)
    }

    // MARK: - Interrupted Import Detection

    private func markInterruptedImportsOnLaunch(modelContainer: ModelContainer) async {
        Log.info("🔍 Starting interrupted import detection", category: .import)

        let modelContext = modelContainer.mainContext

        // Query for ALL import jobs
        let descriptor = FetchDescriptor<ImportJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let allJobs = try modelContext.fetch(descriptor)

            Log.info("📊 Fetched import jobs from database", category: .import, metadata: [
                "total_count": allJobs.count,
                "job_ids": allJobs.map { $0.id.uuidString }
            ])

            // Log detailed status of each job
            for job in allJobs {
                Log.info("📋 Import job details", category: .import, metadata: [
                    "job_id": job.id.uuidString,
                    "job_name": job.jobName ?? "unknown",
                    "status": job.status.rawValue,
                    "has_checkpoint": job.checkpoint != nil,
                    "checkpoint_can_resume": job.checkpoint?.canResume ?? false,
                    "was_interrupted": job.wasInterrupted,
                    "total_items": job.totalItems,
                    "successful_items": job.successfulItems
                ])

                // Log checkpoint details if exists
                if let checkpoint = job.checkpoint {
                    Log.info("🔖 Checkpoint details", category: .import, metadata: [
                        "job_id": job.id.uuidString,
                        "analyzed_pages_count": checkpoint.analyzedPageNumbers.count,
                        "analyzed_pages": checkpoint.analyzedPageNumbers,
                        "last_extracted_index": checkpoint.lastExtractedItemIndex ?? -1,
                        "was_interrupted": checkpoint.wasInterrupted,
                        "can_resume": checkpoint.canResume
                    ])
                }
            }

            // Find jobs that are in processing state - these were interrupted
            // Note: Force-quit doesn't allow cleanup, so checkpoint.wasInterrupted might be false
            // Instead, we detect interruption by checking if job is processing with progress made
            let interruptedJobs = allJobs.filter { job in
                let statusMatch = job.status == .processing
                let hasCheckpoint = job.checkpoint != nil
                let hasProgress = (job.checkpoint?.analyzedPageNumbers.count ?? 0) > 0 ||
                                  job.checkpoint?.lastExtractedItemIndex != nil

                Log.info("🔎 Evaluating job for interruption", category: .import, metadata: [
                    "job_id": job.id.uuidString,
                    "status_match": statusMatch,
                    "has_checkpoint": hasCheckpoint,
                    "has_progress": hasProgress,
                    "passes_filter": statusMatch && hasCheckpoint && hasProgress
                ])

                return statusMatch && hasCheckpoint && hasProgress
            }

            Log.info("✅ Finished filtering interrupted jobs", category: .import, metadata: [
                "interrupted_count": interruptedJobs.count,
                "interrupted_job_ids": interruptedJobs.map { $0.id.uuidString }
            ])

            // Mark them as interrupted if not already marked
            for job in interruptedJobs {
                if !job.wasInterrupted {
                    Log.info("🏷️ Marking job as interrupted", category: .import, metadata: [
                        "job_id": job.id.uuidString
                    ])

                    job.wasInterrupted = true
                    job.interruptedAt = Date()
                    job.checkpoint?.wasInterrupted = true
                    job.checkpoint?.interruptedAt = Date()
                }
            }

            if !interruptedJobs.isEmpty {
                try? modelContext.save()

                Log.info("💾 Detected and saved interrupted imports on launch", category: .import, metadata: [
                    "count": interruptedJobs.count,
                    "job_ids": interruptedJobs.map { $0.id.uuidString }
                ])
            } else {
                Log.info("✓ No interrupted imports found on launch", category: .import)
            }
        } catch {
            Log.error("❌ Failed to check for interrupted imports", category: .import, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    // MARK: - Interrupted Video Processing Detection

    private func markInterruptedVideoJobsOnLaunch(modelContainer: ModelContainer) async {
        Log.info("🔍 Starting interrupted video job detection", category: .video)
        DeviceLogger.shared.log("🔍 [Video] DETECTION FUNCTION CALLED - markInterruptedVideoJobsOnLaunch is executing NOW")
        print("🎬 🎬 🎬 VIDEO DETECTION STARTING - markInterruptedVideoJobsOnLaunch() 🎬 🎬 🎬")

        let modelContext = modelContainer.mainContext

        // Query for ALL video processing jobs
        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let allJobs = try modelContext.fetch(descriptor)

            Log.info("📊 Fetched video jobs from database", category: .video, metadata: [
                "total_count": allJobs.count,
                "job_ids": allJobs.map { $0.id.uuidString }
            ])

            // Log detailed status of each job
            for job in allJobs {
                Log.info("📋 Video job details", category: .video, metadata: [
                    "job_id": job.id.uuidString,
                    "status": job.status.rawValue,
                    "current_phase": job.currentPhase.rawValue,
                    "has_checkpoint": job.checkpoint != nil,
                    "was_interrupted": job.wasInterrupted,
                    "progress": job.progress
                ])

                // Log checkpoint details if exists
                if let checkpoint = job.checkpoint {
                    Log.info("🔖 Video checkpoint details", category: .video, metadata: [
                        "job_id": job.id.uuidString,
                        "has_audio": checkpoint.hasAudioExtraction,
                        "has_transcription": checkpoint.hasTranscription,
                        "has_frames": checkpoint.hasFrameAnalysis,
                        "has_recipe": checkpoint.hasStructuredRecipe,
                        "resume_phase": checkpoint.resumePhase.rawValue
                    ])
                }
            }

            // Find jobs that are in processing or pending state - these were interrupted
            // Note: resumePendingJobs() changes crashed jobs to .pending BEFORE this runs,
            // so we must check for BOTH .processing (fresh force-quit) and .pending (already resumed)
            let interruptedJobs = allJobs.filter { job in
                let statusMatch = job.status == .processing || job.status == .pending
                let hasCheckpoint = job.checkpoint != nil
                let hasProgress = job.checkpoint?.hasAudioExtraction ?? false ||
                                  job.checkpoint?.hasTranscription ?? false ||
                                  job.checkpoint?.hasFrameAnalysis ?? false ||
                                  job.checkpoint?.hasStructuredRecipe ?? false

                Log.info("🔎 Evaluating video job for interruption", category: .video, metadata: [
                    "job_id": job.id.uuidString,
                    "status": job.status.rawValue,
                    "status_match": statusMatch,
                    "has_checkpoint": hasCheckpoint,
                    "has_progress": hasProgress,
                    "passes_filter": statusMatch && hasCheckpoint && hasProgress
                ])

                return statusMatch && hasCheckpoint && hasProgress
            }

            Log.info("✅ Finished filtering interrupted video jobs", category: .video, metadata: [
                "interrupted_count": interruptedJobs.count,
                "interrupted_job_ids": interruptedJobs.map { $0.id.uuidString }
            ])

            // Mark them as interrupted if not already marked
            for job in interruptedJobs {
                if !job.wasInterrupted {
                    // Check if video file still exists
                    let videoURL = URL(fileURLWithPath: job.videoURL)
                    let fileExists = FileManager.default.fileExists(atPath: videoURL.path)

                    if fileExists {
                        // File exists - mark as interrupted for resume
                        Log.info("🏷️ Marking video job as interrupted", category: .video, metadata: [
                            "job_id": job.id.uuidString,
                            "video_path": job.videoURL
                        ])

                        job.wasInterrupted = true
                        job.interruptedAt = Date()
                    } else {
                        // File missing - mark as failed immediately
                        Log.warning("⚠️ Video file missing for interrupted job, marking as failed", category: .video, metadata: [
                            "job_id": job.id.uuidString,
                            "missing_path": job.videoURL
                        ])

                        job.status = .failed
                        job.errorType = .fileNotFound
                        job.errorMessage = "Video file was removed after app crash. Please re-import your video."
                        job.completedAt = Date()
                        job.wasInterrupted = true
                        job.interruptedAt = Date()
                    }
                }
            }

            if !interruptedJobs.isEmpty {
                try? modelContext.save()

                Log.info("💾 Detected and saved interrupted video jobs on launch", category: .video, metadata: [
                    "count": interruptedJobs.count,
                    "job_ids": interruptedJobs.map { $0.id.uuidString }
                ])
            } else {
                Log.info("✓ No interrupted video jobs found on launch", category: .video)
            }
        } catch {
            Log.error("❌ Failed to check for interrupted video jobs", category: .video, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    /// Check for completed/failed video jobs that never received a notification
    /// This catches cases where the notification scheduling failed or the app was killed before delivery
    private func checkForUnnotifiedCompletedJobs(modelContainer: ModelContainer) async {
        let modelContext = modelContainer.mainContext

        let descriptor = FetchDescriptor<VideoProcessingJob>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let allJobs = try modelContext.fetch(descriptor)

            // Find completed or failed jobs that haven't been saved/reviewed yet
            let unreviewed = allJobs.filter { job in
                (job.status == .completed || job.status == .failed) && job.status != .saved
            }

            guard !unreviewed.isEmpty else { return }

            // Check pending and delivered notifications for these job IDs
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()

            let notifiedIds = Set(
                pending.map(\.identifier) + delivered.map(\.request.identifier)
            )

            for job in unreviewed {
                let completeId = "video_job_\(job.id.uuidString)_complete"
                let failedId = "video_job_\(job.id.uuidString)_failed"

                if !notifiedIds.contains(completeId) && !notifiedIds.contains(failedId) {
                    // This job has no pending or delivered notification — schedule a recovery one
                    let content = UNMutableNotificationContent()
                    if job.status == .completed {
                        content.title = "Your recipe is ready!"
                        content.body = "Tap to review and save your extracted recipe."
                        content.categoryIdentifier = "VIDEO_PROCESSING_COMPLETE"
                    } else {
                        content.title = "Video processing failed"
                        content.body = "Tap to view error details."
                        content.categoryIdentifier = "VIDEO_PROCESSING_FAILED"
                    }
                    content.sound = .default
                    content.userInfo = ["jobId": job.id.uuidString]

                    let request = UNNotificationRequest(
                        identifier: "video_job_\(job.id.uuidString)_recovery",
                        content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
                    )

                    do {
                        try await center.add(request)
                        Log.info("Scheduled recovery notification for video job", category: .video, metadata: [
                            "jobId": job.id.uuidString,
                            "status": job.status.rawValue
                        ])
                    } catch {
                        Log.error("Failed to schedule recovery notification", category: .video, metadata: [
                            "jobId": job.id.uuidString,
                            "error": error.localizedDescription
                        ])
                    }
                }
            }
        } catch {
            Log.error("Failed to check for unnotified completed jobs", category: .video, metadata: [
                "error": error.localizedDescription
            ])
        }
    }
}

struct ContentView: View {
    @State private var showAddRecipe = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var hasViewedRecipesList = false
    @State private var showSignInSheet = false
    @State private var needsHeritageSeeding = false
    @State private var isDownloadingHeritageAfterSignIn = false

    // CRITICAL: Wait for auth state to settle before showing onboarding
    // This prevents showing onboarding to returning users before Firebase check completes
    @State private var isCheckingReturningUser = true

    // Deep link coordinator (injected via environment)
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator

    // Firebase auth (injected via environment)
    @Environment(\.firebaseAuth) private var firebaseAuth

    // Model context (injected by SwiftData)
    @Environment(\.modelContext) private var modelContext

    // Tab navigation coordinator (injected from DI container)
    @ObservedObject var tabCoordinator: TabNavigationCoordinator

    // Notification service (injected from DI container)
    @ObservedObject var notificationService: FirebaseNotificationService

    // Badge service for connection requests
    @ObservedObject var badgeService = ServiceContainer.shared.resolve(BadgeService.self)

    // Account deletion service (singleton, @Observable)
    var accountDeletionService = ServiceContainer.shared.resolve(AccountDeletionService.self)

    // Daily unlock celebration state
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @State private var showUnlockCelebration = false
    @State private var newUnlockInfo: (count: Int, themes: [String]) = (0, [])

    // Trial expired sheet state
    @State private var showTrialExpiredSheet = false
    @AppStorage("hasShownTrialExpiredView") private var hasShownTrialExpiredView = false
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainContent
                    .environment(ServiceContainer.shared.resolve(SubscriptionManager.self))
                    .environment(ServiceContainer.shared.resolve(StoreManager.self))
                    .environment(ServiceContainer.shared.resolve(PaywallManager.self))
            } else if isCheckingReturningUser {
                // Show loading while checking if returning user
                // This prevents flashing onboarding to users who have already completed it
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            } else {
                OnboardingContainerView(
                    selectedTab: $tabCoordinator.selectedTab,
                    onComplete: {
                        hasCompletedOnboarding = true

                        // Start demo social behavior service after onboarding
                        DemoSocialBehaviorService.shared.start()
                        DemoSocialBehaviorService.shared.onOnboardingComplete()
                    }
                )
                .environmentObject(notificationService)
                .environment(ServiceContainer.shared.resolve(SubscriptionManager.self))
                .environment(ServiceContainer.shared.resolve(StoreManager.self))
                .environment(ServiceContainer.shared.resolve(PaywallManager.self))
            }
        }
        .sheet(isPresented: $showSignInSheet) {
            FirebaseSignInView()
                .presentationDetents([.large])
        }
        .onAppear {
            Log.info("ContentView.onAppear", category: .auth, metadata: [
                "hasCompletedOnboarding": hasCompletedOnboarding,
                "isAuthenticated": firebaseAuth.isAuthenticated,
                "userId": firebaseAuth.currentUserId ?? "nil"
            ])

            // If already completed onboarding, we're done checking
            if hasCompletedOnboarding {
                isCheckingReturningUser = false

                // Start demo social behavior service for existing users
                DemoSocialBehaviorService.shared.start()
                DemoSocialBehaviorService.shared.onOnboardingComplete()

                // Auto-recover Heritage recipes
                if firebaseAuth.isAuthenticated {
                    Task { @MainActor in
                        guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
                            return
                        }
                        await autoRevealBlindBoxesIfNeeded(modelContext: modelContainer.mainContext)
                    }
                }
                return
            }

            // Not completed onboarding - need to check status
            Task { @MainActor in
                // If not authenticated, show sign-in sheet and wait for auth
                if !firebaseAuth.isAuthenticated {
                    Log.info("Not authenticated - showing sign-in sheet", category: .auth)
                    showSignInSheet = true
                    needsHeritageSeeding = true
                    isCheckingReturningUser = false // Allow onboarding to show (behind sign-in sheet)
                    return
                }

                // User IS authenticated but hasCompletedOnboarding is false
                // This is the RETURNING USER case - check Firebase BEFORE showing onboarding
                Log.info("Authenticated but no local onboarding flag - checking Firebase", category: .auth)

                let isReturningUser = await checkForExistingUserData()
                if isReturningUser {
                    Log.info("RETURNING USER DETECTED - skipping onboarding", category: .auth)
                    hasCompletedOnboarding = true
                    isCheckingReturningUser = false  // dismiss overlay immediately

                    // Start services for existing users
                    DemoSocialBehaviorService.shared.start()
                    DemoSocialBehaviorService.shared.onOnboardingComplete()

                    // Theme sync in background — non-blocking
                    Task { @MainActor in
                        await syncThemeDataOnLogin()
                    }
                } else {
                    // User is authenticated but has no data - show onboarding
                    Log.info("Authenticated user with no Firebase data - showing onboarding", category: .auth)
                    needsHeritageSeeding = true
                    isCheckingReturningUser = false
                }
            }
        }
        .onChange(of: firebaseAuth.isAuthenticated) { oldValue, newValue in
            Log.info("Auth state changed", category: .auth, metadata: [
                "oldValue": oldValue,
                "newValue": newValue,
                "needsHeritageSeeding": needsHeritageSeeding,
                "hasCompletedOnboarding": hasCompletedOnboarding
            ])

            // Sign-IN handling (user just signed in after seeing sign-in sheet)
            if newValue && needsHeritageSeeding {
                // CRITICAL: Check if this is a returning user
                // Show loading state while we check Firebase
                isCheckingReturningUser = true
                isDownloadingHeritageAfterSignIn = true

                Task { @MainActor in
                    // Check for existing user data before showing onboarding
                    let isReturningUser = await checkForExistingUserData()
                    if isReturningUser {
                        Log.info("RETURNING USER DETECTED (via onChange) - skipping onboarding", category: .auth)
                        hasCompletedOnboarding = true
                        needsHeritageSeeding = false
                        isDownloadingHeritageAfterSignIn = false  // dismiss overlay immediately
                        isCheckingReturningUser = false

                        // Start services for existing users
                        DemoSocialBehaviorService.shared.start()
                        DemoSocialBehaviorService.shared.onOnboardingComplete()

                        // Theme sync in background — non-blocking
                        Task { @MainActor in
                            await syncThemeDataOnLogin()
                        }
                    } else {
                        // New user - proceed with normal onboarding flow
                        Log.info("New user detected - seeding heritage and showing onboarding", category: .auth)

                        // CRITICAL: Clear stale theme data from SwiftData before onboarding
                        // This prevents "3 of 3 active" bug when device had themes from previous test sessions
                        await clearStaleThemeSelections()

                        await seedHeritageRecipesAfterAuth()
                        needsHeritageSeeding = false
                        isDownloadingHeritageAfterSignIn = false
                    }

                    // Check complete - allow view to update
                    isCheckingReturningUser = false
                }
            }

            // CRITICAL: Handle case where hasCompletedOnboarding is true but user has no Firebase data
            // This happens when: user completed onboarding, signed out, Firebase data was deleted
            // (e.g., for testing), but UserDefaults still has hasCompletedOnboarding = true.
            if newValue && hasCompletedOnboarding && !needsHeritageSeeding {
                Task { @MainActor in
                    let hasData = await checkForExistingUserData()
                    if !hasData {
                        Log.info("User marked as onboarded but has no Firebase data - resetting for re-onboarding", category: .auth)
                        hasCompletedOnboarding = false
                        needsHeritageSeeding = true
                        showSignInSheet = false // Already signed in, will show onboarding
                    }
                }
            }

            // Sign-OUT handling - show login sheet so user can sign back in
            if oldValue && !newValue {
                Log.info("User signed out - showing sign-in sheet", category: .auth)
                showSignInSheet = true
            }
        }
        .overlay {
            if isDownloadingHeritageAfterSignIn {
                heritageDownloadLoadingScreen
            }
            if accountDeletionService.isDeleting {
                accountDeletionLoadingOverlay
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

            DiscoveryView()
                .environmentObject(notificationService)
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
                .tag(1)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.discoveryTab)
                .accessibilityLabel("Discover")
                .accessibilityHint("Browse and discover community recipes")

            ShoppingListView()
                .environmentObject(tabCoordinator)
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

            KitchenTableView()
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Table", systemImage: "person.3")
                }
                .badge(badgeService.totalBadgeCount)
                .tag(4)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.tableTab)
                .accessibilityLabel("Table")
                .accessibilityHint("Kitchen table and connections")
        }
        .preferredColorScheme(.light)
        .tint(HeirloomColors.familyGreen)
        .toastContainer()
        // TODO: Re-enable milestone celebrations after redesign
        // .milestonesCelebration()
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
                .id(shareURL.absoluteString)  // Force recreation when URL changes
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showURLImportSheet) {
            if let importURL = deepLinkCoordinator.pendingImportURL {
                RecipeImportView(url: importURL)
                    .environmentObject(tabCoordinator)
                    .onDisappear {
                        deepLinkCoordinator.clearPendingImport()
                    }
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showVideoImportSheet) {
            if let importID = deepLinkCoordinator.pendingVideoImportID {
                UnifiedVideoImportView(pendingImportID: importID)
                    .onDisappear {
                        deepLinkCoordinator.clearPendingVideoImport()
                    }
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showImportProgressSheet) {
            if let jobID = deepLinkCoordinator.pendingImportJobID {
                ImportProgressSheetWrapper(jobID: jobID)
                    .onDisappear {
                        deepLinkCoordinator.clearImportProgress()
                    }
            }
        }
        // PDF approval sheet for share extension imports
        .sheet(isPresented: $deepLinkCoordinator.showPDFApprovalSheet) {
            if let pdfURL = deepLinkCoordinator.pendingApprovalPDFURL {
                PDFApprovalSheet(
                    pdfURL: pdfURL,
                    onApprove: { generateImages in
                        Task {
                            await deepLinkCoordinator.processApprovedPDF(generateImages: generateImages)
                        }
                    },
                    onCancel: {
                        Task {
                            await deepLinkCoordinator.cancelPDFApproval()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showImageRecipeSelectionSheet) {
            if let result = deepLinkCoordinator.pendingImageRecipeResult {
                RecipeSelectionView(
                    recipes: result.recipes,
                    sourceImage: result.sourceImage
                )
                .onDisappear {
                    deepLinkCoordinator.clearImageRecipeSelection()
                }
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showTextRecipeSelectionSheet) {
            if let result = deepLinkCoordinator.pendingTextRecipeResult {
                RecipeSelectionView(
                    recipes: result.recipes,
                    sourceImage: result.sourceImage
                )
                .onDisappear {
                    deepLinkCoordinator.clearTextRecipeSelection()
                }
            }
        }
        .sheet(isPresented: $deepLinkCoordinator.showConnectionInviteSheet) {
            if let userId = deepLinkCoordinator.pendingConnectionUserId {
                ConnectionInviteAcceptanceView(userId: userId)
                    .onDisappear {
                        deepLinkCoordinator.pendingConnectionUserId = nil
                        deepLinkCoordinator.showConnectionInviteSheet = false
                    }
            }
        }
        // Phase 10: Profile deep link sheet
        .sheet(isPresented: $deepLinkCoordinator.showProfileSheet) {
            if let userId = deepLinkCoordinator.pendingProfileUserId {
                PublicProfileSheet(userId: userId)
                    .onDisappear {
                        deepLinkCoordinator.clearPendingProfile()
                    }
            }
        }
        // Phase 11: Public recipe detail deep link sheet
        .sheet(isPresented: $deepLinkCoordinator.showPublicRecipeDetail) {
            if let recipeId = deepLinkCoordinator.pendingPublicRecipeId {
                PublicRecipeDetailView(publicRecipeId: recipeId)
                    .onDisappear {
                        deepLinkCoordinator.clearPendingPublicRecipe()
                    }
            }
        }
        // TODO: Re-enable for theme unlocking in Phase A3
        // .sheet(isPresented: $showDailyUnlock) {
        //     DailyUnlockView(
        //         unlockedRecipeIds: unlockedRecipeIds,
        //         currentBatch: currentBatch,
        //         totalBatches: totalBatches,
        //         onDismiss: {
        //             showDailyUnlock = false
        //         }
        //     )
        // }
        // Trial expired sheet - shown once when trial/subscription expires
        .sheet(isPresented: $showTrialExpiredSheet) {
            TrialExpiredView()
                .onDisappear {
                    // Mark as shown so we don't show again
                    hasShownTrialExpiredView = true
                }
        }
        .overlay {
            if deepLinkCoordinator.isExtractingImageRecipes {
                imageExtractionLoadingOverlay
            } else if deepLinkCoordinator.isExtractingTextRecipes {
                textExtractionLoadingOverlay
            } else if showUnlockCelebration {
                UnlockCelebrationView(
                    newRecipeCount: newUnlockInfo.count,
                    themeNames: newUnlockInfo.themes,
                    onDismiss: {
                        dismissCelebration()
                    },
                    onViewRecipes: {
                        dismissCelebration()
                        tabCoordinator.selectedTab = 0 // Navigate to Collections tab
                    }
                )
            }
        }
        .onAppear {
            // Mark app as ready to process deep links
            Log.info("ContentView appeared - marking app ready for deep links", category: .ui)
            DeviceLogger.shared.log("✅ [App] ContentView appeared - marking app as ready for deep links")
            deepLinkCoordinator.markAppReady()

            // Inject ModelContext for video job creation
            deepLinkCoordinator.setModelContext(modelContext)

            // Set up notification observer for premium unlock
            setupPremiumUnlockObserver()

            // Check for daily unlocks
            checkForDailyUnlock()

            // Check if trial/subscription has expired and show TrialExpiredView once
            checkForTrialExpired()
        }
    }

    // MARK: - Daily Unlock Logic

    private func checkForDailyUnlock() {
        guard themeUnlockTracker.checkForNewUnlocks() else { return }

        Log.info("New theme recipes unlocked - showing celebration", category: .collections)

        // Get themes with new unlocks from tracker
        Task { @MainActor in
            let themes = getThemesWithNewUnlocks()
            let count = countNewRecipes()

            if count > 0 {
                newUnlockInfo = (count, themes.map { $0.name })

                // Slight delay for better UX
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                showUnlockCelebration = true
            }
        }
    }

    private func getThemesWithNewUnlocks() -> [RecipeTheme] {
        let descriptor = FetchDescriptor<RecipeTheme>()
        guard let allThemes = try? modelContext.fetch(descriptor) else { return [] }

        return allThemes.filter { theme in
            themeUnlockTracker.isThemeSelected(theme)
        }
    }

    private func countNewRecipes() -> Int {
        // Count newly unlocked recipes
        // This is a simplified implementation - in production you'd track which recipes are "new"
        return themeUnlockTracker.unlockedRecipeIds.count
    }

    private func dismissCelebration() {
        withAnimation {
            showUnlockCelebration = false
        }
        themeUnlockTracker.markUnlocksAsSeen()
    }

    // MARK: - Trial Expired Check

    /// Check if trial/subscription has expired and show TrialExpiredView once
    /// This gives users clear options after their trial ends
    private func checkForTrialExpired() {
        // Only show once
        guard !hasShownTrialExpiredView else { return }

        // Check if subscription status is expired
        guard subscriptionManager.status == .expired else { return }

        // Don't show if user has never been a subscriber (no entitlement history)
        // This prevents showing to brand new free users
        // The expired status means they HAD a subscription/trial that ended
        Log.info("Trial/subscription expired - showing TrialExpiredView", category: .store)
        DeviceLogger.shared.log("📋 [Store] Showing TrialExpiredView for expired subscription")

        // Slight delay for better UX (let the main content load first)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
            showTrialExpiredSheet = true
        }
    }

    // MARK: - Premium Unlock Observer

    /// Set up observer for premium status changes to unlock all theme recipes
    /// TODO: Re-implement for theme unlocking in Phase A3
    private func setupPremiumUnlockObserver() {
        // Capture modelContext for use in closure
        // let context = modelContext
        //
        // NotificationCenter.default.addObserver(
        //     forName: .userBecamePremium,
        //     object: nil,
        //     queue: .main
        // ) { _ in
        //     Task { @MainActor in
        //         Log.info("User became premium - unlocking all theme recipes", category: .store)
        //         DeviceLogger.shared.log("✅ [Premium] User became premium - unlocking all theme recipes")
        //
        //         do {
        //             // Get auth service
        //             guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
        //                   authService.isAuthenticated else {
        //                 Log.warning("Not authenticated, cannot unlock theme recipes", category: .store)
        //                 return
        //             }
        //
        //             // Create unlock service with captured modelContext
        //             let unlockService = ThemeUnlockService(
        //                 modelContext: context,
        //                 firebaseAuth: authService
        //             )
        //
        //             // Unlock all theme recipes
        //             try await unlockService.unlockAllRecipes()
        //
        //             Log.info("All theme recipes unlocked successfully", category: .store)
        //             DeviceLogger.shared.log("✅ [Premium] All theme recipes unlocked")
        //
        //             // Note: User will see unlocked recipes next time they browse collections
        //         } catch {
        //             Log.error("Failed to unlock all theme recipes", category: .store, metadata: [
        //                 "error": error.localizedDescription
        //             ])
        //             DeviceLogger.shared.log("❌ [Premium] Failed to unlock theme recipes: \(error.localizedDescription)")
        //         }
        //     }
        // }
    }

    // MARK: - Theme Recipe Seeding

    /// Setup theme collections after user authentication
    /// NOTE: Recipes are NOT seeded here - they download on-demand after theme selection
    /// TODO: Re-implement for theme system in Phase B2
    private func seedHeritageRecipesAfterAuth() async {
        // guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
        //     Log.warning("ModelContainer not available, cannot setup theme collections", category: .storage)
        //     return
        // }
        //
        // // DISABLED: Collections now created dynamically when recipes download
        // // This ensures Collections tab is empty initially, showing "Download Today's Recipes" button
        // // RecipeCollection.createThemeCollections(context: modelContainer.mainContext)
        //
        // // DISABLED: Blind boxes removed - replaced with theme selection during onboarding
        // // Collections appear progressively as recipes are downloaded over 14 days
        //
        // // CRITICAL: Check if collections were already created on another device
        // // If downloadedRecipeIds exist in Firebase, recreate collections and download recipes
        // await autoRevealThemesIfNeeded(modelContext: modelContainer.mainContext)
        //
        // // Analytics tracking for theme setup
        // let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
        // analytics.track(event: .appLaunched, properties: ["theme_setup": "collections_created"])
    }

    /// Sync theme data on login for returning users
    /// This loads RecipeTheme objects from Firebase and downloads theme recipes
    /// so that theme collections appear automatically without requiring UI interaction
    private func syncThemeDataOnLogin() async {
        // Step 0: ALWAYS restore theme selections from Firebase first
        // This doesn't need ModelContainer and must happen before anything else
        var restoredFromFirebase = false
        if let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self) {
            restoredFromFirebase = await profileService.restoreThemeSelectionsFromFirebase()
            if restoredFromFirebase {
                Log.info("Restored theme selections from Firebase profile", category: .theme)
                // Force ThemeUnlockTracker to reload from UserDefaults
                themeUnlockTracker.objectWillChange.send()
            }
        }

        // Step 1+: Download recipes requires ModelContainer
        guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
            Log.warning("ModelContainer not available for theme recipe download - will sync on next refresh", category: .theme)
            return
        }

        let modelContext = modelContainer.mainContext

        do {

            // Step 1: Load RecipeTheme objects from Firebase into SwiftData
            // (same as done during onboarding in OnboardingContainerView)
            let loader = ThemeLoader()
            let themes = try await loader.loadThemes(into: modelContext)
            Log.info("Loaded themes from Firebase on login", category: .theme, metadata: [
                "themeCount": themes.count
            ])

            // Step 1.5: Clear and restore theme selections
            // IMPORTANT: ALWAYS clear all theme selections to remove stale data from previous sessions
            // RecipeTheme objects persist in SwiftData across sign-out (unlike Recipe/RecipeCollection),
            // so we must reset user-specific data before applying any Firebase-restored values.
            // This fixes the bug where theme counter shows "3 of 3 active" instead of "1 of 3"
            // after switching accounts or fresh sign-in.

            // Always clear existing theme selections first
            var clearedCount = 0
            for theme in themes {
                if theme.addedDate != nil || theme.isSelected {
                    theme.addedDate = nil
                    theme.isSelected = false
                    clearedCount += 1
                }
            }
            if clearedCount > 0 {
                Log.info("Cleared stale theme selections on sign-in", category: .theme, metadata: [
                    "clearedCount": clearedCount
                ])
            }

            // Now apply restored values from Firebase (if any)
            if let profileService = ServiceContainer.shared.resolveOptional(FirebaseUserProfileService.self),
               !profileService.restoredThemeAddedDates.isEmpty {
                for theme in themes {
                    if let addedDate = profileService.restoredThemeAddedDates[theme.firebaseId] {
                        theme.addedDate = addedDate
                        theme.isSelected = true
                        Log.info("Restored theme addedDate", category: .theme, metadata: [
                            "themeId": theme.firebaseId,
                            "addedDate": addedDate.description
                        ])
                    }
                }
            }

            try modelContext.save()

            // Step 2: Download theme recipes for selected themes
            // Read directly from UserDefaults to ensure we get freshly restored values
            // (themeUnlockTracker.selectedThemeIds is a computed property but may have caching)
            let selectedThemeIds: [String]
            if restoredFromFirebase {
                // Read directly from UserDefaults to avoid any caching issues
                selectedThemeIds = UserDefaults.standard.stringArray(forKey: "selected_theme_ids") ?? []
                Log.info("Using freshly restored theme IDs from UserDefaults", category: .theme, metadata: [
                    "themeIds": selectedThemeIds.joined(separator: ", ")
                ])
            } else {
                selectedThemeIds = themeUnlockTracker.selectedThemeIds
            }

            guard !selectedThemeIds.isEmpty else {
                Log.info("No selected themes after restore - user may need to re-select themes", category: .theme)
                return
            }

            Log.info("Downloading theme recipes for selected themes", category: .theme, metadata: [
                "selectedThemes": selectedThemeIds.count,
                "themeIds": selectedThemeIds.joined(separator: ", ")
            ])

            let recipeService = ThemeRecipeService()
            let recipes = try await recipeService.downloadRecipes(for: selectedThemeIds, into: modelContext)

            try modelContext.save()

            Log.info("Theme sync complete on login", category: .theme, metadata: [
                "themesLoaded": themes.count,
                "recipesDownloaded": recipes.count,
                "wasRestoredFromFirebase": restoredFromFirebase
            ])

        } catch {
            Log.error("Failed to sync themes on login", category: .theme, error: error)
        }
    }

    /// Clear stale theme selections from SwiftData
    /// Called for new users to prevent "3 of 3 active" bug from previous test sessions
    private func clearStaleThemeSelections() async {
        guard let modelContainer = ServiceContainer.shared.resolveOptional(ModelContainer.self) else {
            Log.warning("Cannot clear themes - ModelContainer not ready", category: .theme)
            return
        }

        let modelContext = modelContainer.mainContext

        do {
            let descriptor = FetchDescriptor<RecipeTheme>()
            let themes = try modelContext.fetch(descriptor)

            var clearedCount = 0
            for theme in themes {
                if theme.addedDate != nil || theme.isSelected {
                    theme.addedDate = nil
                    theme.isSelected = false
                    clearedCount += 1
                }
            }

            if clearedCount > 0 {
                try modelContext.save()
                Log.info("Cleared stale theme selections for new user", category: .theme, metadata: [
                    "clearedCount": clearedCount
                ])
            }
        } catch {
            Log.error("Failed to clear stale theme selections", category: .theme, error: error)
        }
    }

    /// Check if user has existing data in Firebase (returning user on new device)
    /// Returns true if user has completed onboarding before, indicating they should skip it
    private func checkForExistingUserData() async -> Bool {
        guard let userId = firebaseAuth.currentUserId else {
            return false
        }

        let db = Firestore.firestore()

        do {
            // FIRST: Check for hasCompletedOnboarding flag in user profile
            // This is the authoritative source - survives sign-out/sign-in cycles
            let profileDoc = try await db.collection("users").document(userId)
                .collection("profile").document("data").getDocument()

            let profileExists = profileDoc.exists
            let profileData = profileDoc.data()
            let hasCompletedFlag = profileData?["hasCompletedOnboarding"] as? Bool

            Log.info("Checking Firebase profile for onboarding state", category: .auth, metadata: [
                "userId": userId,
                "profileExists": profileExists,
                "hasData": profileData != nil,
                "hasCompletedOnboarding": hasCompletedFlag as Any
            ])

            if let hasCompleted = hasCompletedFlag, hasCompleted {
                Log.info("User has completed onboarding (from profile) - returning user detected", category: .auth, metadata: [
                    "userId": userId
                ])
                return true
            }

            // FALLBACK: Check for existing recipes (for users who completed onboarding before this fix)
            let recipesQuery = db.collection("users").document(userId).collection("recipes").limit(to: 1)
            let recipesSnapshot = try await recipesQuery.getDocuments()

            if !recipesSnapshot.isEmpty {
                Log.info("Found existing recipes for user - returning user detected", category: .auth, metadata: [
                    "userId": userId
                ])
                // Migrate: Set the flag for next time
                try? await db.collection("users").document(userId)
                    .collection("profile").document("data")
                    .setData(["hasCompletedOnboarding": true], merge: true)
                return true
            }

            Log.info("No onboarding flag or recipes found - new user (will show onboarding)", category: .auth, metadata: ["userId": userId])
            return false

        } catch {
            Log.error("Failed to check for existing user data", category: .auth, error: error)
            // On error, assume new user to be safe (don't skip onboarding)
            return false
        }
    }

    /// Check Firebase heritageState and recreate collections if already downloaded on another device
    /// NOTE: With blind boxes disabled, this ensures multi-device sync still works
    /// TODO: Re-implement for theme system in Phase A3 - sync theme state across devices
    private func autoRevealBlindBoxesIfNeeded(modelContext: ModelContext) async {
        // guard let authService = ServiceContainer.shared.resolveOptional(FirebaseAuthService.self),
        //       let userId = authService.currentUser?.uid else {
        //     Log.info("Not authenticated, skipping auto-reveal check", category: .theme)
        //     return
        // }
        //
        // // CRITICAL: Request background time to complete recovery downloads/saves
        // var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        // await MainActor.run {
        //     backgroundTaskID = UIApplication.shared.beginBackgroundTask {
        //         if backgroundTaskID != .invalid {
        //             UIApplication.shared.endBackgroundTask(backgroundTaskID)
        //             backgroundTaskID = .invalid
        //         }
        //     }
        // }
        //
        // defer {
        //     if backgroundTaskID != .invalid {
        //         Task { @MainActor in
        //             UIApplication.shared.endBackgroundTask(backgroundTaskID)
        //         }
        //     }
        // }
        //
        // do {
        //     let db = Firestore.firestore()
        //     let themeStateDoc = try await db.collection("users").document(userId)
        //         .collection("themeState").document("current").getDocument()
        //
        //     guard themeStateDoc.exists,
        //           let data = themeStateDoc.data(),
        //           let downloadedRecipeIds = data["downloadedRecipeIds"] as? [String],
        //           !downloadedRecipeIds.isEmpty else {
        //         Log.info("No existing theme state found", category: .theme)
        //         return
        //     }
        //
        //     // Theme recipes were already downloaded on another device!
        //     Log.info("Found existing theme state - syncing recipes", category: .theme, metadata: [
        //         "downloadedRecipeCount": downloadedRecipeIds.count
        //     ])
        //
        //     // Download recipes that should already exist
        //     let themeService = ThemeRecipeService(
        //         modelContext: modelContext,
        //         firebaseAuth: authService
        //     )
        //
        //     let recipes = try await themeService.syncRecipesFromFirebase()
        //
        //     Log.info("Auto-synced theme recipes from other device", category: .theme, metadata: [
        //         "recipeCount": recipes.count
        //     ])
        //     DeviceLogger.shared.log("✅ [Theme] Auto-synced \(recipes.count) recipes from other device")
        //
        //     // Save with retry logic
        //     try? await Task.sleep(nanoseconds: 100_000_000)
        //     try modelContext.save()
        //
        //     try? await Task.sleep(nanoseconds: 100_000_000)
        //     try modelContext.save()
        //
        //     Log.info("✅ Theme auto-sync complete", category: .theme)
        //
        // } catch {
        //     Log.error("Failed to auto-sync themes", category: .theme, metadata: [
        //         "error": error.localizedDescription
        //     ])
        // }
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

    /// Blocking overlay shown during account deletion
    /// Fully opaque to hide underlying UI (user cannot interact during deletion)
    @ViewBuilder
    private var accountDeletionLoadingOverlay: some View {
        ZStack {
            // Fully opaque background - hides underlying UI completely
            HeirloomColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: HeirloomSpacing.lg) {
                Image(systemName: "person.crop.circle.badge.minus")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)

                VStack(spacing: HeirloomSpacing.sm) {
                    Text(accountDeletionService.progress.currentStep.displayText)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Please don't close the app")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                    .scaleEffect(1.3)
            }
            .padding(40)
        }
    }

    /// Loading overlay shown during image recipe extraction
    @ViewBuilder
    private var imageExtractionLoadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Card-based loading UI
            VStack(spacing: HeirloomSpacing.lg) {
                // Recipe icon
                Image(systemName: "doc.text.image")
                    .font(.system(size: 56))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(spacing: HeirloomSpacing.sm) {
                    Text(deepLinkCoordinator.imageExtractionProgress)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("This may take a moment")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                    .scaleEffect(1.3)
            }
            .padding(HeirloomSpacing.xl)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .shadow(
                color: HeirloomShadows.card.color,
                radius: HeirloomShadows.card.radius,
                x: HeirloomShadows.card.x,
                y: HeirloomShadows.card.y
            )
            .padding(HeirloomSpacing.xl)
        }
    }

    /// Loading overlay shown during text recipe extraction from Notes
    @ViewBuilder
    private var textExtractionLoadingOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            // Card-based loading UI
            VStack(spacing: HeirloomSpacing.lg) {
                // Recipe icon
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(HeirloomColors.tomato)

                VStack(spacing: HeirloomSpacing.sm) {
                    Text(deepLinkCoordinator.textExtractionProgress)
                        .font(HeirloomFonts.title3)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("This may take a moment")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                    .scaleEffect(1.3)
            }
            .padding(HeirloomSpacing.xl)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .shadow(
                color: HeirloomShadows.card.color,
                radius: HeirloomShadows.card.radius,
                x: HeirloomShadows.card.x,
                y: HeirloomShadows.card.y
            )
            .padding(HeirloomSpacing.xl)
        }
    }
}

// MARK: - Import Progress Sheet Wrapper

/// Wrapper view to fetch ImportJob by ID and show ImportProgressView
private struct ImportProgressSheetWrapper: View {
    let jobID: UUID

    @Environment(\.modelContext) private var modelContext
    @Query private var allJobs: [ImportJob]

    private var job: ImportJob? {
        allJobs.first { $0.id == jobID }
    }

    var body: some View {
        if let job = job {
            NavigationStack {
                ImportProgressView(
                    manager: ServiceContainer.shared.resolve(ImportJobManager.self),
                    job: job
                )
            }
        } else {
            NavigationStack {
                ContentUnavailableView(
                    "Import Not Found",
                    systemImage: "doc.questionmark",
                    description: Text("The import job could not be found.")
                )
            }
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
