//
//  ASMRPassProgressCard.swift
//  Heirloom
//
//  Created by Claude on 1/10/26.
//

import SwiftUI

/// Shows progress and findings for a single ASMR processing pass
struct ASMRPassProgressCard: View {
    let pass: ASMRProcessingPass
    let isActive: Bool
    let isComplete: Bool
    let findings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with pass name and status
            HStack {
                // Pass number indicator (matches regular video import style)
                ZStack {
                    // Outer circle
                    Circle()
                        .fill(statusColor.opacity(isComplete ? 1.0 : 0.15))
                        .frame(width: 40, height: 40)

                    if isComplete {
                        // Checkmark for completed passes
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        // Show number for pending and active phases
                        ZStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 28, height: 28)

                            if isActive {
                                // Spinner while active (matches regular video import)
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                // Pass number for pending
                                Text("\(pass.rawValue + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                // Pass name
                Text(pass.displayName)
                    .font(.headline)
                    .foregroundStyle(isActive ? .primary : .secondary)

                Spacer()
            }

            // Live findings
            if !findings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(findings, id: \.self) { finding in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)

                            Text(finding)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isActive ? 2 : 1)
        )
        .animation(.easeInOut, value: isActive)
        .animation(.easeInOut, value: isComplete)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if isComplete {
            return .green
        } else if isActive {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }

    private var cardBackground: Color {
        if isActive {
            return Color.blue.opacity(0.05)
        } else {
            return Color(.systemGray6)
        }
    }

    private var borderColor: Color {
        if isActive {
            return .blue
        } else if isComplete {
            return .green.opacity(0.3)
        } else {
            return .clear
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // Completed pass
        ASMRPassProgressCard(
            pass: .identifying,
            isActive: false,
            isComplete: true,
            findings: [
                "Identified: Carbonara Pasta",
                "Type: Italian pasta",
                "Confidence: 92%"
            ]
        )

        // Active pass with findings
        ASMRPassProgressCard(
            pass: .detecting,
            isActive: true,
            isComplete: false,
            findings: [
                "Found: Bacon",
                "Found: Eggs",
                "Found: Parmesan cheese"
            ]
        )

        // Pending pass
        ASMRPassProgressCard(
            pass: .inferring,
            isActive: false,
            isComplete: false,
            findings: []
        )
    }
    .padding()
}
