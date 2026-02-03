# Heirloom Firebase Cloud Functions - AI Gateway

Secure backend proxy for all AI service requests. API keys stay server-side.

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Configure API Keys (Server-Side Only)

**Option A: Set All Keys at Once (Recommended)**

```bash
# Set all keys in one command
firebase functions:config:set \
  anthropic.key="sk-ant-api03-YOUR_KEY_HERE" \
  openai.key="sk-proj-YOUR_KEY_HERE" \
  google.vision_key="YOUR_GOOGLE_VISION_KEY" \
  brave.search_key="YOUR_BRAVE_SEARCH_KEY"

# View current config
firebase functions:config:get
```

**Option B: Set Keys Individually**

```bash
firebase functions:config:set anthropic.key="sk-ant-api03-YOUR_KEY_HERE"
firebase functions:config:set openai.key="sk-proj-YOUR_KEY_HERE"
firebase functions:config:set google.vision_key="YOUR_GOOGLE_VISION_KEY"
firebase functions:config:set brave.search_key="YOUR_BRAVE_SEARCH_KEY"
```

**Option B: Environment Variables (Local Development)**

```bash
# Create .env file in functions/ directory
echo "ANTHROPIC_API_KEY=sk-ant-api03-YOUR_KEY_HERE" > .env
echo "OPENAI_API_KEY=sk-proj-YOUR_KEY_HERE" >> .env
```

⚠️ **NEVER commit .env files to git!**

### 3. Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:aiComplete
```

## Local Testing with Emulator

```bash
# Start Firebase emulators
firebase emulators:start

# Your functions will be available at:
# http://localhost:5001/YOUR_PROJECT_ID/us-central1/aiComplete
```

In your iOS app, enable emulator mode:

```swift
// In FirebaseAIGatewayService.swift
#if DEBUG
functions.useEmulator(withHost: "localhost", port: 5001)
#endif
```

## Available Functions

### 1. `aiComplete`

Complete a text prompt with AI.

**Request**:
```json
{
  "prompt": "Extract ingredients from this recipe: ...",
  "provider": "anthropic",
  "model": "claude-3-haiku-20240307",
  "temperature": 0.7,
  "maxTokens": 1024,
  "systemMessage": "You are a recipe extraction assistant"
}
```

**Response**:
```json
{
  "content": "The extracted text...",
  "model": "claude-3-haiku-20240307",
  "usage": {
    "input_tokens": 150,
    "output_tokens": 200,
    "total_tokens": 350
  }
}
```

### 2. `aiCompleteStructured`

Complete with JSON output.

**Request**: Same as `aiComplete`

**Response**:
```json
{
  "content": "{\"ingredients\": [...]}",
  "model": "claude-3-haiku-20240307",
  "usage": { ... }
}
```

### 3. `aiCompleteWithVision`

Complete with vision (image + text).

**Request**:
```json
{
  "imageBase64": "base64_encoded_image_data",
  "prompt": "Extract recipe from this image",
  "provider": "anthropic",
  "model": "claude-sonnet-4-5-20250929",
  "structured": true
}
```

### 4. `checkUserRateLimit`

Check user's rate limit status.

**Request**:
```json
{
  "operation": "ai_complete"
}
```

**Response**:
```json
{
  "count": 42,
  "limit": 100,
  "remaining": 58,
  "resetAt": "2026-02-03T00:00:00Z"
}
```

### 5. `getUserUsageStats`

Get user's AI usage statistics.

**Response**:
```json
{
  "totalCost": 1.23,
  "totalTokens": 50000,
  "operations": 42,
  "lastUpdated": "2026-02-02T15:30:00Z"
}
```

## Rate Limits

Default limits per user per day:
- `ai_complete`: 100 requests/day
- `ai_vision`: 50 requests/day

Limits reset at midnight UTC.

## Cost Tracking

All AI usage is logged to Firestore:
- Collection: `aiUsage` (per-request logs)
- Collection: `userCosts` (aggregated per user)

## Security

✅ **What's Secure**:
- API keys never leave the server
- All requests authenticated via Firebase Auth
- Rate limiting prevents abuse
- Cost tracking for billing control

❌ **What's NOT in the client**:
- No API keys in iOS binary
- No direct API calls to OpenAI/Anthropic
- No way to extract keys via reverse engineering

## Monitoring

View function logs:

```bash
# Tail all logs
firebase functions:log

# Filter specific function
firebase functions:log --only aiComplete

# View errors only
firebase functions:log --only aiComplete | grep ERROR
```

## Troubleshooting

### "API key not configured"

Check that API keys are set:
```bash
firebase functions:config:get
```

### "Unauthenticated" error

Ensure user is signed in to Firebase Auth in iOS app.

### "Rate limit exceeded"

User has exceeded daily quota. Wait until reset or increase limits in `rate-limiter.ts`.

### "Function timeout"

Increase timeout in function definition:
```typescript
export const aiComplete = functions
  .runWith({ timeoutSeconds: 120 })
  .https.onCall(async (data, context) => { ... });
```

## Updating iOS App

After deploying functions, update the iOS app to use FirebaseAIGatewayService:

```swift
// In ServiceContainer.swift
if useAIGateway {  // Feature flag
    let gatewayService = FirebaseAIGatewayService(
        configuration: aiConfiguration,
        usageTracker: usageTracker
    )
    register(AIServiceProtocol.self, instance: gatewayService)
} else {
    // Old direct API service
    let anthropicService = AnthropicAIService(
        configuration: aiConfiguration,
        usageTracker: usageTracker
    )
    register(AIServiceProtocol.self, instance: anthropicService)
}
```

## Migration Checklist

- [ ] Deploy Firebase Functions
- [ ] Test with emulator locally
- [ ] Update iOS app to use FirebaseAIGatewayService
- [ ] Test on device with real AI requests
- [ ] Monitor logs for errors
- [ ] Verify rate limiting works
- [ ] Check cost tracking in Firestore
- [ ] Remove old API keys from iOS app
- [ ] Remove API keys from Config.xcconfig
- [ ] Submit app to App Review (mention no keys in binary)

## Cost Optimization

To reduce costs:

1. **Use cheaper models**: Claude Haiku, GPT-4o-mini
2. **Reduce token limits**: Lower maxTokens in requests
3. **Cache responses**: Store common extractions
4. **Batch operations**: Combine multiple small requests
5. **Stricter rate limits**: Lower daily quotas per user

## Support

Questions? Check:
- Firebase Functions docs: https://firebase.google.com/docs/functions
- Anthropic API: https://docs.anthropic.com
- OpenAI API: https://platform.openai.com/docs
