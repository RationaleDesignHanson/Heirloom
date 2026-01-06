import Foundation

/// Quick test script to verify Anthropic AI service works
/// Run this in Xcode or via command line to test the API

@MainActor
class AIAPITest {
    static func run() async {
        Log.info("Testing Anthropic AI Service", category: .general)
        Log.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .general)

        // Step 1: Check configuration
        Log.info("Step 1: Checking configuration", category: .general)
        let config = ServiceContainer.shared.resolve(AIConfiguration.self)

        if config.isConfigured(provider: .anthropic) {
            Log.info("Anthropic API key is configured", category: .general)
        } else {
            Log.warning("Anthropic API key NOT configured", category: .general)
            Log.info("To configure: 1. Get API key from: https://console.anthropic.com/", category: .general)
            Log.info("2. Get AIConfiguration from ServiceContainer and call setAPIKey(\"sk-ant-...\", for: .anthropic)", category: .general)
            return
        }

        // Step 2: Test simple completion
        Log.info("Step 2: Testing simple completion", category: .general)
        do {
            let service = ServiceContainer.shared.resolve(AIServiceProtocol.self)
            let response = try await service.complete(
                prompt: "Say 'Hello from Heirloom!' in exactly 3 words.",
                options: AICompletionOptions(
                    model: "claude-3-haiku-20240307",
                    temperature: 0.7,
                    maxTokens: 50,
                    systemMessage: "You are a helpful assistant.",
                    stopSequences: nil
                )
            )

            Log.info("API call successful", category: .general, metadata: [
                "response": response.content,
                "model": response.model,
                "tokensUsed": response.usage.totalTokens,
                "cost": response.usage.totalCost
            ])

        } catch let error as AIError {
            Log.error("API call failed", category: .general, metadata: ["error": error.errorDescription ?? "Unknown error", "context": error.context])
        } catch {
            Log.error("Unexpected error", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 3: Test structured completion (JSON response)
        Log.info("Step 3: Testing structured completion (JSON)", category: .general)

        struct IngredientTest: Codable {
            let quantity: Double?
            let unit: String?
            let name: String
        }

        do {
            let service = ServiceContainer.shared.resolve(AIServiceProtocol.self)
            let ingredient = try await service.completeStructured(
                prompt: """
                Parse this ingredient: "2 cups flour"

                Return JSON:
                {
                  "quantity": 2.0,
                  "unit": "cups",
                  "name": "flour"
                }
                """,
                schema: IngredientTest.self
            )

            Log.info("Structured completion successful", category: .general, metadata: [
                "quantity": ingredient.quantity ?? 0,
                "unit": ingredient.unit ?? "none",
                "name": ingredient.name
            ])

        } catch let error as AIError {
            Log.error("Structured completion failed", category: .general, metadata: ["error": error.errorDescription ?? "Unknown error"])
        } catch {
            Log.error("Unexpected error", category: .general, metadata: ["error": error.localizedDescription])
        }

        // Step 4: Show usage statistics
        Log.info("Step 4: Usage statistics", category: .general)
        let tracker = ServiceContainer.shared.resolve(AIUsageTracker.self)
        Log.info("Usage statistics", category: .general, metadata: [
            "totalTokensUsed": tracker.totalTokensUsed,
            "totalCost": tracker.totalCost,
            "requestCount": tracker.requestCount
        ])

        Log.info("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", category: .general)
        Log.info("Test complete", category: .general)
    }
}

// MARK: - How to Run This Test

/*

 Option 1: Run in Xcode (Recommended)
 ────────────────────────────────────
 1. Open Heirloom.xcodeproj
 2. Add this file to the project
 3. Add a button in a view:

    Button("Test AI API") {
        Task {
            await AIAPITest.run()
        }
    }

 4. Run the app and tap the button
 5. Check Xcode console for output


 Option 2: Run as Script (Advanced)
 ──────────────────────────────────

 Create a command-line target in Xcode:
 1. File → New → Target → Command Line Tool
 2. Name it "AITest"
 3. Add AI service files to target
 4. Call AIAPITest.run() in main.swift
 5. Run: swift run AITest


 Setup API Key:
 ─────────────

 // In your app startup or settings:
 let config = ServiceContainer.shared.resolve(AIConfiguration.self)
 config.setAPIKey("sk-ant-api03-YOUR-KEY-HERE", for: .anthropic)

 // Or test without UI by modifying this file:
 // Add at the top of run():
 // let config = ServiceContainer.shared.resolve(AIConfiguration.self)
 // config.setAPIKey("sk-ant-...", for: .anthropic)


 Get API Key:
 ───────────
 1. Go to: https://console.anthropic.com/
 2. Sign up / Log in
 3. Go to Settings → API Keys
 4. Create a new key
 5. Copy the key (starts with sk-ant-)
 6. Paste into AIConfiguration

 Free tier includes $5 credit!

 */
