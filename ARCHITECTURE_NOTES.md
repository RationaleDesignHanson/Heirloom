# Architecture Notes for Unified Video Import Feature

## Existing Video Import Architecture

### Standard Extraction (`Heirloom/Features/Recipes/VideoImport/`)

**Entry Point**: `VideoImportView.swift`
- Presents video picker for camera roll selection
- Badge shows "From Camera Roll" mode indicator
- Requires spoken cooking instructions (best with clear narration)
- Attribution required during review
- Privacy note: "Audio is never stored permanently"

**Key Views**:
- `VideoImportView.swift` - Main entry with video picker
- `VideoProcessingView.swift` - Processing UI during extraction
- `VideoRecipeReviewView.swift` - Review extracted recipe before saving
- `VideoAttributionSheet.swift` - Attribution input
- `VideoExtractionDetailsView.swift` - Shows extraction details

**Dependencies**:
- `VideoProcessingJobManager` (StateObject) - Manages processing jobs
- `TabNavigationCoordinator` (EnvironmentObject) - Navigation coordination
- `FirebaseNotificationService` (EnvironmentObject) - Notifications
- `ToastManager` - Toast notifications

**Flow**:
1. User selects video from camera roll
2. Video is transcribed using WhisperKitTranscriptionService
3. Recipe extracted from transcript via AI
4. User reviews and optionally provides attribution
5. Recipe saved to SwiftData

### Visual/ASMR Extraction (`Heirloom/Features/Recipes/ASMRVideoImport/`)

**Entry Point**: `ASMRVideoImportView.swift`
- For silent videos or videos without clear speech
- Shows usage badge (credit system) - **NOTE: This will be replaced with subscription check**
- Requires user caption for context
- More expensive extraction (visual frame analysis)

**Key Views**:
- `ASMRVideoImportView.swift` - Main entry with caption input
- `ASMRProcessingView.swift` - Visual processing UI

**Current Paywall**:
- Uses `ASMRUsageManager.shared` for credit tracking
- Shows `showPaywall` state for paywall
- **IMPORTANT**: This credit system will be replaced with subscription-based hard wall

**Dependencies**:
- `ASMRUsageManager` (StateObject) - **TO BE REPLACED** with PaywallManager
- `VideoProcessingJobManager` (StateObject) - Same as standard import
- `TabNavigationCoordinator` (EnvironmentObject) - Navigation coordination

### Trigger Points in UI

**Location**: `Heirloom/Features/Recipes/RecipeList/`

**Current Add Recipe Flow** (`RecipeSheetModifiers.swift`):
```swift
// Separate sheets for different import types
.sheet(isPresented: $showAddRecipe) { RecipeEditorView() }
.sheet(isPresented: $showImportRecipe) { RecipeImportView() }
.sheet(isPresented: $showVideoImport) { VideoImportView() }
.sheet(isPresented: $showASMRVideoImport) { ASMRVideoImportView() }
.sheet(isPresented: $showCookbookScanner) { CookbookScannerView() }
```

**Navigation Pattern**:
- `RecipeListView.swift` holds state: `@State private var showAddRecipe = false`
- `RecipeListToolbarActions.swift` provides add button calling `onAddRecipe()`
- Multiple separate boolean states control which sheet appears

**Key Insight**: Currently users must choose between "Video Import" and "ASMR Video Import" upfront. The new unified approach will auto-detect which method to use.

## WhisperKitTranscriptionService API

**Location**: `Heirloom/Core/Services/Video/Transcription/WhisperKitTranscriptionService.swift`

```swift
@MainActor
class WhisperKitTranscriptionService: TranscriptionServiceProtocol {
    let provider: TranscriptionProvider = .whisperKit

    /// Shared instance (lazy loaded to prevent race conditions)
    private static var sharedWhisperKit: WhisperKit?

    /// Initialize with device-appropriate model
    init() async {
        // Selects optimal model: tiny.en, base.en, or small.en
        // Based on device memory (2GB, 4GB, 6GB+)
    }

    var isAvailable: Bool {
        Self.sharedWhisperKit != nil
    }

    /// Main transcription method
    func transcribe(audioURL: URL) async throws -> TranscriptionResult

    /// Preload model in background (call at app launch)
    static func preloadModel()

    /// Select optimal model for device
    static func selectOptimalModel() -> String // Returns: "tiny.en", "base.en", or "small.en"

    /// Check if device has enough memory
    static func checkMemoryAvailable() -> Bool // Requires 2GB+
}
```

