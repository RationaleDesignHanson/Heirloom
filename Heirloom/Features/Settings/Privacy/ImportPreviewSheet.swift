//
//  ImportPreviewSheet.swift
//  Heirloom
//
//  Social Layer Phase 7: Import preview with confirmation
//  Shows what will be imported before user confirms
//

import SwiftUI
import SwiftData

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let previewData: ImportPreviewData
    let fileURL: URL
    let modelContext: ModelContext

    @State private var isImporting = false
    @State private var importResult: HeirloomImportResult?
    @State private var showResult = false
    @State private var importError: String?

    private var exporter: HeirloomDataExporter {
        let profileService: ProfileServiceProtocol = ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
        let connectionService: ConnectionServiceProtocol = ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
        let recipeExporter: RecipeExporter = ServiceContainer.shared.resolve(RecipeExporter.self)
        return HeirloomDataExporter(
            profileService: profileService,
            connectionService: connectionService,
            recipeExporter: recipeExporter
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    if !showResult {
                        previewSection
                    } else if let result = importResult {
                        resultSection(result)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showResult {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button("Import") {
                            Task {
                                await performImport()
                            }
                        }
                        .disabled(isImporting)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Header
            headerSection

            // What will be imported
            importCountsSection

            // Warnings
            if !previewData.warnings.isEmpty {
                warningsSection
            }

            // Instructions
            instructionsSection
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.familyGreen)

                Text("Ready to Import")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Review what will be imported from this backup file.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var importCountsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("What will be imported:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                importCountRow(
                    icon: "fork.knife.circle.fill",
                    title: "Recipes",
                    count: previewData.recipeCount,
                    color: HeirloomColors.tomato
                )

                if previewData.hasProfile {
                    importCountRow(
                        icon: "person.circle.fill",
                        title: "Profile Data",
                        count: 1,
                        color: HeirloomColors.familyGreen
                    )
                }

                if previewData.connectionCount > 0 {
                    importCountRow(
                        icon: "person.2.circle.fill",
                        title: "Connections",
                        count: previewData.connectionCount,
                        color: HeirloomColors.familyGreen
                    )
                }

                if previewData.hasPrivacySettings {
                    importCountRow(
                        icon: "lock.circle.fill",
                        title: "Privacy Settings",
                        count: 1,
                        color: HeirloomColors.warmGray
                    )
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func importCountRow(icon: String, title: String, count: Int, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            Text(title)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text("\(count)")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(HeirloomColors.warning)

                Text("Important Notes")
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                ForEach(previewData.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Text("•")
                            .foregroundStyle(HeirloomColors.warning)
                        Text(warning)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.warning.opacity(0.1))
        .cornerRadius(12)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("How import works:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                instructionItem("Recipes will be merged with your existing collection")
                instructionItem("Duplicate recipes will be skipped")
                instructionItem("Your current data won't be deleted")
                instructionItem("Connections may require manual reconnection")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func instructionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.top, 2)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(_ result: HeirloomImportResult) -> some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Success/Error Header
            if result.errors.isEmpty {
                successHeader
            } else {
                partialSuccessHeader
            }

            // Import Statistics
            statisticsSection(result)

            // Errors (if any)
            if !result.errors.isEmpty {
                errorsSection(result)
            }
        }
    }

    private var successHeader: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.success)

            Text("Import Complete")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Your data has been successfully imported.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var partialSuccessHeader: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warning)

            Text("Import Completed with Warnings")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Some items couldn't be imported. See details below.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func statisticsSection(_ result: HeirloomImportResult) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Import Summary")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                statisticRow(icon: "fork.knife.circle.fill", title: "Recipes", count: result.recipesImported)

                if let connectionsCount = result.connectionsImported {
                    statisticRow(icon: "person.2.circle.fill", title: "Connections", count: connectionsCount)
                }

                if !result.errors.isEmpty {
                    statisticRow(
                        icon: "exclamationmark.circle.fill",
                        title: "Errors",
                        count: result.errors.count,
                        color: HeirloomColors.tomato
                    )
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func statisticRow(icon: String, title: String, count: Int, color: Color = HeirloomColors.familyGreen) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            Text(title)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text("\(count)")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    @ViewBuilder
    private func errorsSection(_ result: HeirloomImportResult) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Errors")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                ForEach(result.errors.prefix(10), id: \.message) { error in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(HeirloomColors.tomato)
                            .padding(.top, 2)

                        Text(error.message)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                if result.errors.count > 10 {
                    Text("...and \(result.errors.count - 10) more")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.tomato.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Import Logic

    private func performImport() async {
        isImporting = true
        importError = nil

        do {
            let result = try await exporter.importData(
                from: fileURL,
                context: modelContext,
                options: .mergeAll
            )

            await MainActor.run {
                self.importResult = result
                self.showResult = true
                self.isImporting = false
            }

            Log.info("Import completed", category: .storage, metadata: [
                "version": result.version,
                "recipesImported": result.recipesImported,
                "errorCount": result.errors.count
            ])

        } catch {
            await MainActor.run {
                self.importError = error.localizedDescription
                self.isImporting = false
            }

            Log.error("Import failed", category: .storage, error: error)
        }
    }
}

// MARK: - Preview

#Preview {
    ImportPreviewSheet(
        previewData: ImportPreviewData(
            version: 2,
            recipeCount: 42,
            hasProfile: true,
            connectionCount: 8,
            hasPrivacySettings: true,
            warnings: ["Connection restoration requires manual confirmation"]
        ),
        fileURL: URL(fileURLWithPath: "/tmp/test.json"),
        modelContext: ModelContext(try! ModelContainer(for: Recipe.self))
    )
}
