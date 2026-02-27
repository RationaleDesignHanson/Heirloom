import SnapshotTesting
import SwiftUI
import XCTest
@testable import Heirloom

@MainActor
final class ImportViewSnapshotTests: SnapshotTestCase {

    // MARK: - Setup
    //
    // RecipeImportView resolves several services from ServiceContainer:
    //   AIIngredientParser, ImageStorageService, ToastManager,
    //   AnalyticsService, CloudRecipeImportService, BackendConfig,
    //   AIConfiguration, SubscriptionManager
    //
    // It also requires TabNavigationCoordinator as @EnvironmentObject.
    //
    // If any of these are not registered, the view init will crash.
    // Register them in setUp below.

    private var tabCoordinator: TabNavigationCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        tabCoordinator = TabNavigationCoordinator()

        // Register services that RecipeImportView resolves from ServiceContainer.
        // NOTE: If ServiceContainer.resolve() crashes for a type, add its
        // mock registration here. The types below are the known dependencies.
        // ToastManager is already registered in the base class setUp.
    }

    override func tearDown() async throws {
        tabCoordinator = nil
        try await super.tearDown()
    }

    // MARK: - Import Options (default state)

    func testImportView_defaultState() {
        let view = RecipeImportView()
            .environmentObject(tabCoordinator!)

        assertBothDevices(view, named: "importView_default")
    }
}
