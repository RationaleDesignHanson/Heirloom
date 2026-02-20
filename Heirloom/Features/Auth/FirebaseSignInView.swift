//
//  FirebaseSignInView.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 3
//  Sign in screen for Firebase authentication
//

import SwiftUI
import UIKit
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
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, resetEmail
    }

    var body: some View {
        ZStack {
            // Background
            HeirloomColors.appBackground
                .ignoresSafeArea()

            GeometryReader { geometry in
                let compact = geometry.size.height < 700
                let imageSize: CGFloat = compact ? 120 : 240

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // App Icon/Logo
                    Image("ceramic-hero-book")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize, height: imageSize)
                        .shadow(color: Color(red: 0.2, green: 0.15, blue: 0.1).opacity(0.3), radius: 12, x: 0, y: 6)

                    // Title
                    VStack(spacing: HeirloomSpacing.sm) {
                        Text("Welcome to Heirloom")
                            .font(HeirloomFonts.title1)
                            .foregroundColor(HeirloomColors.primaryText)

                        Text("Preserve the recipes you love — save from anywhere, share with people you trust.")
                            .font(HeirloomFonts.body)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, compact ? 12 : 20)

                    // Features list
                    VStack(alignment: .leading, spacing: compact ? 6 : 12) {
                        featureRow(icon: "icloud", text: "Automatic cloud sync")
                        featureRow(icon: "arrow.triangle.2.circlepath", text: "Share recipes with family")
                        featureRow(icon: "shield.checkered", text: "Secure and private")
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, compact ? 16 : 32)

                    Spacer(minLength: compact ? 8 : 16)

                    // Sign in buttons
                    if authService.isAuthenticating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: HeirloomColors.tomato))
                            .scaleEffect(1.5)
                            .frame(height: 50)
                    } else if showEmailSignIn {
                        emailSignInView
                    } else {
                        let buttonHeight: CGFloat = compact ? 44 : 50

                        VStack(spacing: compact ? 8 : 12) {
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
                                        // Don't show error for user cancellation
                                        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                                            return
                                        }
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
                                .frame(height: buttonHeight)
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
                                .frame(height: buttonHeight)
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
                            .padding(.vertical, compact ? 2 : 4)

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
                                .frame(height: buttonHeight)
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

                    Spacer(minLength: 0)
                        .frame(maxHeight: compact ? 16 : 40)
                }
                .frame(height: geometry.size.height)
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                hasAttemptedSignIn = false
            }
        } message: {
            Text(userFriendlyErrorMessage(for: authService.authError))
        }
        .onChange(of: authService.isAuthenticating) { _, isAuthenticating in
            // Reset hasAttemptedSignIn when authentication completes (success, error, or cancellation)
            if !isAuthenticating {
                hasAttemptedSignIn = false
            }
        }
        .onChange(of: password) { oldValue, newValue in
            // Auto-dismiss keyboard when auto-fill completes (password populated while email exists)
            // Auto-fill sets multiple characters at once, so check that more than 1 char was added
            // This prevents dismissing keyboard when user types the first character manually
            let charsAdded = newValue.count - oldValue.count
            if charsAdded > 1 && !email.isEmpty && focusedField != nil {
                // Small delay to let auto-fill animation complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = nil
                }
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
                    .textContentType(.username)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
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
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        focusedField = nil
                        // Auto-submit if valid
                        if !email.isEmpty && !password.isEmpty && password.count >= 6 {
                            performSignIn()
                        }
                    }
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
                performSignIn()
            } label: {
                Text(isCreatingAccount ? "Create Account" : "Sign In")
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.buttonTextLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isCreatingAccount ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                    .cornerRadius(12)
            }
            .disabled(email.isEmpty || password.isEmpty || password.count < 6)
            .opacity((email.isEmpty || password.isEmpty || password.count < 6) ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isCreatingAccount)

            // Toggle create/sign in
            Button {
                isCreatingAccount.toggle()
            } label: {
                Text(isCreatingAccount ? "Already have an account? Sign in" : "Don't have an account? Create one")
                    .font(HeirloomFonts.caption1)
                    .foregroundColor(isCreatingAccount ? HeirloomColors.familyGreen : HeirloomColors.tomato)
            }
        }
        .padding(.horizontal, 40)
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside text fields
            focusedField = nil
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordView
        }
    }

    // MARK: - Sign In Action

    private func performSignIn() {
        // Dismiss keyboard first
        focusedField = nil

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
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .resetEmail)
                    .submitLabel(.send)
                    .onSubmit {
                        focusedField = nil
                    }
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

    // MARK: - Error Handling

    /// Convert Firebase auth errors to user-friendly messages
    private func userFriendlyErrorMessage(for error: Error?) -> String {
        guard let error = error else {
            return "An error occurred during sign in. Please try again."
        }

        let nsError = error as NSError

        // Check Firebase Auth error codes
        switch nsError.code {
        case 17011: // userNotFound
            return "This account doesn't exist. It may have been deleted. Please create a new account to continue."
        case 17009: // wrongPassword
            return "Incorrect password. Please try again or reset your password."
        case 17008: // invalidEmail
            return "Please enter a valid email address."
        case 17007: // emailAlreadyInUse
            return "An account with this email already exists. Try signing in instead."
        case 17020: // networkError
            return "Unable to connect. Please check your internet connection and try again."
        case 17010: // userDisabled
            return "This account has been disabled. Please contact support for assistance."
        case 17026: // requiresRecentLogin
            return "For security, please sign in again to complete this action."
        default:
            // Return the original error message for unhandled cases
            return error.localizedDescription
        }
    }
}

#Preview {
    FirebaseSignInView()
}
