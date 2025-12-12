# Zero Inbox AI Infrastructure Analysis for Heirloom

## Executive Summary

The Zero Inbox project demonstrates a comprehensive, production-ready AI infrastructure that can be substantially reused for Heirloom. The key strength is a **protocol-based, modular architecture** with clear separation of concerns, particularly strong in:
- Token management and API credential handling
- Error handling patterns with structured logging
- Multi-AI service support (OpenAI, Gemini)
- Type-safe Swift protocols for dependency injection
- Comprehensive request/response handling

---

## 1. AI Services & Clients

### 1.1 OpenAI Integration
**Location**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/agents/`

Files:
- `test-openai-api.ts` - Basic API testing
- `generate-with-openai.ts` - Production generation logic (200+ emails)
- `generate-fast.ts` - Simplified/fast generation

**Key Pattern**:
```typescript
import OpenAI from 'openai';

const OPENAI_API_KEY = fs.readFileSync('/path/to/key.txt', 'utf8').trim();
const openai = new OpenAI({ apiKey: OPENAI_API_KEY });

const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [...],
  response_format: { type: 'json_object' },
  temperature: 0.9,
  max_tokens: 4000
});
```

**Models Used**:
- `gpt-4o` - High quality, slightly slower
- `gpt-4o-mini` - Fast, cheaper alternative
- Structured output via `response_format: { type: 'json_object' }`

---

### 1.2 Google Gemini Integration
**Location**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Services/SmartReplyService.swift`

```swift
class SmartReplyService {
    private let geminiAPIKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent"
    
    init() {
        self.geminiAPIKey = AppEnvironment.geminiAPIKey
    }
    
    func generateSmartReplies(for email: EmailCard) async throws -> [String] {
        let response = try await callGeminiAPI(prompt: prompt)
        let replies = parseReplies(from: response)
        return replies
    }
}
```

**Key Points**:
- v1 API endpoint (not v1beta)
- Supports `gemini-1.5-flash` model
- Structured prompt engineering
- Tone personalization support

---

### 1.3 Email Service Protocol (Swift)
**Location**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Protocols/EmailServiceProtocol.swift`

Excellent example of protocol-based architecture:
```swift
protocol EmailServiceProtocol {
    // Authentication
    func authenticateDemo(password: String) async throws -> String
    func authenticateGmail(presentationAnchor: ASPresentationAnchor) async throws -> String
    func authenticateMicrosoft(presentationAnchor: ASPresentationAnchor) async throws -> String
    
    // Operations
    func fetchEmails(maxResults: Int, timeRange: EmailTimeRange) async throws -> [EmailCard]
    func performAction(emailId: String, action: EmailBasicAction) async throws
    
    // AI Features
    func generateReply(emailId: String) async throws -> String
    func fetchSmartReplies(emailId: String) async throws -> [String]
}
```

**Reusable Pattern**: Protocol definition with concrete implementation separation enables:
- Easy testing with mocks
- Provider-specific implementations
- Clean dependency injection

---

## 2. API Key Management

### 2.1 Zero's Approach (Lessons & Warnings)
**Current Implementation** (not ideal):
```typescript
// Found in multiple files:
const OPENAI_API_KEY = fs.readFileSync('/Users/matthanson/Desktop/openaik.txt', 'utf8').trim();
```

**Problems**:
- Hardcoded file paths
- API key in repository (security risk)
- Not using environment variables

### 2.2 Recommended Patterns in Zero

**Backend (Node.js)**:
- Uses `dotenv` for `.env` files
- Environment variables: `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`
- Token storage in dedicated directory: `/data/tokens`

**iOS (Swift)**:
```swift
// From LaunchConfiguration.swift & SmartReplyService.swift
private let geminiAPIKey: String = AppEnvironment.geminiAPIKey

// AppEnvironment handles loading from Info.plist or secure storage
```

### 2.3 What Heirloom Should Do
For **Heirloom**, adopt Zero's backend patterns:
1. Use environment variables exclusively
2. Implement secure token storage (Keychain on iOS, secure files on backend)
3. Separate API keys per service (OpenAI, Anthropic, Google)
4. Use `.env.example` (never commit `.env`)

---

## 3. Token Management & Error Handling

### 3.1 Comprehensive Token Manager
**Location**: `/Users/matthanson/Zer0_Inbox/backend/shared/utils/token-manager.js`

**Features**:
```javascript
// Automatic refresh with 5-minute buffer
const REFRESH_BUFFER = 5 * 60 * 1000;

// Proactive refresh before expiry
async function refreshTokenIfNeeded(userId, provider) {
  if (!isTokenExpiring(tokens)) {
    return tokens; // Still fresh
  }
  
  const oauth2Client = createOAuth2Client(userId, provider, tokens);
  const { credentials } = await oauth2Client.refreshAccessToken();
  
  // Automatic persistence via 'tokens' event
  return credentials;
}

