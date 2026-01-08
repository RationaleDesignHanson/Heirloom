//
//  FirebaseProtocols.swift
//  HeirloomTests
//
//  Created for testing Firebase services
//
//  ⚠️ WARNING: This file contains infinite recursion bugs in the extension implementations
//  Temporarily disabled until fixed. See lines 117, 121, 129, 135, 139, 153, 159, 163, etc.
//  These recursive calls cause test hangs.
//

#if false  // Disabled due to infinite recursion bugs - TODO: Fix properly

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - Firestore Protocols

/// Protocol abstraction for Firestore database
protocol FirestoreProtocol {
    func collection(_ path: String) -> CollectionReferenceProtocol
}

/// Protocol abstraction for Firestore collection reference
protocol CollectionReferenceProtocol {
    func document(_ documentID: String) -> DocumentReferenceProtocol
    func addDocument(data: [String: Any]) async throws -> DocumentReferenceProtocol
    func getDocuments() async throws -> QuerySnapshotProtocol
    func addSnapshotListener(_ listener: @escaping (QuerySnapshotProtocol?, Error?) -> Void) -> ListenerRegistration
}

/// Protocol abstraction for Firestore document reference
protocol DocumentReferenceProtocol {
    var documentID: String { get }
    func setData(_ documentData: [String: Any]) async throws
    func getDocument() async throws -> DocumentSnapshotProtocol
    func updateData(_ fields: [AnyHashable: Any]) async throws
    func delete() async throws
}

/// Protocol abstraction for Firestore query snapshot
protocol QuerySnapshotProtocol {
    var documents: [QueryDocumentSnapshotProtocol] { get }
    var documentChanges: [DocumentChangeProtocol] { get }
}

/// Protocol abstraction for Firestore query document snapshot
protocol QueryDocumentSnapshotProtocol {
    var documentID: String { get }
    func data() -> [String: Any]
}

/// Protocol abstraction for Firestore document snapshot
protocol DocumentSnapshotProtocol {
    var documentID: String { get }
    var exists: Bool { get }
    func data() -> [String: Any]?
}

/// Protocol abstraction for document change
protocol DocumentChangeProtocol {
    var type: DocumentChangeType { get }
    var document: QueryDocumentSnapshotProtocol { get }
}

// MARK: - Auth Protocols

/// Protocol abstraction for Firebase Auth
protocol AuthProtocol {
    var currentUser: UserProtocol? { get }
    func signIn(withEmail email: String, password: String) async throws -> AuthDataResultProtocol
    func signOut() throws
    func createUser(withEmail email: String, password: String) async throws -> AuthDataResultProtocol
}

/// Protocol abstraction for Firebase User
protocol UserProtocol {
    var uid: String { get }
    var email: String? { get }
    var displayName: String? { get }
}

/// Protocol abstraction for Auth data result
protocol AuthDataResultProtocol {
    var user: UserProtocol { get }
}

// MARK: - Storage Protocols

/// Protocol abstraction for Firebase Storage
protocol StorageProtocol {
    func reference(withPath path: String) -> StorageReferenceProtocol
}

/// Protocol abstraction for Storage reference
protocol StorageReferenceProtocol {
    func putData(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata
    func getData(maxSize: Int64) async throws -> Data
    func delete() async throws
    func downloadURL() async throws -> URL
}

// MARK: - Firestore Extensions to Conform to Protocols

extension Firestore: FirestoreProtocol {
    func collection(_ path: String) -> CollectionReferenceProtocol {
        return self.collection(path) as CollectionReference
    }
}

extension CollectionReference: CollectionReferenceProtocol {
    func document(_ documentID: String) -> DocumentReferenceProtocol {
        return self.document(documentID) as DocumentReference
    }

    func addDocument(data: [String: Any]) async throws -> DocumentReferenceProtocol {
        return try await self.addDocument(data: data) as DocumentReference
    }

    func getDocuments() async throws -> QuerySnapshotProtocol {
        return try await self.getDocuments() as QuerySnapshot
    }

    func addSnapshotListener(_ listener: @escaping (QuerySnapshotProtocol?, Error?) -> Void) -> ListenerRegistration {
        return self.addSnapshotListener { snapshot, error in
            listener(snapshot as QuerySnapshotProtocol?, error)
        }
    }
}

extension DocumentReference: DocumentReferenceProtocol {
    func getDocument() async throws -> DocumentSnapshotProtocol {
        return try await self.getDocument() as DocumentSnapshot
    }
}

extension QuerySnapshot: QuerySnapshotProtocol {
    var documents: [QueryDocumentSnapshotProtocol] {
        return self.documents.map { $0 as QueryDocumentSnapshotProtocol }
    }

    var documentChanges: [DocumentChangeProtocol] {
        return self.documentChanges.map { $0 as DocumentChangeProtocol }
    }
}

extension QueryDocumentSnapshot: QueryDocumentSnapshotProtocol {
    // Already conforms via data() method
}

extension DocumentSnapshot: DocumentSnapshotProtocol {
    // Already conforms via data() method and exists property
}

extension DocumentChange: DocumentChangeProtocol {
    var document: QueryDocumentSnapshotProtocol {
        return self.document as QueryDocumentSnapshotProtocol
    }
}

extension Auth: AuthProtocol {
    var currentUser: UserProtocol? {
        return self.currentUser as? UserProtocol
    }

    func signIn(withEmail email: String, password: String) async throws -> AuthDataResultProtocol {
        return try await self.signIn(withEmail: email, password: password) as AuthDataResult
    }

    func createUser(withEmail email: String, password: String) async throws -> AuthDataResultProtocol {
        return try await self.createUser(withEmail: email, password: password) as AuthDataResult
    }
}

extension User: UserProtocol {}

extension AuthDataResult: AuthDataResultProtocol {
    var user: UserProtocol {
        return self.user as UserProtocol
    }
}

extension Storage: StorageProtocol {
    func reference(withPath path: String) -> StorageReferenceProtocol {
        return self.reference(withPath: path) as StorageReference
    }
}

extension StorageReference: StorageReferenceProtocol {
    func putData(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        // putData returns StorageMetadata directly, not a tuple
        return try await self.putData(uploadData, metadata: metadata)
    }

    func getData(maxSize: Int64) async throws -> Data {
        return try await self.data(maxSize: maxSize)
    }

    func delete() async throws {
        try await self.delete()
    }

    func downloadURL() async throws -> URL {
        return try await self.downloadURL()
    }
}
#endif  // Disabled due to infinite recursion bugs
