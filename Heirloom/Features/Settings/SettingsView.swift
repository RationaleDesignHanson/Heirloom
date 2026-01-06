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

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var storageSize: String = "Calculating..."
    @State private var showHeritageCleanup = false

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
            if let user = firebaseAuth.currentUser {
                LabeledContent("Signed in as", value: user.email ?? "Unknown")
                    .font(HeirloomFonts.caption1)

                LabeledContent("User ID", value: String(user.uid.prefix(8)) + "...")
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

        // Delete all recipes (cascade deletes ingredients)
        for recipe in recipes {
            modelContext.delete(recipe)
        }

        do {
            try modelContext.save()

            // Clean up images
            Task {
                await imageStorageService.performCleanup()

                // Also clear Firebase if active
                if backendConfig.isFirebaseActive {
                    await clearFirebaseData()
                }
            }

            toastManager.success(title: "Data cleared")
            analytics.track(event: .dataCleared, properties: [
                "recipe_count": recipeCount
            ])
        } catch {
            toastManager.error(title: "Failed to clear data", message: error.localizedDescription)
        }
    }

    private func clearFirebaseData() async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let recipesRef = db.collection("users/\(userId)/recipes")

            // Fetch all recipe documents
            let snapshot = try await recipesRef.getDocuments()

            Log.info("Clearing recipes from Firebase", category: .firebase, metadata: ["count": snapshot.documents.count, "userId": userId])

            // Delete each recipe and its subcollections
            for document in snapshot.documents {
                // Delete ingredients subcollection
                let ingredientsSnapshot = try await recipesRef.document(document.documentID)
                    .collection("ingredients").getDocuments()
                for ingredient in ingredientsSnapshot.documents {
                    try await ingredient.reference.delete()
                }

                // Delete comments subcollection
                let commentsSnapshot = try await recipesRef.document(document.documentID)
                    .collection("comments").getDocuments()
                for comment in commentsSnapshot.documents {
                    try await comment.reference.delete()
                }

                // Delete the recipe document
                try await document.reference.delete()

                // Delete image from Storage if exists
                let storage = Storage.storage()
                let imagePath = "users/\(userId)/recipes/\(document.documentID)/image.jpg"
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

            // Clear local data
            for recipe in recipes {
                modelContext.delete(recipe)
            }
            try modelContext.save()

            // Clear sync timestamps
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
