//
//  OfflineDownloadEducationView.swift
//  Heirloom
//
//  First-time education modal for offline recipe download feature
//

import SwiftUI

/// Education modal shown first time user favorites, cooks, or adds recipe to shopping list
/// Explains the offline download feature with the download arrow
struct OfflineDownloadEducationView: View {
    let onDismiss: () -> Void
    let onDownloadNow: () -> Void

    var body: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(HeirloomColors.familyGreen.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.familyGreen)
            }
            .padding(.top, HeirloomSpacing.lg)

            // Title
            Text("Save Recipes Offline")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.charcoal)
                .multilineTextAlignment(.center)

            // Description
            VStack(spacing: HeirloomSpacing.sm) {
                Text("Want to cook without an internet connection?")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Tap the download arrow next to any recipe title to save it — including its full family heritage — for offline viewing.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, HeirloomSpacing.md)

            // Visual example
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(HeirloomColors.warmGray)

                Text("Recipe Title")
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.charcoal)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cream)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
            )

            Spacer()

            // Buttons
            VStack(spacing: HeirloomSpacing.sm) {
                Button {
                    onDownloadNow()
                } label: {
                    Text("Download This Recipe Now")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HeirloomSpacing.md)
                        .background(HeirloomColors.familyGreen)
                        .cornerRadius(12)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Got It")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.vertical, HeirloomSpacing.sm)
                }
            }
            .padding(.horizontal, HeirloomSpacing.lg)
            .padding(.bottom, HeirloomSpacing.lg)
        }
    }
}

#Preview {
    OfflineDownloadEducationView(
        onDismiss: {},
        onDownloadNow: {}
    )
}
