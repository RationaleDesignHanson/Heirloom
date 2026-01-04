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

    private let configuration: FirebaseConfigurationProtocol
    private let logger: LoggingService

    // MARK: - Initialization

    init(configuration: FirebaseConfigurationProtocol, logger: LoggingService) {
        self.configuration = configuration
        self.logger = logger
        super.init()

        // Check current auth state immediately (before listener fires)
        if let user = configuration.auth.currentUser {
            currentUser = user
            isAuthenticated = true
            hasCheckedInitialAuthState = true
            logger.log("Restored auth session: \(user.uid)", category: .auth, level: .info)
        }

        // Listen for auth state changes
        _ = configuration.auth.addStateDidChangeListener { [weak self] _, user in
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
                    self.logger.log("User signed in: \(user.uid)", category: .auth, level: .info)
                } else {
                    self.logger.log("User signed out", category: .auth, level: .info)
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
        logger.log("Starting Sign in with Apple", category: .auth, level: .info)

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
        logger.log("Starting Sign in with Google", category: .auth, level: .info)

        isAuthenticating = true
        defer { isAuthenticating = false }

        // Get the client ID from Firebase
        guard let clientID = configuration.auth.app?.options.clientID else {
            let error = AuthError.invalidCredential
            logger.log("Missing Google client ID", category: .auth, level: .error)
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
            logger.log("No root view controller found for Google sign in", category: .auth, level: .error)
            authError = error
            throw error
        }

        do {
            // Present Google Sign In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                let error = AuthError.invalidCredential
                logger.log("Missing Google ID token", category: .auth, level: .error)
                authError = error
                throw error
            }

            let accessToken = result.user.accessToken.tokenString

            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            // Sign in to Firebase
            logger.log("Authenticating with Firebase using Google credential", category: .auth, level: .info)
            let authResult = try await configuration.auth.signIn(with: credential)

            logger.log("Successfully signed in with Google: \(authResult.user.uid)", category: .auth, level: .info)

            authError = nil

        } catch {
            logger.log("Google sign in failed: \(error.localizedDescription)", category: .auth, level: .error)

            // Check if user cancelled
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                logger.log("User cancelled Google sign in", category: .auth, level: .info)
                return
            }

            authError = error
            throw error
        }
    }

    /// Sign out
    func signOut() throws {
        logger.log("Signing out user", category: .auth, level: .info)

        do {
            try configuration.auth.signOut()

            // Also sign out from Google
            GIDSignIn.sharedInstance.signOut()

            logger.log("Signed out successfully", category: .auth, level: .info)

        } catch {
            logger.log("Sign out failed: \(error.localizedDescription)", category: .auth, level: .error)
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
                logger.log("Invalid credential type for Apple sign in", category: .auth, level: .error)
                return
            }

            guard let nonce = currentNonce else {
                logger.log("Invalid state: login callback received but no login request was sent", category: .auth, level: .error)
                return
            }

            guard let appleIDToken = appleIDCredential.identityToken else {
                logger.log("Unable to fetch Apple identity token", category: .auth, level: .error)
                return
            }

            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                logger.log("Unable to serialize Apple token string", category: .auth, level: .error)
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
                logger.log("Authenticating with Firebase using Apple credential", category: .auth, level: .info)
                let authResult = try await configuration.auth.signIn(with: credential)

                logger.log("Successfully signed in with Apple: \(authResult.user.uid)", category: .auth, level: .info)

                // Update user profile if this is first sign in
                if let fullName = appleIDCredential.fullName {
                    let displayName = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }
                        .joined(separator: " ")

                    if !displayName.isEmpty {
                        let changeRequest = authResult.user.createProfileChangeRequest()
                        changeRequest.displayName = displayName
                        try await changeRequest.commitChanges()

                        logger.log("Updated user profile: \(displayName)", category: .auth, level: .info)
                    }
                }

                authError = nil

            } catch {
                logger.log("Apple authentication failed: \(error.localizedDescription)", category: .auth, level: .error)
                authError = error
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            logger.log("Sign in with Apple failed: \(error.localizedDescription)", category: .auth, level: .error)

            // Check if user cancelled
            if let authError = error as? ASAuthorizationError {
                if authError.code == .canceled {
                    logger.log("User cancelled Sign in with Apple", category: .auth, level: .info)
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
