import SwiftUI

struct DebugLogView: View {
    @State private var logContents: String = "Loading..."
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Button("Refresh") {
                    loadLog()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Clear") {
                    clearLog()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button("Share") {
                    showShareSheet = true
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // Log contents
            ScrollView {
                Text(logContents)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Debug Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadLog()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = DeviceLogger.shared.getLogFileURL() {
                ShareSheet(items: [url])
            }
        }
    }

    private func loadLog() {
        if let contents = DeviceLogger.shared.getLogContents() {
            logContents = contents.isEmpty ? "No logs yet. Launch the app and perform actions to generate logs." : contents
        } else {
            logContents = "Unable to load log file."
        }
    }

    private func clearLog() {
        DeviceLogger.shared.clearLog()
        loadLog()
    }
}

#Preview {
    NavigationStack {
        DebugLogView()
    }
}
