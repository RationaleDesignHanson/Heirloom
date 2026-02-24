import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Data export and import view with social data support
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSection: Section = .export
    @State private var exportType: ExportType = .fullBackup
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?
    @State private var exportURL: URL?
    @State private var showImportPicker = false
    @State private var showImportPreview = false
    @State private var importFileURL: URL?
    @State private var importPreviewData: ImportPreviewData?

    enum Section: String, CaseIterable {
        case export = "Export"
        case `import` = "Import"
    }

    enum ExportType: String, CaseIterable {
        case fullBackup = "Full Backup"
        case recipesOnly = "Recipes Only"

        var description: String {
            switch self {
            case .fullBackup:
                return "Recipes, profile, connections, and settings"
            case .recipesOnly:
                return "Only your recipes"
            }
        }

        var options: HeirloomExportOptions {
            switch self {
            case .fullBackup:
                return .fullExport
            case .recipesOnly:
                return .recipesOnly
            }
        }
    }

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
                    // Section Picker
                    sectionPicker

                    // Content based on selected section
                    if selectedSection == .export {
                        exportSection
                    } else {
                        importSection
                    }

                    // Error message
                    if let error = exportError {
                        errorView(error)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportFile(result)
            }
            .sheet(isPresented: $showImportPreview) {
                if let previewData = importPreviewData, let fileURL = importFileURL {
                    ImportPreviewSheet(
                        previewData: previewData,
                        fileURL: fileURL,
                        modelContext: modelContext
                    )
                }
            }
        }
    }

    // MARK: - Section Picker

    private var sectionPicker: some View {
        Picker("Section", selection: $selectedSection) {
            ForEach(Section.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedSection) { _, _ in
            // Reset state when switching sections
            exportComplete = false
            exportError = nil
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Header
            exportHeaderSection

            // Export Type Selector
            exportTypeSelector

            // What will be exported
            exportOptionsSection

            // Export Button
            if !exportComplete {
                exportButton
            } else {
                shareButton
            }
        }
    }

    // MARK: - Export Header Section

    private var exportHeaderSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Export Data")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Export your Heirloom data to a JSON file. Choose between a full backup or recipes only.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Export Type Selector

    private var exportTypeSelector: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Export Type")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(spacing: HeirloomSpacing.xs) {
                ForEach(ExportType.allCases, id: \.self) { type in
                    exportTypeOption(type)
                }
            }
        }
    }

    @ViewBuilder
    private func exportTypeOption(_ type: ExportType) -> some View {
        Button {
            exportType = type
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(type.description)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()

                Image(systemName: exportType == type ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(exportType == type ? HeirloomColors.tomato : HeirloomColors.warmGray)
                    .font(.title3)
            }
            .padding(HeirloomSpacing.md)
            .background(exportType == type ? HeirloomColors.cream : HeirloomColors.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(exportType == type ? HeirloomColors.tomato : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export Options Section

    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("What will be exported:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                if exportType == .fullBackup {
                    exportItem("All recipes (title, ingredients, instructions)")
                    exportItem("Your profile (name, bio, specialties)")
                    exportItem("Connections and relationships")
                    exportItem("Privacy settings")
                    exportItem("Recipe comments and notes")
                } else {
                    exportItem("All recipes (title, ingredients, instructions)")
                    exportItem("Recipe metadata (source, dates, ratings)")
                    exportItem("Comments and notes")
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func exportItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.top, 2)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            Task {
                await performExport()
            }
        } label: {
            HStack {
                if isExporting {
                    ProgressView()
                        .tint(HeirloomColors.buttonTextLight)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .cornerRadius(12)
        }
        .disabled(isExporting)
        .buttonStyle(.plain)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        VStack(spacing: HeirloomSpacing.md) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 24))

                Text("Export Complete")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            if let url = exportURL {
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Export File")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        HStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(error)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(.red)
        }
        .padding(HeirloomSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Import Section

    private var importSection: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Import Header
            importHeaderSection

            // Import Instructions
            importInstructionsSection

            // Import Button
            importButton
        }
    }

    private var importHeaderSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "square.and.arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.familyGreen)

                Text("Import Data")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Restore your Heirloom data from a previously exported JSON file. You'll see a preview before importing.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importInstructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("What will be imported:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                exportItem("Recipes (merged with existing)")
                exportItem("Profile data (if present in backup)")
                exportItem("Connections (will attempt to reconnect)")
                exportItem("Privacy settings (if present in backup)")
            }

            Text("Note: Existing data won't be deleted. New recipes will be added alongside your current collection.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.top, HeirloomSpacing.xs)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    private var importButton: some View {
        Button {
            showImportPicker = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Choose Import File")
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.familyGreen)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export Logic

    private func performExport() async {
        isExporting = true
        exportError = nil
        exportComplete = false

        do {
            // Use HeirloomDataExporter service
            let fileURL = try await exporter.exportAllData(
                context: modelContext,
                options: exportType.options
            )

            await MainActor.run {
                self.exportURL = fileURL
                self.exportComplete = true
                self.isExporting = false
            }

            Log.info("Export completed", category: .storage, metadata: [
                "exportType": exportType.rawValue
            ])

        } catch {
            await MainActor.run {
                self.exportError = "Export failed: \(error.localizedDescription)"
                self.isExporting = false
            }

            Log.error("Export failed", category: .storage, error: error)
        }
    }

    // MARK: - Import Logic

    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Save URL and load preview
            importFileURL = url
            Task {
                await loadImportPreview(from: url)
            }

        case .failure(let error):
            exportError = "File selection failed: \(error.localizedDescription)"
            Log.error("Import file selection failed", category: .storage, error: error)
        }
    }

    private func loadImportPreview(from url: URL) async {
        // Security-scoped access is required for files selected via fileImporter
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Read JSON file
            let jsonData = try Data(contentsOf: url)

            // Decode to determine version and contents
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let exportWrapper: HeirloomExportV2
            do {
                exportWrapper = try decoder.decode(HeirloomExportV2.self, from: jsonData)
            } catch {
                // Try v1 format
                Log.info("Attempting v1 import preview", category: .storage)
                let v1Wrapper = try decoder.decode(RecipeExportWrapper.self, from: jsonData)

                await MainActor.run {
                    self.importPreviewData = ImportPreviewData(
                        version: 1,
                        recipeCount: v1Wrapper.recipes.count,
                        hasProfile: false,
                        connectionCount: 0,
                        hasPrivacySettings: false,
                        warnings: ["This is a recipes-only export (v1 format)"]
                    )
                    self.showImportPreview = true
                }
                return
            }

            // Create preview data
            var warnings: [String] = []

            if exportWrapper.connections?.isEmpty == false {
                warnings.append("Connection restoration requires manual confirmation")
            }

            await MainActor.run {
                self.importPreviewData = ImportPreviewData(
                    version: exportWrapper.version,
                    recipeCount: exportWrapper.recipeCount,
                    hasProfile: exportWrapper.userProfile != nil,
                    connectionCount: exportWrapper.connections?.count ?? 0,
                    hasPrivacySettings: exportWrapper.privacySettings != nil,
                    warnings: warnings
                )
                self.showImportPreview = true
            }

        } catch {
            await MainActor.run {
                self.exportError = "Failed to read import file: \(error.localizedDescription)"
            }
            Log.error("Import preview failed", category: .storage, error: error)
        }
    }
}

// MARK: - Import Preview Data

struct ImportPreviewData {
    let version: Int
    let recipeCount: Int
    let hasProfile: Bool
    let connectionCount: Int
    let hasPrivacySettings: Bool
    let warnings: [String]
}

// MARK: - Preview

#Preview {
    DataExportView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
