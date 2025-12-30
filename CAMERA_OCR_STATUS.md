# Camera & OCR Status Report

**Date**: December 29, 2025
**Build**: 1.1.3 (33)
**Status**: Investigation Complete

## Executive Summary

**Good News**: iOS app and web demo already use the SAME OCR technology (Claude Sonnet 4 vision API) with nearly identical prompts. They should have parity.

**Issues Identified**:
1. Camera viewport not filling screen (separate UX issue)
2. AI enhancement may be disabled or not configured (feature flag + API key)
3. No device testing performed to verify actual OCR accuracy

---

## OCR Technology Comparison

### Web Demo
- **Location**: `/Users/matthanson/rationale-public/app/api/heirloom/extract-recipe/route.ts`
- **Technology**: Claude Sonnet 4 vision API
- **Model**: `claude-sonnet-4-20250514`
- **Method**: Direct image → Claude vision API → structured JSON
- **Features**:
  - Bounding box support for multi-recipe images
  - Confidence scoring (high/medium/low)
  - Rate limiting (10 req/min)
  - 10MB image limit

**Prompt Structure** (lines 123-151):
```
You are an OCR system for recipe cards. Extract the recipe from this image and return ONLY valid JSON...
{
  "title": "Recipe Name",
  "ingredients": [...],
  "instructions": [...],
  "servings": "4" or null,
  "prepTime": "15 min" or null,
  "cookTime": "30 min" or null,
  "confidence": { "title": "high", "ingredients": "medium", ... }
}
```

### iOS App
- **Location**: `/Users/matthanson/Heirloom/Heirloom/Core/Services/AI/AIRecipeExtractor.swift`
- **Technology**: Claude Sonnet 4 vision API (same as web demo)
- **Model**: `claude-sonnet-4-20250514` (identical to web demo)
- **Method**: 2-step process
  1. `detectRecipes()` - Find recipes with bounding boxes
  2. `extractRecipesFromImage()` - Extract each recipe via vision API
- **Features**:
  - Bounding box support for multi-recipe images
  - Confidence scoring (0.0-1.0 decimal)
  - Fallback to basic text extraction if AI disabled
  - Rate limiting (100 req/day for default key)

**Prompt Structure** (lines 349-388):
```
Extract the recipe from this image and return it as structured JSON.
{
  "title": "Recipe Title",
  "servings": "4 servings",
  "prep_time": "15 min",
  "cook_time": "30 min",
  "ingredients": [...],
  "instructions": [...],
  "notes": "Optional notes",
  "confidence": 0.95
}
```

### Conclusion
**The iOS app and web demo use identical OCR technology.** They should have parity in extraction accuracy.

---

## Why "Parity" Issues Might Occur

### 1. AI Enhancement Not Enabled
**File**: `AIConfiguration.swift:21-23`
```swift
@Published var enableAIEnhancement: Bool
```

**Impact**: If `enableAIEnhancement` is `false`, the scanner will throw an error:
```swift
// AIRecipeExtractor.swift:276-278
guard AIConfiguration.shared.enableAIEnhancement,
      AIConfiguration.shared.isConfigured(provider: .anthropic) else {
    throw AIError.notConfigured(provider: "Anthropic")
}
```

**Check**:
- Open app → Settings → AI Settings
- Verify "AI Enhancement" toggle is ON
- Verify API key is configured (either user key or default key)

### 2. API Key Not Configured
**File**: `AIConfiguration.swift:90-93`

The app needs either:
1. User-provided Anthropic API key (stored in iOS Keychain)
2. Default API key from `Info.plist` key `DEFAULT_ANTHROPIC_KEY`

**Impact**: Without API key, scanner will fail and show error.

**Check**:
```bash
# Check if default key is configured in build
/usr/libexec/PlistBuddy -c "Print :DEFAULT_ANTHROPIC_KEY" Heirloom/Resources/Info.plist
```

### 3. Camera Viewport Not Filling Screen
**File**: `EnhancedScannerView.swift:507-527`

**Issue**: The camera preview uses `UIViewRepresentable` with manual frame updates:
```swift
func updateUIView(_ uiView: UIView, context: Context) {
    if let previewLayer = cameraManager.getPreviewLayer() {
        previewLayer.frame = uiView.bounds  // May not update properly on rotation
    }
}
```

