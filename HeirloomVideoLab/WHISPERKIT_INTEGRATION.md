# WhisperKit Integration Guide

## Overview

WhisperKit is an on-device speech recognition framework that enables high-quality transcription without API costs. It's a key dependency for the video-to-recipe feature.

**Benefits**:
- ✅ **Free** - No API costs, unlimited transcriptions
- ✅ **On-device** - Privacy-preserving, works offline
- ✅ **Fast** - Optimized for Apple Silicon
- ✅ **Accurate** - Based on OpenAI's Whisper model

## Adding WhisperKit to Xcode

### Step 1: Add Swift Package

1. Open `Heirloom.xcodeproj` in Xcode
2. File → Add Package Dependencies
3. Enter URL: `https://github.com/argmaxinc/WhisperKit`
4. Version: `0.7.2` or later
5. Add to targets: **HeirloomVideoLab** (and later, **Heirloom**)

### Step 2: Configure Build Settings

WhisperKit requires iOS 16+ and specific build settings:

**Deployment Target**: iOS 16.0 minimum
**Swift Version**: 5.9+

### Step 3: Download Models

WhisperKit models are downloaded on first use. Available models:

| Model | Size | RAM Required | Accuracy | Speed |
|-------|------|-------------|----------|-------|
| tiny.en | 39MB | ~1GB | ⭐⭐ | ⚡⚡⚡ |
| base.en | 74MB | ~2GB | ⭐⭐⭐ | ⚡⚡ |
| small.en | 244MB | ~4GB | ⭐⭐⭐⭐ | ⚡ |
| medium.en | 769MB | ~6GB | ⭐⭐⭐⭐⭐ | 🐢 |

Our implementation auto-selects based on device RAM:
- < 4GB RAM → tiny.en
- 4-6GB RAM → base.en (recommended)
- > 6GB RAM → small.en

## Updating WhisperKitTranscriptionService

Once WhisperKit is added, update the placeholder types:

### Remove Placeholder Types

Delete lines 11-67 in `WhisperKitTranscriptionService.swift`:

```swift
// DELETE THESE PLACEHOLDERS:
struct WhisperKit { ... }
struct WhisperKitResult { ... }
struct WhisperSegment { ... }
// etc.
```

### Add Real Import

Replace with:

```swift
import WhisperKit
```

### Update Usage

The rest of the file should work as-is! The service will:
1. Detect device RAM
2. Select appropriate model
3. Download model on first use (cached thereafter)
4. Transcribe audio with progress updates

## Usage Example

```swift
// Initialize (async, downloads model first time)
let service = await WhisperKitTranscriptionService()

// Check availability
if service.isAvailable {
    // Transcribe audio
    let result = try await service.transcribe(audioURL: audioFileURL)

    print("Transcript: \(result.text)")
    print("Confidence: \(result.confidence)")
    print("Provider: \(result.provider.displayName)")
}
```

## Performance Considerations

### First Run
- Model download: ~30 seconds - 2 minutes (depending on model size)
- Models cached to device, no re-download needed
- Show "Downloading transcription model..." message to user

### Subsequent Runs
- base.en model: ~0.1-0.2x real-time (5 min video → 30-60 sec transcription)
- tiny.en model: ~0.05-0.1x real-time (5 min video → 15-30 sec transcription)
- small.en model: ~0.2-0.3x real-time (5 min video → 1-1.5 min transcription)

### Memory Usage
- Peak memory during transcription: 2-6GB depending on model
- Service automatically selects model based on available RAM
- Monitor with Xcode Instruments if experiencing crashes

## Simulator Limitations

⚠️ **WhisperKit does NOT work on iOS Simulator**

The service checks `#if targetEnvironment(simulator)` and returns `isAvailable = false`.

**Testing Options**:
1. Use MockTranscriptionService for simulator testing
2. Test on physical device only
3. Use AdaptiveTranscriptionService (falls back to mock in simulator)

## Error Handling

```swift
do {
    let result = try await service.transcribe(audioURL: audioURL)
    // Success!
} catch TranscriptionError.modelLoadFailed {
    // Model download failed - check internet connection
} catch TranscriptionError.transcriptionFailed {
    // Audio quality too poor or incompatible format
} catch VideoImportError.transcriptionUnavailable {
    // Service not available (simulator or model not loaded)
}
```

## Cost Savings

**WhisperKit vs Cloud Transcription**:

| Videos/Month | Cloud Cost (OpenAI Whisper API) | WhisperKit Cost |
|-------------|--------------------------------|-----------------|
| 10 | ~$0.60 | $0.00 |
| 100 | ~$6.00 | $0.00 |
| 1,000 | ~$60.00 | $0.00 |

*Assuming 5-minute videos @ $0.006/minute*

**Target**: Process videos at **$0.03-0.04 per video** (Claude API only, no transcription cost)

## Troubleshooting

### "Model download failed"
- Check internet connection (first run only)
- Check available storage (models need 40MB-800MB)
- Try smaller model (tiny.en instead of base.en)

### "Out of memory" crash
- Device has insufficient RAM
- Service should auto-select smaller model
- If crash persists, manually select tiny.en

### "Transcription takes forever"
- Normal for first run (model download)
- Check CPU/GPU usage in Xcode
- Consider downgrading to smaller model

### "isAvailable = false"
- Running on simulator (not supported)
- Test on physical device
- Or use MockTranscriptionService

## iOS 26 SpeechAnalyzer (Future)

When iOS 26 is released (expected WWDC 2025):
- `SpeechAnalyzerTranscriptionService` will be implemented
- `AdaptiveTranscriptionService` will prefer SpeechAnalyzer
- WhisperKit remains as fallback for older devices
- Expected benefits: Faster, more accurate, lower battery usage

## References

- WhisperKit GitHub: https://github.com/argmaxinc/WhisperKit
- OpenAI Whisper: https://github.com/openai/whisper
- Apple Speech Framework: https://developer.apple.com/documentation/speech

## Next Steps

1. ✅ Add WhisperKit via SPM
2. ✅ Remove placeholder types from `WhisperKitTranscriptionService.swift`
3. ✅ Add `import WhisperKit`
4. ✅ Test on physical device with sample video
5. ✅ Monitor memory usage with Instruments
6. ✅ Verify model auto-selection works correctly

---

**Status**: Ready for integration when Xcode target is created
**Estimated Setup Time**: 15 minutes
**First Run**: 1-2 minutes (model download)
**Subsequent Runs**: 30-60 seconds per 5-minute video
