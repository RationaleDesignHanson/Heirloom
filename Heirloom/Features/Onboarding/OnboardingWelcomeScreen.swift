//
//  OnboardingWelcomeScreen.swift
//  Heirloom
//
//  Created by Claude Code on 2026-02-01.
//  Updated for capture breadth narrative - Feb 2026
//  "Save from anywhere" - showing all input sources
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Capture breadth screen - Screen 1 of 7
/// Shows all the ways users can save recipes: video, web, photo, handwriting, voice, generative
struct OnboardingWelcomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth

    let onContinue: () -> Void
    /// Callback when user restores from backup (skips rest of onboarding)
    var onRestoreFromBackup: (() -> Void)?

    @State private var showSources = false
    @State private var showRestoreFilePicker = false
    @State private var showRestorePreview = false
    @State private var restoreFileURL: URL?
    @State private var restorePreviewData: ImportPreviewData?
    @State private var showSignOutConfirmation = false

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
                // Progress indicator with sign-out escape hatch
                HStack {
                    Spacer()
                    Text("1/7")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.secondaryText)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    // Sign-out escape hatch (for users stuck due to keychain auth restore)
                    if firebaseAuth.isAuthenticated {
                        Button {
                            showSignOutConfirmation = true
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14))
                                .foregroundColor(HeirloomColors.secondaryText.opacity(0.5))
                                .padding(8)
                        }
                        .accessibilityLabel("Sign out")
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                .padding(.horizontal, 16)

                // Scrollable content
                GeometryReader { geometry in
                    ScrollView {
                    VStack(spacing: 24) {
                        // Header - Capture breadth
                        VStack(spacing: 12) {
                            Text("Save from anywhere")
                                .font(HeirloomFonts.title1Elevated)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .kerning(-0.5)

                            Text("However your recipes exist, Heirloom can capture them.")
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
            // Trigger staggered grid animation
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showSources = true
            }
        }
        .confirmationDialog(
            "Sign Out?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                do {
                    try firebaseAuth.signOut()
                    Log.info("User signed out from welcome screen", category: .auth)
                } catch {
                    Log.error("Failed to sign out from welcome screen", category: .auth, error: error)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sign out to use a different account.")
        }
    }

    // MARK: - Capture Sources Grid

    private var inputsToRecipeVisual: some View {
        VStack(spacing: 20) {
            // 2x3 grid of capture sources
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                captureSourceTile(icon: "video.fill", label: "Video", delay: 0.0)
                captureSourceTile(icon: "globe", label: "Websites", delay: 0.1)
                captureSourceTile(icon: "photo.fill", label: "Photos + PDFs", delay: 0.2)
                captureSourceTile(icon: "pencil.and.scribble", label: "Handwriting", delay: 0.3)
                captureSourceTile(icon: "mic.fill", label: "Voice", delay: 0.4)
                captureSourceTile(icon: "sparkles", label: "Generative", delay: 0.5)
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 20)
    }

    private func captureSourceTile(icon: String, label: String, delay: Double) -> some View {
        VStack(spacing: 10) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(HeirloomColors.tomato.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(HeirloomColors.tomato)
            }

            // Label
            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        .opacity(showSources ? 1 : 0)
        .offset(y: showSources ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(delay), value: showSources)
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
