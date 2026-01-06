import SwiftUI

/// AI service configuration and monitoring view
struct AISettingsView: View {
    @StateObject private var config = ServiceContainer.shared.resolve(AIConfiguration.self)
    @StateObject private var tracker = ServiceContainer.shared.resolve(AIUsageTracker.self)
    @Environment(\.aiService) private var aiService

    private var toastManager: ToastManager { ServiceContainer.shared.resolve(ToastManager.self) }
    private var analytics: AnalyticsService { ServiceContainer.shared.resolve(AnalyticsService.self) }

    @State private var apiKey: String = ""
    @State private var isTestRunning = false
    @State private var testResult: String = ""
    @State private var showingAPIKeyInput = false

    var body: some View {
        List {
            // Configuration Section
            configurationSection

            // Feature Toggles Section
            featureTogglesSection

            // Usage Statistics Section
            usageSection

            // Test Section
            testSection

            // About AI Features Section
            aboutSection
        }
        .navigationTitle("AI Features")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadAPIKey()
        }
        .sheet(isPresented: $showingAPIKeyInput) {
            apiKeyInputSheet
        }
    }

    // MARK: - Configuration Section

    private var configurationSection: some View {
        Section {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(HeirloomColors.tomato)
                Text("AI Provider")
                Spacer()
                Text(config.selectedProvider.displayName)
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
            }

            // API Key Status Row
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: config.currentAPIKey != nil ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(config.currentAPIKey != nil ? .green : .red)
                    Text("API Key")
                    Spacer()

                    if config.isUsingDefaultKey {
                        Text("Shared Key")
                            .foregroundStyle(HeirloomColors.secondaryText)
                            .font(HeirloomFonts.caption1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(HeirloomColors.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Text("Personal Key")
                            .foregroundStyle(.green)
                            .font(HeirloomFonts.caption1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Show masked key
                if let maskedKey = config.maskedAPIKey {
                    Text(maskedKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }

            // Daily quota (only for default key)
            if config.isUsingDefaultKey {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(HeirloomColors.amber)
                    Text("Daily Quota")
                    Spacer()
                    Text("\(config.remainingDailyQuota)/100 recipes")
                        .foregroundStyle(config.remainingDailyQuota > 20 ? HeirloomColors.secondaryText : HeirloomColors.tomato)
                        .font(HeirloomFonts.caption1)
                }
            }

            // Action button
            Button {
                showingAPIKeyInput = true
            } label: {
                if config.isUsingDefaultKey {
                    Label("Add Your Own Key (Unlimited)", systemImage: "key")
                } else {
                    Label("Update Personal Key", systemImage: "key")
                }
            }

            // Remove button (only for personal keys)
            if !config.isUsingDefaultKey {
                Button(role: .destructive) {
                    removeAPIKey()
                } label: {
                    Label("Remove Personal Key", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Configuration")
        } footer: {
            if config.isUsingDefaultKey {
                Text("You're using a shared API key with a daily limit of 100 recipes. Add your own Anthropic key for unlimited usage. Get your key at console.anthropic.com")
            } else {
                Text("You're using your personal Anthropic API key with unlimited usage.")
            }
        }
    }

    // MARK: - Feature Toggles Section

    private var featureTogglesSection: some View {
        Section {
            Toggle(isOn: $config.enableAIParsing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Ingredient Parsing")
                        .font(HeirloomFonts.body)
                    Text("Use AI to parse ingredient text (~95% accuracy)")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .disabled(config.currentAPIKey == nil)

            Toggle(isOn: $config.enableAICategories) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Category Detection")
                        .font(HeirloomFonts.body)
                    Text("Automatically detect recipe categories")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .disabled(config.currentAPIKey == nil)

            Toggle(isOn: $config.enableAIEnhancement) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Recipe Enhancement")
                        .font(HeirloomFonts.body)
                    Text("Add missing metadata and cooking tips")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .disabled(config.currentAPIKey == nil)
        } header: {
            Text("AI Features")
        } footer: {
            if config.currentAPIKey == nil {
                Text("Configure your API key to enable AI features.")
            } else if config.isUsingDefaultKey {
                Text("Enable the AI features you want to use. You have \(config.remainingDailyQuota) requests remaining today.")
            } else {
                Text("Enable the AI features you want to use. Each feature consumes API credits from your personal account.")
            }
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            LabeledContent("Tokens Used", value: "\(tracker.totalTokensUsed)")
            LabeledContent("API Requests", value: "\(tracker.requestCount)")
            LabeledContent("Total Cost", value: formatCost(tracker.totalCost))

            if tracker.requestCount > 0 {
                Button(role: .destructive) {
                    resetUsage()
                } label: {
                    Label("Reset Statistics", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Usage Statistics")
        } footer: {
            Text("Tracks your AI usage for the current month. Costs are approximate based on current Anthropic pricing.")
        }
    }

    // MARK: - Test Section

    private var testSection: some View {
        Section {
            Button {
                runTest()
            } label: {
                HStack {
                    Label("Test AI Connection", systemImage: "wand.and.stars")
                    Spacer()
                    if isTestRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(config.currentAPIKey == nil || isTestRunning)

            if !testResult.isEmpty {
                Text(testResult)
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(testResult.contains("✅") ? .green : .red)
            }
        } header: {
            Text("Testing")
        } footer: {
            Text("Test your API connection and verify AI features are working correctly.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                Text("How AI Features Work")
                    .font(HeirloomFonts.bodyBold)

                Text("Heirloom uses Anthropic's Claude AI to enhance your recipe management experience:")
                    .font(HeirloomFonts.body)
                    .foregroundStyle(HeirloomColors.secondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    FeatureExplanation(
                        icon: "text.magnifyingglass",
                        title: "Ingredient Parsing",
                        description: "Accurately extracts quantities, units, and ingredient names from recipe text."
                    )

                    FeatureExplanation(
                        icon: "tag",
                        title: "Category Detection",
                        description: "Automatically categorizes recipes (e.g., dessert, main course, appetizer)."
                    )

                    FeatureExplanation(
                        icon: "sparkles",
                        title: "Recipe Enhancement",
                        description: "Adds missing information like prep time, cooking tips, and dietary notes."
                    )
                }
                .padding(.top, HeirloomSpacing.xs)
            }
            .padding(.vertical, HeirloomSpacing.xs)
        } header: {
            Text("About AI Features")
        } footer: {
            Text("All AI processing happens securely via Anthropic's API. Your recipes are not used for AI training.")
        }
    }

    // MARK: - API Key Input Sheet

    private var apiKeyInputSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .font(.system(.body, design: .monospaced))

                    Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                        Label("Get API Key", systemImage: "arrow.up.right")
                    }
                } header: {
                    Text("Personal Anthropic API Key")
                } footer: {
                    Text("Add your personal API key for unlimited usage with no daily limits. Your key is stored securely in the iOS Keychain and never shared. Free tier includes $5 credit.")
                }

                Section {
                    VStack(alignment: .leading, spacing: HeirloomSpacing.sm) {
                        Text("How to get your API key:")
                            .font(HeirloomFonts.bodyBold)

                        Text("1. Visit console.anthropic.com")
                        Text("2. Sign up or log in")
                        Text("3. Go to Settings → API Keys")
                        Text("4. Create a new key")
                        Text("5. Copy and paste it here")
                    }
                    .font(HeirloomFonts.caption1)
                    .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingAPIKeyInput = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
        }
    }

    // MARK: - Actions

    private func loadAPIKey() {
        if let key = config.apiKey(for: .anthropic) {
            apiKey = key
        }
    }

    private func saveAPIKey() {
        config.setAPIKey(apiKey, for: .anthropic)
        showingAPIKeyInput = false

        toastManager.success(
            title: "API Key Saved",
            message: "AI features are now available"
        )

        analytics.track(event: .settingChanged, properties: [
            "setting": "ai_api_key",
            "action": "configured"
        ])
    }

    private func removeAPIKey() {
        config.setAPIKey(nil, for: .anthropic)
        apiKey = ""

        // Don't disable AI features - they'll fall back to the default key
        // Only disable if there's no default key available
        if config.currentAPIKey == nil {
            config.enableAIParsing = false
            config.enableAICategories = false
            config.enableAIEnhancement = false
            toastManager.success(title: "API Key Removed")
        } else {
            toastManager.success(
                title: "Personal Key Removed",
                message: "Now using shared key with daily limits"
            )
        }

        analytics.track(event: .settingChanged, properties: [
            "setting": "ai_api_key",
            "action": "removed"
        ])
    }

    private func resetUsage() {
        tracker.reset()
        toastManager.success(title: "Usage Statistics Reset")
    }

    private func runTest() {
        isTestRunning = true
        testResult = ""

        Task {
            do {
                let response = try await aiService.complete(
                    prompt: "Say 'AI is working!' in exactly 3 words.",
                    options: AICompletionOptions(
                        model: "claude-3-haiku-20240307",
                        temperature: 0.7,
                        maxTokens: 20,
                        systemMessage: nil,
                        stopSequences: nil
                    )
                )

                await MainActor.run {
                    testResult = "✅ AI connection successful! Response: \(response.content)"
                    isTestRunning = false
                }

            } catch {
                await MainActor.run {
                    testResult = "❌ Test failed: \(error.localizedDescription)"
                    isTestRunning = false
                }
            }
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Feature Explanation Component

struct FeatureExplanation: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: HeirloomSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HeirloomColors.tomato)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(HeirloomFonts.caption1Bold)
                    .foregroundStyle(HeirloomColors.primaryText)

                Text(description)
                    .font(HeirloomFonts.caption2)
                    .foregroundStyle(HeirloomColors.secondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AISettingsView()
    }
}
