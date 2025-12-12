# Zero Inbox Reusable Code Reference

Quick lookup guide for Zero Inbox code patterns and infrastructure that can be directly reused in Heirloom.

## File Paths to Review

### 1. Token Management (Production-Ready)
**Path**: `/Users/matthanson/Zer0_Inbox/backend/shared/utils/token-manager.js`
**Size**: ~390 lines
**Status**: DIRECTLY REUSABLE for Anthropic OAuth flows

**What it does**:
- Automatic token refresh with 5-minute buffer
- Proactive refresh before expiry
- Failed refresh attempt tracking (max 3 attempts)
- Token health status API
- Re-authentication flag management

**Key Functions to Adapt**:
```javascript
refreshTokenIfNeeded(userId, provider)
getTokenHealth(userId, provider)
createOAuth2Client(userId, provider, tokens)
getManagedOAuth2Client(userId, provider)
```

**Adaptation for Heirloom**: Replace Google OAuth with Anthropic token handling

---

### 2. Request Logging & Security
**Path**: `/Users/matthanson/Zer0_Inbox/backend/shared/middleware/request-logger.js`
**Size**: ~220 lines
**Status**: DIRECTLY REUSABLE for rate limiting

**What it does**:
- IP address tracking (proxied and direct)
- Request rate analysis (per minute, burst detection)
- Bot/scraper pattern detection
- Security event logging
- Automatic cleanup of old tracking data

**Key Patterns**:
```javascript
getRealIP(req)              // Extract real IP from proxied requests
trackRequest(ip, userAgent, path)  // Analyze request patterns
isSuspiciousUserAgent(userAgent)   // Detect bots
```

**Adaptation for Heirloom**: Apply to AI API endpoint monitoring

---

### 3. Error Handling Pattern
**Path**: `/Users/matthanson/Zer0_Inbox/backend/services/classifier/server.js`
**Lines**: 53-150 (classification endpoint)
**Status**: PATTERN-BASED (adapt structure)

**What it does**:
- Input validation before processing
- Structured error logging with context
- HTTP status codes for different error types
- Graceful fallbacks
- Performance metric tracking

**Key Pattern**:
```javascript
// 1. Validate input
if (!req.body || typeof req.body !== 'object') {
  logger.error('Invalid request body', { body: req.body });
  return res.status(400).json({ error: 'Invalid request...' });
}

// 2. Check required fields
if (!email.subject || !email.from) {
  logger.error('Invalid email data: missing required fields', {
    hasSubject: !!email.subject,
    hasFrom: !!email.from
  });
  return res.status(400).json({ error: 'Invalid email data...' });
}

// 3. Process with fallback
let classification;
if (USE_ACTION_FIRST) {
  classification = await classifyEmailActionFirst(email);
} else if (USE_ENHANCED_CLASSIFIER) {
  classification = classifyEmailEnhanced(email);
}

// 4. Log metrics
logger.info('Classification complete', {
  intent: classification.intent,
  isFallback,
  processingTimeMs: Date.now() - startTime
});

// 5. Return structured response
res.json(classification);
```

---

### 4. Logging Infrastructure
**Path**: `/Users/matthanson/Zer0_Inbox/backend/shared/config/logger.js`
**Size**: ~27 lines
**Status**: DIRECTLY REUSABLE

**What it does**:
- Winston logger setup
- File and console output
- Error-level separation
- JSON formatting with timestamps

**Code**:
```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'emailshortform-backend' },
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.combine(
      winston.format.colorize(),
      winston.format.simple()
    )
  }));
}

module.exports = logger;
```

---

### 5. OpenAI Integration (Prompt Engineering)
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/agents/generate-with-openai.ts`
**Size**: ~570 lines
**Status**: ADAPT for Anthropic Claude

**What it does**:
- Structured prompt engineering
- JSON structured output
- Category-based generation
- Cost tracking
- Diverse sample generation (30% straightforward, 40% typical, 20% edge cases, 10% adversarial)

**Key Pattern**:
```typescript
const systemPrompt = `You are an expert...
CRITICAL REQUIREMENTS:
1. High diversity
2. Natural language
3. Edge cases
4. Realistic details
5. Metadata richness`;

const response = await openai.chat.completions.create({
  model: 'gpt-4o',
  messages: [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt }
  ],
  response_format: { type: 'json_object' },
  temperature: 0.9,
  max_tokens: 4000
});

console.log(`Tokens: ${response.usage?.total_tokens}`);
console.log(`Cost: $${(response.usage?.total_tokens || 0) / 1000 * COST_PER_1K}`);
```

**Adaptation for Heirloom**: Use with Anthropic Messages API, adapt cost calculation

---

### 6. Fast/Cost-Optimized Generation
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/agents/generate-fast.ts`
**Size**: ~150 lines
**Status**: ADAPT for efficient Heirloom operations

