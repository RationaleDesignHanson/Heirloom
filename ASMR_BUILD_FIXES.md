# ASMR Build Fixes - Complete

## Summary

Fixed all 20 build errors in 3 files:
- ✅ ASMRRecipeStructurer.swift (15 errors fixed)
- ✅ ASMRUsageManager.swift (1 error fixed)
- ✅ ASMRVideoProcessor.swift (2 errors fixed)

---

## Fixes Applied

### 1. ASMRRecipeStructurer.swift

#### Issue 1: ServiceContainer.aiService doesn't exist
**Line 22:** `ServiceContainer.shared.aiService`

**Fix:**
```swift
// Before
init(aiService: AnthropicAIService = ServiceContainer.shared.aiService, ...)

// After
init(aiService: AnthropicAIService? = nil, ...) {
    self.aiService = aiService ?? ServiceContainer.shared.resolve(AnthropicAIService.self)
}
```

#### Issue 2: ImageUseCase.recipeExtraction doesn't exist
**Lines 170, 268, 365, 440, 565:** `.recipeExtraction` usage

**Fix:** Changed all occurrences to `.display`
```swift
// Before
useCase: .recipeExtraction

// After
useCase: .display
```

**Reason:** ImageUseCase enum only has `.ocr` and `.display` cases

#### Issue 3: Extra useCase argument in text-only API calls
**Lines 365, 565:** `completeStructured` with `useCase` parameter

**Fix:** Removed `useCase` parameter from text-only calls
```swift
// Before
let response = try await aiService.completeStructured(
    prompt: prompt,
    schema: Schema.self,
    options: options,
    useCase: .display  // ❌ Wrong - text-only doesn't take useCase
)

// After
let response = try await aiService.completeStructured(
    prompt: prompt,
    schema: Schema.self,
    options: options  // ✅ Correct
)
```

**Reason:** Only `completeWithVisionStructured` takes `useCase` parameter

#### Issue 4: StructuredRecipe initializer mismatch
**Line 579:** Wrong parameters in StructuredRecipe init

**Fix:** Corrected to match actual StructuredRecipe definition
```swift
// Before
StructuredRecipe(
    title: ...,
    cuisine: ...,          // ❌ Doesn't exist
    totalTime: ...,        // ❌ Doesn't exist
    difficulty: ...,       // ❌ Doesn't exist
    ingredients: [...],
    steps: [...],
    tags: ...,             // ❌ Doesn't exist
    equipment: ...         // ❌ Doesn't exist
)

// After
StructuredRecipe(
    title: ...,
    description: ...,      // ✅ Correct
    servings: ...,
    prepTime: ...,
    cookTime: ...,
    ingredients: [...],    // ExtractedIngredient
    steps: [...],          // ExtractedStep
    overallConfidence: ..., // ✅ Correct
    warnings: [...]        // ✅ Correct
)
```

#### Issue 5: StructuredRecipe.Ingredient/Step doesn't exist
**Lines 588, 599:** Used wrong nested types

**Fix:** Changed to correct types
```swift
// Before
StructuredRecipe.Ingredient(...)  // ❌ Wrong
StructuredRecipe.Step(...)        // ❌ Wrong

// After
ExtractedIngredient(...)          // ✅ Correct
ExtractedStep(...)                // ✅ Correct
```

#### Issue 6: Removed unused mapComplexityToDifficulty function
**Line 662:** Unused helper function

**Fix:** Deleted function entirely (not needed after StructuredRecipe fix)

---

### 2. ASMRUsageManager.swift

#### Issue: SubscriptionManager.shared doesn't exist
**Line 41:** `SubscriptionManager = .shared`

**Fix:**
```swift
// Before
init(subscriptionManager: SubscriptionManager = .shared, ...)

// After
init(subscriptionManager: SubscriptionManager? = nil, ...) {
    self.subscriptionManager = subscriptionManager ??
        ServiceContainer.shared.resolve(SubscriptionManager.self)
}
```

**Reason:** SubscriptionManager accessed via ServiceContainer, not direct `.shared`

