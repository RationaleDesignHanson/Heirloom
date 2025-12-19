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

            // Progress Circle
            ZStack {
                Circle()
                    .stroke(HeirloomColors.warmGray.opacity(0.2), lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: job.progress)
                    .stroke(HeirloomColors.tomato, lineWidth: 12)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.3), value: job.progress)

                VStack(spacing: HeirloomSpacing.xs) {
                    Text("\(Int(job.progress * 100))%")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("\(job.completedItems)/\(job.totalItems)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding(HeirloomSpacing.xl)

            // Status Text
            VStack(spacing: HeirloomSpacing.sm) {
                Text(statusText)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                if manager.isProcessing {
                    Text("Importing recipes...")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

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
                        .foregroundColor(.white)
                        .cornerRadius(12)
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
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                if job.isComplete {
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
                        .foregroundColor(.white)
                        .cornerRadius(12)
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
            manager: ImportJobManager.shared,
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
