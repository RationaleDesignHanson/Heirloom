//
//  MockStorage.swift
//  HeirloomTests
//
//  Mock implementation of Firebase Storage for testing
//

import Foundation
import FirebaseStorage
@testable import Heirloom

/// Mock Firebase Storage for testing

class MockStorage: StorageProtocol {
    var storedData: [String: Data] = [:]
    var shouldFailOperations = false
    var storageDelay: TimeInterval = 0.0

    func reference(withPath path: String) -> StorageReferenceProtocol {
        return MockStorageReference(path: path, storage: self)
    }

    func reset() {
        storedData.removeAll()
        shouldFailOperations = false
        storageDelay = 0.0
    }
}

/// Mock storage reference

class MockStorageReference: StorageReferenceProtocol {
    let path: String
    weak var storage: MockStorage?

    init(path: String, storage: MockStorage) {
        self.path = path
        self.storage = storage
    }

    func putData(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        if let storage = storage, storage.shouldFailOperations {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock upload failed"]
            )
        }

        if let storage = storage, storage.storageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(storage.storageDelay * 1_000_000_000))
        }

        storage?.storedData[path] = uploadData

        let meta = StorageMetadata()
        // meta.size = Int64(uploadData.count) // REMOVED: size is read-only
        meta.contentType = metadata?.contentType ?? "application/octet-stream"
        return meta
    }

    func getData(maxSize: Int64) async throws -> Data {
        if let storage = storage, storage.shouldFailOperations {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock download failed"]
            )
        }

        if let storage = storage, storage.storageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(storage.storageDelay * 1_000_000_000))
        }

        guard let data = storage?.storedData[path] else {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File not found"]
            )
        }

        guard Int64(data.count) <= maxSize else {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File size exceeds max size"]
            )
        }

        return data
    }

    func delete() async throws {
        if let storage = storage, storage.shouldFailOperations {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock delete failed"]
            )
        }

        if let storage = storage, storage.storageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(storage.storageDelay * 1_000_000_000))
        }

        storage?.storedData.removeValue(forKey: path)
    }

    func downloadURL() async throws -> URL {
        if let storage = storage, storage.shouldFailOperations {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Mock download URL failed"]
            )
        }

        if let storage = storage, storage.storageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(storage.storageDelay * 1_000_000_000))
        }

        guard storage?.storedData[path] != nil else {
            throw NSError(
                domain: "MockStorage",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "File not found"]
            )
        }

        // Return a mock URL
        return URL(string: "https://mock-storage.firebase.com/\(path)")!
    }
}
