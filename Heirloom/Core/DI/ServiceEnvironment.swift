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
    static let defaultValue: FirebaseSyncServiceProtocol = ServiceContainer.shared.resolve(FirebaseSyncServiceProtocol.self)
}

private struct FirebaseAuthServiceKey: EnvironmentKey {
    static let defaultValue: FirebaseAuthServiceProtocol = ServiceContainer.shared.resolve(FirebaseAuthServiceProtocol.self)
}

private struct FirebaseRecipeSyncKey: EnvironmentKey {
    static let defaultValue: FirebaseRecipeSyncProtocol = ServiceContainer.shared.resolve(FirebaseRecipeSyncProtocol.self)
}

private struct FirebaseShareServiceKey: EnvironmentKey {
    static let defaultValue: FirebaseShareServiceProtocol = ServiceContainer.shared.resolve(FirebaseShareServiceProtocol.self)
}

private struct FirebaseImageServiceKey: EnvironmentKey {
    static let defaultValue: FirebaseImageServiceProtocol = ServiceContainer.shared.resolve(FirebaseImageServiceProtocol.self)
}

// Logging
private struct LoggingServiceKey: EnvironmentKey {
    static let defaultValue: LoggingService = ServiceContainer.shared.resolve(LoggingService.self)
}

// Analytics
private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServiceProtocol = ServiceContainer.shared.resolve(AnalyticsServiceProtocol.self)
}

// Network
private struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue: NetworkMonitorProtocol = ServiceContainer.shared.resolve(NetworkMonitorProtocol.self)
}

// Recipe Services
private struct RecipeImportServiceKey: EnvironmentKey {
    static let defaultValue: RecipeImportServiceProtocol = ServiceContainer.shared.resolve(RecipeImportServiceProtocol.self)
}

private struct RecipeVersionServiceKey: EnvironmentKey {
    static let defaultValue: RecipeVersionServiceProtocol = ServiceContainer.shared.resolve(RecipeVersionServiceProtocol.self)
}

// Storage
private struct ImageStorageServiceKey: EnvironmentKey {
    static let defaultValue: ImageStorageServiceProtocol = ServiceContainer.shared.resolve(ImageStorageServiceProtocol.self)
}

// AI Services
private struct AIRecipeExtractorKey: EnvironmentKey {
    static let defaultValue: AIRecipeExtractorProtocol = ServiceContainer.shared.resolve(AIRecipeExtractorProtocol.self)
}

// MARK: - Environment Values Extension

extension EnvironmentValues {

    // MARK: Firebase Services

    var firebaseSync: FirebaseSyncServiceProtocol {
        get { self[FirebaseSyncServiceKey.self] }
        set { self[FirebaseSyncServiceKey.self] = newValue }
    }

    var firebaseAuth: FirebaseAuthServiceProtocol {
        get { self[FirebaseAuthServiceKey.self] }
        set { self[FirebaseAuthServiceKey.self] = newValue }
    }

    var firebaseRecipeSync: FirebaseRecipeSyncProtocol {
        get { self[FirebaseRecipeSyncKey.self] }
        set { self[FirebaseRecipeSyncKey.self] = newValue }
    }

    var firebaseShare: FirebaseShareServiceProtocol {
        get { self[FirebaseShareServiceKey.self] }
        set { self[FirebaseShareServiceKey.self] = newValue }
    }

    var firebaseImageService: FirebaseImageServiceProtocol {
        get { self[FirebaseImageServiceKey.self] }
        set { self[FirebaseImageServiceKey.self] = newValue }
    }

    // MARK: Core Services

    var logger: LoggingService {
        get { self[LoggingServiceKey.self] }
        set { self[LoggingServiceKey.self] = newValue }
    }

    var analytics: AnalyticsServiceProtocol {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }

    var networkMonitor: NetworkMonitorProtocol {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }

    // MARK: Recipe Services

    var recipeImport: RecipeImportServiceProtocol {
        get { self[RecipeImportServiceKey.self] }
        set { self[RecipeImportServiceKey.self] = newValue }
    }

    var recipeVersion: RecipeVersionServiceProtocol {
        get { self[RecipeVersionServiceKey.self] }
        set { self[RecipeVersionServiceKey.self] = newValue }
    }

    // MARK: Storage Services

    var imageStorage: ImageStorageServiceProtocol {
        get { self[ImageStorageServiceKey.self] }
        set { self[ImageStorageServiceKey.self] = newValue }
    }

    // MARK: AI Services

    var aiRecipeExtractor: AIRecipeExtractorProtocol {
        get { self[AIRecipeExtractorKey.self] }
        set { self[AIRecipeExtractorKey.self] = newValue }
    }
}

// MARK: - View Extensions for Testing

extension View {
    /// Inject a mock service for testing/previews
    func withMockService<T>(_ keyPath: WritableKeyPath<EnvironmentValues, T>, _ value: T) -> some View {
        self.environment(keyPath, value)
    }

    /// Inject multiple mock services for testing/previews
    func withMockServices(@MockServiceBuilder _ builder: (inout EnvironmentValues) -> Void) -> some View {
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
        let container = ServiceContainer()

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
        var environment = EnvironmentValues()

        // Set mock services here as we create them
        // Example:
        // environment.firebaseSync = MockFirebaseSyncService()

        return environment
    }
}
#endif
