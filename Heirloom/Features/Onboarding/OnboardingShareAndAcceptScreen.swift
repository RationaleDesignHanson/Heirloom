//
//  OnboardingShareAndAcceptScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Versioning demo animation
//

import SwiftUI

/// Share and Accept screen - Screen 4 of 5
/// Shows the versioning model with side-by-side recipe cards
struct OnboardingShareAndAcceptScreen: View {
    let onContinue: () -> Void

    // Versioning demo states
    @State private var showSideBySide = false
    @State private var showCardLabels = false
    @State private var showEditIndicator = false
    @State private var showVersionNotification = false
    @State private var showVersionDropdown = false
    @State private var selectedVersion: VersionOption = .current
    @State private var showSyncGlow = false

    enum VersionOption {
        case current
        case mom
    }

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
                Text("4/5")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Text("Everyone gets their own copy")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Make it yours — and see what others change.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // Versioning demo
                        sideBySideView
                            .padding(.horizontal, 24)
                            .opacity(showSideBySide ? 1 : 0)
                            .scaleEffect(showSideBySide ? 1 : 0.95)

                        // Differentiator callout
                        differentiatorCallout
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }

                // Fixed bottom CTAs
                VStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
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
            startAnimationSequence()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Brief entrance delay then start versioning demo directly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            startVersioningDemo()
        }
    }

    // MARK: - Versioning Demo Animation

    private func startVersioningDemo() {
        // Show side-by-side view with brief entrance
        withAnimation(.easeOut(duration: 0.3)) {
            showSideBySide = true
        }

        // Show labels after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCardLabels = true
            }
        }

        // Edit indicator on Mom's card - animated highlight lines show changes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showEditIndicator = true
            }
        }

        // Notification on Your card
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showVersionNotification = true
            }
        }

        // Dropdown opens
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showVersionDropdown = true
            }
        }

        // Select Mom's version
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedVersion = .mom
                showSyncGlow = true
            }
        }

        // Hide sync glow
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSyncGlow = false
            }
        }

        // Toggle back to current
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                selectedVersion = .current
            }
        }
    }

    // MARK: - Side-by-Side Versioning View

    /// Dynamic header text that changes based on animation state
    private var sideBySideHeaderText: String {
        if showEditIndicator {
            return "See your friends' versions when they make changes"
        } else {
            return "Recipe versions stay connected"
        }
    }

    private var sideBySideView: some View {
        VStack(spacing: 16) {
            // Section header - changes when edit indicator shows
            if showCardLabels {
                Text(sideBySideHeaderText)
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: showEditIndicator)
                    .transition(.opacity)
            }

            // Two cards side by side
            HStack(spacing: 12) {
                momRecipeCard
                yourRecipeCard
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Mom's Recipe Card

    private var momRecipeCard: some View {
        VStack(spacing: 8) {
            // Card label
            if showCardLabels {
                HStack(spacing: 4) {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(HeirloomColors.tomato)
                        )
                    Text("Mom's copy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Recipe card
            VStack(alignment: .leading, spacing: 6) {
                // Recipe thumbnail
                Image("onboarding-pot-roast")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Nana's Pot Roast")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                Text("6 servings")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Animated edit lines showing changes
                if showEditIndicator {
                    VStack(alignment: .leading, spacing: 3) {
                        // Line 1: ingredient change highlight
                        editHighlightLine(delay: 0, text: "3 lb → 4 lb chuck roast")
                        // Line 2: another change
                        editHighlightLine(delay: 0.3, text: "+ 1 cup red wine")
                    }
                    .transition(.opacity)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showSyncGlow && selectedVersion == .mom ? HeirloomColors.familyGreen : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
    }

    // MARK: - Edit Highlight Line Animation

    private func editHighlightLine(delay: Double, text: String) -> some View {
        EditHighlightLineView(text: text, delay: delay, isAnimating: showEditIndicator)
    }

    // MARK: - Your Recipe Card

    private var yourRecipeCard: some View {
        VStack(spacing: 8) {
            // Card label
            if showCardLabels {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        )
                    Text("Your copy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Recipe card
            VStack(alignment: .leading, spacing: 6) {
                // Recipe thumbnail with notification
                ZStack(alignment: .top) {
                    Image("onboarding-pot-roast")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // New version notification banner
                    if showVersionNotification && selectedVersion == .current {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 8))
                            Text("New version")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(6)
                        .offset(y: -8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }

                Text("Nana's Pot Roast")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                // Subtitle changes based on selected version
                Text(selectedVersion == .mom ? "6 servings" : "4 servings")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Version dropdown
                if showVersionDropdown {
                    versionDropdown
                        .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showSyncGlow ? HeirloomColors.familyGreen : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
    }

    // MARK: - Version Dropdown

    private var versionDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dropdown header (selected option)
            HStack(spacing: 4) {
                Text(selectedVersion == .current ? "Current" : "Mom's")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(HeirloomColors.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(6)

            // Dropdown options (expanded appearance)
            VStack(alignment: .leading, spacing: 0) {
                // Current option
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedVersion == .current ? HeirloomColors.tomato : Color.clear)
                        .frame(width: 6, height: 6)
                    Text("Current")
                        .font(.system(size: 10))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedVersion == .current ? HeirloomColors.tomato.opacity(0.1) : Color.clear)

                Divider()

                // Mom's version option
                HStack(spacing: 6) {
                    Circle()
                        .fill(selectedVersion == .mom ? HeirloomColors.tomato : Color.clear)
                        .frame(width: 6, height: 6)
                    Text("Mom (Jan '26)")
                        .font(.system(size: 10))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedVersion == .mom ? HeirloomColors.tomato.opacity(0.1) : Color.clear)
            }
            .background(Color.white)
            .cornerRadius(6)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .padding(.top, 4)
        }
    }

    // MARK: - Differentiator Callout

    private var differentiatorCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(HeirloomColors.familyGreen)
                .font(.system(size: 18))

            Text("Unlike screenshots, shared recipes stay organized and searchable")
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Edit Highlight Line View

/// Animated line that draws in to show text changes
private struct EditHighlightLineView: View {
    let text: String
    let delay: Double
    let isAnimating: Bool

    @State private var lineProgress: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        HStack(spacing: 4) {
            // Animated highlight bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 4)

                    // Animated fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(HeirloomColors.familyGreen.opacity(0.6))
                        .frame(width: geometry.size.width * lineProgress, height: 4)
                }
            }
            .frame(width: 12, height: 4)

            // Change text
            Text(text)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(HeirloomColors.familyGreen)
                .opacity(textOpacity)
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        // Reset
        lineProgress = 0
        textOpacity = 0

        // Animate line drawing
        withAnimation(.easeOut(duration: 0.4).delay(delay)) {
            lineProgress = 1.0
        }

        // Fade in text after line completes
        withAnimation(.easeOut(duration: 0.2).delay(delay + 0.3)) {
            textOpacity = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingShareAndAcceptScreen(
        onContinue: { print("Continue tapped") }
    )
}
