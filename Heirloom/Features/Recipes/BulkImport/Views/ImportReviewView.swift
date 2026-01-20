import SwiftUI
import SwiftData

/// Post-import review showing successes, failures, and retry options
struct ImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var manager: ImportJobManager
    let job: ImportJob

    @State private var selectedTab: ReviewTab = .success
    @State private var showingRetryConfirmation = false

    private var successfulItems: [ImportItem] {
        job.items?.filter { $0.status == .success } ?? []
    }

    private var failedItems: [ImportItem] {
        job.items?.filter { $0.status == .failed } ?? []
    }

    private var skippedItems: [ImportItem] {
        job.items?.filter { $0.status == .skipped } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Summary
            VStack(spacing: HeirloomSpacing.md) {
                Image(systemName: job.failedItems == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(job.failedItems == 0 ? .green : .orange)

                Text("Import Complete")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                HStack(spacing: HeirloomSpacing.lg) {
                    summaryBadge("Success", job.successfulItems, .green)
                    if job.failedItems > 0 {
                        summaryBadge("Failed", job.failedItems, .red)
                    }
                    if job.items?.contains(where: { $0.status == .skipped }) == true {
                        summaryBadge("Skipped", skippedItems.count, .orange)
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
            .background(HeirloomColors.cardBackground)

            Divider()

            // Tab Selector
            Picker("Review Type", selection: $selectedTab) {
                Text("Success (\(job.successfulItems))").tag(ReviewTab.success)
                if job.failedItems > 0 {
                    Text("Failed (\(job.failedItems))").tag(ReviewTab.failed)
                }
                if !skippedItems.isEmpty {
                    Text("Skipped (\(skippedItems.count))").tag(ReviewTab.skipped)
                }
            }
            .pickerStyle(.segmented)
            .padding(HeirloomSpacing.md)

            // Content
            Group {
                switch selectedTab {
                case .success:
                    successListView
                case .failed:
                    failedListView
                case .skipped:
                    skippedListView
                }
            }

            // Bottom Actions
            VStack(spacing: HeirloomSpacing.md) {
                if job.failedItems > 0 {
                    Button {
                        showingRetryConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Retry Failed Imports")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.secondaryText)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .cornerRadius(12)
                    }
                }

                Button {
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
                    .cornerRadius(12)
                }
            }
            .padding(HeirloomSpacing.lg)
            .background(HeirloomColors.cardBackground)
        }
        .navigationTitle("Import Results")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .confirmationDialog(
            "Retry Failed Imports",
            isPresented: $showingRetryConfirmation
        ) {
            Button("Retry \(job.failedItems) Items") {
                Task {
                    try? await manager.retryFailedItems(job, context: modelContext)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Retry importing the \(job.failedItems) failed recipes?")
        }
    }

    // MARK: - Success List

    private var successListView: some View {
        Group {
            if successfulItems.isEmpty {
                emptyStateView(
                    icon: "checkmark.circle",
                    title: "No Successful Imports",
                    subtitle: "No recipes were successfully imported"
                )
            } else {
                List(successfulItems) { item in
                    if let recipeID = item.recipeID,
                       let recipe = try? modelContext.fetch(FetchDescriptor<Recipe>(
                           predicate: #Predicate { $0.id == recipeID }
                       )).first {
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            SuccessRowView(item: item)
                        }
                    } else {
                        SuccessRowView(item: item)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Failed List

    private var failedListView: some View {
        Group {
            if failedItems.isEmpty {
                emptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "No Failures",
                    subtitle: "All imports completed successfully"
                )
            } else {
                List(failedItems) { item in
                    FailedRowView(item: item)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Skipped List

    private var skippedListView: some View {
        Group {
            if skippedItems.isEmpty {
                emptyStateView(
                    icon: "checkmark.circle.fill",
                    title: "No Skipped Items",
                    subtitle: "All items were processed"
                )
            } else {
                List(skippedItems) { item in
                    SkippedRowView(item: item)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Components

    private func summaryBadge(_ label: String, _ count: Int, _ color: Color) -> some View {
        VStack(spacing: HeirloomSpacing.xs) {
            Text("\(count)")
                .font(HeirloomFonts.title2)
                .foregroundStyle(color)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private func emptyStateView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(HeirloomColors.secondaryText)

            Text(title)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(subtitle)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HeirloomSpacing.xl)
    }
}

// MARK: - Review Tab

enum ReviewTab {
    case success
    case failed
    case skipped
}

// MARK: - Success Row

struct SuccessRowView: View {
    let item: ImportItem

    var body: some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(HeirloomFonts.title2)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                if let urlString = item.urlString, let domain = URLNormalizer.extractDomain(urlString) {
                    Text(domain)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Text(item.displayURL)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)

                // Phase 3: AI Suggestions Preview
                if let collections = item.suggestedCollections, !collections.isEmpty {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(HeirloomFonts.caption2)
                        Text(collections.joined(separator: ", "))
                            .font(HeirloomFonts.caption2)
                    }
                    .foregroundStyle(HeirloomColors.tomato.opacity(0.8))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(.vertical, HeirloomSpacing.xs)
    }
}

// MARK: - Failed Row

struct FailedRowView: View {
    let item: ImportItem

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .font(HeirloomFonts.title2)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                if let urlString = item.urlString, let domain = URLNormalizer.extractDomain(urlString) {
                    Text(domain)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Text(item.displayURL)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)

                if let error = item.errorMessage {
                    Text(error)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.red)
                }

                if item.retryCount > 0 {
                    Text("Retried \(item.retryCount) time(s)")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .padding(.vertical, HeirloomSpacing.xs)
    }
}

// MARK: - Skipped Row

struct SkippedRowView: View {
    let item: ImportItem

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.orange)
                .font(HeirloomFonts.title2)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                if let urlString = item.urlString, let domain = URLNormalizer.extractDomain(urlString) {
                    Text(domain)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Text(item.displayURL)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .lineLimit(1)

                if let reason = item.errorMessage {
                    Text(reason)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, HeirloomSpacing.xs)
    }
}

// MARK: - Import Item Extension

extension ImportItem {
    var displayURL: String {
        guard let urlString = urlString else { return "" }
        return urlString.count > 60 ? String(urlString.prefix(57)) + "..." : urlString
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ImportReviewView(
            manager: ServiceContainer.shared.resolve(ImportJobManager.self),
            job: {
                let job = ImportJob(jobName: "Test Import")
                job.totalItems = 10
                job.completedItems = 10
                job.successfulItems = 7
                job.failedItems = 2
                job.status = .completed

                let items = [
                    ImportItem(urlString: "https://cooking.nytimes.com/recipes/1024647-chocolate-chip-cookies"),
                    ImportItem(urlString: "https://www.allrecipes.com/recipe/25037/best-chocolate-chip-cookies/"),
                    ImportItem(urlString: "https://www.bonappetit.com/recipe/bas-best-chocolate-chip-cookies"),
                ]

                items[0].markSuccess(recipeID: UUID())
                items[1].markSuccess(recipeID: UUID())
                items[2].markFailed(error: "Recipe not found")

                job.items = items
                return job
            }()
        )
    }
    .modelContainer(for: [ImportJob.self, ImportItem.self], inMemory: true)
}
