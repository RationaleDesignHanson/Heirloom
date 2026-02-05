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
    @Environment(\.firebaseAuth) private var authService
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var hasAttemptedSignIn = false
    @State private var showEmailSignIn = false
    @State private var isCreatingAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false
    @State private var resetEmail = ""
    @State private var showResetSuccess = false

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(minHeight: 40, maxHeight: 60)

                // App Icon/Logo (smaller on iPad)
                Image("ceramic-hero-book")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
                    .shadow(color: Color(red: 0.2, green: 0.15, blue: 0.1).opacity(0.3), radius: 12, x: 0, y: 6)

                // Title
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("Welcome to Heirloom")
                        .font(HeirloomFonts.title1)
                        .foregroundColor(HeirloomColors.primaryText)

                    Text("Sign in to sync your recipes...")
                        .font(HeirloomFonts.body)
                        .foregroundColor(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                // Features list (more compact)
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "icloud", text: "Automatic cloud sync")
                    featureRow(icon: "arrow.triangle.2.circlepath", text: "Share recipes with family")
                    featureRow(icon: "shield.checkered", text: "Secure and private")
                }
                .padding(.horizontal, 40)
                .padding(.top, 32)

                Spacer()
                    .frame(minHeight: 20, maxHeight: 40)

                // Sign in buttons
                if authService.isAuthenticating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                        .scaleEffect(1.5)
                        .frame(height: 50)
                } else if showEmailSignIn {
                    emailSignInView
                } else {
                    VStack(spacing: 12) {
                        // Sign in with Apple button
                        Button {
                            guard !hasAttemptedSignIn else { return }
                            hasAttemptedSignIn = true

                            Task {
                                do {
                                    try await authService.signInWithApple()
                                    dismiss()
                                } catch {
                                    hasAttemptedSignIn = false
                                    showError = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(HeirloomFonts.title2)
                                Text("Sign in with Apple")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(HeirloomSpacing.cardCornerRadius)
                        }

                        // Sign in with Google button
                        Button {
                            guard !hasAttemptedSignIn else { return }
                            hasAttemptedSignIn = true

                            Task {
                                do {
                                    try await authService.signInWithGoogle()
                                    dismiss()
                                } catch {
                                    hasAttemptedSignIn = false
                                    showError = true
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "g.circle.fill")
                                    .font(HeirloomFonts.title2)
                                Text("Sign in with Google")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .foregroundStyle(HeirloomColors.buttonTextLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.26, green: 0.52, blue: 0.96), Color(red: 0.22, green: 0.45, blue: 0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(HeirloomSpacing.cardCornerRadius)
                        }

                        // Divider
                        HStack {
                            Rectangle()
                                .fill(HeirloomColors.charcoal.opacity(0.2))
                                .frame(height: 1)
                            Text("or")
                                .font(HeirloomFonts.caption1)
                                .foregroundColor(HeirloomColors.secondaryText)
                                .padding(.horizontal, 8)
                            Rectangle()
                                .fill(HeirloomColors.charcoal.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        // Sign in with Email button
                        Button {
                            showEmailSignIn = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(HeirloomFonts.title2)
                                Text("Sign in with Email")
                                    .font(HeirloomFonts.bodyBold)
                            }
                            .foregroundColor(HeirloomColors.tomato)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(HeirloomColors.tomato.opacity(0.1))
                            .cornerRadius(HeirloomSpacing.cardCornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                    .strokeBorder(HeirloomColors.tomato, lineWidth: 1.5)
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(minHeight: 30, maxHeight: 50)
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
                .font(HeirloomFonts.title2)
                .foregroundColor(HeirloomColors.tomato)
                .frame(width: 24)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundColor(HeirloomColors.primaryText)

            Spacer()
        }
    }

    // MARK: - Email Sign In View

    private var emailSignInView: some View {
        VStack(spacing: 20) {
            // Back button
            HStack {
                Button {
                    showEmailSignIn = false
                    email = ""
                    password = ""
                } label: {
                    HStack(spacing: HeirloomSpacing.xs) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(HeirloomFonts.body)
                    .foregroundColor(HeirloomColors.tomato)
                }
                Spacer()
            }
            .padding(.horizontal, 40)

            // Title
            Text(isCreatingAccount ? "Create Account" : "Sign In")
                .font(HeirloomFonts.title2)
                .foregroundColor(HeirloomColors.primaryText)

            // Email field
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Email")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.plain)
                    .font(HeirloomFonts.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(hex: "#F8F8F8"))
                    .cornerRadius(12)
            }

            // Password field
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("Password")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .font(HeirloomFonts.body)
                    .padding()
                    .background(Color(hex: "#F8F8F8"))
                    .cornerRadius(12)
            }

            // Forgot password
            if !isCreatingAccount {
                HStack {
                    Spacer()
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(HeirloomColors.tomato)
                    }
                }
            }

            // Submit button
            Button {
                Task {
                    do {
                        if isCreatingAccount {
                            try await authService.createAccountWithEmail(email: email, password: password)
                        } else {
                            try await authService.signInWithEmail(email: email, password: password)
                        }
                        dismiss()
                    } catch {
                        showError = true
                    }
                }
            } label: {
                Text(isCreatingAccount ? "Create Account" : "Sign In")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(HeirloomColors.tomato)
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || password.count < 6)
            .opacity((email.isEmpty || password.isEmpty || password.count < 6) ? 0.5 : 1.0)

            // Toggle create/sign in
            Button {
                isCreatingAccount.toggle()
            } label: {
                Text(isCreatingAccount ? "Already have an account? Sign in" : "Don't have an account? Create one")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(HeirloomColors.secondaryText)
            }
        }
        .padding(.horizontal, 40)
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordView
        }
    }

    private var forgotPasswordView: some View {
        NavigationStack {
            VStack(spacing: HeirloomSpacing.lg) {
                Text("Reset your password")
                    .font(HeirloomFonts.title3)
                    .foregroundColor(HeirloomColors.primaryText)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(HeirloomFonts.body)
                    .foregroundColor(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)

                TextField("your@email.com", text: $resetEmail)
                    .textFieldStyle(.plain)
                    .font(HeirloomFonts.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(hex: "#F8F8F8"))
                    .cornerRadius(12)

                Button {
                    Task {
                        do {
                            try await authService.sendPasswordReset(email: resetEmail)
                            showForgotPassword = false
                            showResetSuccess = true
                            resetEmail = ""
                        } catch {
                            showError = true
                        }
                    }
                } label: {
                    Text("Send Reset Link")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                }
                .disabled(resetEmail.isEmpty)
                .opacity(resetEmail.isEmpty ? 0.5 : 1.0)

                Spacer()
            }
            .padding(40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showForgotPassword = false
                        resetEmail = ""
                    }
                }
            }
        }
        .alert("Reset Email Sent", isPresented: $showResetSuccess) {
            Button("OK") {}
        } message: {
            Text("Check your email for a link to reset your password.")
        }
    }
}

#Preview {
    FirebaseSignInView()
}
