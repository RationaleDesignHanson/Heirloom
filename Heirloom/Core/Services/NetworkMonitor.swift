import Foundation
import Network
import SwiftUI

/// Network connectivity monitor using NWPathMonitor
/// Provides real-time network status updates for offline capabilities
@MainActor
@Observable
final class NetworkMonitor {

    /// Shared singleton instance
    nonisolated static let shared = NetworkMonitor()

    // MARK: - Published State

    /// Current network connectivity status
    private(set) var isConnected: Bool = true

    /// Current connection type
    private(set) var connectionType: ConnectionType = .unknown

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

    nonisolated private init() {
        self.monitor = NWPathMonitor()
        startMonitoring()
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
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unknown
                }

                // Update connection characteristics
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained

                // Log status change
                self.logNetworkChange()
            }
        }

        monitor.start(queue: queue)
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
            "connectionType": connectionType.displayName,
            "isExpensive": isExpensive,
            "isConstrained": isConstrained
        ])
    }

    // MARK: - Manual Testing Helpers

    #if DEBUG
    /// Simulate offline mode for testing (DEBUG only)
    func simulateOffline() {
        isConnected = false
        connectionType = .unknown
        Log.debug("Simulating offline mode", category: .network)
    }

    /// Simulate online mode for testing (DEBUG only)
    func simulateOnline() {
        isConnected = true
        connectionType = .wifi
        isExpensive = false
        isConstrained = false
        Log.debug("Simulating online mode", category: .network)
    }
    #endif
}

// MARK: - SwiftUI Environment

/// Environment key for NetworkMonitor
struct NetworkMonitorKey: EnvironmentKey {
    static let defaultValue = NetworkMonitor.shared
}

extension EnvironmentValues {
    var networkMonitor: NetworkMonitor {
        get { self[NetworkMonitorKey.self] }
        set { self[NetworkMonitorKey.self] = newValue }
    }
}
