//
//  MockFirestore.swift
//  HeirloomTestsV2
//
//  Created: 2026-01-06
//

import Foundation
@testable import Heirloom

/// Mock implementation of Firestore for testing
/// Simulates document and collection operations with in-memory storage
@MainActor
class MockFirestore: MockTracking, MockErrorInjection, MockStateSimulation {

    // MARK: - MockTracking
    var callLog: [String] = []

    // MARK: - MockErrorInjection
    var shouldFail = false
    var injectedError: Error?

    // MARK: - In-Memory Storage
    /// Structure: [collectionPath: [documentID: data]]
    private var storage: [String: [String: [String: Any]]] = [:]

    // MARK: - Behavior Configuration
    var operationDelay: TimeInterval = 0
    var simulateOffline = false

    // MARK: - Test Inspection
    private(set) var documentsCreated: [(collection: String, id: String, data: [String: Any])] = []
    private(set) var documentsUpdated: [(collection: String, id: String, data: [String: Any])] = []
    private(set) var documentsDeleted: [(collection: String, id: String)] = []
    private(set) var queriesExecuted: [(collection: String, filters: [String])] = []

    // MARK: - Collection Operations

    func collection(_ path: String) -> MockCollectionReference {
        recordCall("collection(\(path))")
        return MockCollectionReference(path: path, firestore: self)
    }

    // MARK: - Document Operations

    func document(path: String) -> MockDocumentReference {
        recordCall("document(\(path))")
        let components = path.split(separator: "/").map(String.init)
        guard components.count >= 2 else {
            fatalError("Invalid document path: \(path)")
        }
        let collectionPath = components.dropLast().joined(separator: "/")
        let documentID = components.last!
        return MockDocumentReference(collection: collectionPath, id: documentID, firestore: self)
    }

    // MARK: - Internal Storage Management

    func setDocument(collection: String, id: String, data: [String: Any], merge: Bool = false) throws {
        if simulateOffline {
            throw FirestoreError.offline
        }

        if shouldFail {
            throw injectedError ?? FirestoreError.writeFailed
        }

        if storage[collection] == nil {
            storage[collection] = [:]
        }

        if merge, let existing = storage[collection]?[id] {
            var merged = existing
            for (key, value) in data {
                merged[key] = value
            }
            storage[collection]?[id] = merged
        } else {
            storage[collection]?[id] = data
        }

        documentsCreated.append((collection, id, data))
    }

    func updateDocument(collection: String, id: String, data: [String: Any]) throws {
        if simulateOffline {
            throw FirestoreError.offline
        }

        if shouldFail {
            throw injectedError ?? FirestoreError.writeFailed
        }

        guard var existing = storage[collection]?[id] else {
            throw FirestoreError.documentNotFound
        }

        for (key, value) in data {
            existing[key] = value
        }

        storage[collection]?[id] = existing
        documentsUpdated.append((collection, id, data))
    }

    func getDocument(collection: String, id: String) throws -> [String: Any]? {
        if simulateOffline {
            throw FirestoreError.offline
        }

        if shouldFail {
            throw injectedError ?? FirestoreError.readFailed
        }

        return storage[collection]?[id]
    }

    func deleteDocument(collection: String, id: String) throws {
        if simulateOffline {
            throw FirestoreError.offline
        }

        if shouldFail {
            throw injectedError ?? FirestoreError.writeFailed
        }

        storage[collection]?.removeValue(forKey: id)
        documentsDeleted.append((collection, id))
    }

    func getDocuments(collection: String) throws -> [[String: Any]] {
        if simulateOffline {
            throw FirestoreError.offline
        }

        if shouldFail {
            throw injectedError ?? FirestoreError.readFailed
        }

        if let documents = storage[collection] {
            return Array(documents.values)
        }
        return []
    }

    // MARK: - Query Simulation

    func query(collection: String, filters: [String: Any]) throws -> [[String: Any]] {
        queriesExecuted.append((collection, filters.keys.map { $0 }))

        let documents = try getDocuments(collection: collection)
        return documents.filter { doc in
            filters.allSatisfy { key, value in
                guard let docValue = doc[key] else { return false }
                return String(describing: docValue) == String(describing: value)
            }
        }
    }

    // MARK: - MockStateSimulation

    func reset() {
        callLog.removeAll()
        storage.removeAll()
        shouldFail = false
        injectedError = nil
        operationDelay = 0
        simulateOffline = false
        documentsCreated.removeAll()
        documentsUpdated.removeAll()
        documentsDeleted.removeAll()
        queriesExecuted.removeAll()
    }

    // MARK: - Test Helpers

    /// Pre-populate Firestore with test data
    func seed(collection: String, documents: [String: [String: Any]]) {
        storage[collection] = documents
    }

    /// Get all documents in a collection (for test inspection)
    func getAllDocuments(in collection: String) -> [[String: Any]] {
        if let documents = storage[collection] {
            return Array(documents.values)
        }
        return []
    }

    /// Check if document exists
    func documentExists(collection: String, id: String) -> Bool {
        return storage[collection]?[id] != nil
    }

    /// Get document count in collection
    func documentCount(in collection: String) -> Int {
        return storage[collection]?.count ?? 0
    }
}

// MARK: - MockCollectionReference

@MainActor
class MockCollectionReference {
    let path: String
    weak var firestore: MockFirestore?

    init(path: String, firestore: MockFirestore) {
        self.path = path
        self.firestore = firestore
    }

    func document(_ id: String) -> MockDocumentReference {
        return MockDocumentReference(collection: path, id: id, firestore: firestore!)
    }

    func addDocument(data: [String: Any]) async throws -> String {
        let id = UUID().uuidString
        try firestore?.setDocument(collection: path, id: id, data: data)
        return id
    }

    func getDocuments() async throws -> [[String: Any]] {
        return try firestore?.getDocuments(collection: path) ?? []
    }
}

// MARK: - MockDocumentReference

@MainActor
class MockDocumentReference {
    let collection: String
    let id: String
    weak var firestore: MockFirestore?

    init(collection: String, id: String, firestore: MockFirestore) {
        self.collection = collection
        self.id = id
        self.firestore = firestore
    }

    func setData(_ data: [String: Any], merge: Bool = false) async throws {
        try firestore?.setDocument(collection: collection, id: id, data: data, merge: merge)
    }

    func updateData(_ data: [String: Any]) async throws {
        try firestore?.updateDocument(collection: collection, id: id, data: data)
    }

    func getDocument() async throws -> [String: Any]? {
        return try firestore?.getDocument(collection: collection, id: id)
    }

    func delete() async throws {
        try firestore?.deleteDocument(collection: collection, id: id)
    }
}

// MARK: - FirestoreError

enum FirestoreError: Error, Equatable {
    case writeFailed
    case readFailed
    case deleteFailed
    case documentNotFound
    case offline
    case permissionDenied
    case quotaExceeded

    var localizedDescription: String {
        switch self {
        case .writeFailed: return "Write operation failed"
        case .readFailed: return "Read operation failed"
        case .deleteFailed: return "Delete operation failed"
        case .documentNotFound: return "Document not found"
        case .offline: return "Firestore is offline"
        case .permissionDenied: return "Permission denied"
        case .quotaExceeded: return "Quota exceeded"
        }
    }
}
