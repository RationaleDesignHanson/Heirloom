//
//  RecipeExportView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-13.
//

import SwiftUI
import SwiftData

/// UI for exporting recipes to JSON or PDF
struct RecipeExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var exportFormat: RecipeExportFormat = .json
    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    private var toastManager: ToastManager {
        ServiceContainer.shared.resolve(ToastManager.self)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.xl) {
                // Header
                headerSection

                // Format picker
                formatPicker

                // Export button
                exportButton

                Spacer()
            }
            .padding()
            .background(HeirloomColors.appBackground)
            .navigationTitle("Export Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange.gradient)

            Text("Export Your Recipes")
                .font(HeirloomFonts.title2)
                .fontWeight(.bold)

            Text("Download all your recipes to keep forever")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    // MARK: - Format Picker

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Export Format")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(spacing: HeirloomSpacing.sm) {
                FormatOptionCard(
                    format: .json,
                    isSelected: exportFormat == .json,
                    onSelect: { exportFormat = .json }
                )

                FormatOptionCard(
                    format: .pdf,
                    isSelected: exportFormat == .pdf,
                    onSelect: { exportFormat = .pdf }
                )
            }
        }
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            performExport()
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                if isExporting {
                    ProgressView()
                        .tint(HeirloomColors.buttonTextLight)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Export Recipes")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.orange.gradient)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .cornerRadius(12)
        }
        .disabled(isExporting)
    }

    // MARK: - Export Action

    private func performExport() {
        isExporting = true
        errorMessage = nil

        Task {
            do {
                let exporter = RecipeExporter()
                let fileURL: URL

                switch exportFormat {
                case .json:
                    fileURL = try await exporter.exportAsJSON(context: modelContext)
                case .pdf:
                    fileURL = try await exporter.exportAsPDF(context: modelContext)
                }

                await MainActor.run {
                    isExporting = false
                    exportedFileURL = fileURL
                    showShareSheet = true

                    toastManager.success(
                        title: "Export Complete",
                        message: "Your recipes are ready to share"
                    )
                }
            } catch RecipeExportError.noRecipesToExport {
                await MainActor.run {
                    isExporting = false
                    errorMessage = "You don't have any recipes to export yet"
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Export Format

enum RecipeExportFormat: String, CaseIterable {
    case json = "JSON"
    case pdf = "PDF"

    var icon: String {
        switch self {
        case .json: return "doc.text.fill"
        case .pdf: return "doc.richtext.fill"
        }
    }

    var description: String {
        switch self {
        case .json:
            return "Machine-readable format perfect for importing into other apps"
        case .pdf:
            return "Printable format with beautiful formatting for cookbooks"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return ".json"
        case .pdf: return ".pdf"
        }
    }
}

// MARK: - Format Option Card

struct FormatOptionCard: View {
    let format: RecipeExportFormat
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: HeirloomSpacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? .orange.opacity(0.2) : Color(.systemGray6))
                        .frame(width: 48, height: 48)

                    Image(systemName: format.icon)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(isSelected ? .orange : HeirloomColors.charcoal.opacity(0.6))
                }

                // Content
                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                    Text(format.rawValue)
                        .font(HeirloomFonts.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(format.description)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(HeirloomSpacing.md)
            .background(Color(.systemBackground))
            .cornerRadius(HeirloomSpacing.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                    .stroke(isSelected ? .orange : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview

#Preview {
    RecipeExportView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
