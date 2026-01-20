import SwiftUI
import SwiftData

/// Real-time progress display for bulk import with pause/resume
struct ImportProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: ImportJobManager
    let job: ImportJob

    @State private var showingCancelConfirmation = false

    var body: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            Spacer()

            // Phase Indicator
            phaseIndicatorView()

            // Progress Circle (using overallProgress for all phases)
            ZStack {
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: job.overallProgress)
                    .stroke(HeirloomColors.tomato, lineWidth: 12)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: job.overallProgress)

                VStack(spacing: HeirloomSpacing.xs) {
                    Text("\(Int(job.overallProgress * 100))%")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text(progressSubtitle)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(HeirloomSpacing.xl)

            // Phase-specific content
            phaseContentView()
                .frame(maxHeight: 250)

            // Stats
            HStack(spacing: HeirloomSpacing.xl) {
                statColumn("Success", job.successfulItems, .green)
                statColumn("Failed", job.failedItems, .red)
                statColumn("Remaining", job.totalItems - job.completedItems, HeirloomColors.secondaryText)
            }
            .padding(HeirloomSpacing.lg)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(12)
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
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.secondaryText)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(HeirloomSpacing.cardCornerRadius)
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
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(HeirloomSpacing.cardCornerRadius)
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
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(HeirloomSpacing.cardCornerRadius)
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
            Button("Cancel Import", role: .destructive) {
                Task {
                    try? manager.pauseJob(job, context: modelContext)
                    dismiss()
                }
            }
        } message: {
            Text("Stop importing recipes? Progress will be saved.")
        }
    }

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
        switch job.phase {
        case .validation:
            return "Phase 1 of 3 • Validating files"
        case .analysis:
            return "Phase 2 of 3 • Analyzing pages"
        case .extraction:
            return "Phase 3 of 3 • \(job.completedItems)/\(job.totalItems) recipes"
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
                .foregroundStyle(HeirloomColors.tomato)

            Text(job.phase.displayName)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .padding(.horizontal, HeirloomSpacing.lg)
        .padding(.vertical, HeirloomSpacing.sm)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(20)
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
