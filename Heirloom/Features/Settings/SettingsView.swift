import SwiftUI
import SwiftData
import FirebaseFirestore
import FirebaseStorage

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var recipes: [Recipe]

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var storageSize: String = "Calculating..."

    var body: some View {
        NavigationStack {
            List {
                // AI Features Section
                aiSection

                // User Experience Section
                userExperienceSection

                // Data Management Section
                dataManagementSection

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
                        Text(AIConfiguration.shared.isConfigured(provider: .anthropic) ? "Configured" : "Not Set")
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

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if let user = FirebaseAuthService.shared.currentUser {
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
                Text("Not signed in")
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("Signing out will clear local data. Your recipes are safely stored in Firebase and will sync when you sign back in.")
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
                AnalyticsService.shared.track(event: .contactSupportTapped, properties: nil)
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

                AnalyticsService.shared.track(event: .bugReportSubmitted, properties: [
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

                AnalyticsService.shared.track(event: .featureRequestSubmitted, properties: nil)

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
        let imageService = ImageStorageService.shared
        let totalSize = await imageService.calculateTotalStorageSize()

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
                await ImageStorageService.shared.performCleanup()

                // Also clear Firebase if active
                if BackendConfig.shared.isFirebaseActive {
                    await clearFirebaseData()
                }
            }

            ToastManager.shared.success(title: "Data cleared")
            AnalyticsService.shared.track(event: .dataCleared, properties: [
                "recipe_count": recipeCount
            ])
        } catch {
            ToastManager.shared.error(title: "Failed to clear data", message: error.localizedDescription)
        }
    }

    private func clearFirebaseData() async {
        guard let userId = FirebaseAuthService.shared.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let recipesRef = db.collection("users/\(userId)/recipes")

            // Fetch all recipe documents
            let snapshot = try await recipesRef.getDocuments()

            print("🗑️ Clearing \(snapshot.documents.count) recipes from Firebase...")

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

            print("✅ Firebase data cleared successfully")
        } catch {
            print("⚠️ Failed to clear Firebase data: \(error.localizedDescription)")
        }
    }

    private func signOut() {
        do {
            // Sign out from Firebase
            try FirebaseAuthService.shared.signOut()

            // Clear local data
            for recipe in recipes {
                modelContext.delete(recipe)
            }
            try modelContext.save()

            // Clear sync timestamps
            UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")

            // Success feedback
            ToastManager.shared.success(title: "Signed out successfully")
        } catch {
            ToastManager.shared.error(
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
