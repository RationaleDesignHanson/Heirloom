import SwiftUI
import SwiftData

/// Real-time progress display for bulk import with pause/resume
struct ImportProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: ImportJobManager
    let job: ImportJob

    @State private var showingCancelConfirmation = false
    @State private var mockProgress: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Phase Indicator
            phaseIndicatorView()

            // Progress Circle (using overallProgress for all phases)
            ZStack {
                // Background ring with subtle shadow
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.15), lineWidth: 14)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)

                // Progress ring with gradient
                Circle()
                    .trim(from: 0, to: displayProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                HeirloomColors.tomato,
                                HeirloomColors.tomato.opacity(0.8),
                                HeirloomColors.tomato
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: job.overallProgress)

                // Center content with better hierarchy
                VStack(spacing: 4) {
                    Text("\(Int(displayProgress * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(statusText)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 120)
                }
            }
            .frame(width: 180, height: 180)
            .padding(HeirloomSpacing.xl)

            // Phase-specific content
            phaseContentView()
                .frame(maxHeight: 250)

            // Error summary for failed jobs
            if job.status == .failed {
                errorSummaryView()
                    .padding(.horizontal, HeirloomSpacing.lg)
            }

            // Stats Bar
            HStack(spacing: 0) {
                // Success
                statColumnEnhanced(
                    icon: "checkmark.circle.fill",
                    color: HeirloomColors.success,
                    value: "\(job.successfulItems)",
                    label: "Success"
                )

                Divider()
                    .frame(height: 40)

                // Failed
                statColumnEnhanced(
                    icon: "xmark.circle.fill",
                    color: HeirloomColors.error,
                    value: "\(job.failedItems)",
                    label: "Failed"
                )

                Divider()
                    .frame(height: 40)

                // Remaining
                statColumnEnhanced(
                    icon: "clock.fill",
                    color: HeirloomColors.warmGray,
                    value: "\(job.totalItems - job.completedItems)",
                    label: "Remaining"
                )
            }
            .padding(.vertical, HeirloomSpacing.md)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .padding(.horizontal, HeirloomSpacing.lg)

            Spacer()

            // Action Buttons
            VStack(spacing: HeirloomSpacing.md) {
                if manager.isProcessing {
                    Button {
                        Task {
                            try? manager.pauseJob(job, context: modelContext)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                            Text("Pause")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.warmGray)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: HeirloomColors.warmGray.opacity(0.3), radius: 8, y: 4)
                    }
                } else if job.status == .paused {
                    Button {
                        Task {
                            try? await manager.resumeJob(job, context: modelContext)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 8, y: 4)
                    }
                }

                // Resume from checkpoint button (for interrupted jobs)
                if job.canResume && !manager.isProcessing {
                    Button {
                        Task {
                            try? await manager.resumeInterruptedJob(job, context: modelContext)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Resume from Checkpoint")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 8, y: 4)
                    }
                }

                if job.isComplete {
                    Button {
                        // Clear activeJob when user dismisses completed job
                        if manager.activeJob?.status == .completed {
                            manager.clearActiveJob()
                        }
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Done")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 8, y: 4)
                    }
                }

                Button("Cancel Import") {
                    showingCancelConfirmation = true
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.bottom, HeirloomSpacing.xl)
        }
        .navigationTitle("Importing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(manager.isProcessing)
        .confirmationDialog(
            "Cancel Import",
            isPresented: $showingCancelConfirmation
        ) {
            Button("Pause Import") {
                Task {
                    try? manager.pauseJob(job, context: modelContext)
                    dismiss()
                }
            }

            Button("Delete Job", role: .destructive) {
                Task {
                    try? manager.deleteJob(job, context: modelContext)
                    dismiss()
                }
            }
        } message: {
            Text("Pause to resume later, or delete to remove completely.")
        }
        .onAppear {
            startMockProgressTimer()
        }
        .onDisappear {
            stopMockProgressTimer()
        }
    }

    // MARK: - Computed Properties

    /// Display progress that uses mock progress when real progress is slow
    private var displayProgress: Double {
        // If real progress is moving (> 5%), use it
        if job.overallProgress > 0.05 {
            return job.overallProgress
        }
        // Otherwise use mock progress (capped at 85% until real completion)
        return min(mockProgress, 0.85)
    }

    // MARK: - Mock Progress Timer

    private func startMockProgressTimer() {
        // Start with small initial progress
        mockProgress = 0.05

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Only increment if real progress is still low
            if job.overallProgress < 0.05 && mockProgress < 0.85 {
                // Increment by 2-5% every 0.5s for visible movement
                mockProgress += Double.random(in: 0.02...0.05)
            } else if job.overallProgress >= 0.05 {
                // Real progress has started, stop mock progress
                stopMockProgressTimer()
            }
        }
    }

    private func stopMockProgressTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Status & Progress Text

    private var statusText: String {
        switch job.status {
        case .pending:
            return "Ready to Start"
        case .processing:
            return "Importing Recipes"
        case .paused:
            return "Paused"
        case .completed:
            return "Import Complete"
        case .failed:
            return "Import Failed"
        }
    }

    private var progressSubtitle: String {
        let totalPhases = job.shouldGenerateAIImages ? 4 : 3
        switch job.phase {
        case .validation:
            return "Phase 1 of \(totalPhases) • Validating files"
        case .analysis:
            return "Phase 2 of \(totalPhases) • Analyzing pages"
        case .extraction:
            return "Phase 3 of \(totalPhases) • \(job.completedItems)/\(job.totalItems) recipes"
        case .imageGeneration:
            let progress = Int(job.phaseProgress * 100)
            return "Phase 4 of 4 • Generating images (\(progress)%)"
        case .completed:
            return "All done!"
        }
    }

    // MARK: - Phase Indicator

    @ViewBuilder
    private func phaseIndicatorView() -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: job.phase.iconName)
                .font(HeirloomFonts.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(
                        colors: [HeirloomColors.tomato, HeirloomColors.tomato.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.phase.displayName)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
                Text(progressSubtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(.horizontal, HeirloomSpacing.lg)
        .padding(.vertical, HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Phase-Specific Content

    @ViewBuilder
    private func phaseContentView() -> some View {
        switch job.phase {
        case .validation:
            validationPhaseView()
        case .analysis:
            analysisPhaseView()
        case .extraction:
            extractionPhaseView()
        case .imageGeneration:
            imageGenerationPhaseView()
        case .completed:
            completionPhaseView()
        }
    }

    private func validationPhaseView() -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Text("Checking PDF files...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            if job.totalItems > 0 {
                Text("\(job.totalItems) file\(job.totalItems == 1 ? "" : "s")")
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.tomato)
            }
        }
        .padding(HeirloomSpacing.lg)
    }

    private func analysisPhaseView() -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Text("Detecting recipe boundaries and extracting images from PDF pages...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(HeirloomSpacing.lg)
    }

    private func extractionPhaseView() -> some View {
        Group {
            if let items = job.items, !items.isEmpty {
                ScrollView {
                    VStack(spacing: HeirloomSpacing.sm) {
                        ForEach(items) { item in
                            itemRow(item)
                        }
                    }
                    .padding(.horizontal, HeirloomSpacing.lg)
                }
            } else {
                // Fallback view for early extraction state
                VStack(spacing: HeirloomSpacing.md) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(HeirloomColors.tomato)

                    Text("Preparing recipes for extraction...")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)

                    if job.totalItems > 0 {
                        Text("Detected \(job.totalItems) recipe\(job.totalItems == 1 ? "" : "s")")
                            .font(HeirloomFonts.caption1Bold)
                            .foregroundStyle(HeirloomColors.tomato)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
        }
    }

    private func completionPhaseView() -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Import Complete!")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            if job.successfulItems > 0 {
                Text("Successfully imported \(job.successfulItems) recipe\(job.successfulItems == 1 ? "" : "s")")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(HeirloomSpacing.lg)
    }

    private func imageGenerationPhaseView() -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)

            Text("Generating AI Images")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Creating beautiful photos for your recipes using your visual style...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)

            // Progress indicator
            let completed = Int(job.phaseProgress * Double(job.successfulItems))
            Text("\(completed) of \(job.successfulItems) images")
                .font(HeirloomFonts.caption1Bold)
                .foregroundStyle(HeirloomColors.tomato)
        }
        .padding(HeirloomSpacing.lg)
    }

    // MARK: - Item Row

    private func itemRow(_ item: ImportItem) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            // Source icon
            sourceIcon(for: item.source)
                .foregroundStyle(sourceIconColor(for: item.source))
                .font(.system(size: 20))

            // Item description
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text(itemTitle(for: item))
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .lineLimit(1)

                if let pageInfo = pageInfo(for: item) {
                    Text(pageInfo)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            Spacer()

            // Status indicator
            statusIndicator(for: item.status)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(8)
    }

    private func sourceIcon(for source: ImportSource) -> Image {
        switch source {
        case .url:
            return Image(systemName: "link.circle.fill")
        case .pdf:
            return Image(systemName: "doc.fill")
        case .camera:
            return Image(systemName: "camera.fill")
        case .photoLibrary:
            return Image(systemName: "photo.fill")
        }
    }

    private func sourceIconColor(for source: ImportSource) -> Color {
        switch source {
        case .url:
            return .blue
        case .pdf:
            return .red
        case .camera:
            return .purple
        case .photoLibrary:
            return .orange
        }
    }

    private func itemTitle(for item: ImportItem) -> String {
        switch item.source {
        case .url:
            if let urlString = item.urlString {
                // Extract domain or show abbreviated URL
                if let url = URL(string: urlString),
                   let host = url.host {
                    return host
                }
                return urlString
            }
            return "Video Recipe"

        case .pdf:
            // Show cookbook title if available
            if let cookbookTitle = item.cookbookTitle {
                return cookbookTitle
            }

            // Fall back to page number display
            if let pageNumber = item.pageNumber {
                if let isMulti = item.isMultiPageRecipe, isMulti, let totalPages = item.totalPages {
                    return "Pages \(pageNumber)-\(pageNumber + totalPages - 1)"
                }
                return "Page \(pageNumber)"
            }
            return "PDF Recipe"

        case .camera:
            return "Camera Capture"

        case .photoLibrary:
            return "Photo Import"
        }
    }

    private func pageInfo(for item: ImportItem) -> String? {
        guard item.source == .pdf else { return nil }

        // If we have a cookbook title, show page number info
        if item.cookbookTitle != nil, let pageNumber = item.pageNumber {
            if let isMulti = item.isMultiPageRecipe, isMulti, let totalPages = item.totalPages {
                return "Pages \(pageNumber)-\(pageNumber + totalPages - 1)"
            } else {
                return "Page \(pageNumber)"
            }
        }

        // Otherwise show total pages info (legacy behavior)
        if let totalPages = item.totalPages, totalPages > 1 {
            if let isMulti = item.isMultiPageRecipe, isMulti {
                return "Multi-page recipe"
            } else {
                return "of \(totalPages) pages"
            }
        }

        return nil
    }

    private func statusIndicator(for status: ImportItemStatus) -> some View {
        Group {
            switch status {
            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.gray)

            case .processing:
                ProgressView()
                    .tint(HeirloomColors.tomato)

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)

            case .skipped:
                Image(systemName: "forward.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 20))
    }

    private func statColumn(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Text("\(value)")
                .font(HeirloomFonts.title2)
                .foregroundStyle(color)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func statColumnEnhanced(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(HeirloomColors.primaryText)

            Text(label)
                .font(.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func errorSummaryView() -> some View {
        if let items = job.items {
            let failedItems = items.filter { $0.status == .failed }

            if !failedItems.isEmpty {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text("Why did it fail?")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }

                    // Show first 3 error messages
                    ForEach(failedItems.prefix(3), id: \.id) { item in
                        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)

                            if let error = item.errorMessage {
                                Text(error)
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Recipe extraction failed")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                        }
                    }

                    if failedItems.count > 3 {
                        Text("+ \(failedItems.count - 3) more errors")
                            .font(HeirloomFonts.caption2)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .padding(.leading, 20)
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(Color.red.opacity(0.08))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ImportProgressView(
            manager: ServiceContainer.shared.resolve(ImportJobManager.self),
            job: {
                let job = ImportJob(jobName: "Test Import")
                job.totalItems = 10
                job.completedItems = 6
                job.successfulItems = 5
                job.failedItems = 1
                job.status = .processing
                return job
            }()
        )
    }
    .modelContainer(for: [ImportJob.self, ImportItem.self], inMemory: true)
}
