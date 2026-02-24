import SwiftUI
import SwiftData
import StoreKit
import FirebaseFirestore
import FirebaseStorage
import FirebaseCrashlytics

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.firebaseAuth) private var firebaseAuth
    @EnvironmentObject private var tabCoordinator: TabNavigationCoordinator
    @Query private var recipes: [Recipe]
    @Query private var allUserCredits: [UserCredits]

    /// Current user's credits (first matching current user ID)
    private var userCredits: UserCredits? {
        guard let userId = firebaseAuth.currentUserId else { return nil }
        return allUserCredits.first { $0.userId == userId }
    }

    // User-created recipes only (excludes theme/discovery recipes)
    private var userRecipes: [Recipe] {
        recipes.filter { !$0.isThemeRecipe }
    }

    // Services resolved at view initialization - prevents lazy evaluation crashes
    @State private var imageStorageService = ServiceContainer.shared.resolve(ImageStorageService.self)
    @State private var toastManager = ServiceContainer.shared.resolve(ToastManager.self)
    @State private var analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
    @State private var backendConfig = ServiceContainer.shared.resolve(BackendConfig.self)
    @State private var aiConfig = ServiceContainer.shared.resolve(AIConfiguration.self)
    @State private var firebaseSyncService = ServiceContainer.shared.resolve(FirebaseSyncService.self)
    @State private var subscriptionManager = ServiceContainer.shared.resolve(SubscriptionManager.self)
    @State private var storeManager = ServiceContainer.shared.resolve(StoreManager.self)

    // Units configuration for measurement system
    @ObservedObject private var unitsConfig: UnitsConfiguration = ServiceContainer.shared.resolve(UnitsConfiguration.self)

    // Visual style configuration for AI-generated images
    @ObservedObject private var visualStyleConfig: VisualStyleConfiguration = ServiceContainer.shared.resolve(VisualStyleConfiguration.self)

    @State private var showClearDataConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var storageSize: String = "Calculating..."
    @State private var authStateChanged = false // Force view updates when auth state changes
    @State private var isClearingData = false // Show loading indicator while clearing
    @State private var showDowngradeAlert = false

    // Developer section password protection
    @State private var showDeveloperSection = false
    @State private var developerPassword = ""
    @State private var showDeveloperPasswordAlert = false
    @State private var showManagePlan = false

    var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                subscriptionSection

                // Account Section (moved UP - common user need)
                accountSection

                // User Experience Section (moved UP - user preferences)
                userExperienceSection

                // Data Management Section
                dataManagementSection

                // App Info Section
                appInfoSection

                // Support Section
                supportSection

                // Developer Section (password protected)
                if showDeveloperSection {
                    developerSection
                } else {
                    developerAccessSection
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await calculateStorageSize()
                // NOTE: Subscription refresh moved to ManagePlanView to avoid
                // state update conflicts during sheet presentation
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
                Text("This will permanently delete all \(userRecipes.count) user recipes and \(recipes.count - userRecipes.count) discovery recipes. This cannot be undone.")
            }
            .alert(
                "Switch to Monthly Plan",
                isPresented: $showDowngradeAlert
            ) {
                Button("Cancel", role: .cancel) {}
                Button("Continue") {
                    openManageSubscription()
                }
            } message: {
                Text("To switch from Annual to Monthly, you'll need to manage your subscription in iOS Settings. Your Annual subscription will remain active until it expires, then you can subscribe to Monthly.")
            }
            .sheet(isPresented: $showSignIn) {
                FirebaseSignInView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showManagePlan) {
                ManagePlanView()
            }
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
                                .foregroundStyle(HeirloomColors.buttonTextLight)
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

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            // Status row with plan info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionStatusText)
                        .font(HeirloomFonts.body)
                        .foregroundStyle(subscriptionStatusColor)

                    if let dateText = subscriptionDateText {
                        Text("\(subscriptionDateLabel): \(dateText)")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
                Spacer()

                // Plan badge
                if subscriptionManager.isPremium {
                    Text(subscriptionManager.currentPlanName ?? "Premium")
                        .font(HeirloomFonts.caption1.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(subscriptionManager.status == .lifetime ? HeirloomColors.tomato : HeirloomColors.familyGreen)
                        .cornerRadius(12)
                }
            }

            // Trial countdown (for free users)
            if !subscriptionManager.isPremium, subscriptionManager.isInTrial, let daysRemaining = subscriptionManager.daysRemaining {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.orange)

                    Text("\(daysRemaining) day\(daysRemaining == 1 ? "" : "s") left in trial")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.orange)

                    Spacer()
                }
                .padding(HeirloomSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange.opacity(0.1))
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            // Manage Plan button - opens our custom view
            Button {
                showManagePlan = true
            } label: {
                HStack {
                    Label(
                        subscriptionManager.isPremium ? "Manage Plan" : "View Plans & Upgrade",
                        systemImage: subscriptionManager.isPremium ? "gearshape" : "crown.fill"
                    )
                    .foregroundStyle(subscriptionManager.isPremium ? .primary : HeirloomColors.tomato)

                    Spacer()

                    if !subscriptionManager.isPremium {
                        Text("Upgrade")
                            .font(HeirloomFonts.caption1.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(HeirloomColors.tomato)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        } header: {
            Text("Subscription")
        } footer: {
            Text(subscriptionFooterText)
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            LabeledContent("Recipes", value: "\(userRecipes.count)")
            LabeledContent("Storage Used", value: storageSize)

            // Privacy & Data (includes export and account deletion for Apple compliance)
            NavigationLink {
                PrivacySettingsView()
            } label: {
                Label("Privacy & Data", systemImage: "hand.raised")
            }
        } header: {
            Text("Data Management")
        } footer: {
            Text("Your recipes are always yours, even without a subscription.")
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Force view dependency on authStateChanged to trigger re-renders
            let _ = authStateChanged

            if firebaseAuth.currentUser != nil {
                // Profile row with avatar and credits badge
                NavigationLink {
                    ProfileView()
                } label: {
                    SettingsProfileRow()
                }

                // Sign Out button
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
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
        } header: {
            Text("Account")
        } footer: {
            if firebaseAuth.currentUser != nil {
                Text("Your recipes are safely stored in Firebase and will sync across all your devices.")
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
                    .onAppear {
                        markWhatsNewAsViewed()
                    }
            } label: {
                HStack {
                    Label("What's New", systemImage: "sparkles")
                    Spacer()
                    if showWhatsNewBadge {
                        Text("NEW")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(HeirloomColors.tomato)
                            )
                    }
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
            // AI Features (moved from main settings for power users)
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

            NavigationLink {
                DeveloperSettingsView()
            } label: {
                Label("Developer Tools", systemImage: "hammer.fill")
            }

            Button(role: .destructive) {
                showClearDataConfirmation = true
            } label: {
                Label("Clear Local Data", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Developer")
        } footer: {
            Text("Build: \(BuildChannel.current.displayName)")
        }
    }

    // MARK: - Developer Access Section (Password Protected)

    private var developerAccessSection: some View {
        Section {
            Button {
                showDeveloperPasswordAlert = true
            } label: {
                Label("Developer Access", systemImage: "lock.fill")
            }
        } footer: {
            Text("Build: \(BuildChannel.current.displayName)")
        }
        .sheet(isPresented: $showDeveloperPasswordAlert) {
            DeveloperPasswordSheet(
                isPresented: $showDeveloperPasswordAlert,
                onUnlock: { showDeveloperSection = true }
            )
            .presentationDetents([.height(200)])
        }
    }
}

// MARK: - Developer Password Sheet

private struct DeveloperPasswordSheet: View {
    @Binding var isPresented: Bool
    let onUnlock: () -> Void

    @State private var password = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Developer Access")
                .font(HeirloomFonts.title3)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { tryUnlock() }
                .padding(.horizontal)

            HStack(spacing: 16) {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundStyle(.secondary)

                Button("Unlock") {
                    tryUnlock()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear { isFocused = true }
    }

    private func tryUnlock() {
        if password == "18" {
            onUnlock()
        }
        isPresented = false
    }
}

// MARK: - SettingsView Extensions

extension SettingsView {
    // MARK: - User Experience Section

    var userExperienceSection: some View {
        Section {
            // Using LabeledContent wrapper fixes menu anchor alignment
            LabeledContent("Measurement System") {
                Picker("", selection: $unitsConfig.preferredSystem) {
                    ForEach(UnitSystem.allCases) { system in
                        Text(system.displayName).tag(system)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Visual Style for AI-generated images
            NavigationLink {
                VisualStylePickerView(styleConfig: visualStyleConfig)
            } label: {
                HStack {
                    Label("Visual Style", systemImage: visualStyleConfig.selectedStyle.iconName)
                    Spacer()
                    Text(visualStyleConfig.selectedStyle.displayName)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("User Experience")
        } footer: {
            Text("Choose your preferred measurement system and visual style for AI-generated collection images.")
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
                if let url = URL(string: "https://discord.gg/nZeX7cfBqj") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Contact Support", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                analytics.track(event: .bugReportSubmitted, properties: nil)
                if let url = URL(string: "https://discord.gg/JXDPWp3sCy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Report a Bug", systemImage: "ladybug")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Button {
                analytics.track(event: .featureRequestSubmitted, properties: nil)
                if let url = URL(string: "https://discord.gg/xVUCgT4c4W") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Request a Feature", systemImage: "lightbulb")
                    .foregroundStyle(HeirloomColors.primaryText)
            }

        } header: {
            Text("Help & Support")
        } footer: {
            Text("Need help? Browse our Help Center, report bugs, or suggest new features.")
        }
    }

    // MARK: - Subscription Helpers

    private var subscriptionStatusText: String {
        // Demo account: always show "Expired" for App Store Review
        if subscriptionManager.isDemoAccountConfigured && !subscriptionManager.isPremium {
            return "Expired"
        }

        // Use statusDisplayText for cancelled subscription status
        // (shows "Cancelled - X days left on Monthly/Annual")
        if subscriptionManager.status.isSubscription && !subscriptionManager.willRenew {
            return subscriptionManager.statusDisplayText
        }

        switch subscriptionManager.status {
        case .none:
            return "Free"
        case .trial:
            if let days = subscriptionManager.daysRemaining {
                return "Premium Trial • \(days) day\(days == 1 ? "" : "s") remaining"
            }
            return "Premium Trial"
        case .monthly:
            return "Premium (Monthly)"
        case .annual:
            return "Premium (Annual)"
        case .lifetime:
            return "Premium (Lifetime)"
        case .expired:
            return "Subscription Expired"
        case .grace:
            return "Payment Issue"
        }
    }

    private var subscriptionStatusColor: Color {
        subscriptionManager.isPremium ? HeirloomColors.tomato : HeirloomColors.secondaryText
    }

    private var subscriptionDateText: String? {
        if let expiryDate = subscriptionManager.subscriptionExpiryDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy" // Always show year explicitly
            return formatter.string(from: expiryDate)
        } else if let trialExpiry = subscriptionManager.trialExpiryDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy" // Always show year explicitly
            return formatter.string(from: trialExpiry)
        }
        return nil
    }

    private var subscriptionDateLabel: String {
        if subscriptionManager.status == .trial {
            return "Trial Ends"
        } else if subscriptionManager.status == .expired {
            return "Ended"
        } else if !subscriptionManager.willRenew {
            return "Expires"
        } else {
            return "Renews"
        }
    }

    private var subscriptionFooterText: String {
        if subscriptionManager.isPremium {
            return "Manage your subscription or restore purchases on another device."
        } else {
            return "Upgrade to unlock URL import, cookbook scanning, and device sync."
        }
    }

    // MARK: - Actions

    private func openManageSubscription() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            toastManager.error(title: "Could not open", message: "Unable to find window scene")
            return
        }

        Task {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene)
                analytics.track(event: .manageSubscriptionOpened)

                // Refresh subscription status after returning from App Store
                // User may have cancelled, renewed, or changed their subscription
                await subscriptionManager.refreshStatus(force: true)
            } catch {
                // Log the actual error for debugging
                await MainActor.run {
                    Log.error(
                        "Failed to open subscription management",
                        category: .store,
                        error: error,
                        metadata: ["error_description": error.localizedDescription]
                    )

                    // Show helpful error message
                    if error.localizedDescription.contains("account") || error.localizedDescription.contains("sign in") {
                        toastManager.error(
                            title: "Apple ID Required",
                            message: "Please sign in to your Apple account in Settings to manage subscriptions"
                        )
                    } else {
                        toastManager.error(
                            title: "Could not open",
                            message: "Unable to open subscription management. Please try again or manage via the App Store."
                        )
                    }
                }
            }
        }
    }

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
            // CRITICAL: Give any ongoing recipe imports time to complete or cancel
            // This prevents crashes where imports try to access deleted ingredients
            // during recipe save operations (web import, video import, etc.)
            Log.info("Waiting for ongoing operations before clearing data", category: .storage)
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

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
                // Delete all recipes
                for recipe in recipes {
                    modelContext.delete(recipe)
                }

                // Delete all collections (with tombstones)
                do {
                    let collectionDescriptor = FetchDescriptor<RecipeCollection>()
                    let collections = try modelContext.fetch(collectionDescriptor)

                    // Create tombstones BEFORE deleting
                    for collection in collections {
                        let tombstone = DeletedCollectionRecord(collectionId: collection.id)
                        modelContext.insert(tombstone)
                        Log.info("Created deletion tombstone for clear all data", category: .collections, metadata: [
                            "collectionId": collection.id.uuidString
                        ])
                    }

                    // Now delete the collections
                    for collection in collections {
                        modelContext.delete(collection)
                    }
                } catch {
                    Log.error("Failed to fetch collections for deletion", category: .general, metadata: ["error": error.localizedDescription])
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

            // Clean up images - pass empty set since all recipes are deleted
            _ = await imageStorageService.cleanupOrphanedImages(validImageFileNames: [])

            // CRITICAL: Wait for Firebase deletion to complete BEFORE showing success
            // This prevents recipes and collections from coming back if user closes app too quickly
            if backendConfig.isFirebaseActive {
                await clearFirebaseData(recipeIds: recipeIds)
                await clearFirebaseCollections()
                // Also delete any orphaned Firebase recipes not in the local ID list
                // (e.g., recipes from another device that were never properly linked locally)
                await clearAllFirebaseRecipes()
            }

            // CRITICAL: Clear sync timestamp at the VERY END, after all Firebase operations
            // This ensures that any internal Firebase writes during cleanup don't restore the timestamp
            await MainActor.run {
                UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
                UserDefaults.standard.removeObject(forKey: "OnboardingRecipeSeeded")
                Log.info("Cleared onboarding flag", category: .storage)
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

    private func clearFirebaseCollections() async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let collectionsRef = db.collection("users/\(userId)/collections")

            Log.info("Clearing collections from Firebase", category: .firebase, metadata: ["userId": userId])

            // Fetch all collections
            let collectionsSnapshot = try await collectionsRef.getDocuments()

            // Delete each collection document
            for collectionDoc in collectionsSnapshot.documents {
                try await collectionDoc.reference.delete()
            }

            Log.info("Firebase collections cleared successfully", category: .firebase, metadata: ["count": collectionsSnapshot.documents.count, "userId": userId])
        } catch {
            Log.error("Failed to clear Firebase collections", category: .firebase, metadata: ["error": error.localizedDescription, "userId": userId])
        }
    }

    /// Delete ALL recipe documents from Firebase, including orphaned ones not in local database
    private func clearAllFirebaseRecipes() async {
        guard let userId = firebaseAuth.currentUser?.uid else { return }

        do {
            let db = Firestore.firestore()
            let recipesRef = db.collection("users/\(userId)/recipes")
            let snapshot = try await recipesRef.getDocuments()

            guard !snapshot.documents.isEmpty else { return }

            Log.info("Clearing all Firebase recipes (including orphaned)", category: .firebase, metadata: [
                "count": snapshot.documents.count
            ])

            for doc in snapshot.documents {
                // Delete subcollections first
                let ingredientsSnapshot = try await doc.reference.collection("ingredients").getDocuments()
                for ingredient in ingredientsSnapshot.documents {
                    try await ingredient.reference.delete()
                }

                let commentsSnapshot = try await doc.reference.collection("comments").getDocuments()
                for comment in commentsSnapshot.documents {
                    try await comment.reference.delete()
                }

                // Delete the recipe document
                try await doc.reference.delete()
            }

            Log.info("All Firebase recipes cleared", category: .firebase, metadata: [
                "count": snapshot.documents.count
            ])
        } catch {
            Log.error("Failed to clear all Firebase recipes", category: .firebase, metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    private func signOut() {
        do {
            // Sign out from Firebase
            try firebaseAuth.signOut()

            // Note: We intentionally DO NOT clear local data here to prevent data loss
            // If we cleared data before sync completed, user recipes could be lost forever
            //
            // Instead, data clearing happens in FirebaseAuthService when:
            // 1. A DIFFERENT user signs in (user switch scenario)
            // 2. After sign out is complete (in the auth state listener)
            //
            // This ensures data is safely synced to Firebase before being removed

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

    private var showWhatsNewBadge: Bool {
        let lastViewedVersion = UserDefaults.standard.string(forKey: "last_viewed_whats_new_version")
        let currentVersion = appVersion
        return lastViewedVersion != currentVersion
    }

    private func markWhatsNewAsViewed() {
        UserDefaults.standard.set(appVersion, forKey: "last_viewed_whats_new_version")
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
