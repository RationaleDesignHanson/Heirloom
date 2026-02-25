//
//  ImportPreviewSheet.swift
//  Heirloom
//
//  Social Layer Phase 7: Import preview with confirmation
//  Shows what will be imported before user confirms
//

import SwiftUI
import SwiftData
import FirebaseFirestore

struct ImportPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let previewData: ImportPreviewData
    let fileURL: URL
    let modelContext: ModelContext

    /// If true, performs a clean restore (deletes all existing data first)
    /// Default is true for settings restore - prevents merge conflicts
    var cleanRestore: Bool = true

    /// Callback when restore completes (used for onboarding flow)
    var onRestoreComplete: (() -> Void)?

    @State private var isImporting = false
    @State private var importResult: HeirloomImportResult?
    @State private var showResult = false
    @State private var importError: String?
    @State private var generateMissingImages = false
    @State private var sharedRecipeCount = 0
    @State private var showSharedRecipePrompt = false
    @State private var isCheckingSharedUpdates = false

    // Image restoration progress
    @State private var isRestoringImages = false
    @State private var imageRestoreProgress: Int = 0
    @State private var imageRestoreTotal: Int = 0

    // Import progress tracking
    enum ImportPhase: String {
        case preparing = "Preparing..."
        case importingRecipes = "Importing recipes..."
        case linkingCollections = "Linking collections..."
        case restoringImages = "Restoring images..."
        case downloadingThemes = "Downloading themes..."
        case finishing = "Finishing up..."
    }
    @State private var importPhase: ImportPhase = .preparing
    @State private var importProgress: Double = 0.0  // 0.0 to 1.0
    @State private var progressTimer: Timer?

    private var exporter: HeirloomDataExporter {
        let profileService: ProfileServiceProtocol = ServiceContainer.shared.resolve(ProfileServiceProtocol.self)
        let connectionService: ConnectionServiceProtocol = ServiceContainer.shared.resolve(ConnectionServiceProtocol.self)
        let recipeExporter: RecipeExporter = ServiceContainer.shared.resolve(RecipeExporter.self)
        return HeirloomDataExporter(
            profileService: profileService,
            connectionService: connectionService,
            recipeExporter: recipeExporter
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    if !showResult {
                        previewSection
                    } else if let result = importResult {
                        resultSection(result)
                    }
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle(isImporting ? "Restoring..." : (cleanRestore ? "Restore Preview" : "Import Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showResult && !isImporting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button(cleanRestore ? "Restore" : "Import") {
                            Task {
                                await performImport()
                            }
                        }
                    }
                } else if showResult {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Show progress during import
            if isImporting {
                importProgressSection
            } else {
                // Header
                headerSection

                // What will be imported
                importCountsSection

                // Warnings
                if !previewData.warnings.isEmpty {
                    warningsSection
                }

                // Instructions
                instructionsSection

                // Image generation option
                imageGenerationSection
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: cleanRestore ? "arrow.counterclockwise.circle.fill" : "doc.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.familyGreen)

                Text(cleanRestore ? "Ready to Restore" : "Ready to Import")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text(cleanRestore
                 ? "Your recipes and settings will be restored from this backup."
                 : "Review what will be imported from this backup file.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var importProgressSection: some View {
        VStack(spacing: HeirloomSpacing.xl) {
            // Animated icon
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.familyGreen)
                .rotationEffect(.degrees(isImporting ? 360 : 0))
                .animation(
                    isImporting ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                    value: isImporting
                )

            // Phase text
            Text(importPhase.rawValue)
                .font(HeirloomFonts.title3)
                .foregroundStyle(HeirloomColors.primaryText)
                .animation(.easeInOut(duration: 0.3), value: importPhase)

            // Progress bar
            VStack(spacing: HeirloomSpacing.sm) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HeirloomColors.warmGray.opacity(0.3))
                            .frame(height: 8)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(HeirloomColors.familyGreen)
                            .frame(width: geometry.size.width * importProgress, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: importProgress)
                    }
                }
                .frame(height: 8)

                // Percentage text
                Text("\(Int(importProgress * 100))%")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .monospacedDigit()
            }

            // Recipe count hint
            Text("Restoring \(previewData.recipeCount) recipes")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(16)
    }

    private var importCountsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("What will be imported:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                importCountRow(
                    icon: "fork.knife.circle.fill",
                    title: "Recipes",
                    count: previewData.recipeCount,
                    color: HeirloomColors.tomato
                )

                if previewData.hasProfile {
                    importCountRow(
                        icon: "person.circle.fill",
                        title: "Profile Data",
                        count: 1,
                        color: HeirloomColors.familyGreen
                    )
                }

                // Note: Connections are stored in backup but NOT restored
                // (would require re-establishing with the other user)
                // So we don't show them in the preview to avoid confusion

                if previewData.hasPrivacySettings {
                    importCountRow(
                        icon: "lock.circle.fill",
                        title: "Privacy Settings",
                        count: 1,
                        color: HeirloomColors.warmGray
                    )
                }

                if previewData.bundledImageCount > 0 {
                    importCountRow(
                        icon: "photo.circle.fill",
                        title: "Bundled Images",
                        count: previewData.bundledImageCount,
                        color: HeirloomColors.familyGreen
                    )
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func importCountRow(icon: String, title: String, count: Int, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            Text(title)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text("\(count)")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(HeirloomColors.warning)

                Text("Important Notes")
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                ForEach(previewData.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Text("•")
                            .foregroundStyle(HeirloomColors.warning)
                        Text(warning)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.warning.opacity(0.1))
        .cornerRadius(12)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text(cleanRestore ? "How restore works:" : "How import works:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                if cleanRestore {
                    instructionItem("Your recipes and collections will be restored")
                    instructionItem("Theme unlock progress will be restored")
                    instructionItem("Recipe images will be restored from backup")
                    instructionItem("Friend connections are not restored")
                } else {
                    instructionItem("Recipes will be merged with your existing collection")
                    instructionItem("Duplicate recipes will be skipped")
                    instructionItem("Your current data won't be deleted")
                    instructionItem("Recipe images will be restored from backup")
                }
            }

            // Account flexibility note for clean restore
            if cleanRestore {
                accountFlexibilityNote
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    private var accountFlexibilityNote: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 14))
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Works with any sign-in method")
                    .font(HeirloomFonts.caption1)
                    .fontWeight(.medium)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text("Your backup data syncs to your current account, regardless of how you signed in.")
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
        .padding(.top, HeirloomSpacing.sm)
    }

    @ViewBuilder
    private func instructionItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(HeirloomColors.familyGreen)
                .padding(.top, 2)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    private var imageGenerationSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Toggle(isOn: $generateMissingImages) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate images for recipes without photos")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("Uses AI to create images for recipes that couldn't be restored")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .tint(HeirloomColors.familyGreen)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Result Section

    @ViewBuilder
    private func resultSection(_ result: HeirloomImportResult) -> some View {
        VStack(spacing: HeirloomSpacing.lg) {
            // Success/Error Header
            if result.errors.isEmpty {
                successHeader
            } else {
                partialSuccessHeader
            }

            // Import Statistics
            statisticsSection(result)

            // Image restoration progress
            if isRestoringImages {
                imageRestorationProgressSection
            }

            // Shared recipe update prompt
            if sharedRecipeCount > 0 && !isCheckingSharedUpdates {
                sharedRecipeUpdateSection
            }

            // Checking for updates indicator
            if isCheckingSharedUpdates {
                checkingUpdatesSection
            }

            // Errors (if any)
            if !result.errors.isEmpty {
                errorsSection(result)
            }
        }
    }

    private var imageRestorationProgressSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.sm) {
                ProgressView()
                    .tint(HeirloomColors.familyGreen)

                Text("Restoring images...")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                Text("\(imageRestoreProgress) of \(imageRestoreTotal)")
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(HeirloomColors.warmGray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(HeirloomColors.familyGreen)
                        .frame(width: geometry.size.width * CGFloat(imageRestoreProgress) / max(CGFloat(imageRestoreTotal), 1), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.3), value: imageRestoreProgress)
                }
            }
            .frame(height: 4)

            Text("Downloading and saving recipe photos")
                .font(HeirloomFonts.caption2)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    private var sharedRecipeUpdateSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "person.2.circle.fill")
                    .font(.title2)
                    .foregroundStyle(HeirloomColors.familyGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared Recipes")
                        .font(HeirloomFonts.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(HeirloomColors.primaryText)

                    Text("You have \(sharedRecipeCount) recipes from connections")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }

                Spacer()
            }

            Text("These were restored as they were at backup time. Would you like to check if your connections have made updates?")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)

            HStack(spacing: HeirloomSpacing.md) {
                Button(action: {
                    Task {
                        await checkForSharedRecipeUpdates()
                    }
                }) {
                    Text("Check for Updates")
                        .font(HeirloomFonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, HeirloomSpacing.md)
                        .padding(.vertical, HeirloomSpacing.sm)
                        .background(HeirloomColors.familyGreen)
                        .cornerRadius(8)
                }

                Button(action: {
                    sharedRecipeCount = 0 // Hide the section
                }) {
                    Text("Keep Backup Versions")
                        .font(HeirloomFonts.subheadline)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.familyGreen.opacity(0.1))
        .cornerRadius(12)
    }

    private var checkingUpdatesSection: some View {
        HStack(spacing: HeirloomSpacing.md) {
            ProgressView()
                .tint(HeirloomColors.familyGreen)

            Text("Checking for updates from connections...")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .padding(HeirloomSpacing.md)
        .frame(maxWidth: .infinity)
        .background(HeirloomColors.cardBackground)
        .cornerRadius(12)
    }

    private var successHeader: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.success)

            Text("Import Complete")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Your data has been successfully imported.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var partialSuccessHeader: some View {
        VStack(spacing: HeirloomSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(HeirloomColors.warning)

            Text("Import Completed with Warnings")
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Some items couldn't be imported. See details below.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func statisticsSection(_ result: HeirloomImportResult) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            Text("Import Summary")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                statisticRow(icon: "fork.knife.circle.fill", title: "Recipes", count: result.recipesImported)

                // Note: Connections are not restored (would require re-establishing)
                // so we don't show them in the result summary

                if !result.errors.isEmpty {
                    statisticRow(
                        icon: "exclamationmark.circle.fill",
                        title: "Errors",
                        count: result.errors.count,
                        color: HeirloomColors.tomato
                    )
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.cream)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func statisticRow(icon: String, title: String, count: Int, color: Color = HeirloomColors.familyGreen) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            Text(title)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Spacer()

            Text("\(count)")
                .font(HeirloomFonts.bodyBold)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    @ViewBuilder
    private func errorsSection(_ result: HeirloomImportResult) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("Errors")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                ForEach(result.errors.prefix(10), id: \.message) { error in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(HeirloomColors.tomato)
                            .padding(.top, 2)

                        Text(error.message)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }

                if result.errors.count > 10 {
                    Text("...and \(result.errors.count - 10) more")
                        .font(HeirloomFonts.caption2)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.tomato.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Import Logic

    private func performImport() async {
        isImporting = true
        importError = nil
        importPhase = .preparing
        importProgress = 0.0

        // Security-scoped access is required for files selected via fileImporter
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Phase 1: Preparing (0-10%)
            await updateProgress(phase: .preparing, progress: 0.05)

            // Clean restore: delete all existing data first
            if cleanRestore {
                await cleanExistingData()
            }
            await updateProgress(phase: .preparing, progress: 0.10)

            // Phase 2: Importing recipes (10-50%)
            await updateProgress(phase: .importingRecipes, progress: 0.15)

            var options = cleanRestore ? HeirloomImportOptions.recipesOnly : HeirloomImportOptions.mergeAll
            options.generateMissingImages = generateMissingImages
            // For clean restore, we want to import all data including theme progress
            if cleanRestore {
                options.mergeRecipes = false // Replace, don't merge
                options.restorePrivacySettings = true
            }
            // Skip async image restoration - we'll do it with progress tracking
            options.skipImageRestoration = true

            let result = try await exporter.importData(
                from: fileURL,
                context: modelContext,
                options: options
            )

            // Phase 3: Linking collections (50-60%)
            await updateProgress(phase: .linkingCollections, progress: 0.50)

            Log.info("Import completed", category: .storage, metadata: [
                "version": result.version,
                "recipesImported": result.recipesImported,
                "errorCount": result.errors.count,
                "cleanRestore": cleanRestore,
                "imagesToRestore": result.imagesToRestore.count
            ])

            // IMPORTANT: Recreate system collections after clean restore
            if cleanRestore {
                await MainActor.run {
                    RecipeCollection.createSystemCollections(context: modelContext)
                    try? modelContext.save()
                    Log.info("Recreated system collections after restore", category: .storage)
                }
            }
            await updateProgress(phase: .linkingCollections, progress: 0.60)

            // Phase 4: Restoring images (60-80%)
            if !result.imagesToRestore.isEmpty {
                await updateProgress(phase: .restoringImages, progress: 0.60)
                await restoreImagesWithProgress(result.imagesToRestore)
            }
            await updateProgress(phase: .restoringImages, progress: 0.80)

            // Phase 5: Downloading themes (80-95%)
            if cleanRestore {
                await updateProgress(phase: .downloadingThemes, progress: 0.80)
                await refreshThemeRecipesFromFirebase()
            }
            await updateProgress(phase: .downloadingThemes, progress: 0.95)

            // Phase 6: Finishing (95-100%)
            await updateProgress(phase: .finishing, progress: 0.95)

            // Mark onboarding as complete after successful restore
            if cleanRestore {
                await markOnboardingComplete()
            }

            // Count shared recipes for update prompt
            await countSharedRecipes()

            await updateProgress(phase: .finishing, progress: 1.0)

            // Show result
            await MainActor.run {
                self.importResult = result
                self.showResult = true
                self.isImporting = false
            }

            // Call completion handler if provided (for onboarding flow)
            // Note: Don't call immediately if there are shared recipes - wait for user decision
            if sharedRecipeCount == 0 {
                onRestoreComplete?()
            }

        } catch {
            await MainActor.run {
                self.importError = error.localizedDescription
                self.isImporting = false
            }

            Log.error("Import failed", category: .storage, error: error)
        }
    }

    /// Update import progress on main thread
    private func updateProgress(phase: ImportPhase, progress: Double) async {
        await MainActor.run {
            self.importPhase = phase
            self.importProgress = progress
        }
    }

    /// Delete all existing local data for clean restore
    private func cleanExistingData() async {
        Log.info("Cleaning existing data for restore", category: .storage)

        // Delete all recipes
        let recipeDescriptor = FetchDescriptor<Recipe>()
        if let recipes = try? modelContext.fetch(recipeDescriptor) {
            for recipe in recipes {
                modelContext.delete(recipe)
            }
            Log.info("Deleted \(recipes.count) recipes", category: .storage)
        }

        // Delete all collections
        let collectionDescriptor = FetchDescriptor<RecipeCollection>()
        if let collections = try? modelContext.fetch(collectionDescriptor) {
            for collection in collections {
                modelContext.delete(collection)
            }
            Log.info("Deleted \(collections.count) collections", category: .storage)
        }

        // Clear theme progress from UserDefaults
        let userDefaults = UserDefaults.standard
        userDefaults.removeObject(forKey: "selected_theme_ids")
        userDefaults.removeObject(forKey: "theme_trial_start_date")
        userDefaults.removeObject(forKey: "last_unlock_day")

        // Save context
        try? modelContext.save()

        Log.info("Clean restore: existing data deleted", category: .storage)
    }

    /// Download theme recipes from Firebase based on restored theme progress
    /// Theme recipes are NOT stored in backups - they come from Firebase/JSON
    /// This recreates theme recipes and collections based on the selectedThemeIds restored from backup
    private func refreshThemeRecipesFromFirebase() async {
        // Get selected theme IDs from UserDefaults (restored from backup's themeProgress)
        let selectedThemeIds = UserDefaults.standard.stringArray(forKey: "selected_theme_ids") ?? []

        guard !selectedThemeIds.isEmpty else {
            Log.info("No selected themes to download - user may not have selected themes yet", category: .storage)
            return
        }

        Log.info("Downloading theme recipes for restored theme selection", category: .storage, metadata: [
            "themeCount": selectedThemeIds.count,
            "themeIds": selectedThemeIds
        ])

        let themeService = ThemeRecipeService()

        for themeId in selectedThemeIds {
            do {
                // Download recipes for this theme (creates recipes with unlockDay set)
                let recipes = try await themeService.downloadRecipesForTheme(themeId: themeId, into: modelContext)
                Log.info("Downloaded theme recipes", category: .storage, metadata: [
                    "themeId": themeId,
                    "count": recipes.count
                ])
            } catch {
                Log.warning("Failed to download theme recipes", category: .storage, metadata: [
                    "themeId": themeId,
                    "error": error.localizedDescription
                ])
                // Continue with other themes even if one fails
            }
        }

        try? modelContext.save()

        // Now create theme collections and link recipes
        // This is normally done in CollectionsListView but we need to do it here for restore
        await createThemeCollectionsAfterRestore(themeIds: selectedThemeIds)

        Log.info("Theme recipe download complete", category: .storage)
    }

    /// Create theme collections and link unlocked recipes after restore
    private func createThemeCollectionsAfterRestore(themeIds: [String]) async {
        Log.info("Creating theme collections after restore", category: .storage)

        // Fetch all themes from database
        let themeDescriptor = FetchDescriptor<RecipeTheme>()
        guard let allThemes = try? modelContext.fetch(themeDescriptor) else {
            Log.warning("No themes found in database", category: .storage)
            return
        }

        let themeUnlockTracker = ThemeUnlockTracker()

        for themeId in themeIds {
            guard let theme = allThemes.first(where: { $0.firebaseId == themeId }) else {
                Log.warning("Theme not found for collection creation", category: .storage, metadata: ["themeId": themeId])
                continue
            }

            // Check if collection already exists
            let collectionDescriptor = FetchDescriptor<RecipeCollection>(
                predicate: #Predicate<RecipeCollection> { $0.sourceThemeId == themeId }
            )

            if let existing = try? modelContext.fetch(collectionDescriptor), !existing.isEmpty {
                Log.debug("Theme collection already exists", category: .storage, metadata: ["themeId": themeId])
                continue
            }

            // Create theme collection
            let collection = RecipeCollection(name: theme.name)
            collection.collectionType = CollectionType.theme.rawValue
            collection.sourceTheme = theme
            collection.sourceThemeId = theme.firebaseId
            collection.recipes = []
            modelContext.insert(collection)

            // Link only unlocked recipes
            let recipeDescriptor = FetchDescriptor<Recipe>(
                predicate: #Predicate<Recipe> { $0.sourceThemeId == themeId }
            )

            if let themeRecipes = try? modelContext.fetch(recipeDescriptor) {
                for recipe in themeRecipes {
                    if themeUnlockTracker.isUnlocked(recipe) {
                        collection.recipes?.append(recipe)
                    }
                }

                Log.info("Created theme collection", category: .storage, metadata: [
                    "themeId": themeId,
                    "themeName": theme.name,
                    "linkedRecipes": collection.recipes?.count ?? 0,
                    "totalRecipes": themeRecipes.count
                ])
            }
        }

        try? modelContext.save()
    }

    /// Restore images with progress tracking
    /// This provides visual feedback during the ~2 minute image restoration process
    private func restoreImagesWithProgress(_ imagesToRestore: [ImageRestoreInfo]) async {
        guard !imagesToRestore.isEmpty else { return }

        await MainActor.run {
            self.isRestoringImages = true
            self.imageRestoreTotal = imagesToRestore.count
            self.imageRestoreProgress = 0
        }

        Log.info("Starting image restoration with progress", category: .storage, metadata: [
            "total": imagesToRestore.count
        ])

        var restored = 0
        var failed = 0

        for imageInfo in imagesToRestore {
            do {
                try await exporter.restoreImage(firebaseURL: imageInfo.firebaseURL, for: imageInfo.recipe)
                restored += 1
            } catch {
                failed += 1
                Log.warning("Image restore failed", category: .storage, metadata: [
                    "recipeId": imageInfo.recipe.id.uuidString,
                    "error": error.localizedDescription
                ])
            }

            await MainActor.run {
                self.imageRestoreProgress = restored + failed
            }
        }

        // Save after all restorations
        try? modelContext.save()

        await MainActor.run {
            self.isRestoringImages = false
        }

        Log.info("Image restoration with progress complete", category: .storage, metadata: [
            "restored": restored,
            "failed": failed
        ])
    }

    /// Count shared recipes after import for update prompt
    private func countSharedRecipes() async {
        let sharedDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.sharedByUserId != nil }
        )

        if let sharedRecipes = try? modelContext.fetch(sharedDescriptor) {
            await MainActor.run {
                self.sharedRecipeCount = sharedRecipes.count
            }
            Log.info("Found shared recipes after restore", category: .storage, metadata: [
                "count": sharedRecipes.count
            ])
        }
    }

    /// Mark onboarding as complete after successful restore
    /// This prevents showing onboarding again and uploads profile to Firebase
    private func markOnboardingComplete() async {
        // Set local flag
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()

        // Upload profile to Firebase so other devices/sessions know onboarding is done
        let profileService = ServiceContainer.shared.resolve(FirebaseUserProfileService.self)
        do {
            try await profileService.syncCurrentUserProfile()
            Log.info("Marked onboarding complete after restore", category: .storage)
        } catch {
            // Non-fatal - local flag is set, Firebase sync will catch up later
            Log.warning("Failed to sync profile after restore", category: .storage, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    /// Check for updates to shared recipes from connections
    private func checkForSharedRecipeUpdates() async {
        isCheckingSharedUpdates = true

        let sharedDescriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { $0.sharedByUserId != nil }
        )

        guard let sharedRecipes = try? modelContext.fetch(sharedDescriptor) else {
            isCheckingSharedUpdates = false
            sharedRecipeCount = 0
            onRestoreComplete?()
            return
        }

        var updatedCount = 0
        let firestore = Firestore.firestore()

        for recipe in sharedRecipes {
            guard let sharerId = recipe.sharedByUserId else { continue }

            // Try to find the original recipe in the sharer's collection
            do {
                let querySnapshot: QuerySnapshot

                if let originalRecipeId = recipe.sharedFromRecipeId {
                    // Query by original recipe ID (exact match, lowercase UUID)
                    querySnapshot = try await firestore
                        .collection("users")
                        .document(sharerId)
                        .collection("recipes")
                        .whereField("id", isEqualTo: originalRecipeId)
                        .limit(to: 1)
                        .getDocuments()
                } else {
                    // Fallback: query by title (for legacy shared recipes without sharedFromRecipeId)
                    querySnapshot = try await firestore
                        .collection("users")
                        .document(sharerId)
                        .collection("recipes")
                        .whereField("title", isEqualTo: recipe.title)
                        .whereField("isDeleted", isEqualTo: false)
                        .limit(to: 1)
                        .getDocuments()
                }

                guard let document = querySnapshot.documents.first else {
                    // Original not found (sharer may have deleted it or their account)
                    continue
                }

                let data = document.data()

                // Check if the sharer's version is newer
                if let sharerModifiedTimestamp = data["modifiedAt"] as? Timestamp {
                    let sharerModified = sharerModifiedTimestamp.dateValue()

                    if sharerModified > recipe.lastModified {
                        // Update recipe with sharer's newer version
                        // Preserve user's personal fields
                        let userFavorite = recipe.isFavorite
                        let userTimesCooked = recipe.timesCooked
                        let userLastCooked = recipe.lastCooked
                        let userCardBack = recipe.cardBack

                        // Update content fields
                        recipe.title = data["title"] as? String ?? recipe.title
                        recipe.notes = data["notes"] as? String
                        recipe.servings = data["servings"] as? String
                        recipe.prepTime = data["prepTime"] as? String
                        recipe.cookTime = data["cookTime"] as? String

                        if let instructionsData = data["instructions"] as? [String] {
                            recipe.instructions = instructionsData
                        }

                        if let imageURL = data["firebaseImageURL"] as? String {
                            recipe.firebaseImageURL = imageURL
                        }

                        // Restore user's personal fields
                        recipe.isFavorite = userFavorite
                        recipe.timesCooked = userTimesCooked
                        recipe.lastCooked = userLastCooked
                        recipe.cardBack = userCardBack

                        updatedCount += 1
                        Log.info("Updated shared recipe from connection", category: .storage, metadata: [
                            "title": recipe.title,
                            "sharerId": sharerId
                        ])
                    }
                }
            } catch {
                Log.warning("Failed to check for shared recipe update", category: .storage, metadata: [
                    "title": recipe.title,
                    "error": error.localizedDescription
                ])
                // Continue checking other recipes
            }
        }

        try? modelContext.save()

        await MainActor.run {
            self.isCheckingSharedUpdates = false
            self.sharedRecipeCount = 0 // Hide the prompt
        }

        Log.info("Shared recipe update check complete", category: .storage, metadata: [
            "checked": sharedRecipes.count,
            "updated": updatedCount
        ])

        // Now call completion handler
        onRestoreComplete?()
    }
}

// MARK: - Preview

#Preview {
    ImportPreviewSheet(
        previewData: ImportPreviewData(
            version: 2,
            recipeCount: 42,
            hasProfile: true,
            connectionCount: 0,  // Connections not shown (not restored)
            hasPrivacySettings: true,
            warnings: []
        ),
        fileURL: URL(fileURLWithPath: "/tmp/test.json"),
        modelContext: ModelContext(try! ModelContainer(for: Recipe.self))
    )
}
