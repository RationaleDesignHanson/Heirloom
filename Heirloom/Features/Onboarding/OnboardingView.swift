import SwiftUI
import UserNotifications
import EventKit

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showImportOptions = false

    let totalPages = 4

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.cream
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Welcome
                welcomePage
                    .tag(0)

                // Page 2: Capture
                featurePage(
                    icon: "link.circle.fill",
                    title: "Capture Any Recipe",
                    description: "Import from your favorite recipe sites, scan cookbook pages, or type them in manually.",
                    color: HeirloomColors.tomato
                )
                .tag(1)

                // Page 3: Smart Shopping
                featurePage(
                    icon: "cart.fill",
                    title: "Smart Shopping Lists",
                    description: "Combine ingredients from multiple recipes. Export directly to iOS Reminders with one tap.",
                    color: HeirloomColors.familyGreen
                )
                .tag(2)

                // Page 4: Cook
                featurePage(
                    icon: "flame.fill",
                    title: "Cook With Confidence",
                    description: "Step-by-step cooking mode with timers. Scale recipes for any serving size.",
                    color: HeirloomColors.amber
                )
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            // Custom Page Indicator & Actions
            VStack {
                Spacer()

                // Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? HeirloomColors.tomato : HeirloomColors.warmGray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.bottom, 20)

                // Action Buttons
                if currentPage < totalPages - 1 {
                    HStack(spacing: 16) {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))

                        Spacer()

                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                } else {
                    Button {
                        showImportOptions = true
                    } label: {
                        Text("Get Started")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showImportOptions) {
            FirstRecipeImportView(onComplete: {
                completeOnboarding()
            })
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 40) {
            Spacer()

            // App Icon
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80))
                .foregroundStyle(HeirloomColors.tomato)
                .padding(.bottom, 20)

            // Title
            Text("Heirloom")
                .font(.system(size: 48, weight: .bold, design: .serif))
                .foregroundStyle(HeirloomColors.charcoal)

            // Tagline
            Text("Recipes worth passing down")
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Feature Pages

    private func featurePage(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(color)

            // Title
            Text(title)
                .font(HeirloomFonts.title1)
                .foregroundStyle(HeirloomColors.charcoal)
                .multilineTextAlignment(.center)

            // Description
            Text(description)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}

// MARK: - First Recipe Import View

struct FirstRecipeImportView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var showURLImport = false
    @State private var showPhotoImport = false
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 60))
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Add Your First Recipe")
                        .font(HeirloomFonts.title1)
                        .foregroundStyle(HeirloomColors.charcoal)
                        .multilineTextAlignment(.center)

                    Text("Choose how you'd like to start")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                // Import Options
                VStack(spacing: 16) {
                    importOptionButton(
                        icon: "link",
                        title: "Paste Recipe URL",
                        subtitle: "From any recipe website",
                        recommended: true
                    ) {
                        requestPermissionsAndImport(.url)
                    }

                    importOptionButton(
                        icon: "camera.fill",
                        title: "Scan Cookbook",
                        subtitle: "Capture recipe pages with camera"
                    ) {
                        requestPermissionsAndImport(.photo)
                    }

                    importOptionButton(
                        icon: "square.and.pencil",
                        title: "Type It In",
                        subtitle: "Write your own recipe"
                    ) {
                        requestPermissionsAndImport(.manual)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Skip Button
                Button("I'll do this later") {
                    onComplete()
                }
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                .padding(.bottom, 40)
            }
            .background(HeirloomColors.cream)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onComplete()
                    }
                }
            }
        }
    }

    private func importOptionButton(
        icon: String,
        title: String,
        subtitle: String,
        recommended: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.tomato)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(HeirloomFonts.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(HeirloomColors.charcoal)

                        if recommended {
                            Text("RECOMMENDED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(HeirloomColors.tomato)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(HeirloomColors.tomato.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.charcoal.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(16)
            .background(.white)
            .cornerRadius(12)
            .shadow(color: HeirloomShadows.card.color, radius: HeirloomShadows.card.radius, x: 0, y: 2)
        }
    }

    private func requestPermissionsAndImport(_ type: ImportType) {
        Task {
            // Request permissions based on import type
            switch type {
            case .url, .manual:
                // No special permissions needed
                performImport(type)

            case .photo:
                // Request camera and possibly notifications
                let notificationCenter = UNUserNotificationCenter.current()
                _ = try? await notificationCenter.requestAuthorization(options: [.alert, .sound])
                performImport(type)
            }
        }
    }

    private func performImport(_ type: ImportType) {
        switch type {
        case .url:
            showURLImport = true
        case .photo:
            showPhotoImport = true
        case .manual:
            showManualEntry = true
        }

        // Dismiss after showing import
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }

    enum ImportType {
        case url, photo, manual
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
