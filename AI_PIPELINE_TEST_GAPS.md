# AI Pipeline Test Coverage: Gaps & Action Plan

## Current State Analysis

### Video → Recipe Pipeline

**Current Coverage**: Listed as 80%, but **55 out of 80 tests are placeholders** ⚠️

**What's Actually Tested**:
- ✅ URL validation (YouTube formats, malformed URLs)
- ✅ Queue management (FIFO, duplicates, concurrency)
- ✅ Progress tracking (state updates)

**What's NOT Tested** (Placeholders Only):
- ❌ WhisperKit transcription (audio → text)
- ❌ Claude API structuring (text → recipe JSON)
- ❌ Frame extraction (video → images)
- ❌ Recipe augmentation (web search + merge)
- ❌ Error handling for AI failures
- ❌ End-to-end pipeline (URL → saved recipe)

**Real Coverage**: ~15-20% (only infrastructure, not AI logic)

### OCR → Recipe Pipeline (Cookbook Scan)

**Current Coverage**: 0% (not implemented yet)

**Status**: Development phase, no code exists

---

## Cloud Sync Clarification

**Yes**, cloud sync = **Local (SwiftData) ↔ Firebase/CloudKit**

**Architecture**:
```
[iOS Device - SwiftData]
         ↕
    [Network Layer]
         ↕
[Firebase Firestore] ← Cloud storage
         ↕
[Other iOS Devices]
```

**What Needs Testing**:
1. Bi-directional sync (local → cloud, cloud → local)
2. Conflict resolution (which version wins?)
3. Offline queue (save changes when offline, sync when online)
4. Data integrity (all fields preserved)
5. Image/asset sync (not just text)

---

## High-Risk Gap: AI Pipeline Testing

### Why This Matters

The video/OCR → recipe pipeline is **HIGH RISK** because:

1. **Revenue**: Premium feature (subscription required)
2. **Complexity**: Multiple external dependencies (WhisperKit, Claude, Firebase)
3. **User-facing**: Directly impacts user experience
4. **Failure modes**: Many ways to fail (network, API limits, bad input)
5. **Data quality**: Wrong recipes = frustrated users

### Current Risk

**Without real tests, you're flying blind on**:
- Does transcription work with accented speech?
- Does Claude handle poorly-structured narration?
- What happens when API quota exceeded?
- Can users recover from failed imports?
- Are partial results saved (resume failed imports)?

---

## Recommended Testing Strategy

### Phase 1: Integration Tests (Real Dependencies)

**Don't mock the AI** - test with real APIs in controlled environment.

#### 1. WhisperKit Transcription Tests (High Priority)

**Setup**: Use test audio files with known transcripts

```swift
func test_whisperKit_transcribesEnglishAccurately() async throws {
    // Given: Pre-recorded audio file (controlled input)
    let audioURL = Bundle.main.url(forResource: "test_cookie_recipe", withExtension: "m4a")!

    // When: Transcribe with WhisperKit
    let transcriber = WhisperKitTranscriber()
    let result = try await transcriber.transcribe(audioPath: audioURL.path)

    // Then: Verify accuracy (word error rate < 5%)
    let expectedWords = ["flour", "sugar", "butter", "eggs", "vanilla", "chocolate chips"]
    for word in expectedWords {
        XCTAssertTrue(result.text.lowercased().contains(word), "Missing ingredient: \(word)")
    }

    // Verify structure
    XCTAssertGreaterThan(result.text.count, 100, "Transcript too short")
    XCTAssertFalse(result.text.isEmpty, "Empty transcription")
}

func test_whisperKit_handlesBackgroundNoise() async throws {
    // Test with noisy audio (kitchen sounds)
    let noisyAudio = Bundle.main.url(forResource: "noisy_kitchen_recipe", withExtension: "m4a")!
    let result = try await transcriber.transcribe(audioPath: noisyAudio.path)

    // Should still extract key recipe terms despite noise
    XCTAssertTrue(result.text.contains("ingredients") || result.text.contains("recipe"))
}

func test_whisperKit_handlesMultipleLanguages() async throws {
    // Test Spanish recipe narration
    let spanishAudio = Bundle.main.url(forResource: "receta_espanola", withExtension: "m4a")!
    let result = try await transcriber.transcribe(audioPath: spanishAudio.path, language: "es")

    XCTAssertTrue(result.text.contains("ingredientes") || result.text.contains("receta"))
}
```

**Test Assets Needed**:
- `test_cookie_recipe.m4a` - Clean English narration
- `noisy_kitchen_recipe.m4a` - With background sounds
- `receta_espanola.m4a` - Spanish language test
- `accented_english.m4a` - Non-native speaker
- `mumbled_recipe.m4a` - Poor audio quality

**Estimated Effort**: 6-8 hours (including recording test audio)