**TranscriptionResult Structure**:
```swift
struct TranscriptionResult {
    let text: String                      // Full transcript
    let segments: [TranscriptSegment]     // Time-stamped segments
    let confidence: Double                // Estimated 0.4-0.8 (WhisperKit doesn't provide direct score)
    let provider: TranscriptionProvider   // .whisperKit
    let language: String?                 // Detected language
}

struct TranscriptSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}
```

**Confidence Estimation**:
- WhisperKit doesn't provide native confidence scores
- Service estimates using heuristics:
  - 0.8 = Good (has content + segments)
  - 0.6 = Moderate (has content, no segments)
  - 0.4 = Low (minimal/no content)

**Model Selection**:
- `tiny.en`: 39MB, 1GB RAM, fastest but least accurate
- `base.en`: 74MB, 2GB RAM, good balance (most devices)
- `small.en`: 244MB, 4GB RAM, best quality for sufficient RAM

**Important Notes**:
- Runs on `@MainActor` - all calls must be from main thread
- Singleton pattern prevents multiple model loads
- Model downloads on first use (background preload recommended)
- May fail on simulator or if download fails

## ProvenanceMetadata Model

**Location**: `Heirloom/Core/Models/ProvenanceMetadata.swift`

```swift
struct ProvenanceMetadata: Codable, Hashable {
    // MARK: - Source Origin
    var sourceType: SourceType              // Where recipe came from
    var sourceURL: String?                  // Original URL if imported
    var sourceAttribution: String?          // Attribution text (e.g., "@username", "Grandma Rose")

    // MARK: - Lineage Tracking (for sharing)
    var rootProvenanceHash: String          // SHA256 identifying share chain root
    var generation: Int                     // 0 = original, 1+ = shared copies
    var parentShareID: String?              // CKShare record ID
    var sharedByName: String?               // Who shared this
    var createdAt: Date

    // MARK: - CloudKit Sync
    var cloudKitRecordID: String?
    var lastSyncedAt: Date?
    var cachedMetrics: AggregatedMetrics    // Shares, cooks, ratings

    // MARK: - Computed Properties
    var isOriginal: Bool { generation == 0 }
    var isShared: Bool { generation > 0 }
    var displaySource: String               // User-friendly source description
    var generationBadgeText: String?        // "Gen 1", "Gen 2", etc.
}

enum SourceType: String, Codable, CaseIterable {
    case userCreated    // Manually entered
    case imported       // From web URL
    case shared         // Received via CKShare
    case scanned        // OCR from cookbook
    case ai             // AI generated
    case video          // Video import (YouTube, TikTok, camera roll)

    var displayName: String
    var iconName: String  // SF Symbol name
}

struct AggregatedMetrics: Codable, Hashable {
    var totalShares: Int = 0
    var totalCooks: Int = 0
    var averageRating: Double? = nil
    var ratingCount: Int = 0
    var commentCount: Int = 0
    var trendingScore: Double = 0.0
    var lastUpdated: Date?

    var isTrending: Bool { trendingScore > 10.0 && totalShares > 5 }
    var displayShareCount: String
}
```

**Extension Points for Video Import**:
- `sourceType`: Use `.video` for all video imports
- `sourceURL`: Store original platform URL (TikTok, Instagram, YouTube, Facebook)
- `sourceAttribution`: Store creator handle/name (e.g., "@username")
- **NEW**: Will need to track detection method (URL metadata, watermark, OCR, manual)

**Key Design**:
- Embedded as Codable property in Recipe model
- Already has `.video` source type
- `sourceAttribution` is perfect for creator names
- No need to create new attribution model - extend this one

## Recipe Model Video-Related Fields

**Location**: `Heirloom/Core/Models/Recipe.swift`

```swift
@Model
final class Recipe {
    // ... other properties ...

    /// Provenance and lineage tracking
    var provenanceMetadata: ProvenanceMetadata

    // Video import creates recipe with:
    // - provenanceMetadata.sourceType = .video
    // - provenanceMetadata.sourceURL = original platform URL
    // - provenanceMetadata.sourceAttribution = creator name/handle
}
```