// Health status checks
function getTokenHealth(userId, provider) {
  return {
    status: 'healthy' | 'expiring' | 'expired' | 'missing',
    needsReauth: boolean,
    expiresAt: timestamp,
    minutesUntilExpiry: number
  };
}
```

**Reusable Elements**:
1. Automatic token refresh mechanism
2. Track failed refresh attempts (max 3 before re-auth required)
3. Health status API for monitoring
4. Clear re-authentication flags

---

### 3.2 Error Handling Pattern (Backend)
**Location**: `/Users/matthanson/Zer0_Inbox/backend/services/classifier/server.js`

```javascript
app.post('/api/classify', async (req, res) => {
  try {
    // Input validation FIRST
    if (!req.body || typeof req.body !== 'object') {
      logger.error('Invalid request body', { body: req.body });
      return res.status(400).json({ error: 'Invalid request: body must be a JSON object' });
    }
    
    const { email } = req.body;
    
    if (!email) {
      logger.error('Missing email object in request', { body: req.body });
      return res.status(400).json({ error: 'Missing email object in request body' });
    }
    
    if (!email.subject || !email.from) {
      logger.error('Invalid email data: missing required fields', {
        hasSubject: !!email.subject,
        hasFrom: !!email.from
      });
      return res.status(400).json({ error: 'Invalid email data: subject and from are required' });
    }
    
    // Processing
    let classification;
    if (USE_ACTION_FIRST) {
      classification = await classifyEmailActionFirst(email);
    } else if (USE_ENHANCED_CLASSIFIER) {
      classification = classifyEmailEnhanced(email);
    }
    
    // Graceful fallbacks
    const isFallback = !classification.intent || 
                       classification.intent === 'generic.transactional';
    
    logger.info('Classification complete', {
      intent: classification.intent,
      isFallback,
      processingTimeMs: Date.now() - startTime
    });
    
    res.json(classification);
    
  } catch (error) {
    logger.error('Error classifying email', {
      error: error.message,
      stack: error.stack
    });
    res.status(500).json({ error: 'Failed to classify email' });
  }
});
```

**Key Patterns**:
1. **Input validation before processing** - type checking, required fields
2. **Structured logging** - includes context (field presence, metrics)
3. **Graceful degradation** - fallback intents when uncertain
4. **Metric tracking** - processing time, classification metrics
5. **Explicit error responses** - different status codes (400 vs 500)

---

### 3.3 Request Logging & Security
**Location**: `/Users/matthanson/Zer0_Inbox/backend/shared/middleware/request-logger.js`

```javascript
const SUSPICIOUS_PATTERNS = {
    highFrequency: 30,      // requests per minute
    burstThreshold: 10,     // requests in 10 seconds
    burstWindow: 10000,     // ms
    botPatterns: [
        /curl/i, /wget/i, /python-requests/i, /scrapy/i, /bot/i, /crawler/i
    ]
};

function trackRequest(ip, userAgent, path) {
    const analysis = {
        totalRequests: tracker.count,
        requestsPerMinute: totalRequests / durationMinutes,
        burstDetected: recentRequests >= BURST_THRESHOLD,
        highFrequency: requestsPerMinute > HIGH_FREQUENCY,
        suspicious: burstDetected || highFrequency || isSuspiciousUserAgent
    };
    
    if (analysis.suspicious) {
        securityLogger.warn('SUSPICIOUS REQUEST DETECTED', { ip, path, analysis });
    }
    
    return analysis;
}
```

**Useful for Heirloom**: Monitor AI API usage patterns, detect abuse/rate limiting

---

## 4. Token Usage & Cost Tracking

### 4.1 OpenAI Cost Tracking
**Pattern from `generate-with-openai.ts`**:

```typescript
const response = await openai.chat.completions.create({...});

console.log(`Tokens used: ${response.usage?.total_tokens}`);
console.log(`Cost: ~$${(response.usage?.total_tokens || 0) / 1000 * 0.0002}`);

// Per-category tracking:
const stats = {
  model: MODEL,
  total_emails: emails.length,
  total_tokens_used: totalTokens,
  estimated_cost: totalTokens / 1000 * COST_PER_1K_TOKENS
};
```

### 4.2 Recommended Implementation for Heirloom
```
Create a token usage tracker that:
1. Logs tokens per API call (OpenAI, Anthropic, etc.)
2. Aggregates costs per service/model
3. Tracks monthly spend
4. Alerts on threshold breaches

Data to track:
- timestamp
- service (openai, anthropic, google)
- model (gpt-4, claude-3, etc.)
- tokens_input
- tokens_output
- total_cost
- user_id (if multi-tenant)
```

---

## 5. Prompt Engineering & Templates

### 5.1 Structured Prompt Pattern
**From `generate-with-openai.ts`**:

```typescript
interface CategoryConfig {
  id: string;
  name: string;
  priority: 'critical' | 'high' | 'medium' | 'low';
  action: string;
  count: number;
  knownAccuracy?: number;
  focusAreas?: string[];
}

