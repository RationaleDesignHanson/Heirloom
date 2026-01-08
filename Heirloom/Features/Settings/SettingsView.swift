import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseStorage

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @Query private var recipes: [Recipe]

    // Using concrete type for image storage
    private var imageStorageService: ImageStorageService { ServiceContainer.shared.resolve(ImageStorageService.self) }

    // Using concrete type for toast notifications
    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }
    private var backendConfig: BackendConfig { ServiceContainer.shared.resolve(BackendConfig.self) }
    private var aiConfig: AIConfiguration { ServiceContainer.shared.resolve(AIConfiguration.self) }
    private var firebaseSyncService: FirebaseSyncService { ServiceContainer.shared.resolve(FirebaseSyncService.self) }

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var storageSize: String = "Calculating..."
    @State private var showHeritageCleanup = false
    @State private var authStateChanged = false // Force view updates when auth state changes
    @State private var isClearingData = false // Show loading indicator while clearing

    var body: some View {
        NavigationStack {
            List {
                // AI Features Section
                aiSection

                // User Experience Section
                userExperienceSection

                // Data Management Section
                dataManagementSection

                // Heritage Collections Section
                heritageCollectionsSection

                // Account Section
                accountSection

                // App Info Section
                appInfoSection

                // Developer Section (for testing)
                developerSection

                // Support Section
                supportSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await calculateStorageSize()
            }
            .confirmationDialog(
                "Clear All Data",
                isPresented: $showClearDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(recipes.count) recipes. This cannot be undone.")
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your recipes.")
            }
            .sheet(isPresented: $showSignIn) {
                FirebaseSignInView()
            }
            // TODO: Re-enable once HeritageRecipeCleanupView is added to Xcode project
            // .sheet(isPresented: $showHeritageCleanup) {
            //     HeritageRecipeCleanupView()
            // }
            .onChange(of: firebaseAuth.isAuthenticated) { _, _ in
                // Toggle state to force view refresh when auth state changes
                authStateChanged.toggle()
            }
            .onChange(of: firebaseAuth.currentUser?.uid) { _, _ in
                // Also watch for user changes (different account sign-in)
                authStateChanged.toggle()
            }
            .overlay {
                if isClearingData {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Clearing data...")
                                .foregroundColor(.white)
                                .font(HeirloomFonts.bodyBold)
                        }
                        .padding(40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(white: 0.2))
                        )
                    }
                }
            }
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        Section {
            NavigationLink {
                AISettingsView()
            } label: {
                HStack {
                    Image(systemName: "brain")
                        .foregroundStyle(HeirloomColors.tomato)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Features")
                        Text(aiConfig.isConfigured(provider: .anthropic) ? "Configured" : "Not Set")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text("Configure AI-powered features like smart ingredient parsing and recipe enhancement.")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            LabeledContent("Recipes", value: "\(recipes.count)")
            LabeledContent("Storage Used", value: storageSize)

            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Clearing data will permanently delete all recipes from this device and Firebase.")
        }
    }

    // MARK: - Heritage Collections Section

    private var heritageCollectionsSection: some View {
        Section {
            let heritageCount = recipes.filter { $0.isHeritageRecipe }.count

            LabeledContent("Heritage Recipes", value: "\(heritageCount)")

            Button {
                showHeritageCleanup = true
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.brown)
                    Text("Review Unused Heritage Recipes")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Heritage Collections")
        } footer: {
            Text("Heritage recipes that haven't been used in 30+ days can be removed to keep your library organized.")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Force view dependency on authStateChanged to trigger re-renders
            let _ = authStateChanged

            if let user = firebaseAuth.currentUser {
                // Determine sign-in provider for fallback display
                let provider = user.providerData.first?.providerID ?? "Unknown"
                let providerName: String = {
                    switch provider {
                    case "apple.com": return "Apple"
                    case "google.com": return "Google"
                    case "password": return "Email"
                    default: return "Unknown Provider"
                    }
                }()

                let userDisplay = user.displayName ?? user.email ?? "Signed in with \(providerName)"
                LabeledContent("Signed in as", value: userDisplay)
                    .font(HeirloomFonts.caption1)

                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in to sync your recipes across devices and share with friends")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        showSignIn = true
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(HeirloomColors.tomato)
                    }
                }
            }
        } header: {
            Text("Account")
        } footer: {
            if firebaseAuth.currentUser != nil {
                Text("Signing out will clear local data. Your recipes are safely stored in Firebase and will sync when you sign back in.")
            } else {
                Text("Your recipes are stored locally. Sign in to enable cloud sync and sharing.")
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)

            NavigationLink {
                WhatsNewView()
            } label: {
                HStack {
                    Label("What's New", systemImage: "sparkles")
                    Spacer()
                    Text("NEW")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(HeirloomColors.tomato)
                        )
                }
            }

            NavigationLink {
                AboutView()
            } label: {
                Label("About Heirloom", systemImage: "info.circle")
            }
        } header: {
            Text("App Information")
        }
    }

    // MARK: - Developer Section

    private var developerSection: some View {
        Section {
            // Debug Log Viewer - FILE-BASED LOGGING FOR DEVICE VISIBILITY
            NavigationLink {
                DebugLogView()
            } label: {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("View Debug Log")
                    Spacer()
                    Text("📁")
                        .font(.caption)
                }
            }
        } header: {
            Text("Developer Testing")
        } footer: {
            Text("View detailed debug logs for troubleshooting.")
        }
    }

    // MARK: - User Experience Section

    private var userExperienceSection: some View {
        Section {
            Picker(selection: Binding(
                get: { UserDefaults.standard.string(forKey: "units_preferred_system") ?? "Metric" },
                set: { UserDefaults.standard.set($0, forKey: "units_preferred_system") }
            )) {
                Text("Imperial (US)").tag("Imperial")
                Text("Metric").tag("Metric")
            } label: {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Measurement System")
                }
            }
            .pickerStyle(.menu)

            Toggle(isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "cardFlipHapticsEnabled") as? Bool ?? true },
                set: { UserDefaults.standard.set($0, forKey: "cardFlipHapticsEnabled") }
            )) {
                HStack {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Card Flip Haptics")
                }
            }

            Toggle(isOn: Binding(
                get: { UserDefaults.standard.object(forKey: "cardFlipSoundEnabled") as? Bool ?? true },
                set: { UserDefaults.standard.set($0, forKey: "cardFlipSoundEnabled") }
            )) {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundStyle(HeirloomColors.tomato)
                    Text("Card Flip Sound")
                }
            }
        } header: {
            Text("User Experience")
        } footer: {
            Text("Choose your preferred measurement system for recipes. This preference will be used for future recipe imports and conversions.")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                Label("Help Center", systemImage: "questionmark.circle")
            }

            Button {
                analytics.track(event: .contactSupportTapped, properties: nil)
                if let url = URL(string: "mailto:support@heirloom.app") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Contact Support", systemImage: "envelope")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                let deviceModel = UIDevice.current.model
                let systemVersion = UIDevice.current.systemVersion

                let subject = "Bug Report - Heirloom v\(appVersion)"
                let body = """


                ---
                Please describe the bug above this line.

                App Version: \(appVersion) (\(buildNumber))
                Device: \(deviceModel)
                iOS Version: \(systemVersion)
                """

                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                analytics.track(event: .bugReportSubmitted, properties: [
                    "app_version": appVersion,
                    "device_model": deviceModel,
                    "ios_version": systemVersion
                ])

                if let url = URL(string: "mailto:support@heirloom.app?subject=\(encodedSubject)&body=\(encodedBody)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Report a Bug", systemImage: "ladybug")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                let subject = "Feature Request - Heirloom"
                let body = """


                ---
                Please describe your feature request above this line.
                """

                let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

                analytics.track(event: .featureRequestSubmitted, properties: nil)

                if let url = URL(string: "mailto:support@heirloom.app?subject=\(encodedSubject)&body=\(encodedBody)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Request a Feature", systemImage: "lightbulb")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Link(destination: URL(string: "https://heirloom.app/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }

            Link(destination: URL(string: "https://heirloom.app/terms")!) {
                Label("Terms of Service", systemImage: "doc.text")
            }
        } header: {
            Text("Help & Support")
        } footer: {
            Text("Need help? Browse our Help Center, report bugs, or suggest new features to make Heirloom better.")
        }
    }

    // MARK: - Actions

    private func calculateStorageSize() async {
        // Calculate storage from image files
        let totalSize = await imageStorageService.calculateTotalStorageSize()

        await MainActor.run {
            storageSize = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        }
    }

    private func clearAllData() {
        let recipeCount = recipes.count

        // Show loading indicator
        isClearingData = true

        // CRITICAL: Wait for any ongoing Firebase sync to complete
        // This prevents crashes where sync tries to access deleted recipes
        Task {
            // Wait for sync to finish (with timeout of 10 seconds)
            var waitTime = 0
            while firebaseSyncService.isSyncing && waitTime < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                waitTime += 1
            }

            // CRITICAL: Force-resolve all Recipe attributes to prevent SwiftData faulting errors
            // When we delete recipes, SwiftData marks them as "faulted" (detached from context)
            // If any code later tries to access an attribute that wasn't loaded, it crashes
            // Solution: Access all optional properties BEFORE deletion to force SwiftData to load them
            let recipeIds = await MainActor.run {
                recipes.map { recipe in
                    // Force-resolve all optional attributes by accessing them
                    _ = recipe.sourceType  // This was causing the crash!
                    _ = recipe.sourceURL
                    _ = recipe.imageFileName
                    _ = recipe.ingredients
                    _ = recipe.tags
                    _ = recipe.collections

                    return recipe.id.uuidString
                }
            }

            // Delete all recipes from local database
            await MainActor.run {
                for recipe in recipes {
                    modelContext.delete(recipe)
                }

                do {
                    try modelContext.save()
                } catch {
                    toastManager.error(title: "Failed to clear data", message: error.localizedDescription)
                    isClearingData = false
                    return
                }
            }

            // CRITICAL: Give SwiftUI time to process the deletion and update all views
            // This prevents crashes where views try to access deleted (faulted) recipe objects
            // The delay ensures all @Query views have updated before we proceed
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            // Clean up images
            await imageStorageService.performCleanup()

            // CRITICAL: Wait for Firebase deletion to complete BEFORE showing success
            // This prevents recipes from coming back if user closes app too quickly
            if backendConfig.isFirebaseActive {
                await clearFirebaseData(recipeIds: recipeIds)
            }

            // CRITICAL: Clear sync timestamp at the VERY END, after all Firebase operations
            // This ensures that any internal Firebase writes during cleanup don't restore the timestamp
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
            }

            // Show success only after ALL cleanup completes (including Firebase)
            await MainActor.run {
                isClearingData = false
                toastManager.success(title: "Data cleared")
                analytics.track(event: .dataCleared, properties: [
                    "recipe_count": recipeCount
                ])
            }
        }
    }

    private func clearFirebaseData(recipeIds: [String]) async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let recipesRef = db.collection("users/\(userId)/recipes")

            Log.info("Clearing recipes from Firebase", category: .firebase, metadata: ["count": recipeIds.count, "userId": userId])

            // Delete each recipe and its subcollections using pre-captured IDs
            for recipeId in recipeIds {
                // Delete ingredients subcollection
                let ingredientsSnapshot = try await recipesRef.document(recipeId)
                    .collection("ingredients").getDocuments()
                for ingredient in ingredientsSnapshot.documents {
                    try await ingredient.reference.delete()
                }

                // Delete comments subcollection
                let commentsSnapshot = try await recipesRef.document(recipeId)
                    .collection("comments").getDocuments()
                for comment in commentsSnapshot.documents {
                    try await comment.reference.delete()
                }

                // Delete the recipe document
                try await recipesRef.document(recipeId).delete()

                // Delete image from Storage if exists
                let storage = Storage.storage()
                let imagePath = "users/\(userId)/recipes/\(recipeId)/image.jpg"
                let imageRef = storage.reference().child(imagePath)
                try? await imageRef.delete() // Don't fail if image doesn't exist
            }

            Log.info("Firebase data cleared successfully", category: .firebase, metadata: ["userId": userId])
        } catch {
            Log.error("Failed to clear Firebase data", category: .firebase, metadata: ["error": error.localizedDescription, "userId": userId])
        }
    }

    private func signOut() {
        do {
            // Sign out from Firebase
            try firebaseAuth.signOut()

            // Clear sync timestamps (but keep local recipes for offline use)
            UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")

            // Success feedback
            toastManager.success(title: "Signed out successfully")
        } catch {
            toastManager.error(
                title: "Sign out failed",
                message: error.localizedDescription
            )
        }
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
