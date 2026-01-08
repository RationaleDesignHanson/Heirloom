//
//  VideoLabApp.swift
//  HeirloomVideoLab
//
//  Created by Claude on 1/8/26.
//
//  Main entry point for HeirloomVideoLab isolated development app

import SwiftUI
import SwiftData

@main
struct VideoLabApp: App {
    // SwiftData container (same schema as main app)
    let modelContainer: ModelContainer

    init() {
        do {
            // Use same models as main Heirloom app
            // For isolated testing, use in-memory or separate file
            let config = ModelConfiguration(
                // Uncomment for isolated testing:
                // isStoredInMemoryOnly: true
                // Or use separate file:
                schema: Schema([]), // Add Recipe, Ingredient models when linked
                url: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("VideoLabRecipes.store")
            )

            modelContainer = try ModelContainer(
                for: Schema([]), // Will populate when Recipe/Ingredient models linked
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var showVideoImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo/Icon
                Image(systemName: "video.badge.waveform")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange.gradient)

                // Title
                VStack(spacing: 8) {
                    Text("HeirloomVideoLab")
                        .font(.largeTitle.bold())

                    Text("Video Recipe Import Testing")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Week 1 - Mock Services")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }

                Spacer()

                // Import button
                Button {
                    showVideoImport = true
                } label: {
                    Label("Import Video Recipe", systemImage: "video.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)

                // Info
                VStack(spacing: 8) {
                    Text("This app uses mock services to simulate video processing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text("Processing time: ~10 seconds")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("VideoLab")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVideoImport) {
                VideoImportView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
