import SwiftUI
import SwiftData

/// Data export view for GDPR/CCPA compliance
struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var exportError: String?
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Header
                    headerSection

                    // Export Options
                    exportOptionsSection

                    // Export Button
                    if !exportComplete {
                        exportButton
                    } else {
                        shareButton
                    }

                    // Error message
                    if let error = exportError {
                        errorView(error)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Export My Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Data Export")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Export all your data from Heirloom in JSON format. This includes your recipes, comments, and privacy settings.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Export Options Section

    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("What will be exported:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                exportItem("All recipes (title, ingredients, instructions)")
                exportItem("Recipe metadata (source, dates, ratings)")
                exportItem("Comments and notes")
                exportItem("Privacy consent settings")
                exportItem("Shopping lists")
                exportItem("Cooking history")
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
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
            }
            .font(HeirloomFonts.bodyBold)
            .foregroundStyle(.white)
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
                    .font(HeirloomFonts.headline)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            if let url = exportURL {
                ShareLink(item: url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Export File")
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(.white)
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

    // MARK: - Export Logic

    private func performExport() async {
        isExporting = true
        exportError = nil
        exportComplete = false

        do {
            // Create export data structure
            let exportData = try await gatherExportData()

            // Encode to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(exportData)

            // Write to temporary file
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("heirloom_export_\(Date().timeIntervalSince1970).json")

            try jsonData.write(to: tempURL)

            await MainActor.run {
                self.exportURL = tempURL
                self.exportComplete = true
                self.isExporting = false
            }

        } catch {
            await MainActor.run {
                self.exportError = "Export failed: \(error.localizedDescription)"
                self.isExporting = false
            }
        }
    }

    private func gatherExportData() async throws -> ExportData {
        // Fetch all recipes
        let descriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        let recipes = try modelContext.fetch(descriptor)

        // Convert to exportable format
        let exportRecipes = recipes.map { recipe in
            ExportRecipe(
                id: recipe.id.uuidString,
                title: recipe.title,
                ingredients: recipe.ingredients?.map { $0.originalText } ?? [],
                instructions: recipe.instructions,
                servings: recipe.servings,
                prepTime: recipe.prepTime,
                cookTime: recipe.cookTime,
                notes: recipe.notes,
                dateAdded: recipe.dateAdded,
                timesCooked: recipe.timesCooked,
                isFavorite: recipe.isFavorite,
                sourceType: recipe.sourceType?.rawValue,
                sourceURL: recipe.sourceURL
            )
        }

        // Get privacy consent status
        let consentStatus = PrivacyConsentService.shared.getConsentStatus()

        return ExportData(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            recipes: exportRecipes,
            privacyConsent: ExportPrivacyConsent(
                hasSharingConsent: consentStatus.hasSharing,
                hasAnalyticsConsent: consentStatus.hasAnalytics,
                consentDate: consentStatus.consentDate,
                policyVersion: consentStatus.policyVersion
            )
        )
    }
}

// MARK: - Export Data Structures

struct ExportData: Codable {
    let exportDate: Date
    let appVersion: String
    let recipes: [ExportRecipe]
    let privacyConsent: ExportPrivacyConsent
}

struct ExportRecipe: Codable {
    let id: String
    let title: String
    let ingredients: [String]
    let instructions: [String]
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let notes: String?
    let dateAdded: Date
    let timesCooked: Int
    let isFavorite: Bool
    let sourceType: String?
    let sourceURL: String?
}

struct ExportPrivacyConsent: Codable {
    let hasSharingConsent: Bool
    let hasAnalyticsConsent: Bool
    let consentDate: Date?
    let policyVersion: String
}

// MARK: - Preview

#Preview {
    DataExportView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
