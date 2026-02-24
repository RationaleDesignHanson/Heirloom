//
//  LogViewerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-19.
//

import SwiftUI

/// Debug view for viewing device logs
/// Accessible from Settings → Developer Testing → View Logs
struct LogViewerView: View {

    @State private var logContent: String = "Loading..."
    @State private var isRefreshing = false
    @State private var searchText = ""
    @State private var filterCredits = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)

                Toggle("💳", isOn: $filterCredits)
                    .toggleStyle(.button)
                    .help("Filter to credit logs only")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            // Log content
            ScrollView {
                ScrollViewReader { proxy in
                    Text(filteredLogs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .id("logBottom")
                        .onAppear {
                            // Scroll to bottom on appear
                            proxy.scrollTo("logBottom", anchor: .bottom)
                        }
                }
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Device Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        refreshLogs()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Share Log File", systemImage: "square.and.arrow.up")
                    }

                    Divider()

                    Button(role: .destructive) {
                        clearLogs()
                    } label: {
                        Label("Clear Logs", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            refreshLogs()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = DeviceLogger.shared.getLogFileURL() {
                LogShareSheet(items: [url])
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredLogs: String {
        var lines = logContent.components(separatedBy: "\n")

        // Filter by search text
        if !searchText.isEmpty {
            lines = lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }

        // Filter to credit logs only
        if filterCredits {
            lines = lines.filter { $0.contains("[Credits]") }
        }

        if lines.isEmpty {
            return filterCredits ? "No credit logs found.\n\nTry importing a recipe or purchasing credits to generate logs." : "No logs match your search."
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Actions

    private func refreshLogs() {
        isRefreshing = true
        logContent = DeviceLogger.shared.getLogContents() ?? "No logs available.\n\nLogs are only generated in DEBUG builds."
        isRefreshing = false
    }

    private func clearLogs() {
        DeviceLogger.shared.clearLog()
        logContent = "Logs cleared."
    }
}

// MARK: - LogShareSheet

/// Local share sheet for log viewer (avoids conflict with other ShareSheet definitions)
private struct LogShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LogViewerView()
    }
}