const systemPrompt = `You are an expert email generator...
CRITICAL REQUIREMENTS:
1. High diversity - no repeated patterns
2. Natural language - emails should read like real messages
3. Edge cases - include tricky examples
4. Realistic details - use real company names
5. Metadata richness - include detailed metadata`;

const userPrompt = `Generate ${category.count} realistic emails...
DIVERSITY REQUIREMENTS:
- 30% straightforward examples
- 40% typical examples
- 20% edge cases
- 10% adversarial examples

OUTPUT FORMAT (JSON array):
[{
  "subject": "...",
  "from": "...",
  "body": "...",
  "metadata": {...}
}]`;
```

**Key Principles**:
1. Separate system prompt (behavior definition) from user prompt (task)
2. Explicit format specification with examples
3. Clear diversity requirements
4. Structured JSON output
5. Metadata inclusion for analysis

### 5.2 Gemini Smart Reply Pattern
**From `SmartReplyService.swift`**:

```swift
private func buildSmartReplyPrompt(
    email: EmailCard,
    userTone: String?,
    context: String?
) -> String {
    var prompt = """
    You are an AI assistant helping generate SHORT, NATURAL email replies.
    
    EMAIL TO REPLY TO:
    From: \(email.sender?.name ?? "Unknown")
    Subject: \(email.title)
    Body: \(email.body ?? email.summary)
    
    TONE: \(userTone ?? "professional")
    
    Generate 2-3 short, contextually relevant replies (2-3 sentences each).
    """
    return prompt
}
```

**Reusable for Heirloom**:
- Tone-based personalization
- Concise instructions (avoid verbose prompts)
- Clear output format (JSON preferred)
- Context awareness (thread history, user preferences)

---

## 6. Request/Response Types & Patterns

### 6.1 Email Classification Response
**Pattern from `intent-classifier.js`**:

```javascript
function classifyIntent(email) {
  // Input validation
  if (!email || typeof email !== 'object') {
    return {
      intent: 'generic.transactional',
      confidence: 0.3,
      source: 'validation_error'
    };
  }
  
  // Processing
  const intentScores = {};
  for (const intentId of getAllIntentIds()) {
    const score = calculateIntentScore(intent, { subject, body, from });
    if (score > 0) {
      intentScores[intentId] = score;
    }
  }
  
  // Return detailed classification
  return {
    intent: detectedIntent,
    confidence: maxScore,
    source: 'pattern_matching',
    scores: intentScores,        // For debugging
    metadata: {
      processedAt: Date.now(),
      threadReply: isThreadReply,
      selfSent: isSelfSent
    }
  };
}
```

### 6.2 Batch Classification
**Pattern from `server.js`**:

```javascript
app.post('/api/classify-batch', async (req, res) => {
  const { emails } = req.body;
  
  if (!Array.isArray(emails)) {
    return res.status(400).json({ error: 'emails must be an array' });
  }
  
  const results = await Promise.all(
    emails.map(email => classifyEmailEnhanced(email))
  );
  
  return res.json({
    count: results.length,
    classifications: results,
    summary: {
      intents: countBy(results, 'intent'),
      avgConfidence: results.reduce((sum, r) => sum + r.confidence, 0) / results.length
    }
  });
});
```

---

## 7. Swift Protocols & Patterns

### 7.1 Logging Protocol
**Location**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Utilities/LoggingProtocol.swift`

```swift
enum LogPrivacy {
    case `public`       // Always visible
    case `private`      // Redacted in release
    case sensitive      // Always redacted
}

protocol Logging {
    func info(_ message: String)
    func error(_ message: String)
    func warning(_ message: String)
    func debug(_ message: String)
    
    // Privacy-aware variants
    func info(_ message: String, privacy: LogPrivacy)
    func error(_ message: String, privacy: LogPrivacy)
}

final class OSLogger: Logging {
    private let logger: os.Logger
    private let samplingRate: Double
    
    init(subsystem: String, category: String, samplingRate: Double = 1.0) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.samplingRate = samplingRate
    }
}

final class MockLogger: Logging {
    var infoMessages: [String] = []
    var errorMessages: [String] = []
    // Easy testing - captures all logs
}
```

**Reusable**:
- Privacy-aware logging
- OSLog integration (production standard)
- Mock implementation for testing
- Sampling for high-frequency logs

### 7.2 Environment Configuration
**From `LaunchConfiguration.swift`**:

