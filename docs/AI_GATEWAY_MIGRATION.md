# AI Gateway Migration Guide

Migrate from direct API calls to secure Firebase backend gateway.

## Why Migrate?

**Current (Insecure) ❌**:
```
iOS App → Direct HTTP → OpenAI/Anthropic API
         [API keys in app binary - extractable!]
```

**New (Secure) ✅**:
```
iOS App → Firebase Auth Token → Cloud Functions → OpenAI/Anthropic API
          [NO keys in app!]      [Keys server-side only]
```

## Benefits

- 🔒 **Security**: API keys never in client app
- 💰 **Cost Control**: Rate limiting and usage tracking
- 📊 **Analytics**: Centralized logging and monitoring
- 🔄 **Flexibility**: Change AI providers without app updates
- 🛡️ **Protection**: Prevent API key theft and abuse

## Migration Steps

### Step 1: Deploy Firebase Functions

```bash
cd functions
npm install

# Set API keys (server-side only)
firebase functions:config:set anthropic.key="sk-ant-YOUR_KEY"
firebase functions:config:set openai.key="sk-proj-YOUR_KEY"

# Deploy
firebase deploy --only functions
```

### Step 2: Update ServiceContainer

**File**: `Core/App/ServiceContainer.swift`

```swift
// Add feature flag
private var useAIGateway: Bool {
    #if DEBUG
    return UserDefaults.standard.bool(forKey: "use_ai_gateway")
    #else
    return true  // Always use gateway in production
    #endif
}

// In registerServices()
func registerAIServices() {
    let aiConfiguration = AIConfiguration(
        analytics: analytics,
        keychain: Keychain()
    )
    register(AIConfigurationProtocol.self, instance: aiConfiguration)

    let usageTracker = AIUsageTracker(
        analytics: analytics,
        aiConfiguration: aiConfiguration
    )

    // Use gateway or direct service
    if useAIGateway {
        Log.info("Using Firebase AI Gateway (secure)", category: .startup)

        let gatewayService = FirebaseAIGatewayService(
            configuration: aiConfiguration,
            usageTracker: usageTracker
        )
        register(AIServiceProtocol.self, instance: gatewayService)
    } else {
        Log.warning("Using direct AI service (API keys in app!)", category: .startup)

        let anthropicService = AnthropicAIService(
            configuration: aiConfiguration,
            usageTracker: usageTracker
        )
        register(AIServiceProtocol.self, instance: anthropicService)
    }
}
```

### Step 3: Test with Feature Flag

**Debug Settings**:

```swift
// Add to SettingsView or create debug menu
Toggle("Use AI Gateway", isOn: Binding(
    get: { UserDefaults.standard.bool(forKey: "use_ai_gateway") },
    set: { UserDefaults.standard.set($0, forKey: "use_ai_gateway") }
))
.onChange(of: useAIGateway) { _, _ in
    // Restart app or reinitialize services
}
```

### Step 4: Test All AI Features

Test each AI operation:

1. **Recipe Import (OCR)**
   - [ ] Scan recipe from book
   - [ ] Verify extraction works
   - [ ] Check quality vs. direct API

2. **Ingredient Parsing**
   - [ ] Import recipe with ingredients
   - [ ] Verify parsing works correctly

3. **Recipe Generation**
   - [ ] Generate recipe from prompt
   - [ ] Verify output quality

4. **Recipe Enhancement**
   - [ ] Ask to improve recipe
   - [ ] Verify suggestions work

### Step 5: Monitor and Verify

```bash
# Watch function logs
firebase functions:log --only aiComplete

# Check for errors
firebase functions:log | grep ERROR

# View rate limiting
firebase firestore:data:get rateLimits

# View usage stats
firebase firestore:data:get userCosts
```

### Step 6: Remove API Keys from iOS App

**CRITICAL: Only after gateway is fully tested!**

