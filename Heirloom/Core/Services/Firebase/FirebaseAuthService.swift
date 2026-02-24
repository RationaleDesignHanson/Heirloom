//
//  FirebaseAuthService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 3
//  Handles Firebase Authentication with Sign in with Apple and Google
//

import Foundation
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
import CryptoKit
import os.log

/// Firebase authentication service with Sign in with Apple and Google
@MainActor
class FirebaseAuthService: NSObject, ObservableObject, FirebaseAuthServiceProtocol {

    // MARK: - Dependencies

    private let configuration: FirebaseConfiguration
    private let logger: LoggingService
    private var userProfileService: FirebaseUserProfileService?

    // MARK: - Initialization

    init(configuration: FirebaseConfiguration, logger: LoggingService) {
        self.configuration = configuration
        self.logger = logger
        super.init()

        // IMPORTANT: Delay auth access until Firebase is fully configured
        // This prevents crashes when service is instantiated before Firebase.configure()
        logger.log("FirebaseAuthService initialized (auth listener setup deferred)", category: .auth, level: .info, metadata: nil)
    }

    /// Set user profile service for syncing display names
    /// Call this after initialization to enable profile syncing
    func setUserProfileService(_ service: FirebaseUserProfileService) {
        self.userProfileService = service
        logger.log("User profile service connected to auth", category: .auth, level: .info, metadata: nil)
    }

    /// Setup auth listener after Firebase is fully configured
    /// Call this from app init AFTER Firebase.configure() completes
    func setupAuthListener() {
        logger.log("Setting up Firebase auth listener", category: .auth, level: .info, metadata: nil)

        // Check current auth state immediately (before listener fires)
        if let user = configuration.auth.currentUser {
            currentUser = user
            isAuthenticated = true
            hasCheckedInitialAuthState = true
            logger.log("Restored auth session: \(user.uid)", category: .auth, level: .info, metadata: nil)
        }

        // Listen for auth state changes
        _ = configuration.auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                // Detect if a DIFFERENT user is signing in (user switch scenario)
                let previousUserId = self.currentUser?.uid
                let newUserId = user?.uid
                let isDifferentUser = previousUserId != nil && newUserId != nil && previousUserId != newUserId

                // Prevent redundant updates if auth state hasn't changed
                if self.hasCheckedInitialAuthState &&
                   previousUserId == newUserId {
                    return
                }

                // CRITICAL: If a different user is signing in, clear previous user's data
                if isDifferentUser {
                    self.logger.log("⚠️ Different user signing in - clearing previous user's data", category: .auth, level: .warning, metadata: [
                        "previousUser": previousUserId ?? "unknown",
                        "newUser": newUserId ?? "unknown"
                    ])

                    // Clear previous user's data to prevent privacy leak
                    await self.clearAllUserData()
                }

                self.currentUser = user
                self.isAuthenticated = user != nil
                self.hasCheckedInitialAuthState = true

                if let user = user {
                    self.logger.log("User signed in: \(user.uid)", category: .auth, level: .info, metadata: nil)

                    // NOTE: Do NOT sync profile here on sign-in!
                    // For returning users, local state (hasCompletedOnboarding, selectedThemeIds) is empty
                    // after sign-out. Syncing now would overwrite Firebase with empty data.
                    // Profile sync happens:
                    // 1. After onboarding completes (OnboardingContainerView.finalizeOnboarding)
                    // 2. When user manually updates their profile
                    // Returning user handling is in HeirloomApp.swift (checkForExistingUserData)
                } else {
                    self.logger.log("User signed out", category: .auth, level: .info, metadata: nil)

                    // Only clear user data if there WAS a previous user (actual sign out)
                    // Don't clear on initial app launch when user is nil from the start
                    if previousUserId != nil {
                        self.logger.log("Previous user existed, clearing data on sign out", category: .auth, level: .info, metadata: [
                            "previousUser": previousUserId ?? "unknown"
                        ])
                        await self.clearAllUserData()
                    } else {
                        self.logger.log("No previous user, skipping data clear (initial app state)", category: .auth, level: .info, metadata: nil)
                    }
                }
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var authError: Error?
    @Published private(set) var isAuthenticating = false

    // Track if we've checked auth state to prevent multiple checks
    private var hasCheckedInitialAuthState = false

    // MARK: - Protocol Properties

    var currentUserId: String? {
        currentUser?.uid
    }

    var currentUserEmail: String? {
        currentUser?.email
    }

    /// Check if user signed in with Apple
    var isAppleUser: Bool {
        currentUser?.providerData.contains { $0.providerID == "apple.com" } ?? false
    }

    /// Check if user signed in with Google
    var isGoogleUser: Bool {
        currentUser?.providerData.contains { $0.providerID == "google.com" } ?? false
    }

    /// Check if user signed in with email/password
    var isEmailUser: Bool {
        currentUser?.providerData.contains { $0.providerID == "password" } ?? false
    }

    // MARK: - Sign in with Apple State

    // Unhashed nonce for Sign in with Apple
    private var currentNonce: String?

    // Continuation for async/await Apple sign-in
    private var appleSignInContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Authentication

    /// Sign in with Apple
    func signInWithApple() async throws {
        logger.log("Starting Sign in with Apple", category: .auth, level: .info, metadata: nil)

        isAuthenticating = true
        defer { isAuthenticating = false }

        // Generate nonce for security
        let nonce = randomNonceString()
        currentNonce = nonce

        // Create Apple Sign In request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        // Use continuation to wait for delegate callback
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.appleSignInContinuation = continuation

            // Present authorization UI
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }

    /// Sign in with Google
    func signInWithGoogle() async throws {
        logger.log("Starting Sign in with Google", category: .auth, level: .info, metadata: nil)

        isAuthenticating = true
        defer { isAuthenticating = false }

        // Get the client ID from Firebase
        guard let clientID = configuration.auth.app?.options.clientID else {
            let error = AuthError.invalidCredential
            logger.log("Missing Google client ID", category: .auth, level: .error, metadata: nil)
            authError = error
            throw error
        }

        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            let error = AuthError.signInFailed(NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"]))
            logger.log("No root view controller found for Google sign in", category: .auth, level: .error, metadata: nil)
            authError = error
            throw error
        }

        do {
            // Present Google Sign In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                let error = AuthError.invalidCredential
                logger.log("Missing Google ID token", category: .auth, level: .error, metadata: nil)
                authError = error
                throw error
            }

            let accessToken = result.user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase
            logger.log("Authenticating with Firebase using Google credential", category: .auth, level: .info, metadata: nil)
            let authResult = try await configuration.auth.signIn(with: credential)

            logger.log("Successfully signed in with Google: \(authResult.user.uid)", category: .auth, level: .info, metadata: nil)

            authError = nil

        } catch {
            logger.log("Google sign in failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)

            // Check if user cancelled
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                logger.log("User cancelled Google sign in", category: .auth, level: .info, metadata: nil)
                return
            }

            authError = error
            throw error
        }
    }

