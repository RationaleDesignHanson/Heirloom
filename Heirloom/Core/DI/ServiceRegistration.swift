//
//  ServiceRegistration.swift
//  Heirloom
//
//  Central registration of all services in the DI container
//

import Foundation

extension ServiceContainer {

    /// Register all production services
    func registerProductionServices() {
        let logger = HeirloomLogger.shared
        logger.log("Registering production services...", category: .general, level: .info)

        // MARK: - Logging (singleton instance, already created)
        register(LoggingService.self, instance: HeirloomLogger.shared)

        // MARK: - Configuration
        register(BackendConfigProtocol.self, lifecycle: .singleton) { _ in
            BackendConfig.shared
        }

        // MARK: - Firebase Core
        register(FirebaseConfigurationProtocol.self, lifecycle: .singleton) { _ in
            FirebaseConfiguration.shared
        }

        register(FirebaseRecordConverterProtocol.self, lifecycle: .singleton) { _ in
            FirebaseRecordConverter()
        }

        // MARK: - Firebase Services

        // FirebaseAuthService (concrete type for ObservableObject)
        register(FirebaseAuthService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            return FirebaseAuthService(configuration: config, logger: logger)
        }

        // FirebaseAuthService protocol (resolves to same instance)
        register(FirebaseAuthServiceProtocol.self, lifecycle: .singleton) { container in
            container.resolve(FirebaseAuthService.self)
        }

        register(FirebaseImageServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            return FirebaseImageService(configuration: config, logger: logger)
        }

        register(FirebaseCollectionSyncProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            let converter = container.resolve(FirebaseRecordConverterProtocol.self)
            return FirebaseCollectionSync(
                configuration: config,
                converter: converter,
                logger: logger
            )
        }

        register(FirebaseRecipeSyncProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            let converter = container.resolve(FirebaseRecordConverterProtocol.self)
            let imageService = container.resolve(FirebaseImageServiceProtocol.self)
            return FirebaseRecipeSync(
                configuration: config,
                converter: converter,
                imageService: imageService,
                logger: logger
            )
        }

        register(FirebaseShareServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            return FirebaseShareService(configuration: config, logger: logger)
        }

        // FirebaseSyncService (concrete type)
        register(FirebaseSyncService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            let recipeSync = container.resolve(FirebaseRecipeSyncProtocol.self)
            let collectionSync = container.resolve(FirebaseCollectionSyncProtocol.self)
            let imageService = container.resolve(FirebaseImageServiceProtocol.self)
            return FirebaseSyncService(
                configuration: config,
                recipeSync: recipeSync,
                collectionSync: collectionSync,
                imageService: imageService,
                logger: logger
            )
        }

        // FirebaseSyncService protocol (resolves to same instance)
        register(FirebaseSyncServiceProtocol.self, lifecycle: .singleton) { container in
            container.resolve(FirebaseSyncService.self)
        }

        // FirebaseNotificationService (concrete type for ObservableObject)
        register(FirebaseNotificationService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfigurationProtocol.self)
            return FirebaseNotificationService(configuration: config, logger: logger)
        }

        // FirebaseNotificationService protocol (resolves to same instance)
        register(FirebaseNotificationServiceProtocol.self, lifecycle: .singleton) { container in
            container.resolve(FirebaseNotificationService.self)
        }

        // FirebaseLineageService
        register(FirebaseLineageServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseSync = container.resolve(FirebaseSyncServiceProtocol.self)
            return FirebaseLineageService(firebaseSync: firebaseSync, logger: logger)
        }

        // MARK: - Network
        register(NetworkMonitorProtocol.self, lifecycle: .singleton) { _ in
            NetworkMonitor.shared
        }

        // MARK: - Analytics
        register(AnalyticsServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return AnalyticsService(logger: logger)
        }

        // MARK: - Storage
        register(ImageStorageServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseImage = container.resolve(FirebaseImageServiceProtocol.self)
            return ImageStorageService(
                firebaseImageService: firebaseImage,
                logger: logger
            )
        }

        register(ImageCacheProtocol.self, lifecycle: .singleton) { _ in
            ImageCache.shared
        }

        // MARK: - Recipe Services
        register(RecipeImportServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let networkMonitor = container.resolve(NetworkMonitorProtocol.self)
            return RecipeImportService(
                networkMonitor: networkMonitor,
                logger: logger
            )
        }

        register(RecipeVersionServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseSync = container.resolve(FirebaseSyncServiceProtocol.self)
            return RecipeVersionService(
                firebaseSync: firebaseSync,
                logger: logger
            )
        }

        register(RecipeExportServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return RecipeExportService(logger: logger)
        }

        register(RecipeMigrationServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return RecipeMigrationService(logger: logger)
        }

        register(RecipeLineageServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseSync = container.resolve(FirebaseSyncServiceProtocol.self)
            return RecipeLineageService(
                firebaseSync: firebaseSync,
                logger: logger
            )
        }

        // MARK: - AI Services
        register(AIConfigurationProtocol.self, lifecycle: .singleton) { _ in
            AIConfiguration.shared
        }

        register(AIRecipeExtractorProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(AIConfigurationProtocol.self)
            return AIRecipeExtractor(configuration: config, logger: logger)
        }

        register(AIIngredientParserProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(AIConfigurationProtocol.self)
            return AIIngredientParser(configuration: config, logger: logger)
        }

        register(AIRecipeDetectorProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(AIConfigurationProtocol.self)
            return AIRecipeDetector(configuration: config, logger: logger)
        }

        // MARK: - OCR
        register(OCRServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return EnhancedOCRService(logger: logger)
        }

        // MARK: - Deep Linking
        register(DeepLinkHandlerProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseShare = container.resolve(FirebaseShareServiceProtocol.self)
            return DeepLinkHandler(
                firebaseShare: firebaseShare,
                logger: logger
            )
        }

        // MARK: - Comments
        register(CommentServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseSync = container.resolve(FirebaseSyncServiceProtocol.self)
            return CommentService(
                firebaseSync: firebaseSync,
                logger: logger
            )
        }

        // MARK: - CRDT
        register(CRDTMergeEngineProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return CRDTMergeEngine(logger: logger)
        }

        // MARK: - Reminders
        register(RemindersServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return RemindersService(logger: logger)
        }

        // MARK: - Undo
        register(UndoServiceProtocol.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return UndoService(logger: logger)
        }

        // MARK: - Toast
        register(ToastManagerProtocol.self, lifecycle: .singleton) { _ in
            ToastManager.shared
        }

        logger.log(
            "Service registration complete: \(registeredServices.count) services",
            category: .general,
            level: .info
        )
    }

    /// Register mock services for testing
    func registerMockServices() {
        let logger = HeirloomLogger.shared
        logger.log("Registering mock services for testing...", category: .general, level: .info)

        // Mock services will be registered here as we create them
        // For now, register real services as placeholders

        registerProductionServices()

        logger.log("Mock service registration complete", category: .general, level: .info)
    }

    /// Register preview services for SwiftUI previews
    func registerPreviewServices() {
        let logger = HeirloomLogger.shared
        logger.log("Registering preview services...", category: .general, level: .debug)

        // Preview services will use mocks when available
        // For now, use production services

        registerProductionServices()

        logger.log("Preview service registration complete", category: .general, level: .debug)
    }
}

// MARK: - Supporting Protocols

protocol BackendConfigProtocol {
    var useFirebase: Bool { get }
    var environment: String { get }
}
