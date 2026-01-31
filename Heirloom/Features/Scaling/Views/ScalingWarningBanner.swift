//
//  ScalingWarningBanner.swift
//  Heirloom
//
//  Created by Claude on 2026-01-30.
//

import SwiftUI
import SwiftData

/// Warning banner displayed when recipe has scaling limitations
///
/// Shows when:
/// - Servings cannot be parsed
/// - Ingredients are missing quantities
///
/// Provides "Fix" button to attempt automatic repair
struct ScalingWarningBanner: View {
    let validation: Recipe.ScalingValidation
    @Binding var showRepairSheet: Bool

    var body: some View {
        if !validation.isFullyScalable {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Scaling Limited")
                        .font(.subheadline)
                        .bold()
                    Spacer()
                    Button("Fix") {
                        showRepairSheet = true
                    }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
                }

                ForEach(validation.issues, id: \.userMessage) { issue in
                    Text("• \(issue.userMessage)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }
}
