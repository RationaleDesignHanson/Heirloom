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
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(version.displayName)
                                                .font(.body)

                                            if version.generation > 0 {
                                                Text(version.modifiedAt, style: .relative)
                                                    .font(HeirloomFonts.caption1)
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
}