**What it does**:
- Simplified prompts
- Cheaper model selection (gpt-4o-mini)
- Faster iteration
- Same quality output with 60% cost savings

**Key Difference from Full Version**:
```typescript
// Full version: gpt-4o with complex prompts
const MODEL = 'gpt-4o';

// Fast version: gpt-4o-mini with simplified prompts
const MODEL = 'gpt-4o-mini';

// Same prompt structure, just more concise:
const prompt = `Generate ${category.count} realistic ${category.name} emails...
Create diverse, realistic emails with:
- Different senders, subjects, tones
- Varied lengths (100-300 words)
- Real company names
- Some tricky examples`;
```

---

### 7. Swift Logging Protocol
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Utilities/LoggingProtocol.swift`
**Size**: ~219 lines
**Status**: DIRECTLY REUSABLE for Heirloom iOS

**What it does**:
- Protocol-based logging abstraction
- Privacy-aware logging (public/private/sensitive)
- OSLog integration (Apple standard)
- Debug log sampling
- Mock implementation for testing

**Key Code**:
```swift
enum LogPrivacy {
    case `public`      // Always visible
    case `private`     // Redacted in release
    case sensitive     // Always redacted
}

protocol Logging {
    func info(_ message: String)
    func error(_ message: String)
    func warning(_ message: String)
    func debug(_ message: String)
    func info(_ message: String, privacy: LogPrivacy)
}

final class OSLogger: Logging {
    private let logger: os.Logger
    init(subsystem: String, category: String, samplingRate: Double = 1.0) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
}

final class MockLogger: Logging {
    var infoMessages: [String] = []
    var errorMessages: [String] = []
}
```

---

### 8. Email Service Protocol (Swift)
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Protocols/EmailServiceProtocol.swift`
**Size**: ~70 lines
**Status**: ADAPT as base for Heirloom services

**Pattern**:
```swift
protocol EmailServiceProtocol {
    // Authentication
    func authenticateDemo(password: String) async throws -> String
    func authenticateGmail(presentationAnchor: ASPresentationAnchor) async throws -> String
    
    // Operations
    func fetchEmails(maxResults: Int, timeRange: EmailTimeRange) async throws -> [EmailCard]
    func fetchEmail(id: String) async throws -> EmailCard
    
    // AI Features
    func generateReply(emailId: String) async throws -> String
    func fetchSmartReplies(emailId: String) async throws -> [String]
}
```

**For Heirloom**: Create `AIServiceProtocol` following same pattern

---

### 9. Configuration Management
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Config/LaunchConfiguration.swift`
**Size**: ~40 lines
**Status**: DIRECTLY REUSABLE

**Pattern**:
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

**For Heirloom**: Add AI provider configuration

---

### 10. Gemini Integration (Swift)
**Path**: `/Users/matthanson/Zer0_Inbox/Zero_ios_2/Zero/Services/SmartReplyService.swift`
**Size**: ~80 lines (reviewed portion)
**Status**: ADAPT for Claude API

**Key Points**:
- v1 API endpoint (not v1beta)
- Supports `gemini-1.5-flash` model
- Tone personalization support
- Structured prompt with email context

**Pattern to Adapt**:
```swift
class SmartReplyService {
    private let geminiAPIKey: String = AppEnvironment.geminiAPIKey
    private let baseURL = "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent"
    
    func generateSmartReplies(for email: EmailCard) async throws -> [String] {
        let prompt = buildSmartReplyPrompt(email: email, userTone: userTone)
        let response = try await callGeminiAPI(prompt: prompt)
        return parseReplies(from: response)
    }
}
```

---

## Key Takeaways for Heirloom

### Directly Port (Minimal Changes)
1. `token-manager.js` - For credential lifecycle
2. `request-logger.js` - For rate limiting
3. `logger.js` - For structured logging
4. `LoggingProtocol.swift` - For iOS logging
5. Error handling patterns from `server.js`

### Adapt (Medium Changes)
1. OpenAI integration -> Add Anthropic support
2. Gemini service -> Create Claude service
3. Prompt templates -> Version and test systematically
4. Configuration -> Add AI provider selection

### Build New
1. Cost optimization layer
2. Streaming response handling
3. Multi-service failover logic
4. Token usage analytics dashboard

---

## Implementation Order

1. **Phase 1: Core Infrastructure**
   - Copy token-manager pattern
   - Implement request logger
   - Set up structured logging
   - Add error handling pattern

2. **Phase 2: AI Service Layer**
   - Create AIServiceProtocol
   - Implement OpenAI client
   - Implement Anthropic client
   - Build prompt templates

3. **Phase 3: Production Hardening**
   - Add cost tracking
   - Implement rate limiting
   - Add monitoring/alerts
   - Security audit
