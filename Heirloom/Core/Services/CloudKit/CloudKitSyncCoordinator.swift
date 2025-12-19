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
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.heirloom.app", category: "CloudKit")
    
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
        }
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
    func saveToPublic(_ record: CKRecord) async throws {
        // Check account first
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
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
    func deleteFromPublic(recordID: CKRecord.ID) async throws {
        guard accountStatus == .available else {
            throw CloudKitSyncError.notAuthenticated
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
    
    /// Retry an operation with exponential backoff
    private func retryOperation<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetryAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                let ckError = CloudKitSyncError.from(error)
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

