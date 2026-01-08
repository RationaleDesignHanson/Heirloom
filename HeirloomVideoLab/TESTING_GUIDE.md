# HeirloomVideoLab Testing Guide

## Overview

Comprehensive testing strategy for video-to-recipe extraction feature, covering unit tests, integration tests, and manual testing procedures.

## Test Infrastructure Setup

### 1. Test Target Configuration

When creating Xcode target, configure test target as follows:

```
Target Name: HeirloomVideoLabTests
Host Application: HeirloomVideoLab
Build Configuration: Debug
Test Host: $(BUILT_PRODUCTS_DIR)/HeirloomVideoLab.app/HeirloomVideoLab
```

### 2. Test Resources

Create test video corpus in `HeirloomVideoLabTests/TestResources/Videos/`:

**Required Test Videos**:

| File | Duration | Purpose | Details |
|------|----------|---------|---------|
| `sample_recipe.mp4` | 30-60s | Happy path testing | Clear audio, simple recipe (scrambled eggs or similar) |
| `recipe_with_text.mp4` | 1-2 min | OCR testing | On-screen text with temperatures, times, measurements |
| `silent_video.mp4` | 30s | Error testing | Video without audio track |
| `noisy_audio.mp4` | 1 min | Robustness testing | Background noise, music, poor audio quality |
| `long_recipe.mp4` | 10-15 min | Performance testing | Full recipe tutorial for timing validation |
| `sample_audio.m4a` | 30s | Transcription testing | Pre-extracted audio file |

**Ground Truth Files** (`TestResources/GroundTruth/`):

```json
// sample_recipe_expected.json
{
  "title": "Simple Scrambled Eggs",
  "ingredients": [
    { "item": "eggs", "quantity": "2", "unit": null },
    { "item": "butter", "quantity": "1", "unit": "tbsp" },
    { "item": "salt", "quantity": "to taste", "unit": null }
  ],
  "steps": [
    { "instruction": "Heat butter in pan", "temperature": "medium heat" },
    { "instruction": "Whisk eggs and add to pan", "duration": null },
    { "instruction": "Cook until just set", "duration": "2-3 minutes" }
  ]
}
```

### 3. Adding Test Resources to Xcode

1. Create `TestResources` group in HeirloomVideoLabTests
2. Drag video files into group
3. In File Inspector: ✅ Target Membership: HeirloomVideoLabTests
4. Build: Xcode will copy to test bundle

**Note**: Do NOT commit videos to Git. Use Git LFS or download script:

```bash
# Scripts/download-test-videos.sh
#!/bin/bash
# Download test videos from cloud storage (S3, Dropbox, etc.)
curl -o TestResources/Videos/sample_recipe.mp4 "https://your-storage/sample_recipe.mp4"
curl -o TestResources/Videos/recipe_with_text.mp4 "https://your-storage/recipe_with_text.mp4"
# ... etc
```

## Running Tests

### Command Line

```bash
# Run all tests
xcodebuild test -scheme HeirloomVideoLab -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Run specific test class
xcodebuild test -scheme HeirloomVideoLab -only-testing:HeirloomVideoLabTests/AudioExtractionServiceTests

# Run on physical device (required for WhisperKit tests)
xcodebuild test -scheme HeirloomVideoLab -destination 'platform=iOS,name=Matt's iPhone'
```

### Xcode GUI

1. **Product → Test** (⌘U)
2. **Test Navigator** (⌘6) → Click diamond next to test/class/suite
3. **View test coverage**: Editor → Show Code Coverage

### GitHub Actions / CI

```yaml
# .github/workflows/test-videolab.yml
name: HeirloomVideoLab Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Download test resources
        run: ./Scripts/download-test-videos.sh
      - name: Run tests
        run: |
          xcodebuild test \
            -scheme HeirloomVideoLab \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES
```

## Unit Test Coverage

### AudioExtractionServiceTests (11 tests)

✅ `testExtractAudioFromValidVideo` - Verifies audio extraction produces valid M4A
✅ `testAudioDurationEstimation` - Checks duration estimation accuracy
✅ `testExtractedAudioHasCorrectFormat` - Validates audio format for transcription
✅ `testExtractAudioFromVideoWithoutAudio_ThrowsError` - Error handling for silent video
✅ `testExtractAudioFromInvalidFile_ThrowsError` - Invalid file handling
✅ `testExtractAudioFromCorruptedVideo_ThrowsError` - Corrupted file handling
✅ `testAudioExtractionPerformance` - Ensures extraction completes <15 seconds
✅ `testCleanupTemporaryAudio` - Verifies temporary file cleanup
✅ `testCleanupNonexistentFile_DoesNotThrow` - Cleanup error handling