**Persistence**: Uses SwiftData (Swift's new data framework)

## PaywallManager & Subscription Infrastructure

### PaywallTrigger Enum

**Location**: `Heirloom/Core/Services/Store/PaywallManager.swift`

```swift
enum PaywallTrigger {
    // Soft Walls (with cooldowns)
    case firstRecipeAdded           // After 1st recipe (48hr cooldown)
    case fiveRecipesOrDay7          // After 5 recipes OR day 7 (72hr cooldown)
    case day13Urgency               // Day 13 urgency nudge (no cooldown)

    // Hard Walls (no cooldown, blocks feature)
    case urlImport                  // Hard wall - URL import feature
    case cookbookScan               // Hard wall - cookbook scan feature
    case sync                       // Hard wall - sync feature
    case largePDFImport(pageCount: Int)  // Hard wall - PDF import 50+ pages

    // TO ADD:
    // case visualVideoExtraction     // Hard wall - visual/ASMR video extraction

    var displayName: String
    var isSoftWall: Bool            // true for first 3, false for rest
    var cooldownHours: Int?         // Soft walls have cooldowns, hard walls nil
}
```

**PaywallManager Methods**:
```swift
@MainActor @Observable
final class PaywallManager {
    private(set) var shouldShowPaywall = false
    private(set) var currentTrigger: PaywallTrigger?
    private(set) var softWallDismissCount = 0
    private(set) var isStrikeRuleActive = false  // After 3 soft wall dismissals

    /// Check if paywall should show for trigger
    func shouldShow(for trigger: PaywallTrigger) -> Bool

    /// Show paywall for trigger
    func show(for trigger: PaywallTrigger)

    /// Dismiss current paywall
    func dismiss()

    /// Track recipe addition (for soft wall triggers)
    func trackRecipeAdded()

    /// Reset all state (testing only)
    func reset()
}
```

**3-Strike Rule**:
- After 3 soft wall dismissals, `isStrikeRuleActive = true`
- Blocks ALL paywalls (soft and hard) until user subscribes
- Hard walls still evaluate but respect strike rule

### SubscriptionManager

**Location**: `Heirloom/Core/Services/Store/SubscriptionManager.swift`

```swift
@MainActor @Observable
final class SubscriptionManager {
    private(set) var status: HeirloomSubscriptionStatus = .none
    private(set) var trialExpiryDate: Date?
    private(set) var subscriptionExpiryDate: Date?
    private(set) var daysRemaining: Int?

    /// Does user have premium access?
    var isPremium: Bool { status.isPremium }

    /// Is user in trial?
    var isInTrial: Bool

    /// Is trial expired?
    var isTrialExpired: Bool

    /// Current product ID (monthly, annual, lifetime)
    var currentProductID: ProductIdentifier?

    /// Current plan name
    var currentPlanName: String?
}
```

**HeirloomSubscriptionStatus**:
```swift
enum HeirloomSubscriptionStatus: String, Codable {
    case none       // Free user
    case trial      // In trial period
    case monthly    // Monthly subscriber

    var isPremium: Bool {
        self == .trial || self == .monthly
    }
}
```

**Usage Pattern for Video Import**:
```swift
// Check if user can use visual extraction
if subscriptionManager.isPremium {
    // Proceed with visual extraction
} else {
    // Show paywall
    paywallManager.show(for: .visualVideoExtraction)
}
```

## Share Extension Current State

### HeirloomShareExtension Target

**Bundle ID**: `com.matthanson.heirloom.HeirloomShareExtension` (inferred from structure)

**App Group**: `group.com.matthanson.heirloom.shared` (from entitlements)

**Activation Rules** (`Info.plist`):
- Activates for URLs (web sharing)
- Detected platforms: Recipe websites via RecipeURLDetector

**Implemented Features** (`ShareViewController.swift`):
- ✅ URL extraction from share context
- ✅ Recipe URL detection (20+ common recipe sites)
- ✅ Confirmation dialog for non-recipe URLs
- ✅ Deep linking to main app: `heirloom://import?url=<encoded_url>`
- ✅ Shared container storage via App Group UserDefaults
- ✅ UIKit-based view controller with loading/status UI

**Current Deep Link Pattern**:
```swift
// Creates: heirloom://import?url=<encoded_url>
URLComponents()
    .scheme = "heirloom"
    .host = "import"
    .queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
```

**Shared Container Storage**:
```swift
let groupDefaults = UserDefaults(suiteName: "group.com.matthanson.heirloom.shared")
groupDefaults?.set(url.absoluteString, forKey: "pendingImportURL")
groupDefaults?.set(Date(), forKey: "pendingImportTimestamp")
```

**Needs Implementation**:
- ❌ Video file handling (currently only URLs)
- ❌ Social platform detection (TikTok, Instagram, YouTube, Facebook)
- ❌ Video file copy to shared container
- ❌ Pending import file tracking
- ❌ Progress reporting during analysis
- ❌ SwiftUI view (currently UIKit)

### Heirloom/ShareExtension/ Directory

**Location**: `Heirloom/ShareExtension/ShareViewController.swift`

**Status**: Supporting code file, not the main extension target (HeirloomShareExtension is the actual target)

## Add Menu Location & Structure

**Location**: `Heirloom/Features/Recipes/RecipeList/`

**Files**:
- `RecipeListView.swift` - Main list view with add recipe state
- `RecipeListToolbarActions.swift` - Toolbar with add button
- `RecipeSheetModifiers.swift` - Sheet modifiers for all add flows

**Current Add Options** (via separate sheets):
1. `showAddRecipe` → `RecipeEditorView()` - Manual entry
2. `showImportRecipe` → `RecipeImportView()` - URL import
3. `showBulkImport` → `BulkImportView()` - Bulk import
4. `showCookbookScanner` → `CookbookScannerView()` - Cookbook OCR
5. `showVideoImport` → `VideoImportView()` - Video (audio narration)
6. `showASMRVideoImport` → `ASMRVideoImportView()` - Video (silent/visual)

**Flow**:
```
RecipeListToolbarActions (+ button)
    → onAddRecipe() callback
    → RecipeListView sets showAddRecipe = true
    → RecipeSheetModifiers presents appropriate sheet
```

**Unified Video Import Change**:
- Replace separate `showVideoImport` and `showASMRVideoImport` sheets
- Add single `showUnifiedVideoImport` → `UnifiedVideoImportView()`
- UnifiedVideoImportView handles:
  1. Video/URL selection
  2. Platform detection
  3. Audio analysis (auto-detect mode)
  4. OCR analysis (if audio poor)
  5. Paywall check (if both poor → visual needed)
  6. Extraction with chosen mode

## App Group Configuration

**App Group ID**: `group.com.matthanson.heirloom.shared`

**Configured In**:
- HeirloomShareExtension.entitlements ✅
- Main app entitlements (assumed) ✅

**Shared Container Paths**:
```swift
FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.com.matthanson.heirloom.shared"
)
```

**Will Store**:
- Pending video imports (file copies)
- Import metadata (JSON)
- Temporary analysis results

## URL Scheme Registration

**Scheme**: `heirloom://`

**Current Deep Links**:
- `heirloom://import?url=<encoded_url>` - Import from URL (share extension)

**Will Add**:
- `heirloom://import-video?id=<pending_import_id>` - Process pending video import

## Summary of Key Integration Points

### Extend (Don't Create New):
1. **PaywallTrigger** - Add `.visualVideoExtraction` case
2. **ProvenanceMetadata** - Use existing fields for attribution
3. **WhisperKitTranscriptionService** - Use existing transcription service
4. **RecipeSheetModifiers** - Add unified video import sheet

### Create New:
1. **ExtractionMode** enum (audioTranscript, onScreenText, visualFrames)
2. **AudioAnalysisResult** model
3. **OnScreenTextResult** model
4. **PendingVideoImport** model for share extension handoff
5. **SocialPlatform** enum (TikTok, Instagram, YouTube, Facebook)
6. **PlatformDetector** service
7. **AudioAnalyzer** service (wraps WhisperKitTranscriptionService)
8. **OnScreenTextDetector** service (Vision framework OCR)
9. **WatermarkDetector** service
10. **AttributionResolver** service
11. **SocialMetadataService** (oEmbed APIs)
12. **PendingImportProcessor** (three-tier cascade + paywall logic)
13. **UnifiedVideoImportView** (replaces separate video import views)
14. **CreatorAttributionBadge** component
15. **RecipeSourceSection** component

### Critical Architecture Decisions:
1. **NO credit system** - Use subscription status only
2. **Hard wall for visual extraction** - No cooldown, blocks feature
3. **Free tiers**: Audio transcript + OCR text
4. **Premium tier**: Visual frame analysis (ASMR videos)
5. **Three-tier cascade**: Audio → OCR → Visual (with paywall between OCR and Visual)
6. **Extend ProvenanceMetadata** - Don't create CreatorAttribution model
7. **Share extension → Main app handoff** via App Group shared container
8. **Deep linking** for seamless transition from share extension
