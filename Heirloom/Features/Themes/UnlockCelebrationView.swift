//
//  UnlockCelebrationView.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-26.
//

import SwiftUI

struct UnlockCelebrationView: View {
    let newRecipeCount: Int
    let themeNames: [String]
    let onDismiss: () -> Void
    let onViewRecipes: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: HeirloomSpacing.md) {
                // Confetti icon
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.amber)
                    .scaleEffect(isVisible ? 1.0 : 0.5)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isVisible)

                // Title
                Text(UXCopy.Celebration.title)
                    .font(HeirloomFonts.title3)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                Text(UXCopy.Celebration.description(count: newRecipeCount, themeNames: themeNames))
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)

                // Buttons
                HStack(spacing: HeirloomSpacing.md) {
                    Button {
                        onDismiss()
                    } label: {
                        Text(UXCopy.Celebration.laterButton)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HeirloomSpacing.md)
                    }

                    Button {
                        onViewRecipes()
                    } label: {
                        Text(UXCopy.Celebration.viewButton)
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, HeirloomSpacing.md)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(HeirloomSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(HeirloomColors.cardBackground)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, HeirloomSpacing.lg)
            .offset(y: isVisible ? 0 : 300)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isVisible)

            Spacer()
                .frame(height: 40)
        }
        .background(Color.black.opacity(isVisible ? 0.3 : 0).ignoresSafeArea())
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    UnlockCelebrationView(
        newRecipeCount: 3,
        themeNames: ["Automat Classics", "Victory Kitchen"],
        onDismiss: {},
        onViewRecipes: {}
    )
}
