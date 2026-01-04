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
class FirebaseAuthService: NSObject, ObservableObject {

    // Device-visible logging
    private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "FirebaseAuth")

    // MARK: - Singleton

    static let shared = FirebaseAuthService()

    private override init() {
        super.init()

        // Check current auth state immediately (before listener fires)
        if let user = Auth.auth().currentUser {
            currentUser = user
            isAuthenticated = true
            hasCheckedInitialAuthState = true
            DeviceLogger.shared.log("🔐 [Firebase] Restored session: \(user.uid)")
            logger.info("🔐 [Firebase] Restored session: \(user.uid)")
        }

        // Listen for auth state changes
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self = self else { return }

                // Prevent redundant updates if auth state hasn't changed
                if self.hasCheckedInitialAuthState &&
                   self.currentUser?.uid == user?.uid {
                    return
                }

                self.currentUser = user
                self.isAuthenticated = user != nil
                self.hasCheckedInitialAuthState = true

                if let user = user {
                    DeviceLogger.shared.log("🔐 [Firebase] User signed in: \(user.uid)")
                    self.logger.info("🔐 [Firebase] User signed in: \(user.uid)")
                } else {
                    DeviceLogger.shared.log("🔐 [Firebase] User signed out")
                    self.logger.info("🔐 [Firebase] User signed out")
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

    // MARK: - Sign in with Apple State

    // Unhashed nonce for Sign in with Apple
    private var currentNonce: String?

    // MARK: - Authentication

    /// Sign in with Apple
    func signInWithApple() async throws {
        DeviceLogger.shared.log("🔐 [Firebase] Starting Sign in with Apple...")
        logger.info("🔐 [Firebase] Starting Sign in with Apple...")
        Log.info("Starting Sign in with Apple", category: .firebase)

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

        // Present authorization UI
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()

        // Note: Completion handled in delegate methods
    }

    /// Sign in with Google
    func signInWithGoogle() async throws {
        DeviceLogger.shared.log("🔐 [Firebase] Starting Sign in with Google...")
        logger.info("🔐 [Firebase] Starting Sign in with Google...")
        Log.info("Starting Sign in with Google", category: .firebase)

        isAuthenticating = true
        defer { isAuthenticating = false }

        // Get the client ID from Firebase
        guard let clientID = Auth.auth().app?.options.clientID else {
            let error = AuthError.invalidCredential
            DeviceLogger.shared.log("❌ [Firebase] Missing Google client ID", level: .error)
            logger.error("❌ [Firebase] Missing Google client ID")
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
            DeviceLogger.shared.log("❌ [Firebase] No root view controller found", level: .error)
            authError = error
            throw error
        }

        do {
            // Present Google Sign In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                let error = AuthError.invalidCredential
                DeviceLogger.shared.log("❌ [Firebase] Missing Google ID token", level: .error)
                logger.error("❌ [Firebase] Missing Google ID token")
                authError = error
                throw error
            }

            let accessToken = result.user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase
            DeviceLogger.shared.log("🔐 [Firebase] Authenticating with Firebase...")
            let authResult = try await Auth.auth().signIn(with: credential)

            DeviceLogger.shared.log("✅ [Firebase] Successfully signed in with Google: \(authResult.user.uid)")
            logger.info("✅ [Firebase] Successfully signed in with Google: \(authResult.user.uid)")
            Log.info("Successfully signed in with Google", category: .firebase, metadata: ["uid": authResult.user.uid])

            authError = nil

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Google sign in failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Google sign in failed: \(error.localizedDescription)")
            Log.error("Google sign in failed", category: .firebase, metadata: ["error": error.localizedDescription])

            // Check if user cancelled
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                DeviceLogger.shared.log("ℹ️ [Firebase] User cancelled Sign in with Google")
                Log.info("User cancelled Sign in with Google", category: .firebase)
                return
            }

            authError = error
            throw error
        }
    }

    /// Sign out
    func signOut() throws {
        DeviceLogger.shared.log("🔐 [Firebase] Signing out...")
        logger.info("🔐 [Firebase] Signing out...")
        Log.info("Signing out from Firebase", category: .firebase)

        do {
            try Auth.auth().signOut()

            // Also sign out from Google
            GIDSignIn.sharedInstance.signOut()

            DeviceLogger.shared.log("✅ [Firebase] Signed out successfully")
            logger.info("✅ [Firebase] Signed out successfully")
            Log.info("Signed out successfully", category: .firebase)

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Sign out failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sign out failed: \(error.localizedDescription)")
            Log.error("Sign out failed", category: .firebase, metadata: ["error": error.localizedDescription])
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
}

// MARK: - ASAuthorizationControllerDelegate

extension FirebaseAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                DeviceLogger.shared.log("❌ [Firebase] Invalid credential type", level: .error)
                return
            }

            guard let nonce = currentNonce else {
                DeviceLogger.shared.log("❌ [Firebase] Invalid state: A login callback was received, but no login request was sent.", level: .error)
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                DeviceLogger.shared.log("❌ [Firebase] Unable to fetch identity token", level: .error)
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                DeviceLogger.shared.log("❌ [Firebase] Unable to serialize token string from data: \(appleIDToken.debugDescription)", level: .error)
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
                DeviceLogger.shared.log("🔐 [Firebase] Authenticating with Firebase...")
                let authResult = try await Auth.auth().signIn(with: credential)

                DeviceLogger.shared.log("✅ [Firebase] Successfully signed in: \(authResult.user.uid)")
                logger.info("✅ [Firebase] Successfully signed in: \(authResult.user.uid)")
                Log.info("Successfully signed in with Apple", category: .firebase, metadata: ["uid": authResult.user.uid])

                // Update user profile if this is first sign in
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")

                    if !displayName.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        try await changeRequest.commitChanges()

                        DeviceLogger.shared.log("✅ [Firebase] Updated user profile: \(displayName)")
                    }
                }

                authError = nil

            } catch {
                DeviceLogger.shared.log("❌ [Firebase] Authentication failed: \(error.localizedDescription)", level: .error)
                logger.error("❌ [Firebase] Authentication failed: \(error.localizedDescription)")
                Log.error("Apple authentication failed", category: .firebase, metadata: ["error": error.localizedDescription])
                authError = error
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            DeviceLogger.shared.log("❌ [Firebase] Sign in with Apple failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sign in with Apple failed: \(error.localizedDescription)")
            Log.error("Sign in with Apple failed", category: .firebase, metadata: ["error": error.localizedDescription])

            // Check if user cancelled
            if let authError = error as? ASAuthorizationError {
                if authError.code == .canceled {
                    DeviceLogger.shared.log("ℹ️ [Firebase] User cancelled Sign in with Apple")
                    Log.info("User cancelled Sign in with Apple", category: .firebase)
                    return
                }
            }

            authError = error
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
