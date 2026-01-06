//
//  MockFirestore.swift
//  HeirloomTests
//
//  Mock implementation of Firestore for testing
//

import Foundation
import FirebaseFirestore
@testable import Heirloom

/// Mock Firestore database for testing

class MockFirestore: FirestoreProtocol {
    var collections: [String: MockCollectionReference] = [:]
    var shouldFailOperations = false
    var operationDelay: TimeInterval = 0.0

    func collection(_ path: String) -> CollectionReferenceProtocol {
        if collections[path] == nil {
            collections[path] = MockCollectionReference(path: path, firestore: self)
        }
        return collections[path]!
    }

    func reset() {
        collections.removeAll()
        shouldFailOperations = false
        operationDelay = 0.0
    }
}

/// Mock collection reference

class MockCollectionReference: CollectionReferenceProtocol {
    let path: String
    weak var firestore: MockFirestore?
    var documents: [String: MockDocumentReference] = [:]
    var listeners: [(QuerySnapshotProtocol?, Error?) -> Void] = []

    init(path: String, firestore: MockFirestore) {
        self.path = path
        self.firestore = firestore
    }

    func document(_ documentID: String) -> DocumentReferenceProtocol {
        if documents[documentID] == nil {
            documents[documentID] = MockDocumentReference(
                collectionPath: path,
                documentID: documentID,
                collection: self
            )
        }
        return documents[documentID]!
    }

    func addDocument(data: [String: Any]) async throws -> DocumentReferenceProtocol {
        if let firestore = firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        let docID = UUID().uuidString
        let docRef = MockDocumentReference(collectionPath: path, documentID: docID, collection: self)
        docRef.data = data
        docRef.exists = true
        documents[docID] = docRef

        // Notify listeners
        notifyListeners()

        return docRef
    }

    func getDocuments() async throws -> QuerySnapshotProtocol {
        if let firestore = firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        let docs = documents.values.filter { $0.exists }.map { docRef in
            MockQueryDocumentSnapshot(documentID: docRef.documentID, data: docRef.data ?? [:])
        }

        return MockQuerySnapshot(documents: docs)
    }

    func addSnapshotListener(_ listener: @escaping (QuerySnapshotProtocol?, Error?) -> Void) -> ListenerRegistration {
        listeners.append(listener)

        // Immediately call with current state
        Task { @MainActor in
            let docs = documents.values.filter { $0.exists }.map { docRef in
                MockQueryDocumentSnapshot(documentID: docRef.documentID, data: docRef.data ?? [:])
            }
            listener(MockQuerySnapshot(documents: docs), nil)
        }

        return MockListenerRegistration { [weak self] in
            self?.listeners.removeAll { $0 as AnyObject === listener as AnyObject }
        }
    }

    func notifyListeners() {
        let docs = documents.values.filter { $0.exists }.map { docRef in
            MockQueryDocumentSnapshot(documentID: docRef.documentID, data: docRef.data ?? [:])
        }
        let snapshot = MockQuerySnapshot(documents: docs)

        for listener in listeners {
            listener(snapshot, nil)
        }
    }
}

/// Mock document reference

class MockDocumentReference: DocumentReferenceProtocol {
    let collectionPath: String
    let documentID: String
    weak var collection: MockCollectionReference?
    var data: [String: Any]?
    var exists = false

    init(collectionPath: String, documentID: String, collection: MockCollectionReference) {
        self.collectionPath = collectionPath
        self.documentID = documentID
        self.collection = collection
    }

    func setData(_ documentData: [String: Any]) async throws {
        if let firestore = collection?.firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = collection?.firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        self.data = documentData
        self.exists = true

        // Notify listeners
        collection?.notifyListeners()
    }

    func getDocument() async throws -> DocumentSnapshotProtocol {
        if let firestore = collection?.firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = collection?.firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        return MockDocumentSnapshot(documentID: documentID, data: data, exists: exists)
    }

    func updateData(_ fields: [AnyHashable: Any]) async throws {
        if let firestore = collection?.firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = collection?.firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        if data == nil {
            data = [:]
        }

        for (key, value) in fields {
            if let stringKey = key as? String {
                data?[stringKey] = value
            }
        }

        self.exists = true

        // Notify listeners
        collection?.notifyListeners()
    }

    func delete() async throws {
        if let firestore = collection?.firestore, firestore.shouldFailOperations {
            throw NSError(domain: "MockFirestore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock operation failed"])
        }

        if let firestore = collection?.firestore, firestore.operationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(firestore.operationDelay * 1_000_000_000))
        }

        self.exists = false
        self.data = nil
        collection?.documents.removeValue(forKey: documentID)

        // Notify listeners
        collection?.notifyListeners()
    }
}

/// Mock query snapshot
struct MockQuerySnapshot: QuerySnapshotProtocol {
    let documents: [QueryDocumentSnapshotProtocol]
    let documentChanges: [DocumentChangeProtocol] = []
}

/// Mock query document snapshot
struct MockQueryDocumentSnapshot: QueryDocumentSnapshotProtocol {
    let documentID: String
    private let storedData: [String: Any]

    func data() -> [String: Any] {
        return storedData
    }

    init(documentID: String, data: [String: Any]) {
        self.documentID = documentID
        self.storedData = data
    }
}

/// Mock document snapshot
struct MockDocumentSnapshot: DocumentSnapshotProtocol {
    let documentID: String
    private let storedData: [String: Any]?
    let exists: Bool

    func data() -> [String: Any]? {
        return storedData
    }

    init(documentID: String, data: [String: Any]?, exists: Bool = true) {
        self.documentID = documentID
        self.storedData = data
        self.exists = exists
    }
}

/// Mock document change
struct MockDocumentChange: DocumentChangeProtocol {
    let type: DocumentChangeType
    let document: QueryDocumentSnapshotProtocol
}

/// Mock listener registration
class MockListenerRegistration: NSObject, ListenerRegistration {
    private let removeHandler: () -> Void

    init(removeHandler: @escaping () -> Void) {
        self.removeHandler = removeHandler
    }

    func remove() {
        removeHandler()
    }
}
