//
//  FirebaseSignInView.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 3
//  Sign in screen for Firebase authentication
//

import SwiftUI
import AuthenticationServices

struct FirebaseSignInView: View {
    @StateObject private var authService = FirebaseAuthService.shared
    @State private var showError = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Icon/Logo
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80))
                .foregroundColor(HeirloomColors.tomato)

            // Title
            VStack(spacing: 8) {
                Text("Welcome to Heirloom")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Sign in to sync your recipes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sign in with Apple button
            SignInWithAppleButton(
                onRequest: { request in
                    // Configured by auth service
                },
                onCompletion: { result in
                    Task {
                        do {
                            try await authService.signInWithApple()
                        } catch {
                            showError = true
                        }
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            // Info text
            Text("Your recipes will be securely synced\nacross all your devices")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 40)
        }
        .padding()
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = authService.authError {
                Text(error.localizedDescription)
            } else {
                Text("An error occurred during sign in. Please try again.")
            }
        }
    }
}

#Preview {
    FirebaseSignInView()
}