**Run**: `xcodebuild test -only-testing:HeirloomVideoLabTests/AudioExtractionServiceTests`

### TranscriptionServiceTests (12 tests)

✅ `testSelectOptimalModel_LowMemoryDevice` - Model selection based on RAM
✅ `testModelSelection_ReturnsValidModelName` - Validates model names
✅ `testMockTranscriptionService_Availability` - Mock service availability
✅ `testMockTranscriptionService_ReturnsValidResult` - Mock result validation
✅ `testMockTranscriptionService_IncludesSegments` - Timestamped segments
✅ `testAdaptiveService_InitializesCorrectly` - Adaptive service initialization
✅ `testAdaptiveService_SelectsWhisperKitOnOlderDevices` - Provider selection
✅ `testTranscriptionResult_HasRequiredFields` - Data model validation
✅ `testTranscriptionCaching_StoresResult` - Cache storage
✅ `testTranscriptionCaching_ReturnsNilForMissingHash` - Cache miss handling
✅ `testTranscriptionError_InvalidAudioFile` - Error handling
✅ `testMockTranscriptionPerformance` - Performance verification

**Note**: Real WhisperKit tests commented out (require physical device)

**Run**: `xcodebuild test -only-testing:HeirloomVideoLabTests/TranscriptionServiceTests`

### FrameAnalysisServiceTests (15 tests)

✅ `testExtractKeyFrames_ValidVideo` - Frame extraction count verification
✅ `testExtractKeyFrames_FrameSizeLimit` - Max dimension enforcement (1280x720)
✅ `testExtractKeyFrames_DistributedTiming` - Even distribution across video
✅ `testExtractKeyFrames_InvalidVideo_ThrowsError` - Invalid input handling
✅ `testAnalyzeForRecipeElements_WithText` - OCR text detection
✅ `testAnalyzeForRecipeElements_EmptyFrames` - Empty input handling
✅ `testAnalyzeForRecipeElements_RemovesDuplicates` - Deduplication logic
✅ `testFrameExtraction_Performance` - <5 second extraction time
✅ `testOCRAnalysis_Performance` - <10 second OCR time for 5 frames
✅ `testShouldSkipFrameAnalysis_HighConfidence` - Skip logic (>= 0.85)
✅ `testShouldSkipFrameAnalysis_LowConfidence` - No skip logic (< 0.85)
✅ `testShouldSkipFrameAnalysis_ThresholdEdgeCase` - Boundary testing
✅ `testDetectTextOverlays` - Text overlay detection
✅ `testExtractKeyFramesAdaptive` - Adaptive sampling
✅ `testFrameExtraction_MemoryEfficient` - Memory constraint verification

**Run**: `xcodebuild test -only-testing:HeirloomVideoLabTests/FrameAnalysisServiceTests`

### ClaudeRecipeStructurerTests (18 tests)

✅ `testStructureRecipe_ValidTranscript` - Basic recipe extraction
✅ `testStructureRecipe_WithoutVisualElements` - Transcript-only extraction
✅ `testStructureRecipe_AllFieldsPopulated` - Complete data extraction
✅ `testIngredientExtraction_WithQuantities` - Explicit measurements
✅ `testIngredientExtraction_ImpreciseMeasurements` - Colloquial conversion
✅ `testStepExtraction_WithTimingAndTemp` - Timing/temperature extraction
✅ `testStepExtraction_LogicalOrdering` - Step sequencing
✅ `testOverallConfidence_HighQuality` - High confidence validation
✅ `testOverallConfidence_LowQuality_ThrowsError` - Low confidence rejection
✅ `testValidation_MissingTitle_ThrowsError` - Title requirement
✅ `testValidation_NoContent_ThrowsError` - Content requirement
✅ `testValidation_InvalidJSON_ThrowsError` - JSON parsing
✅ `testEstimateCost_ShortTranscript` - Cost estimation (<1 cent)
✅ `testEstimateCost_LongTranscript` - Cost validation ($0.01-0.05)
✅ `testEstimateCost_WithoutVisualElements` - Visual elements cost delta
✅ `testStructureRecipe_VeryShortTranscript` - Edge case handling
✅ `testStructureRecipe_VeryLongTranscript` - Large transcript handling

**Run**: `xcodebuild test -only-testing:HeirloomVideoLabTests/ClaudeRecipeStructurerTests`

