import Foundation

/// Mock Keychain for testing secure storage without using device keychain
/// Stores data in memory for test isolation and speed
class MockKeychain {

    // MARK: - Storage

    /// In-memory storage simulating keychain
    private var storage: [String: String] = [:]

    // MARK: - Keychain Operations

    /// Store a value for a key
    func set(_ key: String, value: String) {
        storage[key] = value
    }

    /// Retrieve a value for a key
    func get(_ key: String) -> String? {
        return storage[key]
    }

    /// Delete a value for a key
    func delete(_ key: String) {
        storage.removeValue(forKey: key)
    }

    /// Check if a key exists
    func exists(_ key: String) -> Bool {
        return storage[key] != nil
    }

    /// Get all stored keys
    var allKeys: [String] {
        return Array(storage.keys)
    }

    /// Get count of stored items
    var count: Int {
        return storage.count
    }

    // MARK: - Test Helpers

    /// Clear all stored data
    func reset() {
        storage.removeAll()
    }

    /// Print all stored keys and values (for debugging)
    func dump() {
        print("MockKeychain contents:")
        for (key, value) in storage {
            let maskedValue = value.prefix(8) + "..." // Mask sensitive data
            print("  \(key): \(maskedValue)")
        }
    }
}
