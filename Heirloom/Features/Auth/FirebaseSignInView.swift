//
//  FirebaseSignInView.swift
//  Heirloom
//
//  Created during Firebase Migration - Phase 3
//  Sign in screen with emotional hook: "Your family's recipes deserve a home"
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
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password, confirmPassword, resetEmail
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

                    // App name - prominent branding (largest text on screen)
                    Text("Heirloom")
                        .font(HeirloomFonts.largeTitle)
                        .foregroundColor(HeirloomColors.primaryText)
                        .padding(.top, compact ? 8 : 12)

                    // Tagline - Emotional hook (smaller than app name)
                    VStack(spacing: HeirloomSpacing.sm) {
                        Text("Your family's recipes deserve a home")
                            .font(HeirloomFonts.title3)
                            .foregroundColor(HeirloomColors.primaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Scattered across screenshots, texts, and fading cards — until now.")
                            .font(HeirloomFonts.callout)
                            .foregroundColor(HeirloomColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 12 : 20)

                    // Value proposition features (minimal horizontal row) - hide when email form is shown
                    if !showEmailSignIn {
                        HStack(spacing: 32) {
                            miniFeature(icon: "square.and.arrow.down", label: "Save")
                            miniFeature(icon: "sparkles", label: "Structure")
                            miniFeature(icon: "lock.shield", label: "Private")
                        }
                        .padding(.top, compact ? 12 : 20)
                    }

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
                                Text("or use email")
                                    .font(HeirloomFonts.caption1)
                                    .foregroundColor(HeirloomColors.secondaryText)
                                    .padding(.horizontal, 8)
                                Rectangle()
                                    .fill(HeirloomColors.charcoal.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, compact ? 2 : 4)

                            // Email Sign In / Create Account buttons (side by side)
                            HStack(spacing: 12) {
                                // Sign In button
                                Button {
                                    isCreatingAccount = false
                                    showEmailSignIn = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 16))
                                        Text("Sign In")
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

                                // Create Account button
                                Button {
                                    isCreatingAccount = true
                                    showEmailSignIn = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 16))
                                        Text("Create")
                                            .font(HeirloomFonts.bodyBold)
                                    }
                                    .foregroundColor(HeirloomColors.familyGreen)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: buttonHeight)
                                    .background(HeirloomColors.familyGreen.opacity(0.1))
                                    .cornerRadius(HeirloomSpacing.cardCornerRadius)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: HeirloomSpacing.cardCornerRadius)
                                            .strokeBorder(HeirloomColors.familyGreen, lineWidth: 1.5)
                                    )
                                }
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
    private func miniFeature(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(HeirloomColors.tomato)

            Text(label)
                .font(HeirloomFonts.caption1)
                .foregroundColor(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Validation

    /// Check if form can be submitted
    private var canSubmit: Bool {
        if email.isEmpty || password.isEmpty || password.count < 6 {
            return false
        }
        if isCreatingAccount {
            return password == confirmPassword && !confirmPassword.isEmpty
        }
        return true
    }

    // MARK: - Email Sign In View

    private var emailSignInView: some View {
        VStack(spacing: 20) {
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
                    .textContentType(isCreatingAccount ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(isCreatingAccount ? .next : .go)
                    .onSubmit {
                        if isCreatingAccount {
                            focusedField = .confirmPassword
                        } else {
                            focusedField = nil
                            // Auto-submit if valid
                            if !email.isEmpty && !password.isEmpty && password.count >= 6 {
                                performSignIn()
                            }
                        }
                    }
                    .padding()
                    .background(Color(hex: "#F8F8F8"))
                    .cornerRadius(12)
            }

            // Confirm password field (only for account creation)
            if isCreatingAccount {
                VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                    Text("Confirm Password")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(HeirloomColors.secondaryText)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.plain)
                        .font(HeirloomFonts.body)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.go)
                        .onSubmit {
                            focusedField = nil
                            // Auto-submit if valid
                            if canSubmit {
                                performSignIn()
                            }
                        }
                        .padding()
                        .background(Color(hex: "#F8F8F8"))
                        .cornerRadius(12)

                    // Password mismatch warning
                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords don't match")
                            .font(HeirloomFonts.caption2)
                            .foregroundColor(HeirloomColors.tomato)
                    }
                }
            }

            // Forgot password + Create account row (above the submit button)
            HStack {
                Button {
                    isCreatingAccount.toggle()
                    confirmPassword = ""
                } label: {
                    Text(isCreatingAccount ? "Already have an account?" : "Create an account")
                        .font(HeirloomFonts.caption1)
                        .foregroundColor(isCreatingAccount ? HeirloomColors.familyGreen : HeirloomColors.tomato)
                }

                Spacer()

                if !isCreatingAccount {
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(HeirloomFonts.caption1)
                            .foregroundColor(HeirloomColors.tomato)
                    }
                }
            }

            // Cancel + Submit buttons
            HStack(spacing: 12) {
                Button {
                    showEmailSignIn = false
                    email = ""
                    password = ""
                    confirmPassword = ""
                    isCreatingAccount = false
                } label: {
                    Text("Cancel")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(HeirloomColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "#F8F8F8"))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                        )
                }

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
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1.0 : 0.5)
            }
            .animation(.easeInOut(duration: 0.2), value: isCreatingAccount)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40) // Extra padding for home indicator
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
