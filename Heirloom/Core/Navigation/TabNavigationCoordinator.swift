//
//  TabNavigationCoordinator.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI

/// Coordinates navigation across tabs, including cross-tab navigation after content creation
@MainActor
class TabNavigationCoordinator: ObservableObject {
    // MARK: - Published State

    /// Currently selected tab index (bound to ContentView's TabView)
    @Published var selectedTab: Int = 0

    /// Track navigation context for post-creation navigation
    enum CreationContext {
        case collectionsTab
        case collectionDetail
    }

    private var currentCreationContext: CreationContext?

    // MARK: - Tab Constants

    enum Tab: Int {
        case collections = 0
        case discovery = 1
        case shopping = 2
        case mealPlanning = 3
        case table = 4
    }

    // MARK: - Context Tracking

    /// Call before presenting recipe editor to track source context
    func willCreateRecipe(from context: CreationContext) {
        currentCreationContext = context
        Log.debug("Recipe creation initiated from context", category: .ui, metadata: ["context": "\(context)"])
    }

    /// Call before presenting collection editor to track source context
    func willCreateCollection(from context: CreationContext) {
        currentCreationContext = context
        Log.debug("Collection creation initiated from context", category: .ui, metadata: ["context": "\(context)"])
    }

    // MARK: - Post-Creation Navigation

    /// Call after recipe is successfully saved
    func didCreateRecipe() {
        guard let context = currentCreationContext else { return }

        switch context {
        case .collectionsTab, .collectionDetail:
            // Stay in Collections tab (already there)
            break
        }

        currentCreationContext = nil
    }

    /// Call after collection is successfully saved
    func didCreateCollection() {
        guard let context = currentCreationContext else { return }

        switch context {
        case .collectionsTab, .collectionDetail:
            // Stay in current context
            break
        }

        currentCreationContext = nil
    }

    /// Call if creation is cancelled
    func didCancelCreation() {
        currentCreationContext = nil
    }
}
