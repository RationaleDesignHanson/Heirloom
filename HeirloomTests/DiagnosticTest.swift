import XCTest
import SwiftData
@testable import Heirloom

@MainActor
final class DiagnosticTest: XCTestCase {

    func testContainerCreation() throws {
        print("📍 Starting container creation test...")

        do {
            let container = try TestFixtures.createTestContainer()
            print("✅ Container created successfully: \(container)")
            XCTAssertNotNil(container)
        } catch {
            print("❌ Container creation failed!")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error: \(error)")
            print("❌ Localized description: \(error.localizedDescription)")

            // Try to get more details
            let nsError = error as NSError
            print("❌ Domain: \(nsError.domain)")
            print("❌ Code: \(nsError.code)")
            print("❌ UserInfo: \(nsError.userInfo)")

            XCTFail("Failed to create container: \(error)")
        }
    }
}
