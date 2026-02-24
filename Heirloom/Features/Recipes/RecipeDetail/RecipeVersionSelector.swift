import SwiftUI

/// Unified version control card that combines version selection, change summary, and diff view
struct RecipeVersionSelector: View {
    @ObservedObject var viewModel: RecipeVersionSelectorViewModel
    @Binding var selectedVersion: RecipeLineageVersion?
    @Binding var isDiffExpanded: Bool

    let changeSummary: String?
    let originalVersion: RecipeLineageVersion?

    /// Heritage chain count for offline fallback display
    var heritageChainCount: Int = 0

    /// Real-time network status from NetworkMonitor
    var isOffline: Bool = false

    @State private var showOfflineHelp = false

    /// Whether we have lineage data to show (either loaded versions or heritage chain)
    private var hasLineageData: Bool {
        viewModel.versions.count > 1 || heritageChainCount > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Show offline indicator if offline and we have lineage data
            if isOffline && hasLineageData {
                offlineVersionIndicator
            }
            // Show full selector if we have multiple loaded versions and online
            else if viewModel.versions.count > 1 && !isOffline {
                VStack(alignment: .leading, spacing: 0) {
                    // Badge + Version Selector Row
                    HStack(spacing: HeirloomSpacing.sm) {
                        // Change badge (only show for modified versions)
                        if changeSummary != nil,
                           let selected = selectedVersion,
                           selected.generation > 0 {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isDiffExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isDiffExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .font(HeirloomFonts.title2)
                                    .foregroundStyle(HeirloomColors.success)
                                    .rotationEffect(.degrees(isDiffExpanded ? 0 : 0))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDiffExpanded)
                            }
                            .buttonStyle(.plain)
                        }

                        // Version Selector Dropdown
                        Menu {
                            ForEach(viewModel.versions) { version in
                                Button {
                                    selectedVersion = version
                                } label: {
                                    HStack(spacing: HeirloomSpacing.xs) {
                                        // Person icon
                                        Image(systemName: "person.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        // Version name with optional compact timestamp
                                        if version.isCurrent && version.generation > 0 {
                                            Text("\(version.displayName) (\(version.compactTimestamp))")
                                                .font(.body)
                                        } else {
                                            Text(version.displayName)
                                                .font(.body)
                                        }

                                        Spacer()

                                        // Checkmark for selected version
                                        if version.id == selectedVersion?.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: HeirloomSpacing.sm) {
                                VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                                    Text("Viewing")
                                        .font(HeirloomFonts.caption2)
                                        .foregroundStyle(HeirloomColors.secondaryText)

                                    HStack(spacing: HeirloomSpacing.xs) {
                                        Image(systemName: "arrow.triangle.branch")
                                            .font(HeirloomFonts.caption1)

                                        Text(selectedVersion?.displayName ?? "Select Version")
                                            .font(HeirloomFonts.bodyBold)

                                        Image(systemName: "chevron.down")
                                            .font(HeirloomFonts.caption2)
                                    }
                                    .foregroundStyle(HeirloomColors.charcoal)
                                }

                                Spacer()
                            }
                        }
                    }
                    .padding(HeirloomSpacing.md)

                    // Expanded "What Changed" Section
                    if isDiffExpanded,
                       let summary = changeSummary,
                       let selected = selectedVersion,
                       let original = originalVersion,
                       selected.generation > 0 {
                        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                            Divider()
                                .padding(.horizontal, HeirloomSpacing.md)

                            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                                Text("What Changed")
                                    .font(HeirloomFonts.caption1Bold)
                                    .foregroundStyle(HeirloomColors.charcoal)

                                Text(summary)
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(HeirloomColors.secondaryText)
                            }
                            .padding(.horizontal, HeirloomSpacing.md)

                            Divider()
                                .padding(.horizontal, HeirloomSpacing.md)

                            RecipeDiffView(
                                currentVersion: selected,
                                comparedVersion: original
                            )
                            .padding(HeirloomSpacing.md)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .fill(HeirloomColors.cream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                        .strokeBorder(
                            selectedVersion?.generation ?? 0 > 0 ? HeirloomColors.success.opacity(0.3) : HeirloomColors.charcoal.opacity(0.1),
                            lineWidth: 1
                        )
                )
            }

            if let error = viewModel.error {
                Text(error)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Offline Version Indicator

    private var offlineVersionIndicator: some View {
        HStack(spacing: HeirloomSpacing.sm) {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                Text("Versions")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.warmGray)

                HStack(spacing: HeirloomSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(HeirloomFonts.caption1)

                    Text("\(max(viewModel.versions.count, heritageChainCount)) versions (offline)")
                        .font(HeirloomFonts.bodyBold)

                    Image(systemName: "wifi.slash")
                        .font(HeirloomFonts.caption2)
                }
                .foregroundStyle(HeirloomColors.warmGray)
            }

            Spacer()

            // Help button
            Button {
                showOfflineHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .buttonStyle(.plain)
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .fill(HeirloomColors.cream.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                .strokeBorder(HeirloomColors.warmGray.opacity(0.2), lineWidth: 1)
        )
        .alert("Offline Mode", isPresented: $showOfflineHelp) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Version history requires an internet connection.\n\nTip: Tap the download arrow (↓) next to the recipe title to save this recipe for offline viewing.")
        }
    }
}