```swift
struct LaunchConfiguration {
    let isUITesting: Bool
    let useMockData: Bool
    let skipOnboarding: Bool
    
    init(processInfo: ProcessInfo = .processInfo, 
         userDefaults: UserDefaults = .standard) {
        self.isUITesting = CommandLine.arguments.contains("--uitesting")
        let env = processInfo.environment
        self.useMockData = (env["USE_MOCK_DATA"] as NSString?)?.boolValue ?? false
    }
}
```

**Pattern**: Injectable dependencies for testability

---

## 8. Database & Persistence

### 8.1 Token Storage
**Location**: `/Users/matthanson/Zer0_Inbox/backend/shared/utils/`

- File-based token storage: `/data/tokens/{userId}_{provider}.json`
- Automatic refresh on `oauth2Client.on('tokens')` event
- Health check API for token status monitoring

### 8.2 Data Models
**Located in**: `/Users/matthanson/Zer0_Inbox/backend/shared/models/`

- `EmailCard.js` - Email data structure
- `SavedMailFolder.js` - Folder management
- `Intent.js` - Classification taxonomy

---

## 9. Architecture Recommendations for Heirloom

### What to Directly Port (Minimal Changes)

1. **Token Manager Pattern** (JavaScript/Node)
   - File: `/backend/shared/utils/token-manager.js`
   - Adapt for Anthropic tokens

2. **Request Logger Middleware** (JavaScript/Node)
   - File: `/backend/shared/middleware/request-logger.js`
   - Use for rate limiting, abuse detection

3. **Error Handling Pattern** (Any language)
   - Input validation first
   - Structured logging with context
   - Graceful fallbacks

4. **Logging Protocol** (Swift)
   - File: `/Zero_ios_2/Zero/Utilities/LoggingProtocol.swift`
   - Privacy-aware logging with OSLog

### What to Adapt

1. **OpenAI Integration** -> **OpenAI + Anthropic** support
   - Create abstraction layer
   - Support multiple providers
   - Dynamic model selection

2. **Service Protocols**
   - Extend `EmailServiceProtocol` with AI-specific methods
   - Support streaming responses (Claude Streaming API)

3. **Prompt Templates**
   - Use Zero's structured approach
   - Add version control to prompts
   - A/B testing support for different prompts

### What to Build New

1. **Cost Optimization Layer**
   - Model selection based on complexity
   - Batch processing for efficiency
   - Caching for repeated queries

2. **Streaming Response Handling**
   - OpenAI supports streaming
   - Anthropic supports streaming
   - Real-time UI updates from partial responses

3. **Fine-tuning Pipeline** (if needed)
   - Data collection from usage
   - Training dataset curation
   - Model improvement tracking

---

## 10. Key Files to Review

### Backend (Node.js)
- `/backend/shared/utils/token-manager.js` - Token lifecycle
- `/backend/shared/config/logger.js` - Logging setup (Winston)
- `/backend/services/classifier/server.js` - API patterns
- `/backend/shared/middleware/request-logger.js` - Rate limiting

### Frontend (Swift)
- `/Zero_ios_2/Zero/Protocols/EmailServiceProtocol.swift` - Service abstraction
- `/Zero_ios_2/Zero/Utilities/LoggingProtocol.swift` - Logging abstraction
- `/Zero_ios_2/Zero/Services/SmartReplyService.swift` - AI service implementation
- `/Zero_ios_2/Zero/Config/LaunchConfiguration.swift` - Configuration pattern

### AI Integration
- `/Zero_ios_2/agents/generate-with-openai.ts` - Structured prompt patterns
- `/Zero_ios_2/agents/generate-fast.ts` - Cost-optimized approach
- `/Zero_ios_2/agents/test-openai-api.ts` - Basic API testing

---

## 11. Critical Lessons Learned

1. **Protocol-Based Architecture is Essential**
   - Enables testing, provider switching, mocking
   - Separates concerns cleanly

2. **Validate Input Aggressively**
   - Check types, required fields before processing
   - Log what was invalid for debugging

3. **Track Metrics & Token Usage**
   - Monitor costs per service/model
   - Alert on threshold breaches
   - Support multi-tenant tracking

4. **Graceful Degradation**
   - Have fallback models/services
   - Support partial failures
   - Clear error messages

5. **Security First**
   - Never hardcode API keys
   - Use environment variables
   - Implement request rate limiting
   - Log security events separately

6. **Prompt Engineering as Code**
   - Version control prompts
   - Use structured templates
   - Document tone/style requirements
   - Test variations systematically

---

## Summary

Zero Inbox demonstrates a **mature, production-ready approach** to AI integration with strong patterns for:
- Token management and credential handling
- Multi-service AI support
- Error handling and logging
- Type-safe Swift protocols
- Cost tracking and monitoring

For Heirloom, adopt the protocol-based architecture, token management patterns, and error handling approaches directly. Extend with Anthropic support, streaming response handling, and cost optimization specific to your use case.

