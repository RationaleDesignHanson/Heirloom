# AI Integration Tests

Real integration tests for Claude API and video import pipeline.

## Overview

These tests use **REAL external dependencies** (not mocked):
- Claude API (for recipe structuring)
- WhisperKit (for audio transcription)
- YouTube (for video downloads)
- Firebase (for cloud storage)

**Why not mock?** Integration tests catch real-world issues:
- API response format changes
- Network timeouts
- Rate limiting behavior
- Data integrity across services

## Test Files

### ClaudeRecipeStructuringTests.swift (20 tests)
Tests Claude API recipe structuring with various transcript types:
- Well-formatted recipes (baking, cooking)
- Poorly-structured transcripts (filler words, rambling)
- Edge cases (very long, special characters, multiple recipes)
- Error handling (empty, non-recipe, rate limits)

### VideoImportEndToEndTests.swift (15 tests)
Tests complete pipeline from YouTube URL to saved recipe:
- End-to-end flows (short, medium, long videos)
- Progress tracking through stages
- Network failure recovery
- Partial state and resume
- Cancellation handling
- Concurrent processing
- Queue integration
- Data quality validation

## Setup

### 1. Environment Variables

Set these before running tests:

```bash
# Required: Claude API key
export CLAUDE_API_KEY="sk-ant-api03-..."

# Optional: Test video URLs (YouTube)
export TEST_VIDEO_URL_SHORT="https://www.youtube.com/watch?v=..." # 2-3 min
export TEST_VIDEO_URL_MEDIUM="https://www.youtube.com/watch?v=..." # 10-15 min
export TEST_VIDEO_URL_LONG="https://www.youtube.com/watch?v=..." # 20-30 min
export TEST_VIDEO_URL_COMPLETE="https://www.youtube.com/watch?v=..." # High quality

# Optional: Multiple test videos for concurrent tests
export TEST_VIDEO_URL_1="https://www.youtube.com/watch?v=..."
export TEST_VIDEO_URL_2="https://www.youtube.com/watch?v=..."
export TEST_VIDEO_URL_3="https://www.youtube.com/watch?v=..."
```

**Getting a Claude API Key:**
1. Go to https://console.anthropic.com/
2. Create account or sign in
3. Go to API Keys
4. Create new key (use test/development key, not production)
5. Set quota limits to avoid unexpected costs

### 2. Test YouTube Videos

Create unlisted test videos on YouTube:

**Requirements:**
- Unlisted (not private, so tests can access)
- Simple recipes with clear narration
- Various lengths (2 min, 10 min, 30 min)
- Different recipe types (baking, cooking, drinks)

**Example Test Videos to Create:**
1. **Short Baking Video** (2-3 min)
   - Simple chocolate chip cookies
   - Clear ingredient list
   - Step-by-step instructions

2. **Medium Cooking Video** (10-15 min)
   - Pasta dish or stir-fry
   - Multiple steps
   - Cooking techniques shown

3. **Long Complex Recipe** (20-30 min)
   - Multi-component dish (e.g., beef bourguignon)
   - Many ingredients and steps
   - Detailed techniques

**OR** use existing public recipe videos (but make sure they stay available):
```bash
export TEST_VIDEO_URL_SHORT="https://www.youtube.com/watch?v=dQw4w9WgXcQ" # Example
```

### 3. Xcode Project Configuration

Add test files to HeirloomTestsV2 target:
1. Open Xcode project
2. Right-click HeirloomTestsV2 → Add Files
3. Select Integration/AI/ folder
4. Ensure "HeirloomTestsV2" target is checked

### 4. CI/CD Configuration

For GitHub Actions, add secrets:

```yaml
# .github/workflows/ai-tests.yml
env:
  CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
  TEST_VIDEO_URL_SHORT: ${{ secrets.TEST_VIDEO_URL_SHORT }}
  # ... other video URLs
```

**In GitHub**:
1. Repository Settings → Secrets and variables → Actions
2. Add `CLAUDE_API_KEY` secret
3. Add test video URL secrets

## Running Tests

### Locally

**Run all AI integration tests:**
```bash
xcodebuild test \
  -project Heirloom.xcodeproj \
  -scheme Heirloom \
  -only-testing:HeirloomTestsV2/Integration/AI \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Run specific test file:**
```bash
# Claude tests only
xcodebuild test \
  -scheme Heirloom \
  -only-testing:HeirloomTestsV2/Integration/AI/ClaudeRecipeStructuringTests

# End-to-end tests only
xcodebuild test \
  -scheme Heirloom \
  -only-testing:HeirloomTestsV2/Integration/AI/VideoImportEndToEndTests
```

**Run from Xcode:**
1. Open Test Navigator (⌘6)
2. Expand HeirloomTestsV2 → Integration → AI
3. Click ▶️ next to test class or individual test

### In CI/CD

**Separate test suite** (don't run with every commit):

```yaml
# .github/workflows/ai-integration-tests.yml
name: AI Integration Tests

on:
  schedule:
    - cron: '0 2 * * *'  # Run nightly at 2 AM
  workflow_dispatch:  # Allow manual trigger

