//
//  SoftWallView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-08.
//

import SwiftUI

/// Soft wall for premium features - shows before hard paywall
struct SoftWallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    /// The trigger that caused this soft wall to appear
    let trigger: PaywallTrigger

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.cream
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Lock Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(HeirloomColors.warmGray)

                // Feature-specific headline
                VStack(spacing: 12) {
                    Text(headlineText)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)

                    Text(subtitleText)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 40)

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    // See Plans Button
                    Button {
                        showPaywall = true
                    } label: {
                        Text("See Plans")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }

                    // Not Now Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Not now")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: trigger)
        }
    }

    // MARK: - Dynamic Text

    private var headlineText: String {
        switch trigger {
        case .urlImport:
            return "Import from URL requires Heirloom Premium"
        case .cookbookScan:
            return "Recipe scanning requires Heirloom Premium"
        case .sync:
            return "Syncing across devices requires Heirloom Premium"
        default:
            return "This feature requires Heirloom Premium"
        }
    }

    private var subtitleText: String {
        "You can still add recipes manually by typing them in."
    }
}

// MARK: - Preview

#Preview("URL Import") {
    SoftWallView(trigger: .urlImport)
}

#Preview("Cookbook Scan") {
    SoftWallView(trigger: .cookbookScan)
}

#Preview("Sync") {
    SoftWallView(trigger: .sync)
}
