//
//  VideoProcessingBottomBanner.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-11.
//

import SwiftUI
import SwiftData

/// Persistent bottom banner showing active video processing job
struct VideoProcessingBottomBanner: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showJobList = false
    @State private var jobManager: VideoProcessingJobManager?

    var body: some View {
        if let manager = jobManager,
           let activeJob = manager.activeJob ?? manager.queuedJobs.first {
            bannerContent(for: activeJob, manager: manager)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeJob.id)
                .sheet(isPresented: $showJobList) {
                    VideoProcessingJobListView()
                }
        }
    }

    private func bannerContent(for job: VideoProcessingJob, manager: VideoProcessingJobManager) -> some View {
        Button {
            showJobList = true
        } label: {
            HStack(spacing: HeirloomSpacing.md) {
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: job.progress)
                        .stroke(HeirloomColors.tomato, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: job.progress)

                    if job.progress < 1.0 {
                        Image(systemName: "video.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(HeirloomColors.tomato)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(HeirloomColors.familyGreen)
                    }
                }

                // Job Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.statusText)
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if manager.isProcessing {
                        HStack(spacing: 6) {
                            Text("\(Int(job.progress * 100))%")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            if manager.queuedJobs.count > 1 {
                                Text("•")
                                    .foregroundStyle(HeirloomColors.secondaryText)
                                Text("\(manager.queuedJobs.count - 1) in queue")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.up")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .padding(HeirloomSpacing.md)
            .background(.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 12, y: -4)
            .padding(.horizontal, HeirloomSpacing.md)
            .padding(.bottom, HeirloomSpacing.sm)
        }
        .buttonStyle(.plain)
        .onAppear {
            initializeJobManager()
        }
    }

    private func initializeJobManager() {
        if jobManager == nil {
            jobManager = VideoProcessingJobManager()

            // Start auto-resume
            Task {
                await jobManager?.resumePendingJobs(context: modelContext)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: VideoProcessingJob.self, configurations: config)

    // Create a sample job
    let job = VideoProcessingJob(
        videoURL: "/tmp/video.mp4",
        videoType: .standard,
        userCaption: "Chocolate chip cookies"
    )
    job.status = .processing
    job.currentPhase = .transcribing
    job.progress = 0.45

    container.mainContext.insert(job)

    return ZStack {
        Color.gray.opacity(0.1).ignoresSafeArea()

        VStack {
            Spacer()
            VideoProcessingBottomBanner()
                .modelContainer(container)
        }
    }
}
