//
//  ScalingDiagnostics.swift
//  Heirloom
//
//  Created by Claude on 2026-01-30.
//

import Foundation
import SwiftData
import OSLog

/// Diagnostic service for tracking servings scaling issues
///
/// Provides structured logging to identify:
/// - Servings parsing failures
/// - Missing ingredient quantities
/// - Scaling attempt success/failure
@MainActor
class ScalingDiagnostics {
    static let shared = ScalingDiagnostics()

    private let logger = Logger(subsystem: "com.rationaledesign.heirloom", category: "scaling")

    private init() {}

    /// Logs when servings string cannot be parsed
    ///
    /// - Parameters:
    ///   - recipe: The recipe with unparseable servings
    ///   - rawServings: The raw servings string that failed to parse (or nil)
    func logServingsParsingFailure(recipe: Recipe, rawServings: String?) {
        logger.warning("Failed to parse servings - defaulting to 4 | recipeId=\(recipe.id.uuidString, privacy: .public) sourceType=\(recipe.sourceType.rawValue, privacy: .public) rawServings=\(rawServings ?? "nil", privacy: .public)")
    }

    /// Logs when recipe has ingredients without quantities
    ///
    /// - Parameters:
    ///   - recipe: The recipe with missing quantities
    ///   - missingCount: Number of ingredients without quantities
    ///   - totalCount: Total number of ingredients
    func logMissingQuantities(recipe: Recipe, missingCount: Int, totalCount: Int) {
        let percentMissing = totalCount > 0 ? Double(missingCount) / Double(totalCount) * 100 : 0

        logger.warning("Recipe has ingredients without quantities | recipeId=\(recipe.id.uuidString, privacy: .public) sourceType=\(recipe.sourceType.rawValue, privacy: .public) missingCount=\(missingCount, privacy: .public) totalCount=\(totalCount, privacy: .public) percentMissing=\(String(format: "%.1f", percentMissing), privacy: .public)%")
    }

    /// Logs scaling attempt outcome
    ///
    /// - Parameters:
    ///   - recipe: The recipe being scaled
    ///   - targetServings: The target number of servings
    ///   - success: Whether the scaling was successful
    func logScalingAttempt(recipe: Recipe, targetServings: Int, success: Bool) {
        if success {
            let scaleFactor = Double(targetServings) / Double(recipe.parsedServingCount)
            logger.info("Scaling successful | recipeId=\(recipe.id.uuidString, privacy: .public) originalServings=\(recipe.parsedServingCount, privacy: .public) targetServings=\(targetServings, privacy: .public) scaleFactor=\(String(format: "%.2f", scaleFactor), privacy: .public)")
        } else {
            logger.error("Scaling failed | recipeId=\(recipe.id.uuidString, privacy: .public) targetServings=\(targetServings, privacy: .public)")
        }
    }
}
