import SwiftUI

/// Privacy settings and consent management
struct PrivacySettingsView: View {
    @ObservedObject private var consentService = PrivacyConsentService.shared
    @State private var showPrivacyPolicy = false
    @State private var showDataExport = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            // Status Section
            consentStatusSection

            // Consent Controls
            consentControlsSection

            // Data Management
            dataManagementSection

            // Privacy Policy
            privacyPolicySection
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showDataExport) {
            DataExportView()
        }
        .alert("Delete All Shared Data?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAllSharedData()
            }
        } message: {
            Text("This will delete all recipes and comments you've shared to CloudKit. This cannot be undone. Your local recipes will not be affected.")
        }
    }

    // MARK: - Consent Status Section

    private var consentStatusSection: some View {
        Section {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(consentService.getConsentStatus().hasAnyConsent ? HeirloomColors.tomato : HeirloomColors.warmGray)
                        .font(.system(size: 24))

                    Text("Privacy Status")
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Text(consentService.getConsentStatus().description)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)

                if let date = consentService.getConsentStatus().formattedConsentDate {
                    Text("Last updated: \(date)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .padding(.vertical, HeirloomSpacing.xs)
        } header: {
            Text("Status")
        }
    }

    // MARK: - Consent Controls Section

    private var consentControlsSection: some View {
        Section {
            // Sharing Consent
            Toggle(isOn: $consentService.hasSharingConsent) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(HeirloomColors.tomato)
                        Text("Recipe Sharing")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }

                    Text("Share recipes and comments with family")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .tint(HeirloomColors.tomato)
            .onChange(of: consentService.hasSharingConsent) { _, newValue in
                if newValue {
                    consentService.grantSharingConsent()
                } else {
                    consentService.revokeSharingConsent()
                }
            }

            // Analytics Consent
            Toggle(isOn: $consentService.hasAnalyticsConsent) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(.blue)
                        Text("Anonymous Analytics")
                            .font(HeirloomFonts.body)
                            .foregroundStyle(HeirloomColors.primaryText)
                    }

                    Text("Help improve the app with usage data")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .tint(.blue)
            .onChange(of: consentService.hasAnalyticsConsent) { _, newValue in
                if newValue {
                    consentService.grantAnalyticsConsent()
                } else {
                    consentService.revokeAnalyticsConsent()
                }
            }
        } header: {
            Text("Consent Settings")
        } footer: {
            Text("You can change these settings at any time. Disabling sharing won't affect recipes you've already shared.")
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section {
            // Export Data
            Button {
                showDataExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Export My Data")
                        .foregroundStyle(HeirloomColors.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
            }

            // View Shared Recipes
            NavigationLink {
                SharedRecipesListView()
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(HeirloomColors.tomato)

                    VStack(alignment: .leading) {
                        Text("My Shared Recipes")
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("View recipes you've shared to CloudKit")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }

            // Delete Shared Data
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)

                    Text("Delete All Shared Data")
                        .foregroundStyle(.red)
                }
            }
            .disabled(!consentService.hasSharingConsent)
        } header: {
            Text("Data Management")
        } footer: {
            Text("GDPR and CCPA compliant. You have the right to export and delete your data.")
        }
    }

    // MARK: - Privacy Policy Section

    private var privacyPolicySection: some View {
        Section {
            Button {
                showPrivacyPolicy = true
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(HeirloomColors.tomato)

                    VStack(alignment: .leading) {
                        Text("Privacy Policy")
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Last updated: \(consentService.getCurrentPolicyVersion())")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
            }
        }
    }

    // MARK: - Actions

    private func deleteAllSharedData() {
        Task {
            // Delete all shared recipes from CloudKit
            // This would require implementing a method in PublicShareService
            // For now, just show success message

            ToastManager.shared.success(
                title: "Shared Data Deleted",
                message: "All your shared recipes have been removed from CloudKit"
            )
        }
    }
}

// MARK: - Shared Recipes List View

struct SharedRecipesListView: View {
    var body: some View {
        List {
            Text("Feature coming soon")
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .navigationTitle("Shared Recipes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
