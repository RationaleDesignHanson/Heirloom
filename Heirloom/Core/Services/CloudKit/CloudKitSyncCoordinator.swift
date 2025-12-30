//
//  CloudKitSyncCoordinator.swift
//  Heirloom
//
//  Central service for all CloudKit operations across public/shared databases
//  Handles: retry logic, offline queue, batch operations, subscriptions
//

import Foundation
import CloudKit
import OSLog

@MainActor
final class CloudKitSyncCoordinator: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CloudKitSyncCoordinator()
    
    // MARK: - Properties
    
    /// CloudKit container for Heirloom app
    private let container: CKContainer
    
    /// Public database (for aggregated, anonymous data)
    private let publicDatabase: CKDatabase
    
    /// Shared database (for CKShare records)
    private let sharedDatabase: CKDatabase
    
    /// Queue of operations waiting to execute (offline support)
    @Published private(set) var pendingOperations: [SyncOperation] = []
    
    /// Whether we're currently syncing
    @Published private(set) var isSyncing = false
    
    /// User's CloudKit account status
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    /// Last sync error for debugging
    @Published private(set) var lastSyncError: CloudKitSyncError?

    /// Timestamp of last sync error
    @Published private(set) var lastErrorTime: Date?

    /// Logger for debugging
    private let logger = Logger(subsystem: "com.heirloom.app", category: "CloudKit")

    /// Network monitor for offline detection
    private let networkMonitor = NetworkMonitor.shared

    /// Track last network status to detect changes
    private var wasOnline = true

    // MARK: - Configuration

    /// Maximum retry attempts for failed operations
    private let maxRetryAttempts = 3

    /// Exponential backoff base (seconds)
    private let backoffBase: TimeInterval = 2.0

    /// Batch size for bulk operations
    private let batchSize = 100

    // MARK: - Initialization

    private init() {
        // Get the default CloudKit container
        // This matches your "iCloud.com.matthanson.heirloom" identifier
        self.container = CKContainer.default()
        self.publicDatabase = container.publicCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase

        // Load pending operations from disk
        loadPendingOperations()

        // Check account status on init
        Task {
            await checkAccountStatus()
            await startNetworkMonitoring()
        }
    }

    // MARK: - Network Monitoring

    /// Start monitoring network status for automatic sync
    private func startNetworkMonitoring() async {
        // Process initial state
        if networkMonitor.isConnected {
            await processPendingOperations()
        }

        // Monitor for changes (check every 5 seconds)
        Task {
            while true {
                try? await Task.sleep(for: .seconds(5))
                await checkNetworkStatus()
            }
        }
    }

    /// Check if network status changed
    private func checkNetworkStatus() async {
        let isOnline = networkMonitor.isConnected

        // Detect transition from offline to online
        if !wasOnline && isOnline {
            logger.info("📡 Network restored, processing pending operations")
            await processPendingOperations()
        }

        wasOnline = isOnline
    }
    
    // MARK: - Account Status
    
    /// Check if user is signed into iCloud
    func checkAccountStatus() async {
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = status
            }
            
            if status != .available {
                logger.warning("iCloud account not available: \(status.rawValue)")
            } else {
                logger.info("iCloud account status: available")
                // Process any pending operations
                await processPendingOperations()
            }
        } catch {
            logger.error("Failed to check account status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Database Operations
    
    /// Save a record to public database with retry logic
    /// Automatically queues if offline
    func saveToPublic(_ record: CKRecord) async throws {
        // Check account first
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }

        // If offline, queue for later
        guard networkMonitor.isConnected else {
            logger.info("📴 Offline: Queuing save operation for later")
            queueOperation(type: .update, record: record)
            // Return success - operation will process when online
            return
        }

        // Try to save with retry
        _ = try await retryOperation {
            try await self.publicDatabase.save(record)
        }

        logger.info("Saved record to public DB: \(record.recordID.recordName)")
    }
    
    /// Fetch a record from public database by ID
    func fetchFromPublic(recordID: CKRecord.ID) async throws -> CKRecord {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }
        
        let record = try await retryOperation {
            try await self.publicDatabase.record(for: recordID)
        }
        
        logger.info("Fetched record from public DB: \(recordID.recordName)")
        return record
    }
    
    /// Query public database
    func queryPublic(recordType: String, predicate: NSPredicate = NSPredicate(value: true), sortDescriptors: [NSSortDescriptor] = []) async throws -> [CKRecord] {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }
        
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = sortDescriptors
        
        let (results, _) = try await retryOperation {
            try await self.publicDatabase.records(matching: query)
        }
        
        // Extract successful records
        let records = results.compactMap { _, result in
            try? result.get()
        }
        
        logger.info("Queried public DB: \(recordType), found \(records.count) records")
        return records
    }
    
    /// Delete record from public database
    /// Automatically queues if offline
    func deleteFromPublic(recordID: CKRecord.ID) async throws {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }

        // If offline, queue for later
        guard networkMonitor.isConnected else {
            logger.info("📴 Offline: Queuing delete operation for later")
            // Create a placeholder record for deletion
            let record = CKRecord(recordType: "Placeholder", recordID: recordID)
            queueOperation(type: .delete, record: record)
            return
        }

        try await retryOperation {
            _ = try await self.publicDatabase.deleteRecord(withID: recordID)
        }

        logger.info("Deleted record from public DB: \(recordID.recordName)")
    }
    
    // MARK: - Batch Operations
    
    /// Save multiple records to public database efficiently
    func batchSaveToPublic(_ records: [CKRecord]) async throws {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }
        
        // Process in batches of 100 (CloudKit limit is 400, we're being conservative)
        for batch in records.chunked(into: batchSize) {
            let operation = CKModifyRecordsOperation(recordsToSave: batch)
            operation.savePolicy = .changedKeys  // Only send changed fields
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                
                publicDatabase.add(operation)
            }
        }
        
        logger.info("Batch saved \(records.count) records to public DB")
    }
    
    // MARK: - Shared Database (CKShare) Operations
    
    /// Save a share to shared database
    func saveShare(_ share: CKShare, with rootRecord: CKRecord) async throws {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }
        
        // Save both share and root record together
        let operation = CKModifyRecordsOperation(recordsToSave: [share, rootRecord])
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            sharedDatabase.add(operation)
        }
        
        logger.info("Saved CKShare: \(share.recordID.recordName)")
    }
    
    /// Fetch a share from shared database
    func fetchShare(recordID: CKRecord.ID) async throws -> CKShare {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
        }
        
        let record = try await retryOperation {
            try await self.sharedDatabase.record(for: recordID)
        }
        
        guard let share = record as? CKShare else {
            throw CloudKitSyncError.recordNotFound
        }
        
        logger.info("Fetched CKShare: \(recordID.recordName)")
        return share
    }
    
    // MARK: - Offline Queue Management
    
    /// Queue an operation for later (when offline)
    func queueOperation(type: SyncOperation.OperationType, record: CKRecord) {
        // Encode record data
        guard let recordData = try? NSKeyedArchiver.archivedData(withRootObject: record, requiringSecureCoding: true) else {
            logger.error("Failed to encode record for queue")
            return
        }
        
        let operation = SyncOperation(type: type, recordData: recordData)
        pendingOperations.append(operation)
        savePendingOperations()
        
        logger.info("Queued operation: \(type.rawValue)")
    }
    
    /// Process all pending operations (called when coming online)
    func processPendingOperations() async {
        guard !pendingOperations.isEmpty else { return }
        guard accountStatus == .available else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        logger.info("Processing \(self.pendingOperations.count) pending operations")
        
        var remainingOperations: [SyncOperation] = []
        
        for operation in pendingOperations {
            do {
                // Decode record
                guard let record = try NSKeyedUnarchiver.unarchivedObject(ofClass: CKRecord.self, from: operation.recordData) else {
                    logger.error("Failed to decode record")
                    continue
                }
                
                // Execute based on type
                switch operation.type {
                case .create, .update:
                    try await saveToPublic(record)
                case .delete:
                    try await deleteFromPublic(recordID: record.recordID)
                }
                
                logger.info("Processed queued operation: \(operation.type.rawValue)")
            } catch {
                // Retry logic
                if operation.retryCount < maxRetryAttempts {
                    var updatedOp = operation
                    updatedOp.retryCount += 1
                    remainingOperations.append(updatedOp)
                    logger.warning("Operation failed, will retry (\(updatedOp.retryCount)/\(self.maxRetryAttempts))")
                } else {
                    logger.error("Operation failed after \(self.maxRetryAttempts) attempts, discarding")
                }
            }
        }
        
        // Update pending operations
        pendingOperations = remainingOperations
        savePendingOperations()
    }
    
    /// Clear all pending operations (careful!)
    func clearPendingOperations() {
        pendingOperations.removeAll()
        savePendingOperations()
        logger.info("Cleared all pending operations")
    }
    
    // MARK: - Subscriptions (for push notifications)
    
    /// Subscribe to changes in a record type
    func subscribe(to recordType: String) async throws {
        let subscriptionID = "\(recordType)-subscription"
        
        // Check if already subscribed
        do {
            _ = try await publicDatabase.subscription(for: subscriptionID)
            logger.info("Already subscribed to \(recordType)")
            return
        } catch {
            // Not subscribed yet, continue
        }
        
        // Create subscription
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        
        // Configure notification
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // Silent push
        subscription.notificationInfo = notificationInfo
        
        try await publicDatabase.save(subscription)
        logger.info("Subscribed to \(recordType)")
    }
    
    // MARK: - Helper Methods
    
    // MARK: - Conflict Resolution

    /// Handle a save conflict by merging client and server records
    /// Strategy: Most recent metadata wins, merge arrays intelligently
    func handleConflict(clientRecord: CKRecord, serverRecord: CKRecord) -> CKRecord {
        logger.info("🔀 Resolving conflict for record: \(clientRecord.recordID.recordName)")

        // Use server record as base (has valid change tag)
        let resolvedRecord = serverRecord

        // Get modification dates
        let clientModified = clientRecord.modificationDate ?? Date.distantPast
        let serverModified = serverRecord.modificationDate ?? Date.distantPast

        // Strategy 1: Scalar fields - use most recent
        let scalarKeys = ["title", "notes", "servings", "prepTime", "cookTime",
                          "sourceURL", "sourceType", "imageFileName", "isFavorite"]

        for key in scalarKeys {
            if clientModified > serverModified {
                // Client is newer, use client value
                if let clientValue = clientRecord[key] {
                    resolvedRecord[key] = clientValue
                }
            }
            // Otherwise keep server value (already in resolvedRecord)
        }

        // Strategy 2: Array fields - merge unique items
        let arrayKeys = ["ingredients", "instructions", "comments", "tags"]

        for key in arrayKeys {
            let clientArray = clientRecord[key] as? [String] ?? []
            let serverArray = serverRecord[key] as? [String] ?? []

            // Merge arrays: union of both, preserving order from most recent
            var mergedArray: [String] = []

            if clientModified > serverModified {
                // Client is newer, prioritize client order
                mergedArray = clientArray
                // Add server items not in client
                for item in serverArray where !clientArray.contains(item) {
                    mergedArray.append(item)
                }
            } else {
                // Server is newer, prioritize server order
                mergedArray = serverArray
                // Add client items not in server
                for item in clientArray where !serverArray.contains(item) {
                    mergedArray.append(item)
                }
            }

            resolvedRecord[key] = mergedArray
        }

        // Strategy 3: Special handling for lastModified - always use most recent
        if clientModified > serverModified {
            if let clientLastModified = clientRecord["lastModified"] as? Date {
                resolvedRecord["lastModified"] = clientLastModified
            }
        }

        logger.info("✅ Conflict resolved. Client: \(clientModified), Server: \(serverModified), Used: \(clientModified > serverModified ? "Client" : "Server") as base")

        return resolvedRecord
    }

    // MARK: - Error Tracking

    /// Record a sync error for debugging and user display
    private func recordError(_ error: CloudKitSyncError, context: String = "") {
        lastSyncError = error
        lastErrorTime = Date()

        // Log detailed error information
        logger.error("❌ Sync Error [\(context)]: \(error.localizedDescription)")

        // Log additional context for specific error types
        switch error {
        case .networkUnavailable:
            logger.error("   Context: Network connection lost during sync")
        case .notAuthenticated:
            logger.error("   Context: User not signed into iCloud")
        case .quotaExceeded:
            logger.error("   Context: iCloud storage quota exceeded")
        case .conflictDetected:
            logger.error("   Context: Record conflict detected, attempting merge")
        case .recordNotFound:
            logger.error("   Context: Requested record does not exist")
        case .permissionDenied:
            logger.error("   Context: Permission denied to access CloudKit data")
        case .serviceUnavailable:
            logger.error("   Context: CloudKit service temporarily unavailable")
        case .rateLimited:
            logger.error("   Context: Too many CloudKit requests, rate limited")
        case .badRequest:
            logger.error("   Context: Invalid CloudKit request")
        case .internalError:
            logger.error("   Context: CloudKit internal error")
        case .zoneBusy:
            logger.error("   Context: CloudKit zone is busy, will retry")
        case .unknownError(let error):
            logger.error("   Context: Underlying error: \(error.localizedDescription)")
        }
    }

    /// Clear the last error (called after successful sync)
    func clearLastError() {
        lastSyncError = nil
        lastErrorTime = nil
    }

    /// Retry an operation with exponential backoff and conflict resolution
    private func retryOperation<T>(_ operation: @escaping () async throws -> T, context: String = "operation") async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetryAttempts {
            do {
                let result = try await operation()
                // Clear error on success
                if attempt > 0 {
                    logger.info("✅ Operation succeeded after \(attempt) retries")
                    await MainActor.run {
                        clearLastError()
                    }
                }
                return result
            } catch {
                lastError = error

                // Check if we should retry
                let ckError = CloudKitSyncError.from(error)

                // Record the error
                await MainActor.run {
                    recordError(ckError, context: context)
                }

                // Special handling for conflicts
                if case .conflictDetected = ckError {
                    // Extract CKError to get server record
                    if let ckError = error as? CKError,
                       ckError.code == .serverRecordChanged,
                       let clientRecord = ckError.userInfo[CKRecordChangedErrorClientRecordKey] as? CKRecord,
                       let serverRecord = ckError.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {

                        // Resolve conflict
                        let resolvedRecord = handleConflict(clientRecord: clientRecord, serverRecord: serverRecord)

                        // Try to save resolved record
                        do {
                            // Cast the save operation and try again
                            // This is safe because we know operation() returns a CKRecord
                            let saved = try await publicDatabase.save(resolvedRecord)
                            return saved as! T
                        } catch {
                            logger.error("Failed to save resolved record: \(error.localizedDescription)")
                            throw error
                        }
                    }
                }

                switch ckError {
                case .networkUnavailable, .conflictDetected:
                    // Retryable errors
                    let delay = backoffBase * pow(2.0, Double(attempt))
                    logger.warning("Operation failed (attempt \(attempt + 1)/\(self.maxRetryAttempts)), retrying in \(delay)s")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                default:
                    // Non-retryable error
                    throw ckError
                }
            }
        }

        // All retries failed
        throw lastError ?? CloudKitSyncError.unknownError(NSError(domain: "CloudKit", code: -1))
    }
    
    /// Save pending operations to disk
    private func savePendingOperations() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(pendingOperations) else { return }
        UserDefaults.standard.set(data, forKey: "PendingCloudKitOperations")
    }
    
    /// Load pending operations from disk
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: "PendingCloudKitOperations") else { return }
        let decoder = JSONDecoder()
        pendingOperations = (try? decoder.decode([SyncOperation].self, from: data)) ?? []
        logger.info("Loaded \(self.pendingOperations.count) pending operations from disk")
    }
}

// MARK: - Array Extension for Batching

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


