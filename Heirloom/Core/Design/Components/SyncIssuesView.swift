import SwiftUI

/// View that displays sync errors and recovery options
/// Shows detailed information about CloudKit sync issues
struct SyncIssuesView: View {
    private let syncCoordinator = CloudKitSyncCoordinator.shared
    private let networkMonitor = NetworkMonitor.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                    // Error Icon and Title
                    VStack(spacing: HeirloomSpacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(HeirloomColors.tomato)

                        Text("Sync Issue Detected")
                            .font(HeirloomFonts.title2)
                            .foregroundStyle(HeirloomColors.primaryText)

                        if let errorTime = syncCoordinator.lastErrorTime {
                            Text(timeAgoString(from: errorTime))
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, HeirloomSpacing.xl)

                    // Error Details
                    if let error = syncCoordinator.lastSyncError {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            Text("What Happened")
                                .font(HeirloomFonts.title3)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Text(errorDescription(for: error))
                                .font(HeirloomFonts.body)
                                .foregroundStyle(HeirloomColors.secondaryText)
                                .padding(HeirloomSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(HeirloomColors.warmGray.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Divider()
                            .padding(.vertical, HeirloomSpacing.sm)

                        // Recovery Steps
                        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                            Text("How to Fix")
                                .font(HeirloomFonts.title3)
                                .foregroundStyle(HeirloomColors.primaryText)

                            ForEach(recoverySteps(for: error), id: \.self) { step in
                                HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.body)
                                        .foregroundStyle(HeirloomColors.familyGreen)

                                    Text(step)
                                        .font(HeirloomFonts.body)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }
                            }
                        }

                        // Status Info
                        Divider()
                            .padding(.vertical, HeirloomSpacing.sm)

                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            StatusRow(
                                icon: networkMonitor.isConnected ? "wifi" : "wifi.slash",
                                label: "Network",
                                value: networkMonitor.isConnected ? "Online" : "Offline",
                                color: networkMonitor.isConnected ? HeirloomColors.success : HeirloomColors.tomato
                            )

                            StatusRow(
                                icon: "icloud",
                                label: "Pending Operations",
                                value: "\(syncCoordinator.pendingOperations.count)",
                                color: syncCoordinator.pendingOperations.isEmpty ? HeirloomColors.success : HeirloomColors.amber
                            )
                        }
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Sync Issues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action Buttons
                VStack(spacing: HeirloomSpacing.sm) {
                    // Retry Button
                    if networkMonitor.isConnected && !syncCoordinator.pendingOperations.isEmpty {
                        Button {
                            Task {
                                await syncCoordinator.processPendingOperations()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Retry Sync Now")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HeirloomColors.tomato)
                            .foregroundStyle(.white)
                            .font(HeirloomFonts.bodyBold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(syncCoordinator.isSyncing)
                    }

                    // Clear Error Button
                    Button {
                        syncCoordinator.clearLastError()
                        dismiss()
                    } label: {
                        Text("Dismiss")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HeirloomColors.warmGray.opacity(0.2))
                            .foregroundStyle(HeirloomColors.primaryText)
                            .font(HeirloomFonts.body)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(HeirloomSpacing.md)
                .background(HeirloomColors.cream)
            }
        }
    }

    // MARK: - Helper Methods

    private func errorDescription(for error: CloudKitSyncError) -> String {
        switch error {
        case .networkUnavailable:
            return "Your device lost its network connection while syncing. Your changes have been saved locally and will sync when you're back online."

        case .notAuthenticated:
            return "You're not signed into iCloud. Please sign in to your Apple ID in Settings to enable sync."

        case .quotaExceeded:
            return "Your iCloud storage is full. Please free up space or upgrade your iCloud storage plan to continue syncing."

        case .conflictDetected:
            return "The same recipe was edited on multiple devices. We attempted to merge the changes automatically."

        case .recordNotFound:
            return "A recipe you're trying to sync no longer exists on iCloud. It may have been deleted on another device."

        case .permissionDenied:
            return "You don't have permission to access this shared content. Contact the owner for access."

        case .serviceUnavailable:
            return "iCloud services are temporarily unavailable. We'll automatically retry when the service is back."

        case .rateLimited:
            return "Too many sync requests in a short time. We'll automatically retry after a brief delay."

        case .badRequest:
            return "There was a problem with the sync request. Please restart the app and try again."

        case .internalError:
            return "An internal error occurred during sync. We'll automatically retry."

        case .zoneBusy:
            return "iCloud is busy processing your data. We'll automatically retry in a moment."

        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    private func recoverySteps(for error: CloudKitSyncError) -> [String] {
        switch error {
        case .networkUnavailable:
            return [
                "Check your Wi-Fi or cellular connection",
                "Try toggling Airplane Mode off and on",
                "Your changes will sync automatically when online"
            ]

        case .notAuthenticated:
            return [
                "Open Settings on your device",
                "Tap on your name at the top",
                "Sign in with your Apple ID",
                "Enable iCloud for Heirloom"
            ]

        case .quotaExceeded:
            return [
                "Go to Settings → [Your Name] → iCloud",
                "Manage your storage or upgrade your plan",
                "Delete unnecessary files to free up space"
            ]

        case .conflictDetected:
            return [
                "Your changes have been preserved",
                "Review the recipe to ensure it looks correct",
                "The conflict has been resolved automatically"
            ]

        case .recordNotFound:
            return [
                "This recipe may have been deleted elsewhere",
                "Check your other devices",
                "You can recreate the recipe if needed"
            ]

        case .permissionDenied:
            return [
                "Contact the recipe owner for access",
                "They may need to re-share the recipe with you",
                "Check that you're signed into the correct iCloud account"
            ]

        case .serviceUnavailable, .rateLimited, .internalError, .zoneBusy:
            return [
                "This is a temporary issue",
                "We'll automatically retry for you",
                "No action needed on your part"
            ]

        case .badRequest:
            return [
                "Close and reopen the app",
                "If the problem persists, try restarting your device",
                "Contact support if the issue continues"
            ]

        case .unknownError:
            return [
                "Try restarting the app",
                "Check your internet connection",
                "If the issue persists, contact support"
            ]
        }
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Status Row Component

private struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Network Error") {
    SyncIssuesView()
}