### VideoRecipeProcessorTests (16 integration tests)

✅ `testProcessVideo_CompletePipeline` - End-to-end processing
✅ `testProcessVideo_ProgressIncreases` - Progress tracking (0.0 → 1.0)
✅ `testProcessVideo_WithCaching_UsesCachedResult` - Cache hit performance
✅ `testProcessVideo_WithoutCaching_ReprocessesEverytime` - No cache behavior
✅ `testProcessVideo_SkipsFrameAnalysis_HighConfidence` - Skip logic (>0.85)
✅ `testProcessVideo_PerformsFrameAnalysis_LowConfidence` - No skip (<0.85)
✅ `testProcessVideo_FrameAnalysisDisabled_SkipsRegardlessOfConfidence` - Config override
✅ `testProcessVideo_CalculatesCost` - Cost calculation
✅ `testCostTracking_AccumulatesAcrossVideos` - Cumulative cost tracking
✅ `testProcessVideo_AudioExtractionFails_ThrowsError` - Error propagation
✅ `testProcessVideo_TranscriptionFails_ThrowsError` - Error propagation
✅ `testProcessVideo_StructuringFails_ThrowsError` - Error propagation
✅ `testProcessVideo_FrameAnalysisFails_ContinuesProcessing` - Graceful degradation
✅ `testCancel_StopsProcessing` - Cancellation support
✅ `testProcessVideo_CompletesInReasonableTime` - Performance (<5s with mocks)
✅ `testProcessVideo_CreatesAttributionPlaceholder` - Attribution initialization

**Run**: `xcodebuild test -only-testing:HeirloomVideoLabTests/VideoRecipeProcessorTests`

## Integration Testing Checklist

### Prerequisites

- [ ] Xcode target created
- [ ] WhisperKit package added
- [ ] Test videos downloaded
- [ ] Physical device connected (for WhisperKit tests)

### Manual Integration Tests

#### Test 1: Happy Path (30s video)

1. **Setup**: Use `sample_recipe.mp4` (scrambled eggs or similar)
2. **Execute**:
   - Launch HeirloomVideoLab app
   - Tap "Import Video"
   - Select test video from Photos
3. **Verify**:
   - ✅ Processing completes without errors
   - ✅ Progress indicator shows all stages
   - ✅ Extracted recipe matches ground truth (within 80% accuracy)
   - ✅ Ingredients have quantities and units
   - ✅ Steps are logical and ordered
   - ✅ Attribution fields are present (empty, waiting for user)
   - ✅ Can save recipe to SwiftData

**Expected Time**: ~1-2 minutes

#### Test 2: Long Video (15 min)

1. **Setup**: Use `long_recipe.mp4`
2. **Execute**: Process through full pipeline
3. **Verify**:
   - ✅ Completes in 2-4 minutes
   - ✅ Memory usage stable (<500MB peak)
   - ✅ No crashes or freezes
   - ✅ Cost estimate ~$0.02-0.03

**Expected Time**: 2-4 minutes

#### Test 3: Poor Quality Audio

1. **Setup**: Use `noisy_audio.mp4`
2. **Execute**: Process video
3. **Verify**:
   - ✅ Completes (may have lower confidence)
   - ✅ Frame analysis triggered (low transcript confidence)
   - ✅ Warning shown for low confidence extractions

#### Test 4: Caching

1. **Execute**: Process same video twice
2. **Verify**:
   - ✅ First run: 2-4 minutes
   - ✅ Second run: <2 seconds (cached)
   - ✅ Results identical

#### Test 5: Cancellation

1. **Execute**:
   - Start processing long video
   - Tap Cancel after 30 seconds
2. **Verify**:
   - ✅ Processing stops immediately
   - ✅ Returns to idle state
   - ✅ No memory leaks (check Instruments)
   - ✅ Temporary files cleaned up

#### Test 6: Error Handling

1. **Test silent video**:
   - Use `silent_video.mp4`
   - Should show error: "Video has no audio track"

2. **Test invalid file**:
   - Select non-video file
   - Should show error: "Invalid video format"

3. **Test no internet** (for AI structuring):
   - Turn off WiFi/cellular
   - Should show error: "Unable to structure recipe (no internet)"

#### Test 7: Attribution Workflow