#### 2. Claude Recipe Structuring Tests (Critical)

**Setup**: Use real Claude API with test transcripts

```swift
func test_claude_structuresWellFormattedTranscript() async throws {
    // Given: Clean, well-structured transcript
    let transcript = """
    Today I'm making chocolate chip cookies.
    You'll need 2 cups of all-purpose flour, 1 cup of sugar,
    1 cup of softened butter, 2 eggs, 1 teaspoon vanilla extract,
    and 2 cups of chocolate chips.

    First, preheat your oven to 350 degrees Fahrenheit.
    Cream together the butter and sugar until fluffy.
    Beat in the eggs and vanilla.
    Gradually mix in the flour.
    Fold in the chocolate chips.
    Bake for 12 minutes or until golden brown.
    """

    // When: Structure with Claude
    let structurer = ClaudeRecipeStructurer(apiKey: testAPIKey)
    let recipe = try await structurer.structure(transcript: transcript)

    // Then: Verify structure
    XCTAssertEqual(recipe.title, "Chocolate Chip Cookies")
    XCTAssertEqual(recipe.ingredients?.count, 6, "Should extract 6 ingredients")
    XCTAssertEqual(recipe.instructions.count, 5, "Should have 5 steps")

    // Verify ingredient parsing
    let flour = recipe.ingredients?.first { $0.name.contains("flour") }
    XCTAssertEqual(flour?.quantity, 2.0)
    XCTAssertEqual(flour?.unit, "cups")

    // Verify cooking details
    XCTAssertEqual(recipe.cookTime, "12")
    XCTAssertEqual(recipe.ovenTemp, "350°F")
}

func test_claude_handlesPoorlyStructuredTranscript() async throws {
    // Given: Rambling, unstructured transcript
    let messyTranscript = """
    So like um I'm gonna make cookies today and uh you need some flour
    maybe like 2 cups or so and sugar and butter yeah definitely butter
    oh and eggs too I think 2 eggs and some vanilla
    """

    // When: Structure with Claude
    let recipe = try await structurer.structure(transcript: messyTranscript)

    // Then: Should still extract basic info
    XCTAssertTrue(recipe.title.lowercased().contains("cookie"))
    XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 3, "Should extract main ingredients")
}

func test_claude_handlesAPIRateLimiting() async throws {
    // Given: API rate limit exceeded
    let structurer = ClaudeRecipeStructurer(apiKey: testAPIKey)

    // When: Make multiple rapid requests (simulate rate limit)
    var results: [Result<Recipe, Error>] = []
    for i in 1...10 {
        do {
            let recipe = try await structurer.structure(transcript: "test \(i)")
            results.append(.success(recipe))
        } catch {
            results.append(.failure(error))
        }
    }

    // Then: Should handle rate limits gracefully
    let failures = results.filter { if case .failure = $0 { return true } else { return false } }
    if !failures.isEmpty {
        // Verify error is rate limit (not crash)
        // Verify user sees friendly error message
    }
}

func test_claude_handlesMalformedAPIResponse() async throws {
    // Mock Claude returning invalid JSON
    let mockClaude = MockClaudeClient(response: "{invalid json")
    let structurer = ClaudeRecipeStructurer(client: mockClaude)

    // Should throw structured error (not crash)
    do {
        let _ = try await structurer.structure(transcript: "test")
        XCTFail("Should throw error for malformed response")
    } catch {
        XCTAssertTrue(error is APIError)
    }
}
```

**Estimated Effort**: 8-10 hours (includes API integration setup)

#### 3. End-to-End Pipeline Tests (Critical)

**Test the full flow**: URL → Audio → Transcription → Structuring → Recipe

```swift
func test_videoImport_endToEndPipeline_realYouTubeVideo() async throws {
    // Given: Known YouTube video with recipe (use test account)
    let testVideoURL = "https://www.youtube.com/watch?v=TEST_RECIPE_VIDEO"

    // When: Process full pipeline
    let processor = VideoRecipeProcessor(
        transcriber: WhisperKitTranscriber(),
        structurer: ClaudeRecipeStructurer(apiKey: realAPIKey),
        logger: logger,
        analytics: analytics
    )

    let recipe = try await processor.process(url: testVideoURL, context: modelContext)

    // Then: Verify complete recipe created
    XCTAssertFalse(recipe.title.isEmpty, "Should extract title")
    XCTAssertGreaterThan(recipe.ingredients?.count ?? 0, 0, "Should extract ingredients")
    XCTAssertGreaterThan(recipe.instructions.count, 0, "Should extract instructions")
    XCTAssertEqual(recipe.sourceType, .video)
    XCTAssertEqual(recipe.sourceURL, testVideoURL)

    // Verify saved to database
    try modelContext.save()
    let fetchDescriptor = FetchDescriptor<Heirloom.Recipe>()
    let recipes = try modelContext.fetch(fetchDescriptor)
    XCTAssertEqual(recipes.count, 1)
}

func test_videoImport_resumesAfterNetworkFailure() async throws {
    // Given: Import in progress, network fails mid-transcription
    let processor = VideoRecipeProcessor(...)
    let job = VideoImportJob(url: testURL)

    // Simulate network failure during transcription
    try await processor.startProcessing(job: job)
    // ... simulate network disconnect

    // When: Network restored, resume
    try await processor.resumeProcessing(job: job)

    // Then: Should complete from where it left off (not restart)
    XCTAssertEqual(job.progress, 1.0)
    XCTAssertTrue(job.isCompleted)
}

func test_videoImport_handlesPartialResults() async throws {
    // Given: Transcription succeeds, structuring fails
    let processor = VideoRecipeProcessor(...)

    // When: Process with Claude API error
    // (Mock structurer that fails)

    // Then: Should save partial results
    // - Transcript saved
    // - User can retry structuring
    // - Don't lose transcription work
}
```

