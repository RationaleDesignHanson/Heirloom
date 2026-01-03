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
    @ObservedObject private var authService = FirebaseAuthService.shared
    @State private var showError = false
    @State private var hasAttemptedSignIn = false

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Icon/Logo
                ZStack {
                    Circle()
                        .fill(HeirloomColors.tomato.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 60))
                        .foregroundColor(HeirloomColors.tomato)
                }

                // Title
                VStack(spacing: 12) {
                    Text("Welcome to Heirloom")
                        .font(HeirloomFonts.title1)
                        .foregroundColor(HeirloomColors.primaryText)

                    Text("Sign in to sync your recipes\nacross all your devices")
                        .font(HeirloomFonts.body)
                        .foregroundColor(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "icloud", text: "Automatic cloud sync")
                    featureRow(icon: "arrow.triangle.2.circlepath", text: "Share recipes with family")
                    featureRow(icon: "shield.checkered", text: "Secure and private")
                }
                .padding(.horizontal, 40)

                Spacer()

                // Sign in buttons
                if authService.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                        .scaleEffect(1.5)
                        .frame(height: 50)
                } else {
                    VStack(spacing: 16) {
                        // Sign in with Apple button
                        Button {
                            guard !hasAttemptedSignIn else { return }
                            hasAttemptedSignIn = true

                            Task {
                                do {
                                    try await authService.signInWithApple()
                                } catch {
                                    hasAttemptedSignIn = false
                                    showError = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(.title3)
                                Text("Sign in with Apple")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(12)
                        }

                        // Sign in with Google button
                        Button {
                            guard !hasAttemptedSignIn else { return }
                            hasAttemptedSignIn = true

                            Task {
                                do {
                                    try await authService.signInWithGoogle()
                                } catch {
                                    hasAttemptedSignIn = false
                                    showError = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                Text("Sign in with Google")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.22, green: 0.45, blue: 0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                hasAttemptedSignIn = false
            }
        } message: {
            if let error = authService.authError {
                Text(error.localizedDescription)
            } else {
                Text("An error occurred during sign in. Please try again.")
            }
        }
        .onChange(of: authService.isAuthenticating) { _, isAuthenticating in
            // Reset hasAttemptedSignIn when authentication completes (success, error, or cancellation)
            if !isAuthenticating {
                hasAttemptedSignIn = false
            }
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(HeirloomColors.tomato)
                .frame(width: 24)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)

            Spacer()
        }
    }
}

#Preview {
    FirebaseSignInView()
}
