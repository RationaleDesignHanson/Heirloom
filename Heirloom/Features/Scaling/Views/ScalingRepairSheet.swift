//
//  ScalingRepairSheet.swift
//  Heirloom
//
//  Created by Claude on 2026-01-30.
//

import SwiftUI
import SwiftData
import OSLog

/// Sheet that attempts to automatically repair scaling issues
///
/// Repairs:
/// - Missing ingredient quantities via AI re-parsing
/// - (Future: Manual servings entry)
struct ScalingRepairSheet: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var isRepairing = false
    @State private var repairResult: RepairResult?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Fix Scaling")
                        .font(.title2)
                        .bold()
                    Text("We'll try to automatically fix missing data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                // Issues list
                VStack(alignment: .leading, spacing: 12) {
                    Text("Issues Found:")
                        .font(.headline)

                    ForEach(recipe.scalingValidation.issues, id: \.userMessage) { issue in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(issue.userMessage)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

                if let result = repairResult {
                    // Show results
                    VStack(spacing: 12) {
                        if result.success {
                            Label("Successfully repaired!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Fixed \(result.fixedCount) items")
                                .font(.subheadline)
                        } else {
                            Label("Could not fully repair", systemImage: "exclamationmark.circle")
                                .foregroundStyle(.orange)
                            Text(result.message)
                                .font(.subheadline)
                        }
                    }
                    .padding()
                }

                Spacer()

                // Action buttons
                if repairResult == nil {
                    Button {
                        Task { await attemptRepair() }
                    } label: {
                        if isRepairing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Repair Now")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRepairing)
                    .padding(.horizontal)
                } else {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Repair Scaling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func attemptRepair() async {
        isRepairing = true

        var fixedCount = 0

        // Try to re-parse servings if needed
        if recipe.servings == nil || recipe.parsedServingCount == 4 {
            // Could prompt user to enter servings manually in future
            // For now, log the issue
            Log.warning("Cannot auto-repair servings for recipe \(recipe.id)")
        }

        // Try to re-parse ingredient quantities
        if let ingredients = recipe.ingredients {
            let unparsed = ingredients.filter { $0.quantity == nil }

            if !unparsed.isEmpty {
                do {
                    let texts = unparsed.map { $0.originalText }
                    let parsed = try await AIIngredientParser.shared.parseBatch(texts, context: recipe.modelContext!)

                    for (index, ingredient) in unparsed.enumerated() {
                        if let parsedData = parsed[safe: index], parsedData.quantity != nil {
                            ingredient.quantity = parsedData.quantity
                            ingredient.quantityMax = parsedData.quantityMax
                            ingredient.unit = parsedData.unit
                            ingredient.normalizedUnit = parsedData.normalizedUnit
                            fixedCount += 1
                        }
                    }

                    try recipe.modelContext?.save()
                } catch {
                    Log.error("Repair failed", error: error)
                    repairResult = RepairResult(
                        success: false,
                        fixedCount: 0,
                        message: "AI parsing failed: \(error.localizedDescription)"
                    )
                    isRepairing = false
                    return
                }
            }
        }

        let totalIssues = recipe.scalingValidation.issues.count
        repairResult = RepairResult(
            success: fixedCount > 0,
            fixedCount: fixedCount,
            message: fixedCount == totalIssues ? "All issues fixed!" : "Partial repair completed"
        )

        isRepairing = false
    }
}

/// Result of repair attempt
struct RepairResult {
    let success: Bool
    let fixedCount: Int
    let message: String
}
