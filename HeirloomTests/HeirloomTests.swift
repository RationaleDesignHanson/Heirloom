//
//  HeirloomTests.swift
//  HeirloomTests
//
//  Created by Matt Hanson on 12/27/25.
//

import XCTest
@testable import Heirloom

/// Global test suite setup - runs once before ALL tests
@MainActor
final class HeirloomTests: XCTestCase {

    /// Shared flag to ensure ServiceContainer is only initialized once for the entire test suite
    private static var isServiceContainerInitialized = false
    private static let initializationQueue = DispatchQueue(label: "com.heirloom.tests.init")

    override class func setUp() {
        super.setUp()

        // Initialize ServiceContainer once for ALL tests in the suite
        initializationQueue.sync {
            if !isServiceContainerInitialized {
                print("\n🧪 ========================================")
                print("🧪 [HeirloomTests] Initializing ServiceContainer for test suite...")
                print("🧪 ========================================\n")

                // Import test service registration extension
                ServiceContainer.shared.registerTestServices()

                isServiceContainerInitialized = true
                print("\n✅ ========================================")
                print("✅ [HeirloomTests] ServiceContainer initialized successfully")
                print("✅ ========================================\n")
            }
        }
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        measure {
            // Put the code you want to measure the time of here.
        }
    }

}

// MARK: - Test Service Registration

extension ServiceContainer {

    /// Register services configured for testing with minimal dependencies
    /// This is a minimal registration that only includes services actually used by tests
    func registerTestServices() {
        let logger = HeirloomLogger()
        logger.log("Registering test services...", category: .general, level: .info)

        // MARK: - Logging
        register(LoggingService.self, lifecycle: .singleton) { _ in
            HeirloomLogger()
        }

        register(DeviceLogger.self, lifecycle: .singleton) { _ in
            DeviceLogger()
        }

        // MARK: - Configuration
        register(BackendConfig.self, lifecycle: .singleton) { _ in
            BackendConfig()
        }

        // MARK: - Firebase Core (Test Configuration)
        register(FirebaseConfiguration.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return FirebaseConfiguration(logger: logger)
        }

        register(FirebaseRecordConverter.self, lifecycle: .singleton) { _ in
            FirebaseRecordConverter()
        }

        // MARK: - Firebase Services

        register(FirebaseAuthService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            return FirebaseAuthService(configuration: config, logger: logger)
        }

        register(FirebaseImageService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            return FirebaseImageService(configuration: config, logger: logger)
        }

        register(FirebaseCollectionSync.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            let converter = container.resolve(FirebaseRecordConverter.self)
            return FirebaseCollectionSync(
                configuration: config,
                converter: converter,
                logger: logger
            )
        }

        register(FirebaseLineageService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return FirebaseLineageService(logger: logger)
        }

        register(FirebaseRecipeSync.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            let converter = container.resolve(FirebaseRecordConverter.self)
            let imageService = container.resolve(FirebaseImageService.self)
            let collectionSync = container.resolve(FirebaseCollectionSync.self)
            let lineageService = container.resolve(FirebaseLineageService.self)
            return FirebaseRecipeSync(
                configuration: config,
                converter: converter,
                imageService: imageService,
                collectionSync: collectionSync,
                lineageService: lineageService,
                logger: logger
            )
        }

        // MARK: - Analytics
        register(AnalyticsService.self, lifecycle: .singleton) { _ in
            AnalyticsService()
        }

        // MARK: - CRDT
        register(CRDTMergeEngine.self, lifecycle: .singleton) { _ in
            CRDTMergeEngine()
        }

        // MARK: - Sync Services (Complex dependencies)

        // FirebaseSyncService needs to be registered before FirebaseShareService
        register(FirebaseSyncService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            let recipeSync = container.resolve(FirebaseRecipeSync.self)
            let collectionSync = container.resolve(FirebaseCollectionSync.self)
            let imageService = container.resolve(FirebaseImageService.self)
            let lineageService = container.resolve(FirebaseLineageService.self)
            let crdtMergeEngine = container.resolve(CRDTMergeEngine.self)
            return FirebaseSyncService(
                configuration: config,
                recipeSync: recipeSync,
                collectionSync: collectionSync,
                imageService: imageService,
                lineageService: lineageService,
                logger: logger,
                crdtMergeEngine: crdtMergeEngine
            )
        }

        register(FirebaseShareService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            let firebaseSync = container.resolve(FirebaseSyncService.self)
            let lineageService = container.resolve(FirebaseLineageService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return FirebaseShareService(
                configuration: config,
                logger: logger,
                firebaseSync: firebaseSync,
                lineageService: lineageService,
                analytics: analytics
            )
        }

        register(FirebaseNotificationService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            return FirebaseNotificationService(configuration: config, logger: logger)
        }

        logger.log("Test services registered successfully", category: .general, level: .info)
    }
}
