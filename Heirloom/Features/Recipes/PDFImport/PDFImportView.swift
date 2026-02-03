import SwiftUI
import SwiftData

/// Main view for importing recipes from PDF files
/// Supports multi-file selection, validation, and queue-based processing
///
/// # Complete Import Flow
///
/// ```
/// ┌─────────────────────────────────────────────────────────────┐
/// │                   PDF Import User Flow                       │
/// └─────────────────────────────────────────────────────────────┘
///
///  User taps "Import PDFs" from scanner
///         │
///         ▼
///  PDFImportView appears
///         │
///         │ (1) User taps "Select PDF Files"
///         ▼
///  PDFDocumentPicker sheet
///         │
///         │ (2) User selects 1-20 PDFs from Files app
///         ▼
///  selectedPDFs updated
///         │
///         │ (3) Automatic validation triggered (onChange)
///         ├───► PDFProcessor.validatePDF() for each file
///         │          │
///         │          ├─ Check page count
///         │          ├─ Check password protection
///         │          ├─ Check premium requirement (50+ pages)
///         │          └─ Check hard cap (250 pages)
///         │
///         ▼
///  validationResults populated
///         │
///         │ UI shows real-time status:
///         ├─ ✓ Green: Valid (< 50 pages or premium user)
///         ├─ ⚠️ Orange: Premium required (50+ pages, free user)
///         └─ ✗ Red: Error (password, too large, corrupted)
///         │
///         │ (4) User taps "Import Recipes" button
///         ▼
///  processPDFs() async
///         │
///         │ For each PDF:
///         ├───► Check validation result
///         │     │
///         │     ├─ requiresPremium? → Show paywall, STOP
///         │     ├─ failure? → Skip this PDF
///         │     └─ success? → Continue
///         │
///         ├───► PDFProcessor.renderPDFPages()
///         │     └─ Returns [(1, image), (2, image), ...]
///         │
///         ├───► ImportJobManager.createPDFImportJob()
///         │     ├─ MultiPageRecipeAnalyzer.analyzePageBoundaries()
///         │     │  └─ Claude Vision API per page
///         │     ├─ Groups multi-page recipes
///         │     └─ Creates ImportJob with grouped items
///         │
///         ├───► ImportJobManager.startJob()
///         │     └─ Queue processing begins
///         │
///         └───► Show ImportProgressView
///                    │
///                    │ Real-time progress per recipe
///                    │ User can dismiss and check import history
///                    ▼
///               Recipes extracted and saved
/// ```
///
/// # UI States
///
/// 1. **Initial**: Empty state with "Select PDF Files" button
/// 2. **Selected + Validating**: Shows selected PDFs with spinner indicators
/// 3. **Validated**: Shows validation status (green/orange/red) per PDF
/// 4. **Processing**: "Import Recipes" button shows spinner
/// 5. **Progress View**: Modal sheet with ImportProgressView
///
/// # Validation Display
///
/// Each selected PDF shows:
/// - **Filename**: Truncated with lineLimit(1)
/// - **Page count**: "42 pages" (green if valid)
/// - **Premium indicator**: "75 pages • Premium required" (orange)
/// - **Error message**: "Password protected" (red)
/// - **Icon**: ✓ / ⚠️ / ✗ based on validation result
///
/// # Premium Gate UX
///
/// When user attempts to import 50+ page PDF without premium:
/// 1. Validation shows orange warning indicator
/// 2. On "Import Recipes" tap → Paywall presented
/// 3. User upgrades → Can retry import
/// 4. User cancels → Returns to validation view
///
/// # Error Handling
///
/// - **Too many files** (21+): Alert shown immediately (from PDFDocumentPicker)
/// - **Validation errors**: Shown inline per PDF (red status)
/// - **Processing errors**: Alert shown after import attempt
/// - **Mixed results**: Valid PDFs process, invalid ones skipped
///
/// # Usage Example (Integration)
///
/// ```swift
/// // From EnhancedScannerView or CookbookScannerView:
/// struct EnhancedScannerView: View {
///     @State private var showPDFImport = false
///
///     var body: some View {
///         // ... camera view ...
///
///         .toolbar {
///             ToolbarItem(placement: .primaryAction) {
///                 Button {
///                     showPDFImport = true
///                 } label: {
///                     Image(systemName: "doc.fill")
///                 }
///             }
///         }
///         .sheet(isPresented: $showPDFImport) {
///             PDFImportView()
///         }
///     }
/// }
/// ```
struct PDFImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.firebaseAuth) private var firebaseAuth

    @StateObject private var importManager = ServiceContainer.shared.resolve(ImportJobManager.self)

    private var pdfProcessor: PDFProcessor { ServiceContainer.shared.resolve(PDFProcessor.self) }
    private var subscriptionManager: SubscriptionManager { ServiceContainer.shared.resolve(SubscriptionManager.self) }
    private var paywallManager: PaywallManager { ServiceContainer.shared.resolve(PaywallManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    @State private var selectedPDFs: [URL] = []
    @State private var showDocumentPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var validationResults: [URL: PDFValidationResult] = [:]
    @State private var showAuthRequiredAlert = false
    @State private var showSignIn = false
    @State private var showCookbookNamePrompt = false
    @State private var cookbookNameInput = ""
    @State private var pendingValidPDFs: [URL] = []

    // Credits system state
    @State private var showCostSheet = false
    @State private var costBreakdown: PDFCostCalculator.CostBreakdown?
    @State private var userCredits: UserCredits?
    @State private var showCreditsStore = false
    @State private var isCalculatingCost = false

    // SwiftData query for user credits
    @Query private var allUserCredits: [UserCredits]

    /// Optional callback to dismiss parent view (e.g., CookbookScannerView)
    /// Called after job creation to allow parent to dismiss itself
    var onJobCreated: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.xl) {
                    // Header
                    headerSection

                    // Selection Button
                    selectPDFsButton

                    // Selected PDFs List
                    if !selectedPDFs.isEmpty {
                        selectedPDFsList
                        importButton
                    }

                    // Info Cards
                    infoCardsSection

                    Spacer(minLength: HeirloomSpacing.xl)
                }
                .padding(HeirloomSpacing.lg)
            }
            .navigationTitle("Import PDFs")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showDocumentPicker) {
                PDFDocumentPicker(selectedPDFs: $selectedPDFs)
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
            .alert("Sign In Required", isPresented: $showAuthRequiredAlert) {
                Button("Sign In") {
                    showSignIn = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Sign in to import PDF recipes and keep them backed up safely.")
            }
            .sheet(isPresented: $showSignIn) {
                FirebaseSignInView()
            }
            .alert("Cookbook Name", isPresented: $showCookbookNamePrompt) {
                TextField("Enter cookbook name", text: $cookbookNameInput)
                Button("Continue") {
                    Task {
                        await continueImportWithCookbookName(cookbookNameInput)
                    }
                }
                Button("Cancel", role: .cancel) {
                    isProcessing = false
                    pendingValidPDFs = []
                    cookbookNameInput = ""
                }
            } message: {
                Text("What's the name of this cookbook? This will help organize your recipes.")
            }
            .onChange(of: selectedPDFs) { _, newValue in
                if !newValue.isEmpty {
                    Task {
                        await validateSelectedPDFs()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .pdfImportError)) { notification in
                if let error = notification.userInfo?["error"] as? PDFImportError {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showCostSheet) {
                costSheetContent
            }
            .sheet(isPresented: $showCreditsStore, onDismiss: {
                // Recalculate cost after credits store closes (user may have purchased)
                Task {
                    await calculateCostAndShowSheet()
                }
            }) {
                creditsStoreContent
            }
            .onAppear {
                initializeUserCredits()
            }
        }
    }

    // MARK: - Cost Sheet Content

    @ViewBuilder
    private var costSheetContent: some View {
        if let breakdown = costBreakdown, let credits = userCredits {
            CreditsCostSheet(
                costBreakdown: breakdown,
                userCredits: credits,
                onConfirm: {
                    showCostSheet = false
                    Task {
                        await proceedWithImport()
                    }
                },
                onBuyCredits: {
                    showCostSheet = false
                    showCreditsStore = true
                },
                onQueueForTomorrow: {
                    showCostSheet = false
                    Task {
                        await queueForTomorrow()
                    }
                }
            )
        }
    }

    // MARK: - Credits Store Content

    @ViewBuilder
    private var creditsStoreContent: some View {
        if let userId = firebaseAuth.currentUserId {
            let storeManager = CreditStoreManager(
                logger: ServiceContainer.shared.resolve(LoggingService.self),
                analytics: analytics,
                modelContext: modelContext,
                userId: userId
            )
            CreditsStoreView(storeManager: storeManager)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "doc.fill")
                .font(.system(size: 60))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Import PDF Recipes")
                .font(HeirloomFonts.title2)
                .fontWeight(.bold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Select up to 20 PDF files from cookbook scans or recipe collections. We'll automatically detect recipes and handle multi-page recipes.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Select PDFs Button

    private var selectPDFsButton: some View {
        Button {
            showDocumentPicker = true
        } label: {
            HStack {
                Image(systemName: "folder")
                Text("Select PDF Files")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(HeirloomColors.tomato)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .cornerRadius(12)
        }
    }

    // MARK: - Selected PDFs List

    private var selectedPDFsList: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("\(selectedPDFs.count) PDF\(selectedPDFs.count == 1 ? "" : "s") selected")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(spacing: HeirloomSpacing.sm) {
                ForEach(selectedPDFs, id: \.self) { url in
                    pdfRow(url)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    private func pdfRow(_ url: URL) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "doc.fill")
                .foregroundStyle(validationIconColor(for: url))
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(url.lastPathComponent)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                if let result = validationResults[url] {
                    validationStatusText(for: result)
                }
            }

            Spacer()

            if let result = validationResults[url] {
                validationIcon(for: result)
            } else {
                ProgressView()
                    .tint(HeirloomColors.tomato)
            }
        }
        .padding(HeirloomSpacing.md)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func validationIconColor(for url: URL) -> Color {
        guard let result = validationResults[url] else {
            return .gray
        }

        switch result {
        case .success:
            return .green
        case .requiresPremium:
            return .orange
        case .failure:
            return .red
        }
    }

    private func validationIcon(for result: PDFValidationResult) -> some View {
        Group {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

            case .requiresPremium:
                Image(systemName: "crown.fill")
                    .foregroundStyle(.orange)

            case .failure:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 20))
    }

    private func validationStatusText(for result: PDFValidationResult) -> some View {
        Group {
            switch result {
            case .success(let pageCount):
                Text("\(pageCount) page\(pageCount == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.green)

            case .requiresPremium(_, let pageCount):
                Text("\(pageCount) pages • Premium required")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.orange)

            case .failure(let error):
                Text(error.localizedDescription)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button {
            Task {
                await processPDFs()
            }
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                if isProcessing {
                    ProgressView()
                        .tint(HeirloomColors.buttonTextLight)
                    Text("Starting import...")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "arrow.down.doc")
                    Text("Import Recipes")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canImport ? HeirloomColors.tomato : Color.gray)
            .foregroundStyle(HeirloomColors.buttonTextLight)
            .cornerRadius(12)
        }
        .disabled(!canImport || isProcessing)
    }

    private var canImport: Bool {
        !selectedPDFs.isEmpty &&
        !isProcessing &&
        validationResults.values.allSatisfy { result in
            if case .failure = result {
                return false
            }
            return true
        }
    }

    // MARK: - Info Cards

    private var infoCardsSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            InfoCard(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                title: "Supported PDFs",
                description: "Scanned cookbooks, recipe cards, or any PDF with recipe text and images"
            )

            InfoCard(
                icon: "sparkles",
                iconColor: .purple,
                title: "Smart Multi-Page Detection",
                description: "Automatically detects recipes spanning multiple pages and groups them together"
            )

            InfoCard(
                icon: "crown.fill",
                iconColor: .orange,
                title: "Premium for Large PDFs",
                description: "PDFs with 50+ pages require premium subscription. Hard limit of 250 pages per PDF."
            )

            InfoCard(
                icon: "lock.shield.fill",
                iconColor: .blue,
                title: "Maximum 20 PDFs",
                description: "Select up to 20 PDF files per import session for optimal processing"
            )
        }
    }

    // MARK: - Processing

    private func validateSelectedPDFs() async {
        for url in selectedPDFs {
            let result = await pdfProcessor.validatePDF(url)
            await MainActor.run {
                validationResults[url] = result
            }
        }
    }

    private func processPDFs() async {
        // Check authentication before processing
        guard firebaseAuth.isAuthenticated else {
            await MainActor.run {
                showAuthRequiredAlert = true
            }
            return
        }

        // Check for premium requirement first
        for pdfURL in selectedPDFs {
            guard let result = validationResults[pdfURL] else { continue }

            if case .requiresPremium(let fileName, let pageCount) = result {
                await MainActor.run {
                    analytics.track(event: AnalyticsEvent.largePDFPaywallShown, properties: [
                        "file_name": fileName,
                        "page_count": pageCount
                    ])
                    paywallManager.show(for: .largePDFImport(pageCount: pageCount))
                }
                return
            }
        }

        // Filter to only valid PDFs
        let validPDFs = selectedPDFs.filter { pdfURL in
            if let result = validationResults[pdfURL], case .success = result {
                return true
            }
            return false
        }

        guard !validPDFs.isEmpty else {
            Log.warning("No valid PDFs to import", category: .import)
            return
        }

        // Store valid PDFs for later use
        pendingValidPDFs = validPDFs

        // Calculate cost and show cost sheet
        await calculateCostAndShowSheet()
    }

    /// Calculate credit cost and show the cost sheet
    private func calculateCostAndShowSheet() async {
        guard let credits = userCredits else {
            Log.warning("No user credits found", category: .import)
            // Fall back to direct import if credits not available
            await proceedWithImport()
            return
        }

        isCalculatingCost = true

        let costCalculator = PDFCostCalculator()

        do {
            let breakdown = try await costCalculator.calculateCost(
                for: pendingValidPDFs,
                userCredits: credits
            )

            await MainActor.run {
                isCalculatingCost = false
                costBreakdown = breakdown
                showCostSheet = true
            }
        } catch {
            Log.error("Failed to calculate PDF cost", category: .import, error: error)
            await MainActor.run {
                isCalculatingCost = false
                errorMessage = "Failed to analyze PDFs: \(error.localizedDescription)"
            }
        }
    }

    /// Proceed with import after cost confirmation
    private func proceedWithImport() async {
        guard !pendingValidPDFs.isEmpty else { return }

        isProcessing = true

        let validPDFs = pendingValidPDFs

        // Track analytics
        let totalPages = validationResults.values.compactMap { $0.pageCount }.reduce(0, +)
        analytics.track(event: AnalyticsEvent.pdfImportStarted, properties: [
            "pdf_count": validPDFs.count,
            "total_pages": totalPages,
            "credits_cost": costBreakdown?.totalCredits ?? 0
        ])

        // Check if we need to prompt for cookbook name
        let metadataExtractor = PDFMetadataExtractor()
        let firstPDFMetadata = await metadataExtractor.extractMetadata(from: validPDFs[0])

        let cookbookName: String?
        if let extractedTitle = firstPDFMetadata?.title, !extractedTitle.isEmpty {
            cookbookName = extractedTitle
        } else if validPDFs.count == 1 {
            // Single PDF with no title - prompt user
            await MainActor.run {
                cookbookNameInput = ""
                showCookbookNamePrompt = true
            }
            return
        } else {
            cookbookName = nil
        }

        await startImportJob(validPDFs: validPDFs, cookbookName: cookbookName)
    }

    /// Queue PDFs for tomorrow when quota is available
    private func queueForTomorrow() async {
        guard !pendingValidPDFs.isEmpty else { return }

        // TODO: Implement QueuedPDFImport saving and notification scheduling
        // For now, show a message that this feature is coming

        await MainActor.run {
            toastManager.success(
                title: "Queued for tomorrow",
                message: "Your quota resets at midnight. We'll remind you to import then."
            )
            pendingValidPDFs = []
            dismiss()
        }
    }

    /// Start the actual import job
    private func startImportJob(validPDFs: [URL], cookbookName: String?) async {
        let jobName = validPDFs.count == 1
            ? "Import \(validPDFs[0].lastPathComponent)"
            : "Import \(validPDFs.count) PDFs"

        // Dismiss immediately and show toast
        await MainActor.run {
            let title = validPDFs.count == 1
                ? "Import started"
                : "Importing \(validPDFs.count) PDFs"

            toastManager.success(
                title: title,
                message: "Processing will continue in the background"
            )

            onJobCreated?()
            dismiss()
        }

        // Start analysis and extraction in background
        Task {
            do {
                let job = try await importManager.createAndAnalyzePDFJob(
                    pdfURLs: validPDFs,
                    jobName: jobName,
                    cookbookName: cookbookName,
                    collectionType: .cookbook,
                    context: modelContext,
                    costBreakdown: costBreakdown  // Pass cost breakdown for credit deduction
                )

                try await importManager.startJob(job, context: modelContext)

                let totalPages = validationResults.values.compactMap { $0.pageCount }.reduce(0, +)
                await MainActor.run {
                    analytics.track(event: AnalyticsEvent.pdfImportCompleted, properties: [
                        "pdf_count": validPDFs.count,
                        "total_pages": totalPages,
                        "recipe_count": job.totalItems
                    ])
                }
            } catch {
                Log.error("PDF import job failed", category: .import, error: error)
            }
        }

        pendingValidPDFs = []
    }

    /// Initialize or fetch user credits
    private func initializeUserCredits() {
        guard let userId = firebaseAuth.currentUserId else { return }

        // Check if we already have credits for this user
        if let existing = allUserCredits.first(where: { $0.userId == userId }) {
            userCredits = existing
        } else {
            // Create new UserCredits
            let newCredits = UserCredits(userId: userId)
            modelContext.insert(newCredits)
            userCredits = newCredits
        }
    }

    private func continueImportWithCookbookName(_ cookbookName: String) async {
        guard !pendingValidPDFs.isEmpty else { return }

        await startImportJob(
            validPDFs: pendingValidPDFs,
            cookbookName: cookbookName.isEmpty ? nil : cookbookName
        )
    }
}

// MARK: - Info Card Component

struct InfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 24))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(title)
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PDFImportView()
    }
    .modelContainer(for: [ImportJob.self, ImportItem.self], inMemory: true)
}