    /// Sign in with email and password
    func signInWithEmail(email: String, password: String) async throws {
        logger.log("Starting email/password sign in", category: .auth, level: .info, metadata: nil)

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            // Add timeout protection (30 seconds for auth operations)
            let authResult = try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) { [self] in
                try await self.configuration.auth.signIn(withEmail: email, password: password)
            }
            logger.log("Successfully signed in with email: \(authResult.user.uid)", category: .auth, level: .info, metadata: nil)
            authError = nil
        } catch {
            logger.log("Email sign in failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            authError = error
            throw error
        }
    }

    /// Create account with email and password
    func createAccountWithEmail(email: String, password: String) async throws {
        logger.log("Creating account with email", category: .auth, level: .info, metadata: nil)

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            // Add timeout protection (30 seconds for auth operations)
            let authResult = try await TaskTimeout.withTimeout(seconds: TaskTimeout.firebaseStandard) { [self] in
                try await self.configuration.auth.createUser(withEmail: email, password: password)
            }
            logger.log("Successfully created account: \(authResult.user.uid)", category: .auth, level: .info, metadata: nil)
            authError = nil
        } catch {
            logger.log("Account creation failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            authError = error
            throw error
        }
    }

    /// Send password reset email
    func sendPasswordReset(email: String) async throws {
        logger.log("Sending password reset email", category: .auth, level: .info, metadata: nil)

        do {
            try await configuration.auth.sendPasswordReset(withEmail: email)
            logger.log("Password reset email sent successfully", category: .auth, level: .info, metadata: nil)
        } catch {
            logger.log("Password reset failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            throw error
        }
    }

    /// Re-authenticate user with email and password (required before sensitive operations like delete)
    func reauthenticateWithEmail(password: String) async throws {
        guard let user = currentUser, let email = user.email else {
            throw AuthError.notAuthenticated
        }

        logger.log("Re-authenticating user with email", category: .auth, level: .info, metadata: nil)

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)
            logger.log("Re-authentication successful", category: .auth, level: .info, metadata: nil)
        } catch {
            logger.log("Re-authentication failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            throw error
        }
    }

    /// Sign out
    func signOut() throws {
        logger.log("Signing out user", category: .auth, level: .info, metadata: nil)

        do {
            try configuration.auth.signOut()

            // Also sign out from Google
            GIDSignIn.sharedInstance.signOut()

            logger.log("Signed out successfully", category: .auth, level: .info, metadata: nil)

        } catch {
            logger.log("Sign out failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            throw error
        }
    }

    /// Delete user account
    func deleteAccount() async throws {
        logger.log("Attempting to delete user account", category: .auth, level: .info, metadata: nil)

        guard let user = currentUser else {
            let error = AuthError.notAuthenticated
            logger.log("Cannot delete account: user not authenticated", category: .auth, level: .error, metadata: nil)
            throw error
        }

        do {
            try await user.delete()

            // Also sign out from Google
            GIDSignIn.sharedInstance.signOut()

            logger.log("Account deleted successfully", category: .auth, level: .info, metadata: nil)

        } catch {
            logger.log("Account deletion failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
            throw error
        }
    }

    // MARK: - Helpers

    /// Generate random nonce for Sign in with Apple
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    /// SHA256 hash of input string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }

    /// Clear all user data from local storage
    /// Called when user signs out or when a different user signs in
    ///
    /// CRITICAL PRIVACY PROTECTION:
    /// This method is called in two scenarios to prevent data leakage:
    /// 1. When a DIFFERENT user signs in on the same device (user switch)
    /// 2. After a user signs out (auth state listener detects nil user)
    ///
    /// IMPLEMENTATION STRATEGY:
    /// We use NotificationCenter because FirebaseAuthService doesn't have direct
    /// access to ModelContext (which is needed to delete SwiftData objects).
    /// - FirebaseAuthService posts "ClearAllUserDataNotification"
    /// - RootView (in HeirloomApp.swift) listens for this notification
    /// - RootView has access to ModelContext and performs the actual deletion
    ///
    /// IMPORTANT: Sign out does NOT clear data immediately to prevent data loss
    /// if Firebase sync hasn't completed. Data is only cleared after auth state
    /// confirms the user is signed out OR when a different user signs in.
    @MainActor
    private func clearAllUserData() async {
        // Skip during reset flow — the reset handles its own data clearing
        // and carefully preserves demo seed data. The auth state listener
        // fires asynchronously after signOut() in a Task { @MainActor in },
        // which runs after the reset's defer clears isResetInProgress.
        // suppressDataClear stays true long enough for this check.
        if ScreenRecordingResetService.shared.suppressDataClear {
            logger.log("Skipping clearAllUserData — reset flow handles its own cleanup", category: .auth, level: .info, metadata: nil)
            return
        }

        logger.log("🧹 Clearing all local user data", category: .auth, level: .info, metadata: nil)

        // Clear sync-related UserDefaults
        UserDefaults.standard.removeObject(forKey: "firebase_lastSyncDate")
        UserDefaults.standard.removeObject(forKey: "lastSyncTimestamp")

        // Clear onboarding state — critical to prevent cross-user pollution
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "has_completed_onboarding") // Legacy key

        // Clear subscription/account state — critical for test accounts
        // Each user should start fresh without sandbox subscription from previous user
        UserDefaults.standard.removeObject(forKey: "subscription_status")
        UserDefaults.standard.removeObject(forKey: "trial_expiry_date")
        UserDefaults.standard.removeObject(forKey: "subscription_expiry_date")
        UserDefaults.standard.removeObject(forKey: "last_status_refresh")
        UserDefaults.standard.removeObject(forKey: "cached_product_id")
        UserDefaults.standard.removeObject(forKey: "first_launch_date")
        UserDefaults.standard.removeObject(forKey: "demo_account_configured_for_review")
        UserDefaults.standard.removeObject(forKey: "tester_account_configured_for_review")
        UserDefaults.standard.removeObject(forKey: "demo_account_purchased_this_session")
        logger.log("✅ Cleared subscription and account state", category: .auth, level: .info, metadata: nil)

        // NOTE: Theme unlock state is NOT cleared on sign-out
        // Theme state (selected_theme_ids, trial dates) is managed per-user through:
        // 1. Onboarding flow for new users
        // 2. configureForDemoAccount() for demo@
        // 3. configureForDeletionTest() for deletetest@
        // Clearing theme state here would break multi-account usage on same device

        // Post notification for app to clear SwiftData
        // (We can't access ModelContext directly from this service)
        NotificationCenter.default.post(
            name: NSNotification.Name("ClearAllUserDataNotification"),
            object: nil
        )

        // Post notification for SubscriptionManager to reset in-memory state
        NotificationCenter.default.post(
            name: NSNotification.Name("ResetSubscriptionStateNotification"),
            object: nil
        )

        logger.log("✅ Local user data clear requested", category: .auth, level: .info, metadata: nil)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension FirebaseAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                logger.log("Invalid credential type for Apple sign in", category: .auth, level: .error, metadata: nil)
                let error = AuthError.invalidCredential
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }

            guard let nonce = currentNonce else {
                logger.log("Invalid state: login callback received but no login request was sent", category: .auth, level: .error, metadata: nil)
                let error = AuthError.invalidCredential
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                logger.log("Unable to fetch Apple identity token", category: .auth, level: .error, metadata: nil)
                let error = AuthError.invalidCredential
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                logger.log("Unable to serialize Apple token string", category: .auth, level: .error, metadata: nil)
                let error = AuthError.invalidCredential
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }

            // Create Firebase credential
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce
            )

            do {
                // Sign in to Firebase
                logger.log("Authenticating with Firebase using Apple credential", category: .auth, level: .info, metadata: nil)
                let authResult = try await configuration.auth.signIn(with: credential)

                logger.log("Successfully signed in with Apple: \(authResult.user.uid)", category: .auth, level: .info, metadata: nil)

                // Update user profile if this is first sign in
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")

                    if !displayName.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        try await changeRequest.commitChanges()

                        logger.log("Updated user profile: \(displayName)", category: .auth, level: .info, metadata: nil)
                    }
                }

                authError = nil

                // Resume continuation with success
                appleSignInContinuation?.resume()
                appleSignInContinuation = nil

            } catch {
                logger.log("Apple authentication failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)
                authError = error
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            logger.log("Sign in with Apple failed: \(error.localizedDescription)", category: .auth, level: .error, metadata: nil)

            // Check if user cancelled - still throw so caller knows not to proceed
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                logger.log("User cancelled Sign in with Apple", category: .auth, level: .info, metadata: nil)
                // Don't set authError for cancellation (not a real error to show)
                appleSignInContinuation?.resume(throwing: error)
                appleSignInContinuation = nil
                return
            }

            authError = error
            appleSignInContinuation?.resume(throwing: error)
            appleSignInContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension FirebaseAuthService: ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found for Sign in with Apple presentation")
        }
        return window
    }
}

// MARK: - Errors

extension FirebaseAuthService {
    enum AuthError: LocalizedError {
        case notAuthenticated
        case invalidCredential
        case signInFailed(Error)
        case signOutFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User is not authenticated"
            case .invalidCredential:
                return "Invalid authentication credential"
            case .signInFailed(let error):
                return "Sign in failed: \(error.localizedDescription)"
            case .signOutFailed(let error):
                return "Sign out failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Global Convenience

extension FirebaseAuthService {
    /// Global accessor that resolves from ServiceContainer for proper DI
    /// Maintains backward compatibility with existing .shared usage
    /// Note: Safe to use from any context - ServiceContainer is thread-safe
    nonisolated(unsafe) static var shared: FirebaseAuthService {
        MainActor.assumeIsolated {
            ServiceContainer.shared.resolve(FirebaseAuthService.self)
        }
    }
}
