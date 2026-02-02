//
//  VisualStylePickerView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//

import SwiftUI

struct VisualStylePickerView: View {
    @ObservedObject var styleConfig: VisualStyleConfiguration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(VisualStyle.allCases) { style in
                Button {
                    withAnimation {
                        styleConfig.selectedStyle = style
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 16) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(style.cardAccentColor?.opacity(0.15) ?? HeirloomColors.warmGray.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: style.iconName)
                                .font(.title3)
                                .foregroundStyle(style.cardAccentColor ?? HeirloomColors.primaryText)
                        }

                        // Name and description
                        VStack(alignment: .leading, spacing: 4) {
                            Text(style.displayName)
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(HeirloomColors.primaryText)

                            Text(style.description)
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)
                        }

                        Spacer()

                        // Checkmark if selected
                        if styleConfig.selectedStyle == style {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(HeirloomColors.tomato)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Visual Style")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        VisualStylePickerView(styleConfig: VisualStyleConfiguration())
    }
}
