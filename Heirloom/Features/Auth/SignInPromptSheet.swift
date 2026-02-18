//
//  SignInPromptSheet.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-12.
//

import SwiftUI

/// Half-sheet modal prompting user to sign in for sync & sharing features
struct SignInPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSignInFlow = false

    var body: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Icon with gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                HeirloomColors.tomato.opacity(0.15),
                                HeirloomColors.tomato.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 32))
                    .foregroundStyle(HeirloomColors.tomato)
            }
            .padding(.top, 32)

            // Title & Message
            VStack(spacing: 12) {
                Text("Sync & Share Your Recipes")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .multilineTextAlignment(.center)

                Text("Sync your recipes across devices and share with your community")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            // Benefits List
            VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
                benefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Sync across devices",
                    description: "Access your recipes on all your devices"
                )

                benefitRow(
                    icon: "person.2.fill",
                    title: "Share with community",
                    description: "Share recipes with friends and family"
                )

                benefitRow(
                    icon: "lock.shield.fill",
                    title: "Secure backup",
                    description: "Never lose your recipes again"
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action Buttons
            VStack(spacing: 12) {
                // Primary: Sign In
                Button {
                    showSignInFlow = true
                } label: {
                    Text("Sign In")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }

                // Secondary: Not Now
                Button {
                    recordDismissal()
                    dismiss()
                } label: {
                    Text("Not Now")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(HeirloomColors.cream)
        .sheet(isPresented: $showSignInFlow) {
            FirebaseSignInView()
                .presentationDetents([.large])
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }

    // MARK: - Private Methods

    private func recordDismissal() {
        UserDefaults.standard.set(Date(), forKey: "SignInPromptLastDismissed")
    }
}

// MARK: - Preview

#Preview {
    SignInPromptSheet()
}