**Impact**:
- Camera viewport may not fill screen on all devices/orientations
- Smaller capture area = lower image quality = worse OCR results
- User perceives this as "OCR not working as well"

**Fix Required**: See "Camera Viewport Fix" section below.

---

## Scanner Processing Flow

**Current Implementation** (EnhancedScannerView.swift:287-301):

```swift
private func processImage() {
    // Step 1: Detect recipes with bounding boxes (vision API)
    let detected = try await AIRecipeExtractor.shared.detectRecipes(from: image)

    // Step 2: Extract each recipe using vision API + bounding box
    let result = try await AIRecipeExtractor.shared.extractRecipesFromImage(
        image: image,
        detectedRecipes: detected
    )

    // Step 3: Show results to user
    multiRecipeResult = result
}
```

**Key Points**:
- Uses vision API directly (no Apple Vision framework OCR step)
- Same technology as web demo
- Will fail gracefully if AI not configured

---

## Camera Viewport Fix

**Problem**: Camera preview may not fill screen properly on all devices/orientations.

**Root Cause**: `CameraPreviewView.updateUIView()` updates frame, but SwiftUI may not propagate bounds changes correctly during layout/rotation.

**Affected File**: `EnhancedScannerView.swift:507-527`

**Proposed Fix**:
1. Add `GeometryReader` to get accurate parent view size
2. Use `.onAppear` and `.onChange(of: geometry.size)` to update preview layer
3. Ensure `.ignoresSafeArea()` is applied correctly
4. Test on multiple devices (iPhone SE, Pro, Pro Max) and orientations

**Priority**: HIGH - This directly affects image quality and user-perceived OCR accuracy.

---

## Testing Recommendations

### 1. Verify AI Configuration
- [ ] Check AI enhancement is enabled in Settings
- [ ] Verify API key is configured (default or user key)
- [ ] Test scanner on simulator - should extract recipe successfully
- [ ] Check console logs for "🔍 Step 1: Detecting recipes with vision API..."

### 2. Camera Viewport Testing
- [ ] Test on iPhone SE (smallest screen)
- [ ] Test on iPhone 15 Pro Max (largest screen)
- [ ] Test in portrait and landscape orientations
- [ ] Verify preview layer fills entire screen (no black bars)
- [ ] Take screenshot and measure viewport coverage

### 3. OCR Accuracy Testing
- [ ] Test with 5 different recipe cards (printed)
- [ ] Test with 5 different recipe cards (handwritten)
- [ ] Test with multi-recipe pages (2-3 recipes)
- [ ] Compare results with web demo on same images
- [ ] Measure accuracy:
  - Title extraction: X/10 correct
  - Ingredients extraction: Y% complete
  - Instructions extraction: Z% complete
  - Confidence scores: Average value

### 4. Edge Cases
- [ ] Test with poor lighting (dim, shadows)
- [ ] Test with blurry images
- [ ] Test with angled/skewed photos
- [ ] Test with non-recipe images (should fail gracefully)
- [ ] Test with API key missing (should show clear error)

---

## Next Steps

1. **IMMEDIATE**: Fix camera viewport fill issue (2-3 hours)
2. **BEFORE DEVICE TESTING**: Verify AI configuration on device
3. **DEVICE TESTING**: Test OCR accuracy on 2 physical iPhones (4-6 hours)
4. **COMPARISON**: Run same images through web demo and iOS app
5. **DOCUMENTATION**: Record accuracy metrics in testing doc

---

## Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| `AIConfiguration.swift` | AI settings, model config, API keys | 168-179 (model) |
| `AIRecipeExtractor.swift` | Vision API extraction logic | 271-306 (extract), 313-347 (multi) |
| `EnhancedScannerView.swift` | Camera UI and processing flow | 287-301 (process), 507-527 (preview) |
| `AnthropicAIService.swift` | Claude API client | (need to check) |
| `/Users/matthanson/rationale-public/app/api/heirloom/extract-recipe/route.ts` | Web demo OCR endpoint | 77-242 |

---

## Conclusion

**iOS and web demo have OCR parity** - they use identical technology. Any perceived differences are likely due to:
1. Camera viewport not filling screen (image quality issue)
2. AI features disabled or not configured
3. Lack of device testing to verify actual performance

**Action Required**: Fix camera viewport (next task) and perform comprehensive device testing.
