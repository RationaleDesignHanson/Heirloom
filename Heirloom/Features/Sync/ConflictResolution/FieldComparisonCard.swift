//
//  FieldComparisonCard.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import SwiftUI

/// Card showing side-by-side comparison of conflicting field values
/// Supports swipe gestures for quick resolution
struct FieldComparisonCard: View {
    let conflict: DetailedConflict
    @Binding var resolution: ConflictResolution.ResolutionChoice?

    @State private var dragOffset: CGFloat = 0
    @State private var showingDetailSheet = false

    // Swipe threshold (points)
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // Field name header
            Text(conflict.fieldDisplayName.capitalized)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            // Side-by-side comparison
            HStack(spacing: HeirloomSpacing.md) {
                // Local version (left)
                versionCard(
                    title: "Your Version",
                    deviceName: conflict.localDeviceName,
                    value: conflict.localValue,
                    isSelected: resolution == .keepLocal
                )
                .opacity(dragOffset < 0 ? 1.0 : 0.6)
                .scaleEffect(dragOffset < -swipeThreshold ? 1.05 : 1.0)

                // Remote version (right)
                versionCard(
                    title: remoteVersionTitle,
                    deviceName: conflict.remoteDeviceName,
                    value: conflict.remoteValue,
                    isSelected: resolution == .keepRemote
                )
                .opacity(dragOffset > 0 ? 1.0 : 0.6)
                .scaleEffect(dragOffset > swipeThreshold ? 1.05 : 1.0)
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        handleSwipeEnd(translation: value.translation.width)
                    }
            )

            // Swipe hint (if not resolved yet)
            if resolution == nil {
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw")
                            .font(.caption2)
                        Text("Swipe to choose")
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(HeirloomColors.conflictInfo)
                    Spacer()
                }
            }

            // Tap to see details button
            Button {
                showingDetailSheet = true
            } label: {
                HStack {
                    Spacer()
                    Text("View Details")
                        .font(HeirloomFonts.caption1)
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Spacer()
                }
                .foregroundStyle(HeirloomColors.conflictInfo)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictCardBackground)
        .cornerRadius(12)
        .shadow(color: HeirloomColors.cardShadow, radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingDetailSheet) {
            detailSheet
        }
    }

    // MARK: - Version Card

    @ViewBuilder
    private func versionCard(
        title: String,
        deviceName: String,
        value: OperationValue?,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .textCase(.uppercase)

                Text(deviceName)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.conflictNeutral)
            }

            // Value
            Text(displayValue(value))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
                .lineLimit(3)

            // Selected indicator
            if isSelected {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Selected")
                        .font(HeirloomFonts.caption2)
                }
                .foregroundStyle(HeirloomColors.conflictSafe)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(HeirloomSpacing.sm)
        .background(isSelected ? HeirloomColors.conflictSelectedBackground : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? HeirloomColors.conflictSafe : Color.clear, lineWidth: 2)
        )
        .cornerRadius(8)
    }

    // MARK: - Detail Sheet

    private var detailSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                    // What changed section
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("What Changed?")
                            .font(HeirloomFonts.title3)
                            .foregroundStyle(HeirloomColors.primaryText)

                        changeDescription
                    }

                    Divider()

                    // Full comparison
                    VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                        fullVersionCard(
                            title: "Your Version",
                            deviceName: conflict.localDeviceName,
                            timestamp: conflict.localTimestamp,
                            value: conflict.localValue
                        )

                        fullVersionCard(
                            title: remoteVersionTitle,
                            deviceName: conflict.remoteDeviceName,
                            timestamp: conflict.remoteTimestamp,
                            value: conflict.remoteValue
                        )
                    }

                    // Resolution options
                    VStack(spacing: HeirloomSpacing.sm) {
                        Text("Choose Version")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        Button {
                            resolution = .keepLocal
                            showingDetailSheet = false
                        } label: {
                            HStack {
                                Text("Keep Your Version")
                                Spacer()
                                if resolution == .keepLocal {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(HeirloomColors.conflictSafe)
                                }
                            }
                            .padding()
                            .background(HeirloomColors.cream)
                            .cornerRadius(8)
                        }
                        .foregroundStyle(HeirloomColors.primaryText)

                        Button {
                            resolution = .keepRemote
                            showingDetailSheet = false
                        } label: {
                            HStack {
                                Text("Keep \(conflict.remoteDeviceName)'s Version")
                                Spacer()
                                if resolution == .keepRemote {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(HeirloomColors.conflictSafe)
                                }
                            }
                            .padding()
                            .background(HeirloomColors.cream)
                            .cornerRadius(8)
                        }
                        .foregroundStyle(HeirloomColors.primaryText)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .navigationTitle(conflict.fieldDisplayName.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDetailSheet = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fullVersionCard(
        title: String,
        deviceName: String,
        timestamp: Date,
        value: OperationValue?
    ) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text(title)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(deviceName)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text(timestamp, style: .relative) + Text(" ago")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.conflictNeutral)

            Divider()

            Text(displayValue(value))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(8)
    }

    private var changeDescription: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(HeirloomColors.conflictInfo)
                    .font(.caption)

                Text("You changed it to:")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            Text(displayValue(conflict.localValue))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(HeirloomColors.conflictInfo)
                    .font(.caption)

                Text("\(conflict.remoteDeviceName) changed it to:")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            Text(displayValue(conflict.remoteValue))
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .padding(HeirloomSpacing.sm)
        .background(HeirloomColors.cream)
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func handleSwipeEnd(translation: CGFloat) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if translation < -swipeThreshold {
                // Swiped left - keep local
                resolution = .keepLocal
                dragOffset = 0
            } else if translation > swipeThreshold {
                // Swiped right - keep remote
                resolution = .keepRemote
                dragOffset = 0
            } else {
                // Not far enough - snap back
                dragOffset = 0
            }
        }
    }

    private func displayValue(_ value: OperationValue?) -> String {
        guard let value = value else { return "No value" }

        switch value {
        case .string(let str):
            return str
        case .int(let num):
            return "\(num)"
        case .double(let num):
            return String(format: "%.1f", num)
        case .bool(let bool):
            return bool ? "Yes" : "No"
        case .stringArray(let arr):
            return arr.joined(separator: ", ")
        case .null:
            return "None"
        }
    }

    private var remoteVersionTitle: String {
        if let userName = conflict.remoteUserName {
            return "\(userName)'s Version"
        } else {
            return "Other Version"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FieldComparisonCard(
            conflict: DetailedConflict(
                fieldPath: "servings",
                fieldDisplayName: "servings",
                localValue: .string("4 servings"),
                remoteValue: .string("6 servings"),
                localDeviceName: "Your iPhone",
                remoteDeviceName: "Mom's iPad",
                localUserName: nil,
                remoteUserName: "Mom",
                localTimestamp: Date().addingTimeInterval(-3600),
                remoteTimestamp: Date().addingTimeInterval(-1800),
                operation1: RecipeOperation(
                    recipeId: UUID(),
                    deviceId: "device1",
                    vectorClock: VectorClock(),
                    operationType: .update,
                    fieldPath: "servings"
                ),
                operation2: RecipeOperation(
                    recipeId: UUID(),
                    deviceId: "device2",
                    vectorClock: VectorClock(),
                    operationType: .update,
                    fieldPath: "servings"
                )
            ),
            resolution: .constant(nil)
        )
    }
    .padding()
    .background(HeirloomColors.cream)
}
