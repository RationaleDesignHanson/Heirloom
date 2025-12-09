import SwiftUI
import CloudKit

struct CloudKitDashboardView: View {
    @StateObject private var monitor = CloudKitMonitoringService.shared
    @State private var selectedTab: DashboardTab = .status
    @State private var showingDiagnosticsExport = false
    @State private var diagnosticsReport = ""

    enum DashboardTab {
        case status, activity, errors, metrics
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                tabSelector

                Divider()

                // Content
                ScrollView {
                    contentView
                        .padding()
                }
                .background(HeirloomColors.appBackground)
            }
            .navigationTitle("CloudKit Monitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await monitor.checkConnection()
                                await monitor.checkAccountStatus()
                            }
                        } label: {
                            Label("Refresh Status", systemImage: "arrow.clockwise")
                        }

                        Button {
                            exportDiagnostics()
                        } label: {
                            Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive) {
                            monitor.clearErrorLog()
                        } label: {
                            Label("Clear Error Log", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            monitor.clearSyncActivity()
                        } label: {
                            Label("Clear Activity", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDiagnosticsExport) {
                DiagnosticsExportView(report: diagnosticsReport)
            }
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(.status, icon: "cloud", title: "Status")
            tabButton(.activity, icon: "list.bullet", title: "Activity")
            tabButton(.errors, icon: "exclamationmark.triangle", title: "Errors")
            tabButton(.metrics, icon: "chart.bar", title: "Metrics")
        }
        .background(Color.gray.opacity(0.1))
    }

    private func tabButton(_ tab: DashboardTab, icon: String, title: String) -> some View {
        Button {
            withAnimation {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selectedTab == tab ? HeirloomColors.tomato.opacity(0.1) : Color.clear)
            .foregroundStyle(selectedTab == tab ? HeirloomColors.tomato : HeirloomColors.secondaryText)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .status:
            statusView
        case .activity:
            activityView
        case .errors:
            errorsView
        case .metrics:
            metricsView
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Connection Status Card
            statusCard(
                title: "Connection Status",
                icon: monitor.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill",
                iconColor: monitor.isConnected ? .green : .red,
                status: monitor.isConnected ? "Connected" : "Disconnected",
                subtitle: "iCloud CloudKit Service"
            )

            // Account Status Card
            statusCard(
                title: "iCloud Account",
                icon: accountIcon,
                iconColor: accountColor,
                status: accountStatusText,
                subtitle: accountSubtitle
            )

            // Last Sync Card
            if let lastSync = monitor.metrics.lastSyncDate {
                statusCard(
                    title: "Last Sync",
                    icon: "clock.arrow.circlepath",
                    iconColor: HeirloomColors.familyGreen,
                    status: RelativeDateTimeFormatter().localizedString(for: lastSync, relativeTo: Date()),
                    subtitle: lastSync.formatted()
                )
            }

            // Quick Stats
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                Text("Quick Stats")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HeirloomSpacing.md) {
                    statBox("Shares", value: "\(monitor.metrics.totalShares)", color: .blue)
                    statBox("Pass Downs", value: "\(monitor.metrics.totalPassDowns)", color: HeirloomColors.amber)
                    statBox("Successful", value: "\(monitor.metrics.successfulSyncs)", color: .green)
                    statBox("Failed", value: "\(monitor.metrics.failedSyncs)", color: .red)
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }

    private func statusCard(title: String, icon: String, iconColor: Color, status: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(status)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(subtitle)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    private func statBox(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Activity View

    private var activityView: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
            if monitor.syncActivity.isEmpty {
                emptyState(
                    icon: "list.bullet",
                    title: "No Activity",
                    message: "CloudKit sync activity will appear here"
                )
            } else {
                ForEach(monitor.syncActivity) { event in
                    activityRow(event)
                }
            }
        }
    }

    private func activityRow(_ event: CloudKitMonitoringService.SyncEvent) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: event.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(event.success ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.type.rawValue)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(event.details)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text(event.timestamp.formatted(.relative(presentation: .named)))
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - Errors View

    private var errorsView: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
            if monitor.errorLog.isEmpty {
                emptyState(
                    icon: "checkmark.circle",
                    title: "No Errors",
                    message: "All CloudKit operations are running smoothly"
                )
            } else {
                ForEach(monitor.errorLog) { error in
                    errorRow(error)
                }
            }
        }
    }

    private func errorRow(_ error: CloudKitMonitoringService.ErrorEvent) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)

                Text(error.operation)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text(error.timestamp.formatted(.relative(presentation: .named)))
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            Text(error.error.localizedDescription)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            HStack(spacing: HeirloomSpacing.md) {
                Label("Code: \(error.errorCode)", systemImage: "number")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text("•")
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text(error.errorDomain)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            if !error.details.isEmpty {
                Text(error.details)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.red.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Metrics View

    private var metricsView: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
            // Success Rate
            metricsCard(
                title: "Success Rate",
                value: String(format: "%.1f%%", monitor.getSyncSuccessRate()),
                icon: "chart.line.uptrend.xyaxis",
                color: .green
            )

            // Activity Breakdown
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                Text("Activity Breakdown")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                VStack(spacing: HeirloomSpacing.sm) {
                    metricsRow(label: "Total Shares", value: "\(monitor.metrics.totalShares)")
                    metricsRow(label: "Total Pass Downs", value: "\(monitor.metrics.totalPassDowns)")
                    metricsRow(label: "Total Accepts", value: "\(monitor.metrics.totalAccepts)")
                    metricsRow(label: "Successful Syncs", value: "\(monitor.metrics.successfulSyncs)")
                    metricsRow(label: "Failed Syncs", value: "\(monitor.metrics.failedSyncs)")
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4)

            // Recent Activity (24h)
            let recentActivity = monitor.getRecentActivity()
            if !recentActivity.isEmpty {
                metricsCard(
                    title: "Last 24 Hours",
                    value: "\(recentActivity.count) events",
                    icon: "clock",
                    color: .blue
                )
            }

            // Recent Errors (24h)
            let recentErrors = monitor.getRecentErrors()
            if !recentErrors.isEmpty {
                metricsCard(
                    title: "Errors (24h)",
                    value: "\(recentErrors.count)",
                    icon: "exclamationmark.triangle",
                    color: .red
                )
            }
        }
    }

    private func metricsCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(color)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)

                Text(value)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    private func metricsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            Spacer()

            Text(value)
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(Color.gray.opacity(0.3))

            Text(title)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(message)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func exportDiagnostics() {
        diagnosticsReport = monitor.exportDiagnostics()
        showingDiagnosticsExport = true
    }

    // MARK: - Account Status Helpers

    private var accountIcon: String {
        switch monitor.accountStatus {
        case .available:
            return "checkmark.icloud.fill"
        case .noAccount:
            return "icloud.slash"
        case .restricted:
            return "lock.icloud"
        default:
            return "icloud"
        }
    }

    private var accountColor: Color {
        switch monitor.accountStatus {
        case .available:
            return .green
        case .noAccount, .restricted:
            return .red
        default:
            return .orange
        }
    }

    private var accountStatusText: String {
        switch monitor.accountStatus {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    private var accountSubtitle: String {
        switch monitor.accountStatus {
        case .available:
            return "Your iCloud account is working properly"
        case .noAccount:
            return "Sign in to iCloud in Settings"
        case .restricted:
            return "iCloud access is restricted"
        case .couldNotDetermine:
            return "Unable to verify account status"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Diagnostics Export View

struct DiagnosticsExportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Diagnostics Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = report
                        ToastManager.shared.success(title: "Copied to clipboard")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CloudKitDashboardView()
        .toastContainer()
}
