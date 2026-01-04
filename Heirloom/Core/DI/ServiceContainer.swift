//
//  ServiceContainer.swift
//  Heirloom
//
//  Dependency Injection container for managing service lifecycles and dependencies
//

import Foundation

/// Lifecycle management for services
enum ServiceLifecycle {
    case singleton  // One instance for app lifetime
    case transient  // New instance each time resolved
    case scoped     // One instance per scope (future: per view/session)
}

/// Main dependency injection container
@MainActor
final class ServiceContainer {

    // MARK: - Singleton

    static let shared = ServiceContainer()

    // MARK: - Properties

    private var factories: [String: (ServiceContainer) -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private var lifecycles: [String: ServiceLifecycle] = [:]
    private let logger = HeirloomLogger.shared

    // MARK: - Initialization

    private init() {
        logger.log("ServiceContainer initialized", category: .general, level: .info)
    }

    /// Public initializer for testing and previews
    convenience init(forTesting: Bool) {
        self.init()
    }

    // MARK: - Registration

    /// Register a service with the container
    /// - Parameters:
    ///   - type: The protocol or concrete type to register
    ///   - lifecycle: How the service should be managed (singleton, transient, scoped)
    ///   - factory: Closure that creates the service instance
    func register<T>(
        _ type: T.Type,
        lifecycle: ServiceLifecycle = .singleton,
        factory: @escaping (ServiceContainer) -> T
    ) {
        let key = String(describing: type)
        factories[key] = factory
        lifecycles[key] = lifecycle

        logger.log(
            "Registered service: \(key) with lifecycle: \(lifecycle)",
            category: .general,
            level: .debug
        )
    }

    /// Register an existing instance as a singleton
    /// - Parameters:
    ///   - type: The protocol or concrete type
    ///   - instance: Pre-created instance to register
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        singletons[key] = instance
        lifecycles[key] = .singleton

        logger.log(
            "Registered singleton instance: \(key)",
            category: .general,
            level: .debug
        )
    }

    // MARK: - Resolution

    /// Resolve a service from the container
    /// - Parameter type: The service type to resolve
    /// - Returns: Instance of the requested service
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)

        // Check lifecycle
        guard let lifecycle = lifecycles[key] else {
            logger.log(
                "Service not registered: \(key)",
                category: .general,
                level: .error
            )
            fatalError("Service not registered: \(key). Did you forget to call register?")
        }

        // Singleton: return cached or create and cache
        if lifecycle == .singleton {
            if let cached = singletons[key] as? T {
                return cached
            }

            guard let factory = factories[key] else {
                fatalError("Factory not found for singleton: \(key)")
            }

            let instance = factory(self) as! T
            singletons[key] = instance

            logger.log(
                "Created singleton instance: \(key)",
                category: .general,
                level: .debug
            )

            return instance
        }

        // Transient: always create new
        guard let factory = factories[key] else {
            fatalError("Factory not found for transient: \(key)")
        }

        logger.log(
            "Creating transient instance: \(key)",
            category: .general,
            level: .debug
        )

        return factory(self) as! T
    }

    /// Resolve an optional service (returns nil if not registered)
    /// - Parameter type: The service type to resolve
    /// - Returns: Instance of the requested service or nil
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)

        guard lifecycles[key] != nil else {
            return nil
        }

        return resolve(type)
    }

    // MARK: - Testing Support

    /// Replace a singleton instance (useful for testing)
    /// - Parameters:
    ///   - type: The service type
    ///   - instance: New instance to use
    func replace<T>(_ type: T.Type, with instance: T) {
        let key = String(describing: type)
        singletons[key] = instance

        logger.log(
            "Replaced service instance: \(key) (testing mode)",
            category: .general,
            level: .debug
        )
    }

    /// Reset all singletons (useful for testing)
    func resetSingletons() {
        singletons.removeAll()

        logger.log(
            "Reset all singleton instances (testing mode)",
            category: .general,
            level: .debug
        )
    }

    /// Clear all registrations (useful for testing)
    func reset() {
        factories.removeAll()
        singletons.removeAll()
        lifecycles.removeAll()

        logger.log(
            "Reset container (testing mode)",
            category: .general,
            level: .info
        )
    }

    // MARK: - Debugging

    /// Get list of all registered services
    var registeredServices: [String] {
        Array(lifecycles.keys).sorted()
    }

    /// Print debug information about registered services
    func printRegisteredServices() {
        logger.log(
            "Registered services: \(registeredServices.count)",
            category: .general,
            level: .info
        )

        for service in registeredServices {
            let lifecycle = lifecycles[service] ?? .singleton
            let isCached = singletons[service] != nil
            logger.log(
                "  - \(service) [\(lifecycle), cached: \(isCached)]",
                category: .general,
                level: .debug
            )
        }
    }
}

// MARK: - Convenience Extensions

extension ServiceContainer {
    /// Register multiple services at once
    func registerServices(@ServiceRegistrationBuilder _ builder: () -> [ServiceRegistration]) {
        let registrations = builder()
        for registration in registrations {
            registration.register(in: self)
        }
    }
}

// MARK: - Service Registration DSL

/// Builder for service registrations
@resultBuilder
struct ServiceRegistrationBuilder {
    static func buildBlock(_ components: ServiceRegistration...) -> [ServiceRegistration] {
        components
    }
}

/// Protocol for service registration
protocol ServiceRegistration {
    func register(in container: ServiceContainer)
}

/// Concrete service registration
struct ConcreteServiceRegistration<T>: ServiceRegistration {
    let type: T.Type
    let lifecycle: ServiceLifecycle
    let factory: (ServiceContainer) -> T

    func register(in container: ServiceContainer) {
        container.register(type, lifecycle: lifecycle, factory: factory)
    }
}

// MARK: - Helper Functions

extension ServiceContainer {
    /// Create a registration for a service
    static func registration<T>(
        _ type: T.Type,
        lifecycle: ServiceLifecycle = .singleton,
        factory: @escaping (ServiceContainer) -> T
    ) -> ServiceRegistration {
        ConcreteServiceRegistration(type: type, lifecycle: lifecycle, factory: factory)
    }
}
