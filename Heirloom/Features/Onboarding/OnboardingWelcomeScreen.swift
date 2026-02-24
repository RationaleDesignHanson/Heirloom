//
//  OnboardingWelcomeScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Updated for new 5-screen onboarding flow
//  Task 1: "Turn recipe chaos into a recipe box" visual
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Welcome screen - Screen 1 of 5
/// Shows the "3 inputs → 1 recipe" transformation visual
struct OnboardingWelcomeScreen: View {
    @Environment(\.modelContext) private var modelContext

    let onContinue: () -> Void
    /// Callback when user restores from backup (skips rest of onboarding)
    var onRestoreFromBackup: (() -> Void)?

    @State private var showSources = false
    @State private var showArrow = false
    @State private var showResult = false
    @State private var showRestoreFilePicker = false
    @State private var showRestorePreview = false
    @State private var restoreFileURL: URL?
    @State private var restorePreviewData: ImportPreviewData?

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
                Text("1/5")
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
                            Text("Turn recipe chaos into a recipe box")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("Save from links, videos, cookbooks, and photos—all in one tap.")
                                .font(HeirloomFonts.body)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        // "3 inputs → 1 recipe" visual
                        inputsToRecipeVisual
                            .padding(.horizontal, HeirloomSpacing.md)
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

                    // Restore from backup option - prominent styling to match Continue button
                    if onRestoreFromBackup != nil {
                        Button(action: {
                            showRestoreFilePicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Restore from Backup")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .foregroundColor(HeirloomColors.primaryText)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }

                    // Microcopy
                    Text("Private by default")
                        .font(HeirloomFonts.caption2)
                        .foregroundColor(.secondary.opacity(0.6))
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
        .fileImporter(
            isPresented: $showRestoreFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleRestoreFileSelection(result)
        }
        .sheet(isPresented: $showRestorePreview) {
            if let fileURL = restoreFileURL, let previewData = restorePreviewData {
                ImportPreviewSheet(
                    previewData: previewData,
                    fileURL: fileURL,
                    modelContext: modelContext,
                    cleanRestore: true,
                    onRestoreComplete: {
                        showRestorePreview = false
                        onRestoreFromBackup?()
                    }
                )
            }
        }
        .onAppear {
            // Staggered entrance animations
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showSources = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
                showArrow = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) {
                showResult = true
            }
        }
    }

    // MARK: - Inputs to Recipe Visual

    private var inputsToRecipeVisual: some View {
        HStack(spacing: 12) {
            // Left side: 3 stacked source cards
            sourceCardsStack
                .frame(maxWidth: .infinity)

            // Middle: Arrow indicator
            arrowIndicator

            // Right side: Clean recipe result
            recipeResultCard
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Source Cards Stack

    private var sourceCardsStack: some View {
        ZStack {
            // Video source (back, tilted left)
            sourceCard(
                imageName: "onboarding-source-video",
                label: "Video",
                icon: "play.circle.fill"
            )
            .rotationEffect(.degrees(-8))
            .offset(x: -16, y: -20)
            .opacity(showSources ? 1 : 0)
            .offset(x: showSources ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: showSources)

            // Cookbook source (middle, slight tilt)
            sourceCard(
                imageName: "onboarding-source-cookbook",
                label: "Cookbook",
                icon: "book.fill"
            )
            .rotationEffect(.degrees(4))
            .offset(x: 8, y: 0)
            .opacity(showSources ? 1 : 0)
            .offset(x: showSources ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.35), value: showSources)

            // Website source (front, tilted right)
            sourceCard(
                imageName: "onboarding-source-website",
                label: "Website",
                icon: "globe"
            )
            .rotationEffect(.degrees(-2))
            .offset(x: -4, y: 24)
            .opacity(showSources ? 1 : 0)
            .offset(x: showSources ? 0 : -30)
            .animation(.easeOut(duration: 0.5).delay(0.5), value: showSources)
        }
        .frame(height: 200)
    }

    private func sourceCard(imageName: String, label: String, icon: String) -> some View {
        VStack(spacing: 0) {
            // Image
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)

            // Label with icon
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(HeirloomFonts.caption2)
            }
            .foregroundColor(HeirloomColors.secondaryText)
            .padding(.top, 6)
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    // MARK: - Arrow Indicator

    private var arrowIndicator: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(HeirloomColors.tomato)
                .opacity(showArrow ? 1 : 0)
                .scaleEffect(showArrow ? 1 : 0.5)
        }
        .frame(width: 40)
    }

    // MARK: - Recipe Result Card

    private var recipeResultCard: some View {
        VStack(spacing: 0) {
            // Recipe image
            Image("onboarding-source-recipe")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 140, height: 180)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    // Subtle Heirloom badge
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Saved")
                                .font(HeirloomFonts.caption2)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(HeirloomColors.tomato.opacity(0.9))
                        .cornerRadius(12)
                        .padding(8)
                    },
                    alignment: .bottom
                )
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .opacity(showResult ? 1 : 0)
        .offset(x: showResult ? 0 : 30)
    }

    // MARK: - Restore File Handling

    private func handleRestoreFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start security-scoped access
            guard url.startAccessingSecurityScopedResource() else {
                Log.error("Failed to access security-scoped resource", category: .storage)
                return
            }

            // Parse the file to get preview data
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let exportWrapper = try decoder.decode(HeirloomExportV2.self, from: data)

                let previewData = ImportPreviewData(
                    version: exportWrapper.version,
                    recipeCount: exportWrapper.recipeCount,
                    hasProfile: exportWrapper.userProfile != nil,
                    connectionCount: exportWrapper.connectionCount ?? 0,
                    hasPrivacySettings: exportWrapper.privacySettings != nil,
                    warnings: buildWarnings(for: exportWrapper)
                )

                restoreFileURL = url
                restorePreviewData = previewData
                showRestorePreview = true

            } catch {
                Log.error("Failed to parse restore file", category: .storage, error: error)
                url.stopAccessingSecurityScopedResource()
            }

        case .failure(let error):
            Log.error("File selection failed", category: .storage, error: error)
        }
    }

    private func buildWarnings(for export: HeirloomExportV2) -> [String] {
        var warnings: [String] = []

        if export.themeProgress == nil {
            warnings.append("No theme progress found - you may need to re-select themes")
        }

        if export.connectionCount ?? 0 > 0 {
            warnings.append("Connections will need to be manually re-established")
        }

        // Check for shared recipes that might have been updated
        let sharedRecipeCount = export.recipes.filter { $0.sharedBy != nil }.count
        if sharedRecipeCount > 0 {
            warnings.append("Shared recipes (\(sharedRecipeCount)) will be restored as they were at backup time")
        }

        // Theme recipes will be refreshed from Firebase
        let themeRecipeCount = export.recipes.filter { $0.isThemeRecipe }.count
        if themeRecipeCount > 0 {
            // This is informational, not a warning - theme recipes get refreshed automatically
        }

        return warnings
    }
}

// MARK: - Preview

#Preview {
    OnboardingWelcomeScreen(
        onContinue: { print("Continue tapped") }
    )
}