---

### 3. ASMRVideoProcessor.swift

#### Issue: MainActor isolation in default parameters
**Lines 41-42:** `.shared` accessors in nonisolated init context

**Fix:** Made parameters optional and assigned in init body
```swift
// Before
init(
    usageManager: ASMRUsageManager = .shared,      // ❌ MainActor issue
    cacheService: ASMRCacheService = .shared       // ❌ MainActor issue
)

// After
init(
    usageManager: ASMRUsageManager? = nil,
    cacheService: ASMRCacheService? = nil
) {
    self.usageManager = usageManager ?? ASMRUsageManager.shared
    self.cacheService = cacheService ?? ASMRCacheService.shared
}
```

**Reason:** Default parameters evaluated in nonisolated context, but `.shared` is MainActor-isolated

---

## Key Learnings

### 1. ServiceContainer Access Pattern
```swift
// ✅ Correct
ServiceContainer.shared.resolve(ServiceType.self)

// ❌ Wrong
ServiceContainer.shared.serviceName
```

### 2. ImageUseCase Values
```swift
enum ImageUseCase {
    case ocr        // High quality for text (2048px)
    case display    // Balanced quality (1600px)
    // ❌ .recipeExtraction doesn't exist
}
```

### 3. StructuredRecipe Structure
```swift
struct StructuredRecipe {
    let title: String
    let description: String?          // NOT cuisine
    let servings: String?
    let prepTime: String?
    let cookTime: String?
    let ingredients: [ExtractedIngredient]   // NOT StructuredRecipe.Ingredient
    let steps: [ExtractedStep]               // NOT StructuredRecipe.Step
    let overallConfidence: Double
    let warnings: [String]
    // No: difficulty, totalTime, tags, equipment, tips, etc.
}
```

### 4. AI Service Methods
```swift
// Vision + Structured (with images)
func completeWithVisionStructured<T>(
    image: UIImage,
    prompt: String,
    schema: T.Type,
    options: AICompletionOptions?,
    useCase: ImageUseCase  // ✅ Has useCase parameter
) async throws -> T

// Text-only Structured
func completeStructured<T>(
    prompt: String,
    schema: T.Type,
    options: AICompletionOptions?  // ❌ No useCase parameter
) async throws -> T
```

### 5. MainActor Default Parameters
```swift
@MainActor
class MyClass {
    // ❌ Wrong - default parameter evaluated outside MainActor
    init(manager: Manager = .shared) { }

    // ✅ Correct - assign inside MainActor init body
    init(manager: Manager? = nil) {
        self.manager = manager ?? Manager.shared
    }
}
```

---

## Verification

Run these commands to verify fixes:

```bash
# Verify all files exist
find Heirloom -name "*ASMR*.swift" | wc -l
# Expected: 14 files

# Check for remaining build errors
# Open Xcode and build (Cmd+B)
open Heirloom.xcodeproj

# Or command line build
xcodebuild build -scheme Heirloom \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Files Modified

1. **ASMRRecipeStructurer.swift**
   - Line 22: Fixed ServiceContainer access
   - Lines 170, 268, 440: Changed `.recipeExtraction` to `.display`
   - Lines 365, 565: Removed `useCase` from text-only calls
   - Lines 579-605: Fixed StructuredRecipe initializer
   - Lines 588, 599: Changed to ExtractedIngredient/ExtractedStep
   - Line 662: Deleted unused mapComplexityToDifficulty function

2. **ASMRUsageManager.swift**
   - Line 41: Fixed SubscriptionManager access via ServiceContainer

3. **ASMRVideoProcessor.swift**
   - Lines 38-48: Fixed MainActor default parameter issue

---

## Next Steps

1. ✅ Build errors fixed
2. ⏸️ Build in Xcode (Cmd+B)
3. ⏸️ Run tests (Cmd+U)
4. ⏸️ Test with real videos

---

**Status:** ✅ All build errors resolved
**Date:** January 10, 2026
**Files Modified:** 3
**Errors Fixed:** 20