1. **Execute**: Process video to review screen
2. **Verify**:
   - ✅ Attribution section at top
   - ✅ Creator Name field required (can't save without)
   - ✅ Platform picker works
   - ✅ Source URL pre-filled
   - ✅ Warning shown if attribution incomplete
   - ✅ After saving, recipe shows attribution in metadata

## Performance Benchmarks

### Target Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Processing Time (5 min video) | <2 min | Manual stopwatch or Instruments |
| Processing Time (15 min video) | 2-4 min | Manual stopwatch or Instruments |
| Cost per 15-min video | $0.03-0.04 | Check console logs for token usage |
| Peak Memory Usage | <500MB | Xcode Memory Gauge or Instruments |
| Frame Extraction Time | <5 sec | Unit test assertion |
| OCR per Frame | <2 sec | Unit test assertion |
| Transcript Confidence | >0.75 avg | Aggregate from test corpus |
| Extraction Accuracy | >80% | Compare to ground truth |

### Performance Testing

**Using Xcode Instruments**:

```bash
# Profile with Time Profiler
xcodebuild \
  -scheme HeirloomVideoLab \
  -destination 'platform=iOS,name=YOUR_DEVICE' \
  -resultBundlePath ./TestResults/ProfileResults.xcresult \
  test

# Open in Instruments
open ./TestResults/ProfileResults.xcresult
```

**Memory Profiling**:

1. Run app on device
2. Xcode → Product → Profile (⌘I)
3. Select "Leaks" or "Allocations"
4. Process test video
5. Check for:
   - Memory leaks (should be 0)
   - Peak memory usage (<500MB)
   - Proper cleanup after processing

## Accuracy Validation

### Ground Truth Comparison

Create script to compare extraction results against ground truth:

```swift
// Scripts/validate-accuracy.swift
func compareRecipes(extracted: StructuredRecipe, expected: GroundTruthRecipe) -> Double {
    var score = 0.0

    // Title similarity
    score += titleSimilarity(extracted.title, expected.title) * 0.2

    // Ingredient accuracy
    let ingredientAccuracy = compareIngredients(extracted.ingredients, expected.ingredients)
    score += ingredientAccuracy * 0.5

    // Step accuracy
    let stepAccuracy = compareSteps(extracted.steps, expected.steps)
    score += stepAccuracy * 0.3

    return score
}
```

**Target**: >80% accuracy across test corpus

### Manual Review

For each test video:

1. Watch original video
2. Review extracted recipe
3. Mark each field:
   - ✅ Correct
   - ⚠️ Partially correct
   - ❌ Incorrect
   - ➖ Missing

Calculate accuracy:
```
Accuracy = (Correct + 0.5 * PartiallyCorrect) / (Total Fields)
```

## Test Maintenance

### When to Update Tests

- ✅ After changing service implementation
- ✅ After modifying protocols
- ✅ When adding new features
- ✅ After discovering bugs (add regression test)
- ✅ When WhisperKit version updates

### Adding New Test Videos

1. Record or find appropriate test video
2. Manually transcribe and extract recipe (ground truth)
3. Save to `TestResources/Videos/`
4. Create corresponding `_expected.json` file
5. Add test case referencing new video
6. Document in this guide

### CI/CD Integration

**Pre-merge Requirements**:

- ✅ All unit tests passing (automated)
- ✅ Code coverage >80% (automated)
- ✅ No new compiler warnings (automated)
- ⚠️ Manual integration test on 1-2 videos (before major releases)

## Troubleshooting Test Failures

### "Test video not found"

**Cause**: Test resources not in bundle
**Fix**:
1. Check File Inspector → Target Membership
2. Rebuild test target
3. Ensure test videos downloaded (run `Scripts/download-test-videos.sh`)

### "WhisperKit not available"

**Cause**: Running on simulator
**Fix**: Run on physical device only

### "Model download failed"

**Cause**: No internet or insufficient storage
**Fix**:
1. Check internet connection
2. Check available storage (>1GB free)
3. Try smaller model (tiny.en instead of base.en)

### "OCR finds no text"

**Cause**: Test video has no on-screen text
**Fix**: This is expected for some videos (e.g., `sample_recipe.mp4`)

### Tests timing out

**Cause**: Real services taking too long
**Fix**:
1. Use mock services for unit tests
2. Increase test timeout for integration tests:
```swift
// In test case:
executionTimeAllowance = 120  // 2 minutes
```

---

## Next Steps

1. ✅ Create Xcode test target
2. ✅ Download/create test videos
3. ✅ Run unit tests on simulator
4. ✅ Run integration tests on device
5. ✅ Validate accuracy against ground truth
6. ✅ Profile performance with Instruments
7. ✅ Add CI/CD pipeline

**Target**: >80% test coverage before integration to main app
