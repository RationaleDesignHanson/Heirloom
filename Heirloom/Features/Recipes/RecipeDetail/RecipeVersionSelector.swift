import SwiftUI

/// Unified version control card that combines version selection, change summary, and diff view
struct RecipeVersionSelector: View {
    @ObservedObject var viewModel: RecipeVersionSelectorViewModel
    @Binding var selectedVersion: RecipeLineageVersion?
    @Binding var isDiffExpanded: Bool

    let changeSummary: String?
    let originalVersion: RecipeLineageVersion?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Only show if we have multiple versions
            if viewModel.versions.count > 1 {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    // Version Selector Section
                    Menu {
                        ForEach(viewModel.versions) { version in
                            Button {
                                selectedVersion = version
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(version.displayName)
                                            .font(.body)

                                        if version.generation > 0 {
                                            Text(version.modifiedAt, style: .relative)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if version.id == selectedVersion?.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: HeirloomSpacing.sm) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Viewing")
                                    .font(HeirloomFonts.caption2)
                                    .foregroundStyle(HeirloomColors.secondaryText)

                                HStack(spacing: HeirloomSpacing.xs) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.caption)

                                    Text(selectedVersion?.displayName ?? "Select Version")
                                        .font(HeirloomFonts.bodyBold)

                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundStyle(HeirloomColors.charcoal)
                            }

                            Spacer()
                        }
                        .padding(HeirloomSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(HeirloomColors.cream)
                        )
                    }

                    // Change Summary Section (only for non-original versions)
                    if let summary = changeSummary,
                       let selected = selectedVersion,
                       selected.generation > 0 {
                        Divider()
                            .padding(.horizontal, HeirloomSpacing.md)

                        // Expandable change summary
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDiffExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: HeirloomSpacing.sm) {
                                Image(systemName: isDiffExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(HeirloomColors.success)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("What Changed")
                                        .font(HeirloomFonts.caption1Bold)
                                        .foregroundStyle(HeirloomColors.charcoal)

                                    Text(summary)
                                        .font(HeirloomFonts.caption2)
                                        .foregroundStyle(HeirloomColors.secondaryText)
                                }

                                Spacer()
                            }
                            .padding(HeirloomSpacing.md)
                        }

                        // Expanded diff view
                        if isDiffExpanded, let original = originalVersion {
                            Divider()
                                .padding(.horizontal, HeirloomSpacing.md)

                            RecipeDiffView(
                                currentVersion: selected,
                                comparedVersion: original
                            )
                            .padding(HeirloomSpacing.md)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(HeirloomColors.cream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
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
}
