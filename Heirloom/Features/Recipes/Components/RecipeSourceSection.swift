import SwiftUI

struct RecipeSourceSection: View {
    let provenanceMetadata: ProvenanceMetadata?
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Source")
                    .font(.headline)
                Spacer()
                if provenanceMetadata?.sourceAttribution != nil {
                    Button("Edit") {
                        showingEditor = true
                    }
                    .font(.caption)
                }
            }

            if let metadata = provenanceMetadata,
               let attribution = metadata.sourceAttribution {
                attributionView(metadata: metadata, attribution: attribution)
            } else {
                noAttributionView
            }
        }
        .sheet(isPresented: $showingEditor) {
            // TODO: AttributionEditorView
            Text("Attribution Editor (coming soon)")
        }
    }

    private func attributionView(metadata: ProvenanceMetadata, attribution: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Attempt to detect platform from source attribution or URL
                let platform = detectPlatform(from: metadata)
                CreatorAttributionBadge(
                    platform: platform,
                    attribution: attribution,
                    size: .large
                )

                Spacer()

                if let sourceURL = metadata.sourceURL,
                   let url = URL(string: sourceURL) {
                    Link(destination: url) {
                        Label("View Original", systemImage: "arrow.up.right")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var noAttributionView: some View {
        Button {
            showingEditor = true
        } label: {
            HStack {
                Image(systemName: "person.crop.circle.badge.plus")
                Text("Add source credit")
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func detectPlatform(from metadata: ProvenanceMetadata) -> SocialPlatform {
        // Try to detect platform from URL
        if let urlString = metadata.sourceURL,
           let url = URL(string: urlString),
           let platformInfo = PlatformDetector.detect(from: url) {
            return platformInfo.platform
        }

        // Default to unknown
        return .unknown
    }
}
