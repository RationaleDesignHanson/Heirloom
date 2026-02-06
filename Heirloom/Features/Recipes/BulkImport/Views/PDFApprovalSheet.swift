//
//  PDFApprovalSheet.swift
//  Heirloom
//
//  Approval sheet for PDF imports from share extension
//  Shows preview, cost estimate, and image generation toggle
//

import SwiftUI
import PDFKit

/// Approval sheet for PDF imports requiring user confirmation
struct PDFApprovalSheet: View {
    let pdfURL: URL
    let onApprove: (Bool) -> Void  // Bool = generateImages
    let onCancel: () -> Void

    @State private var generateImages = false
    @State private var pageCount: Int = 0
    @State private var estimatedRecipes: Int = 0
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // PDF Preview
                    pdfPreviewSection

                    // Info Section
                    infoSection

                    // Image Generation Toggle
                    imageGenerationSection

                    // Cost Estimate
                    costEstimateSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.top, HeirloomSpacing.md)
            }
            .navigationTitle("Import PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onApprove(generateImages)
                    }
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
                }
            }
            .task {
                await loadPDFInfo()
            }
        }
    }

    // MARK: - PDF Preview

    private var pdfPreviewSection: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            if let document = pdfDocument, let page = document.page(at: 0) {
                PDFPageView(page: page)
                    .frame(height: 300)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            } else if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(HeirloomColors.warmGray.opacity(0.1))
                    .frame(height: 300)
                    .overlay {
                        ProgressView()
                    }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(HeirloomColors.warmGray.opacity(0.1))
                    .frame(height: 300)
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(HeirloomColors.warmGray)
                            Text("Preview unavailable")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            // File name
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundStyle(HeirloomColors.tomato)
                Text(pdfURL.lastPathComponent)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)
                Spacer()
            }

            // Page count
            if pageCount > 0 {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(HeirloomColors.secondaryText)
                    Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                    Spacer()
                }
            }

            // Estimated recipes (based on page count)
            if estimatedRecipes > 0 {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(HeirloomColors.familyGreen)
                    Text("~\(estimatedRecipes) recipe\(estimatedRecipes == 1 ? "" : "s") estimated")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                    Spacer()
                }
            }
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Image Generation Toggle

    private var imageGenerationSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Toggle(isOn: $generateImages) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate AI Images")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Create beautiful food photos for recipes without images")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .tint(HeirloomColors.familyGreen)

            if generateImages {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(HeirloomColors.familyGreen)
                    Text("Images will be generated after recipe extraction")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.familyGreen)
                }
                .padding(.leading, 4)
            }
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Cost Estimate

    private var costEstimateSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "creditcard")
                    .foregroundStyle(HeirloomColors.tomato)
                Text("Cost Estimate")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                Spacer()
            }

            // Base cost
            HStack {
                Text("PDF Analysis")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                Spacer()
                Text("\(baseCost) credits")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            // Image generation cost (if enabled)
            if generateImages && estimatedRecipes > 0 {
                HStack {
                    Text("AI Images (\(estimatedRecipes) recipes)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                    Spacer()
                    Text("~\(imageCost) credits")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
            }

            Divider()

            // Total
            HStack {
                Text("Estimated Total")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                Spacer()
                Text("~\(totalCost) credits")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.tomato)
            }

            Text("Actual cost may vary based on recipes found")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding()
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var baseCost: Int {
        // Rough estimate: 1 credit per page for analysis
        max(1, pageCount)
    }

    private var imageCost: Int {
        // Rough estimate: 2 credits per image generated
        estimatedRecipes * 2
    }

    private var totalCost: Int {
        baseCost + (generateImages ? imageCost : 0)
    }

    // MARK: - Data Loading

    private func loadPDFInfo() async {
        isLoading = true

        // Load PDF document
        if let document = PDFDocument(url: pdfURL) {
            await MainActor.run {
                pdfDocument = document
                pageCount = document.pageCount

                // Estimate recipes: roughly 1-2 recipes per page for cookbook PDFs
                // This is a rough estimate - actual count determined during extraction
                estimatedRecipes = max(1, pageCount)
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - PDF Page View

/// SwiftUI wrapper for PDFKit page rendering
struct PDFPageView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = page.document {
            pdfView.document = document
            pdfView.go(to: page)
        }
    }
}

// MARK: - Preview

#Preview {
    PDFApprovalSheet(
        pdfURL: URL(fileURLWithPath: "/example.pdf"),
        onApprove: { _ in },
        onCancel: {}
    )
}
