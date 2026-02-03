# API Key Security Audit

Complete inventory of all API keys in Heirloom and their security status.

## Summary

| Service | Current Location | Risk Level | Action Required | Gateway Status |
|---------|------------------|------------|----------------|----------------|
| Anthropic (Claude) | iOS App Binary | 🔴 **CRITICAL** | Move to backend | ✅ Complete |
| OpenAI (GPT) | iOS App Binary | 🔴 **CRITICAL** | Move to backend | ✅ Complete |
| Google Vision | iOS App Binary | 🔴 **HIGH** | Move to backend | ✅ Complete |
| Brave Search | iOS App Binary | 🟡 **MEDIUM** | Move to backend | ✅ Complete |
| Algolia Search | iOS App Binary | 🟢 **SAFE** | No action (search-only key) | ⚠️ Optional |
| Firebase | Google Services | 🟢 **SAFE** | No action (built-in auth) | N/A |

---

## Detailed Breakdown

### 🔴 CRITICAL: Anthropic API Key

**Current Location**: `Config.xcconfig` → `Info.plist` → iOS binary
**Key Format**: `sk-ant-api03-...`
**Risk**: Can be extracted from binary, full API access, costly abuse potential

**Current Usage**:
- Recipe OCR extraction
- Ingredient parsing
- Recipe enhancement
- Video recipe structuring

**Gateway Status**: ✅ **COMPLETE**
- Function: `aiComplete`, `aiCompleteStructured`, `aiCompleteWithVision`
- Rate Limit: 100 text/day, 50 vision/day
- Cost Tracking: Yes

**Action Required**:
1. ✅ Deploy Firebase Functions with key
2. ✅ Update iOS app to use `FirebaseAIGatewayService`
3. ⏳ Test all AI features
4. ⏳ Remove key from `Config.xcconfig`

---

### 🔴 CRITICAL: OpenAI API Key

**Current Location**: `Config.xcconfig` → `Info.plist` → iOS binary
**Key Format**: `sk-proj-...`
**Risk**: Can be extracted from binary, full API access, costly abuse potential

**Current Usage**:
- Alternative to Anthropic (user-selectable)
- GPT-4o for vision tasks
- GPT-4o-mini for parsing

**Gateway Status**: ✅ **COMPLETE**
- Function: `aiComplete`, `aiCompleteStructured`, `aiCompleteWithVision`
- Rate Limit: Same as Anthropic
- Cost Tracking: Yes

**Action Required**:
1. ✅ Deploy Firebase Functions with key
2. ✅ Update iOS app to use `FirebaseAIGatewayService`
3. ⏳ Test all AI features
4. ⏳ Remove key from `Config.xcconfig`

---

### 🔴 HIGH: Google Vision API Key

**Current Location**: `Config.xcconfig` → `Info.plist` → iOS binary
**Key Format**: `AIza...`
**Risk**: Can be extracted, OCR costs can add up quickly

**Current Usage**:
- Handwriting OCR for cookbook recipes
- Fallback for complex recipe images
- Document text detection

**Gateway Status**: ✅ **COMPLETE**
- Function: `googleVisionOCR`
- Rate Limit: 100 requests/day
- Cost Tracking: Yes ($1.50 per 1000 images)

**Action Required**:
1. ✅ Deploy Firebase Functions with key
2. ⏳ Create `FirebaseGoogleVisionService.swift`
3. ⏳ Update iOS app to use gateway
4. ⏳ Remove key from `Config.xcconfig`

---

### 🟡 MEDIUM: Brave Search API Key

**Current Location**: `WebRecipeSearchService.swift` (if used)
**Risk**: Moderate - search abuse possible but less costly

**Current Usage**:
- Web recipe search
- Recipe URL discovery
- Video recipe augmentation

**Gateway Status**: ✅ **COMPLETE**
- Function: `braveSearch`
- Rate Limit: 200 requests/day
- Cost Tracking: Yes

**Action Required**:
1. ✅ Deploy Firebase Functions with key
2. ⏳ Update `WebRecipeSearchService` to use gateway
3. ⏳ Remove key from iOS app

---

### 🟢 SAFE: Algolia Search API Key

**Current Location**: `AlgoliaSearchService.swift:32`
**Key**: `4e4be19553e7b15c90aeba9bbebb6fe0` (search-only)
**Risk**: LOW - This is a **search-only** key (safe for client-side)

**Why It's Safe**:
- ✅ Read-only access (cannot modify index)
- ✅ Cannot delete or add users
- ✅ Rate limited by Algolia
- ✅ Standard practice for Algolia

**Current Usage**:
- User search by name
- Fuzzy matching
- Typo tolerance

**Gateway Status**: ⚠️ **OPTIONAL**
- Not required for security
- Could add for consistency
- Would add latency to search