**Estimated Effort**: 10-12 hours

### Phase 2: Error Handling & Recovery (Medium Priority)

```swift
func test_videoImport_apiQuotaExceeded_queuesForRetry()
func test_videoImport_invalidVideo_showsClearError()
func test_videoImport_cancelMidProcess_cleansUpCorrectly()
func test_videoImport_appBackgrounded_pausesProcessing()
```

**Estimated Effort**: 6-8 hours

### Phase 3: OCR Pipeline (Future - When Implemented)

Similar approach for cookbook scan:
- Vision API integration tests
- Claude structuring from OCR text
- Image quality handling
- Multi-page cookbook support

**Estimated Effort**: 15-20 hours (once feature implemented)

---

## Test Environment Setup

### Required Test Assets

1. **Audio Files** (5-10 files, ~50MB total):
   - Clean narration (English)
   - Noisy kitchen background
   - Non-native accents
   - Multiple languages (Spanish, French)
   - Poor audio quality (mumbled, low volume)

2. **Video URLs** (YouTube test videos):
   - Create unlisted test videos on YouTube
   - Cover various recipe types (baking, cooking, drinks)
   - Different video qualities (720p, 1080p)
   - Different lengths (2 min, 10 min, 30 min)

3. **API Keys**:
   - Claude API (test account with quota)
   - YouTube Data API (for metadata)
   - Firebase (test project)

### CI/CD Considerations

**Problem**: AI tests are slow and may hit API limits.

**Solution**: Separate test suites
```bash
# Fast unit tests (run on every commit)
xcodebuild test -scheme Heirloom -only-testing:HeirloomTestsV2/Unit

# AI integration tests (run nightly)
xcodebuild test -scheme Heirloom -only-testing:HeirloomTestsV2/Integration/AI
```

**Cost Management**:
- Use cached results when possible
- Limit CI to 10 AI calls per run
- Full AI tests only on release branches

---

## Recommended Priorities

### Critical (Do First)

1. **Claude Structuring Tests** (8-10 hours) - Highest risk, user-facing
   - Well-formatted transcript → recipe
   - Poorly structured transcript → still extracts basics
   - API errors handled gracefully

2. **End-to-End Pipeline** (10-12 hours) - Integration validation
   - Real YouTube video → saved recipe
   - Network failures handled
   - Partial results saved

### Important (Do Second)

3. **WhisperKit Transcription** (6-8 hours) - Quality validation
   - Accuracy tests with known transcripts
   - Background noise handling
   - Multiple languages

4. **Error Handling** (6-8 hours) - Reliability
   - API quota exceeded
   - Invalid video formats
   - Network failures

### Nice to Have

5. **Performance Tests** - Ensure fast processing
6. **ASMR Pipeline** - Once feature more mature
7. **OCR Pipeline** - When implemented

---

## Success Criteria

After completing AI pipeline testing:

- ✅ At least 5 end-to-end tests with real YouTube videos
- ✅ Claude API integration tested with 10+ transcripts
- ✅ All error paths tested (network, API limits, bad input)
- ✅ Partial result recovery tested
- ✅ Real coverage: 60%+ (not placeholder tests)

---

## Estimated Total Effort

**Critical Tests**: 18-22 hours
**Important Tests**: 12-16 hours
**Total**: 30-38 hours for comprehensive AI pipeline coverage

**ROI**: Very high - this is a premium feature and major differentiator

---

## Next Steps

1. Record/source test audio files (2-3 hours)
2. Create test YouTube videos (2-3 hours)
3. Set up Claude API test account
4. Implement critical tests (18-22 hours)
5. Add to CI/CD (separate nightly suite)

Ready to implement? I can start with Claude structuring tests (highest value).