1. **Remove from Config.xcconfig**:
```xcconfig
// BEFORE
DEFAULT_ANTHROPIC_KEY = sk-ant-api03-...
DEFAULT_OPENAI_KEY = sk-proj-...

// AFTER
DEFAULT_ANTHROPIC_KEY = REMOVED_USE_GATEWAY
DEFAULT_OPENAI_KEY = REMOVED_USE_GATEWAY
```

2. **Update AIConfiguration**:
```swift
private func defaultAPIKey(for provider: AIProvider) -> String? {
    // GATEWAY ONLY - No default keys in app
    return nil
}
```

3. **Remove old services** (optional):
```bash
git rm Heirloom/Core/Services/AI/Clients/AnthropicAIService.swift
# Keep for reference or remove after thorough testing
```

4. **Clean build**:
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Heirloom-*

# Rebuild
xcodebuild clean build
```

5. **Verify with binary inspection**:
```bash
# Check that no API keys are in binary
strings ./DerivedData/.../Heirloom.app/Heirloom | grep "sk-ant"
strings ./DerivedData/.../Heirloom.app/Heirloom | grep "sk-proj"

# Should return nothing!
```

### Step 7: Update App Review Submission

**App Store Connect Notes**:
```
Security Improvements:
- All AI API keys moved to secure backend
- No API keys in client application
- Requests authenticated via Firebase Auth
- Rate limiting and cost controls implemented
```

## Rollback Plan

If issues arise:

```swift
// Quickly disable gateway
private var useAIGateway: Bool {
    return false  // Revert to direct API
}
```

Or via remote config:
```swift
private var useAIGateway: Bool {
    return RemoteConfig.remoteConfig().configValue(forKey: "use_ai_gateway").boolValue
}
```

## Testing Checklist

### Functional Testing
- [ ] Recipe OCR extraction works
- [ ] Ingredient parsing works
- [ ] Recipe generation works
- [ ] Recipe enhancement works
- [ ] Error handling works properly
- [ ] Rate limiting prevents abuse
- [ ] Cost tracking logs correctly

### Security Testing
- [ ] No API keys in app binary (use `strings` command)
- [ ] No API keys in source code
- [ ] No API keys in Config.xcconfig
- [ ] Authentication required for all requests
- [ ] Unauthorized requests rejected

### Performance Testing
- [ ] Latency acceptable (< 2s for most requests)
- [ ] Vision requests complete within timeout
- [ ] No memory leaks
- [ ] Handles network errors gracefully

### Cost Testing
- [ ] Usage tracked correctly in Firestore
- [ ] Rate limits enforced
- [ ] Cost calculations accurate
- [ ] Daily quotas reset properly

## Common Issues

### "Unauthenticated" Error

**Cause**: User not signed in to Firebase Auth

**Fix**: Ensure user is authenticated before making AI requests:
```swift
guard Auth.auth().currentUser != nil else {
    throw AIError.unauthorized
}
```

### "Rate limit exceeded"

**Cause**: User exceeded daily quota

**Fix**: Wait until quota resets or increase limit in `rate-limiter.ts`

### Higher Latency

**Cause**: Additional network hop (app → functions → AI API)

**Expected**: ~200-500ms additional latency
**Mitigation**: Use faster models (Haiku, GPT-4o-mini)

### Function Timeout

**Cause**: AI request takes too long

**Fix**: Increase timeout in function definition:
```typescript
export const aiComplete = functions
  .runWith({ timeoutSeconds: 120, memory: '1GB' })
  .https.onCall(async (data, context) => { ... });
```

## Success Criteria

✅ **Gateway is ready when**:
- All AI features work through gateway
- No API keys remain in iOS app
- Rate limiting enforced correctly
- Cost tracking accurate
- Latency acceptable (< 3s for vision)
- No security warnings in app review

## Timeline Estimate

- **Week 1**: Deploy functions, test with feature flag
- **Week 2**: Full testing, monitor performance
- **Week 3**: Remove old keys, clean up code
- **Week 4**: App Store submission with security notes

## Support

Issues? Check:
1. Function logs: `firebase functions:log`
2. Firestore console: Check rateLimits and userCosts
3. iOS logs: Look for AI gateway errors
4. This guide: Re-read troubleshooting section
