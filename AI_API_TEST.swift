import Foundation

/// Quick test script to verify Anthropic AI service works
/// Run this in Xcode or via command line to test the API

@MainActor
class AIAPITest {
    static func run() async {
        print("🧪 Testing Anthropic AI Service...")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Step 1: Check configuration
        print("\n1️⃣ Checking configuration...")
        let config = AIConfiguration.shared

        if config.isConfigured(provider: .anthropic) {
            print("✅ Anthropic API key is configured")
        } else {
            print("❌ Anthropic API key NOT configured")
            print("👉 To configure:")
            print("   1. Get API key from: https://console.anthropic.com/")
            print("   2. Run this code in app:")
            print("      AIConfiguration.shared.setAPIKey(\"sk-ant-...\", for: .anthropic)")
            return
        }

        // Step 2: Test simple completion
        print("\n2️⃣ Testing simple completion...")
        do {
            let service = AnthropicAIService.shared
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

            print("✅ API call successful!")
            print("   Response: \(response.content)")
            print("   Model: \(response.model)")
            print("   Tokens used: \(response.usage.totalTokens)")
            print("   Cost: $\(response.usage.totalCost)")

        } catch let error as AIError {
            print("❌ API call failed: \(error.errorDescription ?? "Unknown error")")
            print("   Context: \(error.context)")
        } catch {
            print("❌ Unexpected error: \(error)")
        }

        // Step 3: Test structured completion (JSON response)
        print("\n3️⃣ Testing structured completion (JSON)...")

        struct IngredientTest: Codable {
            let quantity: Double?
            let unit: String?
            let name: String
        }

        do {
            let service = AnthropicAIService.shared
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

            print("✅ Structured completion successful!")
            print("   Quantity: \(ingredient.quantity ?? 0)")
            print("   Unit: \(ingredient.unit ?? "none")")
            print("   Name: \(ingredient.name)")

        } catch let error as AIError {
            print("❌ Structured completion failed: \(error.errorDescription ?? "Unknown error")")
        } catch {
            print("❌ Unexpected error: \(error)")
        }

        // Step 4: Show usage statistics
        print("\n4️⃣ Usage statistics...")
        let tracker = AIUsageTracker.shared
        print("   Total tokens used: \(tracker.totalTokensUsed)")
        print("   Total cost: $\(tracker.totalCost)")
        print("   Request count: \(tracker.requestCount)")

        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Test complete!")
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
 AIConfiguration.shared.setAPIKey("sk-ant-api03-YOUR-KEY-HERE", for: .anthropic)

 // Or test without UI by modifying this file:
 // Add at the top of run():
 // AIConfiguration.shared.setAPIKey("sk-ant-...", for: .anthropic)


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
