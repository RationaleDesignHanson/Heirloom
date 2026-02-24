import SwiftUI

/// Simplified Privacy settings - Export/Import, Delete Account, Privacy Policy
struct PrivacySettingsView: View {
    @State private var showDataExport = false
    @State private var showAccountDeletion = false

    var body: some View {
        List {
            // Data Export
            dataExportSection

            // Account Deletion (Apple Compliance 5.1.1v)
            accountDeletionSection

            // Legal (Privacy Policy, Terms)
            legalSection
        }
        .navigationTitle("Privacy & Data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDataExport) {
            DataExportView()
        }
        .sheet(isPresented: $showAccountDeletion) {
            AccountDeletionView()
        }
    }

    // MARK: - Data Export/Import Section

    private var dataExportSection: some View {
        Section {
            Button {
                showDataExport = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.arrow.down.circle.fill")
                        .foregroundStyle(HeirloomColors.tomato)

                    VStack(alignment: .leading) {
                        Text("Export / Import Data")
                            .foregroundStyle(HeirloomColors.primaryText)

                        Text("Backup or restore your recipes and data")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text("GDPR and CCPA compliant. Export your data anytime or restore from a backup.")
        }
    }

    // MARK: - Account Deletion Section (Apple Compliance)

    private var accountDeletionSection: some View {
        Section {
            Button(role: .destructive) {
                showAccountDeletion = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)

                    VStack(alignment: .leading) {
                        Text("Delete Account")
                            .foregroundStyle(.red)

                        Text("Permanently delete your account and all data")
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        } header: {
            Text("Account")
        } footer: {
            Text("This will permanently delete your Heirloom account and all associated data. This action cannot be undone.")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            Link(destination: URL(string: "https://heirloomrecipebox.app/privacy")!) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Privacy Policy")
                        .foregroundStyle(HeirloomColors.primaryText)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
            }

            Link(destination: URL(string: "https://heirloomrecipebox.app/terms")!) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(HeirloomColors.tomato)

                    Text("Terms of Service")
                        .foregroundStyle(HeirloomColors.primaryText)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(HeirloomColors.warmGray)
                }
            }
        } header: {
            Text("Legal")
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
