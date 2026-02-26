import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ZIPFoundation

/// Data export and import view with social data support
/// Note: Export now uses JSON with embedded base64 images (v2.2 format)
/// This avoids iOS file picker issues with ZIP files
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSection: Section = .export
    @State private var exportType: ExportType = .fullBackup
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?
    @State private var exportURL: URL?
    @State private var showShareSheet = false
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
            .sheet(isPresented: $showImportPicker) {
                DocumentPicker(
                    onPick: { url in
                        showImportPicker = false
                        importFileURL = url
                        Task {
                            await loadImportPreview(from: url)
                        }
                    },
                    onCancel: {
                        showImportPicker = false
                    }
                )
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
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ActivityViewController(activityItems: [url])
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
                    exportItem("All recipes with images")
                    exportItem("Your profile and settings")
                    exportItem("Theme unlock progress")
                    exportItem("Recipe comments and notes")
                } else {
                    exportItem("All recipes with images")
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

            if exportURL != nil {
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Save Export File")
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

    private func loadImportPreview(from url: URL) async {
        // With asCopy: true, the file is copied to temp directory - no security scope needed
        // But we still try in case of fallback paths
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileExtension = url.pathExtension.lowercased()

        Log.info("Loading import preview", category: .storage, metadata: [
            "extension": fileExtension,
            "url": url.lastPathComponent
        ])

        do {
            // Handle ZIP archives (.heirloombackup or .zip)
            if fileExtension == "heirloombackup" || fileExtension == "zip" {
                try await loadZIPPreview(from: url)
                return
            }

            // Handle plain JSON files
            if fileExtension == "json" {
                try await loadJSONPreview(from: url)
                return
            }

            // Unsupported file type
            await MainActor.run {
                self.exportError = "Unsupported file type: .\(fileExtension). Please select a .zip or .json backup file."
            }
            Log.warning("Unsupported import file type", category: .storage, metadata: [
                "extension": fileExtension
            ])

        } catch {
            await MainActor.run {
                self.exportError = "Failed to read import file: \(error.localizedDescription)"
            }
            Log.error("Import preview failed", category: .storage, error: error)
        }
    }

    private func loadJSONPreview(from url: URL) async throws {
        let jsonData = try Data(contentsOf: url)

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
    }

    private func loadZIPPreview(from url: URL) async throws {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let extractDir = tempDir.appendingPathComponent("heirloom-preview-\(UUID().uuidString)", isDirectory: true)

        // Create extraction directory
        try fileManager.createDirectory(at: extractDir, withIntermediateDirectories: true)

        defer {
            // Clean up extraction directory
            try? fileManager.removeItem(at: extractDir)
        }

        // Extract ZIP archive
        try fileManager.unzipItem(at: url, to: extractDir)

        // Find data.json
        let dataJsonURL = try findDataJson(in: extractDir)

        // Read and decode data.json
        let jsonData = try Data(contentsOf: dataJsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportWrapper = try decoder.decode(HeirloomExportV2.self, from: jsonData)

        // Count bundled images
        let imagesDir = findImagesDirectory(relativeTo: dataJsonURL, in: extractDir)
        var bundledImageCount = 0
        if let imagesDir = imagesDir,
           let imageFiles = try? fileManager.contentsOfDirectory(atPath: imagesDir.path) {
            bundledImageCount = imageFiles.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg") || $0.hasSuffix(".png") }.count
        }

        // Create preview data
        var warnings: [String] = []

        if exportWrapper.connections?.isEmpty == false {
            warnings.append("Connection restoration requires manual confirmation")
        }

        if bundledImageCount > 0 {
            Log.info("ZIP archive contains bundled images", category: .storage, metadata: [
                "imageCount": bundledImageCount
            ])
        }

        await MainActor.run {
            self.importPreviewData = ImportPreviewData(
                version: exportWrapper.version,
                recipeCount: exportWrapper.recipeCount,
                hasProfile: exportWrapper.userProfile != nil,
                connectionCount: exportWrapper.connections?.count ?? 0,
                hasPrivacySettings: exportWrapper.privacySettings != nil,
                warnings: warnings,
                bundledImageCount: bundledImageCount
            )
            self.showImportPreview = true
        }
    }

    /// Find data.json in extracted directory (handles both flat and nested archives)
    private func findDataJson(in directory: URL) throws -> URL {
        let fileManager = FileManager.default

        // Check root level first
        let rootDataJson = directory.appendingPathComponent("data.json")
        if fileManager.fileExists(atPath: rootDataJson.path) {
            return rootDataJson
        }

        // Check one level deep (in case ZIP was created with a containing folder)
        if let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey]) {
            for item in contents {
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    let nestedDataJson = item.appendingPathComponent("data.json")
                    if fileManager.fileExists(atPath: nestedDataJson.path) {
                        return nestedDataJson
                    }
                }
            }
        }

        throw NSError(domain: "DataExportView", code: 1, userInfo: [NSLocalizedDescriptionKey: "data.json not found in archive"])
    }

    /// Find images directory relative to data.json location
    private func findImagesDirectory(relativeTo dataJson: URL, in extractDir: URL) -> URL? {
        let fileManager = FileManager.default

        // Check in same directory as data.json
        let parentDir = dataJson.deletingLastPathComponent()
        let imagesDir = parentDir.appendingPathComponent("images", isDirectory: true)

        if fileManager.fileExists(atPath: imagesDir.path) {
            return imagesDir
        }

        return nil
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
    var bundledImageCount: Int = 0 // Number of images bundled in ZIP export
}


// MARK: - Document Picker (UIKit wrapper for better custom UTType support)

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Accept JSON files - export now uses JSON with embedded base64 images
        // Also accept ZIP for backward compatibility with v2.1 exports
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

// MARK: - Preview

#Preview {
    DataExportView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
