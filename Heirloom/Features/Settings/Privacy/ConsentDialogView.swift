import SwiftUI

/// First-launch privacy consent dialog
/// Presents two-tier consent model: Sharing + Analytics
struct ConsentDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var consentService = PrivacyConsentService.shared

    @State private var sharingConsent = false
    @State private var analyticsConsent = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                    // Header
                    headerSection

                    // Sharing Consent
                    consentOption(
                        title: "Recipe Sharing",
                        icon: "person.2.fill",
                        description: "Share recipes with family and friends. Comments you mark as \"Share with Family\" will follow the recipe through generations.",
                        examples: [
                            "Share recipes via link or QR code",
                            "Pass down recipes with personal messages",
                            "See comments from your recipe lineage",
                            "Track who shared recipes to you"
                        ],
                        isGranted: $sharingConsent,
                        color: HeirloomColors.tomato
                    )

                    // Analytics Consent
                    consentOption(
                        title: "Anonymous Analytics",
                        icon: "chart.bar.fill",
                        description: "Help us improve Heirloom by sharing anonymous usage data. No recipe content or personal information is ever collected.",
                        examples: [
                            "Which features you use most",
                            "App performance and crashes",
                            "Feature adoption rates",
                            "No personal data or recipes"
                        ],
                        isGranted: $analyticsConsent,
                        color: .blue
                    )

                    // Important notes
                    notesSection

                    // Privacy policy link
                    privacyPolicyLink
                }
                .padding(HeirloomSpacing.lg)
            }
            .background(HeirloomColors.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Privacy & Consent")
                        .font(HeirloomFonts.headline)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        saveConsents()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .interactiveDismissDisabled() // Can't dismiss until making choice
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            HStack(spacing: HeirloomSpacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Welcome!")
                    .font(HeirloomFonts.largeTitle)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            Text("Heirloom respects your privacy. Choose what features you'd like to enable:")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("You can change these settings anytime in Settings → Privacy.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .italic()
        }
    }

    // MARK: - Consent Option

    @ViewBuilder
    private func consentOption(
        title: String,
        icon: String,
        description: String,
        examples: [String],
        isGranted: Binding<Bool>,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            // Header with toggle
            HStack {
                HStack(spacing: HeirloomSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(color)

                    Text(title)
                        .font(HeirloomFonts.title2)
                        .foregroundStyle(HeirloomColors.primaryText)
                }

                Spacer()

                Toggle("", isOn: isGranted)
                    .labelsHidden()
                    .tint(color)
            }

            // Description
            Text(description)
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Examples
            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                ForEach(examples, id: \.self) { example in
                    HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                            .foregroundStyle(color)
                            .padding(.top, 2)

                        Text(example)
                            .font(HeirloomFonts.caption1)
                            .foregroundStyle(HeirloomColors.secondaryText)
                    }
                }
            }
        }
        .padding(HeirloomSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isGranted.wrappedValue ? color.opacity(0.1) : HeirloomColors.cream)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isGranted.wrappedValue ? color : HeirloomColors.warmGray.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            HStack(spacing: HeirloomSpacing.xs) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(HeirloomColors.warmGray)

                Text("Important")
                    .font(HeirloomFonts.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(HeirloomColors.primaryText)
            }

            VStack(alignment: .leading, spacing: HeirloomSpacing.xs) {
                noteItem("All features are optional - you can use Heirloom without enabling either")
                noteItem("Your recipes are always private unless you explicitly share them")
                noteItem("You can change these settings anytime")
                noteItem("GDPR and CCPA compliant")
            }
        }
        .padding(HeirloomSpacing.md)
        .background(HeirloomColors.warmGray.opacity(0.1))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func noteItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.xs) {
            Text("•")
                .foregroundStyle(HeirloomColors.secondaryText)
            Text(text)
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Privacy Policy Link

    private var privacyPolicyLink: some View {
        Button {
            showPrivacyPolicy = true
        } label: {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(HeirloomColors.tomato)

                Text("Read Full Privacy Policy")
                    .font(HeirloomFonts.subheadline)
                    .foregroundStyle(HeirloomColors.tomato)

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(HeirloomColors.warmGray)
            }
            .padding(HeirloomSpacing.md)
            .background(HeirloomColors.cream)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func saveConsents() {
        consentService.markConsentDialogSeen()

        if sharingConsent {
            consentService.grantSharingConsent()
        }

        if analyticsConsent {
            consentService.grantAnalyticsConsent()
        }

        // Track the consent decision (only if analytics was granted)
        if analyticsConsent {
            AnalyticsService.shared.track(event: .settingChanged, properties: [
                "source": "first_launch",
                "sharing_granted": sharingConsent,
                "analytics_granted": analyticsConsent
            ])
        }

        dismiss()
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(loadPrivacyPolicy())
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)
                    .padding(HeirloomSpacing.md)
            }
            .background(HeirloomColors.appBackground)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func loadPrivacyPolicy() -> String {
        // Load from PRIVACY_POLICY.txt file
        if let url = Bundle.main.url(forResource: "PRIVACY_POLICY", withExtension: "txt"),
           let content = try? String(contentsOf: url) {
            return content
        }
        return "Privacy Policy could not be loaded. Please contact support."
    }
}

// MARK: - Preview

#Preview("Consent Dialog") {
    ConsentDialogView()
}

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}
