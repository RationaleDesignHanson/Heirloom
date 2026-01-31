import SwiftUI

/// Confirmation sheet for reporting a public recipe
struct ReportConfirmationSheet: View {
    let publicRecipeId: String
    let recipeTitle: String
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason = .inappropriate
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    private var authService: FirebaseAuthService {
        ServiceContainer.shared.resolve(FirebaseAuthService.self)
    }

    private var reportService = ReportPublicRecipeService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: HeirloomSpacing.lg) {
                    // Warning icon
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(HeirloomColors.tomato)
                        .padding(.top, HeirloomSpacing.md)

                    // Title
                    Text("Report Recipe")
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)

                    // Recipe info
                    Text("You're reporting: \"\(recipeTitle)\"")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Reason selection
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("Reason for reporting")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        ForEach(ReportReason.allCases, id: \.self) { reason in
                            reportReasonButton(reason)
                        }
                    }
                    .padding(.horizontal)

                    // Additional details (optional)
                    VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                        Text("Additional details (optional)")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        TextField("Provide more information...", text: $additionalDetails, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                            .font(HeirloomFonts.body)
                    }
                    .padding(.horizontal)

                    // What happens next
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("What happens next:")
                            .font(HeirloomFonts.bodyBold)
                            .foregroundStyle(HeirloomColors.primaryText)

                        bulletPoint("Our team will review your report")
                        bulletPoint("Violating content will be removed")
                        bulletPoint("Reports are anonymous")
                        bulletPoint("False reports may result in account review")
                    }
                    .padding()
                    .background(HeirloomColors.warmGray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)

                    // Submit button
                    Button {
                        Task {
                            await submitReport()
                        }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Submit Report")
                                    .font(HeirloomFonts.bodyBold)
                            }
                        }
                        .foregroundStyle(HeirloomColors.buttonTextLight)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(HeirloomColors.tomato)
                        .cornerRadius(12)
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal)
                }
                .padding(.bottom, HeirloomSpacing.lg)
            }
            .navigationTitle("Report Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Failed to submit report. Please try again.")
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for helping keep our community safe. Our team will review this report.")
            }
        }
    }

    @ViewBuilder
    private func reportReasonButton(_ reason: ReportReason) -> some View {
        Button {
            selectedReason = reason
        } label: {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: reason.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(selectedReason == reason ? HeirloomColors.familyBlue : HeirloomColors.warmGray)

                Text(reason.description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Spacer()

                if selectedReason == reason {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HeirloomColors.familyBlue)
                }
            }
            .padding(HeirloomSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedReason == reason ? HeirloomColors.familyBlue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedReason == reason ? HeirloomColors.familyBlue : HeirloomColors.warmGray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Text("•")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)

            Text(text)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.primaryText)
        }
    }

    private func submitReport() async {
        guard !isSubmitting else { return }

        // Check authentication
        guard authService.isAuthenticated, let userId = authService.currentUser?.uid else {
            errorMessage = "You must be signed in to report content."
            showError = true
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            // Check if user already reported this recipe
            let alreadyReported = try await reportService.hasUserReportedRecipe(
                publicRecipeId: publicRecipeId,
                reporterId: userId
            )

            if alreadyReported {
                errorMessage = "You've already reported this recipe."
                showError = true
                isSubmitting = false
                return
            }

            // Submit report
            try await reportService.reportRecipe(
                publicRecipeId: publicRecipeId,
                reason: selectedReason,
                details: additionalDetails.isEmpty ? nil : additionalDetails,
                reporterId: userId
            )

            Log.info("Recipe report submitted successfully", category: .social, metadata: [
                "publicRecipeId": publicRecipeId,
                "reason": selectedReason.rawValue
            ])

            // Track analytics
            let analytics = ServiceContainer.shared.resolve(AnalyticsService.self)
            analytics.track(event: .other(name: "public_recipe_reported"), properties: [
                "public_recipe_id": publicRecipeId,
                "reason": selectedReason.rawValue,
                "has_details": !additionalDetails.isEmpty
            ])

            // Show success
            isSubmitting = false
            showSuccess = true

        } catch {
            isSubmitting = false
            errorMessage = error.localizedDescription
            showError = true

            Log.error("Failed to submit recipe report", category: .social, metadata: [
                "publicRecipeId": publicRecipeId,
                "error": error.localizedDescription
            ])
        }
    }
}

// MARK: - Preview

#Preview {
    ReportConfirmationSheet(
        publicRecipeId: "test-recipe-123",
        recipeTitle: "Grandma's Apple Pie"
    )
}
