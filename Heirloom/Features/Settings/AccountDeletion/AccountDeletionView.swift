//
//  AccountDeletionView.swift
//  Heirloom
//
//  Apple Compliance: Multi-step account deletion flow
//  Guideline 5.1.1(v) - Account Deletion
//

import SwiftUI
import SwiftData
import AuthenticationServices

/// Multi-step account deletion flow with confirmation, re-auth, and progress
struct AccountDeletionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let deletionService = ServiceContainer.shared.resolve(AccountDeletionService.self)
    @State private var currentStep: DeletionFlowStep = .confirmation
    @State private var dataSummary: AccountDataSummary?
    @State private var understandsConsequences = false
    @State private var showExportSheet = false
    @State private var isReauthenticating = false
    @State private var reauthError: String?
    @State private var appleAuthorizationCode: String? // For Apple token revocation
    @State private var emailPassword: String = "" // For email/password re-auth

    private let firebaseAuth = ServiceContainer.shared.resolve(FirebaseAuthService.self)
    private let toastManager = ServiceContainer.shared.resolve(ToastManager.self)

    enum DeletionFlowStep {
        case confirmation
        case subscriptionWarning
        case reAuthentication
        case finalConfirmation
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .confirmation:
                    confirmationView
                case .subscriptionWarning:
                    subscriptionWarningView
                case .reAuthentication:
                    reAuthenticationView
                case .finalConfirmation:
                    finalConfirmationView
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            dataSummary = deletionService.getDataSummary(context: modelContext)
        }
        .sheet(isPresented: $showExportSheet) {
            DataExportView()
        }
    }

    // MARK: - Confirmation View

    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .padding(.top, HeirloomSpacing.xl)

                // Title
                Text("Delete Your Account?")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                Text("This will permanently delete your Heirloom account and all associated data. This action cannot be undone.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Data summary
                if let summary = dataSummary {
                    dataSummarySection(summary)
                }

                Spacer()

                // Action buttons
                VStack(spacing: HeirloomSpacing.md) {
                    // Export data first option
                    Button {
                        showExportSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export My Data First")
                        }
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.tomato)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.cream)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HeirloomColors.tomato, lineWidth: 1)
                        )
                    }

                    // Continue to deletion
                    Button {
                        proceedFromConfirmation()
                    } label: {
                        Text("Continue to Delete")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
        }
        .background(HeirloomColors.appBackground)
    }

    @ViewBuilder
    private func dataSummarySection(_ summary: AccountDataSummary) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            Text("This will delete:")
                .font(HeirloomFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(HeirloomColors.primaryText)

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                deleteItem("\(summary.recipeCount) recipes and all ingredients")
                deleteItem("\(summary.collectionCount) collections")
                deleteItem("Shared recipes and connections")
                deleteItem("Your profile and preferences")
                deleteItem("All recipe images")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func deleteItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Image(systemName: "trash.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .padding(.top, 2)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    // MARK: - Subscription Warning View

    private var subscriptionWarningView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Warning icon
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)
                    .padding(.top, HeirloomSpacing.xl)

                // Title
                Text("Active Subscription")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                VStack(spacing: HeirloomSpacing.md) {
                    Text("You have an active Heirloom Premium subscription.")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    if let expiryDate = dataSummary?.subscriptionExpiryDate {
                        Text("Your subscription is valid until \(expiryDate.formatted(date: .long, time: .omitted))")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    // Refined subscription warning with visual hierarchy
                    VStack(spacing: HeirloomSpacing.sm) {
                        // Primary warning - bold emphasis on key action
                        (Text("Deleting your account will ")
                            .foregroundStyle(HeirloomColors.primaryText) +
                        Text("NOT")
                            .fontWeight(.bold)
                            .foregroundStyle(.orange) +
                        Text(" automatically cancel your subscription.")
                            .foregroundStyle(HeirloomColors.primaryText))
                            .font(HeirloomFonts.body)
                            .multilineTextAlignment(.center)

                        // Secondary instruction - softer emphasis
                        Text("You must cancel separately in the App Store.")
                            .font(HeirloomFonts.subheadline)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                    .padding(HeirloomSpacing.md)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: HeirloomSpacing.md) {
                    // Manage subscription
                    Button {
                        openSubscriptionManagement()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Manage Subscription")
                        }
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.tomato)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.cream)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HeirloomColors.tomato, lineWidth: 1)
                        )
                    }

                    // Continue anyway
                    Button {
                        currentStep = .reAuthentication
                    } label: {
                        Text("Continue Anyway")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Re-Authentication View

    private var reAuthenticationView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(HeirloomColors.tomato)
                    .padding(.top, HeirloomSpacing.xl)

                // Title
                Text("Verify Your Identity")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Description
                Text("For security, please sign in again to confirm account deletion.")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Error message
                if let error = reauthError {
                    Text(error)
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Re-auth buttons - show based on current sign-in method
                VStack(spacing: HeirloomSpacing.md) {
                    // Email/Password re-auth (if signed in with email)
                    if firebaseAuth.currentUserEmail != nil && !firebaseAuth.isAppleUser && !firebaseAuth.isGoogleUser {
                        VStack(spacing: HeirloomSpacing.sm) {
                            Text("Enter your password to confirm")
                                .font(HeirloomFonts.caption1)
                                .foregroundStyle(HeirloomColors.secondaryText)

                            SecureField("Password", text: $emailPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.password)

                            Button {
                                Task {
                                    await handleEmailReauth()
                                }
                            } label: {
                                HStack {
                                    if isReauthenticating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    }
                                    Text("Verify Password")
                                }
                                .font(HeirloomFonts.bodyBold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(emailPassword.isEmpty ? Color.gray : HeirloomColors.tomato)
                                .cornerRadius(12)
                            }
                            .disabled(emailPassword.isEmpty || isReauthenticating)
                        }
                    } else {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        }, onCompletion: { result in
                            handleAppleReauth(result)
                        })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(12)

                        // Sign in with Google
                        Button {
                            Task {
                                await handleGoogleReauth()
                            }
                        } label: {
                            HStack {
                                Image("google-logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Sign in with Google")
                            }
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(HeirloomColors.cardBackground)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(isReauthenticating)
                    }
                }
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)

                if isReauthenticating {
                    ProgressView()
                        .padding()
                }
            }
        }
        .background(HeirloomColors.appBackground)
    }

    // MARK: - Final Confirmation View

    private var finalConfirmationView: some View {
        ScrollView {
            VStack(spacing: HeirloomSpacing.lg) {
                // Warning icon
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)
                    .padding(.top, HeirloomSpacing.xl)

                // Title
                Text("Final Confirmation")
                    .font(HeirloomFonts.title2)
                    .foregroundStyle(HeirloomColors.primaryText)

                // Warning text
                VStack(spacing: HeirloomSpacing.sm) {
                    Text("This is your final warning.")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.red)

                    Text("Once you delete your account:")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)

                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        bulletPoint("All your recipes will be permanently deleted")
                        bulletPoint("You cannot recover your data")
                        bulletPoint("Any shared recipes will be anonymized")
                        bulletPoint("You will be signed out immediately")
                    }
                    .padding(.horizontal)
                }
                .padding(.horizontal)

                Spacer()

                // Confirmation checkbox
                Toggle(isOn: $understandsConsequences) {
                    Text("I understand this action is permanent and cannot be undone")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.primaryText)
                }
                .toggleStyle(CheckboxToggleStyle())
                .padding(.horizontal, HeirloomSpacing.lg)

                // Delete button
                Button {
                    performDeletion()
                } label: {
                    Text("Delete My Account")
                        .font(HeirloomFonts.bodyBold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(understandsConsequences ? Color.red : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!understandsConsequences)
                .padding(.horizontal, HeirloomSpacing.lg)
                .padding(.bottom, HeirloomSpacing.xl)
            }
        }
        .background(HeirloomColors.appBackground)
    }

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Text("•")
                .foregroundStyle(HeirloomColors.primaryText)

            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Actions

    private func proceedFromConfirmation() {
        if deletionService.hasActiveSubscription {
            currentStep = .subscriptionWarning
        } else {
            currentStep = .reAuthentication
        }
    }

    private func openSubscriptionManagement() {
        Task {
            // Open App Store subscription management
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
        }
    }

    private func handleAppleReauth(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            // Extract authorization code for token revocation (Apple compliance)
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let authCodeData = appleIDCredential.authorizationCode,
               let authCode = String(data: authCodeData, encoding: .utf8) {
                appleAuthorizationCode = authCode
                Log.info("Captured Apple authorization code for token revocation", category: .auth)
            }
            // Re-auth successful
            reauthError = nil
            currentStep = .finalConfirmation
        case .failure(let error):
            reauthError = error.localizedDescription
        }
    }

    private func handleGoogleReauth() async {
        isReauthenticating = true
        reauthError = nil

        do {
            try await firebaseAuth.signInWithGoogle()
            await MainActor.run {
                isReauthenticating = false
                currentStep = .finalConfirmation
            }
        } catch {
            await MainActor.run {
                isReauthenticating = false
                reauthError = error.localizedDescription
            }
        }
    }

    private func handleEmailReauth() async {
        isReauthenticating = true
        reauthError = nil

        do {
            try await firebaseAuth.reauthenticateWithEmail(password: emailPassword)
            await MainActor.run {
                isReauthenticating = false
                emailPassword = "" // Clear password
                currentStep = .finalConfirmation
            }
        } catch {
            await MainActor.run {
                isReauthenticating = false
                reauthError = "Incorrect password. Please try again."
            }
        }
    }

    private func performDeletion() {
        // Capture what we need before the sheet dismisses
        let context = modelContext
        let authCode = appleAuthorizationCode
        let service = deletionService
        let toast = toastManager

        // Dismiss the sheet immediately — the blocking overlay on ContentView takes over
        dismiss()

        // Launch an unstructured task that survives the sheet dismiss
        Task { @MainActor in
            do {
                try await service.deleteAccount(
                    context: context,
                    appleAuthorizationCode: authCode
                )
                // On success: Firebase auth deletion triggers isAuthenticated = false
                // RootView swaps to FirebaseSignInView automatically
            } catch {
                toast.error(title: "Deletion failed", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(configuration.isOn ? HeirloomColors.tomato : HeirloomColors.warmGray)

                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Confirmation") {
    AccountDeletionView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
