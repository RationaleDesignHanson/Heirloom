//
//  FirebaseAuthService.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 3
//  Handles Firebase Authentication with Sign in with Apple
//

import Foundation
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import os.log

/// Firebase authentication service with Sign in with Apple
@MainActor
class FirebaseAuthService: NSObject, ObservableObject {

    // Device-visible logging
    private let logger = Logger(subsystem: "com.matthanson.heirloom", category: "FirebaseAuth")

    // MARK: - Singleton

    static let shared = FirebaseAuthService()

    private override init() {
        super.init()

        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil

                if let user = user {
                    DeviceLogger.shared.log("🔐 [Firebase] User signed in: \(user.uid)")
                    self?.logger.info("🔐 [Firebase] User signed in: \(user.uid)")
                } else {
                    DeviceLogger.shared.log("🔐 [Firebase] User signed out")
                    self?.logger.info("🔐 [Firebase] User signed out")
                }
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var authError: Error?
    @Published private(set) var isAuthenticating = false

    // MARK: - Sign in with Apple State

    // Unhashed nonce for Sign in with Apple
    private var currentNonce: String?

    // MARK: - Authentication

    /// Sign in with Apple
    func signInWithApple() async throws {
        DeviceLogger.shared.log("🔐 [Firebase] Starting Sign in with Apple...")
        logger.info("🔐 [Firebase] Starting Sign in with Apple...")
        print("🔐 Starting Sign in with Apple...")

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
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

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Sign in failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sign in failed: \(error.localizedDescription)")
            print("❌ Sign in failed: \(error.localizedDescription)")
            authError = error
            throw error
        }
    }

    /// Sign out
    func signOut() throws {
        DeviceLogger.shared.log("🔐 [Firebase] Signing out...")
        logger.info("🔐 [Firebase] Signing out...")
        print("🔐 Signing out...")

        do {
            try Auth.auth().signOut()

            DeviceLogger.shared.log("✅ [Firebase] Signed out successfully")
            logger.info("✅ [Firebase] Signed out successfully")
            print("✅ Signed out successfully")

        } catch {
            DeviceLogger.shared.log("❌ [Firebase] Sign out failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sign out failed: \(error.localizedDescription)")
            print("❌ Sign out failed: \(error.localizedDescription)")
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
                print("✅ Successfully signed in: \(authResult.user.uid)")

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
                print("❌ Authentication failed: \(error.localizedDescription)")
                authError = error
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            DeviceLogger.shared.log("❌ [Firebase] Sign in with Apple failed: \(error.localizedDescription)", level: .error)
            logger.error("❌ [Firebase] Sign in with Apple failed: \(error.localizedDescription)")
            print("❌ Sign in with Apple failed: \(error.localizedDescription)")

            // Check if user cancelled
            if let authError = error as? ASAuthorizationError {
                if authError.code == .canceled {
                    DeviceLogger.shared.log("ℹ️ [Firebase] User cancelled Sign in with Apple")
                    print("ℹ️ User cancelled Sign in with Apple")
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
