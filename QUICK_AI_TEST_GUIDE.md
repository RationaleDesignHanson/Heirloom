# Quick AI API Test Guide

## 🎯 Goal
Verify the Anthropic AI service works before building features.

---

## Step 1: Get Anthropic API Key (2 minutes)

1. Go to: **https://console.anthropic.com/**
2. Sign up or log in
3. Navigate to: **Settings → API Keys**
4. Click: **Create Key**
5. Copy the key (starts with `sk-ant-api03-...`)

**Note:** Free tier includes **$5 credit** (enough for ~800 recipe imports!)

---

## Step 2: Add AI Files to Xcode (3 minutes)

### Option A: Drag & Drop (Easiest)

1. Open **Heirloom.xcodeproj** in Xcode
2. In Project Navigator (left sidebar), find **Core/Services/**
3. Open Finder to `/Users/matthanson/Heirloom/Heirloom/Core/Services/AI/`
4. **Drag the entire `AI` folder** into Xcode under `Core/Services/`
5. In the dialog:
   - ✅ Check "Copy items if needed" **OFF** (files already in place)
   - ✅ Check "Create groups" (not folder references)
   - ✅ Check "Add to targets: Heirloom"
6. Click **Finish**

### Option B: Add Files Menu

1. Open **Heirloom.xcodeproj** in Xcode
2. Right-click **Core/Services/** folder in Project Navigator
3. Select **Add Files to "Heirloom"...**
4. Navigate to: `Heirloom/Core/Services/AI/`
5. Select the **AI** folder
6. Options:
   - ✅ Uncheck "Copy items if needed"
   - ✅ Select "Create groups"
   - ✅ Add to target: Heirloom
7. Click **Add**

### Verify Files Added

You should see in Xcode Project Navigator:
```
Heirloom
└── Core
    └── Services
        └── AI
            ├── Protocols
            │   └── AIServiceProtocol.swift
            ├── Clients
            │   └── AnthropicAIService.swift
            ├── Configuration
            │   └── AIConfiguration.swift
            └── Utils
                └── AIError.swift
```

---

## Step 3: Add Test Button to App (2 minutes)

### Quick Test in Existing View

1. Open **RecipeListView.swift** (or any view)
2. Add this button to the toolbar:

```swift
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("🧪 Test AI") {
            Task {
                await testAIAPI()
            }
        }
    }
}

// Add this function to the view
private func testAIAPI() async {
    // Set API key (replace with your actual key)
    AIConfiguration.shared.setAPIKey("sk-ant-api03-YOUR-KEY-HERE", for: .anthropic)

    // Run test
    await AIAPITest.run()
}
```

3. **Replace `YOUR-KEY-HERE`** with your actual Anthropic API key

### Or Add Settings Screen (Better)

Create a dedicated AI settings view:

```swift
struct AISettingsView: View {
    @StateObject private var config = AIConfiguration.shared
    @State private var apiKey: String = ""
    @State private var isTestRunning = false
    @State private var testOutput: String = ""

    var body: some View {
        Form {
            Section("API Configuration") {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)

                Button("Save API Key") {
                    config.setAPIKey(apiKey, for: .anthropic)
                }
                .disabled(apiKey.isEmpty)
            }

            Section("Test") {
                Button("Run API Test") {
                    isTestRunning = true
                    Task {
                        await AIAPITest.run()
                        isTestRunning = false
                    }
                }
                .disabled(!config.isConfigured(provider: .anthropic) || isTestRunning)

                if isTestRunning {
                    ProgressView("Testing...")
                }
            }

            Section("Usage") {
                LabeledContent("Tokens Used", value: "\(AIUsageTracker.shared.totalTokensUsed)")
                LabeledContent("Total Cost", value: "$\(AIUsageTracker.shared.totalCost)")
                LabeledContent("Requests", value: "\(AIUsageTracker.shared.requestCount)")
            }
        }
        .navigationTitle("AI Settings")
    }
}
```

---

## Step 4: Run the Test (1 minute)

1. **Build** the app (⌘+B)
2. **Run** the app (⌘+R)
3. Tap the **"🧪 Test AI"** button (or navigate to AI settings)
4. **Watch the Xcode console** for output

### Expected Output

```
🧪 Testing Anthropic AI Service...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣ Checking configuration...
✅ Anthropic API key is configured

2️⃣ Testing simple completion...
✅ API call successful!
   Response: Hello from Heirloom!
   Model: claude-3-haiku-20240307
   Tokens used: 25
   Cost: $0.000031

3️⃣ Testing structured completion (JSON)...
✅ Structured completion successful!
   Quantity: 2.0
   Unit: cups
   Name: flour

4️⃣ Usage statistics...
   Total tokens used: 78
   Total cost: $0.000094
   Request count: 2

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Test complete!
```

---

## Troubleshooting

### ❌ "API key NOT configured"

**Solution:** Make sure you called:
```swift
AIConfiguration.shared.setAPIKey("sk-ant-...", for: .anthropic)
```

### ❌ "Build failed" - Cannot find 'AIConfiguration'

**Solution:** Add AI files to Xcode project (see Step 2)

### ❌ "401 Unauthorized"

**Solution:**
- Check API key is correct
- Verify key starts with `sk-ant-api03-`
- Generate new key at https://console.anthropic.com/

### ❌ "429 Rate Limited"

**Solution:**
- You're making too many requests
- Wait 60 seconds and try again
- Free tier has rate limits

### ❌ "Network error"

**Solution:**
- Check internet connection
- Verify firewall/VPN isn't blocking anthropic.com
- Try again in a moment

---

## What the Test Does

1. **Checks Configuration** - Verifies API key exists
2. **Simple Completion** - Sends basic prompt, gets text response
3. **Structured Completion** - Tests JSON parsing (for ingredient data)
4. **Shows Usage** - Displays token count and cost

---

## Cost Breakdown

Test uses approximately:
- **78 tokens** (~25 input + 53 output)
- **Cost: $0.0001** (less than 1/100th of a cent!)

This validates:
- ✅ API key works
- ✅ Network connection works
- ✅ JSON parsing works
- ✅ Error handling works
- ✅ Cost tracking works

---

## Next Steps After Test Passes

Once the test succeeds:

1. ✅ **Implement AIIngredientParser**
   - Use the structured completion pattern from test
   - Parse ingredient text into structured data

2. ✅ **Integrate into RecipeImportView**
   - Call AIIngredientParser after web scraping
   - Fall back to existing parser on errors

3. ✅ **Add AI Settings UI**
   - Let users configure API key
   - Show usage statistics
   - Toggle AI features on/off

4. ✅ **Test with Real Recipes**
   - Import recipes from websites
   - Verify AI parsing accuracy
   - Monitor token usage

5. ✅ **Ship v1.1.0 to TestFlight**

---

## Security Notes

⚠️ **Never commit API keys to git!**

The key is stored securely in iOS Keychain:
- ✅ Encrypted at rest
- ✅ Not backed up to iCloud
- ✅ Accessible only after device unlock
- ✅ Sandboxed to your app

To keep keys out of code:
```swift
// ❌ BAD - Don't hardcode in code
let apiKey = "sk-ant-api03-..."

// ✅ GOOD - User enters in settings
AIConfiguration.shared.setAPIKey(userProvidedKey, for: .anthropic)
```

---

## API Key Safety Checklist

Before committing code:
- [ ] No API keys in Swift files
- [ ] No API keys in comments
- [ ] Keys only set via user input
- [ ] .gitignore includes any test files with keys

---

## Questions?

See full documentation:
- **PHASE_2_AI_SERVICES_PLAN.md** - Complete roadmap
- **AI_FOUNDATION_SUMMARY.md** - Implementation details
- **README_ZERO_INBOX_ANALYSIS.md** - Zero project patterns

Ready to build AI features! 🚀