jobs:
  ai-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Run AI Integration Tests
        env:
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
          TEST_VIDEO_URL_SHORT: ${{ secrets.TEST_VIDEO_URL_SHORT }}
        run: |
          xcodebuild test \
            -scheme Heirloom \
            -only-testing:HeirloomTestsV2/Integration/AI \
            -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Why nightly?**
- Slow (5-10 minutes total)
- API costs (Claude charges per token)
- Rate limits (avoid hitting limits on every commit)

## Cost Management

### Claude API Costs

**Estimated costs** (as of 2024):
- Claude 3.5 Sonnet: ~$3 per million input tokens, ~$15 per million output tokens
- Average recipe structuring: ~2,000 input tokens, ~1,000 output tokens
- Cost per test: ~$0.02
- Full suite (20 tests): ~$0.40 per run
- Monthly (30 nightly runs): ~$12

**Cost reduction strategies:**
1. **Cache results**: Save API responses, replay in tests
2. **Mock selectively**: Mock for unit tests, real API for integration
3. **Limit CI runs**: Only nightly, not every commit
4. **Use quota limits**: Set spending limits in Claude console

### Caching Strategy

```swift
// Cache Claude responses for faster/cheaper testing
class CachedClaudeStructurer: ClaudeRecipeStructurer {
    private var cache: [String: Recipe] = [:]

    override func structure(transcript: String, context: ModelContext) async throws -> Recipe {
        let cacheKey = transcript.hash
        if let cached = cache[cacheKey] {
            return cached
        }

        let recipe = try await super.structure(transcript: transcript, context: context)
        cache[cacheKey] = recipe
        return recipe
    }
}
```

## Troubleshooting

### Test Failures

**"CLAUDE_API_KEY not set"**
```bash
# Set environment variable
export CLAUDE_API_KEY="sk-ant-api03-..."

# Or set in Xcode scheme:
# Product → Scheme → Edit Scheme → Test → Arguments → Environment Variables
```

**"Rate limit exceeded"**
- Wait 1 minute, then retry
- Reduce concurrent test execution
- Check Claude console for quota status

**"Video not found" or "Invalid URL"**
- Verify video URLs are correct
- Ensure videos are unlisted (not private)
- Check videos haven't been deleted

**"Transcription failed"**
- Ensure WhisperKit is properly initialized
- Check audio download succeeded
- Verify device has enough storage/memory

### Performance Issues

**Tests too slow:**
- Run fewer tests locally (full suite in CI only)
- Use cached results for development
- Skip long video tests during development

**Memory issues:**
- Close other apps
- Use iPhone 15 simulator (not older devices)
- Run tests sequentially, not in parallel

## Test Quality

### What Makes a Good AI Integration Test?

**Good:**
```swift
func test_claude_structuresWellFormattedRecipe() async throws {
    let transcript = "[actual recipe transcript]"
    let recipe = try await structurer.structure(transcript: transcript)

    // Verify actual structure
    XCTAssertTrue(recipe.title.contains("Cookie"))
    XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 5)
}
```

**Bad:**
```swift
func test_claude_returnsRecipe() async throws {
    let recipe = try await structurer.structure(transcript: "test")
    XCTAssertNotNil(recipe) // Too vague, doesn't verify quality
}
```

### Coverage Goals

- **Claude structuring**: 20 tests covering all transcript types
- **End-to-end pipeline**: 15 tests covering full flow
- **Real API calls**: At least 10 tests use actual Claude API
- **Error handling**: 5+ tests verify error scenarios

## Maintenance

### Updating Tests

**When to update:**
- Claude API changes format
- Video URLs become unavailable
- New edge cases discovered
- Performance degrades

**How to update:**
1. Update test transcripts/videos
2. Adjust assertions for new API responses
3. Update expected timings
4. Re-baseline cached responses

### Monitoring

**Track test health:**
- Success rate over time
- Average execution time
- API costs per month
- Failure patterns (specific tests failing?)

**Alerts:**
- Success rate < 90% for 3 consecutive runs
- Execution time > 15 minutes
- API costs > $50/month

## Best Practices

1. **Don't mock external services** - defeats purpose of integration tests
2. **Use real test data** - actual recipe transcripts, real videos
3. **Test error paths** - network failures, API errors, bad input
4. **Keep tests independent** - each test should work in isolation
5. **Run infrequently** - nightly or on-demand, not every commit
6. **Monitor costs** - set API spending limits
7. **Cache when possible** - save API responses for faster re-runs

## Future Improvements

1. **Test data management**: Version control test transcripts/videos
2. **Parallel execution**: Run tests concurrently (with rate limiting)
3. **Flakiness detection**: Track flaky tests, auto-retry
4. **Performance baselines**: Alert on significant slowdowns
5. **Visual regression**: Compare recipe output quality over time

## Support

- **Claude API docs**: https://docs.anthropic.com/
- **WhisperKit docs**: https://github.com/argmaxinc/WhisperKit
- **Questions**: Open issue or ask in #engineering Slack
