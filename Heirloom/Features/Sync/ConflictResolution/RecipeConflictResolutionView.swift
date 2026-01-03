//
//  RecipeConflictResolutionView.swift
//  Heirloom
//
//  Created by Claude on 12/31/25.
//

import SwiftUI
import SwiftData

/// Main view for resolving recipe conflicts
/// Orchestrates the conflict resolution flow with CRDT merge
struct RecipeConflictResolutionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let conflicts: [DetailedConflict]
    let recipeCRDT: RecipeCRDT

    @State private var resolutions: [String: ConflictResolution.ResolutionChoice] = [:]
    @State private var showingPreview = false
    @State private var isSaving = false
    @State private var animateEntrance = false

    var body: some View {
        NavigationView {
            ZStack {
                if showingPreview {
                    // Show preview after all conflicts resolved
                    MergedRecipePreview(
                        recipe: recipeCRDT.recipe,
                        resolutions: buildResolutionsList(),
                        onConfirm: {
                            Task {
                                await saveResolution()
                            }
                        },
                        onCancel: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showingPreview = false
                            }
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    // Show conflict resolution UI
                    conflictResolutionContent
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .navigationTitle("Merge Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        // Dismiss without resolving
                        dismiss()
                    }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                    animateEntrance = true
                }
            }
        }
    }

    // MARK: - Conflict Resolution Content

    private var conflictResolutionContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Header card
                ConflictHeaderCard(
                    recipeTitle: recipeCRDT.recipe.title,
                    conflictCount: conflicts.count,
                    sourceDevice: conflicts.first?.remoteDeviceName,
                    sourceUser: conflicts.first?.remoteUserName
                )
                .opacity(animateEntrance ? 1 : 0)
                .offset(y: animateEntrance ? 0 : -20)

                // Conflicting fields section
                VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                    sectionHeader(
                        title: "Conflicting Fields",
                        subtitle: "These fields were changed differently",
                        icon: "exclamationmark.triangle.fill",
                        color: HeirloomColors.conflictAlert
                    )
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : -20)

                    ForEach(Array(conflicts.enumerated()), id: \.offset) { index, conflict in
                        FieldComparisonCard(
                            conflict: conflict,
                            resolution: Binding(
                                get: { resolutions[conflict.fieldPath] },
                                set: { resolutions[conflict.fieldPath] = $0 }
                            )
                        )
                        .opacity(animateEntrance ? 1 : 0)
                        .offset(y: animateEntrance ? 0 : -20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: animateEntrance)
                    }
                }

                // Progress indicator
                progressIndicator
                    .opacity(animateEntrance ? 1 : 0)
                    .offset(y: animateEntrance ? 0 : -20)

                // Preview button (enabled when all conflicts resolved)
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingPreview = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "eye.circle.fill")
                        Text("Preview Merged Recipe")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(allConflictsResolved ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
                    .foregroundStyle(.white)
                    .font(HeirloomFonts.bodyBold)
                    .cornerRadius(12)
                }
                .disabled(!allConflictsResolved)
                .opacity(animateEntrance ? 1 : 0)
                .offset(y: animateEntrance ? 0 : -20)
                .scaleEffect(allConflictsResolved ? 1.0 : 0.98)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: allConflictsResolved)

                if !allConflictsResolved {
                    HStack {
                        Spacer()
                        Text("Resolve all conflicts to continue")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                        Spacer()
                    }
                }

                // Help text
                helpSection
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.cream)
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Text("Progress")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .textCase(.uppercase)

                Spacer()

                Text("\(resolvedCount) of \(conflicts.count)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(HeirloomColors.warmGray.opacity(0.2))
                        .frame(height: 8)

                    // Progress bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [HeirloomColors.conflictSafe, HeirloomColors.familyGreen],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .animation(.spring(response: 0.4), value: progressPercentage)
                }
            }
            .frame(height: 8)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictCardBackground)
        .cornerRadius(8)
    }

    // MARK: - Help Section

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(HeirloomColors.conflictInfo)
                Text("What's Happening?")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("You edited this recipe on multiple devices, and some fields were changed differently. Choose which version to keep for each field.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("Don't worry - nothing gets deleted until you save. Your original recipe is always safe.")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.conflictNeutral)
                .italic()
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.conflictInfo.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Computed Properties

    private var allConflictsResolved: Bool {
        return resolvedCount == conflicts.count
    }

    private var resolvedCount: Int {
        return resolutions.count
    }

    private var progressPercentage: CGFloat {
        guard conflicts.count > 0 else { return 0 }
        return CGFloat(resolvedCount) / CGFloat(conflicts.count)
    }

    // MARK: - Actions

    private func buildResolutionsList() -> [ConflictResolution] {
        return conflicts.compactMap { conflict in
            guard let choice = resolutions[conflict.fieldPath] else { return nil }

            return ConflictResolution(
                fieldPath: conflict.fieldPath,
                localOperationId: conflict.operation1.id,
                remoteOperationId: conflict.operation2.id,
                choice: choice
            )
        }
    }

    @MainActor
    private func saveResolution() async {
        isSaving = true
        defer { isSaving = false }

        // Build resolutions list
        let resolutionsList = buildResolutionsList()

        // Apply resolutions to CRDT
        CRDTMergeEngine.shared.applyUserResolution(resolutionsList, to: recipeCRDT)

        // Save to database
        do {
            try modelContext.save()

            // Sync to Firebase
            if BackendConfig.shared.isFirebaseActive {
                // Note: Firebase sync will be updated in Phase 4 to use CRDT
                // For now, just upload the resolved recipe
                try await FirebaseSyncService.shared.uploadRecipe(recipeCRDT.recipe)
            }

            // Show success
            ToastManager.shared.success(
                title: "Recipe Merged",
                message: "All conflicts resolved successfully"
            )

            // Track analytics
            AnalyticsService.shared.track(event: .conflictResolved, properties: [
                "conflict_count": conflicts.count,
                "resolution_time": Date().timeIntervalSince(recipeCRDT.recipe.modifiedAt)
            ])

            dismiss()
        } catch {
            // Show error
            ToastManager.shared.error(
                title: "Failed to Save",
                message: error.localizedDescription
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let recipe = Recipe(
        title: "Grandma's Lasagna",
        sourceType: .manual,
        instructions: ["Step 1", "Step 2"],
        servings: "8 servings",
        prepTime: "30 min",
        cookTime: "45 min"
    )

    let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "device1"
    let crdt = RecipeCRDT(recipe: recipe, deviceId: deviceId)

    let conflicts = [
        DetailedConflict(
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
                recipeId: recipe.id,
                deviceId: deviceId,
                vectorClock: VectorClock(),
                operationType: .update,
                fieldPath: "servings"
            ),
            operation2: RecipeOperation(
                recipeId: recipe.id,
                deviceId: "device2",
                vectorClock: VectorClock(),
                operationType: .update,
                fieldPath: "servings"
            )
        ),
        DetailedConflict(
            fieldPath: "cookTime",
            fieldDisplayName: "cook time",
            localValue: .string("45 min"),
            remoteValue: .string("60 min"),
            localDeviceName: "Your iPhone",
            remoteDeviceName: "Mom's iPad",
            localUserName: nil,
            remoteUserName: "Mom",
            localTimestamp: Date().addingTimeInterval(-3600),
            remoteTimestamp: Date().addingTimeInterval(-1800),
            operation1: RecipeOperation(
                recipeId: recipe.id,
                deviceId: deviceId,
                vectorClock: VectorClock(),
                operationType: .update,
                fieldPath: "cookTime"
            ),
            operation2: RecipeOperation(
                recipeId: recipe.id,
                deviceId: "device2",
                vectorClock: VectorClock(),
                operationType: .update,
                fieldPath: "cookTime"
            )
        )
    ]

    return RecipeConflictResolutionView(
        conflicts: conflicts,
        recipeCRDT: crdt
    )
    .modelContainer(for: Recipe.self, inMemory: true)
}
