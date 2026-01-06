//
//  ServiceEnvironment.swift
//  Heirloom
//
//  SwiftUI environment integration for dependency injection
//

import SwiftUI

// MARK: - Environment Keys

// Firebase Services
private struct FirebaseSyncServiceKey: EnvironmentKey {
    static let defaultValue: any FirebaseSyncServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseSyncServiceProtocol).self)
    }
}

private struct FirebaseAuthServiceKey: EnvironmentKey {
    static let defaultValue: any FirebaseAuthServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseAuthServiceProtocol).self)
    }
}

private struct FirebaseRecipeSyncKey: EnvironmentKey {
    static let defaultValue: any FirebaseRecipeSyncProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseRecipeSyncProtocol).self)
    }
}

private struct FirebaseShareServiceKey: EnvironmentKey {
    static let defaultValue: any FirebaseShareServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseShareServiceProtocol).self)
    }
}

private struct FirebaseImageServiceKey: EnvironmentKey {
    static let defaultValue: any FirebaseImageServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseImageServiceProtocol).self)
    }
}

private struct FirebaseLineageServiceKey: EnvironmentKey {
    static let defaultValue: any FirebaseLineageServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any FirebaseLineageServiceProtocol).self)
    }
}

// Logging
private struct LoggingServiceKey: EnvironmentKey {
    static let defaultValue: LoggingService = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve(LoggingService.self)
    }
}

// Analytics
private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: any AnalyticsServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any AnalyticsServiceProtocol).self)
    }
}

// Network
private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: any NetworkMonitorProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any NetworkMonitorProtocol).self)
    }
}

// Recipe Services
private struct RecipeImportServiceKey: EnvironmentKey {
    static let defaultValue: any RecipeImportServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any RecipeImportServiceProtocol).self)
    }
}

private struct RecipeVersionServiceKey: EnvironmentKey {
    static let defaultValue: any RecipeVersionServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any RecipeVersionServiceProtocol).self)
    }
}

// Storage
private struct ImageStorageServiceKey: EnvironmentKey {
    static let defaultValue: any ImageStorageServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any ImageStorageServiceProtocol).self)
    }
}

// AI Services
private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: any AIServiceProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any AIServiceProtocol).self)
    }
}

private struct AIConfigurationKey: EnvironmentKey {
    static let defaultValue: any AIConfigurationProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any AIConfigurationProtocol).self)
    }
}

private struct AIRecipeExtractorKey: EnvironmentKey {
    static let defaultValue: any AIRecipeExtractorProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any AIRecipeExtractorProtocol).self)
    }
}

private struct AIIngredientParserKey: EnvironmentKey {
    static let defaultValue: any AIIngredientParserProtocol = MainActor.assumeIsolated {
        ServiceContainer.shared.resolve((any AIIngredientParserProtocol).self)
    }
}

// MARK: - Environment Values Extension

extension EnvironmentValues {

    // MARK: Firebase Services

    var firebaseSync: any FirebaseSyncServiceProtocol {
        get { self[FirebaseSyncServiceKey.self] }
        set { self[FirebaseSyncServiceKey.self] = newValue }
    }

    var firebaseAuth: any FirebaseAuthServiceProtocol {
        get { self[FirebaseAuthServiceKey.self] }
        set { self[FirebaseAuthServiceKey.self] = newValue }
    }

    var firebaseRecipeSync: any FirebaseRecipeSyncProtocol {
        get { self[FirebaseRecipeSyncKey.self] }
        set { self[FirebaseRecipeSyncKey.self] = newValue }
    }

    var firebaseShare: any FirebaseShareServiceProtocol {
        get { self[FirebaseShareServiceKey.self] }
        set { self[FirebaseShareServiceKey.self] = newValue }
    }

    var firebaseImageService: any FirebaseImageServiceProtocol {
        get { self[FirebaseImageServiceKey.self] }
        set { self[FirebaseImageServiceKey.self] = newValue }
    }

    var firebaseLineage: any FirebaseLineageServiceProtocol {
        get { self[FirebaseLineageServiceKey.self] }
        set { self[FirebaseLineageServiceKey.self] = newValue }
    }

    // MARK: Core Services

    var logger: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var analytics: any AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }

    var networkMonitor: any NetworkMonitorProtocol {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }

    // MARK: Recipe Services

    var recipeImport: any RecipeImportServiceProtocol {
        get { self[RecipeImportServiceKey.self] }
        set { self[RecipeImportServiceKey.self] = newValue }
    }

    var recipeVersion: any RecipeVersionServiceProtocol {
        get { self[RecipeVersionServiceKey.self] }
        set { self[RecipeVersionServiceKey.self] = newValue }
    }

    // MARK: Storage Services

    var imageStorage: any ImageStorageServiceProtocol {
        get { self[ImageStorageServiceKey.self] }
        set { self[ImageStorageServiceKey.self] = newValue }
    }

    // MARK: AI Services

    var aiService: any AIServiceProtocol {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }

    var aiConfiguration: any AIConfigurationProtocol {
        get { self[AIConfigurationKey.self] }
        set { self[AIConfigurationKey.self] = newValue }
    }

    var aiRecipeExtractor: any AIRecipeExtractorProtocol {
        get { self[AIRecipeExtractorKey.self] }
        set { self[AIRecipeExtractorKey.self] = newValue }
    }

    var aiIngredientParser: any AIIngredientParserProtocol {
        get { self[AIIngredientParserKey.self] }
        set { self[AIIngredientParserKey.self] = newValue }
    }
}

// MARK: - View Extensions for Testing

extension View {
    /// Inject a mock service for testing/previews
    func withMockService<T>(_ keyPath: WritableKeyPath<EnvironmentValues, T>, _ value: T) -> some View {
        self.environment(keyPath, value)
    }

    /// Inject multiple mock services for testing/previews
    func withMockServices(@MockServiceBuilder _ builder: @escaping (inout EnvironmentValues) -> Void) -> some View {
        self.transformEnvironment(\.self) { environment in
            builder(&environment)
        }
    }
}

// MARK: - Mock Service Builder

@resultBuilder
struct MockServiceBuilder {
    static func buildBlock(_ components: (inout EnvironmentValues) -> Void...) -> (inout EnvironmentValues) -> Void {
        return { environment in
            for component in components {
                component(&environment)
            }
        }
    }
}

// MARK: - Preview Helpers

extension ServiceContainer {
    /// Create a container configured for SwiftUI previews with mocks
    static func preview() -> ServiceContainer {
        let container = ServiceContainer(forTesting: true)

        // Register mock services here
        // This will be populated as we create mocks

        return container
    }
}

#if DEBUG
// MARK: - Preview Environment Values

extension EnvironmentValues {
    /// Set all services to preview/mock mode
    static var preview: EnvironmentValues {
        let environment = EnvironmentValues()

        // Set mock services here as we create them
        // Example:
        // environment.firebaseSync = MockFirebaseSyncService()

        return environment
    }
}
#endif
