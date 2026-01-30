import SwiftUI

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HeirloomSpacing.xl) {
                // Header
                headerSection

                Divider()

                // Mission
                missionSection

                Divider()

                // Features
                featuresSection

                Divider()

                // Technology
                technologySection

                Divider()

                // Credits
                creditsSection

                Divider()

                // Legal
                legalSection
            }
            .padding(HeirloomSpacing.lg)
        }
        .background(HeirloomColors.appBackground)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            analytics.track(event: .featureUsed, properties: [
                "feature": "about_view"
            ])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: HeirloomSpacing.md) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 80))
                .foregroundStyle(HeirloomColors.tomato)

            Text("Heirloom")
                .font(HeirloomFonts.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(HeirloomColors.primaryText)

            Text("Recipes Worth Passing Down")
                .font(HeirloomFonts.subheadline)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, HeirloomSpacing.lg)
    }

    // MARK: - Mission Section

    private var missionSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionTitle("Our Mission")

            Text("Heirloom helps you preserve and share family recipes. From Grandma's cookies to your own creations, keep your culinary legacy alive for future generations.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("We believe food is more than sustenance—it's stories, memories, and love shared across generations.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
                .italic()
        }
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionTitle("Features")

            FeatureRow(
                icon: "icloud",
                title: "iCloud Sync",
                description: "Access recipes on all your devices"
            )

            FeatureRow(
                icon: "cart",
                title: "Smart Shopping",
                description: "Organized by store layout with auto-aggregation"
            )

            FeatureRow(
                icon: "camera",
                title: "Photo Import",
                description: "Digitize family recipe cards with OCR"
            )

            FeatureRow(
                icon: "square.stack.3d.up",
                title: "Ingredient Math",
                description: "Auto-combine and scale quantities"
            )

            FeatureRow(
                icon: "paintbrush",
                title: "Card Personalization",
                description: "Make each recipe card uniquely yours"
            )

            FeatureRow(
                icon: "fork.knife",
                title: "Dinner Parties",
                description: "Plan meals and manage guest servings"
            )

            FeatureRow(
                icon: "flame",
                title: "Cooking Mode",
                description: "Hands-free cooking with timers"
            )
        }
    }

    // MARK: - Technology Section

    private var technologySection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionTitle("Built With")

            TechnologyRow(name: "SwiftUI", description: "Modern Apple UI framework")
            TechnologyRow(name: "SwiftData", description: "Local data persistence")
            TechnologyRow(name: "CloudKit", description: "iCloud sync infrastructure")
            TechnologyRow(name: "Vision", description: "OCR for recipe cards")
            TechnologyRow(name: "Claude AI", description: "Smart recipe extraction")
        }
    }

    // MARK: - Credits Section

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.md) {
            sectionTitle("Made with ❤️")

            Text("Heirloom is designed to bring families together through food and shared memories.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)

            Text("Created by a team passionate about preserving culinary traditions and making cooking more accessible for everyone.")
                .font(HeirloomFonts.body)
                .foregroundStyle(HeirloomColors.secondaryText)
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
            sectionTitle("Legal")

            Button {
                // Open privacy policy
                if let url = URL(string: "https://heirloom.app/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Privacy Policy")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.tomato)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }

            Button {
                // Open terms
                if let url = URL(string: "https://heirloom.app/terms") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Terms of Service")
                        .font(HeirloomFonts.body)
                        .foregroundStyle(HeirloomColors.tomato)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.tomato)
                }
            }

            Text("© 2024 Heirloom. All rights reserved.")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.secondaryText)
                .padding(.top, HeirloomSpacing.sm)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(HeirloomFonts.title3)
            .fontWeight(.semibold)
            .foregroundStyle(HeirloomColors.primaryText)
    }
}

// MARK: - Feature Row
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: icon)
                .font(HeirloomFonts.title2)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.bodyBold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

// MARK: - Technology Row
struct TechnologyRow: View {
    let name: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(HeirloomFonts.caption1)
                .foregroundStyle(HeirloomColors.familyGreen)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AboutView()
    }
}
