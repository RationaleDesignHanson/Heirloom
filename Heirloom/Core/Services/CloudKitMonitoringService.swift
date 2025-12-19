import Foundation
import CloudKit
import SwiftUI

/// Monitors CloudKit operations, tracks metrics, and manages error reporting
@MainActor
class CloudKitMonitoringService: ObservableObject {
    static let shared = CloudKitMonitoringService()

    private let container: CKContainer

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var accountStatus: CKAccountStatus = .couldNotDetermine
    @Published var syncActivity: [SyncEvent] = []
    @Published var errorLog: [ErrorEvent] = []
    @Published var metrics: PerformanceMetrics = PerformanceMetrics()

    // MARK: - Models

    struct SyncEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: SyncEventType
        let details: String
        let success: Bool

        enum SyncEventType: String {
            case share = "Share"
            case passDown = "Pass Down"
            case accept = "Accept Share"
            case sync = "Sync"
            case upload = "Upload"
            case download = "Download"
        }
    }

    struct ErrorEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let operation: String
        let error: Error
        let details: String

        var errorCode: Int {
            (error as NSError).code
        }

        var errorDomain: String {
            (error as NSError).domain
        }
    }

    struct PerformanceMetrics {
        var totalShares: Int = 0
        var totalPassDowns: Int = 0
        var totalAccepts: Int = 0
        var successfulSyncs: Int = 0
        var failedSyncs: Int = 0
        var averageSyncTime: TimeInterval = 0
        var lastSyncDate: Date?
        var dataUploaded: Int64 = 0 // bytes
        var dataDownloaded: Int64 = 0 // bytes
    }

    // MARK: - Initialization

    private init() {
        // Use the default container which matches the entitlements
        // Container ID: iCloud.com.matthanson.heirloom
        self.container = CKContainer.default()

        Task {
            await checkConnection()
            await checkAccountStatus()
        }
    }

    // MARK: - Connection Status

    func checkConnection() async {
        // For SwiftData + CloudKit apps, the account status is the best indicator
        // of CloudKit connectivity. SwiftData uses the private database which
        // doesn't allow direct queries for connection testing.
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            
            // Connected if account is available
            isConnected = (status == .available)
            
            if !isConnected {
                print("☁️ CloudKit not connected: account status = \(status.rawValue)")
            }
        } catch {
            isConnected = false
            accountStatus = .couldNotDetermine
            logError(operation: "Check Connection", error: error)
        }
    }

    func checkAccountStatus() async {
        do {
            accountStatus = try await container.accountStatus()
            // Keep isConnected in sync with account status
            isConnected = (accountStatus == .available)
        } catch {
            accountStatus = .couldNotDetermine
            isConnected = false
            logError(operation: "Check Account Status", error: error)
        }
    }

    // MARK: - Event Tracking

    func logSyncEvent(type: SyncEvent.SyncEventType, details: String, success: Bool) {
        let event = SyncEvent(
            timestamp: Date(),
            type: type,
            details: details,
            success: success
        )

        syncActivity.insert(event, at: 0)

        // Keep only last 100 events
        if syncActivity.count > 100 {
            syncActivity.removeLast()
        }

        // Update metrics
        updateMetrics(for: event)
    }

    func logError(operation: String, error: Error, details: String = "") {
        let errorEvent = ErrorEvent(
            timestamp: Date(),
            operation: operation,
            error: error,
            details: details
        )

        errorLog.insert(errorEvent, at: 0)

        // Keep only last 50 errors
        if errorLog.count > 50 {
            errorLog.removeLast()
        }

        print("☁️ CloudKit Error [\(operation)]: \(error.localizedDescription)")
    }

    private func updateMetrics(for event: SyncEvent) {
        switch event.type {
        case .share:
            if event.success {
                metrics.totalShares += 1
            }
        case .passDown:
            if event.success {
                metrics.totalPassDowns += 1
            }
        case .accept:
            if event.success {
                metrics.totalAccepts += 1
            }
        case .sync, .upload, .download:
            if event.success {
                metrics.successfulSyncs += 1
            } else {
                metrics.failedSyncs += 1
            }
        }

        metrics.lastSyncDate = Date()
    }

    // MARK: - Analytics

    func getSyncSuccessRate() -> Double {
        let total = metrics.successfulSyncs + metrics.failedSyncs
        guard total > 0 else { return 0 }
        return Double(metrics.successfulSyncs) / Double(total) * 100
    }

    func getRecentActivity(hours: Int = 24) -> [SyncEvent] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        return syncActivity.filter { $0.timestamp > cutoff }
    }

    func getRecentErrors(hours: Int = 24) -> [ErrorEvent] {
        let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
        return errorLog.filter { $0.timestamp > cutoff }
    }

    // MARK: - Data Management

    func clearErrorLog() {
        errorLog.removeAll()
    }

    func clearSyncActivity() {
        syncActivity.removeAll()
    }

    func resetMetrics() {
        metrics = PerformanceMetrics()
    }

    func exportDiagnostics() -> String {
        var report = "# Heirloom CloudKit Diagnostics\n\n"
        report += "Generated: \(Date().formatted())\n\n"

        report += "## Connection Status\n"
        report += "Connected: \(isConnected ? "✅" : "❌")\n"
        report += "Account Status: \(accountStatusDescription)\n\n"

        report += "## Metrics\n"
        report += "Total Shares: \(metrics.totalShares)\n"
        report += "Total Pass Downs: \(metrics.totalPassDowns)\n"
        report += "Total Accepts: \(metrics.totalAccepts)\n"
        report += "Successful Syncs: \(metrics.successfulSyncs)\n"
        report += "Failed Syncs: \(metrics.failedSyncs)\n"
        report += "Success Rate: \(String(format: "%.1f", getSyncSuccessRate()))%\n"
        report += "Last Sync: \(metrics.lastSyncDate?.formatted() ?? "Never")\n\n"

        report += "## Recent Activity (\(syncActivity.count) events)\n"
        for event in syncActivity.prefix(20) {
            report += "[\(event.timestamp.formatted())] \(event.type.rawValue) - \(event.details) \(event.success ? "✅" : "❌")\n"
        }

        report += "\n## Recent Errors (\(errorLog.count) errors)\n"
        for error in errorLog.prefix(10) {
            report += "[\(error.timestamp.formatted())] \(error.operation)\n"
            report += "  Error: \(error.error.localizedDescription)\n"
            report += "  Code: \(error.errorCode), Domain: \(error.errorDomain)\n"
            if !error.details.isEmpty {
                report += "  Details: \(error.details)\n"
            }
            report += "\n"
        }

        return report
    }

    private var accountStatusDescription: String {
        switch accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}
