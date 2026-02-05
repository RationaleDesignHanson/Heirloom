//
//  OnboardingShareExtensionScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-23.
//  Updated for new 5-screen onboarding flow on 2026-02-01
//  Task 3: Interactive 3-step animation showing share workflow
//

import SwiftUI

/// Share Sheet Aha screen - Screen 3 of 5
/// Teaches the core one-tap save workflow with animated mockup
struct OnboardingShareExtensionScreen: View {
    let onContinue: () -> Void

    @State private var currentStep = 1
    @State private var isAnimating = true
    @State private var heirloomIconPulse = false

    // Animation timing
    private let step1Duration: Double = 2.0
    private let step2Duration: Double = 1.5
    private let step3Duration: Double = 2.0
    private let pauseDuration: Double = 1.0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90), // Warm cream
                    Color(red: 0.95, green: 0.90, blue: 0.85)  // Soft beige
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress indicator
                Text("3/5")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Save from anywhere")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("See a recipe? Share it to Heirloom.")
                                .font(HeirloomFonts.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Phone mockup with animated steps
                        phoneMockup
                            .padding(.horizontal, 24)

                        // Step indicators
                        stepIndicators
                            .padding(.top, 8)

                        // Coach mark tip
                        coachMarkTip
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                    .padding(.bottom, 16)
                }

                // Fixed bottom CTAs
                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(HeirloomColors.tomato)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: HeirloomColors.tomato.opacity(0.3), radius: 12, y: 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.90, blue: 0.85).opacity(0),
                            Color(red: 0.95, green: 0.90, blue: 0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .onAppear {
            startAnimationLoop()
        }
    }

    // MARK: - Animation Loop

    private func startAnimationLoop() {
        guard isAnimating else { return }

        // Step 1: Safari with recipe
        currentStep = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + step1Duration) {
            guard isAnimating else { return }
            // Step 2: Share sheet with pulse
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = 2
            }
            // Start pulse animation
            withAnimation(.easeInOut(duration: 0.5).repeatCount(2, autoreverses: true)) {
                heirloomIconPulse = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + step2Duration) {
                guard isAnimating else { return }
                heirloomIconPulse = false
                // Step 3: Success toast
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = 3
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + step3Duration + pauseDuration) {
                    // Loop back
                    startAnimationLoop()
                }
            }
        }
    }

    // MARK: - Phone Mockup

    private var phoneMockup: some View {
        ZStack {
            // Phone frame
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.black)
                .frame(width: 220, height: 380)

            // Phone screen
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .frame(width: 204, height: 364)

            // Screen content based on step
            Group {
                switch currentStep {
                case 1:
                    step1SafariView
                case 2:
                    step2ShareSheetView
                case 3:
                    step3SuccessView
                default:
                    step1SafariView
                }
            }
            .frame(width: 204, height: 364)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
    }

    // MARK: - Step 1: Safari

    private var step1SafariView: some View {
        VStack(spacing: 0) {
            // Safari URL bar
            HStack {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("seriouseats.com")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            // Recipe content mockup
            VStack(spacing: 8) {
                // Recipe image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.largeTitle)
                            .foregroundColor(.orange.opacity(0.5))
                    )

                Text("Pasta Carbonara")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)

                Text("A classic Italian pasta...")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding(12)

            Spacer()

            // Safari toolbar with highlighted share button
            HStack(spacing: 24) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.3))

                // Share button (highlighted)
                ZStack {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(HeirloomColors.tomato)
                }

                Image(systemName: "book")
                Image(systemName: "square.on.square")
            }
            .font(.system(size: 18))
            .foregroundColor(.blue)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
        }
    }

    // MARK: - Step 2: Share Sheet

    private var step2ShareSheetView: some View {
        VStack(spacing: 0) {
            // Dimmed background
            Color.black.opacity(0.3)
                .frame(height: 160)

            // Share sheet
            VStack(spacing: 12) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                // App icons row
                HStack(spacing: 16) {
                    miniAppIcon("message.fill", color: .green, label: "Messages")
                    miniAppIcon("mail.fill", color: .blue, label: "Mail")

                    // Heirloom (highlighted with pulse)
                    VStack(spacing: 4) {
                        ZStack {
                            if heirloomIconPulse {
                                Circle()
                                    .stroke(HeirloomColors.tomato, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                    .scaleEffect(heirloomIconPulse ? 1.4 : 1.0)
                                    .opacity(heirloomIconPulse ? 0 : 0.8)
                            }

                            Circle()
                                .fill(HeirloomColors.tomato)
                                .frame(width: 40, height: 40)

                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        Text("Heirloom")
                            .font(.system(size: 9))
                            .foregroundColor(.primary)
                    }

                    miniAppIcon("doc.on.doc", color: .gray, label: "Copy")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                Divider()

                // Actions
                VStack(alignment: .leading, spacing: 0) {
                    shareActionRow("Add to Reading List", icon: "eyeglasses")
                    shareActionRow("Add Bookmark", icon: "book")
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16, corners: [.topLeft, .topRight])
        }
    }

    private func miniAppIcon(_ systemName: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(color)
                .cornerRadius(10)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.primary)
        }
    }

    private func shareActionRow(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
            Text(title)
                .font(.system(size: 14))
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Step 3: Success

    private var step3SuccessView: some View {
        VStack(spacing: 0) {
            // App background
            Color(red: 0.98, green: 0.95, blue: 0.90)
                .frame(maxHeight: .infinity)
                .overlay(
                    VStack {
                        Spacer()

                        // Success toast
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Saved to Inbox")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Pasta Carbonara")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80)
                    }
                )
        }
    }

    // MARK: - Step Indicators

    private var stepIndicators: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(currentStep == step ? HeirloomColors.tomato : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }

    // MARK: - Coach Mark Tip

    private var coachMarkTip: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))

            Text("Tip: You can also tap + in Heirloom to paste a link")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Corner Radius Extension

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareExtensionScreen(onContinue: {})
}
