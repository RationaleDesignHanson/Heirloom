//
//  SyncOperation.swift
//  Heirloom
//
//  Represents a queued CloudKit operation (for offline support)
//

import Foundation
import CloudKit

/// Operations that can be queued when offline
struct SyncOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let recordData: Data  // Encoded CKRecord
    let timestamp: Date
    var retryCount: Int
    
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }
    
    init(id: UUID = UUID(), type: OperationType, recordData: Data, timestamp: Date = Date(), retryCount: Int = 0) {
        self.id = id
        self.type = type
        self.recordData = recordData
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
}


