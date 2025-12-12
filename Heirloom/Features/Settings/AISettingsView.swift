import SwiftUI

/// AI service configuration and monitoring view
struct AISettingsView: View {
    @StateObject private var config = AIConfiguration.shared
    @StateObject private var tracker = AIUsageTracker.shared

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

            HStack {
                Image(systemName: config.isConfigured(provider: .anthropic) ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(config.isConfigured(provider: .anthropic) ? .green : .red)
                Text("API Key")
                Spacer()
                Text(config.isConfigured(provider: .anthropic) ? "Configured" : "Not Set")
                    .foregroundStyle(HeirloomColors.secondaryText)
                    .font(HeirloomFonts.caption1)
            }

            Button {
                showingAPIKeyInput = true
            } label: {
                Label(
                    config.isConfigured(provider: .anthropic) ? "Update API Key" : "Set API Key",
                    systemImage: "key"
                )
            }

            if config.isConfigured(provider: .anthropic) {
                Button(role: .destructive) {
                    removeAPIKey()
                } label: {
                    Label("Remove API Key", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Configuration")
        } footer: {
            Text("Configure your Anthropic API key to enable AI-powered features. Get your key at console.anthropic.com")
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
            .disabled(!config.isConfigured(provider: .anthropic))

            Toggle(isOn: $config.enableAICategories) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Category Detection")
                        .font(HeirloomFonts.body)
                    Text("Automatically detect recipe categories")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .disabled(!config.isConfigured(provider: .anthropic))

            Toggle(isOn: $config.enableAIEnhancement) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Recipe Enhancement")
                        .font(HeirloomFonts.body)
                    Text("Add missing metadata and cooking tips")
                        .font(HeirloomFonts.caption1)
                        .foregroundStyle(HeirloomColors.secondaryText)
                }
            }
            .disabled(!config.isConfigured(provider: .anthropic))
        } header: {
            Text("AI Features")
        } footer: {
            if !config.isConfigured(provider: .anthropic) {
                Text("Configure your API key to enable AI features.")
            } else {
                Text("Enable the AI features you want to use. Each feature consumes API credits.")
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
            .disabled(!config.isConfigured(provider: .anthropic) || isTestRunning)

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
                    Text("Anthropic API Key")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain and never shared. Free tier includes $5 credit.")
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

        ToastManager.shared.success(
            title: "API Key Saved",
            message: "AI features are now available"
        )

        AnalyticsService.shared.track(event: .settingChanged, properties: [
            "setting": "ai_api_key",
            "action": "configured"
        ])
    }

    private func removeAPIKey() {
        config.setAPIKey(nil, for: .anthropic)
        apiKey = ""

        // Disable all AI features
        config.enableAIParsing = false
        config.enableAICategories = false
        config.enableAIEnhancement = false

        ToastManager.shared.success(title: "API Key Removed")

        AnalyticsService.shared.track(event: .settingChanged, properties: [
            "setting": "ai_api_key",
            "action": "removed"
        ])
    }

    private func resetUsage() {
        tracker.reset()
        ToastManager.shared.success(title: "Usage Statistics Reset")
    }

    private func runTest() {
        isTestRunning = true
        testResult = ""

        Task {
            do {
                let service = AnthropicAIService.shared
                let response = try await service.complete(
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
