import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
/// Allows users to select PDF files from iOS Files app with multi-selection support
///
/// # UIViewControllerRepresentable Pattern
///
/// This struct bridges UIKit's `UIDocumentPickerViewController` to SwiftUI:
/// 1. **makeUIViewController**: Creates the UIKit picker once
/// 2. **updateUIViewController**: Updates picker when SwiftUI state changes
/// 3. **makeCoordinator**: Creates delegate to handle picker callbacks
/// 4. **Coordinator**: Implements `UIDocumentPickerDelegate` to receive results
///
/// # Features
///
/// - Multi-selection (up to 20 PDFs)
/// - Filtered to PDF content type only
/// - Security-scoped URL access (asCopy: true)
/// - Automatic validation and error handling
/// - Integration with NotificationCenter for error display
///
/// # Usage Example
///
/// ```swift
/// struct PDFImportView: View {
///     @State private var selectedPDFs: [URL] = []
///     @State private var showPicker = false
///
///     var body: some View {
///         Button("Select PDFs") {
///             showPicker = true
///         }
///         .sheet(isPresented: $showPicker) {
///             PDFDocumentPicker(selectedPDFs: $selectedPDFs, maxSelection: 20)
///         }
///         .onChange(of: selectedPDFs) { _, newValue in
///             // Process selected PDFs
///             for url in newValue {
///                 processPDF(url)
///             }
///         }
///     }
/// }
/// ```
///
/// # Security-Scoped Resources
///
/// PDFs from the document picker come as security-scoped URLs. When processing:
/// ```swift
/// guard url.startAccessingSecurityScopedResource() else { return }
/// defer { url.stopAccessingSecurityScopedResource() }
///
/// // Access PDF file here
/// let document = PDFDocument(url: url)
/// ```
///
/// # Error Handling
///
/// Errors are posted to `NotificationCenter.default` with name `.pdfImportError`:
/// ```swift
/// .onReceive(NotificationCenter.default.publisher(for: .pdfImportError)) { notification in
///     if let error = notification.userInfo?["error"] as? PDFImportError {
///         // Show error alert
///     }
/// }
/// ```
struct PDFDocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedPDFs: [URL]
    @Environment(\.dismiss) private var dismiss
    let maxSelection: Int

    init(selectedPDFs: Binding<[URL]>, maxSelection: Int = 20) {
        self._selectedPDFs = selectedPDFs
        self.maxSelection = maxSelection
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf],
            asCopy: true  // Copy to app sandbox for processing
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: PDFDocumentPicker

        init(_ parent: PDFDocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Validate max selection limit
            if urls.count > parent.maxSelection {
                Log.warning("PDF selection exceeds maximum", category: .import, metadata: [
                    "selected": urls.count,
                    "max": parent.maxSelection
                ])

                // Notify user via NotificationCenter (UI will handle display)
                NotificationCenter.default.post(
                    name: .pdfImportError,
                    object: nil,
                    userInfo: [
                        "error": PDFImportError.tooManyFiles(selected: urls.count, max: parent.maxSelection)
                    ]
                )

                parent.dismiss()
                return
            }

            // Clean and normalize URLs to handle problematic filenames
            let cleanedURLs = urls.compactMap { url -> URL? in
                return cleanPDFURL(url)
            }

            // Set selected PDFs
            parent.selectedPDFs = cleanedURLs

            Log.info("PDFs selected for import", category: .import, metadata: [
                "count": cleanedURLs.count,
                "files": cleanedURLs.map { $0.lastPathComponent }.joined(separator: ", ")
            ])

            parent.dismiss()
        }

        /// Clean and normalize PDF URL to handle problematic filenames
        /// Handles URL encoding issues, special characters, and copies to a clean filename if needed
        private func cleanPDFURL(_ url: URL) -> URL? {
            // With asCopy: true, files are already copied to app's temporary directory
            // and don't need security-scoped resource access

            // Verify file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                Log.warning("PDF file does not exist", category: .import, metadata: [
                    "file": url.lastPathComponent,
                    "path": url.path
                ])
                return nil
            }

            // Get original filename and decode URL encoding
            let originalFilename = url.lastPathComponent
            let decodedFilename = originalFilename
                .removingPercentEncoding ?? originalFilename
                .replacingOccurrences(of: "+", with: " ")  // Handle plus signs
                .replacingOccurrences(of: "\\'", with: "'")  // Handle escaped apostrophes
                .replacingOccurrences(of: "\\", with: "")     // Remove backslashes

            // If filename is already clean, return original URL
            if originalFilename == decodedFilename {
                return url
            }

            Log.info("Cleaning PDF filename", category: .import, metadata: [
                "original": originalFilename,
                "cleaned": decodedFilename
            ])

            // Create temporary directory for cleaned file
            let tempDir = FileManager.default.temporaryDirectory
            let cleanedURL = tempDir.appendingPathComponent(decodedFilename)

            // Copy file to cleaned filename
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: cleanedURL.path) {
                    try FileManager.default.removeItem(at: cleanedURL)
                }

                // Copy to cleaned filename
                try FileManager.default.copyItem(at: url, to: cleanedURL)

                Log.info("PDF filename cleaned successfully", category: .import, metadata: [
                    "original": originalFilename,
                    "cleaned": decodedFilename
                ])

                return cleanedURL
            } catch {
                Log.error("Failed to clean PDF filename", category: .import, error: error, metadata: [
                    "original": originalFilename,
                    "cleaned": decodedFilename
                ])
                // Return original URL as fallback
                return url
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Log.info("PDF selection cancelled", category: .import)
            parent.dismiss()
        }
    }
}

// MARK: - Errors

enum PDFImportError: LocalizedError {
    case tooManyFiles(selected: Int, max: Int)
    case unreadable(fileName: String)
    case passwordProtected(fileName: String)
    case tooManyPages(fileName: String, pageCount: Int, max: Int)
    case corruptedFile(fileName: String)
    case requiresPremium(fileName: String, pageCount: Int)

    var errorDescription: String? {
        switch self {
        case .tooManyFiles(let selected, let max):
            return "You can import up to \(max) PDFs at a time. Please select fewer files. (Selected: \(selected))"
        case .unreadable(let fileName):
            return "Could not read '\(fileName)'. The file may be corrupted or in an unsupported format."
        case .passwordProtected(let fileName):
            return "'\(fileName)' is password-protected. Please unlock the PDF and try again."
        case .tooManyPages(let fileName, let pageCount, let max):
            return "'\(fileName)' has \(pageCount) pages. Maximum is \(max) pages per PDF."
        case .corruptedFile(let fileName):
            return "'\(fileName)' appears to be corrupted and cannot be opened."
        case .requiresPremium(let fileName, let pageCount):
            return "'\(fileName)' has \(pageCount) pages. PDFs with 50+ pages require a premium subscription."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pdfImportError = Notification.Name("pdfImportError")
}
