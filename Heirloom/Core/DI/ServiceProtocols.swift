//
//  ServiceProtocols.swift
//  Heirloom
//
//  Service protocols for dependency injection
//  Note: Firebase service protocols are in FirebaseServiceProtocols.swift
//

import Foundation
import SwiftUI
import Combine

// MARK: - Network

@MainActor
protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var isExpensive: Bool { get }
    var connectionType: String { get }
}

// MARK: - Recipe Services

protocol RecipeImportServiceProtocol {
    func importRecipe(from url: URL) async throws -> Recipe
    func detectRecipe(from url: URL) async throws -> Bool
    func extractRecipe(from url: URL) async throws -> Recipe
}

protocol RecipeVersionServiceProtocol {
    func createVersion(from recipe: Recipe, reason: String) async throws -> Recipe
    func getVersions(for recipeId: String) async throws -> [Recipe]
    func restoreVersion(_ recipe: Recipe) async throws
}

protocol RecipeExportServiceProtocol {
    func exportRecipe(_ recipe: Recipe, format: ExportFormat) async throws -> Data
    func shareRecipe(_ recipe: Recipe) async throws -> URL
}

protocol RecipeMigrationServiceProtocol {
    func migrateRecipe(_ recipe: Recipe) async throws -> Recipe
    func migrateBatch(_ recipes: [Recipe]) async throws -> [Recipe]
}

protocol RecipeLineageServiceProtocol {
    func getLineage(for recipeId: String) async throws -> [Recipe]
    func getForks(for recipeId: String) async throws -> [Recipe]
}

// MARK: - Storage

protocol ImageStorageServiceProtocol {
    func store(_ image: UIImage, for id: String) async throws -> URL
    func retrieve(for id: String) async throws -> UIImage?
    func delete(for id: String) async throws
    func loadImageVariant(fileName: String, variant: ImageStorageService.ImageVariant) async -> UIImage?
}

protocol ImageCacheProtocol {
    func cache(_ image: UIImage, for key: String)
    func retrieve(for key: String) -> UIImage?
    func clear()
}

// MARK: - AI Services

@MainActor
protocol AIRecipeExtractorProtocol {
    func extract(from text: String) async throws -> Recipe
    func extract(from image: UIImage) async throws -> Recipe
}

@MainActor
protocol AIIngredientParserProtocol {
    func parse(_ text: String) async throws -> Ingredient
    func parseBatch(_ texts: [String]) async throws -> [Ingredient]
}

protocol AIRecipeDetectorProtocol {
    func detect(in text: String) async throws -> Bool
    func detect(in image: UIImage) async throws -> Bool
}

@MainActor
protocol AIConfigurationProtocol {
    var apiKey: String { get }
    var model: String { get }
    var maxTokens: Int { get }
    var enableAIParsing: Bool { get }
    var enableAIEnhancement: Bool { get }
    var currentAPIKey: String? { get }

    func isConfigured(provider: AIProvider) -> Bool
    func model(for task: AITask) -> String
    func incrementRequestCount()
    func canMakeRequest() -> Bool
    func handleUnauthorizedError()
}

protocol CommentAnalysisServiceProtocol {
    // Using Any as return type for now - can be refined later
    func analyzeComment(_ comment: RecipeComment) async throws -> Any
    func analyzeComments(_ comments: [RecipeComment]) async throws -> [Any]
    func extractInsights(from comments: [RecipeComment]) async throws -> Any
}

protocol DinnerPartySummaryServiceProtocol {
    // Using Any as return type for now - can be refined later
    nonisolated func generateSummary(for party: DinnerParty, recipes: [Recipe]) async throws -> Any
}

protocol ShoppingListSummaryServiceProtocol {
    // Using Any as return type for now - can be refined later
    nonisolated func generateSummary(for ingredients: [Ingredient], recipes: [Recipe]) async throws -> Any
}

protocol RecipeTimelineCalculatorProtocol {
    // Using Any as return type for now - can be refined later
    nonisolated func calculateTimeline(for recipes: [Recipe], servingTime: Date) async throws -> Any
}

protocol AIIngredientSpellCheckerProtocol {
    // Using Any as return type for now - can be refined later
    func check(_ text: String) async throws -> Any
    func checkBatch(_ texts: [String]) async throws -> [Any]
}

// MARK: - OCR

protocol OCRServiceProtocol {
    func recognizeText(in image: UIImage) async throws -> String
    func recognizeStructuredRecipe(in image: UIImage) async throws -> Recipe
}

// MARK: - Deep Linking

protocol DeepLinkHandlerProtocol {
    func handle(_ url: URL) async throws
    func canHandle(_ url: URL) -> Bool
}

// MARK: - Comments

protocol CommentServiceProtocol {
    func addComment(_ comment: RecipeComment, to recipeId: String) async throws
    func getComments(for recipeId: String) async throws -> [RecipeComment]
    func deleteComment(_ commentId: String) async throws
}

// MARK: - CRDT

protocol CRDTMergeEngineProtocol {
    func merge(_ operations: [RecipeOperation]) -> Recipe
    func resolveConflict(_ recipe1: Recipe, _ recipe2: Recipe) -> Recipe
}

// MARK: - Reminders

protocol RemindersServiceProtocol {
    func addReminder(for recipe: Recipe, date: Date) async throws
    func getReminders() async throws -> [Reminder]
    func deleteReminder(_ id: String) async throws
}

// MARK: - Undo

protocol UndoServiceProtocol {
    func recordAction(_ action: UndoAction)
    func undo() async throws
    func redo() async throws
    var canUndo: Bool { get }
    var canRedo: Bool { get }
}

// MARK: - Toast

protocol ToastManagerProtocol {
    func show(_ message: String, type: ToastType)
    func show(_ message: String, type: ToastType, duration: TimeInterval)
    func dismiss()
}

// MARK: - Supporting Types

enum ExportFormat {
    case json
    case markdown
    case pdf
    case html
}

struct Reminder: Identifiable {
    let id: String
    let recipeId: String
    let date: Date
    let title: String
}

struct UndoAction {
    let id: String
    let description: String
    let execute: () async throws -> Void
    let undo: () async throws -> Void
}

// Note: ToastType is defined in ToastView.swift
