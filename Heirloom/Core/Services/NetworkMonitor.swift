import Foundation
import Network
import SwiftUI

/// Network connectivity monitor using NWPathMonitor
/// Provides real-time network status updates for offline capabilities
@MainActor
@Observable
final class NetworkMonitor: NetworkMonitorProtocol {

    // MARK: - Published State

    /// Current network connectivity status
    private(set) var isConnected: Bool = true

    /// Current connection type (enum)
    private(set) var connectionTypeEnum: ConnectionType = .unknown

    /// Current connection type (String) - for protocol conformance
    var connectionType: String {
        connectionTypeEnum.displayName
    }

    /// Whether the connection is expensive (cellular data)
    private(set) var isExpensive: Bool = false

    /// Whether the connection is constrained (low data mode)
    private(set) var isConstrained: Bool = false

    // MARK: - Private Properties

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.heirloom.networkmonitor")

    // MARK: - Connection Types

    enum ConnectionType {
        case wifi
        case cellular
        case wired
        case unknown

        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .wired: return "Wired"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .wired: return "cable.connector"
            case .unknown: return "network"
            }
        }
    }

    // MARK: - Initialization

    nonisolated init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
        // Log initialization on main actor
        Task { @MainActor in
            Log.info("NetworkMonitor initialized and monitoring started", category: .network)
        }
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    /// Start monitoring network connectivity
    nonisolated func startMonitoring() {

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Update connection status
                self.isConnected = path.status == .satisfied

                // Update connection type
                if path.usesInterfaceType(.wifi) {
                    self.connectionTypeEnum = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionTypeEnum = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionTypeEnum = .wired
                } else {
                    self.connectionTypeEnum = .unknown
                }

                // Update connection characteristics
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                // Log status change
                self.logNetworkChange()
            }
        }

        monitor.start(queue: queue)

        // Get current path immediately (don't wait for first change)
        let currentPath = monitor.currentPath
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isConnected = currentPath.status == .satisfied
            if currentPath.usesInterfaceType(.wifi) {
                self.connectionTypeEnum = .wifi
            } else if currentPath.usesInterfaceType(.cellular) {
                self.connectionTypeEnum = .cellular
            } else if currentPath.usesInterfaceType(.wiredEthernet) {
                self.connectionTypeEnum = .wired
            } else {
                self.connectionTypeEnum = .unknown
            }
            self.isExpensive = currentPath.isExpensive
            self.isConstrained = currentPath.isConstrained
            Log.info("NetworkMonitor initial state", category: .network, metadata: [
                "isConnected": self.isConnected,
                "connectionType": self.connectionTypeEnum.displayName
            ])
        }
    }

    /// Stop monitoring network connectivity
    nonisolated func stopMonitoring() {
        monitor.cancel()
    }

    // MARK: - Helper Methods

    /// Get human-readable network status
    var statusDescription: String {
        if !isConnected {
            return "Offline"
        }

        var status = "Online"
        if isExpensive {
            status += " (Cellular)"
        }
        if isConstrained {
            status += " (Low Data Mode)"
        }
        return status
    }

    /// Check if the app should avoid large data transfers
    var shouldAvoidLargeTransfers: Bool {
        return !isConnected || isExpensive || isConstrained
    }

    /// Log network status changes
    private func logNetworkChange() {
        Log.info("Network status changed", category: .network, metadata: [
            "status": statusDescription,
            "connectionType": connectionTypeEnum.displayName,
            "isExpensive": isExpensive,
            "isConstrained": isConstrained
        ])
    }

    // MARK: - Async Stream for SwiftUI

    /// Async stream of connection status changes for use with SwiftUI .task modifier
    /// Polls the main monitor's state to avoid multiple NWPathMonitor instances
    /// Usage: .task { for await isOnline in networkMonitor.connectionUpdates { isOffline = !isOnline } }
    var connectionUpdates: AsyncStream<Bool> {
        let currentStatus = self.isConnected
        return AsyncStream { continuation in
            // Yield initial state
            continuation.yield(currentStatus)

            // Poll state changes using Task sleep (cleaner than Timer for async context)
            let pollTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    guard let self, !Task.isCancelled else { break }
                    continuation.yield(self.isConnected)
                }
            }

            continuation.onTermination = { @Sendable _ in
                pollTask.cancel()
            }
        }
    }

    // MARK: - Manual Testing Helpers

    #if DEBUG
    /// Simulate offline mode for testing (DEBUG only)
    func simulateOffline() {
        isConnected = false
        connectionTypeEnum = .unknown
        Log.debug("Simulating offline mode", category: .network)
    }

    /// Simulate online mode for testing (DEBUG only)
    func simulateOnline() {
        isConnected = true
        connectionTypeEnum = .wifi
        isExpensive = false
        isConstrained = false
        Log.debug("Simulating online mode", category: .network)
    }
    #endif
}

// MARK: - SwiftUI Environment
// Environment extension moved to ServiceEnvironment.swift for DI integration