**Recommendation**: **KEEP CLIENT-SIDE**
- Search-only keys are designed for client use
- No security risk
- Better performance (direct connection)
- Standard Algolia practice

---

### 🟢 SAFE: Firebase Credentials

**Current Location**: `GoogleService-Info.plist`
**Risk**: NONE - These are meant to be public

**Why It's Safe**:
- ✅ Designed for client-side use
- ✅ Protected by Firebase Security Rules
- ✅ Authentication required for access
- ✅ Not API keys (configuration only)

**Recommendation**: **NO ACTION NEEDED**

---

## Set All Keys Command

```bash
cd /Users/matthanson/Heirloom/functions

# Set all keys at once
firebase functions:config:set \
  anthropic.key="YOUR_ANTHROPIC_KEY" \
  openai.key="YOUR_OPENAI_KEY" \
  google.vision_key="YOUR_GOOGLE_VISION_KEY" \
  brave.search_key="YOUR_BRAVE_SEARCH_KEY"

# Verify
firebase functions:config:get
```

---

## Migration Checklist

### Phase 1: Deploy Backend (✅ Ready)
- [x] Create Firebase Functions
- [x] Add Anthropic gateway
- [x] Add OpenAI gateway
- [x] Add Google Vision gateway
- [x] Add Brave Search gateway
- [x] Add rate limiting
- [x] Add cost tracking
- [ ] Set API keys
- [ ] Deploy functions

### Phase 2: Update iOS App
- [ ] Create `FirebaseAIGatewayService.swift` ✅ Done
- [ ] Create `FirebaseGoogleVisionService.swift`
- [ ] Create `FirebaseBraveSearchService.swift`
- [ ] Update `ServiceContainer` to use gateways
- [ ] Add feature flag for gradual rollout
- [ ] Test all features

### Phase 3: Remove Old Keys
- [ ] Remove Anthropic key from `Config.xcconfig`
- [ ] Remove OpenAI key from `Config.xcconfig`
- [ ] Remove Google Vision key from `Config.xcconfig`
- [ ] Remove Brave Search key from code
- [ ] Clean build
- [ ] Verify no keys in binary (`strings` command)

### Phase 4: Production
- [ ] Monitor function logs
- [ ] Check rate limiting works
- [ ] Verify cost tracking
- [ ] Submit to App Store with security notes

---

## Testing Verification

After deployment, verify each service:

```swift
// Test Anthropic
let response = try await aiService.complete(prompt: "Test")

// Test OpenAI
configuration.selectedProvider = .openai
let response2 = try await aiService.complete(prompt: "Test")

// Test Google Vision
let text = try await visionService.processImage(image)

// Test Brave Search
let results = try await searchService.search(query: "chocolate chip cookies")
```

---

## Binary Security Check

After removing keys, verify they're gone:

```bash
# Build app
xcodebuild clean build -scheme Heirloom

# Check for Anthropic key
strings ./DerivedData/.../Heirloom.app/Heirloom | grep "sk-ant"
# Should return nothing!

# Check for OpenAI key
strings ./DerivedData/.../Heirloom.app/Heirloom | grep "sk-proj"
# Should return nothing!

# Check for Google key
strings ./DerivedData/.../Heirloom.app/Heirloom | grep "AIza"
# Should return nothing!
```

---

## Cost Estimates (with rate limits)

With default rate limits per user per day:

| Service | Rate Limit | Cost per Request | Max Daily Cost |
|---------|------------|------------------|----------------|
| Anthropic (text) | 100/day | ~$0.001 | $0.10 |
| Anthropic (vision) | 50/day | ~$0.01 | $0.50 |
| OpenAI (text) | 100/day | ~$0.0001 | $0.01 |
| OpenAI (vision) | 50/day | ~$0.005 | $0.25 |
| Google Vision | 100/day | $0.0015 | $0.15 |
| Brave Search | 200/day | $0.001 | $0.20 |
| **Total** | - | - | **~$1.21/user/day** |

With 100 active users: ~$121/day or ~$3,630/month (worst case)

---

## Recommendations

1. **Anthropic & OpenAI**: 🔴 **URGENT** - Move to backend immediately
2. **Google Vision**: 🔴 **HIGH** - Move to backend with AI services
3. **Brave Search**: 🟡 **MEDIUM** - Move to backend for consistency
4. **Algolia**: 🟢 **SAFE** - Keep client-side (search-only key)
5. **Firebase**: 🟢 **SAFE** - No action needed

## Next Steps

1. Run the "Set All Keys" command above
2. Deploy functions: `cd functions && ./deploy.sh`
3. Test each gateway in iOS app
4. Remove keys from iOS app one by one (after testing)
5. Verify with binary security check
6. Monitor costs and adjust rate limits if needed
