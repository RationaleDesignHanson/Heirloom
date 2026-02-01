import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks
import os.log
import FirebaseCore
import FirebaseFirestore
import FirebaseCrashlytics

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

        // REGISTER BACKGROUND TASKS
        if !isRunningTests {
            registerBackgroundTasks()
        }

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

                DeviceLogger.shared.log("🔧 [Heirloom] Resolving FirebaseSyncService...")
                _syncService = State(wrappedValue: serviceContainer.resolve(FirebaseSyncService.self))
                print("✅ [INIT] FirebaseSyncService resolved")

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

                // TODO: Theme collections will be created during onboarding theme selection
                DeviceLogger.shared.log("✅ System collections created")
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

        // TODO: Register collection image refresh background task when implemented for theme collections
        // BGTaskScheduler.shared.register(
        //     forTaskWithIdentifier: CollectionImageRefreshTask.taskIdentifier,
        //     using: nil
        // ) { task in
        //     self.handleCollectionImageRefreshTask(task: task as! BGProcessingTask)
        // }

        Log.info("Background tasks registered", category: .general)
        DeviceLogger.shared.log("✅ [BackgroundTasks] Video processing task registered")
    }

    private func handleVideoProcessingBackgroundTask(task: BGProcessingTask) {
        Log.info("Background video processing task started", category: .video)
        DeviceLogger.shared.log("🔄 [BackgroundTasks] Video processing task started")

        // Schedule expiration handler
        task.expirationHandler = {
            Log.warning("Background task expired", category: .video)
            DeviceLogger.shared.log("⚠️ [BackgroundTasks] Task expired, will resume on foreground")
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
            .onAppear {
                Log.info("🚀 ROOTVIEW.ONAPPEAR: Starting", category: .video)
                DeviceLogger.shared.log("🚀 [Video] RootView.onAppear: Starting detection tasks")

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

                    // Phase 9: Start badge listener for connection requests
                    let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                    badgeService.startListening()
                    Log.info("Started badge listener after user sign-in", category: .social)

                    // Cloud sync is now available to all users
                    // Resolve sync service now (after Firebase is initialized)
                    let syncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
                    syncService.startAutomaticSync()

                    // Heritage sync moved to AFTER recipe seeding (in ContentView and OnboardingContainerView)
                    // This ensures recipes are seeded before creating the unlock schedule
                }

                // When user signs out, stop listeners and clear badges
                if oldValue && !newValue {
                    Log.info("User signed out - stopping listeners", category: .auth)
                    DeviceLogger.shared.log("✅ [Auth] User signed out - stopping listeners")

                    // Phase 9: Stop badge listener and clear badge
                    let badgeService = ServiceContainer.shared.resolve(BadgeService.self)
                    badgeService.clearBadge()
                    Log.info("Cleared badge and stopped listener on sign out", category: .social)
                }
            }
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
                    Log.info("🏷️ Marking video job as interrupted", category: .video, metadata: [
                        "job_id": job.id.uuidString
                    ])

                    job.wasInterrupted = true
                    job.interruptedAt = Date()
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

    // Model context (injected by SwiftData)
    @Environment(\.modelContext) private var modelContext

    // Tab navigation coordinator (injected from DI container)
    @ObservedObject var tabCoordinator: TabNavigationCoordinator

    // Notification service (injected from DI container)
    @ObservedObject var notificationService: FirebaseNotificationService

    // Daily unlock celebration state
    @EnvironmentObject private var themeUnlockTracker: ThemeUnlockTracker
    @State private var showUnlockCelebration = false
    @State private var newUnlockInfo: (count: Int, themes: [String]) = (0, [])

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainContent
                    .environment(ServiceContainer.shared.resolve(SubscriptionManager.self))
                    .environment(ServiceContainer.shared.resolve(StoreManager.self))
                    .environment(ServiceContainer.shared.resolve(PaywallManager.self))
            } else {
                OnboardingContainerView(
                    selectedTab: $tabCoordinator.selectedTab,
                    onComplete: {
                        hasCompletedOnboarding = true
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

            SettingsView()
                .environmentObject(tabCoordinator)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
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
