//
//  OnboardingImportMethodsScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-01-10.
//

import SwiftUI

/// First onboarding screen - Import methods showcase
struct OnboardingImportMethodsScreen: View {
    let onContinue: () -> Void
    @State private var selectedMethod: ImportMethod? = nil

    enum ImportMethod: Identifiable {
        case video, image, website, manual

        var id: Self { self }

        var icon: String {
            switch self {
            case .video: return "video.fill"
            case .image: return "camera.viewfinder"
            case .website: return "globe"
            case .manual: return "square.and.pencil"
            }
        }

        var title: String {
            switch self {
            case .video: return "Video to recipe"
            case .image: return "Image scan"
            case .website: return "Website"
            case .manual: return "Manual"
            }
        }

        var subtitle: String {
            switch self {
            case .video: return "Your favorite creators"
            case .image: return "Cookbooks & family recipes"
            case .website: return "URLs, share extension, emails"
            case .manual: return "Write from scratch"
            }
        }

        var detailedDescription: String {
            switch self {
            case .video:
                return "Import recipes from cooking videos on YouTube, Instagram, and TikTok. AI analyzes the video to extract ingredients, steps, and timing."
            case .image:
                return "Scan recipe cards, cookbook pages, or handwritten family recipes. AI recognizes text and converts it to a structured recipe."
            case .website:
                return "Save recipes from any website with a URL. Works with share extension and email links. Automatically formats and organizes."
            case .manual:
                return "Type or dictate your own recipes from scratch. Perfect for your original creations or recipes from memory."
            }
        }

        var accentColor: Color {
            switch self {
            case .video: return .purple
            case .image: return .blue
            case .website: return .green
            case .manual: return .orange
            }
        }
    }

    var body: some View {
        ZStack {
            // Background with paper texture
            ZStack {
                HeirloomColors.cream
                    .ignoresSafeArea()

                // Subtle paper texture overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .ignoresSafeArea()
                    .blendMode(.overlay)
            }

            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)

                // App Icon & Title (more compact)
                VStack(spacing: 12) {
                    Image("ceramic-hero-book")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)

                    Text("Heirloom")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(HeirloomColors.charcoal)
                }

                // Headline
                Text("Import recipes from a...")
                    .font(HeirloomFonts.title1)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 32)

                // 2x2 Grid of Import Method Cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: HeirloomSpacing.md),
                    GridItem(.flexible(), spacing: HeirloomSpacing.md)
                ], spacing: HeirloomSpacing.md) {
                    ForEach([ImportMethod.video, .image, .website, .manual]) { method in
                        ImportMethodCard(
                            icon: method.icon,
                            title: method.title,
                            subtitle: method.subtitle,
                            accentColor: method.accentColor
                        )
                        .onTapGesture {
                            selectedMethod = method
                        }
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.top, 24)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

                // Continue Button
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)
            }

            // Preview overlay
            if let method = selectedMethod {
                ImportMethodPreviewOverlay(
                    method: method,
                    onDismiss: { selectedMethod = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMethod)
    }
}

// MARK: - Preview Overlay

/// Modal overlay showing detailed information about an import method
struct ImportMethodPreviewOverlay: View {
    let method: OnboardingImportMethodsScreen.ImportMethod
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Card
            VStack(alignment: .leading, spacing: HeirloomSpacing.lg) {
                // Header
                HStack(spacing: HeirloomSpacing.md) {
                    Image(systemName: method.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(method.accentColor)
                        .frame(width: 60, height: 60)
                        .background(method.accentColor.opacity(0.1))
                        .cornerRadius(16)

                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text(method.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(HeirloomColors.charcoal)

                        Text(method.subtitle)
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()
                }

                // Description
                Text(method.detailedDescription)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.charcoal)
                    .lineSpacing(6)

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(method.accentColor)
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(HeirloomColors.cardBackground)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingImportMethodsScreen(onContinue: {})
}
