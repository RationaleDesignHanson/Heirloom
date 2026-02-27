import SnapshotTesting
import SwiftUI
import XCTest
@testable import Heirloom

@MainActor
final class ImportViewSnapshotTests: SnapshotTestCase {

    // MARK: - Import Options (default state)

    func testImportView_defaultState() {
        let view = RecipeImportView()

        assertBothDevices(view, named: "importView_default")
    }
}
