import SwiftUI

/// Banner displayed when the app is offline
/// Appears at the top of views to inform users about connectivity status
struct OfflineBanner: View {
    let networkMonitor: NetworkMonitor

    @State private var isExpanded = false

    var body: some View {
        if !networkMonitor.isConnected {
            VStack(spacing: 0) {
                // Main banner
                HStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.white)

                    Text("Offline")
                        .font(HeirloomFonts.caption1Bold)
                        .foregroundStyle(.white)

                    Spacer()

                    // Info button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel(isExpanded ? "Hide details" : "Show details")
                }
                .padding(.horizontal, HeirloomSpacing.md)
                .padding(.vertical, HeirloomSpacing.sm)
                .background(HeirloomColors.warmGray)

                // Expanded info
                if isExpanded {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("You're currently offline")
                            .font(HeirloomFonts.callout)
                            .foregroundStyle(.white)

                        Text("Changes will sync automatically when connection is restored.")
                            .font(HeirloomFonts.footnote)
                            .foregroundStyle(.white.opacity(0.9))

                        HStack(spacing: HeirloomSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)

                            Text("You can still:")
                                .font(HeirloomFonts.caption1Bold)
                                .foregroundStyle(.white)
                        }
                        .padding(.top, HeirloomSpacing.xs)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                            FeatureItem(icon: "book.closed", text: "View saved recipes")
                            FeatureItem(icon: "cart", text: "Manage shopping lists")
                            FeatureItem(icon: "paintbrush", text: "Personalize cards")
                            FeatureItem(icon: "pencil", text: "Edit recipes")
                        }
                        .padding(.leading, HeirloomSpacing.md)
                    }
                    .padding(HeirloomSpacing.md)
                    .background(HeirloomColors.warmGray.opacity(0.9))
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Offline mode active")
            .accessibilityHint("Changes will sync when online")
        }
    }
}

// MARK: - Feature Item

private struct FeatureItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: HeirloomSpacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 16)

            Text(text)
                .font(HeirloomFonts.caption2)
                .foregroundStyle(.white.opacity(0.9))
        }
    }
}

// MARK: - View Extension

extension View {
    /// Add offline banner to a view
    /// The banner automatically appears/disappears based on network status
    func offlineBanner(networkMonitor: NetworkMonitor = ServiceContainer.shared.resolve(NetworkMonitor.self)) -> some View {
        VStack(spacing: 0) {
            OfflineBanner(networkMonitor: networkMonitor)

            self
        }
    }
}

// MARK: - Preview

#Preview("Online") {
    VStack {
        OfflineBanner(networkMonitor: {
            let monitor = NetworkMonitor()
            #if DEBUG
            monitor.simulateOnline()
            #endif
            return monitor
        }())

        Spacer()
    }
}

#Preview("Offline") {
    VStack {
        OfflineBanner(networkMonitor: {
            let monitor = NetworkMonitor()
            #if DEBUG
            monitor.simulateOffline()
            #endif
            return monitor
        }())

        Spacer()
    }
}
