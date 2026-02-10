//
//  ServiceRegistration.swift
//  Heirloom
//
//  Central registration of all services in the DI container
//

import Foundation
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

extension ServiceContainer {

    /// Register all production services
    func registerProductionServices() {
        let logger = HeirloomLogger()
        logger.log("Registering production services...", category: .general, level: .info)

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

        // MARK: - Feature Management
        // TODO: Re-enable after fixing module visibility
        // register(FeatureFlagManager.self, lifecycle: .singleton) { _ in
        //     FeatureFlagManager.shared
        // }

        // MARK: - Firebase Core
        register(FirebaseConfiguration.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            return FirebaseConfiguration(logger: logger)
        }

        // TODO: Register protocol once service fully implements it
        // register(FirebaseConfigurationProtocol.self, lifecycle: .singleton) { _ in
        //     FirebaseConfiguration.shared
        // }

        register(FirebaseRecordConverter.self, lifecycle: .singleton) { _ in
            FirebaseRecordConverter()
        }

        // TODO: Register protocol once service fully implements it
        // register(FirebaseRecordConverterProtocol.self, lifecycle: .singleton) { container in
        //     container.resolve(FirebaseRecordConverter.self)
        // }

        // MARK: - Firebase Services

        // FirebaseAuthService (concrete type for ObservableObject)
        register(FirebaseAuthService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            let authService = FirebaseAuthService(configuration: config, logger: logger)

            // Connect user profile service for display name syncing
            let profileService = container.resolve(FirebaseUserProfileService.self)
            authService.setUserProfileService(profileService)

            return authService
        }

        register((any FirebaseAuthServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseAuthService.self) as any FirebaseAuthServiceProtocol
        }

        register(FirebaseImageService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            return FirebaseImageService(configuration: config, logger: logger)
        }

        register((any FirebaseImageServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseImageService.self) as any FirebaseImageServiceProtocol
        }

        register(FirebaseImageGenerationService.self, lifecycle: .singleton) { _ in
            FirebaseImageGenerationService()
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

        register((any FirebaseCollectionSyncProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseCollectionSync.self) as any FirebaseCollectionSyncProtocol
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

        register((any FirebaseRecipeSyncProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseRecipeSync.self) as any FirebaseRecipeSyncProtocol
        }

        // FirebaseShareService (concrete type)
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

        register((any FirebaseShareServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseShareService.self) as any FirebaseShareServiceProtocol
        }

        // FirebaseSyncService (concrete type)
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

        register((any FirebaseSyncServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseSyncService.self) as any FirebaseSyncServiceProtocol
        }

        // FirebaseNotificationService (concrete type for ObservableObject)
        register(FirebaseNotificationService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let config = container.resolve(FirebaseConfiguration.self)
            return FirebaseNotificationService(configuration: config, logger: logger)
        }

        register((any FirebaseNotificationServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseNotificationService.self) as any FirebaseNotificationServiceProtocol
        }

        // FirebaseUserProfileService
        register(FirebaseUserProfileService.self, lifecycle: .singleton) { _ in
            FirebaseUserProfileService()
        }

        // MARK: - Social Services (Phase 3)

        // ProfileService (concrete type)
        register(FirebaseProfileService.self, lifecycle: .singleton) { _ in
            FirebaseProfileService()
        }

        register((any ProfileServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseProfileService.self) as any ProfileServiceProtocol
        }

        // ConnectionService (concrete type)
        register(FirebaseConnectionService.self, lifecycle: .singleton) { _ in
            FirebaseConnectionService()
        }

        register((any ConnectionServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseConnectionService.self) as any ConnectionServiceProtocol
        }

        // BadgeService (Phase 9)
        register(BadgeService.self, lifecycle: .singleton) { container in
            let connectionService = container.resolve((any ConnectionServiceProtocol).self)
            return BadgeService(connectionService: connectionService)
        }

        // SearchService (Algolia)
        register(AlgoliaSearchService.self, lifecycle: .singleton) { _ in
            AlgoliaSearchService()
        }

        register((any SearchServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AlgoliaSearchService.self) as any SearchServiceProtocol
        }

        // FirebaseLineageService
        register(FirebaseLineageService.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let profileService = container.resolve(FirebaseUserProfileService.self)
            return FirebaseLineageService(logger: logger, userProfileService: profileService)
        }

        register((any FirebaseLineageServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseLineageService.self) as any FirebaseLineageServiceProtocol
        }

        // MARK: - Network
        register(NetworkMonitor.self, lifecycle: .singleton) { _ in
            NetworkMonitor()
        }

        register((any NetworkMonitorProtocol).self, lifecycle: .singleton) { container in
            container.resolve(NetworkMonitor.self) as any NetworkMonitorProtocol
        }

        // MARK: - Analytics
        register(AnalyticsService.self, lifecycle: .singleton) { _ in
            AnalyticsService()
        }

        register((any AnalyticsServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AnalyticsService.self) as any AnalyticsServiceProtocol
        }

        // ShareAnalyticsService (Phase 1: Inter-Heirloom Sharing Analytics)
        register(ShareAnalyticsService.self, lifecycle: .singleton) { _ in
            ShareAnalyticsService()
        }

        // MARK: - Subscription Services
        register(StoreManager.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return StoreManager(logger: logger, analytics: analytics)
        }

        register(SubscriptionManager.self, lifecycle: .singleton) { container in
            let storeManager = container.resolve(StoreManager.self)
            let logger = container.resolve(LoggingService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return SubscriptionManager(
                storeManager: storeManager,
                logger: logger,
                analytics: analytics
            )
        }

        register(PaywallManager.self, lifecycle: .singleton) { container in
            let subscriptionManager = container.resolve(SubscriptionManager.self)
            let logger = container.resolve(LoggingService.self)
            let analytics = container.resolve(AnalyticsService.self)
            return PaywallManager(
                subscriptionManager: subscriptionManager,
                logger: logger,
                analytics: analytics
            )
        }

        // MARK: - Storage
        register(ImageCache.self, lifecycle: .singleton) { _ in
            ImageCache()
        }

        register((any ImageCacheProtocol).self, lifecycle: .singleton) { container in
            container.resolve(ImageCache.self) as any ImageCacheProtocol
        }

        register(ImageStorageService.self, lifecycle: .singleton) { container in
            let imageCache = container.resolve(ImageCache.self)
            return ImageStorageService(imageCache: imageCache)
        }

        // MARK: - Recipe Services
        register(RecipeImportService.self, lifecycle: .singleton) { _ in
            RecipeImportService()
        }

        register(CloudRecipeImportService.self, lifecycle: .singleton) { container in
            let importService = container.resolve(RecipeImportService.self)
            let languageService = container.resolve(LanguageDetectionService.self)
            return CloudRecipeImportService(importService: importService, languageService: languageService)
        }

        register(LanguageDetectionService.self, lifecycle: .singleton) { _ in
            LanguageDetectionService()
        }

        register(RecipeVersionService.self, lifecycle: .singleton) { _ in
            RecipeVersionService()
        }

        register(RecipeExportService.self, lifecycle: .singleton) { container in
            let toastManager = container.resolve(ToastManager.self)
            let ingredientFormatter = container.resolve(IngredientFormatter.self)
            return RecipeExportService(toastManager: toastManager, ingredientFormatter: ingredientFormatter)
        }

        register(RecipeExporter.self, lifecycle: .singleton) { _ in
            RecipeExporter()
        }

        // HeirloomDataExporter (Phase 3 - v2 export with social data)
        register(HeirloomDataExporter.self, lifecycle: .singleton) { container in
            let profileService = container.resolve((any ProfileServiceProtocol).self)
            let connectionService = container.resolve((any ConnectionServiceProtocol).self)
            let recipeExporter = container.resolve(RecipeExporter.self)
            return HeirloomDataExporter(
                profileService: profileService,
                connectionService: connectionService,
                recipeExporter: recipeExporter
            )
        }

        register(RecipeMigrationService.self, lifecycle: .singleton) { _ in
            RecipeMigrationService()
        }

        // RecipeLineageService
        register(RecipeLineageService.self, lifecycle: .singleton) { container in
            let userProfileService = container.resolve(FirebaseUserProfileService.self)
            return RecipeLineageService(userProfileService: userProfileService)
        }

        // HeritageUnlockService - Note: Requires modelContext at init, instantiate directly where needed
        // Example: HeritageUnlockService(modelContext: modelContext, firebaseAuth: authService)

        register(RecipeStructureParser.self, lifecycle: .singleton) { _ in
            RecipeStructureParser()
        }

        register(CategoryDetectionService.self, lifecycle: .singleton) { _ in
            CategoryDetectionService()
        }

        register(ScalingEngine.self, lifecycle: .singleton) { _ in
            ScalingEngine()
        }

        register(TrendingService.self, lifecycle: .singleton) { _ in
            TrendingService()
        }

        // MARK: - Public Recipe Discovery Services (Phase 11)

        // PublicRecipeService - Manages publishing recipes to public discovery
        register(FirebasePublicRecipeService.self, lifecycle: .singleton) { container in
            let profileService = container.resolve((any ProfileServiceProtocol).self)
            let imageService = container.resolve(ImageStorageService.self)
            return FirebasePublicRecipeService(
                profileService: profileService,
                imageService: imageService
            )
        }

        register((any PublicRecipeServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebasePublicRecipeService.self) as any PublicRecipeServiceProtocol
        }

        // DiscoveryService - Manages fetching and searching public recipes
        register(FirebaseDiscoveryService.self, lifecycle: .singleton) { _ in
            FirebaseDiscoveryService()
        }

        register((any DiscoveryServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseDiscoveryService.self) as any DiscoveryServiceProtocol
        }

        // DuplicateDetectionService - Detects duplicate recipes using content hashing
        register(DuplicateDetectionService.self, lifecycle: .singleton) { _ in
            DuplicateDetectionService()
        }

        register(DinnerPartyShoppingSync.self, lifecycle: .singleton) { _ in
            DinnerPartyShoppingSync()
        }

        // MARK: - Card Customization Services

        // CardCustomizationService - Manages stickers, drawings, text, photos, shapes on recipe cards
        register(CardCustomizationService.self, lifecycle: .singleton) { _ in
            CardCustomizationService()
        }

        // StickerLibraryService - Manages sticker library with 70+ stickers across 7 categories
        register(StickerLibraryService.self, lifecycle: .singleton) { _ in
            StickerLibraryService()
        }

        // HeritageRecipeCleanupService - Manages cleanup of unmodified heritage recipes after 30 days
        register(HeritageRecipeCleanupService.self, lifecycle: .singleton) { _ in
            HeritageRecipeCleanupService()
        }

        // ThemeUnlockTracker - Manages progressive unlock of theme recipes during trial
        register(ThemeUnlockTracker.self, lifecycle: .singleton) { _ in
            ThemeUnlockTracker()
        }

        // ThemeRecipeCache - Durable cache for theme recipes (survives force-quit)
        // register(ThemeRecipeCache.self, lifecycle: .singleton) { _ in
        //     ThemeRecipeCache()
        // }

        // ThemeRecipeService - Note: Requires modelContext at init, instantiate directly where needed
        // Example: ThemeRecipeService(modelContext: modelContext, firebaseAuth: authService)

        // MARK: - AI Services

        // Keychain
        register(Keychain.self, lifecycle: .singleton) { _ in
            Keychain()
        }

        // AIConfiguration
        register(AIConfiguration.self, lifecycle: .singleton) { container in
            let analytics = container.resolve(AnalyticsService.self)
            let keychain = container.resolve(Keychain.self)
            return AIConfiguration(analytics: analytics, keychain: keychain)
        }

        // UnitsConfiguration
        register(UnitsConfiguration.self, lifecycle: .singleton) { _ in
            UnitsConfiguration()
        }

        // VisualStyleConfiguration
        register(VisualStyleConfiguration.self, lifecycle: .singleton) { _ in
            VisualStyleConfiguration()
        }

        // MeasurementConversionService - stateless singleton
        register(MeasurementConversionService.self, lifecycle: .singleton) { _ in
            MeasurementConversionService()
        }

        // IngredientFormatter - depends on UnitsConfiguration
        register(IngredientFormatter.self, lifecycle: .singleton) { container in
            let unitsConfig = container.resolve(UnitsConfiguration.self)
            return IngredientFormatter(unitsConfig: unitsConfig)
        }

        // AIUsageTracker
        register(AIUsageTracker.self, lifecycle: .singleton) { container in
            let analytics = container.resolve(AnalyticsService.self)
            let aiConfig = container.resolve(AIConfiguration.self)
            return AIUsageTracker(analytics: analytics, aiConfiguration: aiConfig)
        }

        register((any AIConfigurationProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AIConfiguration.self) as any AIConfigurationProtocol
        }

        // MARK: AI Service - Firebase Gateway (Secure)
        // Uses Firebase Cloud Functions to proxy AI requests - NO API KEYS IN CLIENT

        // FirebaseAIGatewayService (Secure AI provider via Firebase Functions)
        register(FirebaseAIGatewayService.self, lifecycle: .singleton) { container in
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let usageTracker = container.resolve(AIUsageTracker.self)
            return FirebaseAIGatewayService(configuration: configuration, usageTracker: usageTracker)
        }

        register((any AIServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(FirebaseAIGatewayService.self) as any AIServiceProtocol
        }

        // Legacy: AnthropicAIService (Direct API - DEPRECATED, API keys in client)
        // Keeping for rollback if needed during migration
        register(AnthropicAIService.self, lifecycle: .singleton) { container in
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let usageTracker = container.resolve(AIUsageTracker.self)
            return AnthropicAIService(configuration: configuration, usageTracker: usageTracker)
        }

        // AIRecipeExtractor (Recipe extraction from OCR/images)
        register(AIRecipeExtractor.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve(AnalyticsService.self)
            let googleVisionService = container.resolve(FirebaseGoogleVisionService.self)
            return AIRecipeExtractor(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics,
                googleVisionService: googleVisionService
            )
        }

        register((any AIRecipeExtractorProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AIRecipeExtractor.self) as any AIRecipeExtractorProtocol
        }

        // AIIngredientParser (Ingredient parsing)
        register(AIIngredientParser.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve((any AnalyticsServiceProtocol).self)
            return AIIngredientParser(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics
            )
        }

        register((any AIIngredientParserProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AIIngredientParser.self) as any AIIngredientParserProtocol
        }

        // AIIngredientSpellChecker (Spell checking)
        register(AIIngredientSpellChecker.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve(AnalyticsService.self)
            return AIIngredientSpellChecker(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics
            )
        }

        // DinnerPartySummaryService (Dinner party planning)
        register(DinnerPartySummaryService.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve(AnalyticsService.self)
            return DinnerPartySummaryService(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics
            )
        }

        register((any DinnerPartySummaryServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(DinnerPartySummaryService.self) as any DinnerPartySummaryServiceProtocol
        }

        // ShoppingListSummaryService (Shopping list optimization)
        register(ShoppingListSummaryService.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve(AnalyticsService.self)
            return ShoppingListSummaryService(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics
            )
        }

        register((any ShoppingListSummaryServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(ShoppingListSummaryService.self) as any ShoppingListSummaryServiceProtocol
        }

        // RecipeTimelineCalculator (Timeline calculation)
        register(RecipeTimelineCalculator.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            let analytics = container.resolve(AnalyticsService.self)
            return RecipeTimelineCalculator(
                aiService: aiService,
                configuration: configuration,
                analytics: analytics
            )
        }

        register((any RecipeTimelineCalculatorProtocol).self, lifecycle: .singleton) { container in
            container.resolve(RecipeTimelineCalculator.self) as any RecipeTimelineCalculatorProtocol
        }

        // AIRecipeDetector
        register(AIRecipeDetector.self, lifecycle: .singleton) { container in
            let aiConfig = container.resolve(AIConfiguration.self)
            let aiService = container.resolve((any AIServiceProtocol).self)
            return AIRecipeDetector(aiConfig: aiConfig, aiService: aiService)
        }

        // MARK: Google Vision OCR - Firebase Gateway (Secure)
        // Uses Firebase Cloud Functions - NO API KEYS IN CLIENT

        // FirebaseGoogleVisionService (Secure OCR via Firebase Functions)
        register(FirebaseGoogleVisionService.self, lifecycle: .singleton) { _ in
            FirebaseGoogleVisionService()
        }

        // Legacy: GoogleVisionOCRService (Direct API - DEPRECATED, API keys in client)
        // Keeping for rollback if needed during migration
        register(GoogleVisionOCRService.self, lifecycle: .singleton) { container in
            let aiConfig = container.resolve(AIConfiguration.self)
            guard let apiKey = aiConfig.googleVisionAPIKey() else {
                // Return a dummy service if API key not configured (using Firebase gateway now)
                return GoogleVisionOCRService(apiKey: "")
            }
            return GoogleVisionOCRService(apiKey: apiKey)
        }

        // MARK: Brave Search - Firebase Gateway (Secure)
        // Uses Firebase Cloud Functions for web recipe search - NO API KEYS IN CLIENT

        // FirebaseBraveSearchService (Secure web search via Firebase Functions)
        register(FirebaseBraveSearchService.self, lifecycle: .singleton) { _ in
            FirebaseBraveSearchService()
        }

        // CollectionImageGenerator (DALL-E collection backgrounds via Firebase)
        register(CollectionImageGenerator.self, lifecycle: .singleton) { container in
            let imageStorage = container.resolve(ImageStorageService.self)
            let styleConfig = container.resolve(VisualStyleConfiguration.self)
            let firebaseService = container.resolve(FirebaseImageGenerationService.self)
            return CollectionImageGenerator(imageStorage: imageStorage, styleConfig: styleConfig, firebaseService: firebaseService)
        }

        // AIRecipeGenerator (AI recipe generation from minimal input)
        register(AIRecipeGenerator.self, lifecycle: .singleton) { container in
            let aiService = container.resolve((any AIServiceProtocol).self)
            let configuration = container.resolve((any AIConfigurationProtocol).self)
            return AIRecipeGenerator(aiService: aiService, configuration: configuration)
        }

        register((any AIRecipeGeneratorProtocol).self, lifecycle: .singleton) { container in
            container.resolve(AIRecipeGenerator.self) as any AIRecipeGeneratorProtocol
        }

        // RecipeImageGenerator (DALL-E recipe image generation via Firebase)
        register(RecipeImageGenerator.self, lifecycle: .singleton) { container in
            let styleConfig = container.resolve(VisualStyleConfiguration.self)
            let firebaseService = container.resolve(FirebaseImageGenerationService.self)
            return RecipeImageGenerator(styleConfig: styleConfig, firebaseService: firebaseService)
        }

        register((any RecipeImageGeneratorProtocol).self, lifecycle: .singleton) { container in
            container.resolve(RecipeImageGenerator.self) as any RecipeImageGeneratorProtocol
        }

        // ImageGenerationQueue (Serial background queue for AI image generation)
        register(ImageGenerationQueue.self, lifecycle: .singleton) { container in
            let imageGenerator = container.resolve((any RecipeImageGeneratorProtocol).self)
            return ImageGenerationQueue(imageGenerator: imageGenerator)
        }

        // RecipeGenerationService (Recipe generation with progress tracking and retry logic)
        register(RecipeGenerationService.self, lifecycle: .singleton) { container in
            let aiGenerator = container.resolve((any AIRecipeGeneratorProtocol).self)
            let imageGenerator = container.resolve((any RecipeImageGeneratorProtocol).self)
            let aiService = container.resolve((any AIServiceProtocol).self)
            let aiConfiguration = container.resolve((any AIConfigurationProtocol).self)
            let imageGenerationQueue = container.resolve(ImageGenerationQueue.self)
            return RecipeGenerationService(
                aiGenerator: aiGenerator,
                imageGenerator: imageGenerator,
                aiService: aiService,
                aiConfiguration: aiConfiguration,
                imageGenerationQueue: imageGenerationQueue
            )
        }

        // VoiceDictationService (Speech recognition for voice recipe dictation)
        register(VoiceDictationService.self, lifecycle: .singleton) { _ in
            VoiceDictationService()
        }

        register((any VoiceDictationServiceProtocol).self, lifecycle: .singleton) { container in
            container.resolve(VoiceDictationService.self) as any VoiceDictationServiceProtocol
        }

        // MARK: - OCR
        // Note: EnhancedOCRService doesn't fully implement OCRServiceProtocol yet
        // Registering concrete type only for now
        register(EnhancedOCRService.self, lifecycle: .singleton) { _ in
            EnhancedOCRService()
        }

        // MARK: - Deep Linking
        // Note: DeepLinkHandler doesn't fully implement DeepLinkHandlerProtocol yet
        // Registering concrete type only for now
        register(DeepLinkHandler.self, lifecycle: .singleton) { container in
            let logger = container.resolve(LoggingService.self)
            let firebaseShare = container.resolve(FirebaseShareService.self)
            return DeepLinkHandler(
                firebaseShare: firebaseShare,
                logger: logger
            )
        }

        // MARK: - Navigation
        register(TabNavigationCoordinator.self, lifecycle: .singleton) { _ in
            TabNavigationCoordinator()
        }

        // MARK: - Comments
        // Note: CommentService doesn't fully implement CommentServiceProtocol yet
        // Registering concrete type only for now
        register(CommentService.self, lifecycle: .singleton) { container in
            let firebaseSync = container.resolve(FirebaseSyncService.self)
            return CommentService(firebaseSync: firebaseSync)
        }

        // MARK: - CRDT
        // Note: CRDTMergeEngine doesn't fully implement CRDTMergeEngineProtocol yet
        // Registering concrete type only for now
        register(CRDTMergeEngine.self, lifecycle: .singleton) { _ in
            CRDTMergeEngine()
        }

        // MARK: - Reminders
        // Note: RemindersService doesn't fully implement RemindersServiceProtocol yet
        // Registering concrete type only for now
        register(RemindersService.self, lifecycle: .singleton) { _ in
            RemindersService()
        }

        // MARK: - Undo
        // Note: UndoService doesn't fully implement UndoServiceProtocol yet
        // Registering concrete type only for now
        register(UndoService.self, lifecycle: .singleton) { container in
            let analytics = container.resolve(AnalyticsService.self)
            let backendConfig = container.resolve(BackendConfig.self)
            let firebaseSync = container.resolve(FirebaseSyncService.self)
            return UndoService(analytics: analytics, backendConfig: backendConfig, firebaseSync: firebaseSync)
        }

        // TODO: CardStyleUndoManager needs to be updated to match current RecipeCardStyle model
        // Missing properties: backgroundColor, backgroundStyle, stickers, annotations, hasCoffeeStain, etc.
        // register(CardStyleUndoManager.self, lifecycle: .singleton) { _ in
        //     CardStyleUndoManager()
        // }

        // MilestoneManager
        register(MilestoneManager.self, lifecycle: .singleton) { _ in
            MilestoneManager()
        }

        // MARK: - Help & Gestures
        register(GestureGuide.self, lifecycle: .singleton) { _ in
            GestureGuide()
        }

        register(HelpContent.self, lifecycle: .singleton) { _ in
            HelpContent.shared
        }

        // MARK: - Toast
        // Note: ToastManager doesn't fully implement ToastManagerProtocol yet
        // Registering concrete type only for now
        register(ToastManager.self, lifecycle: .singleton) { _ in
            ToastManager()
        }

        // MARK: - Privacy
        register(PrivacyConsentService.self, lifecycle: .singleton) { container in
            let analytics = container.resolve(AnalyticsService.self)
            return PrivacyConsentService(analytics: analytics)
        }

        // MARK: - Short URL
        register(ShortURLService.self, lifecycle: .singleton) { container in
            let analytics = container.resolve(AnalyticsService.self)
            return ShortURLService(analytics: analytics)
        }

        // MARK: - PDF Import Services
        register(PDFProcessor.self, lifecycle: .singleton) { container in
            let subscriptionManager = container.resolve(SubscriptionManager.self)
            let analytics = container.resolve(AnalyticsService.self)
            return PDFProcessor(subscriptionManager: subscriptionManager, analytics: analytics)
        }

        register(MultiPageRecipeAnalyzer.self, lifecycle: .singleton) { container in
            let aiService = container.resolve(AIServiceProtocol.self)
            let analytics = container.resolve(AnalyticsService.self)
            return MultiPageRecipeAnalyzer(aiService: aiService, analytics: analytics)
        }

        // MARK: - Bulk Import
        register(ImportJobManager.self, lifecycle: .singleton) { container in
            let importService = container.resolve(RecipeImportService.self)
            let aiRecipeExtractor = container.resolve(AIRecipeExtractor.self)
            let multiPageAnalyzer = container.resolve(MultiPageRecipeAnalyzer.self)
            let firebaseSync = container.resolve(FirebaseSyncService.self)
            let backendConfig = container.resolve(BackendConfig.self)
            return ImportJobManager(
                importService: importService,
                aiRecipeExtractor: aiRecipeExtractor,
                multiPageAnalyzer: multiPageAnalyzer,
                firebaseSync: firebaseSync,
                backendConfig: backendConfig
            )
        }

        // MARK: - Video Processing
        // Note: VideoProcessing services will be lazily initialized on first use
        // VideoProcessingJobManager is registered but services will be created when needed

        // MARK: - Mixpanel (Optional)
        #if canImport(Mixpanel)
        register(MixpanelService.self, lifecycle: .singleton) { _ in
            MixpanelService()
        }
        #endif

        logger.log(
            "Service registration complete: \(registeredServices.count) services",
            category: .general,
            level: .info
        )
    }

    /// Register mock services for testing
    func registerMockServices() {
        let logger = HeirloomLogger()
        logger.log("Registering mock services for testing...", category: .general, level: .info)

        // Mock services will be registered here as we create them
        // For now, register real services as placeholders

        registerProductionServices()

        logger.log("Mock service registration complete", category: .general, level: .info)
    }

    /// Register preview services for SwiftUI previews
    func registerPreviewServices() {
        let logger = HeirloomLogger()
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
