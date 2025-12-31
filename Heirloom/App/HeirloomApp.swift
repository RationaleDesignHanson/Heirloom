import SwiftUI
import SwiftData
import UserNotifications
import os.log
import FirebaseCore

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
        DeviceLogger.shared.log("✅ [Heirloom] Firebase initialized successfully")
        logger.info("✅ [Heirloom] Firebase initialized successfully")
        print("✅ Firebase initialized")

        // Log active backend
        let backend = BackendConfig.shared.activeBackend
        DeviceLogger.shared.log("🔧 [Heirloom] Active backend: \(backend.rawValue)")
        logger.info("🔧 [Heirloom] Active backend: \(backend.rawValue)")
        print("🔧 Active backend: \(backend.rawValue)")

        do {
            DeviceLogger.shared.log("🔧 [Heirloom] Configuring SwiftData schema...")
            logger.info("🔧 [Heirloom] Configuring SwiftData schema...")

            // Use versioned schema for future migrations
            let schema = SchemaV1.schema

            // Configure for LOCAL ONLY storage
            // CloudKit sync is handled manually by CloudKitSyncService
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none  // Manual sync - no automatic CloudKit
            )

            let container = try ModelContainer(
                for: schema,
                configurations: config
            )

            DeviceLogger.shared.log("✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)")
            logger.info("✅ [Heirloom] SwiftData initialized (Local storage, manual CloudKit sync)")
            print("✅ SwiftData initialized (Local storage, manual CloudKit sync)")

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
                        deepLinkCoordinator.handle(url)
                    }
                    .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                        print("📱 WindowGroup received user activity")
                        logger.info("📱 WindowGroup received user activity")
                        deepLinkCoordinator.handle(userActivity)
                    }
            } else {
                DataErrorView()
            }
        }
    }

    private func setupServices() {
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

            // PHASE 2: CloudKit enabled with comprehensive logging
            // Configure and start CloudKit sync (hybrid architecture)
            Task { @MainActor in
                DeviceLogger.shared.log("🔄 [Heirloom] Configuring CloudKit sync...")
                logger.info("🔄 [Heirloom] Configuring CloudKit sync...")

                CloudKitSyncService.shared.configure(modelContext: container.mainContext)
                CloudKitSyncService.shared.startAutomaticSync()

                DeviceLogger.shared.log("✅ [Heirloom] CloudKit sync initialized successfully")
                logger.info("✅ [Heirloom] CloudKit sync initialized successfully")
                print("✅ CloudKit sync initialized")
            }

            // PHASE 3: Firebase sync configuration (when Firebase backend is active)
            if BackendConfig.shared.isFirebaseActive {
                Task { @MainActor in
                    DeviceLogger.shared.log("🔄 [Heirloom] Configuring Firebase sync...")
                    logger.info("🔄 [Heirloom] Configuring Firebase sync...")

                    FirebaseSyncService.shared.configure(modelContext: container.mainContext)

                    DeviceLogger.shared.log("✅ [Heirloom] Firebase sync initialized successfully")
                    logger.info("✅ [Heirloom] Firebase sync initialized successfully")
                    print("✅ Firebase sync initialized")
                }
            }
        }
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

    // Network & Sync monitoring for badges
    private let syncCoordinator = CloudKitSyncCoordinator.shared

    // Deep link coordinator (injected via environment)
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed.fill")
                }
                .tag(0)
                .accessibilityIdentifier(AccessibilityIdentifiers.TabBar.recipesTab)
                .accessibilityLabel("Recipes")
                .accessibilityHint("View and manage your recipe collection")

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
                .badge(syncCoordinator.pendingOperations.count)
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            // Mark app as ready to process deep links
            print("✅ ContentView appeared - marking app as ready for deep links")
            deepLinkCoordinator.markAppReady()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DeepLinkCoordinator.shared)
        .modelContainer(for: Recipe.self, inMemory: true)
}
